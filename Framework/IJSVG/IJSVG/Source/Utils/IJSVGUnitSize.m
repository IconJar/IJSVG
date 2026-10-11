//
//  IJSVGUnitSize.m
//  IJSVG
//
//  Created by Curtis Hard on 12/02/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGUnitSize.h>

@implementation IJSVGUnitSize

- (BOOL)containsRelativeUnits
{
    return self.width.isRelativeUnit || self.height.isRelativeUnit;
}

+ (IJSVGUnitSize*)sizeWithWidth:(IJSVGUnitLength*)width
                         height:(IJSVGUnitLength*)height
{
    IJSVGUnitSize* size = [[self alloc] init];
    size->_width = width;
    size->_height = height;
    return size;
}

+ (IJSVGUnitSize*)sizeWithCGSize:(CGSize)size
{
    return [self sizeWithWidth:[IJSVGUnitLength unitWithFloat:size.width]
                        height:[IJSVGUnitLength unitWithFloat:size.height]];
}

+ (IJSVGUnitSize*)zeroSize
{
    return [self sizeWithWidth:IJSVGZeroUnitLength
                        height:IJSVGZeroUnitLength];
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGUnitSize* size = [[self.class alloc] init];
    size->_width = _width.copy;
    size->_height = _height.copy;
    return size;
}

- (BOOL)isZeroSize
{
    return self.width.value == 0.f && self.height.value == 0.f;
}

- (void)convertUnitsToLengthType:(IJSVGUnitLengthType)lengthType
{
    _width = [_width lengthBySettingType:lengthType];
    _height = [_height lengthBySettingType:lengthType];
}

- (CGSize)computeValue:(CGSize)size
{
    return CGSizeMake([_width computeValue:size.width],
                      [_height computeValue:size.height]);
}

- (CGSize)value
{
    return [self computeValue:CGSizeZero];
}


@end
