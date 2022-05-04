//
//  IJSVGGradientLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradientLayer.h>
#import <IJSVG/IJSVGRootLayer.h>

@implementation IJSVGGradientLayer

- (BOOL)requiresBackingScale
{
    return YES;
}

- (void)setGradient:(IJSVGGradient*)newGradient
{
    _gradient = newGradient;

    // lets check its alpha properties on the colors
    BOOL hasAlphaChannel = NO;
    for (NSColor* color in newGradient.colors) {
        if (color.alphaComponent != 1.f) {
            hasAlphaChannel = YES;
            break;
        }
    }
    self.opaque = hasAlphaChannel == NO;
}

- (void)setOpacity:(float)opacity
{
    if (opacity != 1.f) {
        self.opaque = NO;
    }
    [super setOpacity:opacity];
}

- (void)setBackingScaleFactor:(CGFloat)backingScaleFactor
{
    switch (self.renderQuality) {
        case kIJSVGRenderQualityOptimized: {
            backingScaleFactor = (backingScaleFactor * .35f);
            break;
        }
        case kIJSVGRenderQualityLow: {
            backingScaleFactor = (backingScaleFactor * .05f);
            break;
        }
        default: {
            break;
        }
    }
    [super setBackingScaleFactor:backingScaleFactor];
}

- (CALayer<IJSVGDrawableLayer> *)referencingLayer
{
    return [super referencingLayer] ?: self.superlayer;
}

- (void)drawInContext:(CGContextRef)ctx
{
    [super drawInContext:ctx];

    // nothing to do :(
    if (self.gradient == nil) {
        return;
    }

    // draw the gradient
    CALayer<IJSVGDrawableLayer>* layer = (CALayer<IJSVGDrawableLayer>*)self.referencingLayer;
    CGRect objectRect = layer.boundingBox;
    CGRect objectFrame = layer.frame;
    CGAffineTransform affine = [IJSVGLayer absoluteTransformForLayer:layer];
    affine = CGAffineTransformTranslate(affine,
                                        -CGRectGetMinX(objectFrame),
                                        -CGRectGetMinY(objectFrame));
    CGContextSaveGState(ctx);
    
    IJSVGRootLayer* rootNode = (IJSVGRootLayer*)[IJSVGLayer rootLayerForLayer:self];
    CGRect bounds = [rootNode.viewBox computeValue:CGSizeZero];
    
    [self.gradient drawInContextRef:ctx
                         objectRect:objectRect
                  absoluteTransform:affine
                           viewPort:bounds];
    CGContextRestoreGState(ctx);
}

@end
