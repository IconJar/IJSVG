//
//  IJSVGQuartzRenderer.h
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGRendering.h>
#import <IJSVG/IJSVGStyle.h>

@class IJSVGPaint, IJSVGRootPaint, IJSVGShapePaint;

// Resolves the parsed node graph into plain Quartz paint objects.
@interface IJSVGQuartzRenderer : NSObject

@property (nonatomic, strong) IJSVGStyle* style;
@property (nonatomic, copy) IJSVGRenderingOptions* renderingOptions;
@property (nonatomic, assign) CGFloat backingScale;

- (void)renderNode:(IJSVGRootNode*)rootNode
         inContext:(CGContextRef)ctx
          viewPort:(CGRect)viewPort
      backingScale:(CGFloat)backingScale;

- (void)drawPaint:(IJSVGNode*)paint
      boundingBox:(CGRect)boundingBox
         viewPort:(CGRect)viewPort
           region:(CGRect)region
        inContext:(CGContextRef)context;

// Measures painted geometry before clipping to the outer SVG viewport.
- (CGRect)artworkBoundsForRootNode:(IJSVGRootNode*)rootNode;
// Includes filter regions and placement in the parent coordinate system.
- (CGRect)extentForNode:(IJSVGNode*)node
             inViewPort:(CGRect)viewPort;

// Resolve the node graph without allocating a graphics context.
- (IJSVGRootPaint*)rootPaintForRootNode:(IJSVGRootNode*)rootNode;
- (IJSVGPaint*)drawablePaintForNode:(IJSVGNode*)node
                         inViewPort:(CGRect)viewPort;
+ (CGPathRef)newPathFromStrokedShapePaint:(IJSVGShapePaint*)paint CF_RETURNS_RETAINED;
@end
