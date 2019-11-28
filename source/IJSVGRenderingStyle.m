//
//  IJSVGStyleList.m
//  IconJar
//
//  Created by Curtis Hard on 09/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import "IJSVGRenderingStyle.h"

@implementation IJSVGRenderingStyle

@synthesize colorList = _colorList;
@synthesize lineCapStyle = _lineCapStyle;
@synthesize lineJoinStyle = _lineJoinStyle;
@synthesize lineWidth = _lineWidth;
@synthesize fillColor = _fillColor;
@synthesize strokeColor = _strokeColor;

- (void)dealloc
{
    (void)([_fillColor release]), _fillColor = nil;
    (void)([_strokeColor release]), _strokeColor = nil;
    (void)([_colorList release]), _colorList = nil;
    [super dealloc];
}

- (id)init
{
    if((self = [super init]) != nil) {
        _lineCapStyle = IJSVGLineCapStyleNone;
        _lineJoinStyle = IJSVGLineJoinStyleNone;
        _lineWidth = IJSVGInheritedFloatValue;
        _colorList = [[IJSVGColorList alloc] init];
    }
    return self;
}

+ (NSArray<NSString *> *)observableProperties
{
    unsigned int count;
    objc_property_t * properties = class_copyPropertyList(IJSVGRenderingStyle.class,
                                                          &count);
    NSMutableArray * names = [[[NSMutableArray alloc] initWithCapacity:count] autorelease];
    for(int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        const char * name = property_getName(property);
        NSString * stringName = [NSString stringWithCString:name
                                                   encoding:NSUTF8StringEncoding];
        [names addObject:stringName];
    }
    free(properties);
    return names;
}

@end
