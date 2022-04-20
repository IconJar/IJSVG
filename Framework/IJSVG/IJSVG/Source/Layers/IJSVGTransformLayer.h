//
//  IJSVGTransformLayer.h
//  IJSVG
//
//  Created by Curtis Hard on 31/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <IJSVG/IJSVGLayer.h>

@interface IJSVGTransformLayer : CATransformLayer <IJSVGDrawableLayer>

@property (nonatomic, assign) CGBlendMode blendingMode;
@property (nonatomic, strong) CALayer<IJSVGDrawableLayer>* clipLayer;
@property (nonatomic, readonly) CGPoint absoluteOrigin;
@property (nonatomic, readonly) CALayer<IJSVGDrawableLayer>* referencedLayer;
@property (nonatomic, assign) CALayer<IJSVGDrawableLayer>* referencingLayer;

@end
