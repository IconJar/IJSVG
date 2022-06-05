//
//  IJSVGGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGLinearGradient

+ (void)parseGradient:(NSXMLElement*)element
             gradient:(IJSVGLinearGradient*)aGradient
{
    // just ask unit for the value
    NSString* x1 = ([element attributeForName:IJSVGAttributeX1].stringValue ?: @"0");
    NSString* x2 = ([element attributeForName:IJSVGAttributeX2].stringValue ?: @"100%");
    NSString* y1 = ([element attributeForName:IJSVGAttributeY1].stringValue ?: @"0");
    NSString* y2 = ([element attributeForName:IJSVGAttributeY2].stringValue ?: @"0");
    aGradient.x1 = [IJSVGGradientUnitLength unitWithString:x1 fromUnitType:aGradient.units];
    aGradient.x2 = [IJSVGGradientUnitLength unitWithString:x2 fromUnitType:aGradient.units];
    aGradient.y1 = [IJSVGGradientUnitLength unitWithString:y1 fromUnitType:aGradient.units];
    aGradient.y2 = [IJSVGGradientUnitLength unitWithString:y2 fromUnitType:aGradient.units];
    
    // compute the color stops and colours
    NSArray* colors = nil;
    CGFloat* stopsParams = [self.class computeColorStops:aGradient
                                                  colors:&colors];
    aGradient.colors = colors;
    aGradient.locations = stopsParams;
    aGradient.numberOfStops = colors.count;
}

- (void)drawInContextRef:(CGContextRef)ctx
                  bounds:(NSRect)objectRect
               transform:(CGAffineTransform)absoluteTransform
{
    BOOL inUserSpace = self.units == IJSVGUnitUserSpaceOnUse;

    CGPoint gradientStartPoint = CGPointZero;
    CGPoint gradientEndPoint = CGPointZero;
    CGAffineTransform selfTransform = IJSVGConcatTransforms(self.transforms);
    CGRect boundingBox = objectRect;
    
    // make sure we apply the absolute position to
    // transform us back into the correct space
    CGFloat width = CGRectGetWidth(boundingBox);
    CGFloat height = CGRectGetHeight(boundingBox);
    
    if (inUserSpace == YES) {
        CGContextConcatCTM(ctx, absoluteTransform);
    } else {
        width = 1.f;
        height = 1.f;
        CGContextConcatCTM(ctx, CGAffineTransformMakeScale(boundingBox.size.width,
                                                           boundingBox.size.height));
    }
    
    gradientStartPoint = CGPointMake([self.x1 computeValue:width],
                                     [self.y1 computeValue:height]);
    gradientEndPoint = CGPointMake([self.x2 computeValue:width],
                                     [self.y2 computeValue:height]);
    
    // apply the gradient transform if there is one
    CGContextConcatCTM(ctx, selfTransform);
    
    // draw the gradient
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;

    CGContextDrawLinearGradient(ctx, self.CGGradient, gradientStartPoint,
        gradientEndPoint, options);
}

@end
