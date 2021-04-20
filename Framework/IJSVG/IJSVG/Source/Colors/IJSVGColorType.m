//
//  IJSVGColorType.m
//  IJSVG
//
//  Created by Curtis Hard on 20/04/2021.
//  Copyright © 2021 Curtis Hard. All rights reserved.
//

#import "IJSVGColorType.h"

@implementation IJSVGColorType

- (void)dealloc
{
    (void)[_color release], _color = nil;
    [super dealloc];
}

+ (IJSVGColorType*)typeWithColor:(NSColor*)color
                            mask:(IJSVGColorTypeMask)mask
{
    IJSVGColorType* type = [[[self alloc] init] autorelease];
    type.color = color;
    type.mask = mask;
    return type;
}

- (BOOL)isEqual:(id)object
{
    if([object isKindOfClass:IJSVGColorType.class] == NO) {
        return NO;
    }
    return [self.color isEqual:((IJSVGColorType*)object).color];
}

- (NSUInteger)hash
{
    return self.color.hash;
}

@end
