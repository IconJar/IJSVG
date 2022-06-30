//
//  IJSVGColorType.m
//  IJSVG
//
//  Created by Curtis Hard on 20/04/2021.
//  Copyright © 2021 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTraitedColor.h>
#import <IJSVG/IJSVGColor.h>

@implementation IJSVGTraitedColor

+ (IJSVGTraitedColor*)colorWithColor:(NSColor*)color
                              traits:(IJSVGColorUsageTraits)traits
{
    IJSVGTraitedColor* type = [[self alloc] init];
    type.color = color;
    type.traits = traits;
    return type;
}

- (instancetype)init
{
    if((self = [super init]) != nil) {
        _traits = IJSVGColorUsageTraitNone;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if([object isKindOfClass:IJSVGTraitedColor.class] == NO) {
        return NO;
    }
    return [self.color isEqual:((IJSVGTraitedColor*)object).color];
}

- (void)setColor:(NSColor *)color
{
    _color = [IJSVGColor computeColorSpace:color];
}

- (NSUInteger)hash
{
    return self.color.hash;
}

- (void)addTraits:(IJSVGColorUsageTraits)traits
{
    _traits |= traits;
}

- (void)removeTraits:(IJSVGColorUsageTraits)traits
{
    _traits = _traits & ~traits;
}

- (BOOL)matchesTraits:(IJSVGColorUsageTraits)traits
{
    return (self.traits & traits) == traits;
}

@end
