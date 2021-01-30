//
//  IJSVGUnitRect.m
//  IJSVG
//
//  Created by Curtis Hard on 12/02/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import "IJSVGUnitRect.h"

@implementation IJSVGUnitRect

- (void)dealloc
{
    (void)[_size release], _size = nil;
    (void)[_origin release], _origin = nil;
    [super dealloc];
}

+ (IJSVGUnitRect*)rectWithOrigin:(IJSVGUnitPoint*)origin
                            size:(IJSVGUnitSize*)size
{
    IJSVGUnitRect* rect = [[[self alloc] init] autorelease];
    rect.origin = origin;
    rect.size = size;
    return rect;
}

@end
