//
//  IJSVGGradientStops.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
#import <IJSVGGradientStopData.h>
#import <IJSVGGradientStops.h>
#import <IJSVGNodeParsing.h>

static BOOL IJSVGGradientBytesMatch(const unsigned char* bytes, const char* keyword, NSUInteger length)
{
    for (NSUInteger index = 0; index < length; index++) {
        if ((bytes[index] | 0x20) != keyword[index]) {
            return NO;
        }
    }
    return YES;
}

static BOOL IJSVGGradientAttributeDependsOnStyle(IJSVGXMLAttribute* attribute)
{
    const unsigned char* bytes = (const unsigned char*)IJSVGXMLAttributeBytes(attribute);
    NSUInteger length = attribute->value.length;
    for (NSUInteger index = 0; index < length; index++) {

        // Escapes and comments can conceal CSS keywords from this byte scan.
        // Keep them, and non-ASCII values, on the general parsing path.
        if (bytes[index] >= 0x80 || bytes[index] == '\\' || bytes[index] == '/') {
            return YES;
        }
        NSUInteger remaining = length - index;
        if ((remaining >= 7 && (IJSVGGradientBytesMatch(bytes + index, "inherit", 7) || IJSVGGradientBytesMatch(bytes + index, "initial", 7))) || (remaining >= 12 && IJSVGGradientBytesMatch(bytes + index, "currentcolor", 12)) || (remaining >= 4 && IJSVGGradientBytesMatch(bytes + index, "var(", 4)) || (remaining >= 5 && IJSVGGradientBytesMatch(bytes + index, "unset", 5)) || (remaining >= 6 && IJSVGGradientBytesMatch(bytes + index, "revert", 6))) {
            return YES;
        }
    }
    return NO;
}

BOOL IJSVGPopulatePlainGradientStops(IJSVGGradient* gradient, IJSVGXMLNode* element, IJSVGParser* parser)
{
    // Validate every child before changing the gradient.
    for (IJSVGXMLNode* child = IJSVGXMLFirstChild(element); child != NULL; child = IJSVGXMLNext(child)) {
        if (IJSVGXMLType(child) != IJSVGNodeTypeStop || child->childCount != 0) {
            return NO;
        }
        IJSVGXMLAttributeList attributes = IJSVGXMLAttributes(child);
        for (NSUInteger index = 0; index < attributes.count; index++) {
            IJSVGNodeAttribute identifier = attributes.first[index].identifier;
            IJSVGXMLAttribute* attribute = attributes.first + index;
            if (IJSVGGradientAttributeDependsOnStyle(attribute)) {
                return NO;
            }
            if (identifier == IJSVGNodeAttributeStyle) {
                IJSVGStyleSheetStyle* style = [parser parsedInlineStyleForValue:IJSVGXMLAttributeValue(attribute)];
                if (style.hasCustomProperties) {
                    return NO;
                }
                NSUInteger count = 0;
                const IJSVGStyleSheetAttribute* entries = [style attributesWithCount:&count];
                for (NSUInteger entry = 0; entry < count; entry++) {
                    NSUInteger type = entries[entry].attribute;
                    if (type != IJSVGNodeAttributeOffset && type != IJSVGNodeAttributeStopColor && type != IJSVGNodeAttributeStopOpacity) {
                        return NO;
                    }
                }
            } else if (identifier != IJSVGNodeAttributeOffset && identifier != IJSVGNodeAttributeStopColor && identifier != IJSVGNodeAttributeStopOpacity) {
                return NO;
            }
        }
    }
    for (IJSVGXMLNode* child = IJSVGXMLFirstChild(element); child != NULL; child = IJSVGXMLNext(child)) {
        IJSVGStop* stop = [[IJSVGStop alloc] init];
        [gradient addChild:stop];
        IJSVGXMLAttribute* inlineAttribute = IJSVGXMLAttributeForIdentifier(child, IJSVGNodeAttributeStyle);
        if (inlineAttribute == NULL) {
            [stop consumeXMLAttributes:IJSVGXMLAttributes(child) parser:parser];
        } else {
            // Resolve the three declarations before consuming them so inline
            // opacity also applies to a presentation-attribute colour.
            NSString* offset = IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(child, IJSVGNodeAttributeOffset));
            NSString* color = IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(child, IJSVGNodeAttributeStopColor));
            NSString* opacity = IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(child, IJSVGNodeAttributeStopOpacity));
            IJSVGStyleSheetStyle* style = [parser parsedInlineStyleForValue:IJSVGXMLAttributeValue(inlineAttribute)];
            NSUInteger count = 0;
            const IJSVGStyleSheetAttribute* entries = [style attributesWithCount:&count];
            for (NSUInteger index = 0; index < count; index++) {
                switch (entries[index].attribute) {
                    case IJSVGNodeAttributeOffset:
                        offset = entries[index].value;
                        break;
                    case IJSVGNodeAttributeStopColor:
                        color = entries[index].value;
                        break;
                    case IJSVGNodeAttributeStopOpacity:
                        opacity = entries[index].value;
                        break;
                }
            }
            [stop consumeOffset:offset color:color opacity:opacity parser:parser];
        }
    }
    return YES;
}

@implementation IJSVGGradientStops {
    IJSVGGradientStopData* _stops;
    NSUInteger _stopCount;
    NSArray* _colors;
    NSData* _locations;
}

+ (BOOL)canCacheElement:(IJSVGXMLNode*)element
{
    for (IJSVGXMLNode* child = IJSVGXMLFirstChild(element); child != NULL; child = IJSVGXMLNext(child)) {
        if (IJSVGXMLKind(child) != NSXMLElementKind || IJSVGXMLType(child) != IJSVGNodeTypeStop || strcmp(child->name, "stop") != 0 || IJSVGXMLChildCount(child) != 0) {
            return NO;
        }
        IJSVGXMLAttribute* color = IJSVGXMLAttributeForIdentifier(child, IJSVGNodeAttributeStopColor);
        if (color == NULL || color->value.length == 0) {
            return NO;
        }
        IJSVGXMLAttributeList childAttributeIterator = IJSVGXMLAttributes(child);
        for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&childAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&childAttributeIterator)) {
            IJSVGNodeAttribute attributeIdentifier = attribute->identifier;
            if (attributeIdentifier != IJSVGNodeAttributeOffset && attributeIdentifier != IJSVGNodeAttributeStopColor && attributeIdentifier != IJSVGNodeAttributeStopOpacity) {
                return NO;
            }
            if (IJSVGGradientAttributeDependsOnStyle(attribute)) {
                return NO;
            }
        }
    }
    return YES;
}

- (instancetype)initWithGradient:(IJSVGGradient*)gradient element:(IJSVGXMLNode*)element
{
    if ((self = [super init]) != nil) {
        NSUInteger count = gradient.children.count;
        if (count != 0) {
            _stops = calloc(count, sizeof(*_stops));
            if (_stops == NULL) {
                return nil;
            }
        }
        _inheritedOpacity = gradient.fillOpacity.value;
        IJSVGXMLNode* source = IJSVGXMLFirstChild(element);
        for (IJSVGStop* stop in gradient.children) {
            _stops[_stopCount++] = IJSVGGradientStopDataCreate(stop, source);
            source = IJSVGXMLNext(source);
        }
        _colors = gradient.colors.copy;
        _locations = [NSData dataWithBytes:gradient.locations length:gradient.numberOfStops * sizeof(CGFloat)];
    }
    return self;
}

- (void)dealloc
{
    for (NSUInteger index = 0; index < _stopCount; index++) {
        IJSVGGradientStopDataRelease(_stops + index);
    }
    free(_stops);
}

- (void)applyToGradient:(IJSVGGradient*)gradient
{
    [gradient deferStops:self];
    gradient.colors = _colors;
    gradient.numberOfStops = _colors.count;
    CGFloat* locations = _locations.length == 0 ? NULL : malloc(_locations.length);
    if (locations != NULL) {
        memcpy(locations, _locations.bytes, _locations.length);
    }
    gradient.locations = locations;
}

- (void)appendStopsToGradient:(IJSVGGradient*)gradient
{
    for (NSUInteger index = 0; index < _stopCount; index++) {
        [gradient addChild:IJSVGGradientStopDataCreateStop(_stops + index)];
    }
}

@end
