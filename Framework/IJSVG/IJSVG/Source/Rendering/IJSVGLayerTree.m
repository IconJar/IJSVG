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
#import <IJSVG/IJSVGThreadManager.h>

@implementation IJSVGLayerTree

@synthesize style = _style;

- (id)init
{
    if((self = [super init]) != nil) {
        _viewPortStack = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)pushViewPort:(CGRect)viewPort
{
    NSValue* value = [NSValue valueWithRect:viewPort];
    [_viewPortStack addObject:value];
}

- (CGRect)viewPort
{
    NSValue* value = _viewPortStack.lastObject;
    return value.rectValue;
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

+ (CGPathRef)newPathFromStrokedShapeLayer:(IJSVGShapeLayer*)shapeLayer
{
    CGLineCap lineCap = [IJSVGUtils CGLineCapForCALineCap:shapeLayer.lineCap];
    CGLineJoin lineJoin = [IJSVGUtils CGLineJoinForCALineJoin:shapeLayer.lineJoin];
    CGPathRef dashedPath = NULL;
    if(shapeLayer.lineDashPattern != nil && shapeLayer.lineDashPattern.count != 0.f) {
        NSUInteger count = shapeLayer.lineDashPattern.count;
        CGFloat* lengths = (CGFloat*)malloc(sizeof(CGFloat)*count);
        NSUInteger i = 0;
        for(NSNumber* number in shapeLayer.lineDashPattern) {
            lengths[i++] = (CGFloat)number.floatValue;
        }
        dashedPath = CGPathCreateCopyByDashingPath(shapeLayer.path, NULL,
                                                   shapeLayer.lineDashPhase,
                                                   lengths, count);
        (void)free(lengths), lengths = NULL;
    }
    CGPathRef path = dashedPath ?: shapeLayer.path;
    CGPathRef newPath = CGPathCreateCopyByStrokingPath(path, NULL, shapeLayer.lineWidth,
                                                       lineCap, lineJoin,
                                                       shapeLayer.miterLimit);
    if(dashedPath != NULL) {
        CGPathRelease(dashedPath);
    }
    return newPath;
}

- (NSColor*)colorForColor:(NSColor*)color
           matchingTraits:(IJSVGColorUsageTraits)traits
{
    return [_style.colors colorForColor:color
                         matchingTraits:traits];
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
        [layer setLayer:strokeLayer
           forUsageType:IJSVGLayerUsageTypeStroke];

        // make sure we update the bounding box as it has changed
        layer.frame = CGRectInset(layer.frame,
                                  -strokeWidthDifference,
                                  -strokeWidthDifference);
        layer.outerBoundingBox = layer.frame;
    }
        
    // generic fill color
    CALayer<IJSVGDrawableLayer>* fillLayer = nil;
    IJSVGLayerFillType fillType = [IJSVGLayer fillTypeForFill:fill];
    
    IJSVGLayerUsageType fillUsageType = IJSVGLayerUsageTypeFillGeneric;
    switch(fillType) {
        // just a generic fill color
        default:
        case IJSVGLayerFillTypeColor: {
            fillUsageType = IJSVGLayerUsageTypeFillGeneric;
            IJSVGColorNode* colorNode = (IJSVGColorNode*)fill;
            NSColor* color = colorNode.color ?: NSColor.blackColor;
            
            // could be an overall replaced fillColor from the style
            if(_style.fillColor != nil) {
                color = _style.fillColor;
            }
            
            if(colorNode.isNoneOrTransparent == YES) {
                color = nil;
            } else {
                // compute any color that may have been changed via the styles
                NSColor* repColor = [self colorForColor:color
                                         matchingTraits:IJSVGColorUsageTraitFill];
                color = repColor ?: color;
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
            fillUsageType = IJSVGLayerUsageTypeFillPattern;
            fillLayer = [self drawablePatternLayerForPathNode:node
                                                      pattern:(IJSVGPattern*)node.fill
                                                        layer:layer];
            break;
        }
        
        // gradient fill
        case IJSVGLayerFillTypeGradient: {
            fillUsageType = IJSVGLayerUsageTypeFillGradient;
            fillLayer = [self drawableGradientLayerForPathNode:node
                                                      gradient:(IJSVGGradient*)node.fill
                                                         layer:layer];
            
            break;
        }
    }
    
    if(fillLayer != nil) {
        // fill opacity is precalculated for its colour when the type is fillColor,
        // for fills such as gradients and patterns, just reduce the opacity down
        [layer addTraits:IJSVGLayerTraitFilled];
        if(node.fillOpacity.value != 1.f) {
            fillLayer.opacity = node.fillOpacity.value;
        }
        fillLayer.affineTransform = CGAffineTransformTranslate(fillLayer.affineTransform,
                                                                   strokeWidthDifference,
                                                                   strokeWidthDifference);
        [layer addSublayer:fillLayer];
        [layer setLayer:fillLayer
           forUsageType:fillUsageType];
    }
    
        
    // stroke the path
    if(strokeLayer != nil) {
        // we need to work out what type of fill we need for the layer
        [layer addTraits:IJSVGLayerTraitStroked];
        IJSVGLayerFillType type = [IJSVGLayer fillTypeForFill:node.stroke];
        
        switch(type) {
            // patterns
            case IJSVGLayerFillTypePattern: {
                IJSVGPatternLayer* patternLayer = nil;
                patternLayer = [self drawableBasicPatternLayerForLayer:strokeLayer
                                                               pattern:(IJSVGPattern*)node.stroke];
                patternLayer.referencingLayer = layer;
                
                // clip the drawing to a stroked path
                CGPathRef path = [self.class newPathFromStrokedShapeLayer:strokeLayer];
                patternLayer.clipPath = path;
                CGPathRelease(path);
                [layer setLayer:patternLayer
                   forUsageType:IJSVGLayerUsageTypeStrokePattern];
                [layer addSublayer:patternLayer];
                break;
            }
                
            // gradients
            case IJSVGLayerFillTypeGradient: {
                IJSVGGradientLayer* gradientLayer = nil;
                gradientLayer = [self drawableBasicGradientLayerForLayer:strokeLayer
                                                                gradient:(IJSVGGradient*)node.stroke];
                gradientLayer.referencingLayer = layer;
                
                // clip the drawing to a stroked path
                CGPathRef path = [self.class newPathFromStrokedShapeLayer:strokeLayer];
                gradientLayer.clipPath = path;
                CGPathRelease(path);
                [layer setLayer:gradientLayer
                   forUsageType:IJSVGLayerUsageTypeStrokeGradient];
                [layer addSublayer:gradientLayer];
                break;
            }
                
            // generic
            default: {
                [layer setLayer:strokeLayer
                   forUsageType:IJSVGLayerUsageTypeStrokeGeneric];
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
    
    
    // replacement colour
    NSColor* repColor = [self colorForColor:strokeColor
                             matchingTraits:IJSVGColorUsageTraitStroke];
    strokeColor = repColor ?: strokeColor;
    
    // use the users overriding color instead
    if(_style.strokeColor != nil) {
        strokeColor = _style.strokeColor;
    }
    
    // set the color
    layer.fillColor = nil;
    layer.strokeColor = strokeColor.CGColor;
    
    // work out line width
    CGFloat lineWidth = [node.strokeWidth computeValue:frame.size.width];
    
    if(_style.lineWidth != IJSVGInheritedFloatValue) {
        lineWidth = _style.lineWidth;
    }
    
    // work out line styles
    IJSVGLineCapStyle lineCapStyle = node.lineCapStyle;
    IJSVGLineJoinStyle lineJoinStyle = node.lineJoinStyle;
    CGFloat miterLimit = node.strokeMiterLimit.value;
    
    // use anything declared on the style
    if(_style.lineCapStyle != IJSVGLineCapStyleNone &&
       _style.lineCapStyle != IJSVGLineCapStyleInherit) {
        lineCapStyle = _style.lineCapStyle;
    }
    
    if(_style.lineJoinStyle != IJSVGLineJoinStyleNone &&
       _style.lineJoinStyle != IJSVGLineJoinStyleInherit) {
        lineJoinStyle = _style.lineJoinStyle;
    }
    
    // miter limit can be set via the style
    if(_style.miterLimit != IJSVGInheritedFloatValue) {
        miterLimit = _style.miterLimit;
    }
        
    // apply the properties
    layer.lineWidth = lineWidth;
    layer.lineCap = [IJSVGUtils CGLineCapForCapStyle:lineCapStyle];
    layer.lineJoin = [IJSVGUtils CGLineJoinForJoinStyle:lineJoinStyle];
    layer.miterLimit = miterLimit;
    
    CGFloat strokeOpacity = 1.f;
    if(node.strokeOpacity.value != 1.f) {
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
    layer.hasExplicitViewBox = node.hasExplicitViewBox;
    layer.rendersWithViewBoxTransform =
        node.hasExplicitViewBox == YES ||
        node.intrinsicDimensions == (IJSVGIntrinsicDimensionWidth | IJSVGIntrinsicDimensionHeight);
    layer.intrinsicSize = node.intrinsicSize;
    layer.viewBoxAlignment = node.viewBoxAlignment;
    layer.viewBoxMeetOrSlice = node.viewBoxMeetOrSlice;
        
    // we are the top most SVG, not a nested one,
    // we can simply use the viewport given to us
    CGRect frame = CGRectZero;
    frame = CGRectMake(node.x.value, node.y.value,
                       node.intrinsicSize.width.value,
                       node.intrinsicSize.height.value);
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
    CGRect bbox = [IJSVGLayer calculateFrameForSublayers:sublayers];
    layer.frame = bbox;
    layer.boundingBox = bbox;
    layer.outerBoundingBox = bbox;

    // Make sublayer FRAME positions RELATIVE to the group's origin.
    // The outerBoundingBox stays at absolute position (used for gradient
    // coordinate chain calculations via userSpaceTransformForLayer:).
    // The frame is used by renderLayerTree: for positioning sublayers.
    if(bbox.origin.x != 0 || bbox.origin.y != 0) {
        for(CALayer<IJSVGDrawableLayer>* sublayer in sublayers) {
            CGRect sf = sublayer.frame;
            sublayer.frame = CGRectMake(sf.origin.x - bbox.origin.x,
                                         sf.origin.y - bbox.origin.y,
                                         sf.size.width, sf.size.height);
            // DON'T shift outerBoundingBox — it's used for absolute coordinate chains
        }
    }

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

    // Keep each render layer on its own gradient instance. Shared gradient
    // nodes are reused across multiple fills in the parsed SVG tree, and some
    // renderer state ends up bleeding between siblings when they draw against
    // the same object.
    gradient = gradient.copy;

    // lets check its alpha properties on the colors
    IJSVGColorUsageTraits traits = IJSVGColorUsageTraitGradientStop;
    if(_style.colors.replacedColorCount != 0 &&
       [_style.colors matchesReplacementTraits:traits] == YES) {
        NSMutableArray* colors = nil;
        colors = [[NSMutableArray alloc] initWithCapacity:gradient.numberOfStops];
        for(NSColor* color in gradient.colors) {
            NSColor* repColor = [self colorForColor:color
                                     matchingTraits:traits];
            NSColor* compColor = repColor ?: color;
            [colors addObject:compColor];
        }
        gradient.colors = colors;
    }
    
    gradientLayer.gradient = gradient;
    gradientLayer.frame = layer.bounds;
    gradientLayer.viewBox = self.viewPort;
    gradientLayer.opacity = layer.opacity;
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
    gradientLayer.clipRule = layer.fillRule;
    gradientLayer.clipPath = ((IJSVGShapeLayer*)layer).path;
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
    patternLayer.opacity = layer.opacity;
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
    patternLayer.clipRule = layer.fillRule;
    patternLayer.clipPath = ((IJSVGShapeLayer*)layer).path;
    [patternLayer setNeedsDisplay];
    return patternLayer;
}

- (CALayer<IJSVGDrawableLayer>*)maskLayerFromNode:(IJSVGMask*)mask
                                 referencingLayer:(CALayer<IJSVGDrawableLayer>*)layer
                                        fromLayer:(CALayer<IJSVGDrawableLayer>*)fromLayer

{
    IJSVGMask* maskNode = mask;
    CALayer<IJSVGDrawableLayer>* maskLayer = nil;
    maskLayer = fromLayer ?: (CALayer<IJSVGDrawableLayer>*)[self drawableLayerForNode:maskNode];
    CGRect viewPort = maskNode.units == IJSVGUnitUserSpaceOnUse ? self.viewPort : layer.boundingBox;
    CGFloat width = CGRectGetWidth(viewPort);
    CGFloat height = CGRectGetHeight(viewPort);
    CGRect rect = CGRectZero;
    CGRect layerBounds = layer.boundingBox;
    IJSVGUnitLength* xUnit = maskNode.x;
    IJSVGUnitLength* yUnit = maskNode.y;
    IJSVGUnitLength* widthUnit = maskNode.width;
    IJSVGUnitLength* heightUnit = maskNode.height;
    
    // infer the fact that object bounding box must be % values of
    // the box its being drawn into
    if(maskNode.units == IJSVGUnitObjectBoundingBox) {
        xUnit = [xUnit lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        yUnit = [yUnit lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        widthUnit = [widthUnit lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        heightUnit = [heightUnit lengthWithUnitType:IJSVGUnitLengthTypePercentage];
    }
    
    // calculate the rect, rect is the clipping rect
    rect.origin.x = [xUnit computeValue:width];
    rect.origin.y = [yUnit computeValue:height];
    rect.size.width = [widthUnit computeValue:width];
    rect.size.height = [heightUnit computeValue:height];
    // calculate the actual masking bounds, maskingBounds is
    // is the rect that the final mask is transformed into
    // Object-bounding-box mask regions are relative to the target element's
    // bbox in local/user space, including its origin. `innerBoundingBox`
    // normalizes that origin away, which shifts masks toward (0,0) after the
    // relative-coordinate transition.
    CGRect maskBounds = maskLayer.outerBoundingBox;
    CGRect maskingBounds = layerBounds;
    maskingBounds.size.width = maskBounds.size.width;
    maskingBounds.size.height = maskBounds.size.height;
    
    CGAffineTransform userSpaceTransform = [IJSVGLayer userSpaceTransformForLayer:layer];
    if(maskNode.contentUnits == IJSVGUnitUserSpaceOnUse) {
        // User-space mask content is already positioned in the document's
        // coordinate system. Anchoring the mask image to the target layer's
        // bbox shifts it by the target origin and drops masks on <use> /
        // objectBoundingBox cases.
        maskingBounds = CGRectApplyAffineTransform(maskBounds, userSpaceTransform);
        
        // we need to move all the layers back if they are into the userSpace
        // coordinate system
        for(CALayer<IJSVGDrawableLayer> *childLayer in maskLayer.sublayers) {
            CGRect innerBoundingBox = childLayer.innerBoundingBox;
            CGAffineTransform innerTransform = CGAffineTransformMakeTranslation(-innerBoundingBox.origin.x,
                                                                                -innerBoundingBox.origin.y);
            childLayer.frame = CGRectApplyAffineTransform(childLayer.frame, userSpaceTransform);
            childLayer.frame = CGRectApplyAffineTransform(childLayer.frame, innerTransform);
        }
        
    }
    
    if(maskNode.units == IJSVGUnitUserSpaceOnUse) {
        rect = CGRectApplyAffineTransform(rect, userSpaceTransform);
    }
    
    maskLayer.maskingBoundingBox = maskingBounds;
    maskLayer.maskingClippingRect = rect;
    maskLayer.maskUsesAlpha = maskNode.usesAlphaMask;
    maskLayer.referencingLayer = layer;
    return maskLayer;
}

- (NSArray<CALayer<IJSVGDrawableLayer>*>*)clipLayersFromNode:(IJSVGClipPath*)node
                                            referencingLayer:(CALayer<IJSVGDrawableLayer>*)layer
                                                   fromLayer:(CALayer<IJSVGDrawableLayer>*)fromLayer
{
    NSMutableArray<CALayer<IJSVGDrawableLayer>*>* layers = nil;
    layers = [[NSMutableArray alloc] init];
    IJSVGClipPath* refClipPath = node;
    IJSVGGroupLayer* groupLayer = nil;
    while(refClipPath != nil) {
        groupLayer = (IJSVGGroupLayer*)[self drawableLayerForNode:refClipPath];
        if(groupLayer != nil) {
            groupLayer.referencingLayer = layer;
            [layers addObject:groupLayer];
        }
        refClipPath = refClipPath.clipPath;
    }
    CGRect clippingRect = [IJSVGLayer calculateFrameForSublayers:layers];
    CGAffineTransform userSpaceTransform = [IJSVGLayer userSpaceTransformForLayer:layer];
    CGAffineTransform clippingTransform = CGAffineTransformIdentity;
    if(node.contentUnits == IJSVGUnitUserSpaceOnUse) {
        clippingRect = CGRectApplyAffineTransform(clippingRect, userSpaceTransform);
        clippingTransform = userSpaceTransform;
    }
    CGAffineTransform ident = CGAffineTransformMakeTranslation(-CGRectGetMinX(clippingRect),
                                                               -CGRectGetMinY(clippingRect));
    clippingTransform = CGAffineTransformConcat(clippingTransform, ident);
    layer.clippingTransform = clippingTransform;
    layer.clippingBoundingBox = clippingRect;
    return layers;
}

- (CGPathRef)newClipPathFromNode:(IJSVGClipPath*)node
                       fromLayer:(CALayer<IJSVGDrawableLayer>*)layer
{
    CGMutablePathRef mPath = CGPathCreateMutable();
    CGAffineTransform transform = CGAffineTransformIdentity;
    if(node.contentUnits == IJSVGUnitUserSpaceOnUse) {
        transform = [IJSVGLayer userSpaceTransformForLayer:layer];
    }
    // Clip paths render in the target layer's local coordinate space.
    // Group layers now carry their absolute origin in `frame`, so using
    // `innerBoundingBox` here re-adds that absolute origin and misplaces
    // user-space clips on groups. `bounds` keeps the clip local.
    CGRect layerRect = layer.bounds;
    CGAffineTransform layerTransform = CGAffineTransformMakeTranslation(CGRectGetMinX(layerRect),
                                                                        CGRectGetMinY(layerRect));
    transform = CGAffineTransformConcat(transform, layerTransform);
    IJSVGClipPath* clipPath = node;
    while(clipPath != nil) {
        [IJSVGPath recursivelyAddPathedNodesPaths:clipPath.children
                                        transform:transform
                                           toPath:mPath];
        clipPath = clipPath.clipPath;
    }
    return mPath;
}

- (BOOL)_nodeIsSafeForMatchingClipSeam:(IJSVGNode*)node
{
    if([node isKindOfClass:IJSVGPath.class] == NO) {
        return NO;
    }
    if([node matchesTraits:IJSVGNodeTraitStroked] == YES) {
        return NO;
    }
    if(node.clipPath != nil || node.mask != nil || node.filter != nil) {
        return NO;
    }
    return YES;
}

- (BOOL)_pathNode:(IJSVGPath*)pathNode
matchesClipPathNode:(IJSVGPath*)clipPathNode
{
    CGAffineTransform pathTransform = IJSVGConcatTransforms(pathNode.transforms);
    CGAffineTransform clipTransform = IJSVGConcatTransforms(clipPathNode.transforms);
    CGPathRef transformedPath = CGPathCreateCopyByTransformingPath(pathNode.path,
                                                                   &pathTransform);
    CGPathRef transformedClipPath = CGPathCreateCopyByTransformingPath(clipPathNode.path,
                                                                       &clipTransform);
    BOOL matches = CGPathEqualToPath(transformedPath, transformedClipPath);
    CGPathRelease(transformedPath);
    CGPathRelease(transformedClipPath);
    return matches;
}

- (CGFloat)_matchingClipSeamXForNode:(IJSVGNode*)node
                               layer:(CALayer<IJSVGDrawableLayer>*)layer
                            clipPath:(IJSVGClipPath*)clipPath
                            clipRule:(IJSVGWindingRule)clipRule
{
    if([node isKindOfClass:IJSVGGroup.class] == NO ||
       clipPath.clipPath != nil ||
       clipRule == IJSVGWindingRuleEvenOdd) {
        return CGFLOAT_MAX;
    }
    IJSVGGroup *group = (IJSVGGroup *)node;
    if(group.children.count == 0 ||
       group.children.count != clipPath.children.count ||
       group.children.count != layer.sublayers.count ||
       group.children.count != 2) {
        return CGFLOAT_MAX;
    }
    for(NSUInteger idx = 0; idx < group.children.count; idx++) {
        IJSVGNode *groupChild = group.children[idx];
        IJSVGNode *clipChild = clipPath.children[idx];
        if([self _nodeIsSafeForMatchingClipSeam:groupChild] == NO ||
           [self _nodeIsSafeForMatchingClipSeam:clipChild] == NO) {
            return CGFLOAT_MAX;
        }
        if(groupChild.windingRule == IJSVGWindingRuleEvenOdd ||
           clipChild.windingRule == IJSVGWindingRuleEvenOdd) {
            return CGFLOAT_MAX;
        }
        if([self _pathNode:(IJSVGPath *)groupChild
         matchesClipPathNode:(IJSVGPath *)clipChild] == NO) {
            return CGFLOAT_MAX;
        }
    }
    CALayer<IJSVGDrawableLayer> *leftLayer = (CALayer<IJSVGDrawableLayer> *)layer.sublayers[0];
    CALayer<IJSVGDrawableLayer> *rightLayer = (CALayer<IJSVGDrawableLayer> *)layer.sublayers[1];
    CGFloat leftEdge = CGRectGetMaxX(leftLayer.frame);
    CGFloat rightEdge = CGRectGetMinX(rightLayer.frame);
    if(fabs(leftEdge - rightEdge) > 1.f) {
        return CGFLOAT_MAX;
    }
    return (leftEdge + rightEdge) * .5f;
}

- (CALayer<IJSVGDrawableLayer>*)_matchingClipSeamLayerForNode:(IJSVGNode*)node
                                                         layer:(CALayer<IJSVGDrawableLayer>*)layer
                                                      clipPath:(IJSVGClipPath*)clipPath
                                                      clipRule:(IJSVGWindingRule)clipRule
{
    CGFloat seamX = [self _matchingClipSeamXForNode:node
                                              layer:layer
                                           clipPath:clipPath
                                           clipRule:clipRule];
    if(isfinite(seamX) == NO || seamX == CGFLOAT_MAX) {
        return nil;
    }
    IJSVGShapeLayer *seamLayer = [IJSVGShapeLayer layer];
    CGMutablePathRef path = CGPathCreateMutable();
    CGRect bounds = layer.bounds;
    CGPathMoveToPoint(path, NULL, seamX, CGRectGetMinY(bounds));
    CGPathAddLineToPoint(path, NULL, seamX, CGRectGetMaxY(bounds));
    seamLayer.path = path;
    seamLayer.frame = bounds;
    seamLayer.outerBoundingBox = bounds;
    seamLayer.boundingBox = bounds;
    seamLayer.fillColor = nil;
    seamLayer.strokeColor = NSColor.whiteColor.CGColor;
    seamLayer.lineWidth = 1.f;
    seamLayer.opacity = 21.f / 255.f;
    CGPathRelease(path);
    return seamLayer;
}

#pragma mark Defaults

- (void)applyDefaultsToLayer:(CALayer<IJSVGDrawableLayer>*)layer
                    fromNode:(IJSVGNode*)node
{
    // mask the layer
    if(node.mask != nil) {
        layer.maskLayer = [self maskLayerFromNode:node.mask
                                 referencingLayer:layer
                                        fromLayer:nil];
    }
    
    // add the clip mask if any
    if(node.clipPath != nil) {
        IJSVGClipPath* clipPath = node.clipPath;
        IJSVGWindingRule clipRule = node.clipRule;
        if(clipRule == IJSVGWindingRuleInherit) {
            clipRule = clipPath.computedClipRule;
        }
        // Chained clip paths need sequential intersection semantics, and
        // multi-child clip paths only need layered composition when the
        // children are not simple path nodes (for example <use>-based
        // composition like the clippy repro). Direct path children can
        // still be flattened into one CGPath.
        BOOL requiresLayeredClipComposition = clipPath.clipPath != nil;
        if(requiresLayeredClipComposition == NO && clipPath.children.count > 1) {
            for(IJSVGNode *child in clipPath.children) {
                if([child isKindOfClass:IJSVGPath.class] == NO) {
                    requiresLayeredClipComposition = YES;
                    break;
                }
            }
        }
        if(requiresLayeredClipComposition == YES) {
            layer.clipLayers = [self clipLayersFromNode:clipPath
                                       referencingLayer:layer
                                              fromLayer:nil];
        } else {
            CGPathRef path = [self newClipPathFromNode:clipPath
                                             fromLayer:layer];
            layer.clipPath = path;
            layer.clipRule = [IJSVGUtils CGFillRuleForWindingRule:clipRule];
            CGPathRelease(path);
        }
        if(node.filter == nil) {
            CALayer<IJSVGDrawableLayer> *seamLayer = [self _matchingClipSeamLayerForNode:node
                                                                                    layer:layer
                                                                                 clipPath:clipPath
                                                                                 clipRule:clipRule];
            if(seamLayer != nil) {
                [layer addSublayer:seamLayer];
            }
        }
    }
    // setup the opacity
    CGFloat opacity = node.opacity.value;
    if(opacity != 1.f) {
        layer.opacity = opacity;
    }

    // Blending mode
    if(node.blendMode != IJSVGBlendModeNormal) {
        layer.blendingMode = (CGBlendMode)node.blendMode;
    }

    // Should this even be displayed?
    if(node.shouldRender == NO) {
        layer.hidden = YES;
    }
}

#pragma mark Filters

- (CALayer<IJSVGDrawableLayer>*)applyFilter:(IJSVGFilter*)filter
                                    toLayer:(CALayer<IJSVGDrawableLayer>*)layer
                                   fromNode:(IJSVGNode*)node
{
    if(IJSVGThreadManager.currentManager.featureFlags.filters.enabled == NO ||
       (filter == nil || filter.valid == NO)) {
        return layer;
    }
    IJSVGFilterLayer* filterLayer = [IJSVGFilterLayer layer];
    filterLayer.filter = filter;
    filterLayer.frame = layer.frame;
    filterLayer.outerBoundingBox = layer.outerBoundingBox;
    filterLayer.sublayer = layer;
    // SVG compositing applies clipping and masking after filter effects.
    // Move the built clip/mask state to the filter wrapper so the filtered
    // image is clipped, instead of blurring already-clipped source content.
    filterLayer.maskLayer = layer.maskLayer;
    if(filterLayer.maskLayer != nil) {
        filterLayer.maskLayer.referencingLayer = filterLayer;
        layer.maskLayer = nil;
    }
    filterLayer.clipRule = layer.clipRule;
    filterLayer.clipPath = layer.clipPath;
    layer.clipPath = nil;
    filterLayer.clipLayers = layer.clipLayers;
    filterLayer.clippingTransform = layer.clippingTransform;
    filterLayer.clippingBoundingBox = layer.clippingBoundingBox;
    if(filterLayer.clipLayers.count != 0) {
        for(CALayer<IJSVGDrawableLayer> *clipLayer in filterLayer.clipLayers) {
            clipLayer.referencingLayer = filterLayer;
        }
        layer.clipLayers = nil;
        layer.clippingTransform = CGAffineTransformIdentity;
        layer.clippingBoundingBox = CGRectZero;
    }
    // SVG spec: filter is applied before opacity. Transfer the element's
    // opacity to the filter layer so it composites AFTER filtering.
    filterLayer.opacity = layer.opacity;
    layer.opacity = 1.0f;
    filterLayer.referencingLayer = layer.referencingLayer;
    layer.referencingLayer = filterLayer;
    CALayer<IJSVGDrawableLayer> *seamLayer = nil;
    if(node.clipPath != nil) {
        IJSVGWindingRule clipRule = node.clipRule;
        if(clipRule == IJSVGWindingRuleInherit) {
            clipRule = node.clipPath.computedClipRule;
        }
        seamLayer = [self _matchingClipSeamLayerForNode:node
                                                  layer:layer
                                               clipPath:node.clipPath
                                               clipRule:clipRule];
    }
    if(seamLayer != nil) {
        IJSVGGroupLayer *wrapperLayer = [IJSVGGroupLayer layer];
        CGRect frame = filterLayer.frame;
        wrapperLayer.frame = frame;
        wrapperLayer.boundingBox = frame;
        wrapperLayer.outerBoundingBox = frame;
        wrapperLayer.referencingLayer = filterLayer.referencingLayer;
        wrapperLayer.maskLayer = filterLayer.maskLayer;
        wrapperLayer.clipRule = filterLayer.clipRule;
        wrapperLayer.clipPath = filterLayer.clipPath;
        wrapperLayer.clipLayers = filterLayer.clipLayers;
        wrapperLayer.clippingTransform = filterLayer.clippingTransform;
        wrapperLayer.clippingBoundingBox = filterLayer.clippingBoundingBox;
        wrapperLayer.opacity = filterLayer.opacity;
        filterLayer.maskLayer = nil;
        filterLayer.clipPath = nil;
        filterLayer.clipLayers = nil;
        filterLayer.clippingTransform = CGAffineTransformIdentity;
        filterLayer.clippingBoundingBox = CGRectZero;
        filterLayer.opacity = 1.f;
        filterLayer.frame = CGRectMake(0.f, 0.f, frame.size.width, frame.size.height);
        seamLayer.frame = CGRectMake(0.f, 0.f, frame.size.width, frame.size.height);
        seamLayer.outerBoundingBox = filterLayer.frame;
        seamLayer.boundingBox = filterLayer.frame;
        seamLayer.referencingLayer = wrapperLayer;
        filterLayer.referencingLayer = wrapperLayer;
        [wrapperLayer addSublayer:filterLayer];
        [wrapperLayer addSublayer:seamLayer];
        return wrapperLayer;
    }
    return filterLayer;
}

#pragma mark Transforms

- (CALayer<IJSVGDrawableLayer>*)applyTransforms:(NSArray<IJSVGTransform*>*)transforms
                                        toLayer:(CALayer<IJSVGDrawableLayer>*)layer
                                       fromNode:(IJSVGNode*)node

{
    // any x and y?
    CGRect frame = layer.bounds;
    CGFloat x = 0.f;
    CGFloat y = 0.f;
    
    if(layer.treatImplicitOriginAsTransform == YES) {
        x = [node.x computeValue:frame.size.width];
        y = [node.y computeValue:frame.size.height];
    }

    // no need to do anything if no transform, or x or y == 0
    if(transforms.count == 0 && x == 0.f && y == 0.f) {
        return layer;
    }

    // simply cascade all the transforms onto the identity
    CGAffineTransform identity = CGAffineTransformIdentity;
    if(x != 0.f || y != 0.f) {
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

    // For raster image content behind a pure scale/translate <use> transform,
    // absorb the transform into the image viewport instead of scaling the
    // already-rasterized layer. That preserves the image's own
    // preserveAspectRatio behavior instead of squashing the bitmap.
    CALayer<IJSVGDrawableLayer>* imageContainer = layer;
    NSMutableArray<CALayer<IJSVGDrawableLayer>*>* imageContainerChain = [[NSMutableArray alloc] init];
    IJSVGImageLayer* imageLayer = nil;
    while([imageContainer isKindOfClass:IJSVGGroupLayer.class] == YES &&
          imageContainer.sublayers.count == 1) {
        [imageContainerChain addObject:imageContainer];
        CALayer<IJSVGDrawableLayer>* childLayer = (CALayer<IJSVGDrawableLayer>*)imageContainer.sublayers.firstObject;
        if([childLayer isKindOfClass:IJSVGImageLayer.class] == YES) {
            imageLayer = (IJSVGImageLayer*)childLayer;
            break;
        }
        imageContainer = childLayer;
    }
    if(identity.b == 0.f &&
       identity.c == 0.f &&
       identity.a > 0.f &&
       identity.d > 0.f &&
       imageLayer != nil) {
        CGAffineTransform imageTransform = CGAffineTransformIdentity;
        if(x != 0.f || y != 0.f) {
            imageTransform = CGAffineTransformTranslate(imageTransform, x, y);
        }
        for(IJSVGTransform* transform in transforms.reverseObjectEnumerator) {
            CGAffineTransform transformAffine = transform.CGAffineTransform;
            if(transform.appliedContentUnits == IJSVGUnitObjectBoundingBox) {
                CGRect appliedBounds = transform.appliedBounds;
                if(transform.command == IJSVGTransformCommandTranslate ||
                   transform.command == IJSVGTransformCommandTranslateX ||
                   transform.command == IJSVGTransformCommandTranslateY ||
                   transform.command == IJSVGTransformCommandMatrix) {
                    if(isfinite(CGRectGetWidth(appliedBounds)) &&
                       CGRectGetWidth(appliedBounds) != 0.f) {
                        transformAffine.tx /= CGRectGetWidth(appliedBounds);
                    }
                    if(isfinite(CGRectGetHeight(appliedBounds)) &&
                       CGRectGetHeight(appliedBounds) != 0.f) {
                        transformAffine.ty /= CGRectGetHeight(appliedBounds);
                    }
                }
            }
            imageTransform = CGAffineTransformConcat(imageTransform, transformAffine);
        }
        CGRect imageFrame = CGRectApplyAffineTransform(imageLayer.frame, imageTransform);
        imageLayer.frame = imageFrame;
        imageLayer.boundingBox = imageFrame;
        imageLayer.outerBoundingBox = imageFrame;
        // Only force the image to fill its new frame when the absorbed
        // transform has non-uniform scale — that's the case where the
        // author's <use> transform was meant to stretch the raster (so a
        // meet-fit would letterbox the wrong way). For pure translate or
        // uniform scale the frame's aspect ratio is unchanged and the
        // image's own preserveAspectRatio still produces the right result,
        // matching WebKit's <use>-of-<image> semantics.
        if(fabs(imageTransform.a) != fabs(imageTransform.d)) {
            imageLayer.image.viewBoxAlignment = IJSVGViewBoxAlignmentNone;
            imageLayer.image.viewBoxMeetOrSlice = IJSVGViewBoxMeetOrSliceSlice;
        }
        for(CALayer<IJSVGDrawableLayer>* containerLayer in imageContainerChain.reverseObjectEnumerator) {
            CGRect groupFrame = [IJSVGLayer calculateFrameForSublayers:containerLayer.sublayers];
            containerLayer.frame = groupFrame;
            containerLayer.boundingBox = groupFrame;
            containerLayer.outerBoundingBox = groupFrame;
        }
        return layer;
    }

    parentLayer.affineTransform = identity;
    [parentLayer addSublayer:layer];
    parentLayer.outerBoundingBox = [IJSVGLayer calculateFrameForSublayers:parentLayer.sublayers];
    return parentLayer;
}

#pragma mark To Refactor

- (IJSVGLayer*)drawableLayerForImageNode:(IJSVGImage*)image
{
    IJSVGImageLayer* layer = [[IJSVGImageLayer alloc] initWithImage:image];
    // Use the image's declared width/height as-is. Rounding up via ceilf
    // here corrupts fractional OBB sizes (e.g. width="1.05" inflates to
    // 2.0), which then double-stretches raster content when a <use> with
    // a non-uniform scale is absorbed into the frame.
    CGRect frame = layer.frame;
    frame.size.width = image.width.value;
    frame.size.height = image.height.value;
    layer.frame = frame;
    layer.boundingBox = frame;
    layer.outerBoundingBox = frame;
    [layer setNeedsLayout];
    return (IJSVGLayer*)layer;
}

@end
