//
//  IJSVGStyle.m
//  IJSVG
//
//  Created by Curtis Hard on 09/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyle.h>

@implementation IJSVGStyle

- (void)setFillColor:(CGColorRef)value
{
    CGColorRef retained = CGColorRetain(value);
    CGColorRelease(_fillColor);
    _fillColor = retained;
}

- (void)setStrokeColor:(CGColorRef)value
{
    CGColorRef retained = CGColorRetain(value);
    CGColorRelease(_strokeColor);
    _strokeColor = retained;
}

- (void)dealloc
{
    CGColorRelease(_fillColor);
    CGColorRelease(_strokeColor);
}

- (id)init
{
    if ((self = [super init]) != nil) {
        _lineCapStyle = IJSVGLineCapStyleNone;
        _lineJoinStyle = IJSVGLineJoinStyleNone;
        _lineWidth = IJSVGInheritedFloatValue;
        _miterLimit = IJSVGInheritedFloatValue;
    }
    return self;
}

- (IJSVGTraitedColorStorage*)colors
{
    // this can be lazy as most users wont use this functionality
    if (_colors == nil) {
        _colors = [[IJSVGTraitedColorStorage alloc] init];
    }
    return _colors;
}

@end
