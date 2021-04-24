//
//  IJSVGColorList.m
//  IconJar
//
//  Created by Curtis Hard on 07/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import "IJSVGColorList.h"

@implementation IJSVGColorList

- (void)dealloc
{
    (void)([_replacementColorTree release]), _replacementColorTree = nil;
    (void)([_colors release]), _colors = nil;
    [super dealloc];
}

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        _replacementColorTree = [[NSMutableDictionary alloc] init];
        _colors = [[NSMutableSet alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGColorList* sheet = [[self.class alloc] init];
    [sheet setReplacementColors:[_replacementColorTree.copy autorelease]
            clearExistingColors:YES];
    return sheet;
}

- (NSColor*)proposedColorForColor:(NSColor*)color
{
    // nothing found, just return color
    if (_replacementColorTree == nil || _replacementColorTree.count == 0) {
        return color;
    }

    // check the mappings
    NSColor* found = nil;
    color = [IJSVGColor computeColorSpace:color];
    if ((found = _replacementColorTree[color]) != nil) {
        return found;
    }
    return color;
}

- (void)_invalidateColorTree
{
    (void)([_replacementColorTree release]), _replacementColorTree = nil;
    _replacementColorTree = [[NSMutableDictionary alloc] init];
}

- (void)removeAllReplacementColors
{
    [self _invalidateColorTree];
}

- (void)removeReplacementColor:(NSColor*)color
{
    if (_replacementColorTree == nil) {
        return;
    }
    [_replacementColorTree removeObjectForKey:[IJSVGColor computeColorSpace:color]];
}

- (void)setReplacementColor:(NSColor*)newColor
                   forColor:(NSColor*)color
{
    color = [IJSVGColor computeColorSpace:color];
    newColor = [IJSVGColor computeColorSpace:newColor];
    _replacementColorTree[color] = newColor;
}

- (void)setReplacementColors:(NSDictionary<NSColor*, NSColor*>*)colors
         clearExistingColors:(BOOL)clearExistingColors
{
    if (clearExistingColors == YES) {
        [self _invalidateColorTree];
    }
    for (NSColor* oldColor in colors) {
        [self setReplacementColor:colors[oldColor]
                         forColor:oldColor];
    }
}

- (NSSet<IJSVGColorType*>*)colors
{
    return [NSSet setWithSet:_colors];
}

- (void)addColorsFromList:(IJSVGColorList*)sheet
{
    for(IJSVGColorType* color in sheet.colors) {
        [self addColor:color];
    }
}

- (void)addColor:(IJSVGColorType*)color
{
    // we just need to update its bit mask
    if([_colors containsObject:color] == YES) {
        void (^handler)(IJSVGColorType * _Nonnull obj, BOOL * _Nonnull stop) =
        ^(IJSVGColorType * _Nonnull obj, BOOL * _Nonnull stop) {
            if([obj isEqual:color] == YES) {
                obj.flags |= color.flags;
                *stop = YES;
            }
        };
        [_colors enumerateObjectsUsingBlock:handler];
        return;
    }
    [_colors addObject:color];
}

- (NSDictionary<NSColor*,NSColor*>*)replacementColors
{
    return _replacementColorTree;
}

- (void)removeColor:(IJSVGColorType*)color
{
    [_colors removeObject:color];
}

- (NSUInteger)count
{
    return _colors.count;
}

@end
