//
//  IJSVGPatternPaint.m
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGFilterPaint.h>
#import <IJSVGPatternPaint.h>

// Each CGPattern owns its drawing parameters, even if Quartz defers its callback.
@interface IJSVGPatternDrawingInfo : NSObject

@property (nonatomic, strong, readonly) IJSVGPatternPaint* owner;
@property (nonatomic, strong, readonly) IJSVGPaint* pattern;
@property (nonatomic, assign, readonly) CGSize cellSize;
@property (nonatomic, assign, readonly) CGRect viewBox;
@property (nonatomic, assign, readonly) CGAffineTransform pixelTransform;
@property (nonatomic, assign, readonly) IJSVGViewBoxAlignment alignment;
@property (nonatomic, assign, readonly) IJSVGViewBoxMeetOrSlice meetOrSlice;

- (instancetype)initWithPaint:(IJSVGPatternPaint*)paint cellSize:(CGSize)cellSize viewBox:(CGRect)viewBox pixelTransform:(CGAffineTransform)pixelTransform;

@end

@implementation IJSVGPatternDrawingInfo

- (instancetype)initWithPaint:(IJSVGPatternPaint*)paint cellSize:(CGSize)cellSize viewBox:(CGRect)viewBox pixelTransform:(CGAffineTransform)pixelTransform
{
    if ((self = [super init])) {
        // Keep the owner alive for weak parent references in the paint tree.
        _owner = paint;
        _pattern = paint.pattern;
        _cellSize = cellSize;
        _viewBox = viewBox;
        _pixelTransform = pixelTransform;
        _alignment = paint.patternNode.viewBoxAlignment;
        _meetOrSlice = paint.patternNode.viewBoxMeetOrSlice;
    }
    return self;
}

@end

@interface IJSVGPatternPaint () {
    CGImageRef _cachedImage;
    CGFloat _cachedScale;
    CGRect _cachedBounds;
}
@end

@implementation IJSVGPatternPaint

- (IJSVGPaintTraits)paintTraits
{
    return IJSVGPaintTraitPattern;
}

static void IJSVGQuartzPatternRelease(void* info)
{
    CFRelease(info);
}

/// Preserves destination resolution while filters render inside a pattern cell.
static void IJSVGQuartzPatternDrawingCallBack(void* info, CGContextRef ctx)
{
    IJSVGPatternDrawingInfo* drawingInfo = (__bridge IJSVGPatternDrawingInfo*)info;
    CGSize size = drawingInfo.cellSize;
    CGContextSaveGState(ctx);
    @try {
        CGRect rect = CGRectMake(0.f, 0.f, size.width, size.height);
        CGContextClipToRect(ctx, rect);
        // Register the mapping before applying the viewBox so both its scale
        // and translation are picked up from subsequent context transforms.
        [IJSVGFilterPaint drawInContext:ctx
                         pixelTransform:drawingInfo.pixelTransform
                           drawingBlock:^{
                               IJSVGContextDrawViewBox(ctx, drawingInfo.viewBox, rect, drawingInfo.alignment, drawingInfo.meetOrSlice, ^(CGFloat scale[]) {
                                   [IJSVGPaint renderPaint:drawingInfo.pattern inContext:ctx options:IJSVGPaintDrawingOptionNone];
                               });
                           }];
    } @finally {
        CGContextRestoreGState(ctx);
    }
}

- (void)computeCellSize:(CGSize*)cellSize viewBox:(CGRect*)viewBox origin:(CGPoint*)origin
{
    IJSVGPaint* paint = (IJSVGPaint*)self.referencingPaint;
    CGRect rect = IJSVGPaintGetBoundingBoxBounds(paint);

    // get the bounds, we need these as when we render we might need to swap
    // the coordinates over to objectBoundingBox
    IJSVGUnitLength* xLength = _patternNode.x;
    IJSVGUnitLength* yLength = _patternNode.y;
    IJSVGUnitLength* wLength = _patternNode.width;
    IJSVGUnitLength* hLength = _patternNode.height;

    // actually do the swap if required
    if (_patternNode.units == IJSVGUnitObjectBoundingBox) {
        wLength = wLength.lengthByMatchingPercentage;
        hLength = hLength.lengthByMatchingPercentage;
        xLength = xLength.lengthByMatchingPercentage;
        yLength = yLength.lengthByMatchingPercentage;
    }

    CGSize percentageSize = _patternNode.units == IJSVGUnitUserSpaceOnUse ? self.viewPort.size : rect.size;
    *origin = CGPointMake([xLength computeValue:percentageSize.width], [yLength computeValue:percentageSize.height]);

    CGFloat width = [wLength computeValue:percentageSize.width];
    CGFloat height = [hLength computeValue:percentageSize.height];
    *cellSize = CGSizeMake(width, height);

    // Who knew that patterns have viewBoxes? Not me, but here is an
    // implementation of it anyway
    if (_patternNode.viewBox != nil && _patternNode.viewBox.isZeroRect == NO) {
        // A viewBox establishes its own coordinates, regardless of content units.
        *viewBox = [_patternNode.viewBox computeValue:rect.size];
    } else {
        // no viewbox is assigned, so just map it 1:1 with its cellSize
        *viewBox = CGRectMake(0.f, 0.f, cellSize->width, cellSize->height);
    }
}

/// Carries the final pixel scale into deferred pattern drawing.
- (void)drawPatternInContext:(CGContextRef)ctx
{
    // holder for callback
    static const CGPatternCallbacks callbacks = { 0, &IJSVGQuartzPatternDrawingCallBack, &IJSVGQuartzPatternRelease };

    // create base pattern space
    CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern(NULL);
    CGContextSetFillColorSpace(ctx, patternSpace);
    CGColorSpaceRelease(patternSpace);

    IJSVGPaint* paint = (IJSVGPaint*)self.referencingPaint;

    // transform us back into the correct space
    CGAffineTransform transform = [IJSVGPaint userSpaceTransformForPaint:paint];

    CGPoint origin = CGPointZero;
    CGSize cellSize = CGSizeZero;
    CGRect viewBox = CGRectZero;
    [self computeCellSize:&cellSize viewBox:&viewBox origin:&origin];

    // transform the X and Y shift
    // Place the tile in user space before moving into the local space of the
    // referencing paint.
    transform = CGAffineTransformConcat(IJSVGConcatTransforms(self.patternNode.transforms), transform);
    if (_patternNode.units == IJSVGUnitObjectBoundingBox) {
        origin.x += paint.boundingBox.origin.x;
        origin.y += paint.boundingBox.origin.y;
    }
    transform = CGAffineTransformTranslate(transform, origin.x, origin.y);

    // its possible that this paint is shifted inwards due to a stroke on the
    // parent paint
    transform = CGAffineTransformConcat(transform, [IJSVGPaint userSpaceTransformForPaint:self]);

    if (cellSize.width <= 0.f || cellSize.height <= 0.f || !isfinite(cellSize.width) || !isfinite(cellSize.height)) {
        return;
    }

    // Reduce the phase before device space tiling. Large SVG translations
    // otherwise amplify the pixel rounding of the constant spacing of CGPattern.
    CGAffineTransform linear = transform;
    linear.tx = 0.f;
    linear.ty = 0.f;
    CGFloat determinant = linear.a * linear.d - linear.b * linear.c;
    if (determinant != 0.f) {
        CGPoint phase = CGPointApplyAffineTransform(CGPointMake(transform.tx, transform.ty), CGAffineTransformInvert(linear));
        phase.x = fmod(phase.x, cellSize.width);
        phase.y = fmod(phase.y, cellSize.height);
        phase = CGPointApplyAffineTransform(phase, linear);
        transform.tx = phase.x;
        transform.ty = phase.y;
    }
    CGAffineTransform pixelTransform = CGAffineTransformConcat(transform, [IJSVGFilterPaint pixelTransformForContext:ctx]);
    transform = CGAffineTransformConcat(transform, CGContextGetCTM(ctx));

    // create the pattern
    CGRect selfBounds = IJSVGPaintGetBoundingBoxBounds(self);
    IJSVGPatternDrawingInfo* drawingInfo = [[IJSVGPatternDrawingInfo alloc] initWithPaint:self cellSize:cellSize viewBox:viewBox pixelTransform:pixelTransform];
    CGPatternRef ref = CGPatternCreate((void*)CFBridgingRetain(drawingInfo), CGRectMake(0.f, 0.f, cellSize.width, cellSize.height), transform, cellSize.width, cellSize.height, kCGPatternTilingConstantSpacing, true, &callbacks);

    // set the pattern then release it
    CGFloat alpha = 1.f;
    CGContextSetFillPattern(ctx, ref, &alpha);
    CGPatternRelease(ref);

    // fill it
    CGContextFillRect(ctx, selfBounds);
}

- (void)dealloc
{
    CGImageRelease(_cachedImage);
}

/// Sizes intermediate pattern images using the effective destination scale.
- (void)drawInContext:(CGContextRef)ctx
{
    // Intermediate filter bitmaps require materialized pattern cells.
    // Other destinations retain Core Graphics patterns, including vector PDF output.
    if (![IJSVGFilterPaint isRegisteredBitmapContext:ctx]) {
        [self drawPatternInContext:ctx];
        return;
    }

    CGRect bounds = IJSVGPaintGetBoundingBoxBounds(self);
    if (!IJSVGIsValidContextSize(bounds.size)) {
        return;
    }
    CGFloat scale = MAX(self.backingScaleFactor, 1.f);
    {
        // Match the bitmap to the current size in screen pixels.
        CGAffineTransform transform = [IJSVGFilterPaint pixelTransformForContext:ctx];
        scale = MAX(scale, MAX(hypot(transform.a, transform.b), hypot(transform.c, transform.d)));
    }
    scale = MIN(scale, 4096.f / MAX(bounds.size.width, bounds.size.height));
    scale = MIN(scale, sqrt(4194304.f / (bounds.size.width * bounds.size.height)));
    if (_cachedImage == NULL || _cachedScale != scale || !CGRectEqualToRect(_cachedBounds, bounds)) {
        CGContextRef bitmap = CGBitmapContextCreate(NULL, ceil(bounds.size.width * scale), ceil(bounds.size.height * scale), 8, 0, IJSVGDeviceRGBColorSpace(), (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        if (bitmap == NULL) {
            return;
        }
        CGContextScaleCTM(bitmap, scale, scale);
        [self drawPatternInContext:bitmap];
        CGImageRelease(_cachedImage);
        _cachedImage = CGBitmapContextCreateImage(bitmap);
        _cachedScale = scale;
        _cachedBounds = bounds;
        CGContextRelease(bitmap);
    }
    if (_cachedImage != NULL) {
        CGRect imageRect = CGRectMake(0.f, 0.f, CGImageGetWidth(_cachedImage) / scale, CGImageGetHeight(_cachedImage) / scale);
        CGContextDrawImage(ctx, imageRect, _cachedImage);
    }
}

- (CGRect)transparencyBounds
{
    return self.clipPath != NULL ? CGPathGetBoundingBox(self.clipPath) : self.bounds;
}

@end
