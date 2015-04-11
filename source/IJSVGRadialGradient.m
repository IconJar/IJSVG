//
//  IJSVGRadialGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGRadialGradient.h"

@implementation IJSVGRadialGradient

@synthesize cx;
@synthesize cy;
@synthesize fx;
@synthesize fy;
@synthesize radius;


+ (NSGradient *)parseGradient:(NSXMLElement *)element
                     gradient:(IJSVGRadialGradient *)gradient
{
    
    // assume its a vertical / horizonal
    gradient.cx = [[[element attributeForName:@"cx"] stringValue] floatValue]/100;
    gradient.cy = [[[element attributeForName:@"cy"] stringValue] floatValue]/100;
    gradient.radius = [[[element attributeForName:@"r"] stringValue] floatValue]/100;
    gradient.fx = [[[element attributeForName:@"fx"] stringValue] floatValue]/100;
    gradient.fy = [[[element attributeForName:@"fy"] stringValue] floatValue]/100;
    
    // nothing has been specified, make it 50% for everything
    if( gradient.cx == 0.f && gradient.cy == 0.f
       && gradient.fx == 0.f && gradient.fy == 0.f
       && gradient.radius == 0.f )
    {
        gradient.cx = .5;
        gradient.cy = .5;
        gradient.radius = .5;
        gradient.fx = .5;
        gradient.fy = .5;
    }
    
    if( gradient.gradient != nil )
        return nil;
    
    NSArray * colors = nil;
    CGFloat * colorStops = [[self class] computeColorStopsFromString:element colors:&colors];
    NSGradient * ret = [[[NSGradient alloc] initWithColors:colors
                                               atLocations:colorStops
                                                colorSpace:[NSColorSpace genericRGBColorSpace]] autorelease];
    free(colorStops);
    return ret;
}

@end
