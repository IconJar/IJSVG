//
//  IJSVGImageLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGImageLayer.h>

@implementation IJSVGImageLayer

- (id)initWithImage:(IJSVGImage*)image
{
    if((self = [super init]) != nil) {
        self.image = image;
    }
    return self;
}

- (BOOL)requiresBackingScale
{
    return YES;
}

- (void)setImage:(IJSVGImage *)image
{
    _image = image;
    [self setNeedsDisplay];
}

- (void)drawInContext:(CGContextRef)ctx
{
    CGImageRef image = _image.CGImage;
    CGRect imageDrawRect = _image.intrinsicBounds;
    CGRect currentBounds = self.bounds;

    // `preserveAspectRatio` must be resolved in the images own coordinate space,
    // not against the layer frame. When an image is used as objectBoundingBox
    // pattern content the frame has the non-uniform bounding-box scale baked into it,
    // so fitting the raster directly against the frame would letterbox it and then the
    // outer transform squashes the result.
    CGRect imageBounds = _image.bounds;
    if(CGRectGetWidth(imageBounds) <= 0.f || CGRectGetHeight(imageBounds) <= 0.f) {
        imageBounds = currentBounds;
    }
  
    if(CGRectGetWidth(imageBounds) <= 0.f || CGRectGetHeight(imageBounds) <= 0.f ||
       CGRectGetWidth(currentBounds) <= 0.f || CGRectGetHeight(currentBounds) <= 0.f) {
        return;
    }
  
    CGAffineTransform scale =
        CGAffineTransformMakeScale(CGRectGetWidth(currentBounds) / CGRectGetWidth(imageBounds),
                                   CGRectGetHeight(currentBounds) / CGRectGetHeight(imageBounds));

    IJSVGViewBoxDrawingBlock drawBlock = ^(CGFloat scale[]) {
        // image will be upside down, so just translate it back on itself
        CGContextConcatCTM(ctx, CGAffineTransformMakeScale(1.f, -1.f));
        CGContextTranslateCTM(ctx, 0.f, -CGRectGetHeight(imageDrawRect));
        CGContextDrawImage(ctx, imageDrawRect, image);
    };

    CGContextSaveGState(ctx);
    CGContextConcatCTM(ctx, scale);
    IJSVGContextDrawViewBox(ctx, imageDrawRect, imageBounds,
                            _image.viewBoxAlignment,
                            _image.viewBoxMeetOrSlice, drawBlock);
    CGContextRestoreGState(ctx);
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    if(self.maskLayer != nil) {
        [IJSVGLayer clipContextWithMask:self.maskLayer
                                toLayer:self
                              inContext:ctx
                           drawingBlock:^{
            [super performRenderInContext:ctx];
        }];
        return;
    }
    if(self.sublayers.count == 0) {
        if(self.hidden == YES || self.opacity == 0.f) {
            return;
        }
        CGContextSaveGState(ctx);
        if(self.opacity != 1.f) {
            CGContextSetAlpha(ctx, self.opacity);
        }
        [self drawInContext:ctx];
        CGContextRestoreGState(ctx);
        return;
    }
    [super performRenderInContext:ctx];
}

@end
