//
//  IJSVGUnitSize.m
//  IJSVG
//
//  Created by Curtis Hard on 12/02/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGUnitSize.h>

@implementation IJSVGUnitSize

+ (IJSVGUnitSize*)sizeWithWidth:(IJSVGUnitLength*)width
                         height:(IJSVGUnitLength*)height
{
    IJSVGUnitSize* size = [[self alloc] init];
    size.width = width;
    size.height = height;
    return size;
}

+ (IJSVGUnitSize*)sizeWithCGSize:(CGSize)size
{
    return [self sizeWithWidth:[IJSVGUnitLength unitWithFloat:size.width]
                        height:[IJSVGUnitLength unitWithFloat:size.height]];
}

+ (IJSVGUnitSize*)zeroSize
{
    return [self sizeWithCGSize:CGSizeZero];
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGUnitSize* size = [[self.class alloc] init];
    size.width = _width.copy;
    size.height = _height.copy;
    return size;
}

- (void)convertUnitsToLengthType:(IJSVGUnitLengthType)lengthType
{
    _width.type = _height.type = lengthType;
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
