//
//  IJSVGTileLayer.m
//  IJSVG
//
//  Created by Curtis Hard on 29/06/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGTileLayer.h"

@implementation IJSVGTileLayer

@synthesize clipLayers;
@synthesize backingScaleFactor;
@synthesize renderQuality;
@synthesize requiresBackingScale;
@synthesize maskLayer = _maskLayer;
@synthesize fillRule = _fillRule;
@synthesize clipRule = _clipRule;
@synthesize absoluteFrame;
@synthesize boundingBox;
@synthesize outerBoundingBox;
@synthesize filter = _filter;
@synthesize innerBoundingBox;
@synthesize maskingBoundingBox;
@synthesize maskingClippingRect;
@synthesize clippingBoundingBox;
@synthesize clippingTransform;
@synthesize layerTraits = _layerTraits;
@synthesize clipPath = _clipPath;
@synthesize clipPathTransform;
@synthesize referencingLayer = _referencingLayer;
@synthesize absoluteOrigin;
@synthesize blendingMode;
@synthesize colors;

- (void)dealloc
{
    if(_clipPath != NULL) {
        CGPathRelease(_clipPath);
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

- (void)setClipPath:(CGPathRef)clipPath
{
    if(_clipPath != NULL) {
        CGPathRelease(_clipPath);
    }
    _clipPath = CGPathRetain(clipPath);
}

- (NSMapTable<NSNumber*,CALayer<IJSVGDrawableLayer>*>*)layerUsageMapTable
{
    if(_layerUsageMapTable == nil) {
        _layerUsageMapTable = IJSVGLayerDefaultUsageMapTable();
    }
    return _layerUsageMapTable;
}

- (CALayer<IJSVGDrawableLayer>*)layerForUsageType:(IJSVGLayerUsageType)type
{
    return [self.layerUsageMapTable objectForKey:@(type)];
}

- (CALayer<IJSVGDrawableLayer>*)strokeLayer:(IJSVGLayerUsageType*)usageType
{
    CALayer<IJSVGDrawableLayer>* layer = nil;
    if((layer = [self layerForUsageType:IJSVGLayerUsageTypeStrokeGeneric]) != nil) {
        *usageType = IJSVGLayerUsageTypeStrokeGeneric;
        return layer;
    }
    
    if((layer = [self layerForUsageType:IJSVGLayerUsageTypeStrokeGradient]) != nil) {
        *usageType = IJSVGLayerUsageTypeStrokeGradient;
        return layer;
    }
    
    if((layer = [self layerForUsageType:IJSVGLayerUsageTypeStrokePattern]) != nil) {
        *usageType = IJSVGLayerUsageTypeStrokePattern;
        return layer;
    }
    return nil;
}

- (void)setLayer:(CALayer<IJSVGDrawableLayer>*)layer
    forUsageType:(IJSVGLayerUsageType)type
{
    [self.layerUsageMapTable setObject:layer
                                forKey:@(type)];
}

- (void)addTraits:(IJSVGLayerTraits)traits
{
    _layerTraits |= traits;
}

- (void)removeTraits:(IJSVGLayerTraits)traits
{
    _layerTraits = _layerTraits & ~traits;
}

- (BOOL)matchesTraits:(IJSVGLayerTraits)traits
{
    return (_layerTraits & traits) == traits;
}

- (BOOL)treatImplicitOriginAsTransform
{
    return YES;
}

- (CALayer<IJSVGDrawableLayer>*)firstSublayerOfClass:(Class)aClass
{
    return [IJSVGLayer firstSublayerOfClass:aClass
                                  fromLayer:self];
}

@end
