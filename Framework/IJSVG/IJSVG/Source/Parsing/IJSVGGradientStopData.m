//
//  IJSVGGradientStopData.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
#import <IJSVG/IJSVGColorNode.h>
#import <IJSVGGradientStopData.h>

@implementation IJSVGGradientStopData {
    IJSVGUnitLength* _offset;
    IJSVGUnitLength* _opacity;
    NSColor* _color;
    BOOL _hasFill;
    BOOL _isNoneOrTransparent;
}

- (instancetype)initWithStop:(IJSVGStop*)stop element:(IJSVGXMLNode*)element
{
    if ((self = [super init]) != nil) {
        _offset = stop.offset;
        _opacity = IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(element, IJSVGNodeAttributeStopOpacity)).length == 0 ? nil : stop.fillOpacity;
        IJSVGColorNode* fill = (IJSVGColorNode*)stop.fill;
        _hasFill = fill != nil;
        _color = fill.color;
        _isNoneOrTransparent = fill.isNoneOrTransparent;
    }
    return self;
}

- (IJSVGStop*)newStop
{
    IJSVGStop* stop = [[IJSVGStop alloc] init];
    stop.name = @"stop";
    stop.offset = _offset;
    if (_opacity != nil) {
        stop.fillOpacity = _opacity;
    }
    if (_hasFill) {
        IJSVGColorNode* fill = (IJSVGColorNode*)[IJSVGColorNode colorNodeWithColor:_color];
        fill.isNoneOrTransparent = _isNoneOrTransparent;
        stop.fill = fill;
    }
    return stop;
}

@end
