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
@synthesize x1, x2, y1, y2;

- (void)dealloc
{
    [x1 release], x1 = nil;
    [x2 release], x2 = nil;
    [y1 release], y1 = nil;
    [y2 release], y2 = nil;
    [gradient release], gradient = nil;
    if( CGGradient != nil ) {
        CGGradientRelease(CGGradient);
    }
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGGradient * clone = [super copyWithZone:zone];
    clone.gradient = [[self.gradient copy] autorelease];
    return clone;
}

+ (CGFloat *)computeColorStopsFromString:(NSXMLElement *)element
                                  colors:(NSArray **)someColors
{
    // find each stop element
    NSArray * stops = [element children];
    NSMutableArray * colors = [[[NSMutableArray alloc] initWithCapacity:stops.count] autorelease];
    CGFloat * stopsParams = (CGFloat *)malloc(stops.count*sizeof(CGFloat));
    NSInteger i = 0;
    for( NSXMLElement * stop in stops ) {
        // find the offset
        CGFloat offset = [stop attributeForName:@"offset"].stringValue.floatValue;
        if( offset > 1.f ) {
            offset /= 100.f;
        }
        
        stopsParams[i++] = offset;
        
        // find the stop opacity
        CGFloat stopOpacity = 1.f;
        NSXMLNode * stopOpacityAttribute = [stop attributeForName:@"stop-opacity"];
        if( stopOpacityAttribute != nil ) {
            stopOpacity = stopOpacityAttribute.stringValue.floatValue;
        }
        
        // find the stop color
        NSString * scs = [stop attributeForName:@"stop-color"].stringValue;
        NSColor * stopColor = [IJSVGColor colorFromString:scs];
        if(stopColor != nil && stopOpacity != 1.f) {
            stopColor = [IJSVGColor changeAlphaOnColor:stopColor
                                                    to:stopOpacity];
        }
        
        // compute any style that there was...
        NSXMLNode * styleAttribute = [stop attributeForName:@"style"];
        if( styleAttribute != nil ) {
            
            IJSVGStyle * style = [IJSVGStyle parseStyleString:styleAttribute.stringValue];
            NSColor * color = [IJSVGColor colorFromString:[style property:@"stop-color"]];
            
            // we have a color!
            if( color != nil ) {
                // is there a stop opacity?
                NSString * numberString = nil;
                if( (numberString = [style property:@"stop-opacity"] ) != nil ) {
                    color = [IJSVGColor changeAlphaOnColor:color
                                                        to:numberString.floatValue];
                } else {
                    color = [IJSVGColor changeAlphaOnColor:color
                                                        to:stopOpacity];
                }
                stopColor = color;
            }
        }
        
        // default is black
        if(stopColor == nil) {
            stopColor = [IJSVGColor colorFromString:@"black"];
            if(stopOpacity != 1.f) {
                stopColor = [IJSVGColor changeAlphaOnColor:stopColor
                                                        to:stopOpacity];
            }
        }
        
        // add the stop color
        [(NSMutableArray *)colors addObject:stopColor];
    }
    *someColors = colors;
    return stopsParams;
}

- (CGGradientRef)CGGradient
{
    // store it in the cache
    if(CGGradient != nil) {
        return CGGradient;
    }
    
    // actually create the gradient
    NSInteger num = self.gradient.numberOfColorStops;
    CGFloat * locations = malloc(sizeof(CGFloat)*num);
    CFMutableArrayRef colors = CFArrayCreateMutable(kCFAllocatorDefault, (CFIndex)num, &kCFTypeArrayCallBacks);
    for( NSInteger i = 0; i < num; i++ ) {
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
              objectRect:(NSRect)objectRect
       absoluteTransform:(CGAffineTransform)absoluteTransform
                viewPort:(CGRect)viewBox
{
}

@end
