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
@class IJSVGRootLayer;
@class IJSVGRootNode;

@interface IJSVGLayerTree : NSObject {
@private
    NSMutableArray<NSValue*>* _viewPortStack;
}

@property (nonatomic, assign) CGRect viewBox;
@property (nonatomic, assign) CGFloat backingScale;
@property (nonatomic, retain) IJSVGRenderingStyle* style;

- (id)initWithViewPortRect:(CGRect)viewPort
              backingScale:(CGFloat)scale;
- (IJSVGRootLayer*)rootLayerForRootNode:(IJSVGRootNode*)rootNode;

@end
