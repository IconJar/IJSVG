//
//  IJSVGStyleSheetStyle.m
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVG/IJSVGStyleSheetUtils.h>
#import <IJSVG/IJSVGUtils.h>

static BOOL IJSVGStyleSheetPropertyNameIsValid(const char* chars, NSUInteger start,
                                                NSUInteger end)
{
    if(start == end) {
        return NO;
    }
    for(NSUInteger index = start; index < end; index++) {
        char c = IJSVGCharToLower(chars[index]);
        BOOL letter = (c >= 'a' && c <= 'z') || c == '-' || c == '_' || (unsigned char)c >= 0x80;
        if(!letter && !(index > start && c >= '0' && c <= '9')) {
            return NO;
        }
    }
    return YES;
}

static void IJSVGStyleSheetApplyDeclaration(IJSVGStyleSheetStyle* style,
                                             const char* chars, NSUInteger start,
                                             NSUInteger end)
{
    start = IJSVGStyleSheetIndexBySkippingWhitespace(chars, start, end);
    NSUInteger colon = start;
    while(colon < end && chars[colon] != ':') {
        colon++;
    }
    if(colon == end) {
        return;
    }
    NSUInteger keyEnd = colon;
    while(keyEnd > start && IJSVGStyleSheetCharIsWhitespace(chars[keyEnd - 1])) {
        keyEnd--;
    }
    if(!IJSVGStyleSheetPropertyNameIsValid(chars, start, keyEnd)) {
        return;
    }
    NSString* key = IJSVGStyleSheetStringFromUTF8Bytes(chars, start, keyEnd);
    NSString* value = IJSVGStyleSheetStringFromUTF8Bytes(chars, colon + 1, end);
    if(value.length != 0) {
        [style setPropertyValue:value
                    forProperty:key];
    }
}

@implementation IJSVGStyleSheetStyle

- (id)init
{
    if((self = [super init]) != nil) {
        _dict = [[NSMutableDictionary alloc] init];
        _importantProperties = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)setResolvedValue:(id)value
             forProperty:(NSString*)key
               important:(BOOL)important
{
    if(!important && [_importantProperties containsObject:key]) {
        return;
    }
    _dict[key] = value;
    if(important) {
        [_importantProperties addObject:key];
    } else {
        [_importantProperties removeObject:key];
    }
}

- (void)setPropertyValue:(id)value
             forProperty:(NSString*)key
{
    BOOL important = NO;
    if([value isKindOfClass:NSString.class]) {
        value = IJSVGStyleSheetDeclarationValue(value, &important);
        if([value length] == 0) {
            return;
        }
    }
    NSDictionary* declarations = IJSVGStyleSheetExpandDeclaration(key, value);
    for(NSString* property in declarations) {
        [self setResolvedValue:declarations[property]
                   forProperty:property
                     important:important];
    }
}

- (BOOL)isPropertyImportant:(NSString*)key
{
    return [_importantProperties containsObject:key];
}

- (NSDictionary*)properties
{
    return _dict;
}

- (id)property:(NSString*)key
{
    return [_dict objectForKey:key];
}

+ (IJSVGStyleSheetStyle*)parseStyleString:(NSString*)string
{
    IJSVGStyleSheetStyle* style = [[self.class alloc] init];
    NSString* cleanString = IJSVGStyleSheetStringByRemovingCSSComments(string);
    const char* chars = cleanString.UTF8String;
    if(chars == NULL) {
        return style;
    }

    NSUInteger length = strlen(chars);
    if(length == 0) {
        return style;
    }

    NSUInteger start = 0;
    char quote = 0;
    BOOL escaped = NO;
    NSUInteger depth = 0;
    for(NSUInteger index = 0; index <= length; index++) {
        char c = index == length ? ';' : chars[index];
        if(IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
            continue;
        }
        if(c == '(' || c == '[' || c == '{') {
            depth++;
        } else if((c == ')' || c == ']' || c == '}') && depth != 0) {
            depth--;
        } else if(c == ';' && depth == 0) {
            IJSVGStyleSheetApplyDeclaration(style, chars, start, index);
            start = index + 1;
        }
    }

    return style;
}

+ (NSString*)trimString:(NSString*)string
{
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSArray*)allowedColourKeys
{
    return @[ @"fill", @"stroke-color", @"stop-color", @"stroke" ];
}

- (void)setProperties:(NSDictionary*)properties
           replaceAll:(BOOL)flag
{
    if(flag) {
        [_dict removeAllObjects];
        [_importantProperties removeAllObjects];
    }
    for(NSString* key in properties) {
        [self setPropertyValue:properties[key]
                   forProperty:key];
    }
}

- (NSString*)description
{
    return [_dict description];
}

- (void)addPropertiesFromStyle:(IJSVGStyleSheetStyle*)style
{
    for(NSString* key in style->_dict) {
        [self setResolvedValue:style->_dict[key]
                    forProperty:key
                      important:[style->_importantProperties containsObject:key]];
    }
}

- (IJSVGStyleSheetStyle*)mergedStyle:(IJSVGStyleSheetStyle*)style
{
    IJSVGStyleSheetStyle* newStyle = [[IJSVGStyleSheetStyle alloc] init];
    [newStyle addPropertiesFromStyle:self];
    [newStyle addPropertiesFromStyle:style];
    return newStyle;
}

@end
