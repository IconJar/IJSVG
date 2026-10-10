//
//  IJSVGParserTextUtils.m
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGParserTextUtils.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGParserUtils.h>
#import <IJSVG/IJSVGUtils.h>
#import <string.h>
#import <IJSVG/IJSVGStyleSheetUtils.h>

static NSString* const IJSVGTextSerifFontFamily = @"Times";
static NSString* const IJSVGTextSansSerifFontFamily = @"Helvetica";
static NSString* const IJSVGTextMonospaceFontFamily = @"Courier";
static NSString* const IJSVGTextCursiveFontFamily = @"Apple Chancery";
static NSString* const IJSVGTextFantasyFontFamily = @"Papyrus";
static NSString* const IJSVGTextSystemFontFamily = @".AppleSystemUIFont";

static void IJSVGParseTextLength(NSString* value,
                                 IJSVGTextAttributeValue* parsed)
{
    IJSVGUnitLength* length = [IJSVGUnitLength unitWithString:value];
    parsed.number = length.value;
    parsed.unitless = length.originalType == IJSVGUnitLengthTypeNumber;
    switch(length.type) {
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
    if(isfinite(parsed.number) == NO) {
        parsed.number = 0;
    }
}

static void IJSVGParseTextPositions(NSString* value,
                                    IJSVGTextAttributeValue* parsed)
{
    NSArray<NSString*>* tokens = [value ijsvg_componentsSeparatedByChars:" ,\t\r\n"];
    NSMutableArray* lengths = [[NSMutableArray alloc] initWithCapacity:tokens.count];
    for(NSString* token in tokens) {
        IJSVGTextAttributeValue* length = IJSVGParseTextAttribute(token,
                                                                  IJSVGNodeAttributeTextLength);
        [lengths addObject:length];
    }
    parsed.lengths = lengths;
}

static void IJSVGParseTextRotations(NSString* value,
                                    IJSVGTextAttributeValue* parsed)
{
    NSArray<NSNumber*>* numbers = [IJSVGUtils numbersFromString:value];
    NSMutableArray* rotations = [[NSMutableArray alloc] initWithCapacity:numbers.count];
    for(NSNumber* number in numbers) {
        IJSVGTextAttributeValue* rotation = [[IJSVGTextAttributeValue alloc] init];
        // Store radians so layout does not convert every rotation again.
        rotation.number = IJSVGDegreesToRadians(number.doubleValue);
        [rotations addObject:rotation];
    }
    parsed.lengths = rotations;
}

static NSString* IJSVGTextResolveGenericFamily(NSString* family)
{
    const char* name = family.UTF8String;
    if(name == NULL || strlen(name) != [family lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return family;
    }
    switch(IJSVGCharToLower(name[0])) {
        case 's':
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "serif") == YES) {
                return IJSVGTextSerifFontFamily;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "sans-serif") == YES) {
                return IJSVGTextSansSerifFontFamily;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "system-ui") == YES) {
                return IJSVGTextSystemFontFamily;
            }
            break;
        case 'm':
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "monospace") == YES) {
                return IJSVGTextMonospaceFontFamily;
            }
            break;
        case 'c':
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "cursive") == YES) {
                return IJSVGTextCursiveFontFamily;
            }
            break;
        case 'f':
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "fantasy") == YES) {
                return IJSVGTextFantasyFontFamily;
            }
            break;
    }
    return family;
}

static void IJSVGParseTextFamilies(NSString* value,
                                   IJSVGTextAttributeValue* parsed)
{
    NSMutableArray<NSString*>* families = [[NSMutableArray alloc] init];
    BOOL valid = IJSVGStyleSheetEnumerateFontFamilies(value, ^(NSString* family, BOOL quoted) {
        NSString* resolvedFamily = quoted ? family : IJSVGTextResolveGenericFamily(family);
        [families addObject:resolvedFamily];
    });
    parsed.families = valid ? families : @[];
}

static void IJSVGParseTextFeatures(NSString* value,
                                   IJSVGTextAttributeValue* parsed)
{
    static NSCharacterSet* quotes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        quotes = [NSCharacterSet characterSetWithCharactersInString:@"'\""];
    });
    NSArray<NSString*>* entries = [value ijsvg_componentsSeparatedByChars:","];
    NSMutableDictionary* features = [[NSMutableDictionary alloc] initWithCapacity:entries.count];
    for(NSString* entry in entries) {
        NSArray<NSString*>* tokens = [entry ijsvg_componentsSplitByWhiteSpace];
        NSString* tag = [tokens.firstObject stringByTrimmingCharactersInSet:quotes];
        if(tag.length == 4) {
            NSString* setting = tokens.count > 1 ? tokens[1] : @"1";
            switch(IJSVGTextKeywordForString(setting)) {
                case IJSVGTextKeywordOn:
                    features[tag] = @1;
                    break;
                case IJSVGTextKeywordOff:
                    features[tag] = @0;
                    break;
                default:
                    features[tag] = @(setting.integerValue);
                    break;
            }
        }
    }
    parsed.features = features;
}

static void IJSVGParseTextLigatures(NSString* value,
                                    IJSVGTextAttributeValue* parsed)
{
    for(NSString* token in [value ijsvg_componentsSplitByWhiteSpace]) {
        if(IJSVGTextKeywordForString(token) == IJSVGTextKeywordNoCommonLigatures) {
            parsed.keyword = IJSVGTextKeywordNoCommonLigatures;
            return;
        }
    }
}

static void IJSVGParseTextDecorations(NSString* value,
                                      IJSVGTextAttributeValue* parsed)
{
    for(NSString* token in [value ijsvg_componentsSplitByWhiteSpace]) {
        switch(IJSVGTextKeywordForString(token)) {
            case IJSVGTextKeywordUnderline:
                parsed.decorations |= IJSVGTextDecorationUnderline;
                break;
            case IJSVGTextKeywordOverline:
                parsed.decorations |= IJSVGTextDecorationOverline;
                break;
            case IJSVGTextKeywordLineThrough:
                parsed.decorations |= IJSVGTextDecorationLineThrough;
                break;
            default:
                break;
        }
    }
}

IJSVGTextAttributeValue* IJSVGParseTextAttribute(NSString* value,
                                                 IJSVGNodeAttribute attribute)
{
    IJSVGTextAttributeValue* parsed = [[IJSVGTextAttributeValue alloc] init];
    parsed.string = value;
    parsed.keyword = IJSVGTextKeywordForString(value);
    parsed.unitless = YES;

    switch(attribute) {
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
            BOOL validKeyword = parsed.keyword == IJSVGTextKeywordNone ||
                parsed.keyword == IJSVGTextKeywordInherit || parsed.keyword == IJSVGTextKeywordInitial ||
                parsed.keyword == IJSVGTextKeywordUnset;
            if((numeric && (end == start || end == NULL || *end != 0 ||
                            !isfinite(parsed.number) || parsed.number < 0.f)) ||
                (!numeric && !validKeyword)) {
                parsed.keyword = IJSVGTextKeywordInherit;
            }
            break;
        }
        case IJSVGNodeAttributeFontWeight:
            parsed.number = value.doubleValue;
            // Keep numeric weights intact for font matching and relative inheritance.
            if(parsed.keyword == IJSVGTextKeywordUnspecified &&
               (!isfinite(parsed.number) || parsed.number < 1 || parsed.number > 1000)) {
                parsed.keyword = IJSVGTextKeywordInherit;
            }
            break;
        case IJSVGNodeAttributeFontVariantLigatures:
            IJSVGParseTextLigatures(value, parsed);
            break;
        case IJSVGNodeAttributeFontFamily:
            IJSVGParseTextFamilies(value, parsed);
            break;

        case IJSVGNodeAttributeFontFeatureSettings:
            IJSVGParseTextFeatures(value, parsed);
            break;

        case IJSVGNodeAttributeTextDecoration:
        case IJSVGNodeAttributeTextDecorationLine:
            IJSVGParseTextDecorations(value, parsed);
            break;
        default:
            break;
    }
    return parsed;
}


void IJSVGApplyTextAttributes(IJSVGNode* node,
                              NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength])
{
    static NSArray<NSString*>* styleNames;
    static NSArray<NSString*>* positionNames;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        styleNames = @[
            IJSVGAttributeFont, IJSVGAttributeFontFamily, IJSVGAttributeFontSize,
            IJSVGAttributeFontWeight, IJSVGAttributeFontStyle, IJSVGAttributeFontStretch,
            IJSVGAttributeFontVariant, IJSVGAttributeFontVariantLigatures,
            IJSVGAttributeFontFeatureSettings, IJSVGAttributeFontKerning,
            IJSVGAttributeLetterSpacing, IJSVGAttributeWordSpacing, IJSVGAttributeTextAnchor,
            IJSVGAttributeDirection, IJSVGAttributeUnicodeBidi, IJSVGAttributeWritingMode,
            IJSVGAttributeTextOrientation, IJSVGAttributeDominantBaseline,
            IJSVGAttributeAlignmentBaseline, IJSVGAttributeBaselineShift,
            IJSVGAttributeTextDecoration, IJSVGAttributeTextDecorationLine,
            IJSVGAttributeWhiteSpace, IJSVGAttributeLineHeight, IJSVGAttributeInlineSize,
            IJSVGAttributeTextTransform, IJSVGAttributeTextOverflow, IJSVGAttributeXMLSpace,
            IJSVGAttributeLang, IJSVGAttributeXMLLang, IJSVGAttributeFontSizeAdjust
        ];
        positionNames = @[
            IJSVGAttributeX, IJSVGAttributeY, IJSVGAttributeDX, IJSVGAttributeDY,
            IJSVGAttributeRotate, IJSVGAttributeTextLength, IJSVGAttributeLengthAdjust,
            IJSVGAttributeStartOffset, IJSVGAttributeMethod, IJSVGAttributeSpacing,
            IJSVGAttributeSide, IJSVGAttributePath, IJSVGAttributePathLength
        ];
    });

    // Expand shorthand only when present and parse longhands directly by attribute.
    NSString* shorthand = IJSVGAttributeValue(attributeValues,
                                              IJSVGNodeAttributeFont);
    NSDictionary<NSString*, NSString*>* expanded = nil;
    if(shorthand != nil) {
        expanded = IJSVGStyleSheetExpandDeclaration(IJSVGAttributeFont, shorthand);
    }
    NSMutableDictionary<NSString*, IJSVGTextAttributeValue*>* parsed = nil;
    for(NSUInteger index = 1; index < styleNames.count; index++) {
        IJSVGNodeAttribute attribute = IJSVGNodeAttributeFont + index;
        NSString* name = styleNames[index];
        NSString* value = IJSVGAttributeValue(attributeValues, attribute) ?: expanded[name];
        if(value == nil) {
            continue;
        }
        if(parsed == nil) {
            parsed = [[NSMutableDictionary alloc] init];
        }
        parsed[name] = IJSVGParseTextAttribute(value, attribute);
    }
    NSString* textRendering = IJSVGAttributeValue(attributeValues,
                                                  IJSVGNodeAttributeTextRendering);
    if(textRendering != nil) {
        if(parsed == nil) {
            parsed = [[NSMutableDictionary alloc] init];
        }
        parsed[IJSVGAttributeTextRendering] = IJSVGParseTextAttribute(textRendering,
                                                                      IJSVGNodeAttributeTextRendering);
    }
    if(parsed != nil) {
        node.textStyle = parsed;
    }

    if([node isKindOfClass:IJSVGText.class] == NO) {
        return;
    }

    static const IJSVGNodeAttribute positionAttributes[] = {
      IJSVGNodeAttributeX, IJSVGNodeAttributeY, IJSVGNodeAttributeDX,
      IJSVGNodeAttributeDY, IJSVGNodeAttributeRotate, IJSVGNodeAttributeTextLength,
      IJSVGNodeAttributeLengthAdjust, IJSVGNodeAttributeStartOffset,
      IJSVGNodeAttributeMethod, IJSVGNodeAttributeSpacing, IJSVGNodeAttributeSide,
      IJSVGNodeAttributePath, IJSVGNodeAttributePathLength
    };
  
    NSMutableDictionary<NSString*, IJSVGTextAttributeValue*>* positioning = nil;
    for(NSUInteger index = 0; index < positionNames.count; index++) {
        NSString* value = nil;
        if(IJSVGAttributeHasValue(attributeValues, positionAttributes[index], &value)) {
            if(positioning == nil) {
                positioning = [[NSMutableDictionary alloc] init];
            }
            positioning[positionNames[index]] = IJSVGParseTextAttribute(value, positionAttributes[index]);
        }
    }
    ((IJSVGText*)node).positioning = positioning ?: @{};
}
