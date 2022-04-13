//
//  IJSVGShapeLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGGroupLayer.h"
#import "IJSVGShapeLayer.h"

@implementation IJSVGShapeLayer

- (void)dealloc
{
    (void)([_clipLayer release]), _clipLayer = nil;
    (void)([_maskLayer release]), _maskLayer = nil;
    (void)([_maskingLayer release]), _maskingLayer = nil;
    (void)([_clipRule release]), _clipRule = nil;
    [super dealloc];
}

- (CALayer<IJSVGDrawableLayer> *)rootLayer
{
    return [IJSVGLayer rootLayerForLayer:self];
}

- (CGRect)absoluteFrame
{
    return [IJSVGLayer absoluteFrameForLayer:self];
}

- (CGAffineTransform)absoluteTransform
{
    return [IJSVGLayer absoluteTransformForLayer:self];
}

- (CALayer<IJSVGDrawableLayer> *)referencingLayer
{
    return _referencingLayer ?: self.superlayer;
}

- (CGRect)boundingBoxBounds
{
    return (CGRect) {
        .origin = CGPointZero,
        .size = self.boundingBox.size
    };
}

- (BOOL)requiresBackingScaleHelp
{
    return _maskLayer != nil || _clipLayer != nil;
}

- (void)setBackingScaleFactor:(CGFloat)newFactor
{
    if (self.backingScaleFactor == newFactor) {
        return;
    }
    _backingScaleFactor = newFactor;
    self.contentsScale = newFactor;
    self.rasterizationScale = newFactor;
    
    // make sure its applied to any mask or clipPath
    _maskLayer.backingScaleFactor = newFactor;
    _clipLayer.backingScaleFactor = newFactor;
    
    [self setNeedsDisplay];
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    if(_maskLayer != nil) {
        [IJSVGLayer clipContextWithMask:_maskLayer
                                toLayer:self
                              inContext:ctx
                           drawingBlock:^{
            [super renderInContext:ctx];
        }];
        return;
    }
    [super renderInContext:ctx];
}

- (void)setConvertMasksToPaths:(BOOL)flag
{
    if (_convertMasksToPaths == flag) {
        return;
    }
    _convertMasksToPaths = flag;
    if (flag == YES) {
        if (_maskingLayer != nil) {
            (void)([_maskingLayer release]), _maskingLayer = nil;
        }
        _maskingLayer = [(IJSVGLayer*)self.mask retain];
        self.mask = nil;
    } else {
        self.mask = _maskingLayer;
        (void)([_maskingLayer release]), _maskingLayer = nil;
    }
}

- (void)applySublayerMaskToContext:(CGContextRef)context
                       forSublayer:(IJSVGLayer*)sublayer
                        withOffset:(CGPoint)offset
{
    // apply any transforms needed
    CGPoint layerOffset = offset;
    CGAffineTransform sublayerTransform = CATransform3DGetAffineTransform(sublayer.transform);
    CGContextConcatCTM(context, CGAffineTransformInvert(sublayerTransform));

    // walk up the superlayer chain
    CALayer* superlayer = self.superlayer;
    if (IJSVGIsSVGLayer(superlayer) == YES) {
        [(IJSVGLayer*)superlayer applySublayerMaskToContext:context
                                                forSublayer:(IJSVGLayer*)self
                                                 withOffset:layerOffset];
    }

    // grab the masking layer
    IJSVGShapeLayer* maskingLayer = [self maskingLayer];

    // if its a group we need to get the lowest level children
    // and walk up the chain again
    if ([maskingLayer isKindOfClass:[IJSVGGroupLayer class]]) {
        NSArray* subs = [IJSVGLayer deepestSublayersOfLayer:maskingLayer];
        for (IJSVGLayer* subLayer in subs) {
            [subLayer applySublayerMaskToContext:context
                                     forSublayer:(IJSVGLayer*)self
                                      withOffset:layerOffset];
        }
    } else if ([maskingLayer isKindOfClass:[IJSVGShapeLayer class]]) {
        // is a shape, go for it!
        CGPathRef maskPath = maskingLayer.path;
        CGContextTranslateCTM(context, -layerOffset.x, -layerOffset.y);
        CGContextAddPath(context, maskPath);
        CGContextClip(context);
        CGContextTranslateCTM(context, layerOffset.x, layerOffset.y);
    }
    CGContextConcatCTM(context, sublayerTransform);
}

- (IJSVGShapeLayer*)maskingLayer
{
    return (IJSVGShapeLayer*)_maskingLayer ?: nil;
}

- (void)renderInContext:(CGContextRef)ctx
{
    [IJSVGLayer renderLayer:(IJSVGLayer*)self
                  inContext:ctx];
}

- (id<CAAction>)actionForKey:(NSString*)event
{
    return nil;
}

-(NSArray<CALayer<IJSVGDrawableLayer>*>*)debugLayers
{
    return self.sublayers;
}

@end
