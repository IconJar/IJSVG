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
    if((self = [super init]) != nil) {
        _viewPortStack = [[NSMutableArray alloc] init];
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
    
    // lets copy the gradient incase there are any style changes
    IJSVGColorUsageTraits traits = IJSVGColorUsageTraitGradientStop;
    if(_style.colors.replacedColorCount != 0 &&
       [_style.colors matchesReplacementTraits:traits] == YES) {
        gradient = gradient.copy;
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
    CGRect layerBounds = layer.innerBoundingBox;
    CGRect maskBounds = maskLayer.outerBoundingBox;
    CGRect maskingBounds = layerBounds;
    rect.origin.x += layerBounds.origin.x;
    rect.origin.y += layerBounds.origin.y;
    
    maskingBounds.size.width = maskBounds.size.width;
    maskingBounds.size.height = maskBounds.size.height;
    
    CGAffineTransform userSpaceTransform = [IJSVGLayer userSpaceTransformForLayer:layer];
    if(maskNode.contentUnits == IJSVGUnitUserSpaceOnUse) {
        maskingBounds.origin.x += maskBounds.origin.x;
        maskingBounds.origin.y += maskBounds.origin.y;
        maskingBounds = CGRectApplyAffineTransform(maskingBounds, userSpaceTransform);
    }
    
    if(maskNode.units == IJSVGUnitUserSpaceOnUse) {
        rect = CGRectApplyAffineTransform(rect, userSpaceTransform);
    }
    
    maskLayer.maskingBoundingBox = maskingBounds;
    maskLayer.maskingClippingRect = rect;
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
    CGRect layerRect = layer.innerBoundingBox;
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
        CGPathRef path = [self newClipPathFromNode:clipPath
                                         fromLayer:layer];
        
        IJSVGWindingRule clipRule = node.clipRule;
        if(clipRule == IJSVGWindingRuleInherit) {
            clipRule = clipPath.computedClipRule;
        }
        
        layer.clipPath = path;
        layer.clipRule = [IJSVGUtils CGFillRuleForWindingRule:clipRule];
        CGPathRelease(path);
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
    parentLayer.affineTransform = identity;
    [parentLayer addSublayer:layer];
    parentLayer.outerBoundingBox = [IJSVGLayer calculateFrameForSublayers:parentLayer.sublayers];
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
    frame.size.width = ceilf(image.width.value);
    frame.size.height = ceilf(image.height.value);
    layer.frame = frame;
    [layer setNeedsLayout];
    return (IJSVGLayer*)layer;
}

@end
