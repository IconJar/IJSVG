//
//  IJSVGLayer.h
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRendering.h>
#import <IJSVG/IJSVGTransaction.h>
#import <QuartzCore/QuartzCore.h>

@class IJSVGShapeLayer;
@class IJSVGGradientLayer;
@class IJSVGPatternLayer;
@class IJSVGStrokeLayer;
@class IJSVGGroupLayer;
@class IJSVGLayer;

typedef NS_ENUM(NSUInteger, IJSVGLayerFillType) {
    IJSVGLayerFillTypeColor,
    IJSVGLayerFillTypePattern,
    IJSVGLayerFillTypeGradient,
    IJSVGLayerFillTypeUnknown
};

typedef NS_OPTIONS(NSUInteger, IJSVGLayerTraits) {
    IJSVGLayerTraitGroup
};

@protocol IJSVGPathableLayer <NSObject>

@required
@property (nonatomic, assign) CGPathRef path;

@end

@protocol IJSVGDrawableLayer <NSObject>

@required
@property (nonatomic, assign) CGBlendMode blendingMode;
@property (nonatomic, retain) CALayer<IJSVGDrawableLayer>* clipLayer;
@property (nonatomic, retain) CALayer<IJSVGDrawableLayer>* maskLayer;
@property (nonatomic, copy) CAShapeLayerFillRule clipRule;
@property (nonatomic, copy) CAShapeLayerFillRule fillRule;
@property (nonatomic, readonly) CGPoint absoluteOrigin;
@property (nonatomic, assign) IJSVGRenderQuality renderQuality;
@property (nonatomic, assign) CGFloat backingScaleFactor;
@property (nonatomic, readonly) BOOL requiresBackingScaleHelp;
@property (nonatomic, readonly) CALayer<IJSVGDrawableLayer>* rootLayer;
@property (nonatomic, readonly) CGRect absoluteFrame;
@property (nonatomic, assign) CGRect boundingBox;
@property (nonatomic, readonly) CGRect strokeBoundingBox;
@property (nonatomic, readonly) CGRect boundingBoxBounds;
@property (nonatomic, assign) CALayer<IJSVGDrawableLayer>* referencingLayer;
@property (nonatomic, readonly) NSArray<CALayer<IJSVGDrawableLayer>*>* debugLayers;

- (void)performRenderInContext:(CGContextRef)ctx;

@end

@interface IJSVGLayer : CALayer <IJSVGDrawableLayer> {

@private
    IJSVGLayer* _maskingLayer;
}

@property (nonatomic, assign) IJSVGGradientLayer* gradientFillLayer;
@property (nonatomic, assign) IJSVGPatternLayer* patternFillLayer;
@property (nonatomic, assign) IJSVGStrokeLayer* strokeLayer;
@property (nonatomic, assign) IJSVGGradientLayer* gradientStrokeLayer;
@property (nonatomic, assign) IJSVGPatternLayer* patternStrokeLayer;
@property (nonatomic, readonly) BOOL requiresBackingScaleHelp;
@property (nonatomic, assign) CGFloat backingScaleFactor;
@property (nonatomic, assign) IJSVGRenderQuality renderQuality;
@property (nonatomic, assign) CGBlendMode blendingMode;
@property (nonatomic, assign) CGPoint absoluteOrigin;
@property (nonatomic, assign) BOOL convertMasksToPaths;
@property (nonatomic, retain) CALayer<IJSVGDrawableLayer>* clipLayer;
@property (nonatomic, copy) CAShapeLayerFillRule clipRule;
@property (nonatomic, copy) CAShapeLayerFillRule fillRule;
@property (nonatomic, retain) CALayer<IJSVGDrawableLayer>* maskLayer;
@property (nonatomic, readonly) CALayer<IJSVGDrawableLayer>* rootLayer;
@property (nonatomic, readonly) CGRect absoluteFrame;
@property (nonatomic, assign) CGRect boundingBox;
@property (nonatomic, readonly) CGRect boundingBoxBounds;
@property (nonatomic, readonly) CGRect strokeBoundingBox;
@property (nonatomic, assign) CALayer<IJSVGDrawableLayer>* referencingLayer;

+ (IJSVGLayerFillType)fillTypeForFill:(id)fill;

+ (NSArray*)deepestSublayersOfLayer:(CALayer*)layer;
+ (void)recursivelyWalkLayer:(CALayer<IJSVGDrawableLayer>*)layer
                   withBlock:(void (^)(CALayer<IJSVGDrawableLayer>* layer, BOOL* stop))block;

- (void)applySublayerMaskToContext:(CGContextRef)context
                       forSublayer:(IJSVGLayer*)sublayer
                        withOffset:(CGPoint)offset;

+ (void)renderLayer:(CALayer<IJSVGDrawableLayer>*)layer
          inContext:(CGContextRef)ctx;

+ (void)applyBlendingMode:(CGBlendMode)blendMode
                toContext:(CGContextRef)ctx
             drawingBlock:(dispatch_block_t)drawingBlock;

+ (void)clipContextWithClip:(CALayer<IJSVGDrawableLayer>*)clipLayer
                    toLayer:(CALayer<IJSVGDrawableLayer>*)layer
                  inContext:(CGContextRef)ctx
               drawingBlock:(dispatch_block_t)drawingBlock;

+ (void)clipContextWithMask:(CALayer<IJSVGDrawableLayer>*)maskLayer
                    toLayer:(CALayer<IJSVGDrawableLayer>*)layer
                  inContext:(CGContextRef)context
               drawingBlock:(dispatch_block_t)drawingBlock;

+ (CALayer<IJSVGDrawableLayer>*)rootLayerForLayer:(CALayer<IJSVGDrawableLayer>*)layer;
+ (CGAffineTransform)absoluteTransformForLayer:(CALayer*)layer;
+ (CGRect)absoluteFrameForLayer:(CALayer<IJSVGDrawableLayer>*)layer;
+ (CGRect)calculateFrameForSublayers:(NSArray<CALayer<IJSVGDrawableLayer>*>*)layers;

+ (void)logLayer:(CALayer<IJSVGDrawableLayer>*)layer;

@end
