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
    NSMapTable<NSNumber*, CALayer<IJSVGDrawableLayer>*>* _layerUsageMapTable;
}

@property (nonatomic, assign) IJSVGPrimitivePathType primitiveType;

- (void)applySublayerMaskToContext:(CGContextRef)context
                       forSublayer:(IJSVGLayer*)sublayer
                        withOffset:(CGPoint)offset;

@end
