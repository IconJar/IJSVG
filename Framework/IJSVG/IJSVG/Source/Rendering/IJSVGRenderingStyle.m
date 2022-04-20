//
//  IJSVGStyleList.m
//  IconJar
//
//  Created by Curtis Hard on 09/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import "IJSVGRenderingStyle.h"

@implementation IJSVGRenderingStyle

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
            @"colorList", @"fillColor", @"strokeColor" ];
    }
    return array;
}

@end
