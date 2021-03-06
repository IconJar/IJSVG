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

@interface IJSVGShapeLayer : CAShapeLayer {

@private
    IJSVGLayer* _maskingLayer;
}

@property (nonatomic, assign) IJSVGGradientLayer* gradientFillLayer;
@property (nonatomic, assign) IJSVGPatternLayer* patternFillLayer;
@property (nonatomic, assign) IJSVGStrokeLayer* strokeLayer;
@property (nonatomic, assign) IJSVGGradientLayer* gradientStrokeLayer;
@property (nonatomic, assign) IJSVGPatternLayer* patternStrokeLayer;
@property (nonatomic, assign) BOOL requiresBackingScaleHelp;
@property (nonatomic, assign) CGFloat backingScaleFactor;
@property (nonatomic, assign) IJSVGRenderQuality renderQuality;
@property (nonatomic, assign) CGBlendMode blendingMode;
@property (nonatomic, assign) CGPoint absoluteOrigin;
@property (nonatomic, assign) CGPoint originalPathOrigin;
@property (nonatomic, assign) BOOL convertMasksToPaths;
@property (nonatomic, assign) IJSVGPrimitivePathType primitiveType;

- (void)applySublayerMaskToContext:(CGContextRef)context
                       forSublayer:(IJSVGLayer*)sublayer
                        withOffset:(CGPoint)offset;

@end
