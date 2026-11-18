//
//  IJSVGTraitedColorStorage.m
//  IJSVG
//
//  Created by Curtis Hard on 07/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTraitedColorStorage.h>

@implementation IJSVGReplacementColor

- (void)dealloc
{
    CGColorRelease(_replacementColor);
}

/// Retains the replacement profile and components.
- (void)setReplacementColor:(CGColorRef)replacementColor
{
    CGColorRef retained = CGColorRetain([IJSVGColor preservingColorSpace:replacementColor]);
    CGColorRelease(_replacementColor);
    _replacementColor = retained;
}

@end

@implementation IJSVGTraitedColorStorage

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        _replacementColors = [[NSMutableArray alloc] init];
        _colors = [[NSMutableSet alloc] init];
        _replacementTraits = IJSVGColorUsageTraitNone;
        _traits = IJSVGColorUsageTraitNone;
    }
    return self;
}

/// Merges traits into an equivalent stored color using one set lookup.
- (void)addColor:(IJSVGTraitedColor*)color
{
    IJSVGTraitedColor* existingColor = [_colors member:color];
    if (existingColor != nil) {
        [existingColor addTraits:color.traits];
        return;
    }
    _traits |= color.traits;
    [_colors addObject:color];
}

- (void)addTraits:(IJSVGColorUsageTraits)traits
{
    for (IJSVGTraitedColor* color in _colors) {
        [color addTraits:traits];
    }
}

/// Registers replacements using profile aware color identity.
- (void)replaceColor:(CGColorRef)replaceColor withColor:(CGColorRef)withColor traits:(IJSVGColorUsageTraits)traits
{
    replaceColor = [IJSVGColor preservingColorSpace:replaceColor];
    withColor = [IJSVGColor preservingColorSpace:withColor];
    IJSVGReplacementColor* repColor = [self replacementColorForColor:replaceColor withColor:withColor];
    if (repColor == nil) {
        repColor = [[IJSVGReplacementColor alloc] init];
        repColor.color = replaceColor;
        repColor.replacementColor = withColor;
        [_replacementColors addObject:repColor];
    }
    _replacementTraits |= traits;
    [repColor addTraits:traits];
}

- (IJSVGReplacementColor*)replacementColorForColor:(CGColorRef)replacementColor withColor:(CGColorRef)withColor
{
    for (IJSVGReplacementColor* color in _replacementColors) {
        if (CGColorEqualToColor(color.color, replacementColor) == YES && CGColorEqualToColor(color.replacementColor, withColor) == YES) {
            return color;
        }
    }
    return nil;
}

- (IJSVGReplacementColor*)replacementColorForColor:(CGColorRef)color matchingTraits:(IJSVGColorUsageTraits)traits
{
    for (IJSVGReplacementColor* replacementColor in _replacementColors) {
        if (CGColorEqualToColor(replacementColor.color, color) && [replacementColor matchesTraits:traits] == YES) {
            return replacementColor;
        }
    }
    return nil;
}

/// Looks up replacements without clipping wide gamut colors.
- (CGColorRef)colorForColor:(CGColorRef)color matchingTraits:(IJSVGColorUsageTraits)traits
{
    if ([self matchesReplacementTraits:traits] == NO) {
        return nil;
    }
    color = [IJSVGColor preservingColorSpace:color];
    IJSVGReplacementColor* repColor = nil;
    if ((repColor = [self replacementColorForColor:color matchingTraits:traits]) != nil) {
        return repColor.replacementColor;
    }
    return nil;
}

- (void)unionColorStorage:(IJSVGTraitedColorStorage*)colorList
{
    for (IJSVGTraitedColor* traitedColor in colorList.colors) {
        [self addColor:traitedColor];
    }
}

- (BOOL)matchesTraits:(IJSVGColorUsageTraits)traits
{
    return (_traits & traits) == traits;
}

- (BOOL)matchesReplacementTraits:(IJSVGColorUsageTraits)traits
{
    return (_replacementTraits & traits) == traits;
}

- (NSUInteger)replacedColorCount
{
    return _replacementColors.count;
}

- (NSUInteger)count
{
    return _colors.count;
}

- (NSSet<IJSVGTraitedColor*>*)colors
{
    return _colors;
}

@end
