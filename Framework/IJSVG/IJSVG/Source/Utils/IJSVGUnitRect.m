//
//  IJSVGUnitRect.m
//  IJSVG
//
//  Created by Curtis Hard on 12/02/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import "IJSVGUnitRect.h"

@implementation IJSVGUnitRect

+ (IJSVGUnitRect*)rectWithOrigin:(IJSVGUnitPoint*)origin
                            size:(IJSVGUnitSize*)size
{
    IJSVGUnitRect* rect = [[self alloc] init];
    rect.origin = origin;
    rect.size = size;
    return rect;
}

+ (IJSVGUnitRect*)rectWithCGRect:(CGRect)rect
{
    return [self rectWithX:rect.origin.x
                         y:rect.origin.y
                     width:rect.size.width
                    height:rect.size.height];
}

+ (IJSVGUnitRect*)rectWithX:(CGFloat)x
                          y:(CGFloat)y
                      width:(CGFloat)width
                     height:(CGFloat)height
{
    IJSVGUnitPoint* origin = [IJSVGUnitPoint pointWithX:[IJSVGUnitLength unitWithFloat:x]
                                                      y:[IJSVGUnitLength unitWithFloat:y]];
    IJSVGUnitSize* size = [IJSVGUnitSize sizeWithWidth:[IJSVGUnitLength unitWithFloat:width]
                                                height:[IJSVGUnitLength unitWithFloat:height]];
    return [self rectWithOrigin:origin
                           size:size];
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGUnitRect* rect = [[self.class alloc] init];
    rect.size = _size.copy;
    rect.origin = _origin.copy;
    return rect;
}

- (CGRect)computeValue:(CGSize)size
{
    return CGRectMake([_origin.x computeValue:size.width],
                      [_origin.y computeValue:size.height],
                      [_size.width computeValue:size.width],
                      [_size.height computeValue:size.height]);
}

- (BOOL)isZeroRect
{
    CGRect computed = [self computeValue:CGSizeZero];
    return CGRectIsNull(computed) == YES || CGRectEqualToRect(computed, CGRectZero);
}

- (IJSVGUnitRect*)copyByConvertingToUnitsLengthType:(IJSVGUnitLengthType)type
{
    IJSVGUnitRect* rect = self.copy;
    [rect convertUnitsLengthType:type];
    return rect;
}

- (void)convertUnitsLengthType:(IJSVGUnitLengthType)type
{
    [_origin convertUnitsToLengthType:type];
    [_size convertUnitsToLengthType:type];
}

- (CGRect)value
{
    return [self computeValue:CGSizeZero];
}

@end
