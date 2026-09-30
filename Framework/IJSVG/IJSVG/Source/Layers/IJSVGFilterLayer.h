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

// Only branches containing filters need drawing during batch collection.
+ (BOOL)shouldRenderLayerDuringCollection:(CALayer*)layer;

// Returns NO without painting the destination when batching is not applicable.
+ (BOOL)renderBatchedLayer:(CALayer*)root
                 inContext:(CGContextRef)context
              drawingBlock:(void (^)(CGContextRef))drawingBlock;

- (instancetype)initWithSourceLayer:(CALayer<IJSVGDrawableLayer>*)layer
                             filter:(IJSVGFilter*)filter
                           viewPort:(CGRect)viewPort;

@end
