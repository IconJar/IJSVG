//
//  IJSVGGradientStops.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGGradientStopData.h>
#import <IJSVGGradientStops.h>

@implementation IJSVGGradientStops {
    NSArray<IJSVGGradientStopData*>* _stops;
    NSArray<NSColor*>* _colors;
    NSData* _locations;
}

+ (BOOL)canCacheElement:(NSXMLElement*)element
{
    for (NSXMLNode* child in element.children) {
        if (child.kind != NSXMLElementKind || ![child.localName isEqualToString:@"stop"] || child.childCount != 0) {
            return NO;
        }
        if ([((NSXMLElement*)child) attributeForName:@"stop-color"].stringValue.length == 0)
            return NO;
        for (NSXMLNode* attribute in ((NSXMLElement*)child).attributes) {
            NSString* name = attribute.name;
            if (![name isEqualToString:@"offset"] && ![name isEqualToString:@"stop-color"] && ![name isEqualToString:@"stop-opacity"]) {
                return NO;
            }
            NSString* value = attribute.stringValue.lowercaseString;
            if ([value containsString:@"inherit"] || [value containsString:@"currentcolor"] || [value containsString:@"var("]) {
                return NO;
            }
        }
    }
    return YES;
}

- (instancetype)initWithGradient:(IJSVGGradient*)gradient element:(NSXMLElement*)element
{
    if ((self = [super init]) != nil) {
        NSMutableArray<IJSVGGradientStopData*>* stops = [[NSMutableArray alloc] init];
        _inheritedOpacity = gradient.fillOpacity.value;
        NSUInteger index = 0;
        for (IJSVGStop* stop in gradient.children) {
            NSXMLElement* source = (NSXMLElement*)element.children[index++];
            [stops addObject:[[IJSVGGradientStopData alloc] initWithStop:stop element:source]];
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
