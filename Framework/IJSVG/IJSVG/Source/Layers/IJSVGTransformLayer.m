//
//  IJSVGTransformLayer.m
//  IJSVG
//
//  Created by Curtis Hard on 31/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGTransformLayer.h"

@implementation IJSVGTransformLayer

@synthesize backingScaleFactor;
@synthesize renderQuality;
@synthesize requiresBackingScale;
@synthesize maskLayer = _maskLayer;
@synthesize fillRule = _fillRule;
@synthesize clipRule = _clipRule;
@synthesize absoluteFrame;
@synthesize boundingBox;
@synthesize boundingBoxBounds;
@synthesize strokeBoundingBox;
@synthesize outerBoundingBox;
@synthesize filter = _filter;
@synthesize innerBoundingBox;

- (CALayer<IJSVGDrawableLayer> *)referencedLayer
{
    return self.sublayers.firstObject;
}

- (CALayer<IJSVGDrawableLayer> *)referencingLayer {
    return _referencingLayer ?: self.superlayer;
}

- (CALayer<IJSVGDrawableLayer>*)rootLayer
{
    return [IJSVGLayer rootLayerForLayer:self];
}

- (void)renderInContext:(CGContextRef)ctx
{
    [IJSVGLayer renderLayer:self
                  inContext:ctx];
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    [super renderInContext:ctx];
}

- (NSArray<CALayer<IJSVGDrawableLayer>*>*)debugLayers
{
    return self.sublayers;
}

@end
