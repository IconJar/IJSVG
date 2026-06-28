//
//  IJSVGGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradient.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGStyle.h>

@implementation IJSVGGradient

- (void)_invalidateCGGradient
{
    if(_CGGradient != NULL) {
        CGGradientRelease(_CGGradient);
        _CGGradient = NULL;
    }
}

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
    [self _invalidateCGGradient];
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
    if(node.numberOfStops > 0 && node.locations != NULL) {
        size_t length = sizeof(CGFloat)*node.numberOfStops;
        self.locations = (CGFloat*)malloc(length);
        memcpy(self.locations, node.locations, length);
    } else {
        self.locations = NULL;
    }
    self.x1 = node.x1.copy;
    self.x2 = node.x2.copy;
    self.y1 = node.y1.copy;
    self.y2 = node.y2.copy;
}

- (BOOL)containsRelativeUnits
{
    return self.x1.isRelativeUnit == YES || self.x2.isRelativeUnit == YES ||
        self.y1.isRelativeUnit == YES || self.y2.isRelativeUnit == YES ||
        [super containsRelativeUnits] == YES;
}

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style
                              matchingTraits:(IJSVGColorUsageTraits)traits
{
    IJSVGTraitedColorStorage* storage = [[IJSVGTraitedColorStorage alloc] init];
    for(NSColor* color in self.colors) {
        NSColor* replacement = [style.colors colorForColor:color
                                            matchingTraits:IJSVGColorUsageTraitGradientStop];
        IJSVGTraitedColor* traited = nil;
        traited = [IJSVGTraitedColor colorWithColor:replacement ?: color
                                             traits:IJSVGColorUsageTraitGradientStop];
        [storage addColor:traited];
    }
    return storage;
}

- (void)setColors:(NSArray<NSColor*>*)colors
{
    _colors = colors;
    [self _invalidateCGGradient];
}

- (void)setLocations:(CGFloat*)locations
{
    if(_locations != NULL) {
        (void)free(_locations), _locations = NULL;
    }
    _locations = locations;
    [self _invalidateCGGradient];
}

+ (CGFloat*)computeColorStops:(IJSVGGradient*)gradient
                       colors:(NSArray**)someColors
{
    NSUInteger childCount = gradient.children.count;
    NSMutableArray* colors = [[NSMutableArray alloc] initWithCapacity:childCount];
    CGFloat* stopsParams = NULL;
    if(childCount != 0) {
        stopsParams = (CGFloat*)malloc(childCount * sizeof(CGFloat));
    }
    
    NSUInteger i = 0;
    for(IJSVGNode* stopNode in gradient.children) {
        if(stopNode.type != IJSVGNodeTypeStop) {
            continue;
        }
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
    if(i == 0 && stopsParams != NULL) {
        (void)free(stopsParams), stopsParams = NULL;
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
