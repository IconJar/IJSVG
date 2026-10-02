//
//  IJSVGStyle.m
//  IJSVG
//
//  Created by Curtis Hard on 09/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyle.h>

@implementation IJSVGStyle

- (id)init
{
    if((self = [super init]) != nil) {
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
    if(_colors == nil) {
        _colors = [[IJSVGTraitedColorStorage alloc] init];
    }
    return _colors;
}

@end
