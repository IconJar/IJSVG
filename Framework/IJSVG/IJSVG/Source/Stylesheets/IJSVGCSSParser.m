//
//  IJSVGCSSParser.m
//  IJSVG
//
//  Created by Curtis Hard on 12/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGCSSParser.h>
#import <IJSVGParserUtils.h>
#import <IJSVGStyleSheetUtils.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGParsing.h>

IJSVGCSSWideKeyword IJSVGCSSWideKeywordFromString(NSString* value)
{
    IJSVGStringBytes source = IJSVGStringGetBytes(value);
    if(source.bytes == NULL) {
        return IJSVGCSSWideKeywordUnknown;
    }
    switch(source.length) {
        case 5: {
            if(IJSVGCharBufferCaseInsensitiveCompare(source.bytes, "unset")) {
                return IJSVGCSSWideKeywordUnset;
            }
            break;
        }
        case 6: {
            if(IJSVGCharBufferCaseInsensitiveCompare(source.bytes, "revert")) {
                return IJSVGCSSWideKeywordRevert;
            }
            break;
        }
        case 7: {
            if(IJSVGCharBufferCaseInsensitiveCompare(source.bytes, "inherit")) {
                return IJSVGCSSWideKeywordInherit;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(source.bytes, "initial")) {
                return IJSVGCSSWideKeywordInitial;
            }
            break;
        }
        case 12: {
            if(IJSVGCharBufferCaseInsensitiveCompare(source.bytes, "revert-layer")) {
                return IJSVGCSSWideKeywordRevertLayer;
            }
            break;
        }
        default: {
            break;
        }
    }
    return IJSVGCSSWideKeywordUnknown;
}

IJSVGCSSFunction IJSVGCSSFunctionForName(const char* name)
{
    if(name == NULL) {
        return IJSVGCSSFunctionUnknown;
    }
    char normalized[11];
    NSUInteger index = 0;
    do {
        if(index == sizeof(normalized)) {
            return IJSVGCSSFunctionUnknown;
        }
        normalized[index] = IJSVGCharToLower(name[index]);
    } while(normalized[index++] != '\0');
    switch(index - 1) {
        case 3:
            if(strcmp(normalized, "url") == 0) {
                return IJSVGCSSFunctionURL;
            }
            if(strcmp(normalized, "var") == 0) {
                return IJSVGCSSFunctionVar;
            }
            if(strcmp(normalized, "min") == 0) {
                return IJSVGCSSFunctionMin;
            }
            if(strcmp(normalized, "max") == 0) {
                return IJSVGCSSFunctionMax;
            }
            if(strcmp(normalized, "rgb") == 0) {
                return IJSVGCSSFunctionRGB;
            }
            if(strcmp(normalized, "hsl") == 0) {
                return IJSVGCSSFunctionHSL;
            }
            break;
        case 4:
            if(strcmp(normalized, "calc") == 0) {
                return IJSVGCSSFunctionCalc;
            }
            if(strcmp(normalized, "rect") == 0) {
                return IJSVGCSSFunctionRect;
            }
            if(strcmp(normalized, "rgba") == 0) {
                return IJSVGCSSFunctionRGBA;
            }
            if(strcmp(normalized, "hsla") == 0) {
                return IJSVGCSSFunctionHSLA;
            }
            if(strcmp(normalized, "path") == 0) {
                return IJSVGCSSFunctionPath;
            }
            if(strcmp(normalized, "xywh") == 0) {
                return IJSVGCSSFunctionXYWH;
            }
            break;
        case 5:
            if(strcmp(normalized, "clamp") == 0) {
                return IJSVGCSSFunctionClamp;
            }
            if(strcmp(normalized, "shape") == 0) {
                return IJSVGCSSFunctionShape;
            }
            if(strcmp(normalized, "scale") == 0) {
                return IJSVGCSSFunctionScale;
            }
            if(strcmp(normalized, "skewx") == 0) {
                return IJSVGCSSFunctionSkewX;
            }
            if(strcmp(normalized, "skewy") == 0) {
                return IJSVGCSSFunctionSkewY;
            }
            if(strcmp(normalized, "inset") == 0) {
                return IJSVGCSSFunctionInset;
            }
            if(strcmp(normalized, "oklch") == 0) {
                return IJSVGCSSFunctionOKLCH;
            }
            break;
        case 6:
            if(strcmp(normalized, "circle") == 0) {
                return IJSVGCSSFunctionCircle;
            }
            if(strcmp(normalized, "matrix") == 0) {
                return IJSVGCSSFunctionMatrix;
            }
            if(strcmp(normalized, "rotate") == 0) {
                return IJSVGCSSFunctionRotate;
            }
            break;
        case 7:
            if(strcmp(normalized, "polygon") == 0) {
                return IJSVGCSSFunctionPolygon;
            }
            if(strcmp(normalized, "ellipse") == 0) {
                return IJSVGCSSFunctionEllipse;
            }
            break;
        case 9:
            if(strcmp(normalized, "translate") == 0) {
                return IJSVGCSSFunctionTranslate;
            }
            break;
        case 10:
            if(strcmp(normalized, "translatex") == 0) {
                return IJSVGCSSFunctionTranslateX;
            }
            if(strcmp(normalized, "translatey") == 0) {
                return IJSVGCSSFunctionTranslateY;
            }
            break;
        default:
            break;
    }
    return IJSVGCSSFunctionUnknown;
}

BOOL IJSVGCSSFunctionIsCalculation(IJSVGCSSFunction function)
{
    return function >= IJSVGCSSFunctionCalc && function <= IJSVGCSSFunctionClamp;
}

static IJSVGCSSNumericKeyword IJSVGCSSNumericKeywordForName(const char* name)
{
    static const char* names[] = { "", "pi", "e", "infinity", "-infinity", "NaN", "none" };
    for(NSUInteger index = IJSVGCSSNumericKeywordPi; index <= IJSVGCSSNumericKeywordNone; index++) {
        if(IJSVGCharBufferCaseInsensitiveCompare(name, names[index])) {
            return (IJSVGCSSNumericKeyword)index;
        }
    }
    return IJSVGCSSNumericKeywordUnknown;
}

enum {
    IJSVGCSSParserMaximumDepth = 64,
    IJSVGCSSParserMaximumCount = 4096,
    IJSVGCSSParserMaximumBytes = 65536
};

typedef struct {
    const char* bytes;
    NSUInteger length;
    NSUInteger index;
    NSUInteger capacity;
    IJSVGCSSComponents* components;
    IJSVGCSSParserOptions options;
} IJSVGCSSParserCursor;

static BOOL IJSVGCSSParserNameStart(char c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
        c == '_' || (unsigned char)c >= 0x80;
}

// Names use stack storage and share stylesheet escape validation.
static BOOL IJSVGCSSParserConsumeName(IJSVGCSSParserCursor* cursor, char name[32])
{
    NSUInteger start = cursor->index;
    NSUInteger index = start;
    if(index < cursor->length && cursor->bytes[index] == '-') {
        index++;
    }
    if(index == cursor->length || (!IJSVGCSSParserNameStart(cursor->bytes[index]) &&
       cursor->bytes[index] != '\\' && cursor->bytes[index] != '-')) {
        return NO;
    }
    while(index < cursor->length) {
        char c = cursor->bytes[index];
        if(c == '\\') {
            cursor->index = start;
            return IJSVGStyleSheetConsumeASCIIIdentifier(cursor->bytes, cursor->length,
                &cursor->index, name, 32);
        }
        if(!IJSVGCSSParserNameStart(c) && c != '-' && !(c >= '0' && c <= '9')) {
            break;
        }
        index++;
    }
    NSUInteger length = index - start;
    name[0] = '\0';
    if(length < 32) {
        memcpy(name, cursor->bytes + start, length);
        name[length] = '\0';
    }
    cursor->index = index;
    return YES;
}

static BOOL IJSVGCSSParserAppend(IJSVGCSSParserCursor* cursor, IJSVGCSSComponent component,
                                 NSUInteger* index)
{
    IJSVGCSSComponents* components = cursor->components;
    if(components->count == IJSVGCSSParserMaximumCount) {
        return NO;
    }
    if(components->count == cursor->capacity) {
        NSUInteger capacity = cursor->capacity * 2;
        BOOL usesInlineValues = components->values == components->inlineValues;
        IJSVGCSSComponent* values = usesInlineValues
            ? malloc(capacity * sizeof(*values))
            : realloc(components->values, capacity * sizeof(*values));
        if(values == NULL) {
            return NO;
        }
        if(usesInlineValues) {
            memcpy(values, components->values, components->count * sizeof(*values));
        }
        components->values = values;
        cursor->capacity = capacity;
    }
    *index = components->count++;
    components->values[*index] = component;
    return YES;
}

static BOOL IJSVGCSSParserConsumeURL(IJSVGCSSParserCursor* cursor)
{
    const char* bytes = cursor->bytes;
    while(cursor->index < cursor->length && IJSVGStyleSheetCharIsWhitespace(bytes[cursor->index])) {
        cursor->index++;
    }
    if(cursor->index < cursor->length && (bytes[cursor->index] == '\'' || bytes[cursor->index] == '"')) {
        if(!IJSVGStyleSheetSkipQuotedString(bytes, cursor->length, &cursor->index)) {
            return NO;
        }
        while(cursor->index < cursor->length && IJSVGStyleSheetCharIsWhitespace(bytes[cursor->index])) {
            cursor->index++;
        }
        if(cursor->index == cursor->length || bytes[cursor->index] != ')') {
            return NO;
        }
        cursor->index++;
        return YES;
    }
    while(cursor->index < cursor->length) {
        char c = bytes[cursor->index];
        if(c == ')') {
            cursor->index++;
            return YES;
        }
        if(IJSVGStyleSheetCharIsWhitespace(c)) {
            do {
                cursor->index++;
            } while(cursor->index < cursor->length &&
                    IJSVGStyleSheetCharIsWhitespace(bytes[cursor->index]));
            if(cursor->index == cursor->length || bytes[cursor->index] != ')') {
                return NO;
            }
            continue;
        }
        if(c == '(' || c == '\'' || c == '"' || (unsigned char)c < ' ' || c == '\x7f') {
            return NO;
        }
        if(c == '\\') {
            if(!IJSVGStyleSheetSkipEscape(bytes, cursor->length, &cursor->index, NO)) {
                return NO;
            }
        } else {
            cursor->index++;
        }
    }
    return NO;
}

static void IJSVGCSSParserConsumeNumericComponent(IJSVGCSSParserCursor* cursor,
                                                  const char* numberEnd, CGFloat number,
                                                  IJSVGCSSComponent* component)
{
    const char* bytes = cursor->bytes;
    NSUInteger start = cursor->index;
    cursor->index = numberEnd - bytes;
    component->number = number;
    component->kind = IJSVGCSSComponentNumber;
    if(bytes[start] == '-') {
        for(const char* digit = bytes + start + 1; digit < numberEnd &&
            *digit != 'e' && *digit != 'E'; digit++) {
            component->negativeNonzero |= *digit >= '1' && *digit <= '9';
        }
    }
    char name[32];
    if(IJSVGCSSParserConsumeName(cursor, name)) {
        component->kind = IJSVGCSSComponentDimension;
        NSUInteger nameLength = strlen(name);
        component->unit = nameLength == 2 ? IJSVGUnitLengthTypeForCString(name)
            : IJSVGUnitLengthTypeNumber;
        if(nameLength == 3 || nameLength == 4) {
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "deg")) {
                component->angleUnit = IJSVGCSSAngleUnitDegrees;
            } else if(IJSVGCharBufferCaseInsensitiveCompare(name, "rad")) {
                component->angleUnit = IJSVGCSSAngleUnitRadians;
            } else if(IJSVGCharBufferCaseInsensitiveCompare(name, "grad")) {
                component->angleUnit = IJSVGCSSAngleUnitGradians;
            } else if(IJSVGCharBufferCaseInsensitiveCompare(name, "turn")) {
                component->angleUnit = IJSVGCSSAngleUnitTurns;
            }
        }
    } else if(cursor->index < cursor->length && bytes[cursor->index] == '%') {
        cursor->index++;
        component->kind = IJSVGCSSComponentPercentage;
        component->unit = IJSVGUnitLengthTypePercentage;
    }
}

static void IJSVGCSSParserConsumeNamedComponent(IJSVGCSSParserCursor* cursor,
                                                IJSVGCSSComponent* component,
                                                char* childClosing)
{
    const char* bytes = cursor->bytes;
    char name[32];
    if(IJSVGCSSParserConsumeName(cursor, name)) {
        NSUInteger nameEnd = cursor->index;
        if(cursor->options & IJSVGCSSParserOptionSVG) {
            while(cursor->index < cursor->length &&
                  IJSVGStyleSheetCharIsWhitespace(bytes[cursor->index])) {
                cursor->index++;
            }
            if(cursor->index == cursor->length || bytes[cursor->index] != '(') {
                cursor->index = nameEnd;
            }
        }
        if(cursor->index < cursor->length && bytes[cursor->index] == '(') {
            cursor->index++;
            component->kind = IJSVGCSSComponentFunction;
            component->function = IJSVGCSSFunctionForName(name);
            *childClosing = ')';
            component->argumentOffset = (uint32_t)cursor->index;
        } else {
            component->kind = IJSVGCSSComponentIdentifier;
            component->numericKeyword = IJSVGCSSNumericKeywordForName(name);
        }
    } else {
        component->kind = IJSVGCSSComponentDelimiter;
        component->symbol = (IJSVGCSSSymbol)bytes[cursor->index++];
    }
}

static BOOL IJSVGCSSParserConsumeComponent(IJSVGCSSParserCursor* cursor,
                                           IJSVGCSSComponent* component,
                                           char* childClosing)
{
    const char* bytes = cursor->bytes;
    char c = bytes[cursor->index];
    if(c == '\'' || c == '"') {
        component->kind = IJSVGCSSComponentString;
        return IJSVGStyleSheetSkipQuotedString(bytes, cursor->length,
                                               &cursor->index);
    }
    if(c == '(' || c == '[' || c == '{') {
        cursor->index++;
        component->kind = IJSVGCSSComponentBlock;
        component->symbol = (IJSVGCSSSymbol)c;
        *childClosing = c == '(' ? ')' : (c == '[' ? ']' : '}');
        return YES;
    }
    const char* numberEnd = bytes + cursor->index;
    CGFloat number;
    BOOL startsNumber = (c >= '0' && c <= '9') || c == '.' || c == '+' || c == '-';
    if(startsNumber && IJSVGParseLengthNumber(&numberEnd, YES, &number)) {
        if(numberEnd[-1] == '.' && !(cursor->options & IJSVGCSSParserOptionSVG)) {
            return NO;
        }
        IJSVGCSSParserConsumeNumericComponent(cursor, numberEnd, number,
                                              component);
    } else {
        IJSVGCSSParserConsumeNamedComponent(cursor, component, childClosing);
    }
    return YES;
}

static BOOL IJSVGCSSParseComponents(IJSVGCSSParserCursor* cursor, char closing,
                                    NSUInteger depth)
{
    if(depth > IJSVGCSSParserMaximumDepth) {
        return NO;
    }
    BOOL whitespace = NO;
    while(cursor->index < cursor->length) {
        const char* bytes = cursor->bytes;
        char c = bytes[cursor->index];
        if(IJSVGStyleSheetCharIsWhitespace(c)) {
            whitespace = YES;
            cursor->index++;
            continue;
        }
        if(c == '/' && cursor->index + 1 < cursor->length && bytes[cursor->index + 1] == '*') {
            cursor->index += 2;
            while(cursor->index + 1 < cursor->length &&
                  !(bytes[cursor->index] == '*' && bytes[cursor->index + 1] == '/')) {
                cursor->index++;
            }
            if(cursor->index + 1 >= cursor->length) {
                return NO;
            }
            cursor->index += 2;
            // Comments separate tokens but are not CSS whitespace.
            continue;
        }
        if(c == ')' || c == ']' || c == '}') {
            if(c != closing) {
                return NO;
            }
            cursor->index++;
            return YES;
        }
        IJSVGCSSComponent component = { 0 };
        component.precedingWhitespace = whitespace;
        whitespace = NO;
        char childClosing = 0;
        NSUInteger start = cursor->index;
        component.offset = (uint32_t)start;
        if(!IJSVGCSSParserConsumeComponent(cursor, &component, &childClosing)) {
            return NO;
        }
        if(cursor->components->count == 0 &&
           (cursor->options & IJSVGCSSParserOptionLeadingURL) &&
           (component.kind != IJSVGCSSComponentFunction || component.function != IJSVGCSSFunctionURL)) {
            return NO;
        }
        NSUInteger index;
        if(!IJSVGCSSParserAppend(cursor, component, &index)) {
            return NO;
        }
        if(childClosing != 0) {
            BOOL valid = component.function == IJSVGCSSFunctionURL
                ? IJSVGCSSParserConsumeURL(cursor)
                : IJSVGCSSParseComponents(cursor, childClosing, depth + 1);
            if(!valid) {
                return NO;
            }
        }
        IJSVGCSSComponent* stored = cursor->components->values + index;
        stored->next = cursor->components->count;
        stored->length = (uint32_t)(cursor->index - start);
        if(stored->kind == IJSVGCSSComponentFunction) {
            stored->argumentLength = (uint32_t)(cursor->index - stored->argumentOffset - 1);
        }
    }
    return closing == 0;
}

BOOL IJSVGCSSComponentsCreate(const char* bytes, NSUInteger length,
                              IJSVGCSSComponents* components)
{
    return IJSVGCSSComponentsCreateWithOptions(bytes, length,
                                               IJSVGCSSParserOptionNone,
                                               components);
}

BOOL IJSVGCSSComponentsCreateWithOptions(const char* bytes, NSUInteger length,
                                         IJSVGCSSParserOptions options,
                                         IJSVGCSSComponents* components)
{
    components->values = NULL;
    components->count = 0;
    components->bytes = NULL;
    if(bytes == NULL || length > IJSVGCSSParserMaximumBytes || strlen(bytes) != length) {
        return NO;
    }
    components->bytes = bytes;
    components->values = components->inlineValues;
    IJSVGCSSParserCursor cursor = {
      bytes, length, 0, IJSVGCSSParserInlineCapacity, components, options
    };
    return IJSVGCSSParseComponents(&cursor, 0, 0);
}

char* IJSVGCSSComponentCopyArguments(const IJSVGCSSComponents* components,
                                     const IJSVGCSSComponent* component)
{
    return strndup(components->bytes + component->argumentOffset,
                   component->argumentLength);
}

static BOOL IJSVGCSSParsePathData(NSString* value, NSString** result)
{
    IJSVGStringBytes source = IJSVGStringGetBytes(value);
    IJSVGCSSComponents components;
    BOOL valid = NO;
    if(IJSVGCSSComponentsCreate(source.bytes, source.length, &components)) {
        const IJSVGCSSComponent* root = components.values;
        if(components.count == 1 && root->kind == IJSVGCSSComponentIdentifier &&
           root->numericKeyword == IJSVGCSSNumericKeywordNone) {
            valid = YES;
            if(result != NULL) {
                *result = @"";
            }
        } else if(components.count == 2 && root->kind == IJSVGCSSComponentFunction &&
                  root->function == IJSVGCSSFunctionPath && root->next == components.count &&
                  components.values[1].kind == IJSVGCSSComponentString) {
            valid = YES;
            if(result != NULL) {
                const IJSVGCSSComponent* string = components.values + 1;
                *result = IJSVGStyleSheetDecodeString(source.bytes, string->offset,
                                                      string->offset + string->length);
                valid = *result != nil;
            }
        }
    }
    IJSVGCSSComponentsRelease(&components);
    return valid;
}

BOOL IJSVGCSSPathDataIsValid(NSString* value)
{
    return IJSVGCSSParsePathData(value, NULL);
}

NSString* IJSVGCSSPathDataFromString(NSString* value)
{
    NSString* result = nil;
    IJSVGCSSParsePathData(value, &result);
    return result;
}

void IJSVGCSSComponentsRelease(IJSVGCSSComponents* components)
{
    if(components->values != components->inlineValues) {
        free(components->values);
    }
    components->values = NULL;
    components->count = 0;
    components->bytes = NULL;
}
