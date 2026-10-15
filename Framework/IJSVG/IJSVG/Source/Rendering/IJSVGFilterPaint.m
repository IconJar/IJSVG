//
//  IJSVGFilterPaint.m
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <CoreImage/CoreImage.h>
#import <IJSVG/IJSVGCircle.h>
#import <IJSVG/IJSVGEllipse.h>
#import <IJSVG/IJSVGLine.h>
#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGPolygon.h>
#import <IJSVG/IJSVGPolyline.h>
#import <IJSVG/IJSVGRadialGradient.h>
#import <IJSVG/IJSVGRect.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVGFilterGraph.h>
#import <IJSVGFilterPaint.h>
#import <IJSVGFilterSIMD.h>
#import <IJSVGPatternPaint.h>
#import <IJSVGQuartzRenderer.h>
#import <Metal/Metal.h>
#import <limits.h>

static _Thread_local CGContextRef IJSVGFilterBitmapContext;
static _Thread_local CGContextRef IJSVGFilterBackgroundContext;
static _Thread_local CGRect IJSVGFilterBackgroundClip;
static _Thread_local CGContextRef IJSVGFilterDestinationContext;
static _Thread_local CGAffineTransform IJSVGFilterDestinationTransform;

static CGAffineTransform IJSVGFilterPixelTransform(CGContextRef context)
{
    CGAffineTransform transform = CGContextGetCTM(context);
    if (context == IJSVGFilterDestinationContext) {
        transform = CGAffineTransformConcat(transform, IJSVGFilterDestinationTransform);
    }
    return transform;
}

static BOOL IJSVGFilterRectIsFinite(CGRect rect)
{
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) && isfinite(rect.size.width) && isfinite(rect.size.height);
}

// Align to 16 pixel tiles to keep multiresolution blur sampling stable as the
// destination clip moves. Output tiles use the top left corner of the original
// primitive bounds, since Core Image renders CGImage rows from top to bottom.
static CGRect IJSVGFilterAlignedRect(CGRect rect, CGPoint origin)
{
    const CGFloat tileSize = 16.f;
    CGAffineTransform grid = CGAffineTransformMake(1.f / tileSize, 0, 0, -1.f / tileSize, -origin.x / tileSize, origin.y / tileSize);
    rect = CGRectIntegral(CGRectApplyAffineTransform(rect, grid));
    return CGRectApplyAffineTransform(rect, CGAffineTransformInvert(grid));
}

// A shared Metal buffer lets Quartz consume completed filter pixels directly.
// Keep placement, clipping and source over in Quartz: replacing those
// operations with Core Image changes fractional coverage and accumulated 8 bit
// rounding.
static void IJSVGFilterReleaseMetalBuffer(void* info, const void* bytes, size_t length)
{
    CFRelease(info);
}

static CGImageRef IJSVGFilterNewSharedMetalImage(CIImage* output, CGRect extent, CGColorSpaceRef colorSpace)
{
    static id<MTLDevice> device;
    static id<MTLCommandQueue> queue;
    static CIContext* context;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        id<MTLDevice> candidate = MTLCreateSystemDefaultDevice();
        if (candidate.hasUnifiedMemory) {
            device = candidate;
            queue = [device newCommandQueue];
            if (queue != nil) {
                context = [CIContext contextWithMTLCommandQueue:queue options:@{kCIContextCacheIntermediates : @NO}];
            }
        }
    });
    if (context == nil || !IJSVGFilterRectIsFinite(extent) || !CGPointEqualToPoint(extent.origin, CGPointZero) || extent.size.width < 1 || extent.size.height < 1 || extent.size.width > 4096 || extent.size.height > 4096 || extent.size.width * extent.size.height > 4194304 || !CGRectEqualToRect(extent, CGRectIntegral(extent))) {
        return NULL;
    }
    NSUInteger width = extent.size.width, height = extent.size.height;
    NSUInteger alignment = [device minimumLinearTextureAlignmentForPixelFormat:MTLPixelFormatRGBA8Unorm];
    if (alignment == 0) {
        return NULL;
    }
    NSUInteger stride = (width * 4 + alignment - 1) / alignment * alignment;
    id<MTLBuffer> buffer = [device newBufferWithLength:stride * height options:MTLResourceStorageModeShared];
    if (buffer == nil) {
        return NULL;
    }
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:width height:height mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;
    descriptor.storageMode = MTLStorageModeShared;
    id<MTLTexture> texture = [buffer newTextureWithDescriptor:descriptor offset:0 bytesPerRow:stride];
    id<MTLCommandBuffer> commands = [queue commandBuffer];
    if (texture == nil || commands == nil) {
        return NULL;
    }
    CIRenderDestination* destination = [[CIRenderDestination alloc] initWithMTLTexture:texture commandBuffer:commands];
    destination.colorSpace = colorSpace;

    // CGImage providers use top to bottom rows. Materialize the filter at its
    // pixel grid, linear sampling here changes fractional filter region coverage.
    destination.flipped = YES;
    NSError* error = nil;
    CIRenderTask* task = [context startTaskToRender:[output imageBySamplingNearest] fromRect:extent toDestination:destination atPoint:CGPointZero error:&error];
    if (task == nil) {
        return NULL;
    }
    [commands commit];
    [commands waitUntilCompleted];
    if (commands.status != MTLCommandBufferStatusCompleted) {
        return NULL;
    }

    // The provider owns the buffer until Quartz releases the image, no pool may
    // reuse these bytes while an image or destination snapshot still retains
    // them.
    void* retainedBuffer = (void*)CFBridgingRetain(buffer);
    CGDataProviderRef provider = CGDataProviderCreateWithData(retainedBuffer, buffer.contents, buffer.length, IJSVGFilterReleaseMetalBuffer);
    if (provider == NULL) {
        CFRelease(retainedBuffer);
        return NULL;
    }
    CGImageRef image = CGImageCreate(width, height, 8, 32, stride, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big, provider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    return image;
}

// Nested filters already inherit the drawing transform of the supersampled
// bitmap.
static _Thread_local NSUInteger IJSVGFilterRenderDepth = 0;

// A cached ancestor already retains the completed pixels of its nested filters.
static _Thread_local BOOL IJSVGFilterHasCachingAncestor = NO;

@interface IJSVGQuartzFilterBatchEntry : NSObject
@property (nonatomic, strong) CIImage* output;
@property (nonatomic, strong) IJSVGMetalShadowJob* metalShadow;
@property (nonatomic, strong) IJSVGMetalBlurJob* metalBlur;
@property (nonatomic, assign) CGRect workRect;
@property (nonatomic, assign) CGSize pixelSize;
@property (nonatomic, assign) CGRect atlasRect;
@property (nonatomic, assign) CGImageRef renderedImage;
@property (nonatomic, assign) BOOL hasAtlasBacking;
@end

@implementation IJSVGQuartzFilterBatchEntry

- (void)dealloc
{
    if (_renderedImage != NULL) {
        CGImageRelease(_renderedImage);
    }
}

@end

@interface IJSVGQuartzFilterBatch : NSObject

@property (nonatomic, strong) NSMapTable<IJSVGFilterPaint*, IJSVGQuartzFilterBatchEntry*>* entries;
@property (nonatomic, strong) NSMutableArray<IJSVGQuartzFilterBatchEntry*>* orderedEntries;
@property (nonatomic, assign) BOOL collecting;
@property (nonatomic, assign) NSUInteger renderDepth;
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
    while (pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];

        // Nested source batches replay ancestor clips in Quartz. Keep the
        // top level eligibility rules and reject masks in either scope.
        if (paint.maskPaint != nil || (paint.clipPaints.count != 0 && (IJSVGFilterRenderDepth == 0 || [paint isKindOfClass:IJSVGFilterPaint.class]))) {
            return NO;
        }
        if ([paint isKindOfClass:IJSVGFilterPaint.class]) {
            IJSVGFilterPaint* filtered = (id)paint;
            if (filtered.usesBackground) {
                return NO;
            }
            for (IJSVGPaint* parent = paint.parentPaint; parent != nil && parent != root.parentPaint; parent = parent.parentPaint) {
                if ([parent isKindOfClass:IJSVGFilterPaint.class]) {
                    return NO;
                }
            }
            [eligiblePaints addObject:filtered];
            if (++filters > 128) {
                return NO;
            }
        }
        [pending addObjectsFromArray:paint.children ?: @[]];
    }
    return filters >= 3 && filters <= 128;
}

static BOOL IJSVGFilterRenderShadowEntries(NSArray<IJSVGQuartzFilterBatchEntry*>* entries)
{
    NSMutableArray<IJSVGMetalShadowJob*>* shadows = [[NSMutableArray alloc] init];
    for (IJSVGQuartzFilterBatchEntry* entry in entries) {
        if (entry.metalShadow != nil) {
            [shadows addObject:entry.metalShadow];
        }
    }
    if (![IJSVGMetalShadowJob renderJobs:shadows]) {
        return NO;
    }
    for (IJSVGQuartzFilterBatchEntry* entry in entries) {
        if (entry.metalShadow != nil) {
            entry.renderedImage = CGImageRetain(entry.metalShadow.renderedImage);
            entry.metalShadow = nil;
        }
    }
    return YES;
}

static BOOL IJSVGFilterRenderBlurEntries(NSArray<IJSVGQuartzFilterBatchEntry*>* entries)
{
    NSMutableArray<IJSVGMetalBlurJob*>* blurs = [[NSMutableArray alloc] init];
    for (IJSVGQuartzFilterBatchEntry* entry in entries) {
        if (entry.metalBlur != nil) {
            [blurs addObject:entry.metalBlur];
        }
    }
    if (![IJSVGMetalBlurRenderer renderJobs:blurs]) {
        return NO;
    }
    for (IJSVGQuartzFilterBatchEntry* entry in entries) {
        if (entry.metalBlur != nil) {
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
            rendered = [ciContext createCGImage:atlas fromRect:CGRectMake(0, 0, size.width, size.height) format:kCIFormatRGBA8 colorSpace:colorSpace];
        }];
    }];
    CGColorSpaceRelease(colorSpace);
    return rendered;
}

static CIImage* IJSVGFilterAtlasForEntries(NSArray<IJSVGQuartzFilterBatchEntry*>* entries, CGFloat atlasWidth, CGFloat* height)
{
    CGFloat x = 0, y = 0, rowHeight = 0;
    CIImage* atlas = CIImage.emptyImage;
    for (IJSVGQuartzFilterBatchEntry* entry in entries) {
        if (entry.output == nil) {
            continue;
        }
        CGSize size = entry.pixelSize;
        if (x + size.width > atlasWidth) {
            x = 0;
            y += rowHeight;
            rowHeight = 0;
        }
        entry.atlasRect = CGRectMake(x, y, size.width, size.height);
        CIImage* tile = [[entry.output imageByCroppingToRect:CGRectMake(0, 0, size.width, size.height)] imageByApplyingTransform:CGAffineTransformMakeTranslation(x, y)];
        atlas = [tile imageByCompositingOverImage:atlas];
        x += size.width;
        rowHeight = MAX(rowHeight, size.height);
    }
    CGFloat atlasHeight = y + rowHeight;
    *height = atlasHeight;
    return atlas;
}

static BOOL IJSVGFilterRenderCIEntries(NSArray<IJSVGQuartzFilterBatchEntry*>* entries)
{
    NSUInteger pixels = 0;
    NSMutableArray<IJSVGQuartzFilterBatchEntry*>* ciEntries = [[NSMutableArray alloc] init];
    for (IJSVGQuartzFilterBatchEntry* entry in entries) {
        if (entry.output != nil) {
            pixels += entry.pixelSize.width * entry.pixelSize.height;
            [ciEntries addObject:entry];
        }
    }
    if (pixels == 0) {
        return YES;
    }
    CGFloat atlasWidth = ciEntries.count == 1 ? ciEntries.firstObject.pixelSize.width : ceil(sqrt(pixels));
    for (IJSVGQuartzFilterBatchEntry* entry in entries) {
        if (entry.output != nil) {
            atlasWidth = MAX(atlasWidth, entry.pixelSize.width);
        }
    }
    CGFloat atlasHeight;
    CIImage* atlas = IJSVGFilterAtlasForEntries(entries, atlasWidth, &atlasHeight);
    if (atlasWidth * atlasHeight > 1048576 || atlasWidth * atlasHeight > pixels * 2) {
        // Packing padding can exceed the budget even when source pixels fit.
        // Split whole filter images so convolution never loses neighbouring pixels.
        if (ciEntries.count < 2) {
            return NO;
        }
        NSUInteger middle = ciEntries.count / 2;
        return IJSVGFilterRenderCIEntries([ciEntries subarrayWithRange:NSMakeRange(0, middle)]) && IJSVGFilterRenderCIEntries([ciEntries subarrayWithRange:NSMakeRange(middle, ciEntries.count - middle)]);
    }
    CGImageRef rendered = IJSVGFilterNewImageForAtlas(atlas, CGSizeMake(atlasWidth, atlasHeight));
    if (rendered == NULL) {
        return NO;
    }
    for (IJSVGQuartzFilterBatchEntry* entry in entries) {
        if (entry.renderedImage != NULL) {
            continue;
        }
        CGRect crop = entry.atlasRect;
        crop.origin.y = atlasHeight - CGRectGetMaxY(crop);
        entry.renderedImage = CGImageCreateWithImageInRect(rendered, crop);
        entry.hasAtlasBacking = YES;
        entry.output = nil;
        if (entry.renderedImage == NULL) {
            CGImageRelease(rendered);
            return NO;
        }
    }
    CGImageRelease(rendered);
    return YES;
}

static BOOL IJSVGFilterRenderCollectedEntries(NSArray<IJSVGQuartzFilterBatchEntry*>* entries)
{
    NSMutableArray<IJSVGQuartzFilterBatchEntry*>* metalEntries = [[NSMutableArray alloc] init];
    NSMutableArray<IJSVGQuartzFilterBatchEntry*>* ciEntries = [[NSMutableArray alloc] init];
    for (IJSVGQuartzFilterBatchEntry* entry in entries) {
        if (entry.metalShadow != nil || entry.metalBlur != nil) {
            [metalEntries addObject:entry];
        } else if (entry.output != nil) {
            [ciEntries addObject:entry];
        }
    }
    if (ciEntries.count == 0 || metalEntries.count == 0) {
        return IJSVGFilterRenderShadowEntries(metalEntries) && IJSVGFilterRenderBlurEntries(metalEntries) && IJSVGFilterRenderCIEntries(ciEntries);
    }

    // Jobs own their input pixels and the two arrays contain disjoint entries.
    // Submit the direct Metal work while Core Image prepares/renders its graph,
    // then join before Quartz replays any image. Keep shadow and blur leases
    // sequential so their scratch buffers do not overlap.
    dispatch_group_t group = dispatch_group_create();
    __block BOOL metalSucceeded = NO;
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            metalSucceeded = IJSVGFilterRenderShadowEntries(metalEntries) && IJSVGFilterRenderBlurEntries(metalEntries);
        }
    });
    BOOL ciSucceeded = NO;
    @try {
        ciSucceeded = IJSVGFilterRenderCIEntries(ciEntries);
    } @finally {
        // A failed Core Image render must not leave work running after the
        // synchronous draw releases its batch and source images.
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    }
    return metalSucceeded && ciSucceeded;
}

static CGContextRef IJSVGFilterNewCollectionContext(CGContextRef context)
{
    // Display and PDF contexts cannot be queried with bitmap context APIs.
    // Use the pixel mapping supplied by the renderer for the collection bitmap.
    CGAffineTransform transform = IJSVGFilterPixelTransform(context);
    CGRect deviceBounds = CGRectApplyAffineTransform(CGContextGetClipBoundingBox(context), transform);
    if (!IJSVGFilterRectIsFinite(deviceBounds) || CGRectIsEmpty(deviceBounds)) {
        return NULL;
    }
    deviceBounds = CGRectIntegral(deviceBounds);
    if (deviceBounds.size.width > 2048 || deviceBounds.size.height > 2048 || deviceBounds.size.width * deviceBounds.size.height > 4194304) {
        return NULL;
    }
    CGColorSpaceRef scratchColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef scratch = CGBitmapContextCreate(NULL, deviceBounds.size.width, deviceBounds.size.height, 8, 0, scratchColorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(scratchColorSpace);
    if (scratch == NULL) {
        return NULL;
    }
    CGContextTranslateCTM(scratch, -deviceBounds.origin.x, -deviceBounds.origin.y);
    CGContextConcatCTM(scratch, transform);
    return scratch;
}

static NSSet<IJSVGPaint*>* IJSVGFilterCollectionPaintsForFilters(NSSet<IJSVGFilterPaint*>* eligiblePaints)
{
    NSMutableSet<IJSVGPaint*>* collectionPaints = [[NSMutableSet alloc] init];
    for (IJSVGPaint* filtered in eligiblePaints) {
        for (IJSVGPaint* paint = filtered; paint != nil; paint = paint.parentPaint) {
            if ([collectionPaints containsObject:paint]) {
                break;
            }
            [collectionPaints addObject:paint];
        }
    }
    return collectionPaints;
}

static CIImage* IJSVGFilterBackgroundImageFromContext(CGContextRef ctx, CGAffineTransform imageTransform)
{
    // Bitmap destinations can supply their already painted backdrop.
    // Nonbitmap contexts have no readable pixel backing.
    if (ctx != IJSVGFilterBitmapContext) {
        return CIImage.emptyImage;
    }
    CGImageRef background = CGBitmapContextCreateImage(ctx);
    if (background == NULL) {
        return CIImage.emptyImage;
    }
    CIImage* image = [CIImage imageWithCGImage:background];
    CGImageRelease(background);
    if (ctx == IJSVGFilterBackgroundContext && !CGRectIsInfinite(IJSVGFilterBackgroundClip)) {
        image = [image imageByCroppingToRect:IJSVGFilterBackgroundClip];
    }
    CGAffineTransform mapping = CGAffineTransformConcat(CGAffineTransformInvert(CGContextGetCTM(ctx)), imageTransform);
    return [image imageByApplyingTransform:mapping];
}

static BOOL IJSVGFilterReservePixelSize(CGSize pixelSize, IJSVGQuartzFilterBatch* batch, IJSVGQuartzFilterBatchEntry* cached)
{
    if (batch.collecting) {
        NSUInteger pixels = pixelSize.width * pixelSize.height;
        if (cached != nil || pixelSize.width > 2048 || pixelSize.height > 2048 || pixels > 1048576 || batch.totalPixels + pixels > 8388608) {
            batch.invalid = YES;
            return NO;
        }

        // Flush complete jobs at one megapixel. Finished RGBA8 images remain
        // available for ordered replay, while source and GPU scratch storage is
        // reused.
        if (batch.retainedPixels + pixels > 1048576) {
            if (!IJSVGFilterRenderCollectedEntries(batch.orderedEntries)) {
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

static void IJSVGFilterDrawFilteredImage(CGImageRef image, CGContextRef ctx, CGRect region, CGRect workRect)
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
@property (nonatomic, copy) NSArray<id>* signature;
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

/// Restricts snapshots to detached vector data without inherited effects.
static BOOL IJSVGFilterImageNodeIsIndependent(IJSVGNode* node)
{
    if (node == nil || node.parentNode != nil || node.styleParent != nil) {
        return NO;
    }
    if (![node isKindOfClass:IJSVGGraphicsNode.class]) {
        return YES;
    }
    IJSVGGraphicsNode* graphics = (IJSVGGraphicsNode*)node;
    return graphics.mask == nil && graphics.clipPath == nil && graphics.filters.count == 0 && CGRectIsNull(graphics.backgroundRect);
}

/// Copies mutable base drawing values that ordinary node copies share.
static void IJSVGFilterDetachImageValues(IJSVGNode* destination, IJSVGNode* original)
{
    destination.parentNode = nil;
    destination.styleParent = nil;
    if (![original isKindOfClass:IJSVGGraphicsNode.class] || ![destination isKindOfClass:IJSVGGraphicsNode.class]) {
        return;
    }
    IJSVGGraphicsNode* copy = (IJSVGGraphicsNode*)destination;
    IJSVGGraphicsNode* source = (IJSVGGraphicsNode*)original;
    copy.x = source.x.copy;
    copy.y = source.y.copy;
    copy.width = source.width.copy;
    copy.height = source.height.copy;
    copy.opacity = source.opacity.copy;
    copy.fillOpacity = source.fillOpacity.copy;
    copy.strokeOpacity = source.strokeOpacity.copy;
    copy.strokeWidth = source.strokeWidth.copy;
    copy.strokeMiterLimit = source.strokeMiterLimit.copy;
    copy.strokeDashOffset = source.strokeDashOffset.copy;
    copy.transforms = [[NSArray alloc] initWithArray:source.transforms ?: @[] copyItems:YES];
}

/// Freezes plain colours and built in gradients without retaining live paint
/// data.
static IJSVGNode* IJSVGFilterSnapshotImagePaint(IJSVGNode* source)
{
    if (!IJSVGFilterImageNodeIsIndependent(source)) {
        return nil;
    }
    if ([source isMemberOfClass:IJSVGColorNode.class]) {
        IJSVGColorNode* copy = source.copy;
        IJSVGFilterDetachImageValues(copy, source);
        return copy;
    }
    if (![source isMemberOfClass:IJSVGLinearGradient.class] && ![source isMemberOfClass:IJSVGRadialGradient.class]) {
        return nil;
    }
    if (((IJSVGGradient*)source).viewBox != nil) {
        return nil;
    }

    // Only resolved gradient values are used for drawing this private snapshot.
    IJSVGGradient* copy = [[source.class alloc] init];
    [copy applyPropertiesFromNode:(IJSVGGradient*)source];
    if ([source isMemberOfClass:IJSVGRadialGradient.class]) {
        IJSVGRadialGradient* radialSource = (IJSVGRadialGradient*)source;
        IJSVGRadialGradient* radialCopy = (IJSVGRadialGradient*)copy;
        radialCopy.cx = radialSource.cx.copy;
        radialCopy.cy = radialSource.cy.copy;
        radialCopy.fx = radialSource.fx.copy;
        radialCopy.fy = radialSource.fy.copy;
        radialCopy.fr = radialSource.fr.copy;
        radialCopy.r = radialSource.r.copy;
    }
    IJSVGFilterDetachImageValues(copy, source);
    copy.colors = ((IJSVGGradient*)source).colors.copy;
    return copy;
}

static BOOL IJSVGFilterImageIsBuiltinPath(IJSVGNode* node)
{
    Class type = node.class;
    return type == IJSVGPath.class || type == IJSVGRect.class || type == IJSVGCircle.class || type == IJSVGEllipse.class || type == IJSVGLine.class || type == IJSVGPolygon.class || type == IJSVGPolyline.class;
}

/// Snapshots a plain vector image while leaving unsupported inputs on the live
/// path.
static IJSVGNode* IJSVGFilterSnapshotImage(IJSVGFilterPrimitive* primitive)
{
    IJSVGPath* source = (IJSVGPath*)primitive.imageNode;
    if (primitive.image != nil || primitive.parameters[@"href"].length != 0 || primitive.parameters[@"xlink:href"].length != 0 || !IJSVGFilterImageIsBuiltinPath(source) || !IJSVGFilterImageNodeIsIndependent(source)) {
        return nil;
    }
    IJSVGNode* fill = IJSVGFilterSnapshotImagePaint(source.fill);
    IJSVGNode* stroke = IJSVGFilterSnapshotImagePaint(source.stroke);
    if ((source.fill != nil && fill == nil) || (source.stroke != nil && stroke == nil)) {
        return nil;
    }
    IJSVGPath* copy = source.copy;
    IJSVGFilterDetachImageValues(copy, source);
    copy.fill = fill;
    copy.stroke = stroke;
    return copy;
}

@interface IJSVGFilterPaint () {
    NSObject* _outputCacheKey;
    NSArray<id>* _outputSignature;
    BOOL _checkedOutputCaching;
    BOOL _canCacheOutput;
    IJSVGFilter* _imageSnapshotFilter;
    IJSVGFilterMetadata* _filterMetadata;
    BOOL _checkedBackground;
    BOOL _cachedUsesBackground;
}

@end

@implementation IJSVGFilterPaint

@synthesize cachesRenderedOutput = _cachesRenderedOutput;

+ (void)drawInContext:(CGContextRef)context pixelTransform:(CGAffineTransform)pixelTransform drawingBlock:(void (^)(void))drawingBlock
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

+ (void)drawBackgroundForPaint:(IJSVGPaint*)paint context:(CGContextRef)context drawingBlock:(void (^)(CGContextRef))drawingBlock
{
    CGAffineTransform transform = CGContextGetCTM(context);
    CGRect bounds = CGRectIntegral(CGRectApplyAffineTransform(CGContextGetClipBoundingBox(context), transform));
    if (!IJSVGFilterRectIsFinite(bounds) || CGRectIsEmpty(bounds)) {
        return;
    }
    CGFloat scale = MIN(1.f, MIN(4096.f / bounds.size.width, 4096.f / bounds.size.height));
    size_t width = MAX(1, ceil(bounds.size.width * scale));
    size_t height = MAX(1, ceil(bounds.size.height * scale));
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (bitmap == NULL) {
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
    IJSVGFilterBackgroundClip = CGRectIsInfinite(clip) ? clip : CGRectApplyAffineTransform(clip, CGContextGetCTM(bitmap));
    @try {
        drawingBlock(bitmap);
    } @finally {
        IJSVGFilterBitmapContext = previousBitmap;
        IJSVGFilterBackgroundContext = previousBackground;
        IJSVGFilterBackgroundClip = previousClip;
    }
    CGImageRef image = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    if (image != NULL) {
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

+ (void)renderPaint:(IJSVGPaint*)paint inBitmapContext:(CGContextRef)context
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
    if (_outputCacheKey != nil) {
        [IJSVGFilterOutputCache() removeObjectForKey:_outputCacheKey];
    }
}

- (IJSVGFilterMetadata*)filterMetadata
{
    if (!self.cachesRenderedOutput) {
        return [[IJSVGFilterMetadata alloc] initWithFilter:self.filter];
    }
    if (_filterMetadata.filter != self.filter) {
        _filterMetadata = [[IJSVGFilterMetadata alloc] initWithFilter:self.filter];
    }
    return _filterMetadata;
}

- (BOOL)usesBackground
{
    if (!self.cachesRenderedOutput) {
        return [self resolveUsesBackground];
    }
    if (!_checkedBackground) {
        _cachedUsesBackground = [self resolveUsesBackground];
        _checkedBackground = YES;
    }
    return _cachedUsesBackground;
}

- (void)setSourceNode:(IJSVGGraphicsNode*)sourceNode
{
    [super setSourceNode:sourceNode];
    _checkedBackground = NO;
}

- (void)setFilter:(IJSVGFilter*)filter
{
    _filter = filter;
    _filterMetadata = nil;
    _checkedBackground = NO;
}

- (BOOL)resolveUsesBackground
{
    IJSVGFilterInputs inputs = self.filterMetadata.inputs;
    if ((inputs & (IJSVGFilterInputBackgroundImage | IJSVGFilterInputBackgroundAlpha)) == 0) {
        return NO;
    }

    // A new canvas on the filtered container has no earlier contents.
    if (!CGRectIsNull(self.sourceNode.backgroundRect)) {
        return NO;
    }
    for (IJSVGNode* node = self.sourceNode.parentNode; node != nil; node = node.parentNode) {
        if ([node isKindOfClass:IJSVGGraphicsNode.class] && !CGRectIsNull(((IJSVGGraphicsNode*)node).backgroundRect)) {
            return YES;
        }
    }
    return NO;
}

/// Freezes eligible image inputs only for renderer owned immutable paint
/// graphs.
- (void)setCachesRenderedOutput:(BOOL)cachesRenderedOutput
{
    if (_cachesRenderedOutput == cachesRenderedOutput) {
        return;
    }
    _cachesRenderedOutput = cachesRenderedOutput;
    _checkedBackground = NO;
    _filterMetadata = nil;
    if (_outputCacheKey != nil) {
        [IJSVGFilterOutputCache() removeObjectForKey:_outputCacheKey];
    }
    _outputCacheKey = nil;
    _outputSignature = nil;
    _checkedOutputCaching = NO;
    _canCacheOutput = NO;
    _imageSnapshotFilter = nil;
    if (cachesRenderedOutput) {
        [self prepareImageSnapshots];
    }
}

/// Caches resolved output only when its inputs are independent of later draws.
- (BOOL)canCacheOutput
{
    if (!self.cachesRenderedOutput) {
        return NO;
    }
    if (_checkedOutputCaching) {
        return _canCacheOutput;
    }
    _checkedOutputCaching = YES;

    // Backdrop inputs depend on the destination, including those inside masks,
    // patterns and nested filters. feImage can reference another SVG subtree.
    NSMutableArray<IJSVGPaint*>* pending = [NSMutableArray arrayWithObject:self];
    NSMutableSet<IJSVGPaint*>* visited = [[NSMutableSet alloc] init];
    while (pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        if ([visited containsObject:paint]) {
            continue;
        }
        [visited addObject:paint];
        if ([paint isKindOfClass:IJSVGFilterPaint.class]) {
            IJSVGFilter* filter = ((IJSVGFilterPaint*)paint).filter;
            if (((IJSVGFilterPaint*)paint).usesBackground) {
                return NO;
            }
            for (IJSVGFilterPrimitive* primitive in filter.primitives) {
                if (primitive.type == IJSVGNodeTypeFilterImage && ((IJSVGFilterPaint*)paint)->_imageSnapshotFilter == nil) {
                    return NO;
                }
            }
        }
        for (IJSVGPaint* child in paint.children) {
            [pending addObject:child];
        }
        for (IJSVGPaint* clip in paint.clipPaints) {
            [pending addObject:clip];
        }
        if (paint.maskPaint != nil) {
            [pending addObject:paint.maskPaint];
        }
        if ([paint isKindOfClass:IJSVGPatternPaint.class]) {
            IJSVGPaint* pattern = ((IJSVGPatternPaint*)paint).pattern;
            if (pattern != nil) {
                [pending addObject:pattern];
            }
        }
    }
    _outputCacheKey = [[NSObject alloc] init];
    return _canCacheOutput = YES;
}

- (void)drawFilteredImage:(CGImageRef)image context:(CGContextRef)ctx region:(CGRect)region workRect:(CGRect)workRect independentPixels:(BOOL)independentPixels
{
    if (_outputSignature != nil) {
        IJSVGFilterCachedImage* cached = [IJSVGFilterOutputCache() objectForKey:_outputCacheKey];
        if (![cached.signature isEqual:_outputSignature]) {
            NSUInteger width = CGImageGetWidth(image), height = CGImageGetHeight(image);

            // An atlas crop can retain a much larger backing image. Materialize
            // independent RGBA8 pixels so cache cost reflects retained storage.
            if (width != 0 && height != 0 && width <= 4194304 / height) {
                IJSVGQuartzFilterBatchEntry* entry = [IJSVGCurrentFilterBatch.entries objectForKey:self];
                CGImageRef copy = NULL;

                // Shared Metal output and direct batch jobs own independent pixels.
                // Retaining them avoids another allocation and Quartz image draw
                // during the first render. Atlas crops still need detaching.
                if (independentPixels || (entry.renderedImage == image && !entry.hasAtlasBacking)) {
                    copy = CGImageRetain(image);
                } else {
                    CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, width * 4, CGImageGetColorSpace(image), kCGImageAlphaPremultipliedLast);
                    if (bitmap != NULL) {
                        CGContextSetBlendMode(bitmap, kCGBlendModeCopy);
                        CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), image);
                        copy = CGBitmapContextCreateImage(bitmap);
                        CGContextRelease(bitmap);
                    }
                }
                if (copy != NULL) {
                    cached = [[IJSVGFilterCachedImage alloc] init];
                    cached.image = copy;
                    cached.signature = _outputSignature;
                    [IJSVGFilterOutputCache() setObject:cached forKey:_outputCacheKey cost:CGImageGetBytesPerRow(copy) * height];
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
    return !batch.collecting || IJSVGFilterRenderDepth > batch.renderDepth || [batch.collectionPaints containsObject:paint];
}

+ (NSSet<IJSVGFilterPaint*>*)batchableFiltersForPaint:(IJSVGPaint*)root
{
    NSMutableSet<IJSVGFilterPaint*>* paints = [[NSMutableSet alloc] init];
    return IJSVGQuartzFilterBatchEligible(root, paints) ? paints.copy : nil;
}

+ (BOOL)renderBatchedPaints:(NSSet<IJSVGFilterPaint*>*)eligiblePaints inContext:(CGContextRef)context drawingBlock:(void (^)(CGContextRef))drawingBlock
{
    if (context == NULL || IJSVGCurrentFilterBatch != nil || eligiblePaints.count == 0) {
        return NO;
    }
    CGContextRef scratch = IJSVGFilterNewCollectionContext(context);
    if (scratch == NULL) {
        return NO;
    }
    IJSVGQuartzFilterBatch* batch __attribute__((objc_precise_lifetime)) = [[IJSVGQuartzFilterBatch alloc] init];
    batch.eligiblePaints = eligiblePaints;
    batch.renderDepth = IJSVGFilterRenderDepth;
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
        if (batch.invalid || batch.preflightPaints.count < 3) {
            return NO;
        }
        batch.preflighting = NO;
        batch.preflightPaints = nil;
        batch.totalPixels = 0;

        // Visit only filter branches and their ancestors during collection.
        // Unfiltered artwork is painted once, during the final replay.
        drawingBlock(scratch);
        if (batch.invalid || batch.orderedEntries.count < 3) {
            return NO;
        }
        if (!IJSVGFilterRenderCollectedEntries(batch.orderedEntries)) {
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

/// Builds private image snapshots once and preserves the original filter for
/// export.
- (void)prepareImageSnapshots
{
    NSArray<IJSVGFilterPrimitive*>* primitives = self.filterMetadata.primitives;
    NSMutableDictionary<NSNumber*, IJSVGNode*>* snapshots = nil;
    for (NSUInteger index = 0; index < primitives.count; index++) {
        IJSVGFilterPrimitive* primitive = primitives[index];
        if (primitive.type != IJSVGNodeTypeFilterImage) {
            continue;
        }
        IJSVGNode* snapshot = IJSVGFilterSnapshotImage(primitive);
        if (snapshot == nil) {
            return;
        }
        if (snapshots == nil) {
            snapshots = [[NSMutableDictionary alloc] init];
        }
        snapshots[@(index)] = snapshot;
    }
    if (snapshots.count == 0) {
        return;
    }
    _imageSnapshotFilter = self.filter.copy;
    NSArray<IJSVGFilterPrimitive*>* copies = _imageSnapshotFilter.primitives;
    for (NSNumber* index in snapshots) {
        copies[index.unsignedIntegerValue].imageNode = snapshots[index];
    }
}

- (instancetype)initWithSourcePaint:(IJSVGPaint*)paint filter:(IJSVGFilter*)filter viewPort:(CGRect)viewPort
{
    if ((self = [super init]) != nil) {
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

- (CIImage*)paintImageForStroke:(BOOL)stroke graph:(IJSVGFilterGraph*)graph
{
    IJSVGNode* paint = stroke ? self.sourceNode.stroke : self.sourceNode.fill;
    if (paint == nil) {
        return CIImage.emptyImage;
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, graph.extent.size.width, graph.extent.size.height, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (bitmap == NULL) {
        return CIImage.emptyImage;
    }
    CGContextConcatCTM(bitmap, graph.imageTransform);
    CGRect region = CGRectApplyAffineTransform(graph.extent, CGAffineTransformInvert(graph.imageTransform));
    IJSVGQuartzRenderer* tree = [[IJSVGQuartzRenderer alloc] init];
    if (self.renderingOptions != nil) {
        tree.renderingOptions = self.renderingOptions;
    }
    [tree drawPaint:paint boundingBox:self.boundingBox viewPort:self.viewPort region:region inContext:bitmap];
    CGImageRef result = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    CIImage* image = result != NULL ? [CIImage imageWithCGImage:result] : CIImage.emptyImage;
    if (result != NULL) {
        CGImageRelease(result);
    }
    return image;
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    if (self.opacity != 1.f) {
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
    if (self.filter.requiresSupersampling) {
        return YES;
    }

    // An outer filter must supply enough source resolution for nested hard alpha
    // effects.
    NSMutableArray<IJSVGPaint*>* pending = self.children.mutableCopy;
    while (pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        if ([paint isKindOfClass:IJSVGFilterPaint.class]) {
            if ([(IJSVGFilterPaint*)paint requiresFilterSupersampling]) {
                return YES;
            }
        } else if (paint.children.count != 0) {
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

/// Evaluates owned image snapshots when every image dependency can be frozen.
- (IJSVGFilterGraph*)filterGraph
{
    IJSVGFilterGraph* graph = [[IJSVGFilterGraph alloc] init];
    graph.filter = _imageSnapshotFilter ?: self.filter;
    if (self.cachesRenderedOutput && _imageSnapshotFilter == nil) {
        graph.resolvedMetadata = self.filterMetadata;
    }
    graph.renderingOptions = self.renderingOptions;

    // Repeated shadow readbacks can accumulate rounding differences in nested
    // filters.
    graph.hasNestedFilters = IJSVGFilterRenderDepth > 1;
    if (!graph.hasNestedFilters && self.filterMetadata.primitives.count == 1 && self.filterMetadata.primitives.firstObject.type == IJSVGNodeTypeFilterDropShadow) {
        NSMutableArray<IJSVGPaint*>* pending = self.children.mutableCopy;
        while (pending.count != 0) {
            IJSVGPaint* paint = pending.lastObject;
            [pending removeLastObject];
            if ([paint isKindOfClass:IJSVGFilterPaint.class]) {
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

- (void)preflightPixelSize:(CGSize)pixelSize batch:(IJSVGQuartzFilterBatch*)batch
{
    NSUInteger pixels = pixelSize.width * pixelSize.height;
    if ([batch.preflightPaints containsObject:self] || pixelSize.width > 2048 || pixelSize.height > 2048 || pixels > 1048576 || batch.totalPixels + pixels > 8388608) {
        batch.invalid = YES;
        return;
    }
    batch.largestSourcePixels = MAX(batch.largestSourcePixels, pixels);

    // Account for RGBA8 replay images with up to 2x atlas packing padding,
    // the current source bitmap, pending RGBA8 sources, and a full
    // one megapixel Metal lease (44 bytes/pixel), plus parameter headroom.
    // This is a working set estimate, not a process memory limit: CPU filter
    // intermediates and private caches in Core Image can add further storage.
    NSUInteger estimatedBytes = batch.scratchBytes + (batch.totalPixels + pixels) * 8 + batch.largestSourcePixels * 4 + 1048576 * (44 + 4) + 65536;
    if (estimatedBytes > 128 * 1024 * 1024) {
        batch.invalid = YES;
        return;
    }
    [batch.preflightPaints addObject:self];
    batch.totalPixels += pixels;
    return;
}

// Trim only transient output. Cached images and atlas entries must retain
// their complete coverage for later draws with a different destination clip.
- (CGRect)requestedOutputExtentForGraph:(IJSVGFilterGraph*)graph context:(CGContextRef)ctx
{
    CGRect extent = graph.extent;
    if (_outputSignature != nil || IJSVGCurrentFilterBatch.collecting || IJSVGCurrentFilterBatch.preflighting) {
        return extent;
    }
    CGRect clip = CGContextGetClipBoundingBox(ctx);
    if (!IJSVGFilterRectIsFinite(clip)) {
        return extent;
    }
    CGAffineTransform pixels = IJSVGFilterPixelTransform(ctx);
    CGFloat determinant = pixels.a * pixels.d - pixels.b * pixels.c;
    if (!isfinite(determinant) || determinant == 0.f) {
        return extent;
    }

    // Allow two destination pixels for Quartz image interpolation, then
    // snap outwards on the original filter grid. Source and blur halos stay
    // intact.
    CGAffineTransform inverse = CGAffineTransformInvert(pixels);
    CGFloat paddingX = 2.f * (fabs(inverse.a) + fabs(inverse.c));
    CGFloat paddingY = 2.f * (fabs(inverse.b) + fabs(inverse.d));
    clip = CGRectInset(clip, -paddingX, -paddingY);
    CGRect requested = CGRectApplyAffineTransform(clip, graph.imageTransform);
    if (!IJSVGFilterRectIsFinite(requested)) {
        return extent;
    }
    return CGRectIntersection(extent, CGRectIntegral(requested));
}

// Walk backwards conservatively: retain both the original and shifted region
// for named branches, and accumulate every blur halo. Unknown sampling falls
// back.
- (CGRect)requiredSourceExtentForGraph:(IJSVGFilterGraph*)graph context:(CGContextRef)ctx
{
    CGRect extent = graph.extent;
    CGRect required = [self requestedOutputExtentForGraph:graph context:ctx];
    if (CGRectEqualToRect(required, extent) || !self.canCacheOutput) {
        return extent;
    }
    BOOL hasBlur = NO;
    CGFloat scale = graph.imageTransform.a;
    CGSize units = self.filter.contentUnits == IJSVGUnitObjectBoundingBox ? CGSizeMake(self.boundingBox.size.width * scale, self.boundingBox.size.height * scale) : CGSizeMake(scale, scale);
    for (IJSVGFilterPrimitive* primitive in self.filterMetadata.primitives.reverseObjectEnumerator) {
        switch (primitive.type) {
            case IJSVGNodeTypeFilterGaussianBlur:
            case IJSVGNodeTypeFilterDropShadow: {
                if (primitive.edgeMode != IJSVGFilterEdgeModeNone) {
                    return extent;
                }
                CGSize deviation = [primitive pairForParameter:IJSVGAttributeStdDeviation defaultValue:CGSizeZero];
                if (deviation.width < 0.f || deviation.height < 0.f) {
                    return extent;
                }
                hasBlur |= deviation.width > 0.f || deviation.height > 0.f;
                required = CGRectInset(required, -ceil(4.f * deviation.width * units.width) - 2.f, -ceil(4.f * deviation.height * units.height) - 2.f);
                if (primitive.type != IJSVGNodeTypeFilterDropShadow) {
                    break;
                }

                // A drop shadow also samples the original, untranslated source.
                __attribute__((fallthrough));
            }
            case IJSVGNodeTypeFilterOffset: {
                CGFloat dx = [primitive numberForParameter:IJSVGAttributeDX defaultValue:0.f] * units.width;
                CGFloat dy = [primitive numberForParameter:IJSVGAttributeDY defaultValue:0.f] * units.height;
                required = CGRectUnion(required, CGRectOffset(required, -dx, -dy));
                break;
            }
            case IJSVGNodeTypeFilterColorMatrix:
            case IJSVGNodeTypeFilterComponentTransfer:
            case IJSVGNodeTypeFilterComposite:
            case IJSVGNodeTypeFilterBlend:
            case IJSVGNodeTypeFilterMerge:
            case IJSVGNodeTypeFilterFlood:
                break;
            default:
                return extent;
        }
        if (!IJSVGFilterRectIsFinite(required)) {
            return extent;
        }
    }
    if (!hasBlur) {
        // Cheap pointwise effects retain their raster bounds. Moving them can
        // change nested Quartz edge coverage without saving blur work.
        return extent;
    }
    return CGRectIntersection(extent, CGRectIntegral(required));
}

- (void)renderSource:(CIImage*)source graph:(IJSVGFilterGraph*)graph context:(CGContextRef)ctx colorSpace:(CGColorSpaceRef)colorSpace region:(CGRect)region workRect:(CGRect)workRect
{
    IJSVGQuartzFilterBatch* batch = IJSVGCurrentFilterBatch;
    IJSVGQuartzFilterBatchEntry* cached = [batch.entries objectForKey:self];
    CGRect extent = graph.extent;
    CGRect requestedExtent = [self requestedOutputExtentForGraph:graph context:ctx];
    if (CGRectIsEmpty(requestedExtent) || CGRectIsNull(requestedExtent)) {
        return;
    }
    CGSize pixelSize = extent.size;

    // Keep filter coordinates aligned with the source bitmap. The calling context
    // drawing transform handles flipped views and image exports.
    CGAffineTransform imageTransform = graph.imageTransform;
    __block BOOL hasContext = NO;
    [IJSVGThreadManager performBlockWithCIContext:^(CIContext* context, BOOL supportsMetalKernels) {
        hasContext = YES;
        graph.context = context;
        graph.supportsMetalKernels = supportsMetalKernels;
        graph.extent = extent;
        graph.imageTransform = imageTransform;
        __weak IJSVGFilterGraph* weakGraph = graph;
        graph.paintProvider = ^CIImage*(BOOL stroke) {
            return [self paintImageForStroke:stroke graph:weakGraph];
        };
        graph.backgroundProvider = ^CIImage* {
            return self.usesBackground ? IJSVGFilterBackgroundImageFromContext(ctx, imageTransform) : CIImage.emptyImage;
        };

        CIImage* output = [graph imageByFilteringSource:source];
        if (batch.collecting) {
            if (cached != nil) {
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
        CGRect outputExtent = extent;
        if (!CGRectEqualToRect(requestedExtent, extent) && IJSVGFilterRectIsFinite(output.extent)) {
            CGRect anchor = CGRectIntegral(output.extent);
            CGPoint origin = CGPointMake(CGRectGetMinX(anchor), CGRectGetMaxY(anchor));
            outputExtent = CGRectIntersection(extent, IJSVGFilterAlignedRect(requestedExtent, origin));
        }
        CGImageRef image = NULL;

        // Shared output storage lets Quartz read completed Metal pixels directly.
        if (supportsMetalKernels) {
            image = IJSVGFilterNewSharedMetalImage(output, outputExtent, colorSpace);
        }
        BOOL independentPixels = image != NULL;
        if (image == NULL) {
            image = [context createCGImage:output fromRect:outputExtent format:kCIFormatRGBA8 colorSpace:colorSpace];
        }

        if (image != NULL) {
            if (CGRectEqualToRect(outputExtent, extent)) {
                [self drawFilteredImage:image context:ctx region:region workRect:workRect independentPixels:independentPixels];
            } else {
                CGRect outputRect = CGRectApplyAffineTransform(outputExtent, CGAffineTransformInvert(imageTransform));
                IJSVGFilterDrawFilteredImage(image, ctx, region, outputRect);
            }
            CGImageRelease(image);
        }
    }];
    if (!hasContext) {
        // Preserve the previous unfiltered fallback on systems without Metal,
        // while allowing CPU filters to execute without acquiring a CI context.
        if (batch.collecting) {
            batch.invalid = YES;
            return;
        }
        CGContextSaveGState(ctx);
        @try {
            CGContextTranslateCTM(ctx, self.sourcePaint.frame.origin.x, self.sourcePaint.frame.origin.y);
            [self.sourcePaint renderInContext:ctx];
        } @finally {
            CGContextRestoreGState(ctx);
        }
    }
}

- (CGRect)finiteWorkingBoundsForRegion:(CGRect)region
{
    if (self.usesBackground || self.filter.contentUnits == IJSVGUnitObjectBoundingBox || (self.filterMetadata.inputs & IJSVGFilterInputFillPaint) || (self.filterMetadata.inputs & IJSVGFilterInputStrokePaint)) {
        return region;
    }
    CGRect bounds = CGRectUnion(self.outerBoundingBox, CGRectOffset(self.sourcePaint.transparencyBounds, self.sourcePaint.frame.origin.x, self.sourcePaint.frame.origin.y));
    for (IJSVGFilterPrimitive* primitive in self.filterMetadata.primitives) {
        if (primitive.type == IJSVGNodeTypeFilterOffset) {
            CGFloat dx = [primitive numberForParameter:IJSVGAttributeDX defaultValue:0.f];
            CGFloat dy = [primitive numberForParameter:IJSVGAttributeDY defaultValue:0.f];
            bounds = CGRectUnion(bounds, CGRectOffset(bounds, dx, dy));
        } else if (primitive.type == IJSVGNodeTypeFilterGaussianBlur) {
            if (primitive.edgeMode == IJSVGFilterEdgeModeWrap || primitive.edgeMode == IJSVGFilterEdgeModeDuplicate) {
                return region;
            }
            CGSize deviation = [primitive pairForParameter:IJSVGAttributeStdDeviation defaultValue:CGSizeZero];
            bounds = CGRectInset(bounds, -ceil(4.f * MAX(0.f, deviation.width)) - 2.f, -ceil(4.f * MAX(0.f, deviation.height)) - 2.f);
        } else if (primitive.type != IJSVGNodeTypeFilterMerge) {
            return region;
        }
        if (!IJSVGFilterRectIsFinite(bounds)) {
            return region;
        }
    }
    return CGRectIntersection(region, bounds);
}

- (CGFloat)renderScaleForRect:(CGRect)workRect context:(CGContextRef)ctx
{
    // Local transforms extend the pixel mapping supplied by the renderer.
    // Nested bitmaps already contain their full pixel scale.
    CGAffineTransform transform = IJSVGFilterPixelTransform(ctx);
    CGFloat scale = MAX(hypot(transform.a, transform.b), hypot(transform.c, transform.d));

    // Only alpha amplifying matrices need extra coverage samples. Ordinary blurs
    // and shadows retain destination resolution instead of processing 4x the
    // pixels.
    if (IJSVGFilterRenderDepth == 1 && self.requiresFilterSupersampling) {
        scale *= 2.f;
    }
    scale = MIN(scale, 4096.f / MAX(workRect.size.width, workRect.size.height));

    // Floating point primitive buffers need four times the source bitmap storage.
    scale = MIN(scale, sqrt(4194304.f / (workRect.size.width * workRect.size.height)));

    return scale;
}

- (BOOL)collectMetalBitmap:(CGContextRef)bitmap graph:(IJSVGFilterGraph*)graph workRect:(CGRect)workRect
{
    IJSVGQuartzFilterBatch* batch = IJSVGCurrentFilterBatch;
    CGSize pixelSize = graph.extent.size;
    IJSVGMetalShadowJob* shadow = batch.collecting ? [graph metalShadowJobForBitmap:bitmap] : nil;
    if (shadow != nil) {
        IJSVGQuartzFilterBatchEntry* entry = [[IJSVGQuartzFilterBatchEntry alloc] init];
        entry.metalShadow = shadow;
        entry.workRect = workRect;
        entry.pixelSize = pixelSize;
        [batch.entries setObject:entry forKey:self];
        [batch.orderedEntries addObject:entry];
        return YES;
    }
    IJSVGMetalBlurJob* blur = batch.collecting ? [graph metalBlurJobForBitmap:bitmap] : nil;
    if (blur != nil) {
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

- (BOOL)renderDirectImage:(CGImageRef)image context:(CGContextRef)ctx region:(CGRect)region workRect:(CGRect)workRect pixelSize:(CGSize)pixelSize
{
    if (image == NULL) {
        return NO;
    }
    IJSVGQuartzFilterBatch* batch = IJSVGCurrentFilterBatch;
    IJSVGQuartzFilterBatchEntry* cached = [batch.entries objectForKey:self];
    if (batch.collecting) {
        if (cached != nil) {
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
        [self drawFilteredImage:image context:ctx region:region workRect:workRect independentPixels:NO];
        CGImageRelease(image);
    }
    return YES;
}

- (void)renderGraph:(IJSVGFilterGraph*)graph context:(CGContextRef)ctx region:(CGRect)region workRect:(CGRect)workRect pixelSize:(CGSize)pixelSize scale:(CGFloat)scale
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, pixelSize.width, pixelSize.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);

    if (bitmap == NULL) {
        CGColorSpaceRelease(colorSpace);
        return;
    }

    graph.extent = CGRectMake(0, 0, pixelSize.width, pixelSize.height);
    graph.imageTransform = CGAffineTransformMake(scale, 0, 0, scale, -workRect.origin.x * scale, -workRect.origin.y * scale);
    CGRect sourceExtent = [self requiredSourceExtentForGraph:graph context:ctx];
    CGContextScaleCTM(bitmap, scale, scale);
    CGContextTranslateCTM(bitmap, -workRect.origin.x, -workRect.origin.y);
    if (!CGRectEqualToRect(sourceExtent, graph.extent)) {
        CGContextClipToRect(bitmap, CGRectApplyAffineTransform(sourceExtent, CGAffineTransformInvert(graph.imageTransform)));
    }
    IJSVGPaint* sourcePaint = self.sourcePaint;
    CGContextTranslateCTM(bitmap, sourcePaint.frame.origin.x, sourcePaint.frame.origin.y);

    // Batch independent child effects before applying this enclosing filter.
    // Preserve the actual depth for nested sampling and rounding rules.
    NSSet<IJSVGFilterPaint*>* childFilters = IJSVGCurrentFilterBatch == nil ? [IJSVGFilterPaint batchableFiltersForPaint:sourcePaint] : nil;
    BOOL batched = childFilters.count != 0 && [IJSVGFilterPaint renderBatchedPaints:childFilters
                                                                          inContext:bitmap
                                                                       drawingBlock:^(CGContextRef sourceContext) {
                                                                           [IJSVGFilterPaint renderPaint:sourcePaint inBitmapContext:sourceContext];
                                                                       }];
    if (!batched) {
        [IJSVGFilterPaint renderPaint:sourcePaint inBitmapContext:bitmap];
    }

    // Try the targeted CPU/SIMD filters before the general Core Image path.
    CGContextRef backdrop = NULL;
    if (self.usesBackground && IJSVGFilterRenderDepth == 1 && !IJSVGCurrentFilterBatch.collecting && ctx == IJSVGFilterBitmapContext && (ctx != IJSVGFilterBackgroundContext || CGRectIsInfinite(IJSVGFilterBackgroundClip))) {
        backdrop = ctx;
    }
    CGImageRef localImage = [graph newCGImageForWhiteAlpha:bitmap];
    if (localImage == NULL && backdrop != NULL) {
        localImage = IJSVGFilterSIMDNewComposite(bitmap, backdrop, graph, region);
    }
    if (localImage == NULL) {
        localImage = IJSVGFilterSIMDNewLocalFilter(bitmap, graph, region);
    }
    if ([self renderDirectImage:localImage context:ctx region:region workRect:workRect pixelSize:pixelSize]) {
        CGContextRelease(bitmap);
        CGColorSpaceRelease(colorSpace);
        return;
    }

    // Direct blur/shadow rendering: batch Metal work when possible, otherwise
    // use the measured CPU/Metal blur policy for the graph.
    if ([self collectMetalBitmap:bitmap graph:graph workRect:workRect]) {
        CGContextRelease(bitmap);
        CGColorSpaceRelease(colorSpace);
        return;
    }
    CGImageRef directBlur = [graph newCGImageForDirectBlur:bitmap];
    if ([self renderDirectImage:directBlur context:ctx region:region workRect:workRect pixelSize:pixelSize]) {
        CGContextRelease(bitmap);
        CGColorSpaceRelease(colorSpace);
        return;
    }

    // Core Image handles graphs unsupported by the direct paths above.
    CGImageRef sourceImage = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);

    if (sourceImage == NULL) {
        CGColorSpaceRelease(colorSpace);
        return;
    }

    CIImage* source = [CIImage imageWithCGImage:sourceImage];
    CGImageRelease(sourceImage);
    [self renderSource:source graph:graph context:ctx colorSpace:colorSpace region:region workRect:workRect];

    CGColorSpaceRelease(colorSpace);
}

/// Renders the declared filter region on the existing source sampling grid.
- (void)drawFilterInContext:(CGContextRef)ctx
{
    IJSVGQuartzFilterBatch* batch = IJSVGCurrentFilterBatch;
    if (batch.collecting && (batch.invalid || IJSVGFilterRenderDepth != batch.renderDepth + 1 || ![batch.eligiblePaints containsObject:self])) {
        // Indirect SVGs/patterns may introduce filters absent from the paint scan.
        // Discard the collection pass and use the general renderer in that case.
        batch.invalid = YES;
        return;
    }
    IJSVGFilterGraph* graph = self.filterGraph;
    CGRect region = [graph regionForNode:_filter units:_filter.units defaultRegion:CGRectZero];

    if (IJSVGFilterRectIsFinite(region) == NO || CGRectIsEmpty(region) == YES) {
        return;
    }

    IJSVGFilterPrimitive* primitive = self.filterMetadata.primitives.firstObject;
    if (!self.usesBackground && self.filterMetadata.usesBackdropAddition && primitive.x == nil && primitive.y == nil && primitive.width == nil && primitive.height == nil) {
        // Adding transparent black leaves the source unchanged.
        CGContextSaveGState(ctx);
        CGContextClipToRect(ctx, region);
        CGContextTranslateCTM(ctx, self.sourcePaint.frame.origin.x, self.sourcePaint.frame.origin.y);
        [self.sourcePaint renderInContext:ctx];
        CGContextRestoreGState(ctx);
        return;
    }

    CGRect samplingBounds = CGRectUnion(self.outerBoundingBox, region);
    if (IJSVGFilterRectIsFinite(samplingBounds) == NO || CGRectIsEmpty(samplingBounds) == YES) {
        return;
    }

    // SourceGraphic and every primitive are cropped to the filter region.
    // Pixels beyond it cannot contribute, even when the source artwork is larger.
    // Restrict finite effects to their painted coverage before reducing
    // resolution.
    CGRect workRect = region;
    CGFloat scale = [self renderScaleForRect:samplingBounds context:ctx];
    CGAffineTransform pixelTransform = IJSVGFilterPixelTransform(ctx);
    CGFloat destinationScale = MAX(hypot(pixelTransform.a, pixelTransform.b), hypot(pixelTransform.c, pixelTransform.d));
    if (scale < destinationScale) {
        workRect = [self finiteWorkingBoundsForRegion:region];
        if (CGRectIsEmpty(workRect)) {
            return;
        }
        if (!CGRectEqualToRect(workRect, region)) {
            scale = [self renderScaleForRect:workRect context:ctx];
        }
    }
    if (!isfinite(scale) || scale <= 0.f) {
        return;
    }
    CGAffineTransform grid = CGAffineTransformMakeScale(scale, scale);
    CGAffineTransform destination = CGContextGetCTM(ctx);
    if (ctx == IJSVGFilterBitmapContext && isfinite(destination.tx) && isfinite(destination.ty) && fabs(destination.tx) <= INT_MAX && fabs(destination.ty) <= INT_MAX && (fabs(destination.tx - round(destination.tx)) > 1e-9 || fabs(destination.ty - round(destination.ty)) > 1e-9) && fabs(destination.b) <= 1e-9 && fabs(destination.c) <= 1e-9 && fabs(fabs(destination.a) - scale) <= scale * 1e-9 && fabs(fabs(destination.d) - scale) <= scale * 1e-9 && (self.filterMetadata.inputs & IJSVGFilterInputBackgroundImage)) {
        // Include destination translation when snapping backdrop dependent
        // surfaces. Snapping only in local coordinates introduces a fractional
        // resample and prevents direct CPU access to the background pixel grid.
        grid = destination;
    }
    workRect = CGRectApplyAffineTransform(workRect, grid);
    workRect = CGRectIntegral(workRect);
    workRect = CGRectApplyAffineTransform(workRect, CGAffineTransformInvert(grid));
    CGSize pixelSize = CGSizeMake(round(workRect.size.width * scale), round(workRect.size.height * scale));
    graph.extent = (CGRect) { CGPointZero, pixelSize };
    graph.imageTransform = CGAffineTransformMake(scale, 0, 0, scale, -workRect.origin.x * scale, -workRect.origin.y * scale);

    // Collection retains the complete sampling rectangle. Reuse it before
    // destination clipping shrinks the transient work rectangle: the cached
    // pixels already contain the required halo and Quartz applies the clip.
    // Compare in pixels to tolerate transform roundoff without accepting a
    // different sampling grid (the dimensions must still match exactly).
    IJSVGQuartzFilterBatchEntry* cached = [batch.entries objectForKey:self];
    if (!batch.collecting && cached.renderedImage != NULL && CGSizeEqualToSize(cached.pixelSize, pixelSize) && fabs(cached.workRect.origin.x - workRect.origin.x) * scale < 1e-7 && fabs(cached.workRect.origin.y - workRect.origin.y) * scale < 1e-7 && fabs(cached.workRect.size.width - workRect.size.width) * scale < 1e-7 && fabs(cached.workRect.size.height - workRect.size.height) * scale < 1e-7) {
        [self drawFilteredImage:cached.renderedImage context:ctx region:region workRect:workRect independentPixels:NO];
        return;
    }
    CGRect required = [self requiredSourceExtentForGraph:graph context:ctx];

    // Keep the allocation on the original sampling grid, including rotations.
    if (!CGRectIsEmpty(required) && !CGRectIsNull(required) && !CGRectEqualToRect(required, graph.extent)) {
        required = CGRectIntersection(graph.extent, IJSVGFilterAlignedRect(required, CGPointZero));
        workRect = CGRectApplyAffineTransform(required, CGAffineTransformInvert(graph.imageTransform));
        pixelSize = required.size;
    }
    if (batch.preflighting) {
        [self preflightPixelSize:pixelSize batch:batch];
        return;
    }
    if (!IJSVGFilterReservePixelSize(pixelSize, batch, cached)) {
        return;
    }

    // Batch replay needs the collection signature to retain completed pixels.
    // Reset it only when preparing output for a new render.
    _outputSignature = nil;
    if (!IJSVGFilterHasCachingAncestor && self.canCacheOutput) {
        _outputSignature = @[ [NSValue valueWithRect:workRect], [NSValue valueWithSize:pixelSize], [NSValue valueWithRect:region], [NSValue valueWithRect:self.boundingBox], [NSValue valueWithRect:self.viewPort], [NSValue valueWithRect:self.sourcePaint.frame], @(self.backingScaleFactor), @(self.renderQuality), @(IJSVGFilterRenderDepth == 1) ];
        IJSVGFilterCachedImage* output = [IJSVGFilterOutputCache() objectForKey:_outputCacheKey];
        if ([output.signature isEqual:_outputSignature]) {
            if (batch.collecting) {
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
    BOOL previousCachingAncestor = IJSVGFilterHasCachingAncestor;

    // Only suppress inner snapshots when this output fits the cache per image
    // limit. Background dependent ancestors fail canCacheOutput and leave their
    // independent descendants eligible for caching.
    BOOL willCacheOutput = _outputSignature != nil && pixelSize.height > 0 && pixelSize.width <= 4194304 / pixelSize.height;
    IJSVGFilterHasCachingAncestor = previousCachingAncestor || willCacheOutput;
    @try {
        [self renderGraph:graph context:ctx region:region workRect:workRect pixelSize:pixelSize scale:scale];
    } @finally {
        IJSVGFilterHasCachingAncestor = previousCachingAncestor;
    }
}

@end
