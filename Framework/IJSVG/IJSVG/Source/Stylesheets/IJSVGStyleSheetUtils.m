//
//  IJSVGStyleSheetUtils.m
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGStyleSheetUtils.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVGParserUtils.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGCommandParser.h>
#import <IJSVG/IJSVGRendering.h>
#import <math.h>

BOOL IJSVGStyleSheetCharIsWhitespace(char aChar)
{
    return aChar == ' ' || aChar == '\t' || aChar == '\n' ||
        aChar == '\r' || aChar == '\f';
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
    while(IJSVGStyleSheetCharIsWhitespace(**cursor)) {
        (*cursor)++;
    }
}

static BOOL IJSVGMediaConsume(const char** cursor, const char* token)
{
    size_t length = strlen(token);
    if(strncmp(*cursor, token, length) != 0) {
        return NO;
    }
    char next = (*cursor)[length];
    if((token[length - 1] >= 'a' && token[length - 1] <= 'z') &&
       ((next >= 'a' && next <= 'z') || next == '-')) {
        return NO;
    }
    *cursor += length;
    IJSVGMediaSkipWhitespace(cursor);
    return YES;
}

static BOOL IJSVGMediaParseFeature(const char** cursor,
                                   IJSVGMediaCondition* condition, BOOL* valid)
{
    IJSVGMediaSkipWhitespace(cursor);
    BOOL minimum = IJSVGMediaConsume(cursor, "min-");
    BOOL maximum = !minimum && IJSVGMediaConsume(cursor, "max-");
    if(IJSVGMediaConsume(cursor, "width")) {
        condition->feature = IJSVGMediaFeatureWidth;
    } else if(IJSVGMediaConsume(cursor, "height")) {
        condition->feature = IJSVGMediaFeatureHeight;
    } else if(!minimum && !maximum && IJSVGMediaConsume(cursor, "orientation") &&
              IJSVGMediaConsume(cursor, ":")) {
        BOOL portrait = IJSVGMediaConsume(cursor, "portrait");
        BOOL landscape = !portrait && IJSVGMediaConsume(cursor, "landscape");
        *valid = (portrait || landscape) && IJSVGMediaConsume(cursor, ")");
        condition->feature = portrait ? IJSVGMediaFeaturePortrait : IJSVGMediaFeatureLandscape;
        return *valid;
    } else {
        *valid = NO;
        return NO;
    }
    if(!minimum && !maximum && IJSVGMediaConsume(cursor, ")")) {
        condition->comparison = 1;
        return YES;
    }
    int comparison = minimum ? 1 : (maximum ? -1 : 0);
    BOOL equal = YES;
    if(!IJSVGMediaConsume(cursor, ":")) {
        if(minimum || maximum) {
            *valid = NO;
            return NO;
        }
        char operation = **cursor;
        if(operation != '<' && operation != '>' && operation != '=') {
            *valid = NO;
            return NO;
        }
        (*cursor)++;
        comparison = operation == '<' ? -1 : (operation == '>' ? 1 : 0);
        equal = operation == '=' || **cursor == '=';
        if(operation != '=' && **cursor == '=') {
            (*cursor)++;
        }
        IJSVGMediaSkipWhitespace(cursor);
    }
    CGFloat expected;
    if(!IJSVGParseLengthNumber(cursor, NO, &expected)) {
        *valid = NO;
        return NO;
    }
    char suffix[4] = { 0 };
    NSUInteger length = 0;
    while(**cursor != '\0' && **cursor != ')' && !IJSVGStyleSheetCharIsWhitespace(**cursor)) {
        if(length == sizeof(suffix) - 1) {
            *valid = NO;
            return NO;
        }
        suffix[length++] = *(*cursor)++;
    }
    IJSVGUnitLengthType type = IJSVGUnitLengthTypeForCString(suffix);
    if((length == 0 && expected != 0) ||
       (length != 0 && type == IJSVGUnitLengthTypeNumber) ||
       (length == 3 && strcmp(suffix, "rem") != 0) ||
       type == IJSVGUnitLengthTypePercentage || type == IJSVGUnitLengthTypeEX) {
        *valid = NO;
        return NO;
    }
    expected = [IJSVGUnitLength convertUnitValue:expected
                        toBaseFromUnitLengthType:type];
    if(type == IJSVGUnitLengthTypeEM) {
        expected *= IJSVGDefaultFontSize;
    }
    if(!isfinite(expected)) {
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

IJSVGMediaQuery* IJSVGMediaQueryCreate(NSString* media)
{
    NSString* clean = IJSVGStyleSheetStringByRemovingCSSComments(media ?: @"").lowercaseString;
    const char* cursor = clean.UTF8String;
    if(cursor == NULL) {
        return NULL;
    }
    NSUInteger capacity = 1;
    for(const char* character = cursor; *character != '\0'; character++) {
        if(*character == '(' || *character == ',') {
            capacity++;
        }
    }
    IJSVGMediaQuery* query = calloc(1, sizeof(IJSVGMediaQuery) +
                                      capacity * sizeof(IJSVGMediaCondition));
    if(query == NULL) {
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
        if(*cursor != '(') {
            if(IJSVGMediaConsume(&cursor, "all")) {
                clause->value = IJSVGMediaTypeAll;
            } else if(IJSVGMediaConsume(&cursor, "screen")) {
                clause->value = IJSVGMediaTypeScreen;
            } else if(IJSVGMediaConsume(&cursor, "print")) {
                clause->value = IJSVGMediaTypePrint;
            } else if(*cursor != '\0' || clause->negate || only || query->count != 1) {
                clause->valid = NO;
            }
            if(clause->valid && *cursor != ',' && *cursor != '\0') {
                clause->valid = IJSVGMediaConsume(&cursor, "and") && *cursor == '(';
            }
        } else if(only) {
            clause->valid = NO;
        }
        while(clause->valid && *cursor == '(') {
            cursor++;
            IJSVGMediaCondition* condition = &query->conditions[query->count++];
            clause->count++;
            IJSVGMediaParseFeature(&cursor, condition, &clause->valid);
            if(clause->valid && *cursor != ',' && *cursor != '\0') {
                clause->valid = IJSVGMediaConsume(&cursor, "and") && *cursor == '(';
            }
        }
        clause->valid = clause->valid && (*cursor == ',' || *cursor == '\0');
        while(*cursor != '\0' && *cursor != ',') {
            cursor++;
        }
        if(*cursor == '\0') {
            break;
        }
        cursor++;
        IJSVGMediaSkipWhitespace(&cursor);
    } while(YES);
    return query;
}

void IJSVGMediaQueryRelease(IJSVGMediaQuery* query)
{
    free(query);
}

BOOL IJSVGMediaQueryMatches(const IJSVGMediaQuery* query, IJSVGMediaEnvironment environment)
{
    if(query == NULL) {
        return NO;
    }
    for(NSUInteger index = 0; index < query->count;) {
        const IJSVGMediaCondition* clause = &query->conditions[index];
        BOOL matches = clause->value == IJSVGMediaTypeAll || clause->value == environment.type;
        for(NSUInteger offset = 1; clause->valid && offset < clause->count; offset++) {
            const IJSVGMediaCondition* condition = &query->conditions[index + offset];
            CGFloat actual = condition->feature == IJSVGMediaFeatureWidth ?
                environment.viewport.width : environment.viewport.height;
            BOOL feature;
            if(condition->feature == IJSVGMediaFeaturePortrait) {
                feature = environment.viewport.height >= environment.viewport.width;
            } else if(condition->feature == IJSVGMediaFeatureLandscape) {
                feature = environment.viewport.width > environment.viewport.height;
            } else {
                feature = (condition->equal && actual == condition->value) ||
                    (condition->comparison < 0 && actual < condition->value) ||
                    (condition->comparison > 0 && actual > condition->value);
            }
            matches = matches && feature;
        }
        if(clause->valid && (clause->negate ? !matches : matches)) {
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
    return aChar == '#' || aChar == '.' || aChar == '*' || aChar == '|' ||
        IJSVGStyleSheetCharIsCombinator(aChar) ||
        IJSVGStyleSheetCharIsWhitespace(aChar);
}

BOOL IJSVGStyleSheetCharIsInvalidSelectorChar(char aChar)
{
    return aChar == '@' || aChar == ':' || aChar == ';' ||
        aChar == '(' || aChar == ')' || aChar == '[' || aChar == ']';
}

BOOL IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(const char* chars,
                                                    NSUInteger index,
                                                    NSUInteger length)
{
    return chars != NULL && index + 1 < length &&
        chars[index] == '|' && chars[index + 1] == '|';
}

NSUInteger IJSVGStyleSheetIndexBySkippingWhitespace(const char* chars,
                                                    NSUInteger index,
                                                    NSUInteger length)
{
    while(index < length && IJSVGStyleSheetCharIsWhitespace(chars[index])) {
        index++;
    }
    return index;
}

IJSVGStyleSheetSelectorCombinator IJSVGStyleSheetCombinatorForChar(char aChar)
{
    switch(aChar) {
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
    switch(combinator) {
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
    if(chars == NULL || end <= start) {
        return nil;
    }
    return [[NSString alloc] initWithBytes:chars + start
                                    length:end - start
                                  encoding:NSUTF8StringEncoding];
}

BOOL IJSVGStyleSheetConsumeQuotedCharacter(char c, char* quote, BOOL* escaped)
{
    if(*escaped) {
        *escaped = NO;
        return YES;
    }
    if(c == '\\') {
        *escaped = YES;
        return YES;
    }
    if(*quote != 0) {
        if(c == *quote || c == '\n' || c == '\r' || c == '\f') {
            *quote = 0;
        }
        return YES;
    }
    if(c == '\'' || c == '"') {
        *quote = c;
        return YES;
    }
    return NO;
}

static NSRange IJSVGStyleSheetTrimRange(const char* chars, NSUInteger start,
                                         NSUInteger end)
{
    start = IJSVGStyleSheetIndexBySkippingWhitespace(chars, start, end);
    while(end > start && IJSVGStyleSheetCharIsWhitespace(chars[end - 1])) {
        end--;
    }
    return NSMakeRange(start, end - start);
}

NSString* IJSVGStyleSheetDeclarationValue(NSString* value, BOOL* important)
{
    *important = NO;
    const char* chars = value.UTF8String;
    if(chars == NULL) {
        return nil;
    }
    NSUInteger length = strlen(chars);
    if(length != [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return nil;
    }
    NSRange range = IJSVGStyleSheetTrimRange(chars, 0, length);
    NSUInteger end = NSMaxRange(range);
    if(range.length < 10) {
        return IJSVGStyleSheetStringFromUTF8Bytes(chars, range.location, end);
    }
    NSUInteger word = end - 9;
    const char* keyword = "important";
    for(NSUInteger index = 0; index < 9; index++) {
        if(IJSVGCharToLower(chars[word + index]) != keyword[index]) {
            return IJSVGStyleSheetStringFromUTF8Bytes(chars, range.location, end);
        }
    }
    NSUInteger marker = word;
    while(marker > range.location && IJSVGStyleSheetCharIsWhitespace(chars[marker - 1])) {
        marker--;
    }
    if(marker == range.location || chars[marker - 1] != '!') {
        return IJSVGStyleSheetStringFromUTF8Bytes(chars, range.location, end);
    }
    marker--;
    char quote = 0;
    BOOL escaped = NO;
    NSUInteger depth = 0;
    for(NSUInteger index = range.location; index <= marker; index++) {
        char c = chars[index];
        if(IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
            if(index == marker) {
                return IJSVGStyleSheetStringFromUTF8Bytes(chars, range.location, end);
            }
            continue;
        }
        if(c == '(' || c == '[' || c == '{') {
            depth++;
        } else if((c == ')' || c == ']' || c == '}') && depth != 0) {
            depth--;
        }
    }
    if(depth == 0) {
        *important = YES;
        range = IJSVGStyleSheetTrimRange(chars, range.location, marker);
    }
    return IJSVGStyleSheetStringFromUTF8Bytes(chars, range.location, NSMaxRange(range));
}

NSString* IJSVGStyleSheetStringByRemovingCSSComments(NSString* string)
{
    const char* chars = string.UTF8String;
    if(chars == NULL) {
        return string;
    }

    NSUInteger length = strlen(chars);
    if(length == 0) {
        return string;
    }

    NSMutableString* cleanString = [[NSMutableString alloc] initWithCapacity:length];
    NSUInteger marker = 0;
    char quote = 0;
    BOOL escaped = NO;
    for(NSUInteger i = 0; i < length; i++) {
        char c = chars[i];

        if(IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
            continue;
        }

        if(c == '/' && i + 1 < length && chars[i + 1] == '*') {
            NSString* chunk = IJSVGStyleSheetStringFromUTF8Bytes(chars, marker, i);
            if(chunk != nil) {
                [cleanString appendString:chunk];
            }

            i += 2;
            while(i + 1 < length && !(chars[i] == '*' && chars[i + 1] == '/')) {
                i++;
            }

            if(i + 1 >= length) {
                marker = length;
                break;
            }

            i += 1;
            marker = i + 1;
        }
    }

    NSString* chunk = IJSVGStyleSheetStringFromUTF8Bytes(chars, marker, length);
    if(chunk != nil) {
        [cleanString appendString:chunk];
    }
    return cleanString;
}

BOOL IJSVGStyleSheetSelectorRawHasSimpleSelector(IJSVGStyleSheetSelectorRaw* rawSelector)
{
    return rawSelector.tag != nil || rawSelector.identifier != nil || rawSelector.classes.count != 0;
}

BOOL IJSVGStyleSheetSelectorRawHasAnySelector(IJSVGStyleSheetSelectorRaw* rawSelector,
                                              BOOL hasUniversalSelector)
{
    return hasUniversalSelector == YES || IJSVGStyleSheetSelectorRawHasSimpleSelector(rawSelector) == YES;
}

BOOL IJSVGStyleSheetSelectorCommitRawSelector(NSMutableArray<IJSVGStyleSheetSelectorRaw*>* parsedSelectors,
                                              IJSVGStyleSheetSelectorRaw* rawSelector,
                                              BOOL hasUniversalSelector)
{
    if(IJSVGStyleSheetSelectorRawHasAnySelector(rawSelector, hasUniversalSelector) == NO) {
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

static BOOL IJSVGStyleSheetTokenEquals(char* chars, NSRange token, const char* keyword)
{
    if(token.length != strlen(keyword)) {
        return NO;
    }
    NSUInteger end = NSMaxRange(token);
    char saved = chars[end];
    chars[end] = '\0';
    BOOL equal = IJSVGCharBufferCaseInsensitiveCompare(chars + token.location, keyword);
    chars[end] = saved;
    return equal;
}

static NSRange IJSVGStyleSheetNextFontToken(const char* chars, NSUInteger length,
                                            NSUInteger* index)
{
    NSUInteger start = IJSVGStyleSheetIndexBySkippingWhitespace(chars, *index, length);
    *index = start;
    while(*index < length && chars[*index] != '/' &&
          !IJSVGStyleSheetCharIsWhitespace(chars[*index])) {
        (*index)++;
    }
    return NSMakeRange(start, *index - start);
}

static NSUInteger IJSVGStyleSheetSkipDigits(const char* chars, NSUInteger index,
                                             NSUInteger end)
{
    while(index < end && chars[index] >= '0' && chars[index] <= '9') {
        index++;
    }
    return index;
}

static NSUInteger IJSVGStyleSheetSkipExponent(const char* chars, NSUInteger index,
                                               NSUInteger end)
{
    // An e starts an exponent only when followed by digits, not an em/ex unit.
    if(index == end || IJSVGCharToLower(chars[index]) != 'e') {
        return index;
    }
    NSUInteger digits = index + 1;
    if(digits < end && (chars[digits] == '+' || chars[digits] == '-')) {
        digits++;
    }
    NSUInteger exponentEnd = IJSVGStyleSheetSkipDigits(chars, digits, end);
    return exponentEnd != digits ? exponentEnd : index;
}

static BOOL IJSVGStyleSheetFontUnitIsValid(char* chars, NSUInteger index,
                                           NSUInteger end)
{
    // The unit helper checks suffixes, so reject extra bytes first.
    NSUInteger length = end - index;
    if(length == 1 ? chars[index] != '%' :
       (length != 2 || chars[end - 1] == '%')) {
        return NO;
    }
    char saved = chars[end];
    chars[end] = '\0';
    IJSVGUnitLengthType type = IJSVGUnitLengthTypeForCString(chars + index);
    chars[end] = saved;
    return type != IJSVGUnitLengthTypeNumber;
}

static BOOL IJSVGStyleSheetFontNumber(char* chars, NSRange token,
                                      CGFloat* value, BOOL* unitless)
{
    NSUInteger index = token.location;
    NSUInteger end = NSMaxRange(token);
    if(index < end && chars[index] == '+') {
        index++;
    }
    NSUInteger digits = index;
    index = IJSVGStyleSheetSkipDigits(chars, index, end);
    BOOL hasDigits = index != digits;
    if(index < end && chars[index] == '.') {
        digits = ++index;
        index = IJSVGStyleSheetSkipDigits(chars, index, end);
        if(index == digits) {
            return NO;
        }
        hasDigits = YES;
    }
    if(!hasDigits) {
        return NO;
    }
    index = IJSVGStyleSheetSkipExponent(chars, index, end);
    *unitless = index == end;
    if(!*unitless && !IJSVGStyleSheetFontUnitIsValid(chars, index, end)) {
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
    } keywords[] = {
        { "xx-small", IJSVGStyleSheetFontSize },
        { "x-small", IJSVGStyleSheetFontSize },
        { "small", IJSVGStyleSheetFontSize },
        { "medium", IJSVGStyleSheetFontSize },
        { "large", IJSVGStyleSheetFontSize },
        { "x-large", IJSVGStyleSheetFontSize },
        { "xx-large", IJSVGStyleSheetFontSize },
        { "smaller", IJSVGStyleSheetFontSize },
        { "larger", IJSVGStyleSheetFontSize },
        { "italic", IJSVGStyleSheetFontStyle },
        { "oblique", IJSVGStyleSheetFontStyle },
        { "bold", IJSVGStyleSheetFontWeight },
        { "bolder", IJSVGStyleSheetFontWeight },
        { "lighter", IJSVGStyleSheetFontWeight },
        { "small-caps", IJSVGStyleSheetFontVariant },
        { "ultra-condensed", IJSVGStyleSheetFontStretch },
        { "extra-condensed", IJSVGStyleSheetFontStretch },
        { "condensed", IJSVGStyleSheetFontStretch },
        { "semi-condensed", IJSVGStyleSheetFontStretch },
        { "semi-expanded", IJSVGStyleSheetFontStretch },
        { "expanded", IJSVGStyleSheetFontStretch },
        { "extra-expanded", IJSVGStyleSheetFontStretch },
        { "ultra-expanded", IJSVGStyleSheetFontStretch }
    };
    for(NSUInteger index = 0; index < sizeof(keywords) / sizeof(keywords[0]); index++) {
        if(IJSVGStyleSheetTokenEquals(chars, token, keywords[index].keyword)) {
            return keywords[index].property;
        }
    }
    return NSNotFound;
}

static BOOL IJSVGStyleSheetSkipEscape(const char* chars, NSUInteger length,
                                       NSUInteger* index, BOOL quoted)
{
    if(++*index == length) {
        return NO;
    }
    char c = chars[*index];
    if(c == '\n' || c == '\r' || c == '\f') {
        if(!quoted) {
            return NO;
        }
        (*index)++;
        if(c == '\r' && *index < length && chars[*index] == '\n') {
            (*index)++;
        }
        return YES;
    }
    NSUInteger digits = 0;
    while(*index < length && digits < 6) {
        c = IJSVGCharToLower(chars[*index]);
        if(!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) {
            break;
        }
        (*index)++;
        digits++;
    }
    if(digits == 0) {
        (*index)++;
    } else if(*index < length && IJSVGStyleSheetCharIsWhitespace(chars[*index])) {
        c = chars[(*index)++];
        if(c == '\r' && *index < length && chars[*index] == '\n') {
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

static BOOL IJSVGStyleSheetSkipQuotedFamily(const char* chars, NSUInteger length,
                                             NSUInteger* index)
{
    char quote = chars[(*index)++];
    while(*index < length) {
        char c = chars[*index];
        if(c == '\\') {
            if(!IJSVGStyleSheetSkipEscape(chars, length, index, YES)) {
                return NO;
            }
        } else if(c == quote) {
            (*index)++;
            return YES;
        } else if(c == '\n' || c == '\r' || c == '\f') {
            return NO;
        } else {
            (*index)++;
        }
    }
    return NO;
}

static BOOL IJSVGStyleSheetFontFamilyIsReserved(char* chars, NSRange name)
{
    return IJSVGStyleSheetTokenEquals(chars, name, "inherit") ||
        IJSVGStyleSheetTokenEquals(chars, name, "initial") ||
        IJSVGStyleSheetTokenEquals(chars, name, "unset") ||
        IJSVGStyleSheetTokenEquals(chars, name, "default") ||
        IJSVGStyleSheetTokenEquals(chars, name, "revert") ||
        IJSVGStyleSheetTokenEquals(chars, name, "revert-layer");
}

static BOOL IJSVGStyleSheetSkipFamilyIdentifier(char* chars, NSUInteger length,
                                                 NSUInteger* index)
{
    NSUInteger start = *index;
    if(chars[*index] == '-') {
        (*index)++;
    }
    if(*index == length || (!IJSVGStyleSheetNameStart(chars[*index]) &&
       chars[*index] != '\\' && chars[*index] != '-')) {
        return NO;
    }
    while(*index < length) {
        char c = chars[*index];
        if(c == '\\') {
            if(!IJSVGStyleSheetSkipEscape(chars, length, index, NO)) {
                return NO;
            }
        } else if(IJSVGStyleSheetNameStart(c) || c == '-' ||
                  (c >= '0' && c <= '9')) {
            (*index)++;
        } else {
            break;
        }
    }
    return !IJSVGStyleSheetFontFamilyIsReserved(chars, NSMakeRange(start, *index - start));
}

static BOOL IJSVGStyleSheetSkipUnquotedFamily(char* chars, NSUInteger length,
                                               NSUInteger* index)
{
    while(*index < length) {
        if(!IJSVGStyleSheetSkipFamilyIdentifier(chars, length, index)) {
            return NO;
        }
        NSUInteger end = *index;
        *index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, *index, length);
        if(*index == length || chars[*index] == ',') {
            return YES;
        }
        if(*index == end) {
            return NO;
        }
    }
    return NO;
}

static void IJSVGStyleSheetAppendCodePoint(NSMutableData* data, uint32_t scalar)
{
    if(scalar == 0 || scalar > 0x10FFFF || (scalar >= 0xD800 && scalar <= 0xDFFF)) {
        scalar = u'�';
    }
    uint8_t bytes[4];
    NSUInteger count;
    if(scalar < 0x80) {
        bytes[0] = scalar;
        count = 1;
    } else if(scalar < 0x800) {
        bytes[0] = 0xC0 | (scalar >> 6);
        bytes[1] = 0x80 | (scalar & 0x3F);
        count = 2;
    } else if(scalar < 0x10000) {
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

static NSUInteger IJSVGStyleSheetDecodeEscape(const char* chars, NSUInteger index,
                                               NSUInteger end, NSMutableData* data)
{
    index++;
    if(index == end) {
        return index;
    }
    if(chars[index] == '\n' || chars[index] == '\r' || chars[index] == '\f') {
        char c = chars[index++];
        return c == '\r' && index < end && chars[index] == '\n' ? index + 1 : index;
    }
    uint32_t scalar = 0;
    NSUInteger digits = 0;
    while(index < end && digits < 6) {
        char c = IJSVGCharToLower(chars[index]);
        int digit = c >= '0' && c <= '9' ? c - '0' :
            (c >= 'a' && c <= 'f' ? c - 'a' + 10 : -1);
        if(digit < 0) {
            break;
        }
        scalar = scalar * 16 + digit;
        digits++;
        index++;
    }
    if(digits == 0) {
        [data appendBytes:chars + index length:1];
        return index + 1;
    }
    IJSVGStyleSheetAppendCodePoint(data, scalar);
    if(index < end && IJSVGStyleSheetCharIsWhitespace(chars[index])) {
        char c = chars[index++];
        if(c == '\r' && index < end && chars[index] == '\n') {
            index++;
        }
    }
    return index;
}

static NSString* IJSVGStyleSheetDecodeFamily(const char* chars, NSUInteger start,
                                              NSUInteger end, BOOL quoted)
{
    if(quoted) {
        start++;
        end--;
    } else {
        start = IJSVGStyleSheetIndexBySkippingWhitespace(chars, start, end);
    }
    NSMutableData* data = [[NSMutableData alloc] initWithCapacity:end - start];
    for(NSUInteger index = start; index < end;) {
        if(chars[index] == '\\') {
            index = IJSVGStyleSheetDecodeEscape(chars, index, end, data);
        } else if(!quoted && IJSVGStyleSheetCharIsWhitespace(chars[index])) {
            index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, index, end);
            if(index < end) {
                [data appendBytes:" " length:1];
            }
        } else {
            NSUInteger marker = index++;
            while(index < end && chars[index] != '\\' &&
                  (quoted || !IJSVGStyleSheetCharIsWhitespace(chars[index]))) {
                index++;
            }
            [data appendBytes:chars + marker length:index - marker];
        }
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static BOOL IJSVGStyleSheetScanFontFamilies(char* chars, NSUInteger index,
                                             NSUInteger length,
                                             void (^handler)(NSString*, BOOL))
{
    while(index < length) {
        NSUInteger start = index;
        BOOL quoted = chars[index] == '\'' || chars[index] == '"';
        BOOL valid = quoted ? IJSVGStyleSheetSkipQuotedFamily(chars, length, &index) :
            IJSVGStyleSheetSkipUnquotedFamily(chars, length, &index);
        if(!valid) {
            return NO;
        }
        if(handler != nil) {
            NSString* family = IJSVGStyleSheetDecodeFamily(chars, start, index, quoted);
            if(family == nil) {
                return NO;
            }
            handler(family, quoted);
        }
        index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, index, length);
        if(index == length) {
            return YES;
        }
        if(chars[index++] != ',') {
            return NO;
        }
        index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, index, length);
    }
    return NO;
}

BOOL IJSVGStyleSheetEnumerateFontFamilies(NSString* value,
                                           void (^handler)(NSString* family, BOOL quoted))
{
    const char* source = value.UTF8String;
    if(source == NULL) {
        return NO;
    }
    NSUInteger length = strlen(source);
    if(length != [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return NO;
    }
    char* chars = strdup(source);
    if(chars == NULL) {
        return NO;
    }
    NSUInteger start = IJSVGStyleSheetIndexBySkippingWhitespace(chars, 0, length);
    BOOL valid = IJSVGStyleSheetScanFontFamilies(chars, start, length, nil);
    if(valid) {
        valid = IJSVGStyleSheetScanFontFamilies(chars, start, length, handler);
    }
    free(chars);
    return valid;
}

static NSUInteger IJSVGStyleSheetFontTokenProperty(char* chars, NSRange token)
{
    CGFloat number = 0;
    BOOL unitless = NO;
    if(!IJSVGStyleSheetFontNumber(chars, token, &number, &unitless)) {
        return IJSVGStyleSheetFontKeywordProperty(chars, token);
    }
    if(!unitless || number == 0) {
        return IJSVGStyleSheetFontSize;
    }
    return number >= 1 && number <= 1000 ? IJSVGStyleSheetFontWeight : NSNotFound;
}

static BOOL IJSVGStyleSheetParseFontLineHeight(char* chars, NSUInteger length,
                                                NSUInteger* index, NSRange* ranges)
{
    *index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, *index, length);
    if(*index == length || chars[*index] != '/') {
        return YES;
    }
    (*index)++;
    NSRange height = IJSVGStyleSheetNextFontToken(chars, length, index);
    CGFloat number = 0;
    BOOL unitless = NO;
    if(height.length == 0 ||
       (!IJSVGStyleSheetTokenEquals(chars, height, "normal") &&
        !IJSVGStyleSheetFontNumber(chars, height, &number, &unitless))) {
        return NO;
    }
    ranges[IJSVGStyleSheetFontLineHeight] = height;
    *index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, *index, length);
    return YES;
}

static BOOL IJSVGStyleSheetParseFontTail(char* chars, NSUInteger index,
                                          NSUInteger length, NSRange* ranges)
{
    if(!IJSVGStyleSheetParseFontLineHeight(chars, length, &index, ranges) ||
       !IJSVGStyleSheetScanFontFamilies(chars, index, length, nil)) {
        return NO;
    }
    ranges[IJSVGStyleSheetFontFamily] = NSMakeRange(index, length - index);
    return YES;
}

static BOOL IJSVGStyleSheetParseFont(char* chars, NSUInteger length, NSRange* ranges)
{
    NSUInteger index = IJSVGStyleSheetIndexBySkippingWhitespace(chars, 0, length);
    while(length > index && IJSVGStyleSheetCharIsWhitespace(chars[length - 1])) {
        length--;
    }
    NSRange whole = NSMakeRange(index, length - index);
    if(IJSVGStyleSheetTokenEquals(chars, whole, "inherit") ||
       IJSVGStyleSheetTokenEquals(chars, whole, "unset") ||
       IJSVGStyleSheetTokenEquals(chars, whole, "initial")) {
        for(NSUInteger property = 0; property < IJSVGStyleSheetFontPropertyCount; property++) {
            ranges[property] = whole;
        }
        return YES;
    }

    NSUInteger prefixCount = 0;
    while(index < length) {
        NSRange token = IJSVGStyleSheetNextFontToken(chars, length, &index);
        if(token.length == 0) {
            return NO;
        }
        NSUInteger property = IJSVGStyleSheetFontTokenProperty(chars, token);
        if(property == IJSVGStyleSheetFontSize) {
            ranges[property] = token;
            return IJSVGStyleSheetParseFontTail(chars, index, length, ranges);
        }
        if(++prefixCount > 4) {
            return NO;
        }
        if(IJSVGStyleSheetTokenEquals(chars, token, "normal")) {
            continue;
        }
        if(property == NSNotFound || ranges[property].length != 0) {
            return NO;
        }
        ranges[property] = token;
    }
    return NO;
}

static void IJSVGStyleSheetExpandFont(NSString* shorthand, NSMutableDictionary* values)
{
    const char* source = shorthand.UTF8String;
    if(source == NULL) {
        return;
    }
    NSUInteger length = strlen(source);
    if(length != [shorthand lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return;
    }
    char* chars = strdup(source);
    if(chars == NULL) {
        return;
    }
    NSRange ranges[IJSVGStyleSheetFontPropertyCount] = { 0 };
    if(IJSVGStyleSheetParseFont(chars, length, ranges)) {
        NSString* attributes[IJSVGStyleSheetFontPropertyCount] = {
            IJSVGAttributeFontFamily, IJSVGAttributeFontSize, IJSVGAttributeFontStyle,
            IJSVGAttributeFontWeight, IJSVGAttributeFontStretch, IJSVGAttributeFontVariant,
            IJSVGAttributeLineHeight, IJSVGAttributeFontVariantLigatures,
            IJSVGAttributeFontFeatureSettings, IJSVGAttributeFontKerning,
            IJSVGAttributeFontSizeAdjust
        };
        // Create property strings only after the whole shorthand is valid.
        for(NSUInteger property = 0; property < IJSVGStyleSheetFontPropertyCount; property++) {
            NSRange range = ranges[property];
            NSString* value = range.length != 0
                ? IJSVGStyleSheetStringFromUTF8Bytes(chars, range.location, NSMaxRange(range))
                : (property == IJSVGStyleSheetFontKerning ? @"auto" :
                    (property == IJSVGStyleSheetFontSizeAdjust ? IJSVGStringNone : IJSVGStringNormal));
            values[attributes[property]] = value;
        }
    }
    free(chars);
}

typedef BOOL (^IJSVGStyleSheetDeclarationExpander)(NSString*, NSDictionary**);

NSString* IJSVGStyleSheetResolveDeclaration(NSString* property, NSString* value,
                                            NSDictionary<NSString*, NSString*>** expanded)
{
    static NSDictionary<NSString*, IJSVGStyleSheetDeclarationExpander>* expanders;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary<NSString*, IJSVGStyleSheetDeclarationExpander>* handlers = [@{
            IJSVGAttributeMarker: ^BOOL(NSString* shorthand, NSDictionary** values) {
                *values = @{
                    IJSVGAttributeMarkerStart: shorthand,
                    IJSVGAttributeMarkerMid: shorthand,
                    IJSVGAttributeMarkerEnd: shorthand
                };
                return YES;
            },
            IJSVGAttributeFont: ^BOOL(NSString* shorthand, NSDictionary** values) {
                NSMutableDictionary* properties = [[NSMutableDictionary alloc] init];
                IJSVGStyleSheetExpandFont(shorthand, properties);
                *values = properties;
                return properties.count != 0;
            }
        } mutableCopy];
        NSArray<NSString*>* geometryProperties = @[
            IJSVGAttributeX, IJSVGAttributeY, IJSVGAttributeWidth, IJSVGAttributeHeight,
            IJSVGAttributeCX, IJSVGAttributeCY, IJSVGAttributeR, IJSVGAttributeRX, IJSVGAttributeRY
        ];
        for(NSString* geometryProperty in geometryProperties) {
            IJSVGNodeAttribute attribute = (IJSVGNodeAttribute)IJSVGNodeAttributeForName(geometryProperty);
            handlers[geometryProperty] = ^BOOL(NSString* geometryValue, NSDictionary** values) {
                return [geometryValue isKindOfClass:NSString.class] &&
                    IJSVGGeometryLengthIsValid(geometryValue, attribute);
            };
        }
        handlers[IJSVGAttributeTransformOrigin] = ^BOOL(NSString* origin, NSDictionary** values) {
            return [@[@"inherit", @"initial", @"unset", @"revert", @"revert-layer"] containsObject:origin.lowercaseString] ||
                IJSVGTransformOriginFromString(origin) != nil;
        };
        handlers[IJSVGAttributeTransformBox] = ^BOOL(NSString* box, NSDictionary** values) {
            return [@[@"view-box", @"fill-box", @"stroke-box", @"content-box", @"border-box",
                      @"inherit", @"initial", @"unset", @"revert", @"revert-layer"] containsObject:box.lowercaseString];
        };
        expanders = [handlers copy];
    });
    NSString* name = [property hasPrefix:@"--"] ? property : property.lowercaseString;
    IJSVGStyleSheetDeclarationExpander expander = expanders[name];
    *expanded = nil;
    return expander == nil || expander(value, expanded) ? name : nil;
}

NSDictionary<NSString*, NSString*>* IJSVGStyleSheetExpandDeclaration(NSString* property,
                                                                     NSString* value)
{
    NSDictionary* expanded = nil;
    NSString* name = IJSVGStyleSheetResolveDeclaration(property, value, &expanded);
    if(name == nil) {
        return @{};
    }
    if(expanded == nil) {
        return @{name: value};
    }
    NSMutableDictionary* declarations = [expanded mutableCopy];
    declarations[name] = value;
    return declarations;
}
