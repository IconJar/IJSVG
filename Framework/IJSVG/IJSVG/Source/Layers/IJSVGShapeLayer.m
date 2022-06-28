//
//  IJSVGShapeLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroupLayer.h>
#import <IJSVG/IJSVGShapeLayer.h>

@implementation IJSVGShapeLayer

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

- (CGRect)innerBoundingBox
{
    return self.bounds;
}

- (BOOL)requiresBackingScale
{
    return _maskLayer != nil || (_clipLayers != nil && _clipLayers.count != 0);
}

- (void)setClipPath:(CGPathRef)clipPath
{
    if(_clipPath != NULL) {
        CGPathRelease(_clipPath);
    }
    _clipPath = CGPathRetain(clipPath);
}

- (void)setBackingScaleFactor:(CGFloat)newFactor
{
    if (_backingScaleFactor == newFactor) {
        return;
    }
        
    _backingScaleFactor = newFactor;
    self.contentsScale = newFactor;
    self.rasterizationScale = newFactor;
    
    // make sure its applied to any mask or clipPath
    _maskLayer.backingScaleFactor = newFactor;
    
    for(CALayer<IJSVGDrawableLayer>* clipLayer in _clipLayers) {
        clipLayer.backingScaleFactor = newFactor;
    }
    
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
                  inContext:ctx
                    options:IJSVGLayerDrawingOptionNone];
}

- (NSMapTable<NSNumber*,CALayer<IJSVGDrawableLayer>*>*)layerUsageMapTable
{
    if(_layerUsageMapTable == nil) {
        _layerUsageMapTable = IJSVGLayerDefaultUsageMapTable();
    }
    return _layerUsageMapTable;
}

- (void)setLayer:(CALayer<IJSVGDrawableLayer>*)layer
    forUsageType:(IJSVGLayerUsageType)type
{
    [self.layerUsageMapTable setObject:layer
                                forKey:@(type)];
}

- (CALayer<IJSVGDrawableLayer>*)layerForUsageType:(IJSVGLayerUsageType)type
{
    return [self.layerUsageMapTable objectForKey:@(type)];
}

-(NSArray<CALayer<IJSVGDrawableLayer>*>*)debugLayers
{
    return self.sublayers;
}

- (BOOL)treatImplicitOriginAsTransform
{
    return YES;
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

- (CALayer<IJSVGDrawableLayer>*)firstSublayerOfClass:(Class)aClass
{
    return [IJSVGLayer firstSublayerOfClass:aClass
                                  fromLayer:self];
}

@end
