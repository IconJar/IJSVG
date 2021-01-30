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

@end
