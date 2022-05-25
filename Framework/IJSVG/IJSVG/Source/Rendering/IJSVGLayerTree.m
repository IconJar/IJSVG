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
#import <IJSVG/IJSVGRootLayer.h>
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
#import <IJSVG/IJSVGFilterLayer.h>

@implementation IJSVGLayerTree

@synthesize style = _style;

- (id)init
{
    if ((self = [super init]) != nil) {
    }
    return self;
}

- (id)initWithViewPortRect:(CGRect)viewPort
              backingScale:(CGFloat)scale
{
    if((self = [super init]) != nil) {
        _viewPortStack = [[NSMutableArray alloc] init];
        _backingScale = scale;
        [self pushViewPort:viewPort];
    }
    return self;
}

- (void)pushViewPort:(CGRect)viewPort
{
    NSValue* value = [NSValue valueWithRect:NSRectFromCGRect(viewPort)];
    [_viewPortStack addObject:value];
}

- (CGRect)viewPort
{
    NSValue* value = _viewPortStack.lastObject;
    return (CGRect)NSRectToCGRect(value.rectValue);
}

- (void)popViewPort
{
    [_viewPortStack removeLastObject];
}

- (IJSVGRootLayer*)rootLayerForRootNode:(IJSVGRootNode*)rootNode
{
    return (IJSVGRootLayer*)[self drawableLayerForNode:rootNode];
}

- (CALayer<IJSVGDrawableLayer>*)drawableLayerForNode:(IJSVGNode*)node
{
    CALayer<IJSVGDrawableLayer>* layer = nil;
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
        layer = [self applyFilter:node.filter
                          toLayer:layer
                         fromNode:node];
        return [self applyTransforms:node.transforms
                             toLayer:layer
                            fromNode:node];
    }
    return layer;
}

- (CALayer<IJSVGDrawableLayer>*)drawableBasicLayerForPathNode:(IJSVGPath*)node
{
    IJSVGShapeLayer* layer = [IJSVGShapeLayer layer];
    layer.primitiveType = node.primitiveType;
    if(CGPathIsEmpty(node.path) == NO) {
        [self applyTransformedPathToShapeLayer:layer
                                      fromNode:node];
    }
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
    if(pathBounds.origin.x != 0.f || pathBounds.origin.y != 0.f) {
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-pathBounds.origin.x,
                                                                       -pathBounds.origin.y);
        CGPathRef transformedPath = CGPathCreateCopyByTransformingPath(node.path, &transform);
        layer.path = transformedPath;
        CGPathRelease(transformedPath);
    } else {
        layer.path = node.path;
    }
    
    // note that we store the bounding box at this point, as it can be modified later
    // with strokes, however, SVG spec defined bounding box is the path without strokes
    // and without control points.
    layer.frame = pathBounds;
    layer.outerBoundingBox = pathBounds;
    layer.boundingBox = pathBounds;
}

- (CALayer<IJSVGDrawableLayer>*)drawableLayerForPathNode:(IJSVGPath*)node
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
        layer.outerBoundingBox = layer.frame;
    }
        
    // generic fill color
    CALayer<IJSVGDrawableLayer>* fillLayer = nil;
    IJSVGLayerFillType fillType = [IJSVGLayer fillTypeForFill:fill];
    switch(fillType) {
        // just a generic fill color
        default:
        case IJSVGLayerFillTypeColor: {
            IJSVGColorNode* colorNode = (IJSVGColorNode*)fill;
            NSColor* color = colorNode.color ?: NSColor.blackColor;
            
            if(colorNode.isNoneOrTransparent == YES) {
                color = nil;
            }
            
            // set the color against the layer — we cant just use fill layer due to how
            // the stroke is position within the frame, we have to create another
            // layer to draw the colour into!
            IJSVGShapeLayer* shape = (IJSVGShapeLayer*)[self drawableBasicLayerForPathNode:node];
            shape.fillColor = color.CGColor;
            CGRect shapeRect = shape.frame;
            
            // reset back to 0, later on this will move in enough for the stroke
            // to be half over the edge
            shapeRect.origin.x = 0.f;
            shapeRect.origin.y = 0.f;
            shape.frame = shapeRect;
            fillLayer = shape;
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
    }
    
    if(fillLayer != nil) {
        // fill opacity is precalculated for its colour when the type is fillColor,
        // for fills such as gradients and patterns, just reduce the opacity down
        if(fillType != IJSVGLayerFillTypeColor && node.fillOpacity.value != 1.f) {
            fillLayer.opacity = node.fillOpacity.value;
        }
        fillLayer.affineTransform = CGAffineTransformTranslate(fillLayer.affineTransform,
                                                                   strokeWidthDifference,
                                                                   strokeWidthDifference);
        [layer addSublayer:fillLayer];
    }
    
        
    // stroke the path
    if(strokeLayer != nil) {
        // we need to work out what type of fill we need for the layer
        switch([IJSVGLayer fillTypeForFill:node.stroke]) {
            // patterns
            case IJSVGLayerFillTypePattern: {
                IJSVGPatternLayer* patternLayer = nil;
                patternLayer = [self drawableBasicPatternLayerForLayer:strokeLayer
                                                               pattern:(IJSVGPattern*)node.stroke];
                patternLayer.referencingLayer = layer;
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

- (CALayer<IJSVGDrawableLayer>*)drawableStrokedLayerForPathNode:(IJSVGPath*)node
{
    IJSVGStrokeLayer* layer = [IJSVGStrokeLayer layer];
    [self applyTransformedPathToShapeLayer:layer
                                  fromNode:node];
    
    // reset the frame back to zero
    CGRect frame = layer.frame;
    
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
    CGFloat lineWidth = node.strokeWidth.value;
    
    // work out line styles
    IJSVGLineCapStyle lineCapStyle = node.lineCapStyle;
    IJSVGLineJoinStyle lineJoinStyle = node.lineJoinStyle;
    
    // apply the properties
    layer.lineWidth = lineWidth;
    layer.lineCap = [IJSVGUtils CGLineCapForCapStyle:lineCapStyle];
    layer.lineJoin = [IJSVGUtils CGLineJoinForJoinStyle:lineJoinStyle];
    layer.miterLimit = node.strokeMiterLimit.value;
    
    CGFloat strokeOpacity = 1.f;
    if(node.strokeOpacity.value != 0.f) {
        strokeOpacity = node.strokeOpacity.value;
    }
    layer.opacity = strokeOpacity;
    
    // dashing
    layer.lineDashPhase = node.strokeDashOffset.value;
    if(node.strokeDashArrayCount != IJSVGInheritedIntegerValue) {
        layer.lineDashPattern = node.lineDashPattern;
    }
    
    // lets resize the layer as we have computed everything at this point
    CGFloat increase = layer.lineWidth / 2.f;
    frame = CGRectInset(frame, -increase, -increase);
    
    
    // now we know what to do, we need to transform the path
    CGAffineTransform transform = CGAffineTransformMakeTranslation(increase, increase);
    CGPathRef path = CGPathCreateCopyByTransformingPath(layer.path, &transform);
    
    // make sure we reset this back to zero
    layer.frame = (CGRect) {
        .origin = CGPointZero,
        .size = frame.size
    };
    layer.outerBoundingBox = layer.frame;
    layer.path = path;
    CGPathRelease(path);
    
    return layer;
}

- (CALayer<IJSVGDrawableLayer>*)drawableLayerForRootNode:(IJSVGRootNode*)node
{
    IJSVGRootLayer* layer = [IJSVGRootLayer layer];
    layer.viewBox = node.viewBox;
    layer.intrinsicSize = node.intrinsicSize;
    layer.viewBoxAlignment = node.viewBoxAlignment;
    layer.viewBoxMeetOrSlice = node.viewBoxMeetOrSlice;
    layer.backingScaleFactor = _backingScale;
    
    // we are the top most SVG, not a nested one,
    // we can simply use the viewport given to us
    CGRect frame = CGRectZero;
    if(_viewPortStack.count == 1) {
        frame.size = self.viewPort.size;
    } else {
        frame = CGRectMake(0.f, 0.f,
                           node.intrinsicSize.width.value,
                           node.intrinsicSize.height.value);
    }
    layer.frame = frame;
    [self pushViewPort:layer.frame];
    layer.sublayers = [self drawableLayersForNodes:node.children];
    [self popViewPort];
    return layer;
}

- (CALayer<IJSVGDrawableLayer>*)drawableLayerForGroupNode:(IJSVGGroup*)node
{
    NSArray<CALayer<IJSVGDrawableLayer>*>* layers = [self drawableLayersForNodes:node.children];
    return [self drawableLayerForGroupNode:node
                                 sublayers:layers];
}

- (CALayer<IJSVGDrawableLayer>*)drawableLayerForGroupNode:(IJSVGNode*)node
                                                sublayers:(NSArray<CALayer<IJSVGDrawableLayer>*>*)sublayers
{
    IJSVGGroupLayer* layer = [IJSVGGroupLayer layer];
    layer.boundingBox = [IJSVGLayer calculateFrameForSublayers:sublayers];
    layer.outerBoundingBox = layer.boundingBox;
    layer.sublayers = sublayers;
    return layer;
}

- (NSArray<CALayer<IJSVGDrawableLayer>*>*)drawableLayersForNodes:(NSArray<IJSVGNode*>*)nodes
{
    NSMutableArray<CALayer<IJSVGDrawableLayer>*>* layers = nil;
    layers = [[NSMutableArray alloc] initWithCapacity:nodes.count];
    for(IJSVGNode* node in nodes) {
        CALayer<IJSVGDrawableLayer>* layer = [self drawableLayerForNode:node];
        if(layer != nil) {
            [layers addObject:layer];
        }
    }
    return layers;
}

#pragma mark Gradients and Patterns

- (IJSVGGradientLayer*)drawableBasicGradientLayerForLayer:(CALayer<IJSVGDrawableLayer>*)layer
                                                 gradient:(IJSVGGradient*)gradient
{
    // gradient fill
    IJSVGGradientLayer* gradientLayer = [IJSVGGradientLayer layer];
    gradientLayer.backingScaleFactor = _backingScale;
    gradientLayer.gradient = gradient;
    gradientLayer.frame = layer.bounds;
    gradientLayer.viewBox = self.viewPort;
    [gradientLayer setNeedsDisplay];
    return gradientLayer;
}

- (CALayer<IJSVGDrawableLayer>*)drawableGradientLayerForPathNode:(IJSVGPath*)node
                                                        gradient:(IJSVGGradient*)gradient
                                                           layer:(CALayer<IJSVGDrawableLayer>*)layer
{
    // gradient fill
    IJSVGGradientLayer* gradientLayer = [self drawableBasicGradientLayerForLayer:layer
                                                                        gradient:gradient];
    
    // we must clip the fill to the path that we are drawing in, its simply just a matter
    // of asking the tree for a path based on the layer passed in, but then moving
    // it back to our current coordinate space
    CALayer<IJSVGDrawableLayer>* clipLayer = [self drawableBasicLayerForPathNode:node];
    gradientLayer.clipRule = layer.fillRule;
    gradientLayer.clipLayer = clipLayer;
    clipLayer.frame = clipLayer.bounds;
    return gradientLayer;
}

- (IJSVGPatternLayer*)drawableBasicPatternLayerForLayer:(CALayer<IJSVGDrawableLayer>*)layer
                                                pattern:(IJSVGPattern*)pattern
{
    // pattern fill
    IJSVGPatternLayer* patternLayer = [IJSVGPatternLayer layer];
    patternLayer.patternNode = pattern;
    patternLayer.frame = (CGRect) {
        .origin = CGPointZero,
        .size = layer.outerBoundingBox.size
    };
    
    CALayer<IJSVGDrawableLayer>* patternFill = [self drawableLayerForNode:pattern];
    patternFill.referencingLayer = patternLayer;
    patternLayer.pattern = patternFill;
    [patternLayer setNeedsDisplay];
    return patternLayer;
}

- (CALayer<IJSVGDrawableLayer>*)drawablePatternLayerForPathNode:(IJSVGPath*)node
                                                pattern:(IJSVGPattern*)pattern
                                                  layer:(CALayer<IJSVGDrawableLayer>*)layer
{
    // pattern fill
    IJSVGPatternLayer* patternLayer = [self drawableBasicPatternLayerForLayer:layer
                                                                      pattern:pattern];
    
    // we must clip the fill to the path that we are drawing in, its simply just a matter
    // of asking the tree for a path based on the layer passed in, but then moving
    // it back to our current coordinate space
    CALayer<IJSVGDrawableLayer>* clipLayer = [self drawableBasicLayerForPathNode:node];
    patternLayer.clipRule = layer.fillRule;
    patternLayer.clipLayer = clipLayer;
    clipLayer.frame = clipLayer.bounds;
    [patternLayer setNeedsDisplay];
    return patternLayer;
}

#pragma mark Defaults

- (void)applyDefaultsToLayer:(CALayer<IJSVGDrawableLayer>*)layer
                    fromNode:(IJSVGNode*)node
{
    // mask the layer
    if(node.mask != nil) {
        CALayer<IJSVGDrawableLayer>* maskLayer = [self drawableLayerForNode:node.mask];
        if(node.clipPath.contentUnits == IJSVGUnitUserSpaceOnUse) {
            [IJSVGLayer transformLayer:maskLayer
                intoUserSpaceUnitsFrom:layer];
        }
        layer.maskLayer = maskLayer;
    }
    
    // add the clip mask if any
    if(node.clipPath != nil) {
        CALayer<IJSVGDrawableLayer>* clipLayer = [self drawableLayerForNode:node.clipPath];
        if(node.clipPath.contentUnits == IJSVGUnitUserSpaceOnUse) {
            [IJSVGLayer transformLayer:clipLayer
                intoUserSpaceUnitsFrom:layer];
        }
        layer.clipRule = clipLayer.fillRule;
        layer.clipLayer = clipLayer;
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

#pragma mark Filters

- (CALayer<IJSVGDrawableLayer>*)applyFilter:(IJSVGFilter*)filter
                                    toLayer:(CALayer<IJSVGDrawableLayer>*)layer
                                   fromNode:(IJSVGNode*)node
{
    if(filter == nil || filter.valid == NO) {
        return layer;
    }
    IJSVGFilterLayer* filterLayer = [IJSVGFilterLayer layer];
    filterLayer.filter = filter;
    filterLayer.frame = layer.frame;
    filterLayer.sublayer = layer;
    layer.referencingLayer = filterLayer;
    return filterLayer;
}

#pragma mark Transforms

- (CALayer<IJSVGDrawableLayer>*)applyTransforms:(NSArray<IJSVGTransform*>*)transforms
                                        toLayer:(CALayer<IJSVGDrawableLayer>*)layer
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
    IJSVGImageLayer* layer = [[IJSVGImageLayer alloc] initWithImage:image];
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
