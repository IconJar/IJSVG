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
    if(_locations != NULL) {
        (void)free(_locations), _locations = NULL;
    }
    if (_CGGradient != NULL) {
        (void)CGGradientRelease(_CGGradient), _CGGradient = NULL;
    }
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGGradient* clone = [super copyWithZone:zone];
    clone.numberOfStops = self.numberOfStops;
    clone.colors = clone.colors.copy;
    size_t length = sizeof(CGFloat)*self.numberOfStops;
    clone.locations = (CGFloat*)malloc(length);
    memcpy(clone.locations, self.locations, length);
    return clone;
}

- (void)setLocations:(CGFloat*)locations
{
    if(_locations != NULL) {
        (void)free(_locations), _locations = NULL;
    }
    _locations = locations;
}

- (void)setColorList:(IJSVGColorList*)list
{
    _privateColorList = list;
    if (_CGGradient != NULL) {
        CGGradientRelease(_CGGradient);
        _CGGradient = NULL;
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
//    NSInteger num = self.gradient.numberOfColorStops;
//    for (NSInteger i = 0; i < num; i++) {
//        NSColor* color;
//        [self.gradient getColor:&color
//                       location:nil
//                        atIndex:i];
//        IJSVGColorType* type = [IJSVGColorType typeWithColor:color
//                                                        flags:IJSVGColorTypeFlagStop];
//        [sheet addColor:type];
//    }
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
    NSInteger num = self.numberOfStops;
    CFMutableArrayRef colors = CFArrayCreateMutable(kCFAllocatorDefault, (CFIndex)num,
        &kCFTypeArrayCallBacks);
    for (NSColor* color in _colors) {
//        NSColor* color;
//        [self.gradient getColor:&color
//                       location:&locations[i]
//                        atIndex:i];
//        if (_privateColorList != nil) {
//            color = [_privateColorList proposedColorForColor:color];
//        }
        CFArrayAppendValue(colors, color.CGColor);
    }
    CGGradientRef result = CGGradientCreateWithColors(IJSVGColor.defaultColorSpace.CGColorSpace,
        colors, _locations);
    CFRelease(colors);
    return _CGGradient = result;
}

- (void)drawInContextRef:(CGContextRef)ctx
              objectRect:(NSRect)objectRect
       absoluteTransform:(CGAffineTransform)absoluteTransform
                viewPort:(CGRect)viewBox
{
}

@end
