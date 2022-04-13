//
//  IJSVGLayerTree.m
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGGradient.h>
#import <IJSVG/IJSVGGradientLayer.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGGroupLayer.h>
#import <IJSVG/IJSVGImage.h>
#import <IJSVG/IJSVGImageLayer.h>
#import <IJSVG/IJSVGLayer.h>
#import <IJSVG/IJSVGLayerTree.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGPattern.h>
#import <IJSVG/IJSVGPatternLayer.h>
#import <IJSVG/IJSVGShapeLayer.h>
#import <IJSVG/IJSVGStrokeLayer.h>
#import <IJSVG/IJSVGText.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGTransformLayer.h>

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
    IJSVGShapeLayer* layer = [IJSVGShapeLayer layer];
    layer.primitiveType = node.primitiveType;
    [self applyTransformedPathToShapeLayer:layer
                                  fromNode:node];
    layer.fillColor = nil;
    layer.fillRule = [IJSVGUtils CGFillRuleForWindingRule:node.windingRule];
    return layer;
}

- (void)applyTransformedPathToShapeLayer:(CALayer<IJSVGPathableLayer, IJSVGDrawableLayer>*)layer
                                fromNode:(IJSVGPath*)node
{
    CGRect pathBounds = CGPathGetPathBoundingBox(node.path);
    pathBounds = pathBounds;
    
    // this will move the path back to a 0 origin as we actually set the origin
    // with the layer instead (which we can then move around)
    CGAffineTransform transform = CGAffineTransformMakeTranslation(-pathBounds.origin.x,
                                                                   -pathBounds.origin.y);
    CGPathRef transformedPath = CGPathCreateCopyByTransformingPath(node.path, &transform);
    layer.frame = pathBounds;
    layer.path = transformedPath;
    
    // note that we store the bounding box at this point, as it can be modified later
    // with strokes, however, SVG spec defined bounding box is the path without strokes
    // and without control points.
    layer.boundingBox = pathBounds;
    CGPathRelease(transformedPath);
}

- (IJSVG_DRAWABLE_LAYER)drawableLayerForPathNode:(IJSVGPath*)node
{
    IJSVGShapeLayer* layer = (IJSVGShapeLayer*)[self drawableBasicLayerForPathNode:node];
    
    // color the shape
    id fill = node.fill;
    
    // stroke the path
    IJSVGStrokeLayer* strokeLayer = nil;
    CGFloat strokeWidthDifference = 0.f;
    if([node matchesTraits:IJSVGNodeTraitStroked]) {
        // its highly likely that the stroke layer is larger than the layer its being
        // drawing into, so we need to increase the layer size to match or any groups
        // that this is inside wont be the correct frame
        strokeLayer = (IJSVGStrokeLayer*)[self drawableStrokedLayerForPathNode:node];
        strokeWidthDifference = strokeLayer.lineWidth * .5f;

        // make sure we update the bounding box as it has changed
        layer.frame = CGRectInset(layer.frame,
                                  -strokeWidthDifference,
                                  -strokeWidthDifference);
    }
    
    // generic fill color
    IJSVG_DRAWABLE_LAYER fillLayer = nil;
    switch([IJSVGLayer fillTypeForFill:fill]) {
        // just a generic fill color
        case IJSVGLayerFillTypeColor: {
            IJSVGColorNode* colorNode = (IJSVGColorNode*)fill;
            NSColor* color = colorNode.color;
            
            // change the fill color opacity if required
            if(node.fillOpacity.value != 1.f) {
                color = [IJSVGColor changeAlphaOnColor:color
                                                    to:node.fillOpacity.value];
            }
            
            // set the color against the layer
            layer.fillColor = color.CGColor;
            break;
        }
            
        // pattern fill
        case IJSVGLayerFillTypePattern: {
            fillLayer = [self drawablePatternLayerForPathNode:node
                                                      pattern:(IJSVGPattern*)node.fill
                                                        layer:layer];
            break;
        }
        
        // gradient fill
        case IJSVGLayerFillTypeGradient: {
            fillLayer = [self drawableGradientLayerForPathNode:node
                                                      gradient:(IJSVGGradient*)node.fill
                                                         layer:layer];
            break;
        }
            
        // unknown
        default: {
            layer.fillColor = NSColor.blackColor.CGColor;
            break;
        }
    }
    
    if(fillLayer != nil) {
        fillLayer.affineTransform = CGAffineTransformTranslate(fillLayer.affineTransform,
                                                                   strokeWidthDifference,
                                                                   strokeWidthDifference);
        [layer addSublayer:fillLayer];
    }
    
        
    // stroke the path
    if(strokeLayer != nil) {
        // its highly likely that the stroke layer is larger than the layer its being
        // drawing into, so we need to increase the layer size to match or any groups
        // that this is inside wont be the correct frame
//        layer.borderColor = NSColor.greenColor.CGColor;
//        layer.borderWidth = 1.f;
        
        CGRect strokeLayerFrame = strokeLayer.frame;
        strokeLayerFrame.origin.x = strokeLayerFrame.origin.y = strokeWidthDifference;
        strokeLayer.frame = strokeLayerFrame;
        
        // we need to work out what type of fill we need for the layer
        switch([IJSVGLayer fillTypeForFill:node.stroke]) {
            // patterns
            case IJSVGLayerFillTypePattern: {
                IJSVGPatternLayer* patternLayer = nil;
                patternLayer = [self drawableBasicPatternLayerForLayer:strokeLayer
                                                               pattern:(IJSVGPattern*)node.stroke];
                patternLayer.referencingLayer = layer;
                patternLayer.frame = CGRectInset(strokeLayer.frame,
                                                 -strokeWidthDifference,
                                                 -strokeWidthDifference);
                
                strokeLayer.strokeColor = NSColor.whiteColor.CGColor;
                patternLayer.maskLayer = strokeLayer;
                [layer addSublayer:patternLayer];
                break;
            }
                
            // gradients
            case IJSVGLayerFillTypeGradient: {
                IJSVGGradientLayer* gradientLayer = nil;
                gradientLayer = [self drawableBasicGradientLayerForLayer:strokeLayer
                                                                gradient:(IJSVGGradient*)node.stroke];
                gradientLayer.referencingLayer = layer;
                gradientLayer.frame = CGRectInset(strokeLayer.frame,
                                                  -strokeWidthDifference,
                                                  -strokeWidthDifference);
                
                strokeLayer.strokeColor = NSColor.whiteColor.CGColor;
                gradientLayer.maskLayer = strokeLayer;
                [layer addSublayer:gradientLayer];
                break;
            }
                
            // generic
            default: {
                [layer addSublayer:strokeLayer];
                break;
            }
        }
        
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
//    CGFloat increase = layer.lineWidth / 2.f;
////    frame = CGRectInset(frame, -increase, -increase);
    
    // now we know what to do, we need to transform the path
//    CGAffineTransform transform = CGAffineTransformMakeTranslation(increase, increase);
//    CGPathRef path = CGPathCreateCopyByTransformingPath(layer.path, &transform);
    layer.frame = frame;
    layer.path = layer.path;
//    layer.borderColor = NSColor.redColor.CGColor;
//    layer.borderWidth = 1.f;
//    CGPathRelease(path);
    
    return layer;
}

- (IJSVG_DRAWABLE_LAYER)drawableLayerForRootNode:(IJSVGRootNode*)node
{
    IJSVGGroupLayer* layer = [IJSVGGroupLayer layer];
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
    IJSVGGroupLayer* layer = [IJSVGGroupLayer layer];
//    layer.borderColor = NSColor.purpleColor.CGColor;
//    layer.borderWidth = 1.f;
    CGRect rect = [IJSVGLayer calculateFrameForSublayers:sublayers];
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

#pragma mark Gradients and Patterns

- (IJSVGGradientLayer*)drawableBasicGradientLayerForLayer:(IJSVG_DRAWABLE_LAYER)layer
                                                 gradient:(IJSVGGradient*)gradient
{
    // gradient fill
    IJSVGGradientLayer* gradientLayer = [IJSVGGradientLayer layer];
    gradientLayer.gradient = gradient;
    gradientLayer.frame = layer.boundingBoxBounds;
    gradientLayer.viewBox = _viewBox;
    return gradientLayer;
}

- (IJSVG_DRAWABLE_LAYER)drawableGradientLayerForPathNode:(IJSVGPath*)node
                                                gradient:(IJSVGGradient*)gradient
                                                   layer:(IJSVG_DRAWABLE_LAYER)layer
{
    // gradient fill
    IJSVGGradientLayer* gradientLayer = [self drawableBasicGradientLayerForLayer:layer
                                                                        gradient:gradient];
    
    // we must clip the fill to the path that we are drawing in, its simply just a matter
    // of asking the tree for a path based on the layer passed in, but then moving
    // it back to our current coordinate space
    IJSVG_DRAWABLE_LAYER clipLayer = [self drawableBasicLayerForPathNode:node];
    gradientLayer.clipRule = layer.fillRule;
    gradientLayer.clipLayer = clipLayer;
    clipLayer.frame = clipLayer.bounds;
    return gradientLayer;
}

- (IJSVGPatternLayer*)drawableBasicPatternLayerForLayer:(IJSVG_DRAWABLE_LAYER)layer
                                                pattern:(IJSVGPattern*)pattern
{
    // pattern fill
    IJSVGPatternLayer* patternLayer = [IJSVGPatternLayer layer];
    patternLayer.patternNode = pattern;
    patternLayer.frame = layer.boundingBoxBounds;
    
    CALayer<IJSVGDrawableLayer>* patternFill = [self drawableLayerForNode:pattern];
    patternFill.referencingLayer = patternLayer;
    patternLayer.pattern = patternFill;
    return patternLayer;
}

- (IJSVG_DRAWABLE_LAYER)drawablePatternLayerForPathNode:(IJSVGPath*)node
                                                pattern:(IJSVGPattern*)pattern
                                                  layer:(IJSVG_DRAWABLE_LAYER)layer
{
    // pattern fill
    IJSVGPatternLayer* patternLayer = [self drawableBasicPatternLayerForLayer:layer
                                                                      pattern:pattern];
    
    // we must clip the fill to the path that we are drawing in, its simply just a matter
    // of asking the tree for a path based on the layer passed in, but then moving
    // it back to our current coordinate space
    IJSVG_DRAWABLE_LAYER clipLayer = [self drawableBasicLayerForPathNode:node];
    patternLayer.clipRule = layer.fillRule;
    patternLayer.clipLayer = clipLayer;
    clipLayer.frame = clipLayer.bounds;
    [patternLayer setNeedsDisplay];
    return patternLayer;
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
        layer.clipRule = layer.fillRule;
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
    IJSVGTransformLayer* parentLayer = [IJSVGTransformLayer layer];
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
