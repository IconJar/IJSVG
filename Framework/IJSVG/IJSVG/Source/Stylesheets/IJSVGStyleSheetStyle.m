//
//  IJSVGStyle.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVG/IJSVGStyleSheetUtils.h>
#import <IJSVG/IJSVGUtils.h>

@implementation IJSVGStyleSheetStyle

- (id)init
{
    if((self = [super init]) != nil) {
        _dict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)setPropertyValue:(id)value
             forProperty:(NSString*)key
{
    [_dict setObject:value
              forKey:key];
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

    NSUInteger keyStart = 0;
    NSUInteger valueStart = 0;
    NSString* key = nil;
    char quote = 0;
    NSUInteger parenDepth = 0;

    for(NSUInteger i = 0; i < length; i++) {
        char c = chars[i];

        if(quote != 0) {
            if(c == quote && (i == 0 || chars[i - 1] != '\\')) {
                quote = 0;
            }
            continue;
        }

        if(c == '\'' || c == '"') {
            quote = c;
            continue;
        }

        if(c == '(') {
            parenDepth += 1;
            continue;
        }

        if(c == ')' && parenDepth != 0) {
            parenDepth -= 1;
            continue;
        }

        if(key == nil && c == ':') {
            key = IJSVGStyleSheetStringFromUTF8Bytes(chars, keyStart, i);
            valueStart = i + 1;
            continue;
        }

        if(key != nil && parenDepth == 0 && (c == ';' || i == length - 1)) {
            NSUInteger valueEnd = (c == ';') ? i : i + 1;
            NSString* value = IJSVGStyleSheetStringFromUTF8Bytes(chars, valueStart, valueEnd);
            NSString* trimmedKey = [self.class trimString:key];
            NSString* trimmedValue = [self.class trimString:value];

            if(trimmedKey.length != 0 && trimmedValue.length != 0) {
                [style setPropertyValue:trimmedValue
                            forProperty:trimmedKey];
            }

            key = nil;
            keyStart = i + 1;
            valueStart = keyStart;
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
    }
    [_dict addEntriesFromDictionary:properties];
}

- (NSString*)description
{
    return [_dict description];
}

- (IJSVGStyleSheetStyle*)mergedStyle:(IJSVGStyleSheetStyle*)style
{
    IJSVGStyleSheetStyle* newStyle = [[IJSVGStyleSheetStyle alloc] init];
    NSMutableDictionary* dict = [self properties].mutableCopy;
    [dict addEntriesFromDictionary:[style properties]];
    [newStyle setProperties:dict
                 replaceAll:YES];
    return newStyle;
}

@end
