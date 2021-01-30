//
//  IJSVGStyleList.m
//  IconJar
//
//  Created by Curtis Hard on 09/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import "IJSVGRenderingStyle.h"

@implementation IJSVGRenderingStyle

- (void)dealloc
{
    (void)([_fillColor release]), _fillColor = nil;
    (void)([_strokeColor release]), _strokeColor = nil;
    (void)([_colorList release]), _colorList = nil;
    [super dealloc];
}

- (id)init
{
    if ((self = [super init]) != nil) {
        _lineCapStyle = IJSVGLineCapStyleNone;
        _lineJoinStyle = IJSVGLineJoinStyleNone;
        _lineWidth = IJSVGInheritedFloatValue;
        _colorList = [[IJSVGColorList alloc] init];
    }
    return self;
}

+ (NSArray<NSString*>*)observableProperties
{
    static NSArray* array = nil;
    if (array == nil) {
        array = @[ @"lineCapStyle", @"lineJoinStyle", @"lineWidth",
            @"colorList", @"fillColor", @"strokeColor" ]
                    .retain;
    }
    return array;
}

@end
