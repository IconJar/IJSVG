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
@class IJSVGFilter;
@class IJSVGTraitedColorStorage;

typedef NS_OPTIONS(NSUInteger, IJSVGLayerTraits) {
    IJSVGLayerTraitNone = 0,
    IJSVGLayerTraitFilled = 1 << 1,
    IJSVGLayerTraitStroked = 1 << 2
};

typedef NS_OPTIONS(NSUInteger, IJSVGLayerDrawingOptions) {
    IJSVGLayerDrawingOptionNone = 0,
    IJSVGLayerDrawingOptionIgnoreClipping = 1 << 1
};

typedef NS_ENUM(NSUInteger, IJSVGLayerFillType) {
    IJSVGLayerFillTypeColor,
    IJSVGLayerFillTypePattern,
    IJSVGLayerFillTypeGradient,
    IJSVGLayerFillTypeUnknown
};

typedef NS_ENUM(NSUInteger, IJSVGLayerUsageType) {
    IJSVGLayerUsageTypeFillGeneric,
    IJSVGLayerUsageTypeFillPattern,
    IJSVGLayerUsageTypeFillGradient,
    IJSVGLayerUsageTypeStrokeGeneric,
    IJSVGLayerUsageTypeStrokePattern,
    IJSVGLayerUsageTypeStrokeGradient,
    IJSVGLayerUsageTypeStroke
};

@protocol IJSVGPathableLayer <NSObject>

@required
@property (nonatomic, assign) CGPathRef path;

@end

@protocol IJSVGBasicLayer <NSObject>

@required
@property (nonatomic, assign) CGFloat backingScaleFactor;
@property (nonatomic, readonly) BOOL requiresBackingScale;
@property (nonatomic, assign) IJSVGRenderQuality renderQuality;
@property (nonatomic, readonly) NSArray<CALayer<IJSVGBasicLayer>*>* debugLayers;

@end

@protocol IJSVGMaskingLayer <NSObject>

@required
@property (nonatomic, assign) CGRect maskingBoundingBox;
@property (nonatomic, assign) CGRect maskingClippingRect;

@end

@protocol IJSVGClippingLayer <NSObject>

@required
@property (nonatomic, assign) CGRect clippingBoundingBox;
@property (nonatomic, assign) CGAffineTransform clippingTransform;
@property (nonatomic, assign) CGPathRef clipPath;
@property (nonatomic, assign) CGAffineTransform clipPathTransform;

@end

@protocol IJSVGDrawableLayer <NSObject, IJSVGBasicLayer, IJSVGMaskingLayer, IJSVGClippingLayer>

@required
@property (nonatomic, readonly) BOOL treatImplicitOriginAsTransform;
@property (nonatomic, assign) CGBlendMode blendingMode;
@property (nonatomic, strong) NSArray<CALayer<IJSVGDrawableLayer>*>* clipLayers;
@property (nonatomic, strong) CALayer<IJSVGDrawableLayer>* maskLayer;
@property (nonatomic, copy) CAShapeLayerFillRule clipRule;
@property (nonatomic, copy) CAShapeLayerFillRule fillRule;
@property (nonatomic, readonly) CGPoint absoluteOrigin;
@property (nonatomic, readonly) CGRect absoluteFrame;
@property (nonatomic, assign) CGRect boundingBox;
@property (nonatomic, assign) CGRect outerBoundingBox;
@property (nonatomic, readonly) CGRect innerBoundingBox;
@property (nonatomic, assign) CALayer<IJSVGDrawableLayer>* referencingLayer;
@property (nonatomic, strong) IJSVGFilter* filter;
@property (nonatomic, readonly) IJSVGLayerTraits layerTraits;
@property (nonatomic, readonly) NSMapTable<NSNumber*, CALayer<IJSVGDrawableLayer>*>* layerUsageMapTable;
@property (nonatomic, readonly) IJSVGTraitedColorStorage* colors;

- (void)performRenderInContext:(CGContextRef)ctx;

- (void)setLayer:(CALayer<IJSVGDrawableLayer>*)layer
    forUsageType:(IJSVGLayerUsageType)type;
- (CALayer<IJSVGDrawableLayer>*)layerForUsageType:(IJSVGLayerUsageType)type;
- (CALayer<IJSVGDrawableLayer>*)strokeLayer:(IJSVGLayerUsageType*)usageType;

- (void)addTraits:(IJSVGLayerTraits)traits;
- (void)removeTraits:(IJSVGLayerTraits)traits;
- (BOOL)matchesTraits:(IJSVGLayerTraits)traits;

- (CALayer<IJSVGDrawableLayer>*)firstSublayerOfClass:(Class)aClass;

@end

CGRect IJSVGLayerGetBoundingBoxBounds(CALayer<IJSVGDrawableLayer>* drawableLayer);
NSMapTable<NSNumber*, CALayer<IJSVGDrawableLayer>*>* IJSVGLayerDefaultUsageMapTable(void);

@interface IJSVGLayer : CALayer <IJSVGDrawableLayer, IJSVGMaskingLayer> {

@private
    IJSVGLayer* _maskingLayer;
    NSMapTable<NSNumber*, CALayer<IJSVGDrawableLayer>*>* _layerUsageMapTable;
}

+ (IJSVGLayerFillType)fillTypeForFill:(id)fill;

+ (NSArray*)deepestSublayersOfLayer:(CALayer*)layer;
+ (void)recursivelyWalkLayer:(CALayer<IJSVGBasicLayer>*)layer
                   withBlock:(void (^)(CALayer<IJSVGBasicLayer>* layer, BOOL* stop))block;

+ (CALayer<IJSVGDrawableLayer>*)firstSublayerOfClass:(Class)aClass
                                           fromLayer:(CALayer<IJSVGDrawableLayer>*)layer;

+ (void)setBackingScaleFactor:(CGFloat)scale
                renderQuality:(IJSVGRenderQuality)quality
           recursivelyToLayer:(CALayer<IJSVGDrawableLayer>*)layer;

- (void)applySublayerMaskToContext:(CGContextRef)context
                       forSublayer:(IJSVGLayer*)sublayer
                        withOffset:(CGPoint)offset;

+ (CGImageRef)newMaskImageForLayer:(CALayer<IJSVGDrawableLayer>*)layer
                           options:(IJSVGLayerDrawingOptions)options
                             scale:(CGFloat)scale;

+ (CGImageRef)newImageForLayer:(CALayer<IJSVGDrawableLayer>*)layer
                       options:(IJSVGLayerDrawingOptions)options
                    colorSpace:(CGColorSpaceRef)colorSpace
                    bitmapInfo:(uint32_t)bitmapInfo
                         scale:(CGFloat)scale;

+ (CGImageRef)newImageWithSize:(CGSize)size
                     drawBlock:(void (^)(CGContextRef context))drawBlock
                    colorSpace:(CGColorSpaceRef)colorSpace
                    bitmapInfo:(uint32_t)bitmapInfo
                         scale:(CGFloat)scale;

+ (void)renderLayer:(CALayer<IJSVGDrawableLayer>*)layer
          inContext:(CGContextRef)ctx
            options:(IJSVGLayerDrawingOptions)options;

+ (void)applyBlendingMode:(CGBlendMode)blendMode
                toContext:(CGContextRef)ctx
             drawingBlock:(dispatch_block_t)drawingBlock;

+ (void)clipContextWithClipLayers:(NSArray<CALayer<IJSVGDrawableLayer>*>*)clipLayers
                          toLayer:(CALayer<IJSVGDrawableLayer>*)layer
                        inContext:(CGContextRef)ctx
                     drawingBlock:(dispatch_block_t)drawingBlock;

+ (void)clipContextWithMask:(CALayer<IJSVGMaskingLayer>*)maskLayer
                    toLayer:(CALayer<IJSVGDrawableLayer>*)layer
                  inContext:(CGContextRef)context
               drawingBlock:(dispatch_block_t)drawingBlock;

+ (CALayer<IJSVGDrawableLayer>*)rootLayerForLayer:(CALayer<IJSVGDrawableLayer>*)layer;
+ (CGAffineTransform)absoluteTransformForLayer:(CALayer*)layer;
+ (CGRect)absoluteFrameForLayer:(CALayer<IJSVGDrawableLayer>*)layer;
+ (CGRect)calculateFrameForSublayers:(NSArray<CALayer<IJSVGDrawableLayer>*>*)layers;
+ (CGAffineTransform)userSpaceTransformForLayer:(CALayer<IJSVGDrawableLayer>*)layer;
+ (void)transformLayer:(CALayer<IJSVGDrawableLayer>*)layer
intoUserSpaceUnitsFrom:(CALayer<IJSVGDrawableLayer>*)fromLayer;

+ (void)logLayer:(CALayer<IJSVGDrawableLayer>*)layer;

@end
