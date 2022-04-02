//
//  IJSVGLayerTree.m
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVG.h"
#import "IJSVGGradient.h"
#import "IJSVGGradientLayer.h"
#import "IJSVGGroup.h"
#import "IJSVGGroupLayer.h"
#import "IJSVGImage.h"
#import "IJSVGImageLayer.h"
#import "IJSVGLayer.h"
#import "IJSVGLayerTree.h"
#import "IJSVGPath.h"
#import "IJSVGPattern.h"
#import "IJSVGPatternLayer.h"
#import "IJSVGShapeLayer.h"
#import "IJSVGStrokeLayer.h"
#import "IJSVGText.h"
#import "IJSVGTransform.h"
#import "IJSVGUtils.h"
#import "IJSVGTransformLayer.h"

@implementation IJSVGLayerTree

@synthesize style = _style;

- (void)dealloc
{
    (void)([_style release]), _style = nil;
    [super dealloc];
}

- (id)init
{
    if ((self = [super init]) != nil) {
        NSLog(@"================== SVG");
    }
    return self;
}

- (IJSVG_DRAWABLE_LAYER)drawableLayerForNode:(IJSVGNode*)node {
    IJSVG_DRAWABLE_LAYER layer = nil;
    if([node isKindOfClass:IJSVGPath.class]) {
        layer = [self drawableLayerForPathNode:(IJSVGPath*)node];
    } else if([node isKindOfClass:IJSVGRootNode.class]) {
        layer = [self drawableLayerForRootNode:(IJSVGRootNode*)node];
    } else if([node isKindOfClass:IJSVGGroup.class]) {
        layer = [self drawableLayerForGroupNode:(IJSVGGroup*)node];
    } else if([node isKindOfClass:IJSVGImage.class]) {
        layer = [self drawableLayerForImageNode:(IJSVGImage*)node];
    }
    if(layer != nil) {
        [self applyDefaultsToLayer:layer
                          fromNode:node];
        return [self applyTransforms:node.transforms
                             toLayer:layer
                            fromNode:node];
    }
    return layer;
}

- (IJSVG_DRAWABLE_LAYER)drawableBasicLayerForPathNode:(IJSVGPath*)node
{
    IJSVGShapeLayer* layer = [IJSVGShapeLayer new];
    layer.primitiveType = node.primitiveType;
    [self applyTransformedPathToShapeLayer:layer
                                  fromNode:node];
    layer.fillColor = nil;
    layer.fillRule = [IJSVGUtils CGFillRuleForWindingRule:node.windingRule];
    return layer;
}

- (void)applyTransformedPathToShapeLayer:(CAShapeLayer*)layer
                                fromNode:(IJSVGPath*)node
{
    CGRect pathBounds = CGPathGetPathBoundingBox(node.path);
    CGAffineTransform transform = CGAffineTransformMakeTranslation(-pathBounds.origin.x,
                                                                   -pathBounds.origin.y);
    CGPathRef transformedPath = CGPathCreateCopyByTransformingPath(node.path, &transform);
    layer.frame = pathBounds;
    layer.path = transformedPath;
    CGPathRelease(transformedPath);
}

- (IJSVG_DRAWABLE_LAYER)drawableLayerForPathNode:(IJSVGPath*)node
{
    IJSVGShapeLayer* layer = (IJSVGShapeLayer*)[self drawableBasicLayerForPathNode:node];
    layer.borderColor = NSColor.blueColor.CGColor;
    layer.borderWidth = 1.f;
    
    // color the shape
    id fill = node.fill;
    if([fill isKindOfClass:IJSVGColorNode.class]) {
        IJSVGColorNode* colorNode = (IJSVGColorNode*)fill;
        NSColor* color = colorNode.color;
        
        // change the fill color opacity if required
        if(node.fillOpacity.value != 1.f) {
            color = [IJSVGColor changeAlphaOnColor:color
                                                to:node.fillOpacity.value];
        }
        
        // set the color against the layer
        layer.fillColor = color.CGColor;
    } else {
        layer.fillColor = NSColor.blackColor.CGColor;
    }
    
    // stroke the path
    if([node matchesTraits:IJSVGNodeTraitStroked]) {
        IJSVG_DRAWABLE_LAYER strokeLayer = [self drawableStrokedLayerForPathNode:node];
        CGSize difference = CGSizeMake((strokeLayer.frame.size.width - layer.frame.size.width) / 2.f,
                                       (strokeLayer.frame.size.height - layer.frame.size.height) / 2.f);
        layer.frame = CGRectInset(layer.frame, -difference.width, -difference.height);
        layer.borderColor = NSColor.greenColor.CGColor;
        layer.borderWidth = 1.f;
        
        CGRect strokeLayerFrame = strokeLayer.frame;
        strokeLayerFrame.origin.x = strokeLayerFrame.origin.y = 0.f;
        strokeLayer.frame = strokeLayerFrame;
        [layer addSublayer:strokeLayer];
    }
    
    return layer;
}

- (IJSVG_DRAWABLE_LAYER)drawableStrokedLayerForPathNode:(IJSVGPath*)node
{
    IJSVGStrokeLayer* layer = [IJSVGStrokeLayer layer];
    [self applyTransformedPathToShapeLayer:layer
                                  fromNode:node];
    
    // reset the frame back to zero
    CGRect frame = layer.frame;
    frame.origin.x = 0.f;
    frame.origin.y = 0.f;
    layer.frame = frame;
    
    // compute the color
    NSColor* strokeColor = NSColor.blackColor;
    if([node.stroke isKindOfClass:IJSVGColorNode.class]) {
        IJSVGColorNode* colorNode = (IJSVGColorNode*)node.stroke;
        strokeColor = colorNode.color;
    }
    
    // set the color
    layer.fillColor = nil;
    layer.strokeColor = strokeColor.CGColor;
    
    // work out line width
    CGFloat lineWidth = 1.f;
    lineWidth = node.strokeWidth.value;
    
    // work out line styles
    IJSVGLineCapStyle lineCapStyle = node.lineCapStyle;
    IJSVGLineJoinStyle lineJoinStyle = node.lineJoinStyle;
    
    // apply the properties
    layer.lineWidth = lineWidth;
    layer.lineCap = [IJSVGUtils CGLineCapForCapStyle:lineCapStyle];
    layer.lineJoin = [IJSVGUtils CGLineJoinForJoinStyle:lineJoinStyle];
    
    CGFloat strokeOpacity = 1.f;
    if(node.strokeOpacity.value != 0.f) {
        strokeOpacity = node.strokeOpacity.value;
    }
    layer.opacity = strokeOpacity;
    
    // dashing
    layer.lineDashPhase = node.strokeDashOffset.value;
    if(node.strokeDashArrayCount != 0.f) {
        layer.lineDashPattern = node.lineDashPattern;
    }
    
    // lets resize the layer as we have computed everything at this point
    CGFloat increase = layer.lineWidth / 2.f;
    frame = CGRectInset(frame, -increase, -increase);
    
    // now we know what to do, we need to transform the path
    CGAffineTransform transform = CGAffineTransformMakeTranslation(increase, increase);
    CGPathRef path = CGPathCreateCopyByTransformingPath(layer.path, &transform);
    layer.frame = frame;
    layer.path = path;
    layer.borderColor = NSColor.redColor.CGColor;
    layer.borderWidth = 1.f;
    CGPathRelease(path);
    
    return layer;
}

- (IJSVG_DRAWABLE_LAYER)drawableLayerForRootNode:(IJSVGRootNode*)node
{
    IJSVGGroupLayer* layer = [IJSVGGroupLayer new];
    layer.frame = CGRectMake(0.f, 0.f,
                             node.viewBox.size.width,
                             node.viewBox.size.height);
    NSArray<IJSVG_DRAWABLE_LAYER>* layers = [self drawableLayersForNodes:node.children];
    for(IJSVG_DRAWABLE_LAYER drawableLayer in layers) {
        [layer addSublayer:drawableLayer];
    }
    return layer;
}

- (IJSVG_DRAWABLE_LAYER)drawableLayerForGroupNode:(IJSVGGroup*)node
{
    NSArray<IJSVG_DRAWABLE_LAYER>* layers = [self drawableLayersForNodes:node.children];
    return [self drawableLayerForGroupNode:node
                                 sublayers:layers];
}

- (IJSVG_DRAWABLE_LAYER)drawableLayerForGroupNode:(IJSVGNode*)node
                                        sublayers:(NSArray<IJSVG_DRAWABLE_LAYER>*)sublayers
{
    IJSVGGroupLayer* layer = [IJSVGGroupLayer new];
    layer.borderColor = NSColor.purpleColor.CGColor;
    layer.borderWidth = 1.f;
    CGRect rect = [self calculateFrameForSublayers:sublayers];
    layer.frame = rect;
    CGAffineTransform translate = CGAffineTransformMakeTranslation(-rect.origin.x,
                                                                   -rect.origin.y);
    for(IJSVG_DRAWABLE_LAYER sublayer in sublayers) {
        CGAffineTransform transform = sublayer.affineTransform;
        transform = CGAffineTransformConcat(transform, translate);
        sublayer.affineTransform = transform;
        [layer addSublayer:sublayer];
    }
    return layer;
}

- (NSArray<IJSVG_DRAWABLE_LAYER>*)drawableLayersForNodes:(NSArray<IJSVGNode*>*)nodes
{
    NSMutableArray<IJSVG_DRAWABLE_LAYER>* layers = nil;
    layers = [[[NSMutableArray alloc] initWithCapacity:nodes.count] autorelease];
    for(IJSVGNode* node in nodes) {
        IJSVG_DRAWABLE_LAYER layer = [self drawableLayerForNode:node];
        if(layer != nil) {
            [layers addObject:layer];
        }
    }
    return layers;
}

#pragma mark Bounds Calculation

- (CGRect)calculateFrameForSublayers:(NSArray<IJSVG_DRAWABLE_LAYER>*)layers
{
    CGRect rect = CGRectNull;
    for(IJSVG_DRAWABLE_LAYER layer in layers) {
        CGRect layerFrame = layer.frame;
        // if we are a transform layer, we can just apply its transform
        // to its sublayers and keep going down the tree
        if([layer isKindOfClass:IJSVGTransformLayer.class]) {
            CGRect frame = [self calculateFrameForSublayers:layer.sublayers];
            frame = CGRectApplyAffineTransform(frame, layer.affineTransform);
            layerFrame = frame;
        }
        if(CGRectIsNull(rect)) {
            rect = layerFrame;
            continue;
        }
        rect = CGRectUnion(rect, layerFrame);
    }
    return rect;
}

#pragma mark Defaults

- (void)applyDefaultsToLayer:(IJSVG_DRAWABLE_LAYER)layer
                    fromNode:(IJSVGNode*)node
{
    // mask the layer
    if(node.mask != nil) {
        layer.maskLayer = [self drawableLayerForNode:node.mask];
    }
    
    // add the clip mask if any
    if(node.clipPath != nil) {
        layer.clipLayer = [self drawableLayerForNode:node.clipPath];
    }
    
    // setup the opacity
    CGFloat opacity = node.opacity.value;
    if(opacity != 1.f) {
        layer.opacity = opacity;
    }

    // Blending mode
    if (node.blendMode != IJSVGBlendModeNormal) {
        layer.blendingMode = (CGBlendMode)node.blendMode;
    }

    // Should this even be displayed?
    if (node.shouldRender == NO) {
        layer.hidden = YES;
    }
}

#pragma mark Transforms

- (IJSVG_DRAWABLE_LAYER)applyTransforms:(NSArray<IJSVGTransform*>*)transforms
                                toLayer:(IJSVG_DRAWABLE_LAYER)layer
                               fromNode:(IJSVGNode*)node

{
    // any x and y?
    CGRect frame = layer.bounds;
    CGFloat x = [node.x computeValue:frame.size.width];
    CGFloat y = [node.y computeValue:frame.size.height];

    // no need to do anything if no transform, or x or y == 0
    if (transforms.count == 0 && x == 0.f && y == 0.f) {
        return layer;
    }

    // simply cascade all the transforms onto the identity
    CGAffineTransform identity = CGAffineTransformIdentity;
    if (x != 0.f || y != 0.f) {
        identity = CGAffineTransformTranslate(identity, x, y);
    }

    // this used to be done with each transform being added to its own
    // group layer, but we can simply use one and then apply
    // the transforms in reverse order, has same outcome with less memory
    IJSVG_DRAWABLE_LAYER parentLayer = [IJSVGTransformLayer layer];
    for(IJSVGTransform* transform in transforms.reverseObjectEnumerator) {
        identity = CGAffineTransformConcat(identity,
                                           transform.CGAffineTransform);
    }
    parentLayer.affineTransform = identity;
    [parentLayer addSublayer:layer];
    return parentLayer;
}

#pragma mark To Refactor

- (IJSVGLayer*)drawableLayerForImageNode:(IJSVGImage*)image
{
   IJSVGImageLayer* layer = [[[IJSVGImageLayer alloc] initWithImage:image] autorelease];
   // make sure we set the width and height correctly,
   // as this may not be exactly the same as the size of the
   // given image
   CGRect frame = layer.frame;
   frame.size.width = image.width.value;
   frame.size.height = image.height.value;
   layer.frame = frame;
   [layer setNeedsLayout];
   return layer;
}

@end
