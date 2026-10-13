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
            if (identifier != IJSVGNodeAttributeOffset && identifier != IJSVGNodeAttributeStopColor && identifier != IJSVGNodeAttributeStopOpacity) {
                return NO;
            }
        }
    }
    for (IJSVGXMLNode* child = IJSVGXMLFirstChild(element); child != NULL; child = IJSVGXMLNext(child)) {
        IJSVGStop* stop = [[IJSVGStop alloc] init];
        stop.name = @"stop";
        [gradient addChild:stop];
        [stop consumeXMLAttributes:IJSVGXMLAttributes(child) parser:parser];
    }
    return YES;
}

@implementation IJSVGGradientStops {
    IJSVGGradientStopData* _stops;
    NSUInteger _stopCount;
    NSArray<NSColor*>* _colors;
    NSData* _locations;
}

+ (BOOL)canCacheElement:(IJSVGXMLNode*)element
{
    for (IJSVGXMLNode* child = IJSVGXMLFirstChild(element); child != NULL; child = IJSVGXMLNext(child)) {
        if (IJSVGXMLKind(child) != NSXMLElementKind || ![IJSVGXMLLocalName(child) isEqualToString:@"stop"] || IJSVGXMLChildCount(child) != 0) {
            return NO;
        }
        if (IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(child, IJSVGNodeAttributeStopColor)).length == 0) {
            return NO;
        }
        IJSVGXMLAttributeList childAttributeIterator = IJSVGXMLAttributes(child);
        for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&childAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&childAttributeIterator)) {
            IJSVGNodeAttribute attributeIdentifier = attribute->identifier;
            if (attributeIdentifier != IJSVGNodeAttributeOffset && attributeIdentifier != IJSVGNodeAttributeStopColor && attributeIdentifier != IJSVGNodeAttributeStopOpacity) {
                return NO;
            }
            NSString* value = IJSVGXMLAttributeValue(attribute).lowercaseString;
            if ([value containsString:@"inherit"] || [value containsString:@"currentcolor"] || [value containsString:@"var("]) {
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
    for (NSUInteger index = 0; index < _stopCount; index++) {
        [gradient addChild:IJSVGGradientStopDataCreateStop(_stops + index)];
    }
    gradient.colors = _colors;
    gradient.numberOfStops = _colors.count;
    CGFloat* locations = _locations.length == 0 ? NULL : malloc(_locations.length);
    if (locations != NULL) {
        memcpy(locations, _locations.bytes, _locations.length);
    }
    gradient.locations = locations;
}

@end
