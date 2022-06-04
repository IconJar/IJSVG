//
//  IJSVGTransformLayer.m
//  IJSVG
//
//  Created by Curtis Hard on 31/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTransformLayer.h>

@implementation IJSVGTransformLayer

@synthesize clipLayers;
@synthesize backingScaleFactor;
@synthesize renderQuality;
@synthesize requiresBackingScale;
@synthesize maskLayer = _maskLayer;
@synthesize fillRule = _fillRule;
@synthesize clipRule = _clipRule;
@synthesize absoluteFrame;
@synthesize boundingBox;
@synthesize boundingBoxBounds;
@synthesize outerBoundingBox;
@synthesize filter = _filter;
@synthesize innerBoundingBox;
@synthesize maskingBoundingBox;
@synthesize maskingClippingRect;
@synthesize clippingBoundingBox;
@synthesize clippingTransform;
@synthesize clipPath;
@synthesize clipPathTransform;

- (void)dealloc
{
    if(clipPath != NULL) {
        CGPathRelease(clipPath);
    }
}

- (id<CAAction>)actionForKey:(NSString*)event
{
    return nil;
}

- (CALayer<IJSVGDrawableLayer> *)referencedLayer
{
    return self.sublayers.firstObject;
}

- (CALayer<IJSVGDrawableLayer> *)referencingLayer
{
    return _referencingLayer ?: self.superlayer;
}

- (void)renderInContext:(CGContextRef)ctx
{
    [IJSVGLayer renderLayer:self
                  inContext:ctx
                    options:IJSVGLayerDrawingOptionNone];
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
