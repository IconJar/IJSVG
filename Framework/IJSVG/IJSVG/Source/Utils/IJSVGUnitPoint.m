//
//  IJSVGUnitPoint.m
//  IJSVG
//
//  Created by Curtis Hard on 12/02/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import "IJSVGUnitPoint.h"

@implementation IJSVGUnitPoint

- (void)dealloc
{
    (void)[_x release], _x = nil;
    (void)[_y release], _y = nil;
    [super dealloc];
}

+ (IJSVGUnitPoint*)pointWithX:(IJSVGUnitLength*)x
                            y:(IJSVGUnitLength*)y
{
    IJSVGUnitPoint* point = [[[self alloc] init] autorelease];
    point.x = x;
    point.y = y;
    return point;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGUnitPoint* point = [[self.class alloc] init];
    point.x = [_x.copy autorelease];
    point.y = [_y.copy autorelease];
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
