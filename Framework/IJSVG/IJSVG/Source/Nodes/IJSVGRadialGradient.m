//
//  IJSVGRadialGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRadialGradient.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGRadialGradient

- (void)dealloc
{
    (void)([_cx release]), _cx = nil;
    (void)([_cy release]), _cy = nil;
    (void)([_fx release]), _fx = nil;
    (void)([_fy release]), _fy = nil;
    (void)([_fr release]), _fr = nil;
    (void)([_r release]), _r = nil;
    [super dealloc];
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGRadialGradient* grad = [super copyWithZone:zone];
    grad.fx = _fx;
    grad.fy = _fy;
    grad.fr = _fr;
    grad.cx = _cx;
    grad.cy = _cy;
    grad.r = _r;
    return grad;
}

+ (NSGradient*)parseGradient:(NSXMLElement*)element
                    gradient:(IJSVGRadialGradient*)gradient
{
    // cx defaults to 50% if not specified
    NSDictionary* kv = @{
        IJSVGAttributeCX : @"cx",
        IJSVGAttributeCY : @"cy",
        IJSVGAttributeR : @"r" };

    for (NSString* key in kv.allKeys) {
        NSString* str = [element attributeForName:key].stringValue;
        IJSVGUnitLength* unit = nil;
        if (str != nil) {
            unit = [IJSVGUnitLength unitWithString:str
                                      fromUnitType:gradient.units];
        } else {
            // spec says to say 50% for missing property default
            unit = [IJSVGUnitLength unitWithPercentageFloat:.5f];
        }
        [gradient setValue:unit
                    forKey:kv[key]];
    }
    
    // fr
    NSString* fr = [element attributeForName:IJSVGAttributeFR].stringValue;
    if(fr != nil) {
        gradient.fr = [IJSVGUnitLength unitWithString:fr
                                         fromUnitType:gradient.units];
    } else {
        gradient.fr = [IJSVGUnitLength unitWithPercentageFloat:0.f];
    }

    // fx and fy are the same unless specified otherwise
    gradient.fx = gradient.cx;
    gradient.fy = gradient.cy;

    // needs fixing
    NSString* fx = [element attributeForName:IJSVGAttributeFX].stringValue;
    if (fx != nil) {
        gradient.fx = [IJSVGUnitLength unitWithString:fx
                                         fromUnitType:gradient.units];
    }

    NSString* fy = [element attributeForName:IJSVGAttributeFY].stringValue;
    if (fy != nil) {
        gradient.fy = [IJSVGUnitLength unitWithString:fy
                                         fromUnitType:gradient.units];
    }

    if (gradient.gradient != nil) {
        return nil;
    }

    NSArray* colors = nil;
    CGFloat* colorStops = [self.class computeColorStops:gradient
                                                 colors:&colors];
    
    NSGradient* ret = [[[NSGradient alloc] initWithColors:colors
                                              atLocations:colorStops
                                               colorSpace:IJSVGColor.defaultColorSpace] autorelease];
    free(colorStops);
    return ret;
}

- (void)drawInContextRef:(CGContextRef)ctx
              objectRect:(NSRect)objectRect
       absoluteTransform:(CGAffineTransform)absoluteTransform
                viewPort:(CGRect)viewBox
{
    CGContextSaveGState(ctx);
    BOOL inUserSpace = self.units == IJSVGUnitUserSpaceOnUse;
    CGFloat radius = 0.f;
    CGPoint startPoint = CGPointZero;
    CGPoint gradientStartPoint = CGPointZero;
    CGPoint gradientEndPoint = CGPointZero;

    // transforms
    CGAffineTransform selfTransform = IJSVGConcatTransforms(self.transforms);

    CGRect boundingBox = inUserSpace ? viewBox : objectRect;
    
    // compute size based on percentages
    CGFloat width = CGRectGetWidth(boundingBox);
    CGFloat height = CGRectGetHeight(boundingBox);
    CGFloat cx = [_cx computeValue:width];
    CGFloat cy = [_cy computeValue:height];
    startPoint = CGPointMake(cx, cy);
    CGFloat val = MIN(width, height);
    radius = [_r computeValue:val];
    CGFloat focalRadius = [_fr computeValue:val];

    CGFloat fx = [_fx computeValue:width];
    CGFloat fy = [_fy computeValue:height];

    gradientEndPoint = CGPointMake(fx, fy);
    gradientStartPoint = startPoint;

    // transform if width or height is not equal - this can only
    // be done if we are using objectBoundingBox
    if(inUserSpace == YES) {
        CGFloat rad = 2.f * radius;
        CGRect rect = CGRectMake(startPoint.x, startPoint.y, rad, rad);
        rect = CGRectApplyAffineTransform(rect, selfTransform);
        rect = CGRectApplyAffineTransform(rect, absoluteTransform);
        radius = CGRectGetHeight(rect) / 2.f;
        CGContextConcatCTM(ctx, absoluteTransform);
    } else if(width != height) {
        CGAffineTransform transform = CGAffineTransformIdentity;
        CGAffineTransform invert = CGAffineTransformIdentity;
        CGPoint invPoint = CGPointZero;
        CGFloat* radiusScale;
        if(width > height) {
            transform = CGAffineTransformMakeScale(1.f, height / width);
            radiusScale = &invPoint.y;
        } else {
            transform = CGAffineTransformMakeScale(width / height, 1.f);
            radiusScale = &invPoint.x;
        }
        invert = CGAffineTransformInvert(transform);
        invPoint.x = invert.a;
        invPoint.y = invert.d;
        gradientStartPoint.x *= invPoint.x;
        gradientStartPoint.y *= invPoint.y;
        gradientEndPoint.x *= invPoint.x;
        gradientEndPoint.y *= invPoint.y;
        radius *= *radiusScale;
        focalRadius *= *radiusScale;
        selfTransform = CGAffineTransformConcat(transform, selfTransform);
    }
    
    // transform the context
    CGContextConcatCTM(ctx, selfTransform);

    // draw the gradient
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    CGContextDrawRadialGradient(ctx, self.CGGradient,
        gradientEndPoint, focalRadius,
        gradientStartPoint,
        radius, options);
    CGContextRestoreGState(ctx);

//#ifdef IJSVG_DEBUG_GRADIENTS
//    [self _debugStart:gradientStartPoint
//                  end:gradientEndPoint
//              context:ctx];
//#endif
}

@end
