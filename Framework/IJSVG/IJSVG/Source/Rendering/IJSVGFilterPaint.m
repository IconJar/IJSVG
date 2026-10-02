//
//  IJSVGFilterPaint.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterPaint.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGFilterGraph.h>
#import <IJSVGQuartzRenderer.h>
#import <IJSVGPatternPaint.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import "IJSVGFilterSIMD.h"
#import <limits.h>

static _Thread_local CGContextRef IJSVGFilterBitmapContext;
static _Thread_local CGContextRef IJSVGFilterBackgroundContext;
static _Thread_local CGRect IJSVGFilterBackgroundClip;
static _Thread_local CGContextRef IJSVGFilterDestinationContext;
static _Thread_local CGAffineTransform IJSVGFilterDestinationTransform;

static CGAffineTransform IJSVGFilterPixelTransform(CGContextRef context)
{
    CGAffineTransform transform = CGContextGetCTM(context);
    if(context == IJSVGFilterDestinationContext) {
        transform = CGAffineTransformConcat(transform, IJSVGFilterDestinationTransform);
    }
    return transform;
}

static BOOL IJSVGFilterRectIsFinite(CGRect rect)
{
    return isfinite(rect.origin.x) && isfinite(rect.origin.y)
        && isfinite(rect.size.width) && isfinite(rect.size.height);
}


// A shared Metal buffer lets Quartz consume completed filter pixels directly.
// Keep placement, clipping and source-over in Quartz: replacing those operations
// with Core Image changes fractional coverage and accumulated 8-bit rounding.
static void IJSVGFilterReleaseMetalBuffer(void* info, const void* bytes, size_t length)
{
    CFRelease(info);
}

static CGImageRef IJSVGFilterNewSharedMetalImage(CIImage* output, CGRect extent,
                                                CGColorSpaceRef colorSpace)
{
    static id<MTLDevice> device;
    static id<MTLCommandQueue> queue;
    static CIContext* context;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        id<MTLDevice> candidate = MTLCreateSystemDefaultDevice();
        if(candidate.hasUnifiedMemory) {
            device = candidate;
            queue = [device newCommandQueue];
            if(queue != nil) {
                context = [CIContext contextWithMTLCommandQueue:queue
                                                        options:@{
                    kCIContextCacheIntermediates: @NO
                }];
            }
        }
    });
    if(context == nil || !IJSVGFilterRectIsFinite(extent) ||
        !CGPointEqualToPoint(extent.origin, CGPointZero) ||
        extent.size.width < 1 || extent.size.height < 1 ||
        extent.size.width > 4096 || extent.size.height > 4096 ||
        extent.size.width * extent.size.height > 4194304 ||
        !CGRectEqualToRect(extent, CGRectIntegral(extent))) {
        return NULL;
    }
    NSUInteger width = extent.size.width, height = extent.size.height;
    NSUInteger alignment = [device minimumLinearTextureAlignmentForPixelFormat:MTLPixelFormatRGBA8Unorm];
    if(alignment == 0) {
        return NULL;
    }
    NSUInteger stride = (width * 4 + alignment - 1) / alignment * alignment;
    id<MTLBuffer> buffer = [device newBufferWithLength:stride * height
                                               options:MTLResourceStorageModeShared];
    if(buffer == nil) {
        return NULL;
    }
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                          width:width
                                                                                         height:height
                                                                                      mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;
    descriptor.storageMode = MTLStorageModeShared;
    id<MTLTexture> texture = [buffer newTextureWithDescriptor:descriptor
                                                       offset:0
                                                  bytesPerRow:stride];
    id<MTLCommandBuffer> commands = [queue commandBuffer];
    if(texture == nil || commands == nil) {
        return NULL;
    }
    CIRenderDestination* destination = [[CIRenderDestination alloc] initWithMTLTexture:texture
                                                                         commandBuffer:commands];
    destination.colorSpace = colorSpace;
    // CGImage providers use top-to-bottom rows. Materialize the filter at its
    // pixel grid; linear sampling here changes fractional filter-region coverage.
    destination.flipped = YES;
    NSError* error = nil;
    CIRenderTask* task = [context startTaskToRender:[output imageBySamplingNearest]
                                         fromRect:extent
                                    toDestination:destination
                                          atPoint:CGPointZero error:&error];
    if(task == nil) {
        return NULL;
    }
    [commands commit];
    [commands waitUntilCompleted];
    if(commands.status != MTLCommandBufferStatusCompleted) {
        return NULL;
    }

    // The provider owns the buffer until Quartz releases the image; no pool may
    // reuse these bytes while an image or destination snapshot still retains them.
    void* retainedBuffer = (void*)CFBridgingRetain(buffer);
    CGDataProviderRef provider = CGDataProviderCreateWithData(retainedBuffer,
        buffer.contents, buffer.length, IJSVGFilterReleaseMetalBuffer);
    if(provider == NULL) {
        CFRelease(retainedBuffer);
        return NULL;
    }
    CGImageRef image = CGImageCreate(width, height, 8, 32, stride, colorSpace,
        (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big,
        provider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    return image;
}

// Nested filters already inherit the drawing transform of the supersampled bitmap.
static _Thread_local NSUInteger IJSVGFilterRenderDepth = 0;

@interface IJSVGQuartzFilterBatchEntry : NSObject
@property (nonatomic, strong) CIImage* output;
@property (nonatomic, strong) IJSVGMetalShadowJob* metalShadow;
@property (nonatomic, strong) IJSVGMetalBlurJob* metalBlur;
@property (nonatomic, assign) CGRect workRect;
@property (nonatomic, assign) CGSize pixelSize;
@property (nonatomic, assign) CGRect atlasRect;
@property (nonatomic, assign) CGImageRef renderedImage;
@end

@implementation IJSVGQuartzFilterBatchEntry

- (void)dealloc
{
    if(_renderedImage != NULL) {
        CGImageRelease(_renderedImage);
    }
}
@end

@interface IJSVGQuartzFilterBatch : NSObject

@property (nonatomic, strong) NSMapTable<IJSVGFilterPaint*, IJSVGQuartzFilterBatchEntry*>* entries;
@property (nonatomic, strong) NSMutableArray<IJSVGQuartzFilterBatchEntry*>* orderedEntries;
@property (nonatomic, assign) BOOL collecting;
@property (nonatomic, assign) BOOL preflighting;
@property (nonatomic, strong) NSMutableSet<IJSVGFilterPaint*>* preflightPaints;
@property (nonatomic, assign) BOOL invalid;
@property (nonatomic, assign) NSUInteger retainedPixels;
@property (nonatomic, assign) NSUInteger totalPixels;
@property (nonatomic, assign) NSUInteger scratchBytes;
@property (nonatomic, assign) NSUInteger largestSourcePixels;
@property (nonatomic, strong) NSSet<IJSVGFilterPaint*>* eligiblePaints;
@property (nonatomic, strong) NSSet<IJSVGPaint*>* collectionPaints;
@end

@implementation IJSVGQuartzFilterBatch
@end

// Scoped to a synchronous draw, the owning local retains the batch until the
// pointer is cleared in @finally. No state survives the synchronous draw.
static _Thread_local __unsafe_unretained IJSVGQuartzFilterBatch* IJSVGCurrentFilterBatch;

static BOOL IJSVGQuartzFilterBatchEligible(IJSVGPaint* root, NSMutableSet<IJSVGFilterPaint*>* eligiblePaints)
{
    NSMutableArray<IJSVGPaint*>* pending = [NSMutableArray arrayWithObject:root];
    NSUInteger filters = 0;
    while(pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        if(paint.maskPaint != nil || paint.clipPaints.count != 0) {
            return NO;
        }
        if([paint isKindOfClass:IJSVGFilterPaint.class]) {
            IJSVGFilterPaint* filtered = (id)paint;
            if(filtered.usesBackground) {
                return NO;
            }
            for(IJSVGPaint* parent = paint.parentPaint; parent != nil;
                parent = parent.parentPaint) {
                if([parent isKindOfClass:IJSVGFilterPaint.class]) {
                    return NO;
                }
            }
            [eligiblePaints addObject:filtered];
            filters++;
        }
        [pending addObjectsFromArray:paint.children ?: @[]];
    }
    return filters >= 3 && filters <= 128;
}

static BOOL IJSVGFilterRenderShadowEntries(NSArray<IJSVGQuartzFilterBatchEntry*>* entries)
{
    NSMutableArray<IJSVGMetalShadowJob*>* shadows = [[NSMutableArray alloc] init];
    for(IJSVGQuartzFilterBatchEntry* entry in entries) {
        if(entry.metalShadow != nil) {
            [shadows addObject:entry.metalShadow];
        }
    }
    if(![IJSVGMetalShadowJob renderJobs:shadows]) {
        return NO;
    }
    for(IJSVGQuartzFilterBatchEntry* entry in entries) {
        if(entry.metalShadow != nil) {
            entry.renderedImage = CGImageRetain(entry.metalShadow.renderedImage);
            entry.metalShadow = nil;
        }
    }
    return YES;
}


static BOOL IJSVGFilterRenderBlurEntries(NSArray<IJSVGQuartzFilterBatchEntry*>* entries)
{
    NSMutableArray<IJSVGMetalBlurJob*>* blurs = [[NSMutableArray alloc] init];
    for(IJSVGQuartzFilterBatchEntry* entry in entries) {
        if(entry.metalBlur != nil) {
            [blurs addObject:entry.metalBlur];
        }
    }
    if(![IJSVGMetalBlurRenderer renderJobs:blurs]) {
        return NO;
    }
    for(IJSVGQuartzFilterBatchEntry* entry in entries) {
        if(entry.metalBlur != nil) {
            entry.renderedImage = CGImageRetain(entry.metalBlur.renderedImage);
            entry.metalBlur = nil;
        }
    }
    return YES;
}


static CGImageRef IJSVGFilterNewImageForAtlas(CIImage* atlas, CGSize size)
{
    __block CGImageRef rendered = NULL;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    // Wait before leasing a context. Source drawing and graph construction
    // remain concurrent, and the slot is returned before cropping or replay.
    [IJSVGThreadManager performCIOutputBlock:^{
        [IJSVGThreadManager performBlockWithCIContext:^(CIContext* ciContext, BOOL supportsMetalKernels) {
            rendered = [ciContext createCGImage:atlas
                                       fromRect:CGRectMake(0, 0, size.width, size.height)
                                         format:kCIFormatRGBA8
                                     colorSpace:colorSpace];
        }];
    }];
    CGColorSpaceRelease(colorSpace);
    return rendered;
}


static CIImage* IJSVGFilterAtlasForEntries(
    NSArray<IJSVGQuartzFilterBatchEntry*>* entries,
    CGFloat atlasWidth,
    CGFloat* height)
{
    CGFloat x = 0, y = 0, rowHeight = 0;
    CIImage* atlas = CIImage.emptyImage;
    for(IJSVGQuartzFilterBatchEntry* entry in entries) {
        if(entry.output == nil) {
            continue;
        }
        CGSize size = entry.pixelSize;
        if(x + size.width > atlasWidth) {
            x = 0;
            y += rowHeight;
            rowHeight = 0;
        }
        entry.atlasRect = CGRectMake(x, y, size.width, size.height);
        CIImage* tile = [[entry.output imageByCroppingToRect:CGRectMake(0, 0, size.width, size.height)]
                         imageByApplyingTransform:CGAffineTransformMakeTranslation(x, y)];
        atlas = [tile imageByCompositingOverImage:atlas];
        x += size.width;
        rowHeight = MAX(rowHeight, size.height);
    }
    CGFloat atlasHeight = y + rowHeight;
    *height = atlasHeight;
    return atlas;
}


static BOOL IJSVGFilterRenderCollectedEntries(NSArray<IJSVGQuartzFilterBatchEntry*>* entries)
{
    if(!IJSVGFilterRenderShadowEntries(entries)) {
        return NO;
    }
    if(!IJSVGFilterRenderBlurEntries(entries)) {
        return NO;
    }
    NSUInteger pixels = 0;
    NSMutableArray<IJSVGQuartzFilterBatchEntry*>* ciEntries = [[NSMutableArray alloc] init];
    for(IJSVGQuartzFilterBatchEntry* entry in entries) {
        if(entry.output != nil) {
            pixels += entry.pixelSize.width * entry.pixelSize.height;
            [ciEntries addObject:entry];
        }
    }
    if(pixels == 0) {
        return YES;
    }
    CGFloat atlasWidth = ciEntries.count == 1 ? ciEntries.firstObject.pixelSize.width : ceil(sqrt(pixels));
    for(IJSVGQuartzFilterBatchEntry* entry in entries) {
        if(entry.output != nil) {
            atlasWidth = MAX(atlasWidth, entry.pixelSize.width);
        }
    }
    CGFloat atlasHeight;
    CIImage* atlas = IJSVGFilterAtlasForEntries(entries, atlasWidth, &atlasHeight);
    if(atlasWidth * atlasHeight > 1048576 || atlasWidth * atlasHeight > pixels * 2) {
        // Packing padding can exceed the budget even when source pixels fit.
        // Split whole filter images so convolution never loses neighbouring pixels.
        if(ciEntries.count < 2) {
            return NO;
        }
        NSUInteger middle = ciEntries.count / 2;
        return IJSVGFilterRenderCollectedEntries([ciEntries subarrayWithRange:NSMakeRange(0, middle)]) &&
            IJSVGFilterRenderCollectedEntries(
                [ciEntries subarrayWithRange:NSMakeRange(middle, ciEntries.count - middle)]);
    }
    CGImageRef rendered = IJSVGFilterNewImageForAtlas(atlas, CGSizeMake(atlasWidth, atlasHeight));
    if(rendered == NULL) {
        return NO;
    }
    for(IJSVGQuartzFilterBatchEntry* entry in entries) {
        if(entry.renderedImage != NULL) {
            continue;
        }
        CGRect crop = entry.atlasRect;
        crop.origin.y = atlasHeight - CGRectGetMaxY(crop);
        entry.renderedImage = CGImageCreateWithImageInRect(rendered, crop);
        entry.output = nil;
        if(entry.renderedImage == NULL) {
            CGImageRelease(rendered);
            return NO;
        }
    }
    CGImageRelease(rendered);
    return YES;
}


static CGContextRef IJSVGFilterNewCollectionContext(CGContextRef context)
{
    // Display and PDF contexts cannot be queried with bitmap context APIs.
    // Use the pixel mapping supplied by the renderer for the collection bitmap.
    CGAffineTransform transform = IJSVGFilterPixelTransform(context);
    CGRect deviceBounds = CGRectApplyAffineTransform(CGContextGetClipBoundingBox(context), transform);
    if(!IJSVGFilterRectIsFinite(deviceBounds) || CGRectIsEmpty(deviceBounds)) {
        return NULL;
    }
    deviceBounds = CGRectIntegral(deviceBounds);
    if(deviceBounds.size.width > 2048 || deviceBounds.size.height > 2048 ||
        deviceBounds.size.width * deviceBounds.size.height > 4194304) {
        return NULL;
    }
    CGColorSpaceRef scratchColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef scratch = CGBitmapContextCreate(NULL, deviceBounds.size.width, deviceBounds.size.height,
        8, 0, scratchColorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(scratchColorSpace);
    if(scratch == NULL) {
        return NULL;
    }
    CGContextTranslateCTM(scratch, -deviceBounds.origin.x, -deviceBounds.origin.y);
    CGContextConcatCTM(scratch, transform);
    return scratch;
}


static NSSet<IJSVGPaint*>* IJSVGFilterCollectionPaintsForFilters(NSSet<IJSVGFilterPaint*>* eligiblePaints)
{
    NSMutableSet<IJSVGPaint*>* collectionPaints = [[NSMutableSet alloc] init];
    for(IJSVGPaint* filtered in eligiblePaints) {
        for(IJSVGPaint* paint = filtered; paint != nil; paint = paint.parentPaint) {
            if([collectionPaints containsObject:paint]) {
                break;
            }
            [collectionPaints addObject:paint];
        }
    }
    return collectionPaints;
}


static CIImage* IJSVGFilterBackgroundImageFromContext(CGContextRef ctx,
                                                      CGAffineTransform imageTransform)
{
    // Bitmap destinations can supply their already painted backdrop.
    // Nonbitmap contexts have no readable pixel backing.
    if(ctx != IJSVGFilterBitmapContext) {
        return CIImage.emptyImage;
    }
    CGImageRef background = CGBitmapContextCreateImage(ctx);
    if(background == NULL) {
        return CIImage.emptyImage;
    }
    CIImage* image = [CIImage imageWithCGImage:background];
    CGImageRelease(background);
    if(ctx == IJSVGFilterBackgroundContext && !CGRectIsInfinite(IJSVGFilterBackgroundClip)) {
        image = [image imageByCroppingToRect:IJSVGFilterBackgroundClip];
    }
    CGAffineTransform mapping
        = CGAffineTransformConcat(CGAffineTransformInvert(CGContextGetCTM(ctx)), imageTransform);
    return [image imageByApplyingTransform:mapping];
}


static BOOL IJSVGFilterReservePixelSize(CGSize pixelSize,
                                        IJSVGQuartzFilterBatch* batch,
                                        IJSVGQuartzFilterBatchEntry* cached)
{
    if(batch.collecting) {
        NSUInteger pixels = pixelSize.width * pixelSize.height;
        if(cached != nil || pixelSize.width > 2048 || pixelSize.height > 2048 ||
            pixels > 1048576 || batch.totalPixels + pixels > 8388608) {
            batch.invalid = YES;
            return NO;
        }
        // Flush complete jobs at one megapixel. Finished RGBA8 images remain
        // available for ordered replay, while source and GPU scratch storage is reused.
        if(batch.retainedPixels + pixels > 1048576) {
            if(!IJSVGFilterRenderCollectedEntries(batch.orderedEntries)) {
                batch.invalid = YES;
                return NO;
            }
            batch.retainedPixels = 0;
        }
        batch.retainedPixels += pixels;
        batch.totalPixels += pixels;
    }
    return YES;
}


static void IJSVGFilterDrawFilteredImage(CGImageRef image, CGContextRef ctx,
                                         CGRect region, CGRect workRect)
{
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, region);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextDrawImage(ctx, workRect, image);
    CGContextRestoreGState(ctx);
}


// Cached pixels never retain the paint graph. NSCache can discard them under
// memory pressure, and a paint removes its entry when its resolved graph dies.
@interface IJSVGFilterCachedImage : NSObject
@property (nonatomic, assign) CGImageRef image;
@property (nonatomic, copy) NSArray* signature;
@end

@implementation IJSVGFilterCachedImage
- (void)dealloc
{
    CGImageRelease(_image);
}
@end

static NSCache<NSObject*, IJSVGFilterCachedImage*>* IJSVGFilterOutputCache(void)
{
    static NSCache* cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 256;
        cache.totalCostLimit = 32 * 1024 * 1024;
    });
    return cache;
}

@interface IJSVGFilterPaint () {
    NSObject* _outputCacheKey;
    NSArray* _outputSignature;
    BOOL _checkedOutputCaching;
    BOOL _canCacheOutput;
}
@end

@implementation IJSVGFilterPaint

+ (void)drawInContext:(CGContextRef)context
       pixelTransform:(CGAffineTransform)pixelTransform
         drawingBlock:(void (^)(void))drawingBlock
{
    CGContextRef previousContext = IJSVGFilterDestinationContext;
    CGAffineTransform previousTransform = IJSVGFilterDestinationTransform;
    // Keep only the mapping that is missing from the drawing context.
    CGAffineTransform transform = CGContextGetCTM(context);
    IJSVGFilterDestinationContext = context;
    IJSVGFilterDestinationTransform = CGAffineTransformConcat(CGAffineTransformInvert(transform), pixelTransform);
    @try {
        drawingBlock();
    } @finally {
        IJSVGFilterDestinationContext = previousContext;
        IJSVGFilterDestinationTransform = previousTransform;
    }
}

+ (void)drawBackgroundForPaint:(IJSVGPaint*)paint
                       context:(CGContextRef)context
                  drawingBlock:(void (^)(CGContextRef))drawingBlock
{
    CGAffineTransform transform = CGContextGetCTM(context);
    CGRect bounds = CGRectIntegral(CGRectApplyAffineTransform(CGContextGetClipBoundingBox(context), transform));
    if(!IJSVGFilterRectIsFinite(bounds) || CGRectIsEmpty(bounds)) {
        return;
    }
    CGFloat scale = MIN(1.f, MIN(4096.f / bounds.size.width, 4096.f / bounds.size.height));
    size_t width = MAX(1, ceil(bounds.size.width * scale));
    size_t height = MAX(1, ceil(bounds.size.height * scale));
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, 0, space,
        kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if(bitmap == NULL) {
        return;
    }
    CGContextScaleCTM(bitmap, scale, scale);
    CGContextTranslateCTM(bitmap, -bounds.origin.x, -bounds.origin.y);
    CGContextConcatCTM(bitmap, transform);
    CGContextRef previousBitmap = IJSVGFilterBitmapContext;
    CGContextRef previousBackground = IJSVGFilterBackgroundContext;
    CGRect previousClip = IJSVGFilterBackgroundClip;
    IJSVGFilterBitmapContext = bitmap;
    IJSVGFilterBackgroundContext = bitmap;
    CGRect clip = paint.sourceNode.backgroundRect;
    IJSVGFilterBackgroundClip = CGRectIsInfinite(clip) ? clip
        : CGRectApplyAffineTransform(clip, CGContextGetCTM(bitmap));
    @try {
        drawingBlock(bitmap);
    } @finally {
        IJSVGFilterBitmapContext = previousBitmap;
        IJSVGFilterBackgroundContext = previousBackground;
        IJSVGFilterBackgroundClip = previousClip;
    }
    CGImageRef image = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    if(image != NULL) {
        CGContextSaveGState(context);
        CGContextConcatCTM(context, CGAffineTransformInvert(transform));
        // Apply container opacity after its children finish reading the background.
        CGContextSetAlpha(context, paint.opacity);
        CGContextDrawImage(context, bounds, image);
        CGContextRestoreGState(context);
        CGImageRelease(image);
    }
}

+ (BOOL)isRegisteredBitmapContext:(CGContextRef)context
{
    return context != NULL && context == IJSVGFilterBitmapContext;
}

+ (void)renderPaint:(IJSVGPaint*)paint
    inBitmapContext:(CGContextRef)context
{
    CGContextRef previous = IJSVGFilterBitmapContext;
    IJSVGFilterBitmapContext = context;
    @try {
        [paint renderInContext:context];
    } @finally {
        IJSVGFilterBitmapContext = previous;
    }
}

- (void)dealloc
{
    if(_outputCacheKey != nil) {
        [IJSVGFilterOutputCache() removeObjectForKey:_outputCacheKey];
    }
}

- (BOOL)usesBackground
{
    NSSet* names = self.filter.inputNames;
    if(![names containsObject:IJSVGStringBackgroundImage] &&
        ![names containsObject:IJSVGStringBackgroundAlpha]) {
        return NO;
    }
    // A new canvas on the filtered container has no earlier contents.
    if(!CGRectIsNull(self.sourceNode.backgroundRect)) {
        return NO;
    }
    for(IJSVGNode* node = self.sourceNode.parentNode; node != nil;
        node = node.parentNode) {
        if(!CGRectIsNull(node.backgroundRect)) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)canCacheOutput
{
    if(!self.cachesRenderedOutput) {
        return NO;
    }
    if(_checkedOutputCaching) {
        return _canCacheOutput;
    }
    _checkedOutputCaching = YES;
    // Backdrop inputs depend on the destination, including those inside masks,
    // patterns and nested filters. feImage can reference another SVG subtree.
    NSMutableArray<IJSVGPaint*>* pending = [NSMutableArray arrayWithObject:self];
    NSMutableSet<IJSVGPaint*>* visited = [[NSMutableSet alloc] init];
    while(pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        if([visited containsObject:paint]) {
            continue;
        }
        [visited addObject:paint];
        if([paint isKindOfClass:IJSVGFilterPaint.class]) {
            IJSVGFilter* filter = ((IJSVGFilterPaint*)paint).filter;
            if(((IJSVGFilterPaint*)paint).usesBackground) {
                return NO;
            }
            for(IJSVGFilterPrimitive* primitive in filter.primitives) {
                if(primitive.type == IJSVGNodeTypeFilterImage) {
                    return NO;
                }
            }
        }
        [pending addObjectsFromArray:paint.children];
        [pending addObjectsFromArray:paint.clipPaints ?: @[]];
        if(paint.maskPaint != nil) {
            [pending addObject:paint.maskPaint];
        }
        if([paint isKindOfClass:IJSVGPatternPaint.class]) {
            IJSVGPaint* pattern = ((IJSVGPatternPaint*)paint).pattern;
            if(pattern != nil) {
                [pending addObject:pattern];
            }
        }
    }
    _outputCacheKey = [[NSObject alloc] init];
    return _canCacheOutput = YES;
}

- (void)drawFilteredImage:(CGImageRef)image
                 context:(CGContextRef)ctx
                  region:(CGRect)region
                workRect:(CGRect)workRect
{
    if(_outputSignature != nil) {
        IJSVGFilterCachedImage* cached = [IJSVGFilterOutputCache() objectForKey:_outputCacheKey];
        if(![cached.signature isEqual:_outputSignature]) {
            NSUInteger width = CGImageGetWidth(image), height = CGImageGetHeight(image);
            // An atlas crop can retain a much larger backing image. Materialize
            // independent RGBA8 pixels so cache cost reflects retained storage.
            if(width != 0 && height != 0 && width <= 4194304 / height) {
                CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
                    CGImageGetColorSpace(image), kCGImageAlphaPremultipliedLast);
                if(bitmap != NULL) {
                    CGContextSetBlendMode(bitmap, kCGBlendModeCopy);
                    CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), image);
                    CGImageRef copy = CGBitmapContextCreateImage(bitmap);
                    CGContextRelease(bitmap);
                    if(copy != NULL) {
                        cached = [[IJSVGFilterCachedImage alloc] init];
                        cached.image = copy;
                        cached.signature = _outputSignature;
                        [IJSVGFilterOutputCache() setObject:cached
                                                     forKey:_outputCacheKey
                                                       cost:width * height * 4];
                    }
                }
            }
        }
    }
    IJSVGFilterDrawFilteredImage(image, ctx, region, workRect);
}

+ (BOOL)shouldRenderPaintDuringCollection:(IJSVGPaint*)paint
{
    IJSVGQuartzFilterBatch* batch = IJSVGCurrentFilterBatch;
    // Filter source bitmaps still need their complete subtree.
    return !batch.collecting || IJSVGFilterRenderDepth != 0
        || [batch.collectionPaints containsObject:paint];
}

+ (NSSet<IJSVGFilterPaint*>*)batchableFiltersForPaint:(IJSVGPaint*)root
{
    NSMutableSet<IJSVGFilterPaint*>* paints = [[NSMutableSet alloc] init];
    return IJSVGQuartzFilterBatchEligible(root, paints) ? paints.copy : nil;
}

+ (BOOL)renderBatchedPaints:(NSSet<IJSVGFilterPaint*>*)eligiblePaints
                 inContext:(CGContextRef)context
              drawingBlock:(void (^)(CGContextRef))drawingBlock
{
    if(context == NULL || IJSVGCurrentFilterBatch != nil || eligiblePaints.count == 0) {
        return NO;
    }
    CGContextRef scratch = IJSVGFilterNewCollectionContext(context);
    if(scratch == NULL) {
        return NO;
    }
    IJSVGQuartzFilterBatch* batch __attribute__((objc_precise_lifetime)) = [[IJSVGQuartzFilterBatch alloc] init];
    batch.eligiblePaints = eligiblePaints;
    batch.scratchBytes = CGBitmapContextGetBytesPerRow(scratch) * CGBitmapContextGetHeight(scratch);
    batch.collectionPaints = IJSVGFilterCollectionPaintsForFilters(eligiblePaints);
    batch.entries = NSMapTable.strongToStrongObjectsMapTable;
    batch.orderedEntries = [[NSMutableArray alloc] init];
    batch.collecting = YES;
    IJSVGCurrentFilterBatch = batch;
    @try {
        // Walk the actual drawing transforms, but stop each filter before its
        // source bitmap is allocated or painted. Reject over budget draws before
        // doing source rasterization, blur calibration or GPU submissions.
        batch.preflighting = YES;
        batch.preflightPaints = [[NSMutableSet alloc] init];
        drawingBlock(scratch);
        if(batch.invalid || batch.preflightPaints.count < 3) {
            return NO;
        }
        batch.preflighting = NO;
        batch.preflightPaints = nil;
        batch.totalPixels = 0;
        // Visit only filter branches and their ancestors during collection.
        // Unfiltered artwork is painted once, during the final replay.
        drawingBlock(scratch);
        if(batch.invalid || batch.orderedEntries.count < 3) {
            return NO;
        }
        if(!IJSVGFilterRenderCollectedEntries(batch.orderedEntries)) {
            return NO;
        }
        batch.collecting = NO;
        drawingBlock(context);
        return YES;
    } @finally {
        IJSVGCurrentFilterBatch = nil;
        CGContextRelease(scratch);
    }
}

- (instancetype)initWithSourcePaint:(IJSVGPaint*)paint
                             filter:(IJSVGFilter*)filter
                           viewPort:(CGRect)viewPort
{
    if((self = [super init]) != nil) {
        _filter = filter;
        self.viewPort = viewPort;
        self.boundingBox = paint.boundingBox;
        self.outerBoundingBox = paint.outerBoundingBox;
        [self addChild:paint];
    }
    return self;
}

- (IJSVGPaint*)sourcePaint
{
    return (IJSVGPaint*)self.children.firstObject;
}

- (BOOL)treatImplicitOriginAsTransform
{
    return self.sourcePaint.treatImplicitOriginAsTransform;
}

- (BOOL)requiresBackingScale
{
    return YES;
}

- (CIImage*)paintImageForStroke:(BOOL)stroke
                          graph:(IJSVGFilterGraph*)graph
{
    IJSVGNode* paint = stroke ? self.sourceNode.stroke : self.sourceNode.fill;
    if(paint == nil) {
        return CIImage.emptyImage;
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, graph.extent.size.width,
                                                graph.extent.size.height, 8, 0, space,
                                                kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if(bitmap == NULL) {
        return CIImage.emptyImage;
    }
    CGContextConcatCTM(bitmap, graph.imageTransform);
    CGRect region = CGRectApplyAffineTransform(graph.extent,
                                               CGAffineTransformInvert(graph.imageTransform));
    IJSVGQuartzRenderer* tree = [[IJSVGQuartzRenderer alloc] init];
    [tree drawPaint:paint
        boundingBox:self.boundingBox
           viewPort:self.viewPort
             region:region
          inContext:bitmap];
    CGImageRef result = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    CIImage* image = result != NULL ? [CIImage imageWithCGImage:result] : CIImage.emptyImage;
    if(result != NULL) {
        CGImageRelease(result);
    }
    return image;
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    if(self.opacity != 1.f) {
        CGContextSetAlpha(ctx, self.opacity);
    }
    [self drawInContext:ctx];
}

- (CGRect)transparencyBounds
{
    return CGRectInfinite;
}

- (BOOL)requiresFilterSupersampling
{
    if(self.filter.requiresSupersampling) {
        return YES;
    }

    // An outer filter must supply enough source resolution for nested hard alpha effects.
    NSMutableArray<IJSVGPaint*>* pending = self.children.mutableCopy;
    while(pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        if([paint isKindOfClass:IJSVGFilterPaint.class]) {
            if([(IJSVGFilterPaint*)paint requiresFilterSupersampling]) {
                return YES;
            }
        } else if(paint.children.count != 0) {
            [pending addObjectsFromArray:paint.children];
        }
    }
    return NO;
}

- (void)drawInContext:(CGContextRef)ctx
{
    IJSVGFilterRenderDepth++;
    @try {
        [self drawFilterInContext:ctx];
    } @finally {
        IJSVGFilterRenderDepth--;
    }
}

- (IJSVGFilterGraph*)filterGraph
{
    IJSVGFilterGraph* graph = [[IJSVGFilterGraph alloc] init];
    graph.filter = self.filter;
    // Repeated shadow readbacks can accumulate rounding differences in nested filters.
    graph.hasNestedFilters = IJSVGFilterRenderDepth > 1;
    if(!graph.hasNestedFilters && self.filter.primitives.count == 1 &&
        self.filter.primitives.firstObject.type == IJSVGNodeTypeFilterDropShadow) {
        NSMutableArray<IJSVGPaint*>* pending = self.children.mutableCopy;
        while(pending.count != 0) {
            IJSVGPaint* paint = pending.lastObject;
            [pending removeLastObject];
            if([paint isKindOfClass:IJSVGFilterPaint.class]) {
                graph.hasNestedFilters = YES;
                break;
            }
            [pending addObjectsFromArray:paint.children ?: @[]];
        }
    }
    graph.boundingBox = self.boundingBox;
    graph.viewPort = self.viewPort;
    return graph;
}

- (void)preflightPixelSize:(CGSize)pixelSize
                     batch:(IJSVGQuartzFilterBatch*)batch
{
    NSUInteger pixels = pixelSize.width * pixelSize.height;
    if([batch.preflightPaints containsObject:self] ||
        pixelSize.width > 2048 || pixelSize.height > 2048 ||
        pixels > 1048576 || batch.totalPixels + pixels > 8388608) {
        batch.invalid = YES;
        return;
    }
    batch.largestSourcePixels = MAX(batch.largestSourcePixels, pixels);
    // Account for RGBA8 replay images with up to 2x atlas packing padding,
    // the current source bitmap, pending RGBA8 sources, and a full
    // one megapixel Metal lease (44 bytes/pixel), plus parameter headroom.
    // This is a working set estimate, not a process memory limit: CPU filter
    // intermediates and private caches in Core Image can add further storage.
    NSUInteger estimatedBytes = batch.scratchBytes
        + (batch.totalPixels + pixels) * 8
        + batch.largestSourcePixels * 4 + 1048576 * (44 + 4) + 65536;
    if(estimatedBytes > 128 * 1024 * 1024) {
        batch.invalid = YES;
        return;
    }
    [batch.preflightPaints addObject:self];
    batch.totalPixels += pixels;
    return;
}

- (void)renderSource:(CIImage*)source
               graph:(IJSVGFilterGraph*)graph
             context:(CGContextRef)ctx
          colorSpace:(CGColorSpaceRef)colorSpace
              region:(CGRect)region
            workRect:(CGRect)workRect
{
    IJSVGQuartzFilterBatch* batch = IJSVGCurrentFilterBatch;
    IJSVGQuartzFilterBatchEntry* cached = [batch.entries objectForKey:self];
    CGRect extent = graph.extent;
    CGSize pixelSize = extent.size;
    // Keep filter coordinates aligned with the source bitmap. The calling context
    // drawing transform handles flipped views and image exports.
    CGAffineTransform imageTransform = graph.imageTransform;
    [IJSVGThreadManager performBlockWithCIContext:^(CIContext* context, BOOL supportsMetalKernels) {
        graph.context = context;
        graph.supportsMetalKernels = supportsMetalKernels;
        graph.extent = extent;
        graph.imageTransform = imageTransform;
        __weak IJSVGFilterGraph* weakGraph = graph;
        graph.paintProvider = ^CIImage*(BOOL stroke) {
            return [self paintImageForStroke:stroke
                                       graph:weakGraph];
        };
        graph.backgroundProvider = ^CIImage* {
            return self.usesBackground ? IJSVGFilterBackgroundImageFromContext(ctx, imageTransform) : CIImage.emptyImage;
        };

        CIImage* output = [graph imageByFilteringSource:source];
        if(batch.collecting) {
            if(cached != nil) {
                batch.invalid = YES;
                return;
            }

            IJSVGQuartzFilterBatchEntry* entry = [[IJSVGQuartzFilterBatchEntry alloc] init];
            entry.output = output;
            entry.workRect = workRect;
            entry.pixelSize = pixelSize;
            [batch.entries setObject:entry forKey:self];
            [batch.orderedEntries addObject:entry];
            return;
        }
        CGImageRef image = NULL;
        // Only renderer-owned bitmap storage can supply pixels for the Metal shortcut.
        if(IJSVGFilterSIMDUsesBackdropAddition(self.filter) &&
            supportsMetalKernels && IJSVGFilterRenderDepth == 1 &&
            ctx == IJSVGFilterBitmapContext) {
            image = IJSVGFilterNewSharedMetalImage(output, extent, colorSpace);
        }
        if(image == NULL) {
            image = [context createCGImage:output
                                  fromRect:extent
                                    format:kCIFormatRGBA8
                                colorSpace:colorSpace];
        }

        if(image != NULL) {
            [self drawFilteredImage:image
                            context:ctx
                             region:region
                           workRect:workRect];
            CGImageRelease(image);
        }
    }];

}

- (CGFloat)renderScaleForRect:(CGRect)workRect context:(CGContextRef)ctx
{
    // Local transforms extend the pixel mapping supplied by the renderer.
    // Nested bitmaps already contain their full pixel scale.
    CGAffineTransform transform = IJSVGFilterPixelTransform(ctx);
    CGFloat scale = MAX(hypot(transform.a, transform.b), hypot(transform.c, transform.d));

    // Only alpha amplifying matrices need extra coverage samples. Ordinary blurs
    // and shadows retain destination resolution instead of processing 4x the pixels.
    if(IJSVGFilterRenderDepth == 1 && self.requiresFilterSupersampling) {
        scale *= 2.f;

    }
    scale = MIN(scale, 4096.f / MAX(workRect.size.width, workRect.size.height));

    // Floating point primitive buffers need four times the source bitmap storage.
    scale = MIN(scale, sqrt(4194304.f / (workRect.size.width * workRect.size.height)));

    return scale;
}

- (BOOL)collectMetalBitmap:(CGContextRef)bitmap
                     graph:(IJSVGFilterGraph*)graph
                  workRect:(CGRect)workRect
{
    IJSVGQuartzFilterBatch* batch = IJSVGCurrentFilterBatch;
    CGSize pixelSize = graph.extent.size;
    IJSVGMetalShadowJob* shadow = batch.collecting ? [graph metalShadowJobForBitmap:bitmap] : nil;
    if(shadow != nil) {
        IJSVGQuartzFilterBatchEntry* entry = [[IJSVGQuartzFilterBatchEntry alloc] init];
        entry.metalShadow = shadow;
        entry.workRect = workRect;
        entry.pixelSize = pixelSize;
        [batch.entries setObject:entry forKey:self];
        [batch.orderedEntries addObject:entry];
        return YES;
    }
    IJSVGMetalBlurJob* blur = batch.collecting ? [graph metalBlurJobForBitmap:bitmap] : nil;
    if(blur != nil) {
        IJSVGQuartzFilterBatchEntry* entry = [[IJSVGQuartzFilterBatchEntry alloc] init];
        entry.metalBlur = blur;
        entry.workRect = workRect;
        entry.pixelSize = pixelSize;
        [batch.entries setObject:entry forKey:self];
        [batch.orderedEntries addObject:entry];
        return YES;
    }
    return NO;
}

- (BOOL)renderDirectImage:(CGImageRef)image
                  context:(CGContextRef)ctx
                   region:(CGRect)region
                 workRect:(CGRect)workRect
                pixelSize:(CGSize)pixelSize
{
    if(image == NULL) {
        return NO;
    }
    IJSVGQuartzFilterBatch* batch = IJSVGCurrentFilterBatch;
    IJSVGQuartzFilterBatchEntry* cached = [batch.entries objectForKey:self];
    if(batch.collecting) {
        if(cached != nil) {
            batch.invalid = YES;
            CGImageRelease(image);
        } else {
            IJSVGQuartzFilterBatchEntry* entry = [[IJSVGQuartzFilterBatchEntry alloc] init];
            entry.renderedImage = image;
            entry.workRect = workRect;
            entry.pixelSize = pixelSize;
            [batch.entries setObject:entry forKey:self];
            [batch.orderedEntries addObject:entry];
        }
    } else {
        [self drawFilteredImage:image
                        context:ctx
                         region:region
                       workRect:workRect];
        CGImageRelease(image);
    }
    return YES;
}

- (void)renderGraph:(IJSVGFilterGraph*)graph
            context:(CGContextRef)ctx
             region:(CGRect)region
           workRect:(CGRect)workRect
          pixelSize:(CGSize)pixelSize
              scale:(CGFloat)scale
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, pixelSize.width, pixelSize.height,
                                                8, 0, colorSpace, kCGImageAlphaPremultipliedLast);

    if(bitmap == NULL) {
        CGColorSpaceRelease(colorSpace);
        return;
    }

    CGContextScaleCTM(bitmap, scale, scale);
    CGContextTranslateCTM(bitmap, -workRect.origin.x, -workRect.origin.y);
    IJSVGPaint* sourcePaint = self.sourcePaint;
    CGContextTranslateCTM(bitmap, sourcePaint.frame.origin.x, sourcePaint.frame.origin.y);
    [IJSVGFilterPaint renderPaint:sourcePaint inBitmapContext:bitmap];
    graph.extent = CGRectMake(0, 0, pixelSize.width, pixelSize.height);
    graph.imageTransform = CGAffineTransformMake(scale, 0, 0, scale,
        -workRect.origin.x * scale, -workRect.origin.y * scale);
    CGImageRef composite = NULL;
    if(self.usesBackground && IJSVGFilterRenderDepth == 1 && !IJSVGCurrentFilterBatch.collecting &&
        ctx == IJSVGFilterBitmapContext &&
        (ctx != IJSVGFilterBackgroundContext || CGRectIsInfinite(IJSVGFilterBackgroundClip))) {
        composite = IJSVGFilterSIMDNewComposite(bitmap, ctx, graph, region);
    }
    if(composite != NULL) {
        [self drawFilteredImage:composite
                        context:ctx
                         region:region
                       workRect:workRect];
        CGImageRelease(composite);
        CGContextRelease(bitmap);
        CGColorSpaceRelease(colorSpace);
        return;
    }
    CGImageRef localImage = IJSVGFilterSIMDNewLocalFilter(bitmap, graph, region);
    if([self renderDirectImage:localImage
                       context:ctx
                        region:region
                      workRect:workRect
                     pixelSize:pixelSize]) {
        CGContextRelease(bitmap);
        CGColorSpaceRelease(colorSpace);
        return;
    }
    if([self collectMetalBitmap:bitmap
                          graph:graph
                       workRect:workRect]) {
        CGContextRelease(bitmap);
        CGColorSpaceRelease(colorSpace);
        return;
    }
    CGImageRef smallBlur = [graph newCGImageForSmallBlur:bitmap];
    if([self renderDirectImage:smallBlur
                       context:ctx
                        region:region
                      workRect:workRect
                     pixelSize:pixelSize]) {
        CGContextRelease(bitmap);
        CGColorSpaceRelease(colorSpace);
        return;
    }
    CGImageRef sourceImage = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);

    if(sourceImage == NULL) {
        CGColorSpaceRelease(colorSpace);
        return;
    }

    CIImage* source = [CIImage imageWithCGImage:sourceImage];
    CGImageRelease(sourceImage);
    [self renderSource:source
                 graph:graph
               context:ctx
            colorSpace:colorSpace
                region:region
              workRect:workRect];

    CGColorSpaceRelease(colorSpace);
}

- (void)drawFilterInContext:(CGContextRef)ctx
{
    IJSVGQuartzFilterBatch* batch = IJSVGCurrentFilterBatch;
    if(batch.collecting && (batch.invalid || IJSVGFilterRenderDepth != 1 ||
        ![batch.eligiblePaints containsObject:self])) {
        // Indirect SVGs/patterns may introduce filters absent from the paint scan.
        // Discard the collection pass and use the general renderer in that case.
        batch.invalid = YES;
        return;
    }
    IJSVGFilterGraph* graph = self.filterGraph;
    CGRect region = [graph regionForNode:_filter
                                   units:_filter.units
                           defaultRegion:CGRectZero];

    if(IJSVGFilterRectIsFinite(region) == NO || CGRectIsEmpty(region) == YES) {
        return;
    }

    IJSVGFilterPrimitive* primitive = self.filter.primitives.firstObject;
    if(!self.usesBackground && IJSVGFilterSIMDUsesBackdropAddition(self.filter) &&
        primitive.x == nil && primitive.y == nil && primitive.width == nil && primitive.height == nil) {
        // Adding transparent black leaves the source unchanged.
        CGContextSaveGState(ctx);
        CGContextClipToRect(ctx, region);
        CGContextTranslateCTM(ctx, self.sourcePaint.frame.origin.x, self.sourcePaint.frame.origin.y);
        [self.sourcePaint renderInContext:ctx];
        CGContextRestoreGState(ctx);
        return;
    }

    CGRect workRect = CGRectUnion(self.outerBoundingBox, region);
    if(IJSVGFilterRectIsFinite(workRect) == NO || CGRectIsEmpty(workRect) == YES) {
        return;
    }

    CGFloat scale = [self renderScaleForRect:workRect context:ctx];
    if(!isfinite(scale) || scale <= 0.f) {
        return;
    }
    CGAffineTransform grid = CGAffineTransformMakeScale(scale, scale);
    CGAffineTransform destination = CGContextGetCTM(ctx);
    if(ctx == IJSVGFilterBitmapContext &&
        isfinite(destination.tx) && isfinite(destination.ty) &&
        fabs(destination.tx) <= INT_MAX && fabs(destination.ty) <= INT_MAX &&
        (fabs(destination.tx - round(destination.tx)) > 1e-9 ||
            fabs(destination.ty - round(destination.ty)) > 1e-9) &&
        fabs(destination.b) <= 1e-9 && fabs(destination.c) <= 1e-9 &&
        fabs(fabs(destination.a) - scale) <= scale * 1e-9 &&
        fabs(fabs(destination.d) - scale) <= scale * 1e-9 &&
        [self.filter.inputNames containsObject:IJSVGStringBackgroundImage]) {
        // Include destination translation when snapping backdrop-dependent
        // surfaces. Snapping only in local coordinates introduces a fractional
        // resample and prevents direct CPU access to the background pixel grid.
        grid = destination;
    }
    workRect = CGRectApplyAffineTransform(workRect, grid);
    workRect = CGRectIntegral(workRect);
    workRect = CGRectApplyAffineTransform(workRect, CGAffineTransformInvert(grid));
    CGSize pixelSize = CGSizeMake(round(workRect.size.width * scale),
                                  round(workRect.size.height * scale));
    if(batch.preflighting) {
        [self preflightPixelSize:pixelSize batch:batch];
        return;
    }
    IJSVGQuartzFilterBatchEntry* cached = [batch.entries objectForKey:self];
    if(!batch.collecting && cached.renderedImage != NULL &&
        CGRectEqualToRect(cached.workRect, workRect) && CGSizeEqualToSize(cached.pixelSize, pixelSize)) {
        [self drawFilteredImage:cached.renderedImage
                        context:ctx
                         region:region
                       workRect:workRect];
        return;
    }
    if(!IJSVGFilterReservePixelSize(pixelSize, batch, cached)) {
        return;
    }
    _outputSignature = nil;
    if(self.canCacheOutput) {
        _outputSignature = @[
            [NSValue valueWithRect:workRect], [NSValue valueWithSize:pixelSize],
            [NSValue valueWithRect:region], [NSValue valueWithRect:self.boundingBox],
            [NSValue valueWithRect:self.viewPort], [NSValue valueWithRect:self.sourcePaint.frame],
            @(self.backingScaleFactor), @(self.renderQuality), @(IJSVGFilterRenderDepth == 1)
        ];
        IJSVGFilterCachedImage* output = [IJSVGFilterOutputCache() objectForKey:_outputCacheKey];
        if([output.signature isEqual:_outputSignature]) {
            if(batch.collecting) {
                IJSVGQuartzFilterBatchEntry* entry = [[IJSVGQuartzFilterBatchEntry alloc] init];
                entry.renderedImage = CGImageRetain(output.image);
                entry.workRect = workRect;
                entry.pixelSize = pixelSize;
                [batch.entries setObject:entry forKey:self];
                [batch.orderedEntries addObject:entry];
            } else {
                IJSVGFilterDrawFilteredImage(output.image, ctx, region, workRect);
            }
            return;
        }
    }
    [self renderGraph:graph
              context:ctx
               region:region
             workRect:workRect
            pixelSize:pixelSize
                scale:scale];
}

@end
