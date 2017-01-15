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
    CGRect pathBoundingBox = CGPathGetBoundingBox(layer.path);
    
    // any gradient?
    if(self.fillColor == nil && path.fillGradient != nil) {
        
        // add the mask
        IJSVGShapeLayer * mask = [self layerMaskFromLayer:layer
                                                 fromNode:path];
        
        // the gradient drawing layer
        IJSVGGradientLayer * gradLayer = [[[IJSVGGradientLayer alloc] init] autorelease];
        gradLayer.frame = pathBoundingBox;
        gradLayer.gradient = path.fillGradient;
        gradLayer.mask = mask;
        
        // is there a fill opacity?
        if(path.fillOpacity.value != 0.f) {
            gradLayer.opacity = path.fillOpacity.value;
        }
        
        // display it
        [gradLayer setNeedsDisplay];

        // add the gradient
        [layer addSublayer:gradLayer];
        
        // assign it
        layer.gradientFillLayer = gradLayer;
        
        if(path.fillGradient.units == IJSVGUnitUserSpaceOnUse) {
            // move back if needed
            gradLayer.frame = (CGRect){
                .size = gradLayer.frame.size,
                .origin = CGPointMake(-(gradLayer.frame.origin.x),
                                      -(gradLayer.frame.origin.y))
            };
        }
        
    } else if(self.fillColor == nil && path.fillPattern != nil) {
        
        // create the pattern, this is actually not as easy as it may seem
        IJSVGPatternLayer * patternLayer = [[[IJSVGPatternLayer alloc] init] autorelease];
        patternLayer.patternNode = path.fillPattern;
        patternLayer.pattern = [self layerForNode:path.fillPattern];
        patternLayer.frame = pathBoundingBox;
        
        // add the mask
        patternLayer.mask = [self layerMaskFromLayer:layer
                                            fromNode:path];
        
        // display it
        [patternLayer setNeedsDisplay];
        
        // add it
        [layer addSublayer:patternLayer];
        
        // assign it
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
    if(path.strokeColor != nil) {
        
        // same as fill, dont use global if the alpha is 0.f
        NSColor * sColor = path.strokeColor;
        if(self.strokeColor != nil && (sColor != nil && sColor.alphaComponent != 0.f)) {
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
        strokeLayer.miterLimit = lineWidth;
        
        CGFloat strokeOpacity = 1.f;
        if(path.strokeOpacity.value != 0.f) {
            strokeOpacity = path.strokeOpacity.value;
        }
        strokeLayer.opacity = strokeOpacity;
        
        // dashing
        strokeLayer.lineDashPhase = path.strokeDashOffset.value;
        strokeLayer.lineDashPattern = [self lineDashPattern:path];
        
        // add the stroke layer
        [layer addSublayer:strokeLayer];
        
        // add it
        layer.strokeLayer = strokeLayer;
    }
    
    // apply masking
    [self maskLayer:(IJSVGLayer *)layer
           fromNode:path];
    return (IJSVGLayer *)layer;
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
