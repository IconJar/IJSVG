//
//  IJSVGLayerTree.h
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGStyle.h>
#import <QuartzCore/QuartzCore.h>

@class IJSVGLayer;
@class IJSVGRootLayer;
@class IJSVGRootNode;

@interface IJSVGLayerTree : NSObject {
@private
    NSMutableArray<NSValue*>* _viewPortStack;
    NSMutableArray<NSValue*>* _unitBoundsStack;
}

@property (nonatomic, assign) CGRect viewBox;
@property (nonatomic, assign) CGFloat backingScale;
@property (nonatomic, strong) IJSVGStyle* style;

+ (CGPathRef)newPathFromStrokedShapeLayer:(IJSVGShapeLayer*)shapeLayer;

- (CALayer<IJSVGDrawableLayer>*)drawableLayerForNode:(IJSVGNode*)node
                                          inViewPort:(CGRect)viewPort;

- (void)drawPaint:(IJSVGNode*)paint
      boundingBox:(CGRect)boundingBox
         viewPort:(CGRect)viewPort
           region:(CGRect)region
        inContext:(CGContextRef)context;

- (IJSVGRootLayer*)rootLayerForRootNode:(IJSVGRootNode*)rootNode;

@end
