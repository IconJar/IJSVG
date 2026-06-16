//
//  IJSVGShapeLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroupLayer.h>
#import <IJSVG/IJSVGShapeLayer.h>
#import <IJSVG/IJSVGStrokeLayer.h>
#import <IJSVG/IJSVGGradientLayer.h>
#import <IJSVG/IJSVGTraitedColorStorage.h>
#import <IJSVG/IJSVGPatternLayer.h>

@implementation IJSVGShapeLayer

@synthesize backingScaleFactor = _backingScaleFactor;
@synthesize requiresBackingScale;
@synthesize renderQuality;
@synthesize blendingMode;
@synthesize absoluteOrigin;
@synthesize clipPath = _clipPath;
@synthesize clipRule;
@synthesize clipLayers = _clipLayers;
@synthesize clippingTransform;
@synthesize clippingBoundingBox;
@synthesize maskingClippingRect;
@synthesize clipPathTransform;
@synthesize colors;
@synthesize boundingBox;
@synthesize layerTraits = _layerTraits;
@synthesize maskingBoundingBox;
@synthesize filter;
@synthesize referencingLayer = _referencingLayer;
@synthesize outerBoundingBox;
@synthesize maskLayer = _maskLayer;
@synthesize treatImplicitOriginAsTransform;

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
    if(_backingScaleFactor == newFactor) {
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

static void IJSVGShapeLayerApplyDashPattern(IJSVGShapeLayer* layer, CGContextRef ctx)
{
    NSArray<NSNumber*>* dashPattern = layer.lineDashPattern;
    if(dashPattern == nil || dashPattern.count == 0) {
        CGContextSetLineDash(ctx, 0.f, NULL, 0);
        return;
    }
    NSUInteger count = dashPattern.count;
    CGFloat* lengths = (CGFloat*)malloc(sizeof(CGFloat)*count);
    NSUInteger i = 0;
    for(NSNumber* number in dashPattern) {
        lengths[i++] = (CGFloat)number.floatValue;
    }
    CGContextSetLineDash(ctx, layer.lineDashPhase, lengths, count);
    (void)free(lengths), lengths = NULL;
}

static void IJSVGShapeLayerDrawPath(IJSVGShapeLayer* layer, CGContextRef ctx)
{
    if(layer.path == NULL || layer.opacity == 0.f || layer.hidden == YES) {
        return;
    }
    CGContextSaveGState(ctx);
    if(layer.opacity != 1.f) {
        CGContextSetAlpha(ctx, layer.opacity);
    }
    CGColorRef fillColor = layer.fillColor;
    if(fillColor != NULL) {
        CGContextAddPath(ctx, layer.path);
        CGContextSetFillColorWithColor(ctx, fillColor);
        if([layer.fillRule isEqualToString:kCAFillRuleEvenOdd]) {
            CGContextEOFillPath(ctx);
        } else {
            CGContextFillPath(ctx);
        }
    }
    CGColorRef strokeColor = layer.strokeColor;
    if(strokeColor != NULL && layer.lineWidth > 0.f) {
        CGContextAddPath(ctx, layer.path);
        CGContextSetStrokeColorWithColor(ctx, strokeColor);
        CGContextSetLineWidth(ctx, layer.lineWidth);
        CGContextSetLineCap(ctx, [IJSVGUtils CGLineCapForCALineCap:layer.lineCap]);
        CGContextSetLineJoin(ctx, [IJSVGUtils CGLineJoinForCALineJoin:layer.lineJoin]);
        CGContextSetMiterLimit(ctx, layer.miterLimit);
        IJSVGShapeLayerApplyDashPattern(layer, ctx);
        CGContextStrokePath(ctx);
    }
    CGContextRestoreGState(ctx);
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
    if(self.sublayers.count == 0) {
        IJSVGShapeLayerDrawPath(self, ctx);
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
    if(IJSVGIsSVGLayer(superlayer) == YES) {
        [(IJSVGLayer*)superlayer applySublayerMaskToContext:context
                                                forSublayer:(IJSVGLayer*)self
                                                 withOffset:layerOffset];
    }

    // grab the masking layer
    IJSVGShapeLayer* maskingLayer = [self maskingLayer];

    // if its a group we need to get the lowest level children
    // and walk up the chain again
    if([maskingLayer isKindOfClass:[IJSVGGroupLayer class]]) {
        NSArray* subs = [IJSVGLayer deepestSublayersOfLayer:maskingLayer];
        for (IJSVGLayer* subLayer in subs) {
            [subLayer applySublayerMaskToContext:context
                                     forSublayer:(IJSVGLayer*)self
                                      withOffset:layerOffset];
        }
    } else if([maskingLayer isKindOfClass:[IJSVGShapeLayer class]]) {
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

- (IJSVGTraitedColorStorage*)colors
{
    IJSVGTraitedColorStorage* list = [[IJSVGTraitedColorStorage alloc] init];
    
    // we have a fill color
    if([self matchesTraits:IJSVGLayerTraitFilled] == YES) {
        IJSVGShapeLayer* fillLayer = nil;
        if((fillLayer = (IJSVGShapeLayer*)[self layerForUsageType:IJSVGLayerUsageTypeFillGeneric]) != nil) {
            CGColorRef colorRef = NULL;
            if((colorRef = fillLayer.fillColor) != NULL) {
                NSColor* nsColor = [NSColor colorWithCGColor:colorRef];
                IJSVGTraitedColor* color = [IJSVGTraitedColor colorWithColor:nsColor
                                                                      traits:IJSVGColorUsageTraitFill];
                [list addColor:color];
            }
        }
        
        // patterns
        if((fillLayer = (IJSVGShapeLayer*)[self layerForUsageType:IJSVGLayerUsageTypeFillPattern]) != nil) {
            IJSVGTraitedColorStorage* storage = fillLayer.colors;
            [storage addTraits:IJSVGColorUsageTraitFill];
            [list unionColorStorage:storage];
        }
        
        // gradients
        if((fillLayer = (IJSVGShapeLayer*)[self layerForUsageType:IJSVGLayerUsageTypeFillGradient]) != nil) {
            IJSVGTraitedColorStorage* storage = fillLayer.colors;
            [storage addTraits:IJSVGColorUsageTraitGradientStop];
            [list unionColorStorage:storage];
        }
    }
    
    // we have a stroke color
    if([self matchesTraits:IJSVGLayerTraitStroked] == YES) {
        IJSVGStrokeLayer* strokeLayer = nil;
        if((strokeLayer = (IJSVGStrokeLayer*)[self layerForUsageType:IJSVGLayerUsageTypeStrokeGeneric]) != nil) {
            CGColorRef colorRef = NULL;
            if((colorRef = strokeLayer.strokeColor) != NULL) {
                NSColor* nsColor = [NSColor colorWithCGColor:colorRef];
                IJSVGTraitedColor* color = [IJSVGTraitedColor colorWithColor:nsColor
                                                                     traits:IJSVGColorUsageTraitStroke];
                [list addColor:color];
            }
        }
        
        // patterns
        if((strokeLayer = (IJSVGStrokeLayer*)[self layerForUsageType:IJSVGLayerUsageTypeStrokePattern]) != nil) {
            IJSVGTraitedColorStorage* storage = strokeLayer.colors;
            [storage addTraits:IJSVGColorUsageTraitFill];
            [list unionColorStorage:storage];
        }
        
        // gradients
        if((strokeLayer = (IJSVGStrokeLayer*)[self layerForUsageType:IJSVGLayerUsageTypeStrokeGradient]) != nil) {
            IJSVGTraitedColorStorage* storage = strokeLayer.colors;
            [storage addTraits:IJSVGColorUsageTraitGradientStop];
            [list unionColorStorage:storage];
        }
    }
    return list;
}

@end
