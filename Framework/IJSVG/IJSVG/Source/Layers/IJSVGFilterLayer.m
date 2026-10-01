//
//  IJSVGFilterLayer.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterLayer.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGFilterGraph.h>
#import <IJSVG/IJSVGLayerTree.h>
#import <CoreImage/CoreImage.h>

static BOOL IJSVGFilterRectIsFinite(CGRect rect)
{
    return isfinite(rect.origin.x) && isfinite(rect.origin.y)
        && isfinite(rect.size.width) && isfinite(rect.size.height);
}

// Nested filters already inherit the drawing transform of the supersampled bitmap.
static _Thread_local NSUInteger IJSVGFilterRenderDepth = 0;

@interface IJSVGFilterBatchEntry : NSObject
@property (nonatomic, strong) CIImage* output;
@property (nonatomic, strong) IJSVGMetalShadowJob* metalShadow;
@property (nonatomic, strong) IJSVGMetalBlurJob* metalBlur;
@property (nonatomic, assign) CGRect workRect;
@property (nonatomic, assign) CGSize pixelSize;
@property (nonatomic, assign) CGRect atlasRect;
@property (nonatomic, assign) CGImageRef renderedImage;
@end

@implementation IJSVGFilterBatchEntry

- (void)dealloc
{
    if(_renderedImage != NULL) {
        CGImageRelease(_renderedImage);
    }
}
@end

@interface IJSVGFilterBatch : NSObject
@property (nonatomic, strong) NSMapTable<IJSVGFilterLayer*, IJSVGFilterBatchEntry*>* entries;
@property (nonatomic, strong) NSMutableArray<IJSVGFilterBatchEntry*>* orderedEntries;
@property (nonatomic, assign) BOOL collecting;
@property (nonatomic, assign) BOOL preflighting;
@property (nonatomic, strong) NSMutableSet<IJSVGFilterLayer*>* preflightLayers;
@property (nonatomic, assign) BOOL invalid;
@property (nonatomic, assign) NSUInteger retainedPixels;
@property (nonatomic, assign) NSUInteger totalPixels;
@property (nonatomic, assign) NSUInteger scratchBytes;
@property (nonatomic, assign) NSUInteger largestSourcePixels;
@property (nonatomic, strong) NSSet<IJSVGFilterLayer*>* eligibleLayers;
@property (nonatomic, strong) NSSet<CALayer*>* collectionLayers;
@end

@implementation IJSVGFilterBatch
@end

// Scoped to a synchronous draw; the owning local retains the batch until the
// pointer is cleared in @finally. No state survives the synchronous draw.
static _Thread_local __unsafe_unretained IJSVGFilterBatch* IJSVGCurrentFilterBatch;

static BOOL IJSVGFilterBatchEligible(CALayer* root, NSMutableSet<IJSVGFilterLayer*>* eligibleLayers)
{
    NSMutableArray<CALayer*>* pending = [NSMutableArray arrayWithObject:root];
    NSUInteger filters = 0;
    while(pending.count != 0) {
        CALayer* layer = pending.lastObject;
        [pending removeLastObject];
        if(layer.mask != nil) {
            return NO;
        }
        if([layer conformsToProtocol:@protocol(IJSVGDrawableLayer)]) {
            CALayer<IJSVGDrawableLayer>* drawable = (id)layer;
            if(drawable.maskLayer != nil || drawable.clipLayers.count != 0) {
                return NO;
            }
        }
        if([layer isKindOfClass:IJSVGFilterLayer.class]) {
            IJSVGFilterLayer* filtered = (id)layer;
            NSSet* names = filtered.filter.inputNames;
            if([names containsObject:IJSVGStringBackgroundImage]
                || [names containsObject:IJSVGStringBackgroundAlpha]) {
                return NO;
            }
            for(CALayer* parent = layer.superlayer; parent != nil; parent = parent.superlayer) {
                if([parent isKindOfClass:IJSVGFilterLayer.class]) {
                    return NO;
                }
            }
            [eligibleLayers addObject:filtered];
            filters++;
        }
        [pending addObjectsFromArray:layer.sublayers ?: @[]];
    }
    return filters >= 3 && filters <= 128;
}

@implementation IJSVGFilterLayer

+ (BOOL)shouldRenderLayerDuringCollection:(CALayer*)layer
{
    IJSVGFilterBatch* batch = IJSVGCurrentFilterBatch;
    // Filter source bitmaps still need their complete subtree.
    return !batch.collecting || IJSVGFilterRenderDepth != 0
        || [batch.collectionLayers containsObject:layer];
}

+ (BOOL)renderCollectedEntries:(NSArray<IJSVGFilterBatchEntry*>*)entries
{
    NSMutableArray<IJSVGMetalShadowJob*>* shadows = [[NSMutableArray alloc] init];
    for(IJSVGFilterBatchEntry* entry in entries) {
        if(entry.metalShadow != nil) {
            [shadows addObject:entry.metalShadow];
        }
    }
    if(![IJSVGMetalShadowJob renderJobs:shadows]) {
        return NO;
    }
    for(IJSVGFilterBatchEntry* entry in entries) {
        if(entry.metalShadow != nil) {
            entry.renderedImage = CGImageRetain(entry.metalShadow.renderedImage);
            entry.metalShadow = nil;
        }
    }
    NSMutableArray<IJSVGMetalBlurJob*>* blurs = [[NSMutableArray alloc] init];
    for(IJSVGFilterBatchEntry* entry in entries) {
        if(entry.metalBlur != nil) {
            [blurs addObject:entry.metalBlur];
        }
    }
    if(![IJSVGMetalBlurRenderer renderJobs:blurs]) {
        return NO;
    }
    for(IJSVGFilterBatchEntry* entry in entries) {
        if(entry.metalBlur != nil) {
            entry.renderedImage = CGImageRetain(entry.metalBlur.renderedImage);
            entry.metalBlur = nil;
        }
    }
    NSUInteger pixels = 0;
    NSMutableArray<IJSVGFilterBatchEntry*>* ciEntries = [[NSMutableArray alloc] init];
    for(IJSVGFilterBatchEntry* entry in entries) {
        if(entry.output != nil) {
            pixels += entry.pixelSize.width * entry.pixelSize.height;
            [ciEntries addObject:entry];
        }
    }
    if(pixels == 0) {
        return YES;
    }
    CGFloat atlasWidth = ciEntries.count == 1 ? ciEntries.firstObject.pixelSize.width : ceil(sqrt(pixels));
    for(IJSVGFilterBatchEntry* entry in entries) {
        if(entry.output != nil) {
            atlasWidth = MAX(atlasWidth, entry.pixelSize.width);
        }
    }
    CGFloat x = 0, y = 0, rowHeight = 0;
    CIImage* atlas = CIImage.emptyImage;
    for(IJSVGFilterBatchEntry* entry in entries) {
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
    if(atlasWidth * atlasHeight > 1048576 || atlasWidth * atlasHeight > pixels * 2) {
        // Packing padding can exceed the budget even when source pixels fit.
        // Split whole filter images so convolution never loses neighbouring pixels.
        if(ciEntries.count < 2) {
            return NO;
        }
        NSUInteger middle = ciEntries.count / 2;
        return [self renderCollectedEntries:[ciEntries subarrayWithRange:NSMakeRange(0, middle)]]
            && [self renderCollectedEntries:[ciEntries subarrayWithRange:NSMakeRange(middle, ciEntries.count - middle)]];
    }
    __block CGImageRef rendered = NULL;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    // Wait before leasing a context. Source drawing and graph construction
    // remain concurrent, and the slot is returned before cropping or replay.
    [IJSVGThreadManager performCIOutputBlock:^{
        [IJSVGThreadManager performBlockWithCIContext:^(CIContext* ciContext, BOOL supportsMetalKernels) {
            rendered = [ciContext createCGImage:atlas
                                       fromRect:CGRectMake(0, 0, atlasWidth, atlasHeight)
                                         format:kCIFormatRGBA8 colorSpace:colorSpace];
        }];
    }];
    CGColorSpaceRelease(colorSpace);
    if(rendered == NULL) {
        return NO;
    }
    for(IJSVGFilterBatchEntry* entry in entries) {
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

+ (BOOL)renderBatchedLayer:(CALayer*)root
                 inContext:(CGContextRef)context
              drawingBlock:(void (^)(CGContextRef))drawingBlock
{
    NSMutableSet<IJSVGFilterLayer*>* eligibleLayers = [[NSMutableSet alloc] init];
    if(context == NULL || IJSVGCurrentFilterBatch != nil || !IJSVGFilterBatchEligible(root, eligibleLayers)) {
        return NO;
    }
    // Display and PDF contexts cannot be queried with bitmap context APIs.
    // The collection pass only needs disposable storage with the same scale.
    CGAffineTransform transform = CGContextGetCTM(context);
    CGRect deviceBounds = CGRectApplyAffineTransform(CGContextGetClipBoundingBox(context), transform);
    if(!IJSVGFilterRectIsFinite(deviceBounds) || CGRectIsEmpty(deviceBounds)) {
        return NO;
    }
    deviceBounds = CGRectIntegral(deviceBounds);
    if(deviceBounds.size.width > 2048 || deviceBounds.size.height > 2048
        || deviceBounds.size.width * deviceBounds.size.height > 4194304) {
        return NO;
    }
    CGColorSpaceRef scratchColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef scratch = CGBitmapContextCreate(NULL, deviceBounds.size.width, deviceBounds.size.height,
        8, 0, scratchColorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(scratchColorSpace);
    if(scratch == NULL) {
        return NO;
    }
    CGContextTranslateCTM(scratch, -deviceBounds.origin.x, -deviceBounds.origin.y);
    CGContextConcatCTM(scratch, transform);
    IJSVGFilterBatch* batch __attribute__((objc_precise_lifetime)) = [[IJSVGFilterBatch alloc] init];
    batch.eligibleLayers = eligibleLayers;
    batch.scratchBytes = CGBitmapContextGetBytesPerRow(scratch) * CGBitmapContextGetHeight(scratch);
    NSMutableSet<CALayer*>* collectionLayers = [[NSMutableSet alloc] init];
    for(CALayer* filtered in eligibleLayers) {
        for(CALayer* layer = filtered; layer != nil; layer = layer.superlayer) {
            if([collectionLayers containsObject:layer]) {
                break;
            }
            [collectionLayers addObject:layer];
        }
    }
    batch.collectionLayers = collectionLayers;
    batch.entries = [NSMapTable strongToStrongObjectsMapTable];
    batch.orderedEntries = [[NSMutableArray alloc] init];
    batch.collecting = YES;
    IJSVGCurrentFilterBatch = batch;
    @try {
        // Walk the actual drawing transforms, but stop each filter before its
        // source bitmap is allocated or painted. Reject over-budget draws before
        // doing source rasterization, blur calibration or GPU submissions.
        batch.preflighting = YES;
        batch.preflightLayers = [[NSMutableSet alloc] init];
        drawingBlock(scratch);
        if(batch.invalid || batch.preflightLayers.count < 3) {
            return NO;
        }
        batch.preflighting = NO;
        batch.preflightLayers = nil;
        batch.totalPixels = 0;
        // Visit only filter branches and their ancestors during collection.
        // Unfiltered artwork is painted once, during the final replay.
        drawingBlock(scratch);
        if(batch.invalid || batch.orderedEntries.count < 3) {
            return NO;
        }
        if(![self renderCollectedEntries:batch.orderedEntries]) {
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

- (instancetype)initWithSourceLayer:(CALayer<IJSVGDrawableLayer>*)layer
                             filter:(IJSVGFilter*)filter
                           viewPort:(CGRect)viewPort
{
    if((self = [super init]) != nil) {
        _filter = filter;
        _viewPort = viewPort;
        self.boundingBox = layer.boundingBox;
        self.outerBoundingBox = layer.outerBoundingBox;
        [self addSublayer:layer];
    }
    return self;
}

- (CALayer<IJSVGDrawableLayer>*)sourceLayer
{
    return (CALayer<IJSVGDrawableLayer>*)self.sublayers.firstObject;
}

- (BOOL)treatImplicitOriginAsTransform
{
    return self.sourceLayer.treatImplicitOriginAsTransform;
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
    CGContextRef bitmap = CGBitmapContextCreate(
        NULL, graph.extent.size.width, graph.extent.size.height, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if(bitmap == NULL) {
        return CIImage.emptyImage;
    }
    CGContextConcatCTM(bitmap, graph.imageTransform);
    CGRect region = CGRectApplyAffineTransform(graph.extent, CGAffineTransformInvert(graph.imageTransform));
    IJSVGLayerTree* tree = [[IJSVGLayerTree alloc] init];
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
    if(self.hidden == YES || self.opacity == 0.f) {
        return;
    }
    dispatch_block_t drawingBlock = ^{
        CGContextSaveGState(ctx);
        CGContextSetAlpha(ctx, self.opacity);
        [self drawInContext:ctx];
        CGContextRestoreGState(ctx);
    };
    if(self.maskLayer != nil) {
        [IJSVGLayer clipContextWithMask:self.maskLayer
                                toLayer:self
                              inContext:ctx
                           drawingBlock:drawingBlock];
    } else {
        drawingBlock();
    }
}

- (BOOL)requiresFilterSupersampling
{
    if(self.filter.requiresSupersampling) {
        return YES;
    }
  
    // An outer filter must supply enough source resolution for nested hard alpha effects.
    NSMutableArray<CALayer*>* pending = [self.sublayers mutableCopy];
    while(pending.count != 0) {
        CALayer* layer = pending.lastObject;
        [pending removeLastObject];
        if([layer isKindOfClass:IJSVGFilterLayer.class]) {
            if([(IJSVGFilterLayer*)layer requiresFilterSupersampling]) {
                return YES;
            }
        } else if(layer.sublayers.count != 0) {
            [pending addObjectsFromArray:layer.sublayers];
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

- (CIImage*)backgroundImageFromContext:(CGContextRef)ctx
                        imageTransform:(CGAffineTransform)imageTransform
{
    // Bitmap destinations can supply their already painted backdrop.
    // Nonbitmap contexts have no readable pixel backing.
    if(CGBitmapContextGetData(ctx) == NULL) {
        return CIImage.emptyImage;
    }
    CGImageRef background = CGBitmapContextCreateImage(ctx);
    if(background == NULL) {
        return CIImage.emptyImage;
    }
    CIImage* image = [CIImage imageWithCGImage:background];
    CGImageRelease(background);
    CGAffineTransform mapping
        = CGAffineTransformConcat(CGAffineTransformInvert(CGContextGetCTM(ctx)), imageTransform);
    return [image imageByApplyingTransform:mapping];
}

- (void)drawFilterInContext:(CGContextRef)ctx
{
    IJSVGFilterBatch* batch = IJSVGCurrentFilterBatch;
    if(batch.collecting && (batch.invalid || IJSVGFilterRenderDepth != 1
        || ![batch.eligibleLayers containsObject:self])) {
        // Indirect SVGs/patterns may introduce filters absent from the layer scan.
        // Discard the collection pass and use the general renderer in that case.
        batch.invalid = YES;
        return;
    }
    IJSVGFilterGraph* graph = [[IJSVGFilterGraph alloc] init];
    graph.filter = self.filter;
    graph.boundingBox = self.boundingBox;
    graph.viewPort = self.viewPort;
    CGRect region = [graph regionForNode:_filter
                                   units:_filter.units
                           defaultRegion:CGRectZero];
  
    if(IJSVGFilterRectIsFinite(region) == NO || CGRectIsEmpty(region) == YES) {
        return;
    }

    CGRect workRect = CGRectUnion(self.outerBoundingBox, region);
    if(IJSVGFilterRectIsFinite(workRect) == NO || CGRectIsEmpty(workRect) == YES) {
        return;
    }

    // Use the actual drawing transform so zoom, export size and Retina all
    // produce the same effect in SVG units. Bound temporary raster storage.
    CGAffineTransform transform = CGContextGetCTM(ctx);
    CGFloat scale = MAX(hypot(transform.a, transform.b), hypot(transform.c, transform.d));
  
    // Only alpha amplifying matrices need extra coverage samples. Ordinary blurs
    // and shadows retain destination resolution instead of processing 4x the pixels.
    if(IJSVGFilterRenderDepth == 1 && [self requiresFilterSupersampling]) {
        scale *= 2.f;
  
    }
    scale = MIN(scale, 4096.f / MAX(workRect.size.width, workRect.size.height));
  
    // Floating point primitive buffers need four times the source bitmap storage.
    scale = MIN(scale, sqrt(4194304.f / (workRect.size.width * workRect.size.height)));
    if(isfinite(scale) == NO || scale <= 0.f) {
        return;
    }
  
    workRect = CGRectApplyAffineTransform(workRect, CGAffineTransformMakeScale(scale, scale));
    workRect = CGRectIntegral(workRect);
    workRect = CGRectApplyAffineTransform(workRect, CGAffineTransformMakeScale(1.f / scale, 1.f / scale));
    CGSize pixelSize = CGSizeMake(round(workRect.size.width * scale),
                                  round(workRect.size.height * scale));
    if(batch.preflighting) {
        NSUInteger pixels = pixelSize.width * pixelSize.height;
        if([batch.preflightLayers containsObject:self]
            || pixelSize.width > 2048 || pixelSize.height > 2048
            || pixels > 1048576 || batch.totalPixels + pixels > 8388608) {
            batch.invalid = YES;
            return;
        }
        batch.largestSourcePixels = MAX(batch.largestSourcePixels, pixels);
        // Account for RGBA8 replay images with up to 2x atlas packing padding,
        // the current source bitmap, pending RGBA8 sources, and a full
        // one-megapixel Metal lease (44 bytes/pixel), plus parameter headroom.
        // This is a working-set estimate, not a process memory limit: CPU filter
        // intermediates and Core Image's private caches can add further storage.
        NSUInteger estimatedBytes = batch.scratchBytes
            + (batch.totalPixels + pixels) * 8
            + batch.largestSourcePixels * 4 + 1048576 * (44 + 4) + 65536;
        if(estimatedBytes > 128 * 1024 * 1024) {
            batch.invalid = YES;
            return;
        }
        [batch.preflightLayers addObject:self];
        batch.totalPixels += pixels;
        return;
    }
    IJSVGFilterBatchEntry* cached = [batch.entries objectForKey:self];
    if(!batch.collecting && cached.renderedImage != NULL
        && CGRectEqualToRect(cached.workRect, workRect) && CGSizeEqualToSize(cached.pixelSize, pixelSize)) {
        CGContextSaveGState(ctx);
        CGContextClipToRect(ctx, region);
        CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
        CGContextDrawImage(ctx, workRect, cached.renderedImage);
        CGContextRestoreGState(ctx);
        return;
    }
    if(batch.collecting) {
        NSUInteger pixels = pixelSize.width * pixelSize.height;
        if(cached != nil || pixelSize.width > 2048 || pixelSize.height > 2048
            || pixels > 1048576 || batch.totalPixels + pixels > 8388608) {
            batch.invalid = YES;
            return;
        }
        // Flush complete jobs at one megapixel. Finished RGBA8 images remain
        // available for ordered replay, while source and GPU scratch storage is reused.
        if(batch.retainedPixels + pixels > 1048576) {
            if(![self.class renderCollectedEntries:batch.orderedEntries]) {
                batch.invalid = YES;
                return;
            }
            batch.retainedPixels = 0;
        }
        batch.retainedPixels += pixels;
        batch.totalPixels += pixels;
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, pixelSize.width, pixelSize.height,
                                                8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
  
    if(bitmap == NULL) {
        CGColorSpaceRelease(colorSpace);
        return;
    }
  
    CGContextScaleCTM(bitmap, scale, scale);
    CGContextTranslateCTM(bitmap, -workRect.origin.x, -workRect.origin.y);
    CALayer<IJSVGDrawableLayer>* sourceLayer = self.sourceLayer;
    CGContextTranslateCTM(bitmap, sourceLayer.frame.origin.x, sourceLayer.frame.origin.y);
    [sourceLayer renderInContext:bitmap];
    graph.extent = CGRectMake(0, 0, pixelSize.width, pixelSize.height);
    graph.imageTransform = CGAffineTransformMake(scale, 0, 0, scale,
        -workRect.origin.x * scale, -workRect.origin.y * scale);
    IJSVGMetalShadowJob* shadow = batch.collecting ? [graph metalShadowJobForBitmap:bitmap] : nil;
    if(shadow != nil) {
        IJSVGFilterBatchEntry* entry = [[IJSVGFilterBatchEntry alloc] init];
        entry.metalShadow = shadow;
        entry.workRect = workRect;
        entry.pixelSize = pixelSize;
        [batch.entries setObject:entry forKey:self];
        [batch.orderedEntries addObject:entry];
        CGContextRelease(bitmap);
        CGColorSpaceRelease(colorSpace);
        return;
    }
    IJSVGMetalBlurJob* blur = batch.collecting ? [graph metalBlurJobForBitmap:bitmap] : nil;
    if(blur != nil) {
        IJSVGFilterBatchEntry* entry = [[IJSVGFilterBatchEntry alloc] init];
        entry.metalBlur = blur;
        entry.workRect = workRect;
        entry.pixelSize = pixelSize;
        [batch.entries setObject:entry forKey:self];
        [batch.orderedEntries addObject:entry];
        CGContextRelease(bitmap);
        CGColorSpaceRelease(colorSpace);
        return;
    }
    CGImageRef smallBlur = [graph newCGImageForSmallBlur:bitmap];
    if(smallBlur != NULL) {
        if(batch.collecting) {
            if(cached != nil) {
                batch.invalid = YES;
                CGImageRelease(smallBlur);
            } else {
                IJSVGFilterBatchEntry* entry = [[IJSVGFilterBatchEntry alloc] init];
                entry.renderedImage = smallBlur;
                entry.workRect = workRect;
                entry.pixelSize = pixelSize;
                [batch.entries setObject:entry forKey:self];
                [batch.orderedEntries addObject:entry];
            }
        } else {
            CGContextSaveGState(ctx);
            CGContextClipToRect(ctx, region);
            CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
            CGContextDrawImage(ctx, workRect, smallBlur);
            CGContextRestoreGState(ctx);
            CGImageRelease(smallBlur);
        }
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
    CGRect extent = CGRectMake(0.f, 0.f, pixelSize.width, pixelSize.height);
    // Keep filter coordinates aligned with the source bitmap. The calling context
    // drawing transform handles flipped views and image exports.
    CGAffineTransform imageTransform = CGAffineTransformMake(scale, 0.f, 0.f,
                                                             scale, -workRect.origin.x * scale,
                                                             -workRect.origin.y * scale);
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
            return [self backgroundImageFromContext:ctx
                                    imageTransform:imageTransform];
        };

        CIImage* output = [graph imageByFilteringSource:source];
        if(batch.collecting) {
            if(cached != nil) {
                batch.invalid = YES;
                return;
            }

            IJSVGFilterBatchEntry* entry = [[IJSVGFilterBatchEntry alloc] init];
            entry.output = output;
            entry.workRect = workRect;
            entry.pixelSize = pixelSize;
            [batch.entries setObject:entry forKey:self];
            [batch.orderedEntries addObject:entry];
            return;
        }
        CGImageRef image = [context createCGImage:output
                                         fromRect:extent
                                           format:kCIFormatRGBA8
                                       colorSpace:colorSpace];

        if(image != NULL) {
            CGContextSaveGState(ctx);
            CGContextClipToRect(ctx, region);
            CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
            CGContextDrawImage(ctx, workRect, image);
            CGContextRestoreGState(ctx);
            CGImageRelease(image);
        }
    }];

    CGColorSpaceRelease(colorSpace);
}

@end
