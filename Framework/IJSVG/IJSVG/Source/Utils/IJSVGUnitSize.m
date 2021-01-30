//
//  IJSVGUnitSize.m
//  IJSVG
//
//  Created by Curtis Hard on 12/02/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import "IJSVGUnitSize.h"

@implementation IJSVGUnitSize

- (void)dealloc
{
    (void)[_width release], _width = nil;
    (void)[_height release], _height = nil;
    [super dealloc];
}

+ (IJSVGUnitSize*)sizeWithWidth:(IJSVGUnitLength*)width
                         height:(IJSVGUnitLength*)height
{
    IJSVGUnitSize* size = [[[self alloc] init] autorelease];
    size.width = width;
    size.height = height;
    return size;
}

@end
