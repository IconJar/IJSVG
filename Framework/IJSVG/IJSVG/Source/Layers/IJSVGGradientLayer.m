//
//  IJSVGGradientLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradientLayer.h>
#import <IJSVG/IJSVGRootLayer.h>
#import <IJSVG/IJSVGThreadManager.h>

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
        if(IJSVGColorAlphaComponent(color) != 1.f) {
            hasAlphaChannel = YES;
            break;
        }
    }
    self.opaque = hasAlphaChannel == NO;
}

- (void)setOpacity:(float)opacity
{
    if(opacity != 1.f) {
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
    if(self.gradient == nil) {
        return;
    }

    // perform the draw
    CGRect bounds = CGRectZero;
    CGAffineTransform transform = CGAffineTransformIdentity;
    CALayer<IJSVGDrawableLayer>* layer = (CALayer<IJSVGDrawableLayer>*)self.referencingLayer;
    if(self.gradient.units == IJSVGUnitUserSpaceOnUse) {
        CALayer<IJSVGDrawableLayer>* rootCandidate = [IJSVGLayer rootLayerForLayer:self];
        if([rootCandidate isKindOfClass:IJSVGRootLayer.class]) {
            IJSVGRootLayer* rootNode = (IJSVGRootLayer*)rootCandidate;
            bounds = [rootNode.viewBox computeValue:CGSizeZero];
        } else {
            bounds = layer.frame;
        }
        transform = [IJSVGLayer userSpaceTransformForLayer:layer];

        // When rendering inside a filter context, the element was moved to (0,0)
        // but the gradient needs the original position to compute coordinates.
        NSValue* filterOffset = [IJSVGThreadManager.currentManager userInfoObjectForKey:@"IJSVGFilterElementOffset"];
        // In filter rendering we only need to restore the saved offset for the
        // top-level filtered layer that was normalized to the origin. Descendant
        // layers still carry their absolute outerBoundingBox, so applying the
        // saved element offset again shifts user-space gradients twice.
        if(filterOffset != nil &&
           CGRectGetMinX(layer.outerBoundingBox) == 0.f &&
           CGRectGetMinY(layer.outerBoundingBox) == 0.f) {
            NSPoint offset = filterOffset.pointValue;
            transform = CGAffineTransformTranslate(transform, -offset.x, -offset.y);
        }
    } else {
        bounds = IJSVGLayerGetBoundingBoxBounds(layer);
    }
    
    // its possible that this layer is shifted inwards due to a stroke on the
    // parent layer
    transform = CGAffineTransformConcat(transform, [IJSVGLayer userSpaceTransformForLayer:self]);
    
    [self.gradient drawInContextRef:ctx
                             bounds:bounds
                          transform:transform];
}

- (IJSVGTraitedColorStorage*)colors
{
    IJSVGTraitedColorStorage* list = [[IJSVGTraitedColorStorage alloc] init];
    for(NSColor* color in self.gradient.colors) {
        IJSVGTraitedColor* traited = nil;
        traited = [IJSVGTraitedColor colorWithColor:color
                                             traits:IJSVGColorUsageTraitNone];
        [list addColor:traited];
    }
    return list;
}

@end
