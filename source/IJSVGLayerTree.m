//
//  IJSVGLayerTree.m
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGLayerTree.h"
#import "IJSVGGroup.h"
#import "IJSVGTransform.h"
#import "IJSVGUtils.h"
#import "IJSVGPath.h"
#import "IJSVGImage.h"
#import "IJSVGGradient.h"
#import "IJSVGGradientLayer.h"
#import "IJSVGPatternLayer.h"
#import "IJSVGPattern.h"
#import "IJSVG.h"
#import "IJSVGText.h"
#import "IJSVGLayer.h"
#import "IJSVGShapeLayer.h"
#import "IJSVGImageLayer.h"
#import "IJSVGGroupLayer.h"
#import "IJSVGStrokeLayer.h"

@implementation IJSVGLayerTree

#define DEFAULT_SHAPE_FILL_COLOR [NSColor blackColor].CGColor

@synthesize viewBox;
@synthesize fillColor;
@synthesize strokeColor;

- (void)dealloc
{
    [fillColor release], fillColor = nil;
    [strokeColor release], strokeColor = nil;
    [super dealloc];
}

- (IJSVGLayer *)layerForNode:(IJSVGNode *)node
{
    IJSVGLayer * layer = nil;
    
    // is there a sub SVG?
    if([node isKindOfClass:[IJSVGPath class]]) {
        // path
        layer = [self layerForPath:(IJSVGPath *)node];
    } else if([node isKindOfClass:[IJSVGGroup class]]) {
        // group
        layer = [self layerForGroup:(IJSVGGroup *)node];
    } else if([node isKindOfClass:[IJSVGImage class]]) {
        // image
        layer = [self layerForImage:(IJSVGImage *)node];
    }
    
    // apply any basic defaults
    [self applyDefaultsToLayer:layer
                      fromNode:node];
    
    return [self proposedLayerAfterApplyingTransforms:layer
                                           transforms:node.transforms];
}

- (IJSVGLayer *)proposedLayerAfterApplyingTransforms:(IJSVGLayer *)layer
                                       transforms:(NSArray<IJSVGTransform *> *)transforms
{
    // add any transforms
    if(transforms.count != 0) {
        IJSVGLayer * topLayer = nil;
        IJSVGLayer * parentLayer = nil;
        
        for(IJSVGTransform * transform in transforms) {
            // make sure we apply the transform to the parent
            // so they stack
            IJSVGGroupLayer * childLayer = [[[IJSVGGroupLayer alloc] init] autorelease];
            childLayer.affineTransform = transform.CGAffineTransform;
            
            // add it to the parent layer
            if(parentLayer != nil) {
                [parentLayer addSublayer:childLayer];
            } else {
                // make sure we keep track of the top most layer
                topLayer = childLayer;
            }
            
            // reset parent layer to the new child
            parentLayer = childLayer;
        }
        
        // swap the layer around
        [parentLayer addSublayer:layer];
        layer = topLayer;
    }
    return layer;
}

- (void)applyDefaultsToLayer:(IJSVGLayer *)layer
                    fromNode:(IJSVGNode *)node
{
    CGFloat opacity = node.opacity.value;
    if(opacity == 0.f) {
        opacity = 1.f;
    }
    layer.opacity = opacity;
    
    // setup the blending mode
    if(node.blendMode != IJSVGBlendModeNormal) {
        layer.blendingMode = (CGBlendMode)node.blendMode;
    }
    
    // display?
    if(node.shouldRender == NO) {
        layer.hidden = YES;
    }
    
}

- (IJSVGLayer *)layerForImage:(IJSVGImage *)image
{
    IJSVGImageLayer * layer = [[[IJSVGImageLayer alloc] initWithCGImage:image.CGImage] autorelease];
    layer.frame = CGRectMake(image.x.value, image.y.value, image.width.value, image.height.value);
    layer.affineTransform = CGAffineTransformConcat(layer.affineTransform,
                                                    CGAffineTransformMakeScale( 1.f, -1.f));
    return layer;
}

- (IJSVGLayer *)layerForGroup:(IJSVGGroup *)group
{
    IJSVGGroupLayer * groupLayer = [[[IJSVGGroupLayer alloc] init] autorelease];
    for(IJSVGNode * node in group.children) {
        [groupLayer addSublayer:[self layerForNode:node]];
    }
    groupLayer.frame = (CGRect){
        .origin = (CGPoint){
            .x = group.x.value,
            .y = group.y.value
        },
        .size = (CGSize){
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
    if(bounds.origin.x >= INFINITY) {
        bounds.origin.x = 0.f;
    }
    if(bounds.origin.y >= INFINITY) {
        bounds.origin.y = 0.f;
    }
    if(bounds.size.width >= INFINITY) {
        bounds.size.width = 0.f;
    }
    if(bounds.size.height >= INFINITY) {
        bounds.size.height = 0.f;
    }
    return bounds;
}

- (IJSVGShapeLayer *)basicLayerForPath:(IJSVGPath *)path
{
    // setup path and layer
    IJSVGShapeLayer * layer = [[[IJSVGShapeLayer alloc] init] autorelease];
    CGPathRef introPath = [path newPathRefByAutoClosingPath:NO];
    
    CGRect bounds = [self correctedBounds:CGPathGetBoundingBox(introPath)];
    
    // zero back the path
    CGAffineTransform trans = CGAffineTransformMakeTranslation(-bounds.origin.x,
                                                               -bounds.origin.y);
    CGPathRef transformedPath = CGPathCreateCopyByTransformingPath(introPath, &trans);
    layer.path = transformedPath;
    
    // clean up path memory
    CGPathRelease(transformedPath);
    CGPathRelease(introPath);

    // set the bounds
    layer.frame = bounds;
    
    // basic fill color and rule
    layer.fillColor = nil;
    layer.fillRule = [self fillRule:path.windingRule];
    return layer;
}

- (IJSVGShapeLayer *)layerMaskFromLayer:(CAShapeLayer *)layer
                               fromNode:(IJSVGNode *)node
{
    IJSVGShapeLayer * mask = [[[IJSVGShapeLayer alloc] init] autorelease];
    mask.fillColor = [NSColor blackColor].CGColor;
    mask.path = layer.path;
    return mask;
}

- (IJSVGLayer *)layerForPath:(IJSVGPath *)path
{
    // is there a sub SVG?
    if(path.svg != nil) {
        // grab the sub layer tree from the SVG
        return [path.svg layerWithTree:self];
    }
    
    // garb the basic shape layer
    IJSVGShapeLayer * layer = [self basicLayerForPath:path];
    
    // any gradient?
    if(self.fillColor == nil && path.fillGradient != nil) {
        
        // create the gradient
        IJSVGGradientLayer * gradLayer = [self gradientLayerForLayer:layer
                                                            gradient:path.fillGradient
                                                            fromNode:path];
        
        // add the gradient and set it against the layer
        [layer addSublayer:gradLayer];
        
        // apply offsets
        [self applyOffsetsToLayer:gradLayer
                         fromNode:path.fillGradient];
        
        layer.gradientFillLayer = gradLayer;
        
    } else if(self.fillColor == nil && path.fillPattern != nil) {
        
        // create the pattern, this is actually not as easy as it may seem
        IJSVGPatternLayer * patternLayer = [self patternLayerForLayer:layer
                                                              pattern:path.fillPattern
                                                             fromNode:path];
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
        NSColor * fColor = path.fillColor;
        BOOL hasColor = (fColor.alphaComponent == 0.f || fColor == nil) == NO;
        BOOL hasFill = path.fillPattern != nil || path.fillGradient != nil;
        if(self.fillColor && (hasFill || hasColor || fColor == nil)) {
            fColor = self.fillColor;
        }
        
        // just set the color
        layer.fillColor = fColor.CGColor ?: DEFAULT_SHAPE_FILL_COLOR;
    }
    
    // stroke it
    if(path.strokeColor != nil ||
       path.strokePattern != nil ||
       path.strokeGradient != nil) {
        
        // load the stroke layer
        IJSVGStrokeLayer * strokeLayer = [self strokeLayer:layer
                                                  fromNode:path];
        
        // reset the node
        BOOL moveStrokeLayer = NO;
        if(self.strokeColor == nil && path.strokeGradient != nil) {
            
            // force reset of the mask colour as we need to use the stroke layer
            // as the mask for the stroke gradient
            strokeLayer.strokeColor = [NSColor blackColor].CGColor;
            
            // create the gradient
            IJSVGGradientLayer * gradLayer = [self gradientStrokeLayerForLayer:layer
                                                                      gradient:path.strokeGradient
                                                                      fromNode:path];
            
            moveStrokeLayer = YES;
            gradLayer.mask = strokeLayer;
            gradLayer.opacity = strokeLayer.opacity;
            
            // add it
            [layer addSublayer:gradLayer];
            layer.strokeLayer = strokeLayer;
            layer.gradientStrokeLayer = gradLayer;
            
        } else if(self.strokeColor == nil && path.strokePattern != nil) {
            
            // force reset of the mask
            strokeLayer.strokeColor = [NSColor blackColor].CGColor;
            
            // create the pattern
            IJSVGPatternLayer * patternLayer = [self patternStrokeLayerForLayer:layer
                                                                        pattern:path.strokePattern
                                                                       fromNode:path];
            
            // set the mask for it
            moveStrokeLayer = YES;
            patternLayer.mask = strokeLayer;
            patternLayer.opacity = strokeLayer.opacity;
            
            // add it
            [layer addSublayer:patternLayer];
            layer.strokeLayer = strokeLayer;
            layer.patternStrokeLayer = (IJSVGPatternLayer *)patternLayer;
            
        } else {
            // just add the coloured layer
            [layer addSublayer:strokeLayer];
            layer.strokeLayer = strokeLayer;
        }
        
        // if we required to move the stroke layer
        // then move it in based on half of what the stroke
        // width is, as strokes are draw on the center
        if(moveStrokeLayer) {
            CGFloat strokeWidth = path.strokeWidth.value;
            CGRect rect = strokeLayer.frame;
            rect.origin.x += (strokeWidth*.5f);
            rect.origin.y += (strokeWidth*.5f);
            strokeLayer.frame = rect;
        }
        
    }
    
    // apply masking
    [self maskLayer:(IJSVGLayer *)layer
           fromNode:path];
    
    return (IJSVGLayer *)layer;
}

- (CGRect)correctBounds:(CGRect)bounds
         forStrokedPath:(IJSVGNode *)path
{
    // minus half the stroke width from x and y
    // plus the stroke width to width and height
    CGFloat val = path.strokeWidth.value;
    bounds.origin.x -= (val*.5f);
    bounds.origin.y -= (val*.5f);
    bounds.size.width += val;
    bounds.size.height += val;
    return bounds;
}

- (IJSVGGradientLayer *)gradientStrokeLayerForLayer:(IJSVGShapeLayer *)layer
                                           gradient:(IJSVGGradient *)gradient
                                           fromNode:(IJSVGNode *)path
{
    // the gradient drawing layer
    IJSVGGradientLayer * gradLayer = [[[IJSVGGradientLayer alloc] init] autorelease];
    gradLayer.gradient = gradient;
    
    // is there a fill opacity?
    if(path.fillOpacity.value != 0.f) {
        gradLayer.opacity = path.fillOpacity.value;
    }
    
    // set the bounds
    CGRect bounds = CGPathGetBoundingBox(layer.path);
    bounds = [self correctBounds:bounds forStrokedPath:path];
    gradLayer.frame = bounds;
    
    // display it
    [gradLayer setNeedsDisplay];
    
    if(path.fillGradient.units == IJSVGUnitUserSpaceOnUse) {
        // move back if needed
        gradLayer.frame = (CGRect){
            .size = gradLayer.frame.size,
            .origin = CGPointMake(-fabs(gradLayer.frame.origin.x),
                                  -fabs(gradLayer.frame.origin.y))
        };
    }
    
    return gradLayer;
}


- (IJSVGGradientLayer *)gradientLayerForLayer:(IJSVGShapeLayer *)layer
                                     gradient:(IJSVGGradient *)gradient
                                     fromNode:(IJSVGNode *)path
{
    // add the mask
    IJSVGShapeLayer * mask = [self layerMaskFromLayer:layer
                                             fromNode:path];
    
    // the gradient drawing layer
    IJSVGGradientLayer * gradLayer = [[[IJSVGGradientLayer alloc] init] autorelease];
    gradLayer.frame = CGPathGetBoundingBox(((IJSVGShapeLayer *)layer).path);
    gradLayer.gradient = gradient;
    gradLayer.mask = mask;
    
    // is there a fill opacity?
    if(path.fillOpacity.value != 0.f) {
        gradLayer.opacity = path.fillOpacity.value;
    }
    
    // display it
    [gradLayer setNeedsDisplay];
    
    if(path.fillGradient.units == IJSVGUnitUserSpaceOnUse) {
        // move back if needed
        gradLayer.frame = (CGRect){
            .size = gradLayer.frame.size,
            .origin = CGPointMake(-fabs(gradLayer.frame.origin.x),
                                  -fabs(gradLayer.frame.origin.y))
        };
    }
    
    return gradLayer;
}

- (IJSVGPatternLayer *)patternStrokeLayerForLayer:(IJSVGShapeLayer *)layer
                                          pattern:(IJSVGPattern *)pattern
                                         fromNode:(IJSVGNode *)path
{
    // create the pattern, this is actually not as easy as it may seem
    IJSVGPatternLayer * patternLayer = [[[IJSVGPatternLayer alloc] init] autorelease];
    patternLayer.patternNode = pattern;
    patternLayer.pattern = [self layerForNode:pattern];
    
    // is there a fill opacity?
    if(path.fillOpacity.value != 0.f) {
        patternLayer.opacity = path.fillOpacity.value;
    }
    
    // set the bounds
    CGRect bounds = CGPathGetBoundingBox(layer.path);
    bounds = [self correctBounds:bounds forStrokedPath:path];
    patternLayer.frame = bounds;
    
    // display
    [patternLayer setNeedsDisplay];
    
    return patternLayer;
}

- (IJSVGPatternLayer *)patternLayerForLayer:(IJSVGShapeLayer *)layer
                                    pattern:(IJSVGPattern *)pattern
                                   fromNode:(IJSVGNode *)path
{
    // create the pattern, this is actually not as easy as it may seem
    IJSVGPatternLayer * patternLayer = [[[IJSVGPatternLayer alloc] init] autorelease];
    patternLayer.patternNode = pattern;
    patternLayer.pattern = [self layerForNode:pattern];
    patternLayer.frame = CGPathGetBoundingBox(layer.path);
    
    // is there a fill opacity?
    if(path.fillOpacity.value != 0.f) {
        patternLayer.opacity = path.fillOpacity.value;
    }
    
    // add the mask
    patternLayer.mask = [self layerMaskFromLayer:layer
                                        fromNode:path];
    
    // display
    [patternLayer setNeedsDisplay];
    
    return patternLayer;
}

- (void)applyOffsetsToLayer:(IJSVGLayer *)layer
                   fromNode:(IJSVGNode *)node
{
    // make sure it has a superlayer
    if(layer.superlayer == nil) {
        return;
    }
    
    // grab the x and y
    IJSVGUnitLength * x = nil;
    IJSVGUnitLength * y = nil;
    
    // sort out the rect
    CGRect rect = layer.superlayer.frame;
    CGRect frame = layer.frame;
    
    // x
    if((x = node.x) != nil) {
        frame.origin.x = [x computeValue:rect.size.width];
    }
    
    // y
    if((y = node.y) != nil) {
        frame.origin.y = [y computeValue:rect.size.height];
    }
    
    // update the frame
    if(CGRectEqualToRect(frame, layer.frame) == NO) {
        layer.frame = frame;
    }
    
}

- (IJSVGStrokeLayer *)strokeLayer:(IJSVGShapeLayer *)layer
                         fromNode:(IJSVGNode *)path
{
    // same as fill, dont use global if the alpha is 0.f, but do use it
    // if there is a pattern or gradient
    NSColor * sColor = path.strokeColor;
    if(self.strokeColor != nil &&
       ((sColor != nil && sColor.alphaComponent != 0.f) ||
            path.strokePattern != nil || path.strokeGradient != nil )) {
        sColor = self.strokeColor;
    }
    
    // stroke layer
    IJSVGStrokeLayer * strokeLayer = [[[IJSVGStrokeLayer alloc] init] autorelease];
    strokeLayer.path = layer.path;
    strokeLayer.fillColor = nil;
    strokeLayer.strokeColor = sColor.CGColor;
    
    CGFloat lineWidth = 1.f;
    if(path.strokeWidth.value > 0.f) {
        lineWidth = path.strokeWidth.value;
    }
    
    // line styles
    strokeLayer.lineWidth = lineWidth;
    strokeLayer.lineCap = [self lineCap:path.lineCapStyle];
    strokeLayer.lineJoin = [self lineJoin:path.lineJoinStyle];
    
    CGFloat strokeOpacity = 1.f;
    if(path.strokeOpacity.value != 0.f) {
        strokeOpacity = path.strokeOpacity.value;
    }
    strokeLayer.opacity = strokeOpacity;
    
    // dashing
    strokeLayer.lineDashPhase = path.strokeDashOffset.value;
    strokeLayer.lineDashPattern = [self lineDashPattern:path];
    
    return strokeLayer;
}

- (void)maskLayer:(IJSVGLayer *)layer
         fromNode:(IJSVGNode *)node
{
    // any clippath?
    if(node.clipPath != nil || node.mask != nil) {
        IJSVGGroupLayer * maskLayer = [[[IJSVGGroupLayer alloc] init] autorelease];
        
        // add clip mask
        if(node.clipPath != nil) {
            IJSVGLayer * clip = [self layerForNode:node.clipPath];
            
            // adjust the frame
            [self adjustLayer:clip
           toParentLayerFrame:layer];
            
            // add the layer
            [maskLayer addSublayer:clip];
        }
        
        // add the actual mask
        if(node.mask != nil) {
            IJSVGLayer * mask = [self layerForNode:node.mask];
            
            // only move if bounding box
            if(node.mask.units == IJSVGUnitObjectBoundingBox) {
                [self adjustLayer:mask
               toParentLayerFrame:layer];
            }
            
            // add the layer
            [maskLayer addSublayer:mask];
        }
        
        // recursive colourize for each item
        [self _recursiveColorLayersFromLayer:maskLayer
                                   withColor:[NSColor whiteColor].CGColor];
        
        // add the mask
        layer.mask = maskLayer;
    }
}

- (void)_recursiveColorLayersFromLayer:(IJSVGLayer *)layer
                             withColor:(CGColorRef)color
{
    if([layer isKindOfClass:[IJSVGShapeLayer class]]) {
        // has a proper fill method
        for(IJSVGLayer * c in layer.sublayers) {
            if([c isKindOfClass:[IJSVGGradientLayer class]] ||
               [c isKindOfClass:[IJSVGPatternLayer class]]) {
                return;
            }
        }
        
        // set the fill
        IJSVGShapeLayer * l = (IJSVGShapeLayer *)layer;
        l.fillColor = color;
    } else if([layer isKindOfClass:[IJSVGGroupLayer class]]) {
        // go through its children, assume its a group
        for(IJSVGLayer * child in layer.sublayers) {
            [self _recursiveColorLayersFromLayer:child
                                       withColor:color];
        }
    }
}

- (void)adjustLayer:(IJSVGLayer *)childLayer
 toParentLayerFrame:(IJSVGLayer *)parent
{
    childLayer.frame = (CGRect){
        .size = childLayer.frame.size,
        .origin = CGPointMake((childLayer.frame.origin.x - parent.frame.origin.x),
                              (childLayer.frame.origin.y - parent.frame.origin.y))
    };
}

- (NSArray<NSNumber *> *)lineDashPattern:(IJSVGNode *)node
{
    NSMutableArray * arr = [[[NSMutableArray alloc] init] autorelease];
    for(NSInteger i = 0; i < node.strokeDashArrayCount; i++) {
        [arr addObject:@((CGFloat)node.strokeDashArray[i])];
    }
    return [[arr copy] autorelease];
}

- (NSString *)lineJoin:(IJSVGLineJoinStyle)joinStyle
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

- (NSString *)lineCap:(IJSVGLineCapStyle)capStyle
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

- (NSString *)fillRule:(IJSVGWindingRule)rule
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
