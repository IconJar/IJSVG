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

@implementation IJSVGGradientStops {
    NSArray<IJSVGGradientStopData*>* _stops;
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
        NSMutableArray<IJSVGGradientStopData*>* stops = [[NSMutableArray alloc] init];
        _inheritedOpacity = gradient.fillOpacity.value;
        IJSVGXMLNode* source = IJSVGXMLFirstChild(element);
        for (IJSVGStop* stop in gradient.children) {
            [stops addObject:[[IJSVGGradientStopData alloc] initWithStop:stop element:source]];
            source = IJSVGXMLNext(source);
        }
        _stops = stops.copy;
        _colors = gradient.colors.copy;
        _locations = [NSData dataWithBytes:gradient.locations length:gradient.numberOfStops * sizeof(CGFloat)];
    }
    return self;
}

- (void)applyToGradient:(IJSVGGradient*)gradient
{
    for (IJSVGGradientStopData* data in _stops) {
        [gradient addChild:[data newStop]];
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
