//
//  IJSVGGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGGradient.h"

@implementation IJSVGGradient

@synthesize gradient, CGGradient;
@synthesize angle, startPoint, endPoint;

- (void)dealloc
{
    [gradient release], gradient = nil;
    if( CGGradient != nil )
        CGGradientRelease(CGGradient);
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGGradient * clone = [super copyWithZone:zone];
    clone.gradient = [[self.gradient copy] autorelease];
    clone.startPoint = self.startPoint;
    clone.endPoint = self.endPoint;
    return clone;
}

+ (CGFloat *)computeColorStopsFromString:(NSXMLElement *)element
                                  colors:(NSArray **)someColors
{
    // find each stop element
    NSArray * stops = [element nodesForXPath:@"stop"
                                       error:nil];
    
    NSMutableArray * colors = [[[NSMutableArray alloc] init] autorelease];
    CGFloat * stopsParams = (CGFloat *)malloc(stops.count*sizeof(CGFloat));
    NSInteger i = 0;
    for( NSXMLElement * stop in stops )
    {
        // find the offset
        CGFloat offset = [[[stop attributeForName:@"offset"] stringValue] floatValue];
        if( offset > 1 )
            offset /= 100.f;
        
        stopsParams[i++] = offset;
        
        // find the stop opacity
        CGFloat stopOpacity = 1.f;
        NSXMLNode * stopOpacityAttribute = [stop attributeForName:@"stop-opacity"];
        if( stopOpacityAttribute != nil )
            stopOpacity = [[stopOpacityAttribute stringValue] floatValue];
        
        // find the stop color
        NSColor * stopColor = [IJSVGColor colorFromHEXString:[[stop attributeForName:@"stop-color"] stringValue]
                                                       alpha:stopOpacity];
        
        // no hex, grab it from predefined
        if( stopColor == nil )
        {
            stopColor = [IJSVGColor colorFromPredefinedColorName:[[stop attributeForName:@"stop-color"] stringValue]];
            if( stopColor != nil && stopOpacity != 1.f )
                stopColor = [IJSVGColor changeAlphaOnColor:stopColor
                                                        to:stopOpacity];
        }
        
        // add it into the array
        if( stopColor != nil )
            [(NSMutableArray *)colors addObject:stopColor];
        
        NSXMLNode * styleAttribute = [stop attributeForName:@"style"];
        if( styleAttribute != nil )
        {
            IJSVGStyle * style = [IJSVGStyle parseStyleString:[styleAttribute stringValue]];
            NSColor * color = [style property:@"stop-color"];
            
            // we have a color!
            if( color != nil )
            {
                // is there a stop opacity?
                NSNumber * number = nil;
                if( (number = [style property:@"stop-opacity"] ) != nil )
                    color = [IJSVGColor changeAlphaOnColor:color
                                                        to:[number floatValue]];
                else
                    color = [IJSVGColor changeAlphaOnColor:color
                                                        to:stopOpacity];
                [(NSMutableArray *)colors addObject:color];
            }
        }
    }
    *someColors = colors;
    return stopsParams;
}

- (CGGradientRef)CGGradient
{
    // store it in the cache
    if(CGGradient != nil)
        return CGGradient;
    
    // actually create the gradient
    NSInteger num = self.gradient.numberOfColorStops;
    CGFloat * locations = malloc(sizeof(CGFloat)*num);
    CFMutableArrayRef colors = CFArrayCreateMutable(kCFAllocatorDefault, (CFIndex)num, &kCFTypeArrayCallBacks);
    for( NSInteger i = 0; i < num; i++ )
    {
        NSColor * color;
        [self.gradient getColor:&color
                       location:&locations[i]
                        atIndex:i];
        CFArrayAppendValue(colors, color.CGColor);
    }
    CGGradientRef result = CGGradientCreateWithColors(self.gradient.colorSpace.CGColorSpace, colors, locations);
    CFRelease(colors);
    free(locations);
    return CGGradient = result;
}

- (void)drawInContextRef:(CGContextRef)ctx
                    path:(IJSVGPath *)path
{
}

@end
