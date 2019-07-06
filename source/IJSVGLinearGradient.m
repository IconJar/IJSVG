//
//  IJSVGGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGLinearGradient.h"
#import "IJSVGUtils.h"

@implementation IJSVGLinearGradient

+ (NSGradient *)parseGradient:(NSXMLElement *)element
                     gradient:(IJSVGLinearGradient *)aGradient
{
    // just ask unit for the value
    NSString * x1 = ([element attributeForName:@"x1"].stringValue ?: @"0");
    NSString * x2 = ([element attributeForName:@"x2"].stringValue ?: @"100%");
    NSString * y1 = ([element attributeForName:@"y1"].stringValue ?: @"0");
    NSString * y2 = ([element attributeForName:@"y2"].stringValue ?: @"0");
    aGradient.x1 = [IJSVGGradientUnitLength unitWithString:x1 fromUnitType:aGradient.units];
    aGradient.x2 = [IJSVGGradientUnitLength unitWithString:x2 fromUnitType:aGradient.units];
    aGradient.y1 = [IJSVGGradientUnitLength unitWithString:y1 fromUnitType:aGradient.units];
    aGradient.y2 = [IJSVGGradientUnitLength unitWithString:y2 fromUnitType:aGradient.units];

    // compute the color stops and colours
    NSArray * colors = nil;
    CGFloat * stopsParams = [self.class computeColorStopsFromString:element
                                                               colors:&colors];
    
    // create the gradient with the colours
    NSGradient * grad = [[NSGradient alloc] initWithColors:colors
                                               atLocations:stopsParams
                                                colorSpace:IJSVGColor.defaultColorSpace];
    
    free(stopsParams);
    return [grad autorelease];
}

- (void)drawInContextRef:(CGContextRef)ctx
              objectRect:(NSRect)objectRect
       absoluteTransform:(CGAffineTransform)absoluteTransform
                viewPort:(CGRect)viewBox
{
    BOOL inUserSpace = self.units == IJSVGUnitUserSpaceOnUse;
    
    CGPoint gradientStartPoint = CGPointZero;
    CGPoint gradientEndPoint = CGPointZero;
    CGAffineTransform selfTransform = IJSVGConcatTransforms(self.transforms);
    
    CGRect boundingBox = inUserSpace ? viewBox : objectRect;
    
    // make sure we apply the absolute position to
    // transform us back into the correct space
    if(inUserSpace == YES) {
        CGContextConcatCTM(ctx, absoluteTransform);
    }
    
    CGFloat width = CGRectGetWidth(boundingBox);
    CGFloat height = CGRectGetHeight(boundingBox);
    gradientStartPoint = CGPointMake([self.x1 computeValue:width],
                                     [self.y1 computeValue:height]);
    
    gradientEndPoint = CGPointMake([self.x2 computeValue:width],
                                   [self.y2 computeValue:height]);

    // transform the context
    CGContextConcatCTM(ctx, selfTransform);
    
    // draw the gradient
    CGGradientDrawingOptions options =
        kCGGradientDrawsBeforeStartLocation|
        kCGGradientDrawsAfterEndLocation;
    
    CGContextDrawLinearGradient(ctx, self.CGGradient, gradientStartPoint,
                                gradientEndPoint, options);
    
#ifdef IJSVG_DEBUG
    [self _debugStart:gradientStartPoint
                  end:gradientEndPoint
              context:ctx];
#endif
}

@end
