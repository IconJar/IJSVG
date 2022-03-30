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
    (void)([_maskingLayer release]), _maskingLayer = nil;
    [super dealloc];
}

- (CGRect)computedFrame
{
    return [self absoluteFrame];
}

- (CGRect)absoluteFrame
{
    return (CGRect) {
      .origin = self.absoluteOrigin,
      .size = self.frame.size
    };
}

- (BOOL)requiresBackingScaleHelp
{
    return self.mask != nil;
}

- (void)setBackingScaleFactor:(CGFloat)newFactor
{
    if (self.backingScaleFactor == newFactor) {
        return;
    }
    _backingScaleFactor = newFactor;
    self.contentsScale = newFactor;
    self.rasterizationScale = newFactor;
    if(self.mask != nil) {
        self.mask.contentsScale = newFactor;
        self.mask.rasterizationScale = newFactor;
        [self.mask setNeedsDisplay];
    }
    [self setNeedsDisplay];
}

- (void)performRenderInContext:(CGContextRef)ctx
{
//    if (self.convertMasksToPaths == YES && _maskingLayer != nil) {
//        CGContextSaveGState(ctx);
//        [self applySublayerMaskToContext:ctx
//                             forSublayer:(IJSVGLayer*)self
//                              withOffset:CGPointZero];
//        [super renderInContext:ctx];
//        CGContextRestoreGState(ctx);
//        return;
//    }
//    [super renderInContext:ctx];
    if(self.mask != nil) {
        IJSVGLayer* mask = self.mask;
        self.mask = nil;
        [IJSVGLayer clipContextWithMask:mask
                                toLayer:self
                              inContext:ctx
                           drawingBlock:^{
            [super renderInContext:ctx];
        }];
        self.mask = mask;
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

- (CGPoint)absoluteOrigin
{
    CGPoint point = CGPointZero;
    CALayer* pLayer = self;
    while (pLayer != nil) {
        point.x += pLayer.frame.origin.x;
        point.y += pLayer.frame.origin.y;
        pLayer = pLayer.superlayer;
    }
    return point;
}

- (id<CAAction>)actionForKey:(NSString*)event
{
    return nil;
}

@end
