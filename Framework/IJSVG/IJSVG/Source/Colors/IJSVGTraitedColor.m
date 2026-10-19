//
//  IJSVGTraitedColor.m
//  IJSVG
//
//  Created by Curtis Hard on 20/04/2021.
//  Copyright © 2021 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGTraitedColor.h>

#import <objc/runtime.h>

@implementation IJSVGTraitedColor

+ (IJSVGTraitedColor*)colorWithColor:(CGColorRef)color traits:(IJSVGColorUsageTraits)traits
{
    IJSVGTraitedColor* type = [[self alloc] init];
    type.color = color;
    type->_traits = traits;
    return type;
}

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        _traits = IJSVGColorUsageTraitNone;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    // Foundation equality accepts arbitrary objects.
    for (Class type = object_getClass(object); type != Nil; type = class_getSuperclass(type)) {
        if (type == IJSVGTraitedColor.class) {
            return [self isEqualToTraitedColor:(IJSVGTraitedColor*)object];
        }
    }
    return NO;
}

- (BOOL)isEqualToTraitedColor:(IJSVGTraitedColor*)other
{
    return other != nil && CGColorEqualToColor(self.color, other.color);
}

- (void)setColor:(CGColorRef)color
{
    CGColorRef retained = CGColorRetain([IJSVGColor computeColorSpace:color]);
    CGColorRelease(_color);
    _color = retained;
}

- (void)dealloc
{
    CGColorRelease(_color);
}

- (NSUInteger)hash
{
    return self.color == NULL ? 0 : CFHash(self.color);
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
