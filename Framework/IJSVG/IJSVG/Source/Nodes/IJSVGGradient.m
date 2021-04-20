//
//  IJSVGGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGGradient.h"
#import "IJSVGParser.h"

@implementation IJSVGGradient

@synthesize colorList = _privateColorList;

- (void)dealloc
{
    (void)([_x1 release]), _x1 = nil;
    (void)([_x2 release]), _x2 = nil;
    (void)([_y1 release]), _y1 = nil;
    (void)([_y2 release]), _y2 = nil;
    (void)([_gradient release]), _gradient = nil;
    (void)([_privateColorList release]), _privateColorList = nil;
    if (_CGGradient != nil) {
        CGGradientRelease(_CGGradient);
    }
    [super dealloc];
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGGradient* clone = [super copyWithZone:zone];
    clone.gradient = [[self.gradient copy] autorelease];
    return clone;
}

- (void)setColorList:(IJSVGColorList*)list
{
    (void)([_privateColorList release]), _privateColorList = nil;
    _privateColorList = list.retain;
    if (_CGGradient != nil) {
        CGGradientRelease(_CGGradient);
    }
}

+ (CGFloat *)computeColorStops:(IJSVGGradient*)gradient
                        colors:(NSArray**)someColors
{
    NSArray<IJSVGNode*>* stops = gradient.childNodes;
    NSMutableArray* colors = [[[NSMutableArray alloc] initWithCapacity:stops.count] autorelease];
    CGFloat* stopsParams = (CGFloat*)malloc(stops.count * sizeof(CGFloat));
    
    NSInteger i = 0;
    for(IJSVGNode* stopNode in stops) {
        NSColor* color = stopNode.fillColor;
        CGFloat opacity = stopNode.fillOpacity.value;
        CGFloat offset = stopNode.offset.value;
        stopsParams[i++] = offset;
        if(color == nil) {
            color = [IJSVGColor colorFromHEXInteger:0x000000];
            if(opacity != 1.f) {
                color = [IJSVGColor changeAlphaOnColor:color
                                                    to:opacity];
            }
        }
        [colors addObject:color];
    }
    *someColors = (NSArray*)colors;
    return stopsParams;
}

//+ (CGFloat*)computeColorStops:(IJSVGGradient*)gradient
//                      element:(NSXMLElement*)element
//                       colors:(NSArray**)someColors
//{
//    // find each stop element
//    NSArray* stops = [element children];
//    NSMutableArray* colors = [[[NSMutableArray alloc] initWithCapacity:stops.count] autorelease];
//    CGFloat* stopsParams = (CGFloat*)malloc(stops.count * sizeof(CGFloat));
//    NSInteger i = 0;
//    for (NSXMLElement* stop in stops) {
//        // find the offset
//        CGFloat offset = [stop attributeForName:IJSVGAttributeOffset].stringValue.floatValue;
//        if (offset > 1.f) {
//            offset /= 100.f;
//        }
//
//        stopsParams[i++] = offset;
//
//        // find the stop opacity
//        CGFloat stopOpacity = 1.f;
//        NSXMLNode* stopOpacityAttribute = [stop attributeForName:IJSVGAttributeStopOpacity];
//        if (stopOpacityAttribute != nil) {
//            stopOpacity = stopOpacityAttribute.stringValue.floatValue;
//        }
//
//        // find the stop color
//        NSString* scs = [stop attributeForName:IJSVGAttributeStopColor].stringValue;
//        NSColor* stopColor = [IJSVGColor colorFromString:scs];
//        if (stopColor != nil && stopOpacity != 1.f) {
//            stopColor = [IJSVGColor changeAlphaOnColor:stopColor
//                                                    to:stopOpacity];
//        }
//
//        // compute any style that there was...
//        NSXMLNode* styleAttribute = [stop attributeForName:IJSVGAttributeStyle];
//        if (styleAttribute != nil) {
//
//            IJSVGStyle* style = [IJSVGStyle parseStyleString:styleAttribute.stringValue];
//            NSColor* color = [IJSVGColor colorFromString:[style property:IJSVGAttributeStopColor]];
//
//            // we have a color!
//            if (color != nil) {
//                // is there a stop opacity?
//                NSString* numberString = nil;
//                if ((numberString = [style property:IJSVGAttributeStopOpacity]) != nil) {
//                    color = [IJSVGColor changeAlphaOnColor:color
//                                                        to:numberString.floatValue];
//                } else {
//                    color = [IJSVGColor changeAlphaOnColor:color
//                                                        to:stopOpacity];
//                }
//                stopColor = color;
//            }
//        }
//
//        // default is black
//        if (stopColor == nil) {
//            stopColor = [IJSVGColor colorFromString:@"black"];
//            if (stopOpacity != 1.f) {
//                stopColor = [IJSVGColor changeAlphaOnColor:stopColor
//                                                        to:stopOpacity];
//            }
//        }
//
//        // add the stop color
//        [(NSMutableArray*)colors addObject:stopColor];
//    }
//    *someColors = colors;
//    return stopsParams;
//}

- (IJSVGColorList*)colorList
{
    IJSVGColorList* sheet = [[[IJSVGColorList alloc] init] autorelease];
    sheet.types |= IJSVGColorListTypeStopColor;
    NSInteger num = self.gradient.numberOfColorStops;
    for (NSInteger i = 0; i < num; i++) {
        NSColor* color;
        [self.gradient getColor:&color
                       location:nil
                        atIndex:i];
        [sheet addColor:color];
    }
    return sheet;
}

- (CGGradientRef)CGGradient
{
    // store it in the cache
    if (_CGGradient != nil) {
        return _CGGradient;
    }

    // actually create the gradient
    NSInteger num = self.gradient.numberOfColorStops;
    CGFloat* locations = malloc(sizeof(CGFloat) * num);
    CFMutableArrayRef colors = CFArrayCreateMutable(kCFAllocatorDefault, (CFIndex)num,
        &kCFTypeArrayCallBacks);
    for (NSInteger i = 0; i < num; i++) {
        NSColor* color;
        [self.gradient getColor:&color
                       location:&locations[i]
                        atIndex:i];
        if (_privateColorList != nil) {
            color = [_privateColorList proposedColorForColor:color];
        }
        CFArrayAppendValue(colors, color.CGColor);
    }
    CGGradientRef result = CGGradientCreateWithColors(self.gradient.colorSpace.CGColorSpace,
        colors, locations);
    CFRelease(colors);
    free(locations);
    return _CGGradient = result;
}

- (void)drawInContextRef:(CGContextRef)ctx
              objectRect:(NSRect)objectRect
       absoluteTransform:(CGAffineTransform)absoluteTransform
                viewPort:(CGRect)viewBox
{
}

- (void)_debugStart:(CGPoint)startPoint
                end:(CGPoint)endPoint
            context:(CGContextRef)ctx
{
    CGContextSaveGState(ctx);
    CGContextSetStrokeColorWithColor(ctx, NSColor.blackColor.CGColor);
    CGContextSetLineWidth(ctx, 1.f);
    CGContextMoveToPoint(ctx, startPoint.x, startPoint.y);
    CGContextAddLineToPoint(ctx, endPoint.x, endPoint.y);
    CGContextStrokePath(ctx);
}

@end
