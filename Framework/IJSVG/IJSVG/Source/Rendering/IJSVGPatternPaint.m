//
//  IJSVGPatternPaint.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGPatternPaint.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGUtils.h>

@interface IJSVGPatternPaint () {
    CGImageRef _cachedImage;
    CGFloat _cachedScale;
    CGRect _cachedBounds;
}

@property (nonatomic, assign) CGSize cellSize;
@property (nonatomic, assign) CGRect viewBox;
@end

@implementation IJSVGPatternPaint

static void IJSVGQuartzPatternRelease(void* info)
{
    CFRelease(info);
}

static void IJSVGQuartzPatternDrawingCallBack(void* info, CGContextRef ctx)
{
    // reassign the paint
    IJSVGPatternPaint* paint = (__bridge IJSVGPatternPaint*)info;
    CGSize size = paint.cellSize;
    CGContextSaveGState(ctx);
    CGRect rect = CGRectMake(0.f, 0.f, size.width, size.height);
    CGContextClipToRect(ctx, rect);

    IJSVGViewBoxAlignment alignment = paint.patternNode.viewBoxAlignment;
    IJSVGViewBoxMeetOrSlice meetOrSlice = paint.patternNode.viewBoxMeetOrSlice;
    CGRect viewBox = paint.viewBox;
    IJSVGViewBoxDrawingBlock drawBlock = ^(CGFloat scale[]) {
        [IJSVGPaint renderPaint:paint.pattern
                      inContext:ctx
                        options:IJSVGPaintDrawingOptionNone];
    };
    IJSVGContextDrawViewBox(ctx, viewBox, rect, alignment, meetOrSlice,
                            drawBlock);
    CGContextRestoreGState(ctx);
}
- (void)computeCellSize:(CGSize*)cellSize
                viewBox:(CGRect*)viewBox
                 origin:(CGPoint*)origin
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
    if(_patternNode.units == IJSVGUnitObjectBoundingBox) {
        wLength = wLength.lengthByMatchingPercentage;
        hLength = hLength.lengthByMatchingPercentage;
        xLength = xLength.lengthByMatchingPercentage;
        yLength = yLength.lengthByMatchingPercentage;
    }

    *origin = CGPointMake([xLength computeValue:rect.size.width],
                          [yLength computeValue:rect.size.height]);

    CGFloat width = [wLength computeValue:rect.size.width];
    CGFloat height = [hLength computeValue:rect.size.height];
    *cellSize = CGSizeMake(width, height);

    // who knew that patterns have viewBoxes? Not me, but here is an implementation
    // of it anyway
    if(_patternNode.viewBox != nil && _patternNode.viewBox.isZeroRect == NO) {
        IJSVGUnitRect* nViewBox = _patternNode.viewBox;
        if(_patternNode.contentUnits == IJSVGUnitObjectBoundingBox) {
            nViewBox = [nViewBox copyByConvertingToUnitsLengthType:IJSVGUnitLengthTypePercentage];
        }
        *viewBox = [nViewBox computeValue:rect.size];
    } else {
        // no viewbox is assigned, so just map it 1:1 with its cellSize
        *viewBox = CGRectMake(0.f, 0.f, cellSize->width, cellSize->height);
    }
}
- (void)drawPatternInContext:(CGContextRef)ctx
{
    // holder for callback
    static const CGPatternCallbacks callbacks = {
      0, &IJSVGQuartzPatternDrawingCallBack, &IJSVGQuartzPatternRelease
    };

    // create base pattern space
    CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern(NULL);
    CGContextSetFillColorSpace(ctx, patternSpace);
    CGColorSpaceRelease(patternSpace);

    IJSVGPaint* paint = (IJSVGPaint*)self.referencingPaint;

    // transform us back into the correct space
    CGAffineTransform transform = CGAffineTransformIdentity;
    if(_patternNode.units == IJSVGUnitUserSpaceOnUse) {
        transform = [IJSVGPaint userSpaceTransformForPaint:paint];
    }

    CGPoint origin = CGPointZero;
    [self computeCellSize:&_cellSize
                  viewBox:&_viewBox
                   origin:&origin];

    // transform the X and Y shift
    transform = CGAffineTransformConcat(transform, IJSVGConcatTransforms(self.patternNode.transforms));
    transform = CGAffineTransformTranslate(transform, origin.x, origin.y);

    // its possible that this paint is shifted inwards due to a stroke on the
    // parent paint
    transform = CGAffineTransformConcat(transform, [IJSVGPaint userSpaceTransformForPaint:self]);

    if(_cellSize.width <= 0.f || _cellSize.height <= 0.f ||
        !isfinite(_cellSize.width) || !isfinite(_cellSize.height)) {
        return;
    }
    // Reduce the phase before device space tiling. Large SVG translations
    // otherwise amplify the pixel rounding of the constant spacing of CGPattern.
    CGAffineTransform linear = transform;
    linear.tx = 0.f;
    linear.ty = 0.f;
    CGFloat determinant = linear.a * linear.d - linear.b * linear.c;
    if(determinant != 0.f) {
        CGPoint phase = CGPointApplyAffineTransform(CGPointMake(transform.tx, transform.ty),
                                                    CGAffineTransformInvert(linear));
        phase.x = fmod(phase.x, _cellSize.width);
        phase.y = fmod(phase.y, _cellSize.height);
        phase = CGPointApplyAffineTransform(phase, linear);
        transform.tx = phase.x;
        transform.ty = phase.y;
    }
    transform = CGAffineTransformConcat(transform, CGContextGetCTM(ctx));

    // create the pattern
    CGRect selfBounds = IJSVGPaintGetBoundingBoxBounds(self);
    CGPatternRef ref = CGPatternCreate((void*)CFBridgingRetain(self),
                                       CGRectMake(0.f, 0.f, _cellSize.width, _cellSize.height),
                                       transform, _cellSize.width, _cellSize.height,
                                       kCGPatternTilingConstantSpacing,
                                       true, &callbacks);

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

- (void)drawInContext:(CGContextRef)ctx
{
    // Keep vector patterns for PDF destinations. Bitmap destinations reuse a
    // Quartz backing image, avoiding repeated cell rendering on every repaint.
    if(CGBitmapContextGetData(ctx) == NULL) {
        [self drawPatternInContext:ctx];
        return;
    }
    CGRect bounds = IJSVGPaintGetBoundingBoxBounds(self);
    if(!IJSVGIsValidContextSize(bounds.size)) {
        return;
    }
    CGFloat scale = MAX(self.backingScaleFactor, 1.f);
    scale = MIN(scale, 4096.f / MAX(bounds.size.width, bounds.size.height));
    scale = MIN(scale, sqrt(4194304.f / (bounds.size.width * bounds.size.height)));
    if(_cachedImage == NULL || _cachedScale != scale || !CGRectEqualToRect(_cachedBounds, bounds)) {
        CGContextRef bitmap = CGBitmapContextCreate(NULL, ceil(bounds.size.width * scale),
                                                    ceil(bounds.size.height * scale), 8, 0,
                                                    IJSVGDeviceRGBColorSpace(),
                                                    (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        if(bitmap == NULL) {
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
    if(_cachedImage != NULL) {
        CGRect imageRect = CGRectMake(0.f, 0.f, CGImageGetWidth(_cachedImage) / scale,
                                      CGImageGetHeight(_cachedImage) / scale);
        CGContextDrawImage(ctx, imageRect, _cachedImage);
    }
}

- (CGRect)transparencyBounds
{
    return self.clipPath != NULL ? CGPathGetBoundingBox(self.clipPath) : self.bounds;
}

@end
