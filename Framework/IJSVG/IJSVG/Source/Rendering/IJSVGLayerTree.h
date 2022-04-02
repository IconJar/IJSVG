//
//  IJSVGLayerTree.h
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGRenderingStyle.h>
#import <QuartzCore/QuartzCore.h>

#define IJSVG_DRAWABLE_LAYER CALayer<IJSVGDrawableLayer>*

@class IJSVGLayer;

@interface IJSVGLayerTree : NSObject {
}

@property (nonatomic, assign) CGRect viewBox;
@property (nonatomic, retain) IJSVGRenderingStyle* style;

- (IJSVG_DRAWABLE_LAYER)drawableLayerForNode:(IJSVGNode*)node;

@end
