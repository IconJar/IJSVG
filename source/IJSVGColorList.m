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
    [_name release], _name = nil;
    [_colorTree release], _colorTree = nil;
    [super dealloc];
}

- (instancetype)init
{
    if((self = [super init]) != nil) {
        _colorTree = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGColorList * sheet = [[self.class alloc] init];
//    [sheet setReplacementColors:[_colorTree.copy autorelease]
//            clearExistingColors:YES];
    return sheet;
}

- (NSMutableDictionary<NSColor *, NSColor *> *)_dictForUsageType:(IJSVGColorListUsageType)type
{
    NSMutableDictionary * dict = _colorTree[@(type)];
    if(dict == nil) {
        dict = [[[NSMutableDictionary alloc] init] autorelease];
        _colorTree[@(type)] = dict;
    }
    return dict;
}

- (NSColor *)proposedColorForColor:(NSColor *)color
                         usageType:(IJSVGColorListUsageType)type
{
    // nothing found, just return color
    if(_colorTree == nil || _colorTree.count == 0) {
        return color;
    }
    
    // check the mappings
    NSColor * found = nil;
    NSDictionary * dict = [self _dictForUsageType:type];
    color = [IJSVGColor computeColorSpace:color];
    if((found = dict[color]) != nil) {
        return found;
    }
    return color;
}

- (void)_invalidateColorTree
{
    [_colorTree release], _colorTree = nil;
    _colorTree = [[NSMutableDictionary alloc] init];
}

- (void)removeAllReplacementColors
{
    [self _invalidateColorTree];
}

- (void)removeReplacementColor:(NSColor *)color
                  forUsageType:(IJSVGColorListUsageType)type
{
    if(_colorTree == nil) {
        return;
    }
    NSMutableDictionary * dict = [self _dictForUsageType:type];
    [dict removeObjectForKey:[IJSVGColor computeColorSpace:color]];
}

- (void)setReplacementColor:(NSColor *)newColor
                   forColor:(NSColor *)color
                  usageType:(IJSVGColorListUsageType)type
{
    color = [IJSVGColor computeColorSpace:color];
    newColor = [IJSVGColor computeColorSpace:newColor];
    NSMutableDictionary * dict = [self _dictForUsageType:type];
    dict[color] = newColor;
}

- (void)setReplacementColors:(NSDictionary<NSColor *, NSColor *> *)colors
                   usageType:(IJSVGColorListUsageType)usageType
         clearExistingColors:(BOOL)clearExistingColors
{
    if(clearExistingColors == YES) {
    }
    for(NSColor * oldColor in colors) {
        [self setReplacementColor:colors[oldColor]
                         forColor:oldColor
                        usageType:usageType];
    }
}

- (NSSet<NSColor *> *)colorsForUsageType:(IJSVGColorListUsageType)type
{
    NSDictionary * dict = [self _dictForUsageType:type];
    return [NSSet setWithArray:dict.allValues];
}

- (void)addColorsFromList:(IJSVGColorList *)sheet
{
//    [_colors addObjectsFromArray:sheet.colors.allObjects];
}

- (void)addColor:(NSColor *)color
    forUsageType:(IJSVGColorListUsageType)type
{
    NSMutableDictionary * dict = [self _dictForUsageType:type];
    color = [IJSVGColor computeColorSpace:color];
    dict[color] = color;
}

- (void)removeColor:(NSColor *)color
       forUsageType:(IJSVGColorListUsageType)type
{
    NSMutableDictionary * dict = [self _dictForUsageType:type];
    [dict removeObjectForKey:[IJSVGColor computeColorSpace:color]];
}


@end
