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

typedef NS_OPTIONS(NSUInteger, IJSVGLayerTraits) {
    IJSVGLayerTraitGroup
};

@protocol IJSVGDrawableLayer <NSObject>

@required
@property (nonatomic, assign) CGBlendMode blendingMode;
@property (nonatomic, retain) CALayer<IJSVGDrawableLayer>* clipLayer;
@property (nonatomic, retain) CALayer<IJSVGDrawableLayer>* maskLayer;
@property (nonatomic, readonly) CGPoint absoluteOrigin;
@property (nonatomic, assign) IJSVGRenderQuality renderQuality;
@property (nonatomic, assign) CGFloat backingScaleFactor;
@property (nonatomic, readonly) BOOL requiresBackingScaleHelp;

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
@property (nonatomic, retain) CALayer<IJSVGDrawableLayer>* maskLayer;

+ (NSArray*)deepestSublayersOfLayer:(CALayer*)layer;
+ (void)recursivelyWalkLayer:(CALayer*)layer
                   withBlock:(void (^)(CALayer* layer, BOOL isMask, BOOL* stop))block;

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

@end
