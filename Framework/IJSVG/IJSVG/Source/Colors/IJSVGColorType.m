//
//  IJSVGColorType.m
//  IJSVG
//
//  Created by Curtis Hard on 20/04/2021.
//  Copyright © 2021 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColorType.h>

@implementation IJSVGColorType

+ (IJSVGColorType*)typeWithColor:(NSColor*)color
                           flags:(IJSVGColorTypeFlags)mask
{
    IJSVGColorType* type = [[self alloc] init];
    type.color = color;
    type.flags = mask;
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
