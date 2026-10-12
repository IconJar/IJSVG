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

IJSVGCSSFunction IJSVGCSSFunctionForName(const char* name)
{
    if(name == NULL) {
        return IJSVGCSSFunctionUnknown;
    }
    switch(IJSVGCharToLower(name[0])) {
        case 'c': {
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "calc")) {
                return IJSVGCSSFunctionCalc;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "clamp")) {
                return IJSVGCSSFunctionClamp;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "circle")) {
                return IJSVGCSSFunctionCircle;
            }
            break;
        }
        case 'm': {
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "min")) {
                return IJSVGCSSFunctionMin;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "max")) {
                return IJSVGCSSFunctionMax;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "matrix")) {
                return IJSVGCSSFunctionMatrix;
            }
            break;
        }
        case 'r': {
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "rgb")) {
                return IJSVGCSSFunctionRGB;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "rgba")) {
                return IJSVGCSSFunctionRGBA;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "rotate")) {
                return IJSVGCSSFunctionRotate;
            }
            break;
        }
        case 'h': {
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "hsl")) {
                return IJSVGCSSFunctionHSL;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "hsla")) {
                return IJSVGCSSFunctionHSLA;
            }
            break;
        }
        case 's': {
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "scale")) {
                return IJSVGCSSFunctionScale;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "skewx")) {
                return IJSVGCSSFunctionSkewX;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "skewy")) {
                return IJSVGCSSFunctionSkewY;
            }
            break;
        }
        case 't': {
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "translate")) {
                return IJSVGCSSFunctionTranslate;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "translatex")) {
                return IJSVGCSSFunctionTranslateX;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(name, "translatey")) {
                return IJSVGCSSFunctionTranslateY;
            }
            break;
        }
        case 'u': {
            return IJSVGCharBufferCaseInsensitiveCompare(name, "url")
                ? IJSVGCSSFunctionURL : IJSVGCSSFunctionUnknown;
        }
        case 'o': {
            return IJSVGCharBufferCaseInsensitiveCompare(name, "oklch")
                ? IJSVGCSSFunctionOKLCH : IJSVGCSSFunctionUnknown;
        }
        case 'e': {
            return IJSVGCharBufferCaseInsensitiveCompare(name, "ellipse")
                ? IJSVGCSSFunctionEllipse : IJSVGCSSFunctionUnknown;
        }
        default: {
            break;
        }
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
    c = IJSVGCharToLower(c);
    return (c >= 'a' && c <= 'z') || c == '_' || (unsigned char)c >= 0x80;
}

// Common ASCII names never allocate. Escaped names reuse the stylesheet decoder.
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
            NSUInteger end = start;
            NSString* decoded = IJSVGStyleSheetConsumeIdentifier(cursor->bytes,
                                                                 cursor->length, &end);
            if(decoded == nil) {
                return NO;
            }
            const char* bytes = decoded.UTF8String;
            size_t length = strlen(bytes);
            name[0] = '\0';
            if(length < 32) {
                memcpy(name, bytes, length + 1);
            }
            cursor->index = end;
            return YES;
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
        NSUInteger capacity = cursor->capacity == 0 ? 32 : cursor->capacity * 2;
        IJSVGCSSComponent* values = realloc(components->values, capacity * sizeof(*values));
        if(values == NULL) {
            return NO;
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
        if(c == '\'' || c == '"') {
            if(!IJSVGStyleSheetSkipQuotedString(bytes, cursor->length,
                                                &cursor->index)) {
                return NO;
            }
            component.kind = IJSVGCSSComponentString;
        } else if(c == '(' || c == '[' || c == '{') {
            cursor->index++;
            component.kind = IJSVGCSSComponentBlock;
            component.symbol = (IJSVGCSSSymbol)c;
            childClosing = c == '(' ? ')' : (c == '[' ? ']' : '}');
        } else {
            const char* numberEnd = bytes + start;
            CGFloat number;
            if(IJSVGParseLengthNumber(&numberEnd, YES, &number)) {
                if(numberEnd[-1] == '.' && !(cursor->options & IJSVGCSSParserOptionSVG)) {
                    return NO;
                }
                cursor->index = numberEnd - bytes;
                component.number = number;
                component.kind = IJSVGCSSComponentNumber;
                if(bytes[start] == '-') {
                    for(const char* digit = bytes + start + 1; digit < numberEnd &&
                        *digit != 'e' && *digit != 'E'; digit++) {
                        component.negativeNonzero |= *digit >= '1' && *digit <= '9';
                    }
                }
                char name[32];
                if(IJSVGCSSParserConsumeName(cursor, name)) {
                    component.kind = IJSVGCSSComponentDimension;
                    NSUInteger nameLength = strlen(name);
                    component.unit = nameLength == 2 ? IJSVGUnitLengthTypeForCString(name)
                        : IJSVGUnitLengthTypeNumber;
                    if(nameLength == 3 || nameLength == 4) {
                        if(IJSVGCharBufferCaseInsensitiveCompare(name, "deg")) {
                            component.angleUnit = IJSVGCSSAngleUnitDegrees;
                        } else if(IJSVGCharBufferCaseInsensitiveCompare(name, "rad")) {
                            component.angleUnit = IJSVGCSSAngleUnitRadians;
                        } else if(IJSVGCharBufferCaseInsensitiveCompare(name, "grad")) {
                            component.angleUnit = IJSVGCSSAngleUnitGradians;
                        } else if(IJSVGCharBufferCaseInsensitiveCompare(name, "turn")) {
                            component.angleUnit = IJSVGCSSAngleUnitTurns;
                        }
                    }
                } else if(cursor->index < cursor->length && bytes[cursor->index] == '%') {
                    cursor->index++;
                    component.kind = IJSVGCSSComponentPercentage;
                    component.unit = IJSVGUnitLengthTypePercentage;
                }
            } else {
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
                        component.kind = IJSVGCSSComponentFunction;
                        component.function = IJSVGCSSFunctionForName(name);
                        childClosing = ')';
                        component.argumentOffset = (uint32_t)cursor->index;
                    } else {
                        component.kind = IJSVGCSSComponentIdentifier;
                        component.numericKeyword = IJSVGCSSNumericKeywordForName(name);
                    }
                } else {
                    component.kind = IJSVGCSSComponentDelimiter;
                    component.symbol = (IJSVGCSSSymbol)bytes[cursor->index++];
                }
            }
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

BOOL IJSVGCSSComponentsCreate(const char* bytes,
                              IJSVGCSSComponents* components)
{
    return IJSVGCSSComponentsCreateWithOptions(bytes, IJSVGCSSParserOptionNone, components);
}

BOOL IJSVGCSSComponentsCreateWithOptions(const char* bytes,
                                         IJSVGCSSParserOptions options,
                                         IJSVGCSSComponents* components)
{
    *components = (IJSVGCSSComponents){ 0 };
    if(bytes == NULL) {
        return NO;
    }
    NSUInteger length = strlen(bytes);
    if(length > IJSVGCSSParserMaximumBytes) {
        return NO;
    }
    components->bytes = bytes;
    IJSVGCSSParserCursor cursor = { bytes, length, 0, 0, components, options };
    return IJSVGCSSParseComponents(&cursor, 0, 0);
}

char* IJSVGCSSComponentCopyArguments(const IJSVGCSSComponents* components,
                                     const IJSVGCSSComponent* component)
{
    return strndup(components->bytes + component->argumentOffset,
                   component->argumentLength);
}

void IJSVGCSSComponentsRelease(IJSVGCSSComponents* components)
{
    free(components->values);
    *components = (IJSVGCSSComponents){ 0 };
}
