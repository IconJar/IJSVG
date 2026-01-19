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

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags64* storage = [[IJSVGBitFlags64 alloc] init];
    [storage addBits:[super allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeFX];
    [storage setBit:IJSVGNodeAttributeFY];
    [storage setBit:IJSVGNodeAttributeFR];
    [storage setBit:IJSVGNodeAttributeCX];
    [storage setBit:IJSVGNodeAttributeCY];
    [storage setBit:IJSVGNodeAttributeR];
    return storage;
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

+ (void)parseGradient:(NSXMLElement*)element
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
        if(str != nil) {
            unit = [IJSVGUnitLength unitWithString:str
                                      fromUnitType:gradient.units];
        }
        // spec says to say 50% for missing property default
        unit = unit ?: [IJSVGUnitLength unitWithPercentageFloat:.5f];
        [gradient setValue:unit
                    forKey:kv[key]];
    }
    
    // fr
    NSString* fr = [element attributeForName:IJSVGAttributeFR].stringValue;
    if(fr != nil) {
        gradient.fr = [IJSVGUnitLength unitWithString:fr
                                         fromUnitType:gradient.units];
    }
  
    gradient.fr = gradient.fr ?: [IJSVGUnitLength unitWithPercentageFloat:0.f];

    // fx and fy are the same unless specified otherwise
    gradient.fx = gradient.cx;
    gradient.fy = gradient.cy;

    // needs fixing
    NSString* fx = [element attributeForName:IJSVGAttributeFX].stringValue;
    if(fx != nil) {
        gradient.fx = [IJSVGUnitLength unitWithString:fx
                                         fromUnitType:gradient.units] ?: gradient.fx;
    }

    NSString* fy = [element attributeForName:IJSVGAttributeFY].stringValue;
    if(fy != nil) {
        gradient.fy = [IJSVGUnitLength unitWithString:fy
                                         fromUnitType:gradient.units] ?: gradient.fy;
    }

    NSArray* colors = nil;
    CGFloat* colorStops = [self.class computeColorStops:gradient
                                                 colors:&colors];
    gradient.locations = colorStops;
    gradient.colors = colors;
    gradient.numberOfStops = colors.count;
}

- (void)drawInContextRef:(CGContextRef)ctx
                  bounds:(NSRect)objectRect
               transform:(CGAffineTransform)absoluteTransform
{
    CGContextSaveGState(ctx);
    BOOL inUserSpace = self.units == IJSVGUnitUserSpaceOnUse;
    CGFloat radius = 0.f;
    CGPoint startPoint = CGPointZero;
    CGPoint gradientStartPoint = CGPointZero;
    CGPoint gradientEndPoint = CGPointZero;
    CGRect boundingBox = objectRect;
    
    // compute size based on percentages
    CGFloat width = 0.f;
    CGFloat height = 0.f;
    if(inUserSpace == YES) {
        width = CGRectGetWidth(boundingBox);
        height = CGRectGetHeight(boundingBox);
    } else {
        width = 1.f;
        height = 1.f;
    }
    
    CGFloat cx = [_cx computeValue:width];
    CGFloat cy = [_cy computeValue:height];
    startPoint = CGPointMake(cx, cy);
    CGFloat val = MIN(width, height);
    radius = [_r computeValue:val];
    CGFloat focalRadius = [_fr computeValue:val];

    CGFloat fx = [_fx computeValue:width];
    CGFloat fy = [_fy computeValue:height];

    gradientStartPoint = startPoint;
    gradientEndPoint = CGPointMake(fx, fy);

    // transform if width or height is not equal - this can only
    // be done if we are using objectBoundingBox
    if(inUserSpace == YES) {
        CGContextConcatCTM(ctx, absoluteTransform);
    } else {
        CGContextConcatCTM(ctx, CGAffineTransformMakeScale(CGRectGetWidth(boundingBox),
                                                           CGRectGetHeight(boundingBox)));
    }
    
    // concat the gradient transform into the context
    IJSVGConcatTransformsCTM(ctx, self.transforms);

    // draw the gradient
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    CGContextDrawRadialGradient(ctx, self.CGGradient,
        gradientEndPoint, focalRadius,
        gradientStartPoint,
        radius, options);
    CGContextRestoreGState(ctx);
}

@end
