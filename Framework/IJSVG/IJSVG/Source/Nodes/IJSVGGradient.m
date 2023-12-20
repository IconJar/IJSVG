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

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags64* storage = [[IJSVGBitFlags64 alloc] init];
    [storage addBits:[super allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeGradientUnits];
    [storage setBit:IJSVGNodeAttributeGradientTransform];
    return storage;
}

- (void)dealloc
{
    if(_locations != NULL) {
        (void)free(_locations), _locations = NULL;
    }
    if(_CGGradient != NULL) {
        (void)CGGradientRelease(_CGGradient), _CGGradient = NULL;
    }
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGGradient* clone = [[self.class alloc] init];
    [clone applyPropertiesFromNode:self];
    return clone;
}

- (void)applyPropertiesFromNode:(IJSVGGradient*)node
{
    [super applyPropertiesFromNode:node];
    self.numberOfStops = node.numberOfStops;
    self.colors = node.colors.copy;
    size_t length = sizeof(CGFloat)*node.numberOfStops;
    self.locations = (CGFloat*)malloc(length);
    memcpy(self.locations, node.locations, length);
    self.x1 = node.x1.copy;
    self.x2 = node.x2.copy;
    self.y1 = node.y1.copy;
    self.y2 = node.y2.copy;
}

- (void)setLocations:(CGFloat*)locations
{
    if(_locations != NULL) {
        (void)free(_locations), _locations = NULL;
    }
    _locations = locations;
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

- (CGGradientRef)CGGradient
{
    // store it in the cache
    if(_CGGradient != nil) {
        return _CGGradient;
    }

    // actually create the gradient
    NSInteger num = self.numberOfStops;
    CFMutableArrayRef colors = CFArrayCreateMutable(kCFAllocatorDefault, (CFIndex)num,
        &kCFTypeArrayCallBacks);
    for (NSColor* color in _colors) {
        CFArrayAppendValue(colors, color.CGColor);
    }
    CGGradientRef result = CGGradientCreateWithColors(IJSVGColor.defaultColorSpace.CGColorSpace,
        colors, _locations);
    CFRelease(colors);
    return _CGGradient = result;
}

- (void)drawInContextRef:(CGContextRef)ctx
                  bounds:(NSRect)objectRect
               transform:(CGAffineTransform)absoluteTransform
{
}

@end
