//
//  IJSVGImagePaint.m
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <IJSVGImagePaint.h>

@implementation IJSVGImagePaint

- (id)initWithImage:(IJSVGImage*)image
{
    if ((self = [super init]) != nil) {
        _image = image;
    }
    return self;
}

- (BOOL)treatImplicitOriginAsTransform
{
    return NO;
}

- (void)drawInContext:(CGContextRef)ctx
{
    CGImageRef image = _image.CGImage;
    CGRect imageDrawRect = _image.intrinsicBounds;
    CGRect currentBounds = self.bounds;

    // `preserveAspectRatio` must be resolved in the images own coordinate space,
    // not against the paint frame. When an image is used as objectBoundingBox
    // pattern content the frame has the non uniform bounding box scale baked into
    // it, so fitting the raster directly against the frame would letterbox it and
    // then the outer transform squashes the result.
    CGRect imageBounds = _image.bounds;
    if (CGRectGetWidth(imageBounds) <= 0.f || CGRectGetHeight(imageBounds) <= 0.f) {
        imageBounds = currentBounds;
    }

    if (CGRectGetWidth(imageBounds) <= 0.f || CGRectGetHeight(imageBounds) <= 0.f || CGRectGetWidth(currentBounds) <= 0.f || CGRectGetHeight(currentBounds) <= 0.f) {
        return;
    }

    CGAffineTransform scale = CGAffineTransformMakeScale(CGRectGetWidth(currentBounds) / CGRectGetWidth(imageBounds), CGRectGetHeight(currentBounds) / CGRectGetHeight(imageBounds));

    IJSVG* vectorSVG = _image.embeddedSVG;
    IJSVGViewBoxDrawingBlock drawBlock = ^(CGFloat scale[]) {
        if (vectorSVG != nil) {
            // SVG already uses downward y coordinates. Draw it at the destination
            // resolution without an intermediate raster image.
            [vectorSVG drawInRect:imageDrawRect context:ctx];
            return;
        }

        // image will be upside down, so just translate it back on itself
        CGContextConcatCTM(ctx, CGAffineTransformMakeScale(1.f, -1.f));
        CGContextTranslateCTM(ctx, 0.f, -CGRectGetHeight(imageDrawRect));
        CGContextDrawImage(ctx, imageDrawRect, image);
    };

    IJSVGViewBoxAlignment alignment = _image.viewBoxAlignment;
    if (vectorSVG.rootNode.viewBoxWasInferred) {
        alignment = IJSVGViewBoxAlignmentNone;
    }
    CGContextSaveGState(ctx);
    switch (self.imageRendering) {
        case IJSVGImageRenderingOptimizeSpeed:
            CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
            break;
        case IJSVGImageRenderingOptimizeQuality:
            CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
            break;
        default:
            break;
    }
    CGContextConcatCTM(ctx, scale);
    if (alignment != IJSVGViewBoxAlignmentNone && _image.viewBoxMeetOrSlice == IJSVGViewBoxMeetOrSliceSlice && _image.overflowVisibility != IJSVGOverflowVisibilityVisible) {
        CGContextClipToRect(ctx, imageBounds);
    }
    IJSVGContextDrawViewBox(ctx, imageDrawRect, imageBounds, alignment, _image.viewBoxMeetOrSlice, drawBlock);
    CGContextRestoreGState(ctx);
}

- (CGRect)transparencyBounds
{
    return self.bounds;
}

@end
