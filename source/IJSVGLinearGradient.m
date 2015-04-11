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
    // assume its a vertical / horizonal
    CGFloat x1 = [[[element attributeForName:@"x1"] stringValue] floatValue];
    CGFloat x2 = [[[element attributeForName:@"x2"] stringValue] floatValue];
    CGFloat y1 = [[[element attributeForName:@"y1"] stringValue] floatValue];
    CGFloat y2 = [[[element attributeForName:@"y2"] stringValue] floatValue];
    
    // horizontal
    if( y1 == y2 && x1 != x2 )
        aGradient.angle = 0.f;
    
    // vertical
    else if( x1 == x2 && y1 != y2 )
        aGradient.angle = 270.f;
    
    // angles
    else if( x1 != x2 && y1 != y2 )
        aGradient.angle = [IJSVGUtils angleBetweenPointA:NSMakePoint( x1, y1 )
                                                  pointb:NSMakePoint( x2, y2 )];
    
    if( aGradient.gradient != nil )
        return nil;
    
    // compute the color stops and colours
    NSArray * colors = nil;
    CGFloat * stopsParams = [[self class] computeColorStopsFromString:element
                                                               colors:&colors];
    
    // create the gradient with the colours
    NSGradient * grad = [[[NSGradient alloc] initWithColors:colors
                                               atLocations:stopsParams
                                                colorSpace:[NSColorSpace genericRGBColorSpace]] autorelease];
    free(stopsParams);
    return grad;
}

@end
