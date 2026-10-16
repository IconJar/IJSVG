//
//  IJSVGParserTextUtils.m
//  IJSVG
//
//  Created by Curtis Hard on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGParserTextUtils.h>
#import <IJSVGParserUtils.h>
#import <IJSVGStyleSheetUtils.h>
#import <string.h>

static NSString* const IJSVGTextSerifFontFamily = @"Times";
static NSString* const IJSVGTextSansSerifFontFamily = @"Helvetica";
static NSString* const IJSVGTextMonospaceFontFamily = @"Courier";
static NSString* const IJSVGTextCursiveFontFamily = @"Apple Chancery";
static NSString* const IJSVGTextFantasyFontFamily = @"Papyrus";
static NSString* const IJSVGTextSystemFontFamily = @".AppleSystemUIFont";

static void IJSVGParseTextLengthBytes(const char* bytes, IJSVGTextAttributeValue* parsed)
{
    IJSVGParsedUnitLength length = { 0 };
    if (bytes != NULL && strchr(bytes, '(') == NULL) {
        IJSVGParseUnitBytes(bytes, &length);
    }
    BOOL fontRelative = length.originalType == IJSVGUnitLengthTypeEM || length.originalType == IJSVGUnitLengthTypeEX;
    parsed.number = fontRelative ? length.value : IJSVGConvertUnitValue(length.value, length.originalType);
    parsed.unitless = length.originalType == IJSVGUnitLengthTypeNumber;
    switch (length.originalType) {
        case IJSVGUnitLengthTypeEM:
            parsed.lengthBasis = IJSVGTextLengthBasisFontSize;
            break;
        case IJSVGUnitLengthTypeEX:
            parsed.lengthBasis = IJSVGTextLengthBasisXHeight;
            break;
        case IJSVGUnitLengthTypePercentage:
            parsed.lengthBasis = IJSVGTextLengthBasisPercentage;
            break;
        default:
            parsed.lengthBasis = IJSVGTextLengthBasisAbsolute;
            break;
    }
    if (isfinite(parsed.number) == NO) {
        parsed.number = 0;
    }
}

static void IJSVGParseTextLength(NSString* value, IJSVGTextAttributeValue* parsed)
{
    IJSVGStringBytes source = IJSVGStringGetBytes(value);
    const char* bytes = source.bytes;
    if (bytes != NULL && memchr(bytes, 0, source.length) != NULL) {
        bytes = NULL;
    }
    IJSVGParseTextLengthBytes(bytes, parsed);
}

static void IJSVGParseTextPositions(NSString* value, IJSVGTextAttributeValue* parsed)
{
    const char* bytes = value.UTF8String;
    char* buffer = bytes != NULL ? strdup(bytes) : NULL;
    NSMutableArray<IJSVGTextAttributeValue*>* lengths = [[NSMutableArray alloc] init];
    if (buffer != NULL) {
        char* state = NULL;
        for (char* token = strtok_r(buffer, " ,\t\r\n", &state); token != NULL; token = strtok_r(NULL, " ,\t\r\n", &state)) {
            NSString* string = [NSString stringWithUTF8String:token];
            if (string != nil) {
                IJSVGTextAttributeValue* length = [[IJSVGTextAttributeValue alloc] init];
                length.string = string;
                length.keyword = IJSVGTextKeywordForString(string);
                IJSVGParseTextLengthBytes(token, length);
                [lengths addObject:length];
            }
        }
        free(buffer);
    }
    parsed.lengths = lengths;
}

static void IJSVGParseTextRotations(NSString* value, IJSVGTextAttributeValue* parsed)
{
    NSMutableArray<IJSVGTextAttributeValue*>* rotations = [[NSMutableArray alloc] init];
    IJSVGEnumerateNumbers(value, ^(CGFloat number) {
        IJSVGTextAttributeValue* rotation = [[IJSVGTextAttributeValue alloc] init];

        // Store radians so layout does not convert every rotation again.
        rotation.number = IJSVGDegreesToRadians(number);
        [rotations addObject:rotation];
    });
    parsed.lengths = rotations;
}

static NSString* IJSVGTextResolveGenericFamily(NSString* family)
{
    const char* name = family.UTF8String;
    if (name == NULL || strlen(name) != [family lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return family;
    }
    switch (IJSVGCharToLower(name[0])) {
        case 's':
            if (IJSVGCharBufferCaseInsensitiveCompare(name, "serif") == YES) {
                return IJSVGTextSerifFontFamily;
            }
            if (IJSVGCharBufferCaseInsensitiveCompare(name, "sans-serif") == YES) {
                return IJSVGTextSansSerifFontFamily;
            }
            if (IJSVGCharBufferCaseInsensitiveCompare(name, "system-ui") == YES) {
                return IJSVGTextSystemFontFamily;
            }
            break;
        case 'm':
            if (IJSVGCharBufferCaseInsensitiveCompare(name, "monospace") == YES) {
                return IJSVGTextMonospaceFontFamily;
            }
            break;
        case 'c':
            if (IJSVGCharBufferCaseInsensitiveCompare(name, "cursive") == YES) {
                return IJSVGTextCursiveFontFamily;
            }
            break;
        case 'f':
            if (IJSVGCharBufferCaseInsensitiveCompare(name, "fantasy") == YES) {
                return IJSVGTextFantasyFontFamily;
            }
            break;
    }
    return family;
}

static void IJSVGParseTextFamilies(NSString* value, IJSVGTextAttributeValue* parsed)
{
    NSMutableArray<NSString*>* families = [[NSMutableArray alloc] init];
    BOOL valid = IJSVGStyleSheetEnumerateFontFamilies(value, ^(NSString* family, BOOL quoted) {
        NSString* resolvedFamily = quoted ? family : IJSVGTextResolveGenericFamily(family);
        [families addObject:resolvedFamily];
    });
    parsed.families = valid ? families : @[];
}

static void IJSVGParseTextFeatures(NSString* value, IJSVGTextAttributeValue* parsed)
{
    const char* bytes = value.UTF8String;
    char* buffer = bytes != NULL ? strdup(bytes) : NULL;
    NSMutableDictionary<NSString*, NSNumber*>* features = [[NSMutableDictionary alloc] init];
    if (buffer != NULL) {
        char* entries = NULL;
        for (char* entry = strtok_r(buffer, ",", &entries); entry != NULL; entry = strtok_r(NULL, ",", &entries)) {
            char* tokens = NULL;
            char* tagBytes = strtok_r(entry, " \t\r\n", &tokens);
            if (tagBytes == NULL) {
                continue;
            }
            char* setting = strtok_r(NULL, " \t\r\n", &tokens);
            tagBytes += strspn(tagBytes, "'\"");
            size_t length = strlen(tagBytes);
            while (length != 0 && (tagBytes[length - 1] == '\'' || tagBytes[length - 1] == '"')) {
                tagBytes[--length] = 0;
            }
            NSString* tag = [NSString stringWithUTF8String:tagBytes];
            if (tag.length != 4) {
                continue;
            }
            NSInteger number = 1;
            if (setting != NULL) {
                if (IJSVGCharBufferCaseInsensitiveCompare(setting, "on")) {
                    number = 1;
                } else if (IJSVGCharBufferCaseInsensitiveCompare(setting, "off")) {
                    number = 0;
                } else {
                    number = (NSInteger)strtoll(setting, NULL, 10);
                    for (const unsigned char* character = (const unsigned char*)setting; *character != 0; character++) {
                        if (*character >= 128) {
                            number = [NSString stringWithUTF8String:setting].integerValue;
                            break;
                        }
                    }
                }
            }
            features[tag] = @(number);
        }
        free(buffer);
    }
    parsed.features = features;
}

static void IJSVGParseTextKeywordList(NSString* value, IJSVGTextAttributeValue* parsed, BOOL ligatures)
{
    const char* bytes = value.UTF8String;
    char* buffer = bytes != NULL ? strdup(bytes) : NULL;
    if (buffer == NULL) {
        return;
    }
    char* state = NULL;
    for (char* token = strtok_r(buffer, "\t\n\r ", &state); token != NULL; token = strtok_r(NULL, "\t\n\r ", &state)) {
        if (ligatures) {
            if (IJSVGCharBufferCaseInsensitiveCompare(token, "no-common-ligatures")) {
                parsed.keyword = IJSVGTextKeywordNoCommonLigatures;
                break;
            }
        } else if (IJSVGCharBufferCaseInsensitiveCompare(token, "underline")) {
            parsed.decorations |= IJSVGTextDecorationUnderline;
        } else if (IJSVGCharBufferCaseInsensitiveCompare(token, "overline")) {
            parsed.decorations |= IJSVGTextDecorationOverline;
        } else if (IJSVGCharBufferCaseInsensitiveCompare(token, "line-through")) {
            parsed.decorations |= IJSVGTextDecorationLineThrough;
        }
    }
    free(buffer);
}

IJSVGTextAttributeValue* IJSVGParseTextAttribute(NSString* value, IJSVGNodeAttribute attribute)
{
    IJSVGTextAttributeValue* parsed = [[IJSVGTextAttributeValue alloc] init];
    parsed.string = value;
    parsed.keyword = IJSVGTextKeywordForString(value);
    parsed.unitless = YES;

    switch (attribute) {
        case IJSVGNodeAttributeFontSize:
        case IJSVGNodeAttributeLetterSpacing:
        case IJSVGNodeAttributeWordSpacing:
        case IJSVGNodeAttributeBaselineShift:
        case IJSVGNodeAttributeLineHeight:
        case IJSVGNodeAttributeInlineSize:
        case IJSVGNodeAttributeTextLength:
        case IJSVGNodeAttributeStartOffset:
            IJSVGParseTextLength(value, parsed);
            break;

        case IJSVGNodeAttributeX:
        case IJSVGNodeAttributeY:
        case IJSVGNodeAttributeDX:
        case IJSVGNodeAttributeDY:
            IJSVGParseTextPositions(value, parsed);
            break;

        case IJSVGNodeAttributeRotate:
            IJSVGParseTextRotations(value, parsed);
            break;

        case IJSVGNodeAttributePathLength:
            parsed.number = value.doubleValue;
            break;
        case IJSVGNodeAttributeFontSizeAdjust: {
            const char* start = value.UTF8String;
            char* end = NULL;
            parsed.number = start != NULL ? strtod(start, &end) : -1.f;
            BOOL numeric = parsed.keyword == IJSVGTextKeywordUnspecified;
            BOOL validKeyword = parsed.keyword == IJSVGTextKeywordNone || parsed.keyword == IJSVGTextKeywordInherit || parsed.keyword == IJSVGTextKeywordInitial || parsed.keyword == IJSVGTextKeywordUnset;
            if ((numeric && (end == start || end == NULL || *end != 0 || !isfinite(parsed.number) || parsed.number < 0.f)) || (!numeric && !validKeyword)) {
                parsed.keyword = IJSVGTextKeywordInherit;
            }
            break;
        }
        case IJSVGNodeAttributeFontWeight:
            parsed.number = value.doubleValue;

            // Keep numeric weights intact for font matching and relative inheritance.
            if (parsed.keyword == IJSVGTextKeywordUnspecified && (!isfinite(parsed.number) || parsed.number < 1 || parsed.number > 1000)) {
                parsed.keyword = IJSVGTextKeywordInherit;
            }
            break;
        case IJSVGNodeAttributeFontVariantLigatures:
            IJSVGParseTextKeywordList(value, parsed, YES);
            break;
        case IJSVGNodeAttributeFontFamily:
            IJSVGParseTextFamilies(value, parsed);
            break;

        case IJSVGNodeAttributeFontFeatureSettings:
            IJSVGParseTextFeatures(value, parsed);
            break;

        case IJSVGNodeAttributeTextDecoration:
        case IJSVGNodeAttributeTextDecorationLine:
            IJSVGParseTextKeywordList(value, parsed, NO);
            break;
        default:
            break;
    }
    return parsed;
}

void IJSVGApplyTextAttributes(IJSVGNode* node, NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength], uint64_t textAttributes)
{
    static NSArray<NSString*>* styleNames;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        styleNames = @[ IJSVGAttributeFont, IJSVGAttributeFontFamily, IJSVGAttributeFontSize, IJSVGAttributeFontWeight, IJSVGAttributeFontStyle, IJSVGAttributeFontStretch, IJSVGAttributeFontVariant, IJSVGAttributeFontVariantLigatures, IJSVGAttributeFontFeatureSettings, IJSVGAttributeFontKerning, IJSVGAttributeLetterSpacing, IJSVGAttributeWordSpacing, IJSVGAttributeTextAnchor, IJSVGAttributeDirection, IJSVGAttributeUnicodeBidi, IJSVGAttributeWritingMode, IJSVGAttributeTextOrientation, IJSVGAttributeDominantBaseline, IJSVGAttributeAlignmentBaseline, IJSVGAttributeBaselineShift, IJSVGAttributeTextDecoration, IJSVGAttributeTextDecorationLine, IJSVGAttributeWhiteSpace, IJSVGAttributeLineHeight, IJSVGAttributeInlineSize, IJSVGAttributeTextTransform, IJSVGAttributeTextOverflow, IJSVGAttributeXMLSpace, IJSVGAttributeLang, IJSVGAttributeXMLLang, IJSVGAttributeFontSizeAdjust ];
    });

    // Expand shorthand only when present and parse longhands directly by
    // attribute.
    NSString* shorthand = IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeFont);
    NSDictionary<NSString*, NSString*>* expanded = nil;
    if (shorthand != nil) {
        expanded = IJSVGStyleSheetExpandDeclaration(IJSVGAttributeFont, shorthand);
    }
    NSMutableDictionary<NSString*, IJSVGTextAttributeValue*>* parsed = nil;
    uint64_t longhands = expanded != nil ? (UINT64_C(1) << styleNames.count) - 1 : textAttributes;
    longhands &= ~(UINT64_C(1) | (UINT64_C(1) << 63));
    while (longhands != 0) {
        NSUInteger index = __builtin_ctzll(longhands);
        longhands &= longhands - 1;
        IJSVGNodeAttribute attribute = IJSVGNodeAttributeFont + index;
        if (attributeValues[attribute] == nil && expanded == nil) {
            continue;
        }
        NSString* name = styleNames[index];
        NSString* value = IJSVGAttributeValue(attributeValues, attribute) ?: expanded[name];
        if (value == nil) {
            continue;
        }
        if (parsed == nil) {
            parsed = [[NSMutableDictionary alloc] init];
        }
        parsed[name] = IJSVGParseTextAttribute(value, attribute);
    }
    NSString* textRendering = IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeTextRendering);
    if (textRendering != nil) {
        if (parsed == nil) {
            parsed = [[NSMutableDictionary alloc] init];
        }
        parsed[IJSVGAttributeTextRendering] = IJSVGParseTextAttribute(textRendering, IJSVGNodeAttributeTextRendering);
    }
    if (parsed != nil) {
        node.textStyle = parsed;
    }
}

void IJSVGReadTextPositionAttribute(NSString* __unsafe_unretained const* values, IJSVGNodeAttribute attribute, NSString* name, NSMutableDictionary<NSString*, IJSVGTextAttributeValue*>* __strong* positioning)
{
    NSString* value = nil;
    if (IJSVGAttributeHasValue(values, attribute, &value)) {
        if (*positioning == nil) {
            *positioning = [[NSMutableDictionary alloc] init];
        }
        (*positioning)[name] = IJSVGParseTextAttribute(value, attribute);
    }
}
