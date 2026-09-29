//
//  IJSVGFilterLayer.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroupLayer.h>
#import <IJSVG/IJSVGFilter.h>

@interface IJSVGFilterLayer : IJSVGGroupLayer

@property (nonatomic, strong) IJSVGFilter* filter;
@property (nonatomic, strong) IJSVGNode* sourceNode;
@property (nonatomic, assign) CGRect viewPort;
@property (nonatomic, readonly) CALayer<IJSVGDrawableLayer>* sourceLayer;

- (instancetype)initWithSourceLayer:(CALayer<IJSVGDrawableLayer>*)layer
                             filter:(IJSVGFilter*)filter
                           viewPort:(CGRect)viewPort;

@end
