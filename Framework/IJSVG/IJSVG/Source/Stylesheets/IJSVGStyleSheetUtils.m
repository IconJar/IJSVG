//
//  IJSVGStyleSheetUtils.m
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGCommandParser.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGRendering.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGCSSParser.h>
#import <IJSVGCSSVariables.h>
#import <IJSVGParserUtils.h>
#import <IJSVGStyleSheetUtils.h>
#import <math.h>

IJSVGSelectorPseudoDescriptor IJSVGSelectorPseudoForBytes(const char* bytes, NSUInteger length)
{
    if (bytes == NULL || length == 0 || length > 16) {
        return (IJSVGSelectorPseudoDescriptor) { 0 };
    }
    char name[16];
    for (NSUInteger index = 0; index < length; index++) {
        unsigned char character = bytes[index];
        name[index] = character >= 'A' && character <= 'Z' ? character + ('a' - 'A') : character;
    }
    bytes = name;
    switch (length) {
        case 2:
            if (memcmp(bytes, "is", 2) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoIs, IJSVGSelectorPseudoFunctional | IJSVGSelectorPseudoForgiving, YES };
            }
            break;
        case 3:
            if (memcmp(bytes, "not", 3) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoNot, IJSVGSelectorPseudoFunctional, YES };
            }
            if (memcmp(bytes, "has", 3) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoHas, IJSVGSelectorPseudoFunctional, YES };
            }
            break;
        case 4:
            if (memcmp(bytes, "lang", 4) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoLang, IJSVGSelectorPseudoFunctional, YES };
            }
            if (memcmp(bytes, "root", 4) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoRoot, 0, YES };
            }
            break;
        case 5:
            if (memcmp(bytes, "scope", 5) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoScope, 0, YES };
            }
            if (memcmp(bytes, "empty", 5) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoEmpty, 0, YES };
            }
            if (memcmp(bytes, "where", 5) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoWhere, IJSVGSelectorPseudoFunctional | IJSVGSelectorPseudoForgiving, YES };
            }
            break;
        case 9:
            if (memcmp(bytes, "nth-child", 9) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoNth, IJSVGSelectorPseudoFunctional, YES };
            }
            break;
        case 10:
            if (memcmp(bytes, "last-child", 10) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoNth, IJSVGSelectorPseudoFromEnd, YES };
            }
            if (memcmp(bytes, "only-child", 10) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoNth, IJSVGSelectorPseudoOnly, YES };
            }
            break;
        case 11:
            if (memcmp(bytes, "first-child", 11) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoNth, 0, YES };
            }
            if (memcmp(bytes, "nth-of-type", 11) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoNth, IJSVGSelectorPseudoFunctional | IJSVGSelectorPseudoOfType, YES };
            }
            break;
        case 12:
            if (memcmp(bytes, "last-of-type", 12) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoNth, IJSVGSelectorPseudoOfType | IJSVGSelectorPseudoFromEnd, YES };
            }
            if (memcmp(bytes, "only-of-type", 12) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoNth, IJSVGSelectorPseudoOfType | IJSVGSelectorPseudoOnly, YES };
            }
            break;
        case 13:
            if (memcmp(bytes, "first-of-type", 13) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoNth, IJSVGSelectorPseudoOfType, YES };
            }
            break;
        case 14:
            if (memcmp(bytes, "nth-last-child", 14) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoNth, IJSVGSelectorPseudoFunctional | IJSVGSelectorPseudoFromEnd, YES };
            }
            break;
        case 16:
            if (memcmp(bytes, "nth-last-of-type", 16) == 0) {
                return (IJSVGSelectorPseudoDescriptor) { IJSVGSelectorPseudoNth, IJSVGSelectorPseudoFunctional | IJSVGSelectorPseudoOfType | IJSVGSelectorPseudoFromEnd, YES };
            }
            break;
        default:
            break;
    }
    return (IJSVGSelectorPseudoDescriptor) { 0 };
}

BOOL IJSVGStyleSheetCharIsWhitespace(char aChar)
{
    return aChar == ' ' || aChar == '\t' || aChar == '\n' || aChar == '\r' || aChar == '\f';
}

typedef NS_ENUM(uint8_t, IJSVGMediaFeature) {
    IJSVGMediaFeatureType,
    IJSVGMediaFeatureWidth,
    IJSVGMediaFeatureHeight,
    IJSVGMediaFeaturePortrait,
    IJSVGMediaFeatureLandscape
};

typedef struct {
    IJSVGMediaFeature feature;
    double value;
    int comparison;
    BOOL equal;
    BOOL valid;
    BOOL negate;
    NSUInteger count;
} IJSVGMediaCondition;

// Each clause stores its media type followed by its feature conditions.
struct IJSVGMediaQuery {
    NSUInteger count;
    IJSVGMediaCondition conditions[];
};

static void IJSVGMediaSkipWhitespace(const char** cursor)
{
    while (IJSVGStyleSheetCharIsWhitespace(**cursor)) {
        (*cursor)++;
    }
}

static BOOL IJSVGMediaConsume(const char** cursor, const char* token)
{
    size_t length = strlen(token);
    if (strncmp(*cursor, token, length) != 0) {
        return NO;
    }
    char next = (*cursor)[length];
    if ((token[length - 1] >= 'a' && token[length - 1] <= 'z') && ((next >= 'a' && next <= 'z') || next == '-')) {
        return NO;
    }
    *cursor += length;
    IJSVGMediaSkipWhitespace(cursor);
    return YES;
}

static BOOL IJSVGMediaParseFeature(const char** cursor, IJSVGMediaCondition* condition, BOOL* valid)
{
    IJSVGMediaSkipWhitespace(cursor);
    BOOL minimum = IJSVGMediaConsume(cursor, "min-");
    BOOL maximum = !minimum && IJSVGMediaConsume(cursor, "max-");
    if (IJSVGMediaConsume(cursor, "width")) {
        condition->feature = IJSVGMediaFeatureWidth;
    } else if (IJSVGMediaConsume(cursor, "height")) {
        condition->feature = IJSVGMediaFeatureHeight;
    } else if (!minimum && !maximum && IJSVGMediaConsume(cursor, "orientation") && IJSVGMediaConsume(cursor, ":")) {
        BOOL portrait = IJSVGMediaConsume(cursor, "portrait");
        BOOL landscape = !portrait && IJSVGMediaConsume(cursor, "landscape");
        *valid = (portrait || landscape) && IJSVGMediaConsume(cursor, ")");
        condition->feature = portrait ? IJSVGMediaFeaturePortrait : IJSVGMediaFeatureLandscape;
        return *valid;
    } else {
        *valid = NO;
        return NO;
    }
    if (!minimum && !maximum && IJSVGMediaConsume(cursor, ")")) {
        condition->comparison = 1;
        return YES;
    }
    int comparison = minimum ? 1 : (maximum ? -1 : 0);
    BOOL equal = YES;
    if (!IJSVGMediaConsume(cursor, ":")) {
        if (minimum || maximum) {
            *valid = NO;
            return NO;
        }
        char operation = **cursor;
        if (operation != '<' && operation != '>' && operation != '=') {
            *valid = NO;
            return NO;
        }
        (*cursor)++;
        comparison = operation == '<' ? -1 : (operation == '>' ? 1 : 0);
        equal = operation == '=' || **cursor == '=';
        if (operation != '=' && **cursor == '=') {
            (*cursor)++;
        }
        IJSVGMediaSkipWhitespace(cursor);
    }
    CGFloat expected;
    if (!IJSVGParseLengthNumber(cursor, NO, &expected)) {
        *valid = NO;
        return NO;
    }
    char suffix[4] = { 0 };
    NSUInteger length = 0;
    while (**cursor != '\0' && **cursor != ')' && !IJSVGStyleSheetCharIsWhitespace(**cursor)) {
        if (length == sizeof(suffix) - 1) {
            *valid = NO;
            return NO;
        }
        suffix[length++] = *(*cursor)++;
    }
    IJSVGUnitLengthType type = IJSVGUnitLengthTypeForCString(suffix);
    if ((length == 0 && expected != 0) || (length != 0 && type == IJSVGUnitLengthTypeNumber) || (length == 3 && strcmp(suffix, "rem") != 0) || type == IJSVGUnitLengthTypePercentage || type == IJSVGUnitLengthTypeEX) {
        *valid = NO;
        return NO;
    }
    expected = [IJSVGUnitLength convertUnitValue:expected toBaseFromUnitLengthType:type];
    if (type == IJSVGUnitLengthTypeEM) {
        expected *= IJSVGDefaultFontSize;
    }
    if (!isfinite(expected)) {
        *valid = NO;
        return NO;
    }
    IJSVGMediaSkipWhitespace(cursor);
    *valid = IJSVGMediaConsume(cursor, ")");
    condition->value = expected;
    condition->comparison = comparison;
    condition->equal = equal;
    return *valid;
}

static IJSVGMediaQuery* IJSVGMediaQueryCreateNormalized(const char* cursor)
{
    NSUInteger capacity = 1;
    for (const char* character = cursor; *character != '\0'; character++) {
        if (*character == '(' || *character == ',') {
            capacity++;
        }
    }
    IJSVGMediaQuery* query = calloc(1, sizeof(IJSVGMediaQuery) + capacity * sizeof(IJSVGMediaCondition));
    if (query == NULL) {
        return NULL;
    }
    IJSVGMediaSkipWhitespace(&cursor);
    do {
        IJSVGMediaCondition* clause = &query->conditions[query->count++];
        clause->feature = IJSVGMediaFeatureType;
        clause->count = 1;
        clause->valid = YES;
        clause->negate = IJSVGMediaConsume(&cursor, "not");
        BOOL only = !clause->negate && IJSVGMediaConsume(&cursor, "only");
        if (*cursor != '(') {
            if (IJSVGMediaConsume(&cursor, "all")) {
                clause->value = IJSVGMediaTypeAll;
            } else if (IJSVGMediaConsume(&cursor, "screen")) {
                clause->value = IJSVGMediaTypeScreen;
            } else if (IJSVGMediaConsume(&cursor, "print")) {
                clause->value = IJSVGMediaTypePrint;
            } else if (*cursor != '\0' || clause->negate || only || query->count != 1) {
                clause->valid = NO;
            }
            if (clause->valid && *cursor != ',' && *cursor != '\0') {
                clause->valid = IJSVGMediaConsume(&cursor, "and") && *cursor == '(';
            }
        } else if (only) {
            clause->valid = NO;
        }
        while (clause->valid && *cursor == '(') {
            cursor++;
            IJSVGMediaCondition* condition = &query->conditions[query->count++];
            clause->count++;
            IJSVGMediaParseFeature(&cursor, condition, &clause->valid);
            if (clause->valid && *cursor != ',' && *cursor != '\0') {
                clause->valid = IJSVGMediaConsume(&cursor, "and") && *cursor == '(';
            }
        }
        clause->valid = clause->valid && (*cursor == ',' || *cursor == '\0');
        while (*cursor != '\0' && *cursor != ',') {
            cursor++;
        }
        if (*cursor == '\0') {
            break;
        }
        cursor++;
        IJSVGMediaSkipWhitespace(&cursor);
    } while (YES);
    return query;
}

IJSVGMediaQuery* IJSVGMediaQueryCreateFromCleanBytes(const char* bytes, NSUInteger length)
{
    if (length == NSUIntegerMax || memchr(bytes, '\0', length) != NULL) {
        return NULL;
    }
    // The existing numeric/token readers require a terminator. Keep common
    // queries on the stack and normalize ASCII without allocating NSStrings.
    char storage[512];
    char* normalized = length < sizeof(storage) ? storage : malloc(length + 1);
    if (normalized == NULL) {
        return NULL;
    }
    for (NSUInteger index = 0; index < length; index++) {
        normalized[index] = IJSVGCharToLower(bytes[index]);
    }
    normalized[length] = '\0';
    IJSVGMediaQuery* query = IJSVGMediaQueryCreateNormalized(normalized);
    if (normalized != storage) {
        free(normalized);
    }
    return query;
}

IJSVGMediaQuery* IJSVGMediaQueryCreate(NSString* media)
{
    NSString* clean = IJSVGStyleSheetStringByRemovingCSSComments(media ?: @"");
    const char* bytes = clean.UTF8String;
    return bytes == NULL ? NULL : IJSVGMediaQueryCreateFromCleanBytes(bytes, [clean lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

void IJSVGMediaQueryRelease(IJSVGMediaQuery* query)
{
    free(query);
}

BOOL IJSVGMediaQueryMatches(const IJSVGMediaQuery* query, IJSVGMediaEnvironment environment)
{
    if (query == NULL) {
        return NO;
    }
    for (NSUInteger index = 0; index < query->count;) {
        const IJSVGMediaCondition* clause = &query->conditions[index];
        BOOL matches = clause->value == IJSVGMediaTypeAll || clause->value == environment.type;
        for (NSUInteger offset = 1; clause->valid && offset < clause->count; offset++) {
            const IJSVGMediaCondition* condition = &query->conditions[index + offset];
            CGFloat actual = condition->feature == IJSVGMediaFeatureWidth ? environment.viewport.width : environment.viewport.height;
            BOOL feature;
            if (condition->feature == IJSVGMediaFeaturePortrait) {
                feature = environment.viewport.height >= environment.viewport.width;
            } else if (condition->feature == IJSVGMediaFeatureLandscape) {
                feature = environment.viewport.width > environment.viewport.height;
            } else {
                feature = (condition->equal && actual == condition->value) || (condition->comparison < 0 && actual < condition->value) || (condition->comparison > 0 && actual > condition->value);
            }
            matches = matches && feature;
        }
        if (clause->valid && (clause->negate ? !matches : matches)) {
            return YES;
        }
        index += clause->count;
    }
    return NO;
}

BOOL IJSVGStyleSheetCharIsCombinator(char aChar)
{
    return aChar == '>' || aChar == '+' || aChar == '~';
}

BOOL IJSVGStyleSheetCharEndsIdentifier(char aChar)
{
    return aChar == ':' || aChar == '#' || aChar == '.' || aChar == '*' || aChar == '|' || IJSVGStyleSheetCharIsCombinator(aChar) || IJSVGStyleSheetCharIsWhitespace(aChar);
}

BOOL IJSVGStyleSheetCharIsInvalidSelectorChar(char aChar)
{
    return aChar == '@' || aChar == ':' || aChar == ';' || aChar == '(' || aChar == ')' || aChar == '[' || aChar == ']';
}

BOOL IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(const char* chars, NSUInteger index, NSUInteger length)
{
    return chars != NULL && index + 1 < length && chars[index] == '|' && chars[index + 1] == '|';
}

NSUInteger IJSVGStyleSheetIndexBySkippingWhitespace(const char* chars, NSUInteger index, NSUInteger length)
{
    while (index < length && IJSVGStyleSheetCharIsWhitespace(chars[index])) {
        index++;
    }
    return index;
}

IJSVGStyleSheetSelectorCombinator IJSVGStyleSheetCombinatorForChar(char aChar)
{
    switch (aChar) {
        case '+': {
            return IJSVGStyleSheetSelectorCombinatorNextSibling;
        }
        case '~': {
            return IJSVGStyleSheetSelectorCombinatorPrecededSibling;
        }
        case '|': {
            return IJSVGStyleSheetSelectorCombinatorColumn;
        }
        case '>':
        default: {
            return IJSVGStyleSheetSelectorCombinatorDirectDescendant;
        }
    }
}

NSString* IJSVGStyleSheetCombinatorStringForCombinator(IJSVGStyleSheetSelectorCombinator combinator)
{
    switch (combinator) {
        case IJSVGStyleSheetSelectorCombinatorDirectDescendant: {
            return @">";
        }
        case IJSVGStyleSheetSelectorCombinatorNextSibling: {
            return @"+";
        }
        case IJSVGStyleSheetSelectorCombinatorPrecededSibling: {
            return @"~";
        }
        case IJSVGStyleSheetSelectorCombinatorColumn: {
            return @"||";
        }
        case IJSVGStyleSheetSelectorCombinatorWildcard:
        case IJSVGStyleSheetSelectorCombinatorDescendant:
        default: {
            return @" ";
        }
    }
}

NSString* IJSVGStyleSheetStringFromUTF8Bytes(const char* chars, NSUInteger start, NSUInteger end)
{
    if (chars == NULL || end <= start) {
        return nil;
    }
    return [[NSString alloc] initWithBytes:chars + start length:end - start encoding:NSUTF8StringEncoding];
}

BOOL IJSVGStyleSheetConsumeQuotedCharacter(char c, char* quote, BOOL* escaped)
{
    if (*escaped) {
        *escaped = NO;
        return YES;
    }
    if (c == '\\') {
        *escaped = YES;
        return YES;
    }
    if (*quote != 0) {
        if (c == *quote || c == '\n' || c == '\r' || c == '\f') {
            *quote = 0;
        }
        return YES;
    }
    if (c == '\'' || c == '"') {
        *quote = c;
        return YES;
    }
    return NO;
}

static NSRange IJSVGStyleSheetTrimRange(const char* chars, NSUInteger start, NSUInteger end)
{
    start = IJSVGStyleSheetIndexBySkippingWhitespace(chars, start, end);
    while (end > start && IJSVGStyleSheetCharIsWhitespace(chars[end - 1])) {
        end--;
    }
    return NSMakeRange(start, end - start);
}

static NSString* IJSVGStyleSheetTrimmedDeclaration(NSString* value, const char* chars, NSRange range, NSUInteger length)
{
    if (range.length == 0) {
        return nil;
    }
    if (range.location == 0 && range.length == length) {
        return [value copy];
    }
    return IJSVGStyleSheetStringFromUTF8Bytes(chars, range.location, NSMaxRange(range));
}

NSRange IJSVGStyleSheetDeclarationRange(const char* chars, NSUInteger length, BOOL* important)
{
    *important = NO;
    NSRange range = IJSVGStyleSheetTrimRange(chars, 0, length);
    NSUInteger end = NSMaxRange(range);
    if (range.length < 10) {
        return range;
    }
    NSUInteger word = end - 9;
    const char* keyword = "important";
    for (NSUInteger index = 0; index < 9; index++) {
        if (IJSVGCharToLower(chars[word + index]) != keyword[index]) {
            return range;
        }
    }
    NSUInteger marker = word;
    while (marker > range.location && IJSVGStyleSheetCharIsWhitespace(chars[marker - 1])) {
        marker--;
    }
    if (marker == range.location || chars[marker - 1] != '!') {
        return range;
    }
    marker--;
    char quote = 0;
    BOOL escaped = NO;
    NSUInteger depth = 0;
    for (NSUInteger index = range.location; index <= marker; index++) {
        char c = chars[index];
        if (IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
            if (index == marker) {
                return range;
            }
            continue;
        }
        if (c == '(' || c == '[' || c == '{') {
            depth++;
        } else if ((c == ')' || c == ']' || c == '}') && depth != 0) {
            depth--;
        }
    }
    if (depth == 0) {
        *important = YES;
        range = IJSVGStyleSheetTrimRange(chars, range.location, marker);
    }
    return range;
}

NSString* IJSVGStyleSheetDeclarationValue(NSString* value, BOOL* important)
{
    *important = NO;
    IJSVGStringBytes source = IJSVGStringGetBytes(value);
    if (source.bytes == NULL || memchr(source.bytes, 0, source.length) != NULL) {
        return nil;
    }
    NSRange range = IJSVGStyleSheetDeclarationRange(source.bytes, source.length, important);
    return IJSVGStyleSheetTrimmedDeclaration(value, source.bytes, range, source.length);
}

static BOOL IJSVGStyleSheetSkipIdentifier(const char* chars, NSUInteger length, NSUInteger* index);

NSString* IJSVGStyleSheetStringByRemovingCSSComments(NSString* string)
{
    const char* chars = string.UTF8String;
    if (chars == NULL) {
        return string;
    }

    NSUInteger length = strlen(chars);
    if (length != [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return nil;
    }
    if (length == 0) {
        return string;
    }

    if (strstr(chars, "/*") == NULL) {
        return [string copy];
    }

    char* clean = malloc(length);
    if (clean == NULL) {
        return nil;
    }
    NSUInteger written = 0;
    NSUInteger marker = 0;
    NSUInteger depth = 0;
    NSUInteger mathDepth = 0;
    BOOL customValue = NO;
    char quote = 0;
    BOOL escaped = NO;
    for (NSUInteger i = 0; i < length; i++) {
        if (mathDepth != 0 && quote == 0 && !escaped) {
            i += strcspn(chars + i, "()/'\"\\");
            if (i == length) {
                break;
            }
        }
        char c = chars[i];

        if (IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
            continue;
        }

        // Keep comments inside calculations until tokenization: deleting them
        // would merge tokens (1/**/px) or change binary operator whitespace.
        NSUInteger identifierEnd = i;
        if (IJSVGStyleSheetSkipIdentifier(chars, length, &identifierEnd)) {
            if (chars[i] == '-' && i + 1 < identifierEnd && chars[i + 1] == '-') {
                NSUInteger colon = IJSVGStyleSheetIndexBySkippingWhitespace(chars, identifierEnd, length);
                if (colon < length && chars[colon] == ':') {
                    customValue = YES;
                }
            }
            if (identifierEnd < length && chars[identifierEnd] == '(' && mathDepth == 0) {
                NSUInteger nameLength = identifierEnd - i;
                IJSVGCSSFunction function = IJSVGCSSFunctionUnknown;
                if (memchr(chars + i, '\\', nameLength) != NULL) {
                    NSUInteger cursor = i;
                    char name[6] = { 0 };
                    IJSVGStyleSheetConsumeASCIIIdentifier(chars, length, &cursor, name, sizeof(name));
                    function = IJSVGCSSFunctionForName(name);
                } else if (nameLength <= 5) {
                    char name[6];
                    memcpy(name, chars + i, nameLength);
                    name[nameLength] = '\0';
                    function = IJSVGCSSFunctionForName(name);
                }
                if (IJSVGCSSFunctionIsCalculation(function) || function == IJSVGCSSFunctionVar) {
                    mathDepth = depth + 1;
                }
            }
            i = identifierEnd - 1;
            continue;
        }
        if (c == '(') {
            depth++;
        } else if (c == ')' && depth != 0) {
            if (mathDepth == depth) {
                mathDepth = 0;
            }
            depth--;
        }
        if (depth == 0 && (c == ';' || c == '}')) {
            customValue = NO;
        }
        if (c == '/' && i + 1 < length && chars[i + 1] == '*') {
            memcpy(clean + written, chars + marker, i - marker);
            written += i - marker;
            const char* end = strstr(chars + i + 2, "*/");
            if (mathDepth != 0 || customValue) {
                NSUInteger boundaryLength = end == NULL ? 2 : 4;
                memcpy(clean + written, "/**/", boundaryLength);
                written += boundaryLength;
            }
            if (end == NULL) {
                marker = length;
                break;
            }
            i = (NSUInteger)(end - chars) + 1;
            marker = i + 1;
        }
    }

    memcpy(clean + written, chars + marker, length - marker);
    written += length - marker;
    return [[NSString alloc] initWithBytesNoCopy:clean length:written encoding:NSUTF8StringEncoding freeWhenDone:YES];
}

BOOL IJSVGStyleSheetSelectorRawHasSimpleSelector(IJSVGStyleSheetSelectorRaw* rawSelector)
{
    return rawSelector.pseudoClasses.count != 0 || rawSelector.rootCount != 0 || rawSelector.tag != nil || rawSelector.identifier != nil || rawSelector.classes.count != 0;
}

BOOL IJSVGStyleSheetSelectorRawHasAnySelector(IJSVGStyleSheetSelectorRaw* rawSelector, BOOL hasUniversalSelector)
{
    return hasUniversalSelector == YES || IJSVGStyleSheetSelectorRawHasSimpleSelector(rawSelector) == YES;
}

BOOL IJSVGStyleSheetSelectorCommitRawSelector(NSMutableArray<IJSVGStyleSheetSelectorRaw*>* parsedSelectors, IJSVGStyleSheetSelectorRaw* rawSelector, BOOL hasUniversalSelector)
{
    if (IJSVGStyleSheetSelectorRawHasAnySelector(rawSelector, hasUniversalSelector) == NO) {
        return NO;
    }
    [parsedSelectors addObject:rawSelector];
    return YES;
}

IJSVGStyleSheetSelectorRaw* IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinator combinator)
{
    IJSVGStyleSheetSelectorRaw* rawSelector = [[IJSVGStyleSheetSelectorRaw alloc] init];
    rawSelector.combinator = combinator;
    return rawSelector;
}

typedef NS_ENUM(NSUInteger, IJSVGStyleSheetFontProperty) {
    IJSVGStyleSheetFontFamily,
    IJSVGStyleSheetFontSize,
    IJSVGStyleSheetFontStyle,
    IJSVGStyleSheetFontWeight,
    IJSVGStyleSheetFontStretch,
    IJSVGStyleSheetFontVariant,
    IJSVGStyleSheetFontLineHeight,
    IJSVGStyleSheetFontLigatures,
    IJSVGStyleSheetFontFeatures,
    IJSVGStyleSheetFontKerning,
    IJSVGStyleSheetFontSizeAdjust,
    IJSVGStyleSheetFontPropertyCount
};

static BOOL IJSVGStyleSheetTokenEquals(const char* chars, NSRange token, const char* keyword)
{
    if (token.length != strlen(keyword)) {
        return NO;
    }
    for (NSUInteger index = 0; index < token.length; index++) {
        if (IJSVGCharToLower(chars[token.location + index]) != keyword[index]) {
            return NO;
        }
    }
    return YES;
}

static NSRange IJSVGStyleSheetNextFontToken(const char* chars, NSUInteger length, NSUInteger* index)
{
    NSUInteger start = IJSVGStyleSheetIndexBySkippingWhitespace(chars, *index, length);
    *index = start;
    while (*index < length && chars[*index] != '/' && !IJSVGStyleSheetCharIsWhitespace(chars[*index])) {
        (*index)++;
    }
    return NSMakeRange(start, *index - start);
}

static NSUInteger IJSVGStyleSheetSkipDigits(const char* chars, NSUInteger index, NSUInteger end)
{
    while (index < end && chars[index] >= '0' && chars[index] <= '9') {
        index++;
    }
    return index;
}

static NSUInteger IJSVGStyleSheetSkipExponent(const char* chars, NSUInteger index, NSUInteger end)
{
    // An e starts an exponent only when followed by digits, not an em/ex unit.
    if (index == end || IJSVGCharToLower(chars[index]) != 'e') {
        return index;
    }
    NSUInteger digits = index + 1;
    if (digits < end && (chars[digits] == '+' || chars[digits] == '-')) {
        digits++;
    }
    NSUInteger exponentEnd = IJSVGStyleSheetSkipDigits(chars, digits, end);
    return exponentEnd != digits ? exponentEnd : index;
}

static BOOL IJSVGStyleSheetFontUnitIsValid(char* chars, NSUInteger index, NSUInteger end)
{
    // The unit helper checks suffixes, so reject extra bytes first.
    NSUInteger length = end - index;
    if (length == 1 ? chars[index] != '%' : (length != 2 || chars[end - 1] == '%')) {
        return NO;
    }
    char saved = chars[end];
    chars[end] = '\0';
    IJSVGUnitLengthType type = IJSVGUnitLengthTypeForCString(chars + index);
    chars[end] = saved;
    return type != IJSVGUnitLengthTypeNumber;
}

static BOOL IJSVGStyleSheetFontNumber(char* chars, NSRange token, CGFloat* value, BOOL* unitless)
{
    NSUInteger index = token.location;
    NSUInteger end = NSMaxRange(token);
    if (index < end && chars[index] == '+') {
        index++;
    }
    NSUInteger digits = index;
    index = IJSVGStyleSheetSkipDigits(chars, index, end);
    BOOL hasDigits = index != digits;
    if (index < end && chars[index] == '.') {
        digits = ++index;
        index = IJSVGStyleSheetSkipDigits(chars, index, end);
        if (index == digits) {
            return NO;
        }
        hasDigits = YES;
    }
    if (!hasDigits) {
        return NO;
    }
    index = IJSVGStyleSheetSkipExponent(chars, index, end);
    *unitless = index == end;
    if (!*unitless && !IJSVGStyleSheetFontUnitIsValid(chars, index, end)) {
        return NO;
    }
    char saved = chars[index];
    chars[index] = '\0';
    *value = IJSVGParseFloat(chars + token.location);
    chars[index] = saved;
    return isfinite(*value);
}

static NSUInteger IJSVGStyleSheetFontKeywordProperty(char* chars, NSRange token)
{
    static const struct {
        const char* keyword;
        IJSVGStyleSheetFontProperty property;
    } keywords[] = { { "xx-small", IJSVGStyleSheetFontSize }, { "x-small", IJSVGStyleSheetFontSize }, { "small", IJSVGStyleSheetFontSize }, { "medium", IJSVGStyleSheetFontSize }, { "large", IJSVGStyleSheetFontSize }, { "x-large", IJSVGStyleSheetFontSize }, { "xx-large", IJSVGStyleSheetFontSize }, { "smaller", IJSVGStyleSheetFontSize }, { "larger", IJSVGStyleSheetFontSize }, { "italic", IJSVGStyleSheetFontStyle }, { "oblique", IJSVGStyleSheetFontStyle }, { "bold", IJSVGStyleSheetFontWeight }, { "bolder", IJSVGStyleSheetFontWeight }, { "lighter", IJSVGStyleSheetFontWeight }, { "small-caps", IJSVGStyleSheetFontVariant }, { "ultra-condensed", IJSVGStyleSheetFontStretch }, { "extra-condensed", IJSVGStyleSheetFontStretch }, { "condensed", IJSVGStyleSheetFontStretch }, { "semi-condensed", IJSVGStyleSheetFontStretch }, { "semi-expanded", IJSVGStyleSheetFontStretch }, { "expanded", IJSVGStyleSheetFontStretch }, { "extra-expanded", IJSVGStyleSheetFontStretch }, { "ultra-expanded", IJSVGStyleSheetFontStretch } };

    for (NSUInteger index = 0; index < sizeof(keywords) / sizeof(keywords[0]); index++) {
        if (IJSVGStyleSheetTokenEquals(chars, token, keywords[index].keyword)) {
            return keywords[index].property;
        }
    }
    return NSNotFound;
}

BOOL IJSVGStyleSheetSkipEscape(const char* chars, NSUInteger length, NSUInteger* index, BOOL quoted)
{
    if (++*index == length) {
        return NO;
    }
    char c = chars[*index];
    if (c == '\n' || c == '\r' || c == '\f') {
        if (!quoted) {
            return NO;
        }
        (*index)++;
        if (c == '\r' && *index < length && chars[*index] == '\n') {
            (*index)++;
        }
        return YES;
    }
    NSUInteger digits = 0;
    while (*index < length && digits < 6) {
        c = IJSVGCharToLower(chars[*index]);
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) {
            break;
        }
        (*index)++;
        digits++;
    }
    if (digits == 0) {
        (*index)++;
    } else if (*index < length && IJSVGStyleSheetCharIsWhitespace(chars[*index])) {
        c = chars[(*index)++];
        if (c == '\r' && *index < length && chars[*index] == '\n') {
            (*index)++;
        }
    }
    return YES;
}

static BOOL IJSVGStyleSheetNameStart(char c)
{
    char lower = IJSVGCharToLower(c);
    return (lower >= 'a' && lower <= 'z') || c == '_' || (unsigned char)c >= 0x80;
}

BOOL IJSVGStyleSheetSkipQuotedString(const char* chars, NSUInteger length, NSUInteger* index)
{
    char quote = chars[(*index)++];
    while (*index < length) {
        char c = chars[*index];
        if (c == '\\') {
            if (!IJSVGStyleSheetSkipEscape(chars, length, index, YES)) {
                return NO;
            }
        } else if (c == quote) {
            (*index)++;
            return YES;
        } else if (c == '\n' || c == '\r' || c == '\f') {
            return NO;
        } else {
            (*index)++;
        }
    }
    return NO;
}

static BOOL IJSVGStyleSheetFontFamilyIsReserved(const char* chars, NSRange name)
{
    return IJSVGStyleSheetTokenEquals(chars, name, "inherit") || IJSVGStyleSheetTokenEquals(chars, name, "initial") || IJSVGStyleSheetTokenEquals(chars, name, "unset") || IJSVGStyleSheetTokenEquals(chars, name, "default") || IJSVGStyleSheetTokenEquals(chars, name, "revert") || IJSVGStyleSheetTokenEquals(chars, name, "revert-layer");
}

static BOOL IJSVGStyleSheetSkipIdentifier(const char* chars, NSUInteger length, NSUInteger* index)
{
    if (*index >= length) {
        return NO;
    }
    if (chars[*index] == '-') {
        (*index)++;
    }
    if (*index == length || (!IJSVGStyleSheetNameStart(chars[*index]) && chars[*index] != '\\' && chars[*index] != '-')) {
        return NO;
    }
    while (*index < length) {
        char c = chars[*index];
        if (c == '\\') {
            if (!IJSVGStyleSheetSkipEscape(chars, length, index, NO)) {
                return NO;
            }
        } else if (IJSVGStyleSheetNameStart(c) || c == '-' || (c >= '0' && c <= '9')) {
            (*index)++;
        } else {
            break;
        }
    }
    return YES;
}

static BOOL IJSVGStyleSheetSkipFamilyIdentifier(const char* chars, NSUInteger length, NSUInteger* index)
{
    NSUInteger start = *index;
    return IJSVGStyleSheetSkipIdentifier(chars, length, index) && !IJSVGStyleSheetFontFamilyIsReserved(chars, NSMakeRange(start, *index - start));
}

static BOOL IJSVGStyleSheetSkipUnquotedFamily(const char* chars, NSUInteger length, NSUInteger* index)
{
    while (*index < length) {
        if (!IJSVGStyleSheetSkipFamilyIdentifier(chars, length, index)) {
            return NO;
        }
        NSUInteger end = *index;
        *index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, *index, length);
        if (*index == length || chars[*index] == ',') {
            return YES;
        }
        if (*index == end) {
            return NO;
        }
    }
    return NO;
}

static void IJSVGStyleSheetAppendCodePoint(NSMutableData* data, uint32_t scalar)
{
    if (scalar == 0 || scalar > 0x10FFFF || (scalar >= 0xD800 && scalar <= 0xDFFF)) {
        scalar = u'�';
    }
    uint8_t bytes[4];
    NSUInteger count;
    if (scalar < 0x80) {
        bytes[0] = scalar;
        count = 1;
    } else if (scalar < 0x800) {
        bytes[0] = 0xC0 | (scalar >> 6);
        bytes[1] = 0x80 | (scalar & 0x3F);
        count = 2;
    } else if (scalar < 0x10000) {
        bytes[0] = 0xE0 | (scalar >> 12);
        bytes[1] = 0x80 | ((scalar >> 6) & 0x3F);
        bytes[2] = 0x80 | (scalar & 0x3F);
        count = 3;
    } else {
        bytes[0] = 0xF0 | (scalar >> 18);
        bytes[1] = 0x80 | ((scalar >> 12) & 0x3F);
        bytes[2] = 0x80 | ((scalar >> 6) & 0x3F);
        bytes[3] = 0x80 | (scalar & 0x3F);
        count = 4;
    }
    [data appendBytes:bytes length:count];
}

static uint32_t IJSVGStyleSheetReadHexEscape(const char* chars, NSUInteger end, NSUInteger* index)
{
    uint32_t scalar = 0;
    for (NSUInteger digits = 0; *index < end && digits < 6; digits++) {
        char c = IJSVGCharToLower(chars[*index]);
        int digit = c >= '0' && c <= '9' ? c - '0' : (c >= 'a' && c <= 'f' ? c - 'a' + 10 : -1);
        if (digit < 0) {
            break;
        }
        scalar = scalar * 16 + digit;
        (*index)++;
    }
    return scalar;
}

static NSUInteger IJSVGStyleSheetDecodeEscape(const char* chars, NSUInteger index, NSUInteger end, NSMutableData* data)
{
    index++;
    if (index == end) {
        return index;
    }
    if (chars[index] == '\n' || chars[index] == '\r' || chars[index] == '\f') {
        char c = chars[index++];
        return c == '\r' && index < end && chars[index] == '\n' ? index + 1 : index;
    }
    NSUInteger start = index;
    uint32_t scalar = IJSVGStyleSheetReadHexEscape(chars, end, &index);
    if (index == start) {
        [data appendBytes:chars + index length:1];
        return index + 1;
    }
    IJSVGStyleSheetAppendCodePoint(data, scalar);
    if (index < end && IJSVGStyleSheetCharIsWhitespace(chars[index])) {
        char c = chars[index++];
        if (c == '\r' && index < end && chars[index] == '\n') {
            index++;
        }
    }
    return index;
}

static NSString* IJSVGStyleSheetDecodeFamily(const char* chars, NSUInteger start, NSUInteger end, BOOL quoted)
{
    if (quoted) {
        start++;
        end--;
    } else {
        start = IJSVGStyleSheetIndexBySkippingWhitespace(chars, start, end);
    }
    if (!quoted) {
        while (end > start && IJSVGStyleSheetCharIsWhitespace(chars[end - 1])) {
            end--;
        }
    }
    BOOL decode = NO;
    for (NSUInteger index = start; index < end; index++) {
        if (chars[index] == '\\' || (!quoted && IJSVGStyleSheetCharIsWhitespace(chars[index]))) {
            decode = YES;
            break;
        }
    }
    if (!decode) {
        return start == end ? @"" : IJSVGStyleSheetStringFromUTF8Bytes(chars, start, end);
    }
    NSMutableData* data = [[NSMutableData alloc] initWithCapacity:end - start];
    for (NSUInteger index = start; index < end;) {
        if (chars[index] == '\\') {
            index = IJSVGStyleSheetDecodeEscape(chars, index, end, data);
        } else if (!quoted && IJSVGStyleSheetCharIsWhitespace(chars[index])) {
            index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, index, end);
            if (index < end) {
                [data appendBytes:" " length:1];
            }
        } else {
            NSUInteger marker = index++;
            while (index < end && chars[index] != '\\' && (quoted || !IJSVGStyleSheetCharIsWhitespace(chars[index]))) {
                index++;
            }
            [data appendBytes:chars + marker length:index - marker];
        }
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

NSString* IJSVGStyleSheetDecodeString(const char* chars, NSUInteger start, NSUInteger end)
{
    if (end < start + 2 || (chars[start] != '"' && chars[start] != '\'')) {
        return nil;
    }
    NSUInteger cursor = start;
    if (!IJSVGStyleSheetSkipQuotedString(chars, end, &cursor) || cursor != end) {
        return nil;
    }
    if (end == start + 2) {
        return @"";
    }
    if (memchr(chars + start, '\\', end - start) == NULL) {
        return IJSVGStyleSheetStringFromUTF8Bytes(chars, start + 1, end - 1);
    }
    return IJSVGStyleSheetDecodeFamily(chars, start, end, YES);
}

BOOL IJSVGStyleSheetConsumeASCIIIdentifier(const char* chars, NSUInteger length, NSUInteger* index, char* name, NSUInteger capacity)
{
    NSUInteger start = *index;
    NSUInteger end = start;
    if (!IJSVGStyleSheetSkipIdentifier(chars, length, &end)) {
        return NO;
    }
    *index = end;
    if (capacity == 0) {
        return YES;
    }
    NSUInteger count = 0;
    while (start < end) {
        uint32_t scalar = (unsigned char)chars[start++];
        if (scalar == '\\') {
            NSUInteger escape = start - 1;
            NSUInteger digits = start;
            scalar = IJSVGStyleSheetReadHexEscape(chars, end, &digits);
            if (digits == start) {
                scalar = (unsigned char)chars[start];
            }
            IJSVGStyleSheetSkipEscape(chars, end, &escape, NO);
            start = escape;
        }
        if (scalar == 0 || scalar >= 0x80 || count == capacity - 1) {
            name[0] = '\0';
            return YES;
        }
        name[count++] = (char)scalar;
    }
    name[count] = '\0';
    return YES;
}

NSString* IJSVGStyleSheetConsumeIdentifier(const char* chars, NSUInteger length, NSUInteger* index)
{
    NSUInteger start = *index;
    NSUInteger cursor = start;
    if (!IJSVGStyleSheetSkipIdentifier(chars, length, &cursor)) {
        return nil;
    }
    *index = cursor;
    if (memchr(chars + start, '\\', cursor - start) == NULL) {
        return IJSVGStyleSheetStringFromUTF8Bytes(chars, start, cursor);
    }
    return IJSVGStyleSheetDecodeFamily(chars, start, cursor, NO);
}

static BOOL IJSVGStyleSheetScanFontFamilies(const char* chars, NSUInteger index, NSUInteger length, void (^handler)(NSString*, BOOL))
{
    while (index < length) {
        NSUInteger start = index;
        BOOL quoted = chars[index] == '\'' || chars[index] == '"';
        BOOL valid = quoted ? IJSVGStyleSheetSkipQuotedString(chars, length, &index) : IJSVGStyleSheetSkipUnquotedFamily(chars, length, &index);
        if (!valid) {
            return NO;
        }
        if (handler != nil) {
            NSString* family = IJSVGStyleSheetDecodeFamily(chars, start, index, quoted);
            if (family == nil) {
                return NO;
            }
            handler(family, quoted);
        }
        index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, index, length);
        if (index == length) {
            return YES;
        }
        if (chars[index++] != ',') {
            return NO;
        }
        index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, index, length);
    }
    return NO;
}

BOOL IJSVGStyleSheetEnumerateFontFamilies(NSString* value, void (^handler)(NSString* family, BOOL quoted))
{
    __attribute__((objc_precise_lifetime)) NSString* snapshot = [value copy];
    IJSVGStringBytes source = IJSVGStringGetBytes(snapshot);
    if (source.bytes == NULL || memchr(source.bytes, 0, source.length) != NULL) {
        return NO;
    }
    const char* chars = source.bytes;
    NSUInteger length = source.length;
    NSUInteger start = IJSVGStyleSheetIndexBySkippingWhitespace(chars, 0, length);
    BOOL valid = IJSVGStyleSheetScanFontFamilies(chars, start, length, nil);
    if (valid) {
        valid = IJSVGStyleSheetScanFontFamilies(chars, start, length, handler);
    }
    return valid;
}

static NSUInteger IJSVGStyleSheetFontTokenProperty(char* chars, NSRange token)
{
    CGFloat number = 0;
    BOOL unitless = NO;
    if (!IJSVGStyleSheetFontNumber(chars, token, &number, &unitless)) {
        return IJSVGStyleSheetFontKeywordProperty(chars, token);
    }
    if (!unitless || number == 0) {
        return IJSVGStyleSheetFontSize;
    }
    return number >= 1 && number <= 1000 ? IJSVGStyleSheetFontWeight : NSNotFound;
}

static BOOL IJSVGStyleSheetParseFontLineHeight(char* chars, NSUInteger length, NSUInteger* index, NSRange* ranges)
{
    *index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, *index, length);
    if (*index == length || chars[*index] != '/') {
        return YES;
    }
    (*index)++;
    NSRange height = IJSVGStyleSheetNextFontToken(chars, length, index);
    CGFloat number = 0;
    BOOL unitless = NO;
    if (height.length == 0 || (!IJSVGStyleSheetTokenEquals(chars, height, "normal") && !IJSVGStyleSheetFontNumber(chars, height, &number, &unitless))) {
        return NO;
    }
    ranges[IJSVGStyleSheetFontLineHeight] = height;
    *index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, *index, length);
    return YES;
}

static BOOL IJSVGStyleSheetParseFontTail(char* chars, NSUInteger index, NSUInteger length, NSRange* ranges)
{
    if (!IJSVGStyleSheetParseFontLineHeight(chars, length, &index, ranges) || !IJSVGStyleSheetScanFontFamilies(chars, index, length, nil)) {
        return NO;
    }
    ranges[IJSVGStyleSheetFontFamily] = NSMakeRange(index, length - index);
    return YES;
}

static BOOL IJSVGStyleSheetParseFont(char* chars, NSUInteger length, NSRange* ranges)
{
    NSUInteger index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, 0, length);
    while (length > index && IJSVGStyleSheetCharIsWhitespace(chars[length - 1])) {
        length--;
    }
    NSRange whole = NSMakeRange(index, length - index);
    if (IJSVGStyleSheetTokenEquals(chars, whole, "inherit") || IJSVGStyleSheetTokenEquals(chars, whole, "unset") || IJSVGStyleSheetTokenEquals(chars, whole, "initial")) {
        for (NSUInteger property = 0; property < IJSVGStyleSheetFontPropertyCount; property++) {
            ranges[property] = whole;
        }
        return YES;
    }

    NSUInteger prefixCount = 0;
    while (index < length) {
        NSRange token = IJSVGStyleSheetNextFontToken(chars, length, &index);
        if (token.length == 0) {
            return NO;
        }
        NSUInteger property = IJSVGStyleSheetFontTokenProperty(chars, token);
        if (property == IJSVGStyleSheetFontSize) {
            ranges[property] = token;
            return IJSVGStyleSheetParseFontTail(chars, index, length, ranges);
        }
        if (++prefixCount > 4) {
            return NO;
        }
        if (IJSVGStyleSheetTokenEquals(chars, token, "normal")) {
            continue;
        }
        if (property == NSNotFound || ranges[property].length != 0) {
            return NO;
        }
        ranges[property] = token;
    }
    return NO;
}

static void IJSVGStyleSheetExpandFont(NSString* shorthand, NSMutableDictionary<NSString*, NSString*>* values, BOOL pending)
{
    NSString* attributes[IJSVGStyleSheetFontPropertyCount] = { IJSVGAttributeFontFamily, IJSVGAttributeFontSize, IJSVGAttributeFontStyle, IJSVGAttributeFontWeight, IJSVGAttributeFontStretch, IJSVGAttributeFontVariant, IJSVGAttributeLineHeight, IJSVGAttributeFontVariantLigatures, IJSVGAttributeFontFeatureSettings, IJSVGAttributeFontKerning, IJSVGAttributeFontSizeAdjust };
    if (pending) {
        for (NSUInteger property = 0; property < IJSVGStyleSheetFontPropertyCount; property++) {
            values[attributes[property]] = shorthand;
        }
        return;
    }
    const char* source = shorthand.UTF8String;
    if (source == NULL) {
        return;
    }
    NSUInteger length = strlen(source);
    if (length != [shorthand lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return;
    }
    char* chars = strdup(source);
    if (chars == NULL) {
        return;
    }
    NSRange ranges[IJSVGStyleSheetFontPropertyCount] = { 0 };
    if (IJSVGStyleSheetParseFont(chars, length, ranges)) {
        // Create property strings only after the whole shorthand is valid.
        for (NSUInteger property = 0; property < IJSVGStyleSheetFontPropertyCount; property++) {
            NSRange range = ranges[property];
            NSString* value = range.length != 0 ? IJSVGStyleSheetStringFromUTF8Bytes(chars, range.location, NSMaxRange(range)) : (property == IJSVGStyleSheetFontKerning ? @"auto" : (property == IJSVGStyleSheetFontSizeAdjust ? IJSVGStringNone : IJSVGStringNormal));
            values[attributes[property]] = value;
        }
    }
    free(chars);
}

static BOOL IJSVGStyleSheetValueIsCSSWideKeyword(NSString* value)
{
    return IJSVGCSSWideKeywordFromString(value) != IJSVGCSSWideKeywordUnknown;
}

static NSDictionary<NSString*, NSString*>* IJSVGStyleSheetExpandMarker(NSString* value)
{
    return @ { IJSVGAttributeMarkerStart : value, IJSVGAttributeMarkerMid : value, IJSVGAttributeMarkerEnd : value };
}

static NSDictionary<NSString*, NSString*>* IJSVGStyleSheetExpandFontDeclaration(NSString* value, BOOL pending)
{
    NSMutableDictionary<NSString*, NSString*>* properties = [[NSMutableDictionary alloc] init];
    IJSVGStyleSheetExpandFont(value, properties, pending);
    return properties;
}

static BOOL IJSVGStyleSheetExpandShorthand(NSUInteger attribute, NSString* value, BOOL pending, NSDictionary<NSString*, NSString*>** expanded)
{
    switch (attribute) {
        case IJSVGNodeAttributeMarker:
            *expanded = IJSVGStyleSheetExpandMarker(value);
            return YES;

        case IJSVGNodeAttributeFont:
            *expanded = IJSVGStyleSheetExpandFontDeclaration(value, pending);
            return (*expanded).count != 0;

        default:
            return YES;
    }
}

static BOOL IJSVGStyleSheetStrokeValueIsValid(NSUInteger attribute, NSString* value)
{
    if (IJSVGStyleSheetValueIsCSSWideKeyword(value)) {
        return YES;
    }
    if (attribute == IJSVGNodeAttributeStrokeDashArray) {
        IJSVGStringBytes source = IJSVGStringGetBytes(value);
        return IJSVGStyleSheetTokenEquals(source.bytes, NSMakeRange(0, source.length), "none") || IJSVGUnitLengthsAreValid(value, NO, NO);
    }
    return IJSVGUnitLengthsAreValid(value, attribute == IJSVGNodeAttributeStrokeDashOffset, YES);
}

static BOOL IJSVGStyleSheetTransformBoxIsValid(NSString* value)
{
    IJSVGStringBytes source = IJSVGStringGetBytes(value);
    NSRange token = NSMakeRange(0, source.length);
    switch (source.length) {
        case 8:
            return IJSVGStyleSheetTokenEquals(source.bytes, token, "view-box") || IJSVGStyleSheetTokenEquals(source.bytes, token, "fill-box");
        case 10:
            return IJSVGStyleSheetTokenEquals(source.bytes, token, "stroke-box") || IJSVGStyleSheetTokenEquals(source.bytes, token, "border-box");
        case 11:
            return IJSVGStyleSheetTokenEquals(source.bytes, token, "content-box");
        default:
            return IJSVGStyleSheetValueIsCSSWideKeyword(value);
    }
}

static BOOL IJSVGStyleSheetDeclarationValueIsValid(NSUInteger attribute, NSString* value)
{
    if (IJSVGAttributeIsGeometryProperty(attribute)) {
        return [value isKindOfClass:NSString.class] && IJSVGGeometryLengthIsValid(value, (IJSVGNodeAttribute)attribute);
    }
    switch (attribute) {
        case IJSVGNodeAttributeStrokeWidth:
        case IJSVGNodeAttributeStrokeDashOffset:
        case IJSVGNodeAttributeStrokeDashArray:
            return IJSVGStyleSheetStrokeValueIsValid(attribute, value);

        case IJSVGNodeAttributeD:
            return IJSVGStyleSheetValueIsCSSWideKeyword(value) || IJSVGCSSPathDataIsValid(value);

        case IJSVGNodeAttributeTransformOrigin:
            return IJSVGStyleSheetValueIsCSSWideKeyword(value) || IJSVGTransformOriginFromString(value) != nil;

        case IJSVGNodeAttributeTransformBox:
            return IJSVGStyleSheetTransformBoxIsValid(value);

        default:
            return YES;
    }
}

static IJSVGCSSVariableSyntax IJSVGStyleSheetDeclarationVariableSyntax(NSString* value, BOOL custom)
{
    if (custom || IJSVGCSSValueMayContainVariables(value)) {
        return IJSVGCSSValidateVariables(value);
    }
    return IJSVGCSSVariableSyntaxLiteral;
}

NSString* IJSVGStyleSheetResolveDeclaration(NSString* property, NSString* value, NSDictionary<NSString*, NSString*>** expanded)
{
    BOOL variables = NO;
    return IJSVGStyleSheetResolveVariableDeclaration(property, value, expanded, &variables);
}

NSString* IJSVGStyleSheetResolveVariableDeclaration(NSString* property, NSString* value, NSDictionary<NSString*, NSString*>** expanded, BOOL* variables)
{
    *expanded = nil;
    *variables = NO;
    BOOL custom = [property hasPrefix:@"--"];
    NSString* name = custom ? property : property.lowercaseString;
    IJSVGCSSVariableSyntax syntax = IJSVGStyleSheetDeclarationVariableSyntax(value, custom);
    if (syntax == IJSVGCSSVariableSyntaxInvalid || (custom && name.length == 2)) {
        return nil;
    }
    if (custom) {
        return name;
    }

    NSUInteger attribute = IJSVGNodeAttributeForName(name);
    *variables = syntax == IJSVGCSSVariableSyntaxReferences;
    if (!*variables && !IJSVGStyleSheetDeclarationValueIsValid(attribute, value)) {
        return nil;
    }
    return IJSVGStyleSheetExpandShorthand(attribute, value, *variables, expanded) ? name : nil;
}

NSDictionary<NSString*, NSString*>* IJSVGStyleSheetExpandDeclaration(NSString* property, NSString* value)
{
    NSDictionary<NSString*, NSString*>* expanded = nil;
    NSString* name = IJSVGStyleSheetResolveDeclaration(property, value, &expanded);
    if (name == nil) {
        return @ {};
    }
    if (expanded == nil) {
        return @ { name : value };
    }
    NSMutableDictionary<NSString*, NSString*>* declarations = [expanded mutableCopy];
    declarations[name] = value;
    return declarations;
}
