//
//  IJSVGShapeLayer.h
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLayer.h>
#import <IJSVG/IJSVGUtils.h>
#import <QuartzCore/QuartzCore.h>

@interface IJSVGShapeLayer : CAShapeLayer <IJSVGDrawableLayer, IJSVGPathableLayer> {

@private
    IJSVGLayer* _maskingLayer;
}

@property (nonatomic, assign) IJSVGGradientLayer* gradientFillLayer;
@property (nonatomic, assign) IJSVGPatternLayer* patternFillLayer;
@property (nonatomic, assign) IJSVGStrokeLayer* strokeLayer;
@property (nonatomic, assign) IJSVGGradientLayer* gradientStrokeLayer;
@property (nonatomic, assign) IJSVGPatternLayer* patternStrokeLayer;
@property (nonatomic, assign) CGFloat backingScaleFactor;
@property (nonatomic, readonly) BOOL requiresBackingScale;
@property (nonatomic, assign) IJSVGRenderQuality renderQuality;
@property (nonatomic, assign) CGBlendMode blendingMode;
@property (nonatomic, assign) CGPoint absoluteOrigin;
@property (nonatomic, assign) CGPoint originalPathOrigin;
@property (nonatomic, assign) IJSVGPrimitivePathType primitiveType;
@property (nonatomic, strong) CALayer<IJSVGDrawableLayer>* clipLayer;
@property (nonatomic, strong) NSArray<CALayer<IJSVGDrawableLayer>*>* clipLayers;
@property (nonatomic, strong) CALayer<IJSVGDrawableLayer>* maskLayer;
@property (nonatomic, readonly) CGRect absoluteFrame;
@property (nonatomic, assign) CGRect boundingBox;
@property (nonatomic, assign) CGRect outerBoundingBox;
@property (nonatomic, readonly) CGRect innerBoundingBox;
@property (nonatomic, readonly) CGRect boundingBoxBounds;
@property (nonatomic, strong) IJSVGFilter* filter;
@property (nonatomic, assign) CALayer<IJSVGDrawableLayer>* referencingLayer;
@property (nonatomic, copy) CAShapeLayerFillRule clipRule;
@property (nonatomic, assign) CGRect maskingBoundingBox;
@property (nonatomic, assign) CGRect maskingClippingRect;
@property (nonatomic, assign) CGRect clippingBoundingBox;
@property (nonatomic, assign) CGAffineTransform clippingTransform;
@property (nonatomic, assign) CGPathRef clipPath;
@property (nonatomic, assign) CGAffineTransform clipPathTransform;

- (void)applySublayerMaskToContext:(CGContextRef)context
                       forSublayer:(IJSVGLayer*)sublayer
                        withOffset:(CGPoint)offset;

@end
