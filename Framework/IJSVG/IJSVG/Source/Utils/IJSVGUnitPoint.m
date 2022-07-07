//
//  IJSVGUnitPoint.m
//  IJSVG
//
//  Created by Curtis Hard on 12/02/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGUnitPoint.h>

@implementation IJSVGUnitPoint

+ (IJSVGUnitPoint*)pointWithX:(IJSVGUnitLength*)x
                            y:(IJSVGUnitLength*)y
{
    IJSVGUnitPoint* point = [[self alloc] init];
    point.x = x;
    point.y = y;
    return point;
}

+ (IJSVGUnitPoint *)pointWithCGPoint:(CGPoint)point
{
    return [self pointWithX:[IJSVGUnitLength unitWithFloat:point.x]
                          y:[IJSVGUnitLength unitWithFloat:point.y]];
}

+ (IJSVGUnitPoint*)zeroPoint
{
    return [self pointWithCGPoint:CGPointZero];
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGUnitPoint* point = [[self.class alloc] init];
    point.x = _x.copy;
    point.y = _y.copy;
    return point;
}

- (void)convertUnitsToLengthType:(IJSVGUnitLengthType)lengthType
{
    _x.type = _y.type = lengthType;
}

- (CGPoint)computeValue:(CGSize)size
{
    return CGPointMake([_x computeValue:size.width],
                       [_y computeValue:size.height]);
}

- (CGPoint)value
{
    return [self computeValue:CGSizeZero];
}

@end
