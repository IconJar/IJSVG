//
//  IJSVGGradientStopData.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColorNode.h>
#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVGGradientStopData.h>
#import <IJSVGXML.h>

IJSVGGradientStopData IJSVGGradientStopDataCreate(IJSVGStop* stop, IJSVGXMLNode* element)
{
    IJSVGXMLAttribute* opacity = IJSVGXMLAttributeForIdentifier(element, IJSVGNodeAttributeStopOpacity);
    BOOL explicitOpacity = opacity != NULL && opacity->value.length != 0;
    NSString* inlineValue = IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(element, IJSVGNodeAttributeStyle));
    if (inlineValue.length != 0) {
        IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleString:inlineValue];
        NSUInteger count = 0;
        const IJSVGStyleSheetAttribute* entries = [style attributesWithCount:&count];
        for (NSUInteger index = 0; index < count; index++) {
            explicitOpacity |= entries[index].attribute == IJSVGNodeAttributeStopOpacity && entries[index].value.length != 0;
        }
    }
    IJSVGColorNode* fill = (IJSVGColorNode*)stop.fill;
    return (IJSVGGradientStopData) {
        .offset = CFBridgingRetain(stop.offset),
        .opacity = explicitOpacity ? CFBridgingRetain(stop.fillOpacity) : NULL,
        .color = CGColorRetain(fill.color),
        .hasFill = fill != nil,
        .isNoneOrTransparent = fill.isNoneOrTransparent
    };
}

void IJSVGGradientStopDataRelease(IJSVGGradientStopData* data)
{
    if (data->offset != NULL) {
        CFRelease(data->offset);
    }
    if (data->opacity != NULL) {
        CFRelease(data->opacity);
    }
    if (data->color != NULL) {
        CFRelease(data->color);
    }
}

IJSVGStop* IJSVGGradientStopDataCreateStop(const IJSVGGradientStopData* data)
{
    IJSVGStop* stop = [[IJSVGStop alloc] init];
    stop.offset = (__bridge IJSVGUnitLength*)data->offset;
    if (data->opacity != NULL) {
        stop.fillOpacity = (__bridge IJSVGUnitLength*)data->opacity;
    }
    if (data->hasFill) {
        IJSVGColorNode* fill = [[IJSVGColorNode alloc] initWithColor:(CGColorRef)data->color];
        fill.isNoneOrTransparent = data->isNoneOrTransparent;
        stop.fill = fill;
    }
    return stop;
}
