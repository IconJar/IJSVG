//
//  IJSVGColorList.m
//  IconJar
//
//  Created by Curtis Hard on 07/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTraitedColorStorage.h>

@implementation IJSVGReplacementColor

- (void)setReplacementColor:(NSColor*)replacementColor
{
    _replacementColor = [IJSVGColor computeColorSpace:replacementColor];
}

@end

@implementation IJSVGTraitedColorStorage

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        _replacementColors = [[NSMutableArray alloc] init];
        _colors = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)addColor:(IJSVGTraitedColor*)color
{
    if([_colors containsObject:color] == YES) {
        void (^handler)(IJSVGTraitedColor * _Nonnull obj, BOOL * _Nonnull stop) =
        ^(IJSVGTraitedColor * _Nonnull obj, BOOL * _Nonnull stop) {
            if([obj isEqual:color] == YES) {
                [obj addTraits:color.traits];
                *stop = YES;
            }
        };
        [_colors enumerateObjectsUsingBlock:handler];
        return;
    }
    [_colors addObject:color];
}

- (void)addTraits:(IJSVGColorUsageTraits)traits
{
    for(IJSVGTraitedColor* color in _colors) {
        [color addTraits:traits];
    }
}

- (void)replaceColor:(NSColor*)replaceColor
           withColor:(NSColor*)withColor
              traits:(IJSVGColorUsageTraits)traits
{
    replaceColor = [IJSVGColor computeColorSpace:replaceColor];
    withColor = [IJSVGColor computeColorSpace:withColor];
    IJSVGReplacementColor* repColor = [self replacementColorForColor:replaceColor
                                                           withColor:withColor];
    if(repColor == nil) {
        repColor = [[IJSVGReplacementColor alloc] init];
        repColor.color = replaceColor;
        repColor.replacementColor = withColor;
        [_replacementColors addObject:repColor];
    }
    [repColor addTraits:traits];
}

- (IJSVGReplacementColor*)replacementColorForColor:(NSColor*)replacementColor
                                         withColor:(NSColor*)withColor
{
    for(IJSVGReplacementColor* color in _replacementColors) {
        if([color.color isEqual:color] == YES &&
           [color.replacementColor isEqual:withColor] == YES) {
            return color;
        }
    }
    return nil;
}

- (IJSVGReplacementColor*)replacementColorForColor:(NSColor*)color
                                    matchingTraits:(IJSVGColorUsageTraits)traits
{
    for(IJSVGReplacementColor* replacementColor in _replacementColors) {
        if([replacementColor.color isEqual:color] &&
           [replacementColor matchesTraits:traits] == YES) {
            return replacementColor;
        }
    }
    return nil;
}

- (NSColor*)colorForColor:(NSColor*)color
           matchingTraits:(IJSVGColorUsageTraits)traits
{
    color = [IJSVGColor computeColorSpace:color];
    IJSVGReplacementColor* repColor = nil;
    if((repColor = [self replacementColorForColor:color
                                   matchingTraits:traits]) != nil) {
        return repColor.replacementColor;
    }
    return nil;
}

- (void)mergeWithColors:(IJSVGTraitedColorStorage*)colorList
{
    for(IJSVGTraitedColor* traitedColor in colorList.colors) {
        [self addColor:traitedColor];
    }
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
