//
//  IJSVGStyleSheetStyle.m
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGCSSParser.h>
#import <IJSVGCSSVariables.h>
#import <IJSVGParserUtils.h>
#import <IJSVGStyleSheetUtils.h>

@interface IJSVGStyleSheetStyle ()
- (void)setDeclarationValue:(id)value forProperty:(NSString*)key important:(BOOL)important;
@end

static BOOL IJSVGStyleSheetPropertyNameIsValid(const char* chars, NSUInteger start, NSUInteger end)
{
    if (start == end) {
        return NO;
    }
    for (NSUInteger index = start; index < end; index++) {
        char c = IJSVGCharToLower(chars[index]);
        BOOL letter = (c >= 'a' && c <= 'z') || c == '-' || c == '_' || (unsigned char)c >= 0x80;
        if (!letter && !(index > start && c >= '0' && c <= '9')) {
            return NO;
        }
    }
    return YES;
}

static void IJSVGStyleSheetApplyDeclaration(IJSVGStyleSheetStyle* style, const char* chars, NSUInteger start, NSUInteger end)
{
    start = IJSVGStyleSheetIndexBySkippingWhitespace(chars, start, end);
    NSUInteger colon = start;
    while (colon < end && chars[colon] != ':') {
        if (chars[colon] == '\\') {
            if (!IJSVGStyleSheetSkipEscape(chars, end, &colon, NO)) {
                return;
            }
        } else {
            colon++;
        }
    }
    if (colon == end) {
        return;
    }
    NSUInteger keyEnd = colon;
    while (keyEnd > start && IJSVGStyleSheetCharIsWhitespace(chars[keyEnd - 1])) {
        keyEnd--;
    }
    NSString* key;
    if (memchr(chars + start, '\\', keyEnd - start) != NULL) {
        NSUInteger cursor = start;
        key = IJSVGStyleSheetConsumeIdentifier(chars, keyEnd, &cursor);
        if (key == nil || cursor != keyEnd) {
            return;
        }
    } else {
        if (!IJSVGStyleSheetPropertyNameIsValid(chars, start, keyEnd)) {
            return;
        }
        key = IJSVGStyleSheetStringFromUTF8Bytes(chars, start, keyEnd);
    }
    BOOL important = NO;
    const char* bytes = chars + colon + 1;
    NSRange range = IJSVGStyleSheetDeclarationRange(bytes, end - colon - 1, &important);
    if (range.length == 0 && ![key hasPrefix:@"--"]) {
        return;
    }
    NSString* value = range.length == 0 ? @"" : IJSVGStyleSheetStringFromUTF8Bytes(bytes, range.location, NSMaxRange(range));
    if (value != nil) {
        [style setDeclarationValue:value forProperty:key important:important];
    }
}

static NSString* IJSVGStyleSheetResolvedVariableProperty(NSString* property, NSString* source, NSString* raw, NSDictionary<NSString*, id>* properties, NSMutableDictionary<NSString*, NSMutableDictionary<NSString*, NSDictionary<NSString*, NSString*>*>*>** cache)
{
    NSUInteger attribute = IJSVGNodeAttributeForName(source);
    if (attribute != IJSVGNodeAttributeFont && attribute != IJSVGNodeAttributeMarker) {
        NSString* value = IJSVGCSSResolveDeclarationVariables(raw, properties);
        NSDictionary<NSString*, NSString*>* expanded = nil;
        return value != nil && IJSVGStyleSheetResolveDeclaration(source, value, &expanded) != nil ? value : nil;
    }
    if (*cache == nil) {
        *cache = [[NSMutableDictionary alloc] init];
    }
    NSMutableDictionary<NSString*, NSDictionary<NSString*, NSString*>*>* declarations = (*cache)[source];
    if (declarations == nil) {
        declarations = [[NSMutableDictionary alloc] init];
        (*cache)[source] = declarations;
    }
    NSDictionary<NSString*, NSString*>* expanded = declarations[raw];
    if (expanded == nil) {
        NSString* value = IJSVGCSSResolveDeclarationVariables(raw, properties);
        expanded = value != nil ? IJSVGStyleSheetExpandDeclaration(source, value) : @ {};
        declarations[raw] = expanded;
    }
    return expanded[property];
}

@implementation IJSVGStyleSheetStyle

- (id)init
{
    if ((self = [super init]) != nil) {
        _dict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)setResolvedValue:(id)value forProperty:(NSString*)key important:(BOOL)important
{
    NSString* source = [value isKindOfClass:NSString.class] && IJSVGCSSValueMayContainVariables(value) ? key : nil;
    [self storeResolvedValue:value forProperty:key important:important variableSource:source];
}

- (void)storeResolvedValue:(id)value forProperty:(NSString*)key important:(BOOL)important variableSource:(NSString*)source
{
    if (!important && [_importantProperties containsObject:key]) {
        return;
    }
    _dict[key] = value;
    [_invalidVariableProperties removeObject:key];
    if ([key hasPrefix:@"--"]) {
        _hasCustomProperties = YES;
    } else if (source != nil) {
        if (_variableSources == nil) {
            _variableSources = [[NSMutableDictionary alloc] init];
        }
        _variableSources[key] = source;
    } else {
        [_variableSources removeObjectForKey:key];
    }
    _geometryPropertiesKnown = NO;
    [self invalidateAttributeEntries];
    if (important) {
        if (_importantProperties == nil) {
            _importantProperties = [[NSMutableSet alloc] init];
        }
        [_importantProperties addObject:key];
    } else {
        [_importantProperties removeObject:key];
    }
}

- (void)setPropertyValue:(id)value forProperty:(NSString*)key
{
    BOOL important = NO;
    if ([value isKindOfClass:NSString.class]) {
        NSString* original = value;
        value = IJSVGStyleSheetDeclarationValue(value, &important);
        if ([value length] == 0) {
            const char* bytes = original.UTF8String;
            BOOL emptyCustom = [key hasPrefix:@"--"] && bytes != NULL && strlen(bytes) == [original lengthOfBytesUsingEncoding:NSUTF8StringEncoding] && (important || strspn(bytes, " \t\r\n\f") == strlen(bytes));
            if (!emptyCustom) {
                return;
            }
            value = @"";
        }
    }
    [self setDeclarationValue:value forProperty:key important:important];
}

- (void)setDeclarationValue:(id)value forProperty:(NSString*)key important:(BOOL)important
{
    NSDictionary<NSString*, NSString*>* declarations = nil;
    BOOL variables = NO;
    NSString* name = IJSVGStyleSheetResolveVariableDeclaration(key, value, &declarations, &variables);
    if (name == nil) {
        return;
    }

    [self storeResolvedValue:value forProperty:name important:important variableSource:variables ? name : nil];

    for (NSString* property in declarations) {
        if (!important && [self isPropertyImportant:property]) {
            continue;
        }
        [self storeResolvedValue:declarations[property] forProperty:property important:important variableSource:variables ? name : nil];
    }
}

- (BOOL)hasCustomProperties
{
    return _hasCustomProperties;
}

- (void)copyProperty:(NSString*)property fromStyle:(IJSVGStyleSheetStyle*)style
{
    BOOL important = [style isPropertyImportant:property];
    if (!important && [self isPropertyImportant:property]) {
        return;
    }
    [self storeResolvedValue:[style property:property] forProperty:property important:important variableSource:style->_variableSources[property]];
    if ([style->_invalidVariableProperties containsObject:property]) {
        if (_invalidVariableProperties == nil) {
            _invalidVariableProperties = [[NSMutableSet alloc] init];
        }
        [_invalidVariableProperties addObject:property];
    }
}

- (IJSVGStyleSheetStyle*)styleByResolvingVariables:(NSDictionary<NSString*, id>*)properties
{
    if (_variableSources.count == 0) {
        return self;
    }
    IJSVGStyleSheetStyle* result = [[IJSVGStyleSheetStyle alloc] init];
    result->_dict = [_dict mutableCopy];
    result->_importantProperties = [_importantProperties mutableCopy];
    result->_invalidVariableProperties = [_invalidVariableProperties mutableCopy];
    result->_hasCustomProperties = _hasCustomProperties;
    NSMutableDictionary<NSString*, NSMutableDictionary<NSString*, NSDictionary<NSString*, NSString*>*>*>* shorthands = nil;
    for (NSString* property in _variableSources) {
        NSString* source = _variableSources[property];
        NSString* value = IJSVGStyleSheetResolvedVariableProperty(property, source, _dict[property], properties, &shorthands);
        value = IJSVGCSSResolvedPaintValue(value, IJSVGNodeAttributeForName(property));
        BOOL invalid = value.length == 0;
        [result storeResolvedValue:invalid ? @"" : value forProperty:property important:[self isPropertyImportant:property] variableSource:nil];
        if (invalid) {
            if (result->_invalidVariableProperties == nil) {
                result->_invalidVariableProperties = [[NSMutableSet alloc] init];
            }
            [result->_invalidVariableProperties addObject:property];
        }
    }
    return result;
}

- (BOOL)hasImportantProperties
{
    return _importantProperties.count != 0;
}

- (BOOL)isPropertyImportant:(NSString*)key
{
    return [_importantProperties containsObject:key];
}

- (NSDictionary<NSString*, id>*)properties
{
    return _dict;
}

- (void)dealloc
{
    free(_attributes);
}

- (void)invalidateAttributeEntries
{
    free(_attributes);
    _attributes = NULL;
    _attributeCount = 0;
    _attributesReady = NO;
}

- (void)buildAttributeEntries
{
    NSUInteger capacity = _dict.count;
    _attributes = capacity == 0 ? NULL : malloc(capacity * sizeof(IJSVGStyleSheetAttribute));
    if (capacity != 0 && _attributes == NULL) {
        [NSException raise:NSMallocException format:@"Unable to allocate style attributes"];
    }
    _attributeCount = 0;
    _hasGeometryProperties = NO;
    for (NSString* name in _dict) {
        NSUInteger attribute = IJSVGNodeAttributeForName(name);
        if (attribute == NSNotFound) {
            continue;
        }
        if (IJSVGAttributeIsGeometryProperty(attribute)) {
            _hasGeometryProperties = YES;
            continue;
        }
        _attributes[_attributeCount++] = (IJSVGStyleSheetAttribute) { attribute, name, _dict[name], [_importantProperties containsObject:name], [_invalidVariableProperties containsObject:name] };
    }
    _geometryPropertiesKnown = YES;
    _attributesReady = YES;
}

- (const IJSVGStyleSheetAttribute*)attributesWithCount:(NSUInteger*)count
{
    if (!_attributesReady) {
        [self buildAttributeEntries];
    }
    *count = _attributeCount;
    return _attributes;
}

- (BOOL)hasGeometryProperties
{
    if (!_geometryPropertiesKnown) {
        _hasGeometryProperties = NO;
        for (NSString* name in _dict) {
            if (IJSVGAttributeIsGeometryProperty(IJSVGNodeAttributeForName(name))) {
                _hasGeometryProperties = YES;
                break;
            }
        }
        _geometryPropertiesKnown = YES;
    }
    return _hasGeometryProperties;
}

- (id)property:(NSString*)key
{
    return [_dict objectForKey:key];
}

+ (IJSVGStyleSheetStyle*)parseStyleString:(NSString*)string
{
    return [self parseStyleString:string removeComments:YES];
}

+ (IJSVGStyleSheetStyle*)parseStyleString:(NSString*)string removeComments:(BOOL)removeComments
{
    __attribute__((objc_precise_lifetime)) NSString* cleanString = removeComments ? IJSVGStyleSheetStringByRemovingCSSComments(string) : string;
    IJSVGStringBytes source = IJSVGStringGetBytes(cleanString);
    return [self parseStyleBytes:source.bytes length:source.length];
}

+ (IJSVGStyleSheetStyle*)parseStyleBytes:(const char*)chars length:(NSUInteger)length
{
    IJSVGStyleSheetStyle* style = [[self.class alloc] init];
    if (chars == NULL || memchr(chars, 0, length) != NULL) {
        return style;
    }
    NSUInteger start = 0;
    char quote = 0;
    BOOL escaped = NO;
    NSUInteger depth = 0;
    for (NSUInteger index = 0; index <= length; index++) {
        if (quote == 0 && !escaped) {
            while (index < length && strchr(";()[]{}'\"\\", chars[index]) == NULL) {
                index++;
            }
        }
        char c = index == length ? ';' : chars[index];
        if (IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
            continue;
        }
        if (c == '(' || c == '[' || c == '{') {
            depth++;
        } else if ((c == ')' || c == ']' || c == '}') && depth != 0) {
            depth--;
        } else if (c == ';' && depth == 0) {
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

+ (NSArray<NSString*>*)allowedColourKeys
{
    return @[ @"fill", @"stroke-color", @"stop-color", @"stroke" ];
}

- (void)setProperties:(NSDictionary<NSString*, id>*)properties replaceAll:(BOOL)flag
{
    if (flag) {
        [_dict removeAllObjects];
        [_variableSources removeAllObjects];
        [_invalidVariableProperties removeAllObjects];
        _hasCustomProperties = NO;
        _geometryPropertiesKnown = NO;
        [self invalidateAttributeEntries];
        [_importantProperties removeAllObjects];
    }
    for (NSString* key in properties) {
        [self setPropertyValue:properties[key] forProperty:key];
    }
}

- (NSString*)description
{
    return [_dict description];
}

- (void)addPropertiesFromStyle:(IJSVGStyleSheetStyle*)style
{
    for (NSString* key in style->_dict) {
        [self copyProperty:key fromStyle:style];
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
