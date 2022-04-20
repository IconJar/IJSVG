//
//  IJSVGGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradient.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGGradient

@synthesize colorList = _privateColorList;

- (void)dealloc
{
    if (_CGGradient != nil) {
        CGGradientRelease(_CGGradient);
    }
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGGradient* clone = [super copyWithZone:zone];
    clone.gradient = self.gradient.copy;
    return clone;
}

- (void)setColorList:(IJSVGColorList*)list
{
    _privateColorList = list;
    if (_CGGradient != nil) {
        CGGradientRelease(_CGGradient);
        _CGGradient = nil;
    }
}

+ (CGFloat*)computeColorStops:(IJSVGGradient*)gradient
                        colors:(NSArray**)someColors
{
    NSArray<IJSVGNode*>* stops = gradient.children;
    NSMutableArray* colors = [[NSMutableArray alloc] initWithCapacity:stops.count];
    CGFloat* stopsParams = (CGFloat*)malloc(stops.count * sizeof(CGFloat));
    
    NSInteger i = 0;
    for(IJSVGNode* stopNode in stops) {
        NSColor* color = ((IJSVGColorNode*)(stopNode.fill)).color;
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

- (IJSVGColorList*)colorList
{
    IJSVGColorList* sheet = [[IJSVGColorList alloc] init];
    NSInteger num = self.gradient.numberOfColorStops;
    for (NSInteger i = 0; i < num; i++) {
        NSColor* color;
        [self.gradient getColor:&color
                       location:nil
                        atIndex:i];
        IJSVGColorType* type = [IJSVGColorType typeWithColor:color
                                                        flags:IJSVGColorTypeFlagStop];
        [sheet addColor:type];
    }
    return sheet;
}

- (IJSVGColorList*)computedColorList
{
    return _privateColorList;
}

- (CGGradientRef)CGGradient
{
    // store it in the cache
    if (_CGGradient != nil) {
        return _CGGradient;
    }

    // actually create the gradient
    NSInteger num = self.gradient.numberOfColorStops;
    CGFloat* locations = (CGFloat*)malloc(sizeof(CGFloat) * num);
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
    CGGradientRef result = CGGradientCreateWithColors(_gradient.colorSpace.CGColorSpace,
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
