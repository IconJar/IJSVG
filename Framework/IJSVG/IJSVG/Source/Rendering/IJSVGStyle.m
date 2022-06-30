//
//  IJSVGStyleList.m
//  IconJar
//
//  Created by Curtis Hard on 09/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyle.h>

@implementation IJSVGStyle

- (id)init
{
    if ((self = [super init]) != nil) {
        _lineCapStyle = IJSVGLineCapStyleNone;
        _lineJoinStyle = IJSVGLineJoinStyleNone;
        _lineWidth = IJSVGInheritedFloatValue;
        _miterLimit = IJSVGInheritedFloatValue;
        _colors = [[IJSVGColorList alloc] init];
    }
    return self;
}

@end
