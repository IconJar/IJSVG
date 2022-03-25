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
    }
    return self;
}

- (IJSVGLayer*)layerForNode:(IJSVGNode*)node
{
    IJSVGLayer* layer = nil;

    // is there a sub SVG?
    if ([node isKindOfClass:[IJSVGPath class]]) {
        // path
        layer = [self layerForPath:(IJSVGPath*)node];
    } else if ([node isKindOfClass:[IJSVGGroup class]]) {
        // group
        layer = [self layerForGroup:(IJSVGGroup*)node];
    } else if ([node isKindOfClass:[IJSVGImage class]]) {
        // image
        layer = [self layerForImage:(IJSVGImage*)node];
    }

    [self applyDefaultsToLayer:layer fromNode:node];

    // create the new layer
    layer = [self applyTransforms:node.transforms
                          toLayer:layer
                         fromNode:node];

    return layer;
}

- (IJSVGLayer*)applyTransforms:(NSArray<IJSVGTransform*>*)transforms
                       toLayer:(IJSVGLayer*)layer
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
    IJSVGGroupLayer* parentLayer = [[[IJSVGGroupLayer alloc] init] autorelease];
    for(IJSVGTransform* transform in transforms.reverseObjectEnumerator) {
        identity = CGAffineTransformConcat(identity, transform.CGAffineTransform);
    }
    parentLayer.affineTransform = identity;
    [parentLayer addSublayer:layer];
    return parentLayer;
}

- (void)applyDefaultsToLayer:(IJSVGLayer*)layer
                    fromNode:(IJSVGNode*)node
{
    CGFloat opacity = node.opacity.value;
    if(opacity != 1.f) {
        layer.opacity = opacity;
    }

    // setup the blending mode
    if (node.blendMode != IJSVGBlendModeNormal) {
        layer.blendingMode = (CGBlendMode)node.blendMode;
    }

    // display?
    if (node.shouldRender == NO) {
        layer.hidden = YES;
    }
}

- (IJSVGLayer*)layerForImage:(IJSVGImage*)image
{
    IJSVGImageLayer* layer = [[[IJSVGImageLayer alloc] initWithCGImage:image.CGImage] autorelease];
    layer.affineTransform = CGAffineTransformConcat(layer.affineTransform,
        CGAffineTransformMakeScale(1.f, -1.f));

    // make sure we set the width and height correctly,
    // as this may not be exactly the same as the size of the
    // given image
    CGRect frame = layer.frame;
    frame.size.width = image.width.value;
    frame.size.height = image.height.value;
    layer.frame = frame;
    return layer;
}

- (IJSVGLayer*)layerForGroup:(IJSVGGroup*)group
{

    // grab the sub layer tree from the SVG
    if (group.svg != nil) {
        return [self layerForGroup:group.svg.rootNode];
    }

    IJSVGGroupLayer* groupLayer = [[[IJSVGGroupLayer alloc] init] autorelease];
    for (IJSVGNode* node in group.childNodes) {
        [groupLayer addSublayer:[self layerForNode:node]];
    }
    groupLayer.frame = (CGRect) {
        .origin = CGPointZero,
        .size = (CGSize) {
            .width = group.width.value,
            .height = group.height.value
        }
    };

    // mask it - forgot groups can have masks too, doh! simple
    // enough to apply though, recursion ftw!
    [self maskLayer:groupLayer
           fromNode:group];
    return groupLayer;
}

- (CGRect)correctedBounds:(CGRect)bounds
{
    if (bounds.origin.x >= INFINITY) {
        bounds.origin.x = 0.f;
    }
    if (bounds.origin.y >= INFINITY) {
        bounds.origin.y = 0.f;
    }
    if (bounds.size.width >= INFINITY) {
        bounds.size.width = 0.f;
    }
    if (bounds.size.height >= INFINITY) {
        bounds.size.height = 0.f;
    }
    return bounds;
}

- (IJSVGShapeLayer*)basicLayerForPath:(IJSVGPath*)path
                  originalBoundingBox:(CGRect*)originalBoundingBox
{
    // setup path and layer
    IJSVGShapeLayer* layer = [[[IJSVGShapeLayer alloc] init] autorelease];
    layer.primitiveType = path.primitiveType;
    CGPathRef introPath = path.path;

    *originalBoundingBox = CGRectIntegral(CGPathGetBoundingBox(introPath));
    layer.originalPathOrigin = (*originalBoundingBox).origin;

    CGRect bounds = [self correctedBounds:*originalBoundingBox];

    // zero back the path
    CGAffineTransform trans = CGAffineTransformMakeTranslation(-bounds.origin.x,
        -bounds.origin.y);

    CGPathRef transformedPath = CGPathCreateCopyByTransformingPath(introPath, &trans);
    layer.path = transformedPath;

    // clean up path memory
    CGPathRelease(transformedPath);

    // set the bounds
    layer.frame = CGRectIntegral(bounds);

    // basic fill color and rule
    layer.fillColor = nil;
    layer.fillRule = [self fillRule:path.windingRule];
    return layer;
}

- (IJSVGShapeLayer*)layerMaskFromLayer:(CAShapeLayer*)layer
                              fromNode:(IJSVGNode*)node
{
    IJSVGShapeLayer* mask = [[[IJSVGShapeLayer alloc] init] autorelease];
    mask.fillColor = [NSColor blackColor].CGColor;
    mask.path = layer.path;
    mask.fillRule = layer.fillRule;
    return mask;
}

- (CGAffineTransform)absoluteTransform:(IJSVGNode*)node
{
    CGAffineTransform parentAbsoluteTransform = CGAffineTransformIdentity;
    IJSVGNode* intermediateNode = node.intermediateParentNode;
    IJSVGNode* parentSVGNode = node;
    while ((parentSVGNode = parentSVGNode.parentNode) != nil) {
        if (node == intermediateNode) {
            continue;
        }
        parentAbsoluteTransform = [self absoluteTransform:parentSVGNode];
    }
    return CGAffineTransformConcat(IJSVGConcatTransforms(node.transforms),
        parentAbsoluteTransform);
}

- (IJSVGLayer*)layerForPath:(IJSVGPath*)path
{
    // grab the basic shape layer
    CGRect originalShapeBounds;
    IJSVGShapeLayer* layer = [self basicLayerForPath:path
                                 originalBoundingBox:&originalShapeBounds];

    BOOL hasStroke = (path.strokeColor != nil || path.strokePattern != nil || path.strokeGradient != nil);

    // any gradient?
    if (_style.fillColor == nil && path.fillGradient != nil) {

        // create the gradient
        IJSVGGradientLayer* gradLayer = [self gradientLayerForLayer:layer
                                                           gradient:path.fillGradient
                                                           fromNode:path
                                                         objectRect:originalShapeBounds
                                                         shouldMask:YES];

        // add the gradient and set it against the layer
        [layer addSublayer:gradLayer];
        layer.gradientFillLayer = gradLayer;

    } else if (_style.fillColor == nil && path.fillPattern != nil) {

        // create the pattern, this is actually not as easy as it may seem
        IJSVGPatternLayer* patternLayer = [self patternLayerForLayer:layer
                                                             pattern:path.fillPattern
                                                            fromNode:path
                                                          objectRect:originalShapeBounds];
        // add it
        [layer addSublayer:patternLayer];

        // apply offsets
        [self applyOffsetsToLayer:patternLayer
                         fromNode:path.fillPattern];

        layer.patternFillLayer = patternLayer;

    } else {
        // only use the global if its set and the current colors
        // alpha channel is not 0.f, otherwise its a blank clear color,
        // aka, not filled in
        NSColor* fColor = path.fillColor;
        BOOL hasColor = (fColor.alphaComponent == 0.f || fColor == nil) == NO;
        BOOL hasFill = path.fillPattern != nil || path.fillGradient != nil;
        
        // is there an overriding style in the sheet?
        if (_style.fillColor && (hasFill || hasColor || fColor == nil)) {
            fColor = _style.fillColor;
        }
        
        // if there is a color, change the opacity if required
        if (fColor != nil && path.fillOpacity.value != 1.f) {
            fColor = [IJSVGColor changeAlphaOnColor:fColor
                                                 to:path.fillOpacity.value];
        }

        // anything changed by user?
        fColor = [_style.colorList proposedColorForColor:fColor];

        // just set the color
        if (fColor != nil) {
            layer.fillColor = fColor.CGColor;
        } else {
            // use default color
            NSColor* defColor = [IJSVGColor computeColorSpace:NSColor.blackColor];
            if (path.fillOpacity.value != 1.f) {
                defColor = [IJSVGColor changeAlphaOnColor:defColor
                                                       to:path.fillOpacity.value];
            }

            // work out if anything was changed by user
            NSColor* proposedColor = [_style.colorList proposedColorForColor:defColor];
            layer.fillColor = proposedColor.CGColor;
        }
    }

    // stroke it
    if (hasStroke == YES) {

        // load the stroke layer
        IJSVGStrokeLayer* strokeLayer = [self strokeLayer:layer
                                                 fromNode:path];

        // reset the node
        BOOL moveStrokeLayer = NO;
        if (_style.strokeColor == nil && path.strokeGradient != nil) {

            // force reset of the mask colour as we need to use the stroke layer
            // as the mask for the stroke gradient
            strokeLayer.strokeColor = [IJSVGColor computeColorSpace:NSColor.blackColor].CGColor;

            // create the gradient
            IJSVGGradientLayer* gradLayer = [self gradientStrokeLayerForLayer:layer
                                                                     gradient:path.strokeGradient
                                                                     fromNode:path
                                                                   objectRect:originalShapeBounds];

            moveStrokeLayer = YES;
            gradLayer.mask = strokeLayer;
            gradLayer.opacity = strokeLayer.opacity;

            // add it
            [layer addSublayer:gradLayer];
            layer.strokeLayer = strokeLayer;
            layer.gradientStrokeLayer = gradLayer;

        } else if (_style.strokeColor == nil && path.strokePattern != nil) {

            // force reset of the mask
            strokeLayer.strokeColor = [IJSVGColor computeColorSpace:NSColor.blackColor].CGColor;

            // create the pattern
            IJSVGPatternLayer* patternLayer = [self patternStrokeLayerForLayer:layer
                                                                       pattern:path.strokePattern
                                                                      fromNode:path
                                                                    objectRect:originalShapeBounds];

            // set the mask for it
            moveStrokeLayer = YES;
            patternLayer.mask = strokeLayer;
            patternLayer.opacity = strokeLayer.opacity;

            // add it
            [layer addSublayer:patternLayer];
            layer.strokeLayer = strokeLayer;
            layer.patternStrokeLayer = (IJSVGPatternLayer*)patternLayer;

        } else {
            // just add the coloured layer
            [layer addSublayer:strokeLayer];
            layer.strokeLayer = strokeLayer;
        }

        // if we required to move the stroke layer
        // then move it in based on half of what the stroke
        // width is, as strokes are draw on the center
        if (moveStrokeLayer) {
            CGFloat layerStrokeWidth = strokeLayer.lineWidth;
            CGRect rect = strokeLayer.frame;
            rect.origin.x += (layerStrokeWidth * .5f);
            rect.origin.y += (layerStrokeWidth * .5f);
            strokeLayer.frame = rect;
        }
    }

    // apply masking
    [self maskLayer:(IJSVGLayer*)layer
           fromNode:path];

    return (IJSVGLayer*)layer;
}

- (CGRect)correctBounds:(CGRect)bounds
         forStrokedPath:(IJSVGNode*)path
{
    // minus half the stroke width from x and y
    // plus the stroke width to width and height
    CGFloat val = path.strokeWidth.value;
    bounds.origin.x -= (val * .5f);
    bounds.origin.y -= (val * .5f);
    bounds.size.width += val;
    bounds.size.height += val;
    return bounds;
}

- (IJSVGGradientLayer*)gradientStrokeLayerForLayer:(IJSVGShapeLayer*)layer
                                          gradient:(IJSVGGradient*)gradient
                                          fromNode:(IJSVGNode*)path
                                        objectRect:(CGRect)objectRect
{
    // the gradient drawing layer
    IJSVGGradientLayer* gradLayer = [self gradientLayerForLayer:layer
                                                       gradient:gradient
                                                       fromNode:path
                                                     objectRect:objectRect
                                                     shouldMask:NO];

    // set the bounds
    CGRect bounds = CGPathGetBoundingBox(layer.path);
    bounds = [self correctBounds:bounds forStrokedPath:path];
    gradLayer.frame = bounds;
    return gradLayer;
}

- (IJSVGGradientLayer*)gradientLayerForLayer:(IJSVGShapeLayer*)layer
                                    gradient:(IJSVGGradient*)gradient
                                    fromNode:(IJSVGNode*)path
                                  objectRect:(CGRect)objectRect
                                  shouldMask:(BOOL)shouldMask
{
    // the gradient drawing layer
    gradient.colorList = _style.colorList;
    IJSVGGradientLayer* gradLayer = [[[IJSVGGradientLayer alloc] init] autorelease];
    gradLayer.viewBox = _viewBox;
    gradLayer.frame = layer.bounds;
    gradLayer.gradient = gradient;
    gradLayer.absoluteTransform = [self absoluteTransform:path];
    gradLayer.objectRect = CGRectApplyAffineTransform(objectRect,
        gradLayer.absoluteTransform);

    if (shouldMask == YES) {
        // add the mask
        IJSVGShapeLayer* mask = [self layerMaskFromLayer:layer
                                                fromNode:path];
        gradLayer.mask = mask;
    }

    // is there a fill opacity?
    if (path.fillOpacity.value != 0.f) {
        gradLayer.opacity = path.fillOpacity.value;
    }
    
    // display
    [gradLayer setNeedsDisplay];
    gradLayer.masksToBounds = YES;
    return gradLayer;
}

- (IJSVGPatternLayer*)patternStrokeLayerForLayer:(IJSVGShapeLayer*)layer
                                         pattern:(IJSVGPattern*)pattern
                                        fromNode:(IJSVGNode*)path
                                      objectRect:(CGRect)objectRect
{
    // create the pattern, this is actually not as easy as it may seem
    IJSVGPatternLayer* patternLayer = [[[IJSVGPatternLayer alloc] init] autorelease];
    patternLayer.patternNode = pattern;
    patternLayer.viewBox = _viewBox;
    patternLayer.absoluteTransform = [self absoluteTransform:path];
    patternLayer.objectRect = CGRectApplyAffineTransform(objectRect,
                                                         patternLayer.absoluteTransform);
    patternLayer.pattern = [self layerForNode:pattern];

    // is there a fill opacity?
    if (path.fillOpacity.value != 0.f) {
        patternLayer.opacity = path.fillOpacity.value;
    }

    // set the bounds
    CGRect bounds = CGPathGetBoundingBox(layer.path);
    bounds = [self correctBounds:bounds forStrokedPath:path];
    patternLayer.frame = bounds;
    patternLayer.masksToBounds = YES;

    // display
    [patternLayer setNeedsDisplay];
    return patternLayer;
}

- (IJSVGPatternLayer*)patternLayerForLayer:(IJSVGShapeLayer*)layer
                                   pattern:(IJSVGPattern*)pattern
                                  fromNode:(IJSVGNode*)path
                                objectRect:(CGRect)objectRect
{
    // create the pattern, this is actually not as easy as it may seem
    IJSVGPatternLayer* patternLayer = [[[IJSVGPatternLayer alloc] init] autorelease];
    patternLayer.patternNode = pattern;
    patternLayer.pattern = [self layerForNode:pattern];
    patternLayer.frame = CGPathGetBoundingBox(layer.path);
    patternLayer.absoluteTransform = [self absoluteTransform:path];
    patternLayer.viewBox = _viewBox;
    patternLayer.objectRect = CGRectApplyAffineTransform(objectRect,
                                                         patternLayer.absoluteTransform);

    // is there a fill opacity?
    if (path.fillOpacity.value != 0.f) {
        patternLayer.opacity = path.fillOpacity.value;
    }

    // add the mask
    patternLayer.mask = [self layerMaskFromLayer:layer
                                        fromNode:path];

    // display
    [patternLayer setNeedsDisplay];
    patternLayer.masksToBounds = YES;

    return patternLayer;
}

- (void)applyOffsetsToLayer:(IJSVGLayer*)layer
                   fromNode:(IJSVGNode*)node
{
    // make sure it has a superlayer
    if (layer.superlayer == nil) {
        return;
    }

    // grab the x and y
    IJSVGUnitLength* x = nil;
    IJSVGUnitLength* y = nil;

    // sort out the rect
    CGRect rect = layer.superlayer.frame;
    CGRect frame = layer.frame;

    // x
    if ((x = node.x) != nil) {
        frame.origin.x = [x computeValue:rect.size.width];
    }

    // y
    if ((y = node.y) != nil) {
        frame.origin.y = [y computeValue:rect.size.height];
    }

    // update the frame
    if (CGRectEqualToRect(frame, layer.frame) == NO) {
        layer.frame = frame;
    }
}

- (IJSVGStrokeLayer*)strokeLayer:(IJSVGShapeLayer*)layer
                        fromNode:(IJSVGPath*)path
{
    // same as fill, dont use global if the alpha is 0.f, but do use it
    // if there is a pattern or gradient
    NSColor* sColor = path.strokeColor;
    if (_style.strokeColor != nil && ((sColor != nil && sColor.alphaComponent != 0.f) || path.strokePattern != nil || path.strokeGradient != nil)) {
        sColor = _style.strokeColor;
    }

    sColor = [_style.colorList proposedColorForColor:sColor];

    // stroke layer
    IJSVGStrokeLayer* strokeLayer = [[[IJSVGStrokeLayer alloc] init] autorelease];
    strokeLayer.path = layer.path;
    strokeLayer.fillColor = nil;
    strokeLayer.strokeColor = sColor.CGColor;

    CGFloat lineWidth = 1.f;
    if (_style.lineWidth != IJSVGInheritedFloatValue) {
        lineWidth = _style.lineWidth;
    } else {
        lineWidth = path.strokeWidth.value;
    }

    // work out line styles
    IJSVGLineCapStyle lCapStyle;
    IJSVGLineJoinStyle lJoinStyle;

    // forced cap style
    if (_style.lineCapStyle != IJSVGLineCapStyleNone) {
        lCapStyle = _style.lineCapStyle;
    } else {
        lCapStyle = path.lineCapStyle;
    }

    // forced join style
    if (_style.lineJoinStyle != IJSVGLineJoinStyleNone) {
        lJoinStyle = _style.lineJoinStyle;
    } else {
        lJoinStyle = path.lineJoinStyle;
    }

    // line styles
    strokeLayer.lineWidth = lineWidth;
    strokeLayer.lineCap = [self lineCap:lCapStyle];
    strokeLayer.lineJoin = [self lineJoin:lJoinStyle];

    CGFloat strokeOpacity = 1.f;
    if (path.strokeOpacity.value != 0.f) {
        strokeOpacity = path.strokeOpacity.value;
    }
    strokeLayer.opacity = strokeOpacity;

    // dashing
    strokeLayer.lineDashPhase = path.strokeDashOffset.value;
    if(path.strokeDashArrayCount != 0.f) {
        strokeLayer.lineDashPattern = [self lineDashPattern:path];
    }

    return strokeLayer;
}

- (void)maskLayer:(IJSVGLayer*)layer
         fromNode:(IJSVGNode*)node
{
    // any clippath?
    if (node.clipPath != nil || node.mask != nil) {
        IJSVGGroupLayer* maskLayer = [[[IJSVGGroupLayer alloc] init] autorelease];

        // add clip mask
        if (node.clipPath != nil && node.clipPath.overflowVisibility == IJSVGOverflowVisibilityHidden) {
            IJSVGLayer* clip = [self layerForNode:node.clipPath];

            // adjust the frame
            if (node.clipPath.units == IJSVGUnitObjectBoundingBox) {
                [self adjustLayer:clip
               toParentLayerFrame:layer];
            }

            // add the layer
            [maskLayer addSublayer:clip];
        }

        // add the actual mask
        if (node.mask != nil && node.mask.overflowVisibility == IJSVGOverflowVisibilityHidden) {
            IJSVGLayer* mask = [self layerForNode:node.mask];

            // only move if bounding box
            if (node.mask.units == IJSVGUnitObjectBoundingBox) {
                [self adjustLayer:mask
               toParentLayerFrame:layer];
            }

            // add the layer
            [maskLayer addSublayer:mask];
        }

        // add the mask
        if(maskLayer.sublayers.count != 0) {
            // recursive colourize for each item
            NSColor* color = [IJSVGColor computeColorSpace:NSColor.whiteColor];
            [self _recursiveColorLayersFromLayer:maskLayer
                                       withColor:color.CGColor];
            layer.mask = maskLayer;
        }
    }
}

- (void)_recursiveColorLayersFromLayer:(IJSVGLayer*)layer
                             withColor:(CGColorRef)color
{
    if ([layer isKindOfClass:[IJSVGShapeLayer class]]) {
        // has a proper fill method
        for (IJSVGLayer* c in layer.sublayers) {
            if ([c isKindOfClass:[IJSVGGradientLayer class]] ||
                [c isKindOfClass:[IJSVGPatternLayer class]]) {
                return;
            }
        }

        // set the fill
        IJSVGShapeLayer* l = (IJSVGShapeLayer*)layer;
        l.fillColor = color;
    } else if ([layer isKindOfClass:[IJSVGGroupLayer class]]) {
        // go through its children, assume its a group
        for (IJSVGLayer* child in layer.sublayers) {
            [self _recursiveColorLayersFromLayer:child
                                       withColor:color];
        }
    }
}

- (void)adjustLayer:(IJSVGLayer*)childLayer
    toParentLayerFrame:(IJSVGLayer*)parent
{
    childLayer.frame = (CGRect){
        .size = childLayer.frame.size,
        .origin = CGPointMake((childLayer.frame.origin.x - parent.frame.origin.x),
            (childLayer.frame.origin.y - parent.frame.origin.y))
    };
}

- (NSArray<NSNumber*>*)lineDashPattern:(IJSVGNode*)node
{
    NSMutableArray* arr = [[[NSMutableArray alloc] initWithCapacity:node.strokeDashArrayCount] autorelease];
    for (NSInteger i = 0; i < node.strokeDashArrayCount; i++) {
        [arr addObject:@((CGFloat)node.strokeDashArray[i])];
    }
    return arr;
}

- (NSString*)lineJoin:(IJSVGLineJoinStyle)joinStyle
{
    switch (joinStyle) {
        default:
        case IJSVGLineJoinStyleMiter: {
            return kCALineJoinMiter;
        }
        case IJSVGLineJoinStyleBevel: {
            return kCALineJoinBevel;
        }
        case IJSVGLineJoinStyleRound: {
            return kCALineJoinRound;
        }
    }
}

- (NSString*)lineCap:(IJSVGLineCapStyle)capStyle
{
    switch (capStyle) {
        default:
        case IJSVGLineCapStyleButt: {
            return kCALineCapButt;
        }
        case IJSVGLineCapStyleRound: {
            return kCALineCapRound;
        }
        case IJSVGLineCapStyleSquare: {
            return kCALineCapSquare;
        }
    }
}

- (NSString*)fillRule:(IJSVGWindingRule)rule
{
    switch (rule) {
        case IJSVGWindingRuleEvenOdd: {
            return kCAFillRuleEvenOdd;
        }
        default: {
            return kCAFillRuleNonZero;
        }
    }
}

@end
