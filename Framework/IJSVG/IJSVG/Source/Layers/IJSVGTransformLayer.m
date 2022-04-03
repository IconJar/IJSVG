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
@synthesize requiresBackingScaleHelp;
@synthesize maskLayer = _maskLayer;
@synthesize fillRule = _fillRule;
@synthesize clipRule = _clipRule;
@synthesize absoluteFrame;

- (void)dealloc
{
    (void)[_maskLayer release], _maskLayer = nil;
    (void)[_fillRule release], _fillRule = nil;
    (void)[_clipRule release], _clipRule = nil;
    (void)[_clipLayer release], _clipLayer = nil;
    [super dealloc];
}

- (CALayer<IJSVGDrawableLayer> *)referencedLayer
{
    return self.sublayers.firstObject;
}

- (CALayer<IJSVGDrawableLayer>*)rootLayer
{
    return [IJSVGLayer rootLayerForLayer:self];
}

- (BOOL)requiresBackingScaleHelp
{
    return YES;
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    // do nothing, this does nothing as a group
}

@end
