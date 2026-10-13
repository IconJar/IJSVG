//
//  IJSVGParserUtils.m
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
#import <IJSVG/IJSVGCircle.h>
#import <IJSVG/IJSVGCommandParser.h>
#import <IJSVG/IJSVGEllipse.h>
#import <IJSVG/IJSVGGraphicsNode.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGRoundedShape.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGCSSMathExpression.h>
#import <IJSVGCSSParser.h>
#import <IJSVGParserUtils.h>
#import <string.h>

uint64_t IJSVGTextStyleBit(NSUInteger attribute)
{
    if (attribute >= IJSVGNodeAttributeFont && attribute <= IJSVGNodeAttributeFontSizeAdjust) {
        return UINT64_C(1) << (attribute - IJSVGNodeAttributeFont);
    }
    return attribute == IJSVGNodeAttributeTextRendering ? UINT64_C(1) << 63 : 0;
}

IJSVGUnitLength* IJSVGScalarLengthFromBytes(const char* bytes, NSUInteger length, BOOL allowNegative, IJSVGUnitType units)
{
    const char* end = bytes + length;
    const char* position = bytes;
    CGFloat value = 0;
    if (!IJSVGParseLengthNumberInRange(&position, end, allowNegative, &value)) {
        return nil;
    }
    IJSVGUnitLengthType originalType = IJSVGUnitLengthTypeNumber;
    if (position < end && *position == '%') {
        originalType = IJSVGUnitLengthTypePercentage;
        value /= 100.f;
        position++;
    }
    if (position != end) {
        return nil;
    }
    IJSVGUnitLengthType type = units == IJSVGUnitObjectBoundingBox ? IJSVGUnitLengthTypePercentage : originalType;
    return [IJSVGUnitLength unitWithFloat:value type:type originalType:originalType inherit:NO];
}

IJSVGUnitLength* IJSVGUnitLengthFromXMLAttribute(IJSVGXMLAttribute* attribute, IJSVGUnitType units)
{
    if (attribute == NULL) {
        return nil;
    }
    IJSVGUnitLength* length = IJSVGScalarLengthFromBytes(IJSVGXMLAttributeBytes(attribute), attribute->value.length, YES, units);
    return length ?: [IJSVGUnitLength unitWithString:IJSVGXMLAttributeValue(attribute) fromUnitType:units];
}

BOOL IJSVGXMLAttributeEquals(IJSVGXMLAttribute* attribute, const char* value)
{
    return attribute != NULL && attribute->value.length == strlen(value) && memcmp(IJSVGXMLAttributeBytes(attribute), value, attribute->value.length) == 0;
}

BOOL IJSVGParseHexColorBytes(const char* bytes, NSUInteger length, uint32_t* rgba)
{
    if ((length != 4 && length != 5 && length != 7 && length != 9) || bytes[0] != '#') {
        return NO;
    }
    BOOL shorthand = length <= 5;
    uint32_t result = 0;
    for (NSUInteger index = 1; index < length; index++) {
        unsigned char character = bytes[index];
        unsigned int digit;
        if (character >= '0' && character <= '9') {
            digit = character - '0';
        } else if (character >= 'a' && character <= 'f') {
            digit = character - 'a' + 10;
        } else if (character >= 'A' && character <= 'F') {
            digit = character - 'A' + 10;
        } else {
            return NO;
        }
        result = shorthand ? (result << 8) | (digit * 17) : (result << 4) | digit;
    }
    *rgba = length == 4 || length == 7 ? (result << 8) | 255 : result;
    return YES;
}

static BOOL IJSVGLengthListIsWhitespace(char character)
{
    return character == ' ' || character == '\t' || character == '\r' || character == '\n';
}

static BOOL IJSVGLengthListIsDigit(char character)
{
    return character >= '0' && character <= '9';
}

BOOL IJSVGParseLengthNumberInRange(const char** position, const char* end, BOOL allowNegative, CGFloat* value)
{
    const char* cursor = *position;
    if (cursor == NULL || end == NULL || cursor >= end) {
        return NO;
    }
    const char* number = cursor;
    BOOL negative = *cursor == '-';
    if (*cursor == '+' || negative) {
        cursor++;
    }
    BOOL rejectsNegative = negative && !allowNegative;
    const char* digits = cursor;
    double scalar = 0;
    while (cursor < end && IJSVGLengthListIsDigit(*cursor)) {
        if (rejectsNegative && *cursor != '0') {
            return NO;
        }
        scalar = scalar * 10.f + (*cursor++ - '0');
    }
    BOOL hasDigits = cursor != digits;
    if (cursor < end && *cursor == '.') {
        digits = ++cursor;
        double scale = 10.f;
        while (cursor < end && IJSVGLengthListIsDigit(*cursor)) {
            // Check the mantissa before conversion can underflow.
            if (rejectsNegative && *cursor != '0') {
                return NO;
            }
            scalar += (*cursor++ - '0') / scale;
            scale *= 10.f;
        }
        hasDigits |= cursor != digits;
    }
    if (!hasDigits) {
        return NO;
    }

    // The letter e starts an exponent only when digits follow. em/ex are units.
    BOOL hasExponent = NO;
    if (cursor < end && (*cursor == 'e' || *cursor == 'E')) {
        const char* exponent = cursor + 1;
        if (exponent < end && (*exponent == '+' || *exponent == '-')) {
            exponent++;
        }
        if (exponent < end && IJSVGLengthListIsDigit(*exponent)) {
            hasExponent = YES;
            cursor = exponent + 1;
            while (cursor < end && IJSVGLengthListIsDigit(*cursor)) {
                cursor++;
            }
        }
    }
    if (hasExponent) {
        scalar = IJSVGParseFloatWithLength(number, (NSUInteger)(cursor - number));
    } else if (negative) {
        scalar = -scalar;
    }
    CGFloat converted = (CGFloat)scalar;
    if (!isfinite(converted)) {
        return NO;
    }
    *value = converted;
    *position = cursor;
    return YES;
}

BOOL IJSVGParseLengthNumber(const char** position, BOOL allowNegative, CGFloat* value)
{
    const char* bytes = *position;
    return bytes != NULL && IJSVGParseLengthNumberInRange(position, bytes + strlen(bytes), allowNegative, value);
}

static BOOL IJSVGParseUnitLengthsFromBytes(const char* string, NSUInteger byteLength, BOOL allowNegative, BOOL single, NSMutableArray<IJSVGUnitLength*>* lengths, IJSVGUnitLength** singleLength);

static BOOL IJSVGParseCSSUnitLengths(const char* string, NSUInteger byteLength, BOOL allowNegative, BOOL single, NSMutableArray<IJSVGUnitLength*>* lengths, IJSVGUnitLength** singleLength)
{
    IJSVGCSSComponents components;
    BOOL valid = IJSVGCSSComponentsCreate(string, byteLength, &components);
    NSUInteger count = 0;
    BOOL afterComma = NO;
    BOOL validatesOnly = lengths == nil && singleLength == NULL;
    IJSVGUnitLength* length = nil;
    for (NSUInteger index = 0; valid && index < components.count;) {
        const IJSVGCSSComponent* component = components.values + index;
        if (component->kind == IJSVGCSSComponentDelimiter && component->symbol == IJSVGCSSSymbolComma) {
            if (count == 0 || afterComma || single) {
                valid = NO;
                break;
            }
            afterComma = YES;
            index = component->next;
            continue;
        }
        if (count != 0 && (single || (!afterComma && !component->precedingWhitespace))) {
            valid = NO;
            break;
        }
        length = nil;
        if (component->kind == IJSVGCSSComponentFunction) {
            if (validatesOnly) {
                valid = IJSVGCSSMathExpressionIsValid(&components, index);
            } else {
                length = [IJSVGUnitLength unitWithCalculationComponents:&components atIndex:index allowNegative:allowNegative];
            }
        } else if (component->kind == IJSVGCSSComponentNumber || component->kind == IJSVGCSSComponentDimension || component->kind == IJSVGCSSComponentPercentage) {
            IJSVGUnitLengthType type = component->unit;
            CGFloat scalar = IJSVGConvertUnitValue(component->number, type);
            if ((component->kind == IJSVGCSSComponentDimension && type == IJSVGUnitLengthTypeNumber) || !isfinite(scalar) || (!allowNegative && component->negativeNonzero)) {
                valid = NO;
                break;
            }
            IJSVGUnitLengthType resolved = type == IJSVGUnitLengthTypePercentage || type == IJSVGUnitLengthTypeEM || type == IJSVGUnitLengthTypeEX ? type : IJSVGUnitLengthTypeNumber;
            if (!validatesOnly) {
                length = [IJSVGUnitLength unitWithFloat:scalar type:resolved originalType:type inherit:NO];
            }
        } else {
            valid = NO;
        }
        if (!valid || (!validatesOnly && length == nil)) {
            valid = NO;
            break;
        }
        [lengths addObject:length];
        afterComma = NO;
        count++;
        index = component->next;
    }
    valid = valid && count != 0 && !afterComma;
    if (singleLength != NULL) {
        *singleLength = valid && count == 1 ? length : nil;
    }
    IJSVGCSSComponentsRelease(&components);
    return valid;
}

static BOOL IJSVGParseUnitLengthsFromBytes(const char* string, NSUInteger byteLength, BOOL allowNegative, BOOL single, NSMutableArray<IJSVGUnitLength*>* lengths, IJSVGUnitLength** singleLength)
{
    if (string == NULL || byteLength == 0 || memchr(string, 0, byteLength) != NULL) {
        return NO;
    }
    if (memchr(string, '(', byteLength) != NULL || memchr(string, '\\', byteLength) != NULL || memchr(string, '/', byteLength) != NULL) {
        return IJSVGParseCSSUnitLengths(string, byteLength, allowNegative, single, lengths, singleLength);
    }
    const char* cursor = string;
    const char* end = string + byteLength;
    IJSVGUnitLength* parsedLength = nil;
    NSUInteger count = 0;
    BOOL valid = YES;
    while (cursor < end && IJSVGLengthListIsWhitespace(*cursor)) {
        cursor++;
    }
    while (cursor < end) {
        CGFloat scalar;
        if (!IJSVGParseLengthNumberInRange(&cursor, end, allowNegative, &scalar)) {
            valid = NO;
            break;
        }
        const char* suffix = cursor;
        while (cursor < end && *cursor != ',' && !IJSVGLengthListIsWhitespace(*cursor)) {
            cursor++;
        }
        size_t suffixLength = cursor - suffix;
        if (suffixLength > 2) {
            valid = NO;
            break;
        }
        char unit[3] = { 0 };
        memcpy(unit, suffix, suffixLength);
        IJSVGUnitLengthType type = IJSVGUnitLengthTypeForCString(unit);
        if (suffixLength != 0 && (type == IJSVGUnitLengthTypeNumber || (type == IJSVGUnitLengthTypePercentage ? suffixLength != 1 : suffixLength != 2))) {
            valid = NO;
            break;
        }
        scalar = [IJSVGUnitLength convertUnitValue:scalar toBaseFromUnitLengthType:type];
        if (!isfinite(scalar) || (!allowNegative && scalar < 0.f)) {
            valid = NO;
            break;
        }
        count++;
        if (single && count > 1) {
            return NO;
        }
        if (lengths != nil || singleLength != NULL) {
            IJSVGUnitLengthType resolvedType = type == IJSVGUnitLengthTypePercentage || type == IJSVGUnitLengthTypeEM || type == IJSVGUnitLengthTypeEX ? type : IJSVGUnitLengthTypeNumber;
            IJSVGUnitLength* length = [IJSVGUnitLength unitWithFloat:scalar type:resolvedType originalType:type inherit:NO];
            parsedLength = length;
            [lengths addObject:length];
        }
        while (cursor < end && IJSVGLengthListIsWhitespace(*cursor)) {
            cursor++;
        }
        if (cursor < end && *cursor == ',') {
            cursor++;
            while (cursor < end && IJSVGLengthListIsWhitespace(*cursor)) {
                cursor++;
            }
            if (cursor == end) {
                valid = NO;
                break;
            }
        }
    }
    if (singleLength != NULL) {
        *singleLength = valid && count == 1 ? parsedLength : nil;
    }
    return valid && count != 0;
}

static BOOL IJSVGParseUnitLengths(NSString* value, BOOL allowNegative, BOOL single, NSMutableArray<IJSVGUnitLength*>* lengths, IJSVGUnitLength** singleLength)
{
    return IJSVGParseUnitLengthsFromBytes(value.UTF8String, [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding], allowNegative, single, lengths, singleLength);
}

IJSVGUnitLength* IJSVGLengthFromBytes(const char* bytes, NSUInteger length, BOOL allowNegative)
{
    IJSVGUnitLength* result = nil;
    return IJSVGParseUnitLengthsFromBytes(bytes, length, allowNegative, YES, nil, &result) ? result : nil;
}

IJSVGUnitLength* IJSVGLengthFromString(NSString* value, BOOL allowNegative)
{
    return IJSVGLengthFromBytes(value.UTF8String, [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding], allowNegative);
}

BOOL IJSVGUnitLengthsAreValidBytes(const char* bytes, NSUInteger length, BOOL allowNegative, BOOL single)
{
    return IJSVGParseUnitLengthsFromBytes(bytes, length, allowNegative, single, nil, NULL);
}

BOOL IJSVGUnitLengthsAreValid(NSString* value, BOOL allowNegative, BOOL single)
{
    return IJSVGUnitLengthsAreValidBytes(value.UTF8String, [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding], allowNegative, single);
}

NSArray<IJSVGUnitLength*>* IJSVGUnitLengthsFromBytes(const char* bytes, NSUInteger length)
{
    NSMutableArray<IJSVGUnitLength*>* lengths = [[NSMutableArray alloc] init];
    return IJSVGParseUnitLengthsFromBytes(bytes, length, NO, NO, lengths, NULL) ? lengths : nil;
}

NSArray<IJSVGUnitLength*>* IJSVGUnitLengthsFromString(NSString* value)
{
    return IJSVGUnitLengthsFromBytes(value.UTF8String, [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

BOOL IJSVGAttributeIsGeometryProperty(NSUInteger attribute)
{
    switch (attribute) {
        case IJSVGNodeAttributeX:
        case IJSVGNodeAttributeY:
        case IJSVGNodeAttributeWidth:
        case IJSVGNodeAttributeHeight:
        case IJSVGNodeAttributeCX:
        case IJSVGNodeAttributeCY:
        case IJSVGNodeAttributeR:
        case IJSVGNodeAttributeRX:
        case IJSVGNodeAttributeRY:
            return YES;
        default:
            return NO;
    }
}

BOOL IJSVGAttributeSupportsVariables(NSUInteger attribute)
{
    if (IJSVGAttributeIsGeometryProperty(attribute) || (attribute >= IJSVGNodeAttributeFont && attribute <= IJSVGNodeAttributeTextOverflow)) {
        return YES;
    }
    switch (attribute) {
        case IJSVGNodeAttributeOpacity:
        case IJSVGNodeAttributeStrokeOpacity:
        case IJSVGNodeAttributeStrokeWidth:
        case IJSVGNodeAttributeStrokeDashOffset:
        case IJSVGNodeAttributeFillOpacity:
        case IJSVGNodeAttributeClipPath:
        case IJSVGNodeAttributeClipRule:
        case IJSVGNodeAttributeMask:
        case IJSVGNodeAttributeTransform:
        case IJSVGNodeAttributeStrokeLineCap:
        case IJSVGNodeAttributeStrokeLineJoin:
        case IJSVGNodeAttributeStroke:
        case IJSVGNodeAttributeStrokeDashArray:
        case IJSVGNodeAttributeStrokeMiterLimit:
        case IJSVGNodeAttributeFill:
        case IJSVGNodeAttributeFillRule:
        case IJSVGNodeAttributeBlendMode:
        case IJSVGNodeAttributeDisplay:
        case IJSVGNodeAttributeStopColor:
        case IJSVGNodeAttributeStopOpacity:
        case IJSVGNodeAttributeOverflow:
        case IJSVGNodeAttributeMarker:
        case IJSVGNodeAttributeFilter:
        case IJSVGNodeAttributeFloodColor:
        case IJSVGNodeAttributeFloodOpacity:
        case IJSVGNodeAttributeLightingColor:
        case IJSVGNodeAttributeColorInterpolationFilters:
        case IJSVGNodeAttributeEnableBackground:
        case IJSVGNodeAttributeFontSizeAdjust:
        case IJSVGNodeAttributeTextRendering:
        case IJSVGNodeAttributeMarkerStart:
        case IJSVGNodeAttributeMarkerMid:
        case IJSVGNodeAttributeMarkerEnd:
        case IJSVGNodeAttributeVectorEffect:
        case IJSVGNodeAttributeIsolation:
        case IJSVGNodeAttributePaintOrder:
        case IJSVGNodeAttributeColor:
        case IJSVGNodeAttributeVisibility:
        case IJSVGNodeAttributeMaskType:
        case IJSVGNodeAttributeTransformOrigin:
        case IJSVGNodeAttributeTransformBox:
            return YES;
        default:
            return NO;
    }
}

static BOOL IJSVGGeometryPropertyAllowsAuto(IJSVGNodeAttribute attribute)
{
    return attribute == IJSVGNodeAttributeWidth || attribute == IJSVGNodeAttributeHeight || attribute == IJSVGNodeAttributeRX || attribute == IJSVGNodeAttributeRY;
}

static BOOL IJSVGGeometryPropertyAllowsNegative(IJSVGNodeAttribute attribute)
{
    return attribute == IJSVGNodeAttributeX || attribute == IJSVGNodeAttributeY || attribute == IJSVGNodeAttributeCX || attribute == IJSVGNodeAttributeCY;
}

typedef NS_ENUM(NSUInteger, IJSVGGeometryKeyword) {
    IJSVGGeometryKeywordNone,
    IJSVGGeometryKeywordInitial,
    IJSVGGeometryKeywordInherit,
    IJSVGGeometryKeywordAuto
};

static IJSVGGeometryKeyword IJSVGGeometryKeywordFromString(NSString* value)
{
    if ([value isEqualToString:@"inherit"]) {
        return IJSVGGeometryKeywordInherit;
    }
    if ([value isEqualToString:@"initial"] || [value isEqualToString:@"unset"] || [value isEqualToString:@"revert"] || [value isEqualToString:@"revert-layer"]) {
        return IJSVGGeometryKeywordInitial;
    }
    return [value isEqualToString:@"auto"] ? IJSVGGeometryKeywordAuto : IJSVGGeometryKeywordNone;
}

IJSVGUnitLength* IJSVGGeometryInitialLength(IJSVGNodeAttribute attribute)
{
    return IJSVGGeometryPropertyAllowsAuto(attribute) ? IJSVGAutoUnitLength : IJSVGZeroUnitLength;
}

static BOOL IJSVGParseGeometryLength(NSString* value, IJSVGNodeAttribute attribute, IJSVGUnitLength** parsedLength)
{
    const char* chars = value.UTF8String;
    if (chars == NULL) {
        return NO;
    }
    while (IJSVGLengthListIsWhitespace(*chars)) {
        chars++;
    }
    if (strchr(chars, '(') == NULL && ((*chars >= 'a' && *chars <= 'z') || (*chars >= 'A' && *chars <= 'Z'))) {
        NSString* keywordString = [value.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        IJSVGGeometryKeyword keyword = IJSVGGeometryKeywordFromString(keywordString);
        if (keyword == IJSVGGeometryKeywordNone || (keyword == IJSVGGeometryKeywordAuto && !IJSVGGeometryPropertyAllowsAuto(attribute))) {
            return NO;
        }
        if (parsedLength != NULL) {
            if (keyword == IJSVGGeometryKeywordInherit) {
                *parsedLength = IJSVGGeometryPropertyAllowsAuto(attribute) ? IJSVGInheritedAutoUnitLength : IJSVGInheritedZeroUnitLength;
            } else {
                *parsedLength = IJSVGGeometryInitialLength(attribute);
            }
        }
        return YES;
    }
    return IJSVGParseUnitLengths(value, IJSVGGeometryPropertyAllowsNegative(attribute), YES, nil, parsedLength);
}

BOOL IJSVGGeometryLengthIsValid(NSString* value, IJSVGNodeAttribute attribute)
{
    return IJSVGParseGeometryLength(value, attribute, NULL);
}

IJSVGUnitLength* IJSVGGeometryLengthFromString(NSString* value, IJSVGNodeAttribute attribute)
{
    IJSVGUnitLength* length = nil;
    return IJSVGParseGeometryLength(value, attribute, &length) ? length : nil;
}

IJSVGPaintOrder IJSVGPaintOrderFromString(NSString* value)
{
    value = [value.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([value isEqualToString:@"normal"] || [value isEqualToString:@"initial"]) {
        return IJSVGPaintOrderNormal;
    }
    NSArray<NSString*>* names = @[ @"fill", @"stroke", @"markers" ];
    NSUInteger seen = 0, order = 0, count = 0;
    for (NSString* token in [value componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]) {
        if (token.length == 0) {
            continue;
        }
        NSUInteger operation = [names indexOfObject:token];
        if (operation == NSNotFound || (seen & (1 << operation)) != 0) {
            return IJSVGPaintOrderInherit;
        }
        seen |= 1 << operation;
        order |= operation << (2 * count++);
    }
    if (count == 0) {
        return IJSVGPaintOrderInherit;
    }
    for (NSUInteger operation = 0; operation < 3; operation++) {
        if ((seen & (1 << operation)) == 0) {
            order |= operation << (2 * count++);
        }
    }
    return (IJSVGPaintOrder)order;
}

NSString* IJSVGStringFromPaintOrder(IJSVGPaintOrder order)
{
    NSArray<NSString*>* names = @[ @"fill", @"stroke", @"markers" ];
    return [NSString stringWithFormat:@"%@ %@ %@", names[order & 3], names[(order >> 2) & 3], names[(order >> 4) & 3]];
}

BOOL IJSVGIsolationFromString(NSString* value, BOOL parentIsolation)
{
    if ([value isEqualToString:@"inherit"]) {
        return parentIsolation;
    }
    return [value isEqualToString:@"isolate"];
}

IJSVGUnitLength* IJSVGDimensionFromString(NSString* value, IJSVGNodeType type)
{
    IJSVGUnitLength* length = [IJSVGUnitLength unitWithString:value];
    BOOL viewportUse = type == IJSVGNodeTypeUse || type == IJSVGNodeTypeSymbol;
    if (viewportUse && ([value isEqualToString:@"auto"] || length.value < 0.f)) {
        return nil;
    }
    return length;
}

IJSVGUnitLength* IJSVGSymbolReferenceFromString(NSString* value, IJSVGNodeAttribute attribute)
{
    if (value == nil) {
        return nil;
    }
    BOOL horizontal;
    switch (attribute) {
        case IJSVGNodeAttributeRefX:
            horizontal = YES;
            break;
        case IJSVGNodeAttributeRefY:
            horizontal = NO;
            break;
        default:
            return nil;
    }
    if ([value isEqualToString:horizontal ? @"left" : @"top"]) {
        return IJSVGZeroPercentageUnitLength;
    } else if ([value isEqualToString:@"center"]) {
        return IJSVGHalfPercentageUnitLength;
    } else if ([value isEqualToString:horizontal ? @"right" : @"bottom"]) {
        return IJSVGOnePercentageUnitLength;
    }
    return [IJSVGUnitLength unitWithString:value];
}

void IJSVGApplyBackgroundAttribute(IJSVGGraphicsNode* node, NSString* value)
{
    char* buffer = IJSVGTimmedCharBufferCreate(value.UTF8String);
    if (buffer == NULL) {
        return;
    }
    size_t length = strcspn(buffer, " \t\r\n");
    char* parameters = buffer + length;
    if (*parameters != 0) {
        *parameters++ = 0;
        IJSVGTrimCharBuffer(parameters);
    }
    IJSVGBackgroundEnabled mode = IJSVGBackgroundEnabledUnspecified;
    CGRect bounds = CGRectNull;
    if (IJSVGCharBufferCompare(buffer, "inherit") && *parameters == 0) {
        mode = IJSVGBackgroundEnabledInherit;
    } else if (IJSVGCharBufferCompare(buffer, "accumulate") && *parameters == 0) {
        mode = IJSVGBackgroundEnabledAccumulate;
    } else if (IJSVGCharBufferCompare(buffer, "new")) {
        if (*parameters == 0) {
            mode = IJSVGBackgroundEnabledNew;
            bounds = CGRectInfinite;
        } else {
            CGFloat values[4];
            CGFloat* output = values;
            __block NSUInteger count = 0;
            BOOL valid = IJSVGEnumerateNumbersFromCString(parameters, ^(CGFloat number) {
                if (count < 4) {
                    output[count] = number;
                }
                count++;
            });
            if (valid && count == 4 && values[2] > 0 && values[3] > 0) {
                mode = IJSVGBackgroundEnabledNew;
                bounds = CGRectMake(values[0], values[1], values[2], values[3]);
            }
        }
    }
    free(buffer);
    node.backgroundEnabled = mode;
    node.backgroundBounds = bounds;
}

BOOL IJSVGAttributeMaskContains(uint64_t mask, IJSVGNodeAttribute attribute)
{
    return (mask & (1ULL << attribute)) != 0;
}

NSString* IJSVGAttributeValue(NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength], IJSVGNodeAttribute attribute)
{
    return attributeValues[attribute];
}

BOOL IJSVGAttributeHasValue(NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength], IJSVGNodeAttribute attribute, NSString* __autoreleasing* value)
{
    NSString* __unsafe_unretained attributeValue = attributeValues[attribute];
    if (attributeValue == nil || attributeValue.length == 0) {
        return NO;
    }
    if (value != NULL) {
        *value = attributeValue;
    }
    return YES;
}

BOOL IJSVGReadXMLAttribute(IJSVGXMLAttribute* node, IJSVGBitFlags* activeAttributes, NSUInteger* attribute, NSString* __unsafe_unretained* value, IJSVGReferenceAttributes* reference)
{
    NSUInteger index = node->identifier;
    if (reference != NULL && (index == IJSVGNodeAttributeHref || index == IJSVGNodeAttributeXLink || index == NSNotFound)) {
        IJSVGReadReferenceAttribute(node, reference);
    }
    if (index == NSNotFound || (activeAttributes != nil && ![activeAttributes bitIsSet:(int)index])) {
        return NO;
    }
    NSString* __unsafe_unretained string = IJSVGXMLAttributeValue(node);
    if (string.length == 0) {
        return NO;
    }
    *attribute = index;
    *value = string;
    return YES;
}

NSSet<NSString*>* IJSVGClassNameList(NSString* value)
{
    return [NSSet setWithArray:[value ijsvg_componentsSplitByWhiteSpace] ?: @[]];
}

static uint64_t IJSVGStorePrioritizedStyleAttributes(IJSVGStyleSheetStyle* style, IJSVGStyleSheetStyle* fallback, IJSVGBitFlags* activeAttributes, NSString* __unsafe_unretained attributeValues[kIJSVGNodeAttributeStorageLength])
{
    if (style == nil) {
        return 0;
    }
    if (!fallback.hasImportantProperties) {
        fallback = nil;
    }
    uint64_t textAttributes = 0;
    NSUInteger count = 0;
    __attribute__((objc_precise_lifetime)) IJSVGStyleSheetStyle* owner = style;
    const IJSVGStyleSheetAttribute* entries = [owner attributesWithCount:&count];
    const int* allowed = activeAttributes.storage;
    NSUInteger allowedCount = MAX(0, activeAttributes.length);
    for (NSUInteger index = 0; index < count; index++) {
        IJSVGStyleSheetAttribute entry = entries[index];
        if (entry.attribute >= allowedCount || allowed[entry.attribute] != 1) {
            continue;
        }
        if (!entry.important && [fallback isPropertyImportant:entry.name]) {
            continue;
        }
        if (entry.invalidAtComputedValue) {
            attributeValues[entry.attribute] = nil;
        } else if (entry.value.length != 0) {
            attributeValues[entry.attribute] = entry.value;
            textAttributes |= IJSVGTextStyleBit(entry.attribute);
        }
    }
    return textAttributes;
}

void IJSVGStoreStyleAttributes(IJSVGStyleSheetStyle* style, IJSVGBitFlags* activeAttributes, NSString* __unsafe_unretained attributeValues[kIJSVGNodeAttributeStorageLength])
{
    IJSVGStorePrioritizedStyleAttributes(style, nil, activeAttributes, attributeValues);
}

uint64_t IJSVGStoreCascadedStyleAttributes(IJSVGStyleSheetStyle* style, IJSVGStyleSheetStyle* inlineStyle, IJSVGBitFlags* activeAttributes, NSString* __unsafe_unretained attributeValues[kIJSVGNodeAttributeStorageLength])
{
    uint64_t textAttributes = IJSVGStorePrioritizedStyleAttributes(style, nil, activeAttributes, attributeValues);
    return textAttributes | IJSVGStorePrioritizedStyleAttributes(inlineStyle, style, activeAttributes, attributeValues);
}

typedef NS_ENUM(NSUInteger, IJSVGOriginKeyword) {
    IJSVGOriginKeywordNone,
    IJSVGOriginKeywordCenter,
    IJSVGOriginKeywordLeft,
    IJSVGOriginKeywordRight,
    IJSVGOriginKeywordTop,
    IJSVGOriginKeywordBottom
};

static IJSVGOriginKeyword IJSVGOriginKeywordFromCString(const char* token)
{
    static const char* keywords[] = { "center", "left", "right", "top", "bottom" };
    for (NSUInteger index = 0; index < sizeof(keywords) / sizeof(keywords[0]); index++) {
        if (IJSVGCharBufferCaseInsensitiveCompare(token, keywords[index])) {
            return (IJSVGOriginKeyword)(index + 1);
        }
    }
    return IJSVGOriginKeywordNone;
}

static NSUInteger IJSVGPositionTokenize(char* buffer, const char* tokens[3], NSUInteger capacity)
{
    NSUInteger count = 0;
    char* cursor = buffer;
    while (*cursor != '\0') {
        while (IJSVGLengthListIsWhitespace(*cursor) || *cursor == '\f') {
            cursor++;
        }
        if (*cursor == '\0') {
            break;
        }
        if (count == capacity) {
            return 0;
        }
        tokens[count++] = cursor;
        while (*cursor != '\0' && !IJSVGLengthListIsWhitespace(*cursor) && *cursor != '\f') {
            cursor++;
        }
        if (*cursor != '\0') {
            *cursor++ = '\0';
        }
    }
    return count;
}

NSArray<IJSVGUnitLength*>* IJSVGPositionFromBuffer(char* buffer, IJSVGPositionSyntax syntax)
{
    const char* tokens[3] = { NULL };
    NSUInteger count = IJSVGPositionTokenize(buffer, tokens, syntax == IJSVGPositionSyntaxBasicShape ? 2 : 3);
    if (count == 0) {
        return nil;
    }
    if (count == 3) {
        // The renderer validates depth without applying a depth translation.
        if (strchr(tokens[2], '%') != NULL || !IJSVGParseUnitLengthsFromBytes(tokens[2], strlen(tokens[2]), YES, YES, nil, NULL)) {
            return nil;
        }
        count--;
    }
    IJSVGOriginKeyword keywords[2] = { IJSVGOriginKeywordFromCString(tokens[0]), IJSVGOriginKeywordCenter };
    if (count == 1) {
        tokens[1] = "center";
        if (keywords[0] == IJSVGOriginKeywordTop || keywords[0] == IJSVGOriginKeywordBottom) {
            tokens[1] = tokens[0];
            tokens[0] = "center";
            keywords[1] = keywords[0];
            keywords[0] = IJSVGOriginKeywordCenter;
        }
    } else {
        keywords[1] = IJSVGOriginKeywordFromCString(tokens[1]);
        if (keywords[0] == IJSVGOriginKeywordTop || keywords[0] == IJSVGOriginKeywordBottom || keywords[1] == IJSVGOriginKeywordLeft || keywords[1] == IJSVGOriginKeywordRight) {
            if (keywords[0] == IJSVGOriginKeywordNone || keywords[1] == IJSVGOriginKeywordNone) {
                return nil;
            }
            const char* token = tokens[0];
            tokens[0] = tokens[1];
            tokens[1] = token;
            IJSVGOriginKeyword keyword = keywords[0];
            keywords[0] = keywords[1];
            keywords[1] = keyword;
        }
    }
    IJSVGUnitLength* result[2] = { nil };
    for (NSUInteger index = 0; index < 2; index++) {
        IJSVGOriginKeyword leading = index == 0 ? IJSVGOriginKeywordLeft : IJSVGOriginKeywordTop;
        IJSVGOriginKeyword trailing = index == 0 ? IJSVGOriginKeywordRight : IJSVGOriginKeywordBottom;
        IJSVGOriginKeyword keyword = keywords[index];
        if (keyword == leading || keyword == trailing || keyword == IJSVGOriginKeywordCenter) {
            result[index] = keyword == leading ? IJSVGZeroPercentageUnitLength : (keyword == trailing ? IJSVGOnePercentageUnitLength : IJSVGHalfPercentageUnitLength);
        } else {
            IJSVGUnitLength* length = nil;
            if (keyword != IJSVGOriginKeywordNone || !IJSVGParseUnitLengthsFromBytes(tokens[index], strlen(tokens[index]), YES, YES, nil, &length)) {
                return nil;
            }
            result[index] = length;
        }
    }
    return @[ result[0], result[1] ];
}

NSArray<IJSVGUnitLength*>* IJSVGTransformOriginFromString(NSString* value)
{
    const char* bytes = value.UTF8String;
    if (bytes == NULL || strlen(bytes) != [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return nil;
    }

    // Tokenize one owned buffer, keeping all intermediate tokens in C.
    char* buffer = strdup(bytes);
    if (buffer == NULL) {
        return nil;
    }
    NSArray<IJSVGUnitLength*>* origin = IJSVGPositionFromBuffer(buffer, IJSVGPositionSyntaxTransformOrigin);
    free(buffer);
    return origin;
}

void IJSVGApplyTransformAttribute(IJSVGGraphicsNode* node, NSString* value, BOOL allowCSSUnits)
{
    IJSVGApplyParsedTransforms(node, [IJSVGTransform transformsForString:value allowCSSUnits:allowCSSUnits]);
}

void IJSVGApplyParsedTransforms(IJSVGGraphicsNode* node, NSArray<IJSVGTransform*>* parsedTransforms)
{
    NSMutableArray<IJSVGTransform*>* transforms = parsedTransforms.mutableCopy;
    if (transforms == nil) {
        transforms = [[NSMutableArray alloc] init];
    }
    if (node.transforms != nil) {
        [transforms addObjectsFromArray:node.transforms];
    }
    node.transforms = transforms;
}

static inline BOOL IJSVGAttributeNameEquals(const char* name, size_t length, const char* expected)
{
    return strlen(expected) == length && memcmp(name, expected, length) == 0;
}

IJSVGNodeAttribute IJSVGNodeAttributeForName(NSString* name)
{
    char buffer[64];
    NSUInteger length = name.length;
    if (length == 0 || length >= sizeof(buffer) || ![name getCString:buffer maxLength:sizeof(buffer) encoding:NSASCIIStringEncoding]) {
        return IJSVGNodeAttributeUnknown;
    }
    return IJSVGNodeAttributeForBytes(buffer, length);
}

IJSVGNodeAttribute IJSVGNodeAttributeForBytes(const char* attributeName, NSUInteger length)
{
    if (attributeName == NULL || length == 0) {
        return IJSVGNodeAttributeUnknown;
    }
    switch (length) {
        case 1: {
            char c = attributeName[0];
            if (c == 'd') {
                return IJSVGNodeAttributeD;
            }
            if (c == 'x') {
                return IJSVGNodeAttributeX;
            }
            if (c == 'y') {
                return IJSVGNodeAttributeY;
            }
            if (c == 'r') {
                return IJSVGNodeAttributeR;
            }
            if (attributeName[0] == 'z') {
                return IJSVGNodeAttributeZ;
            }
            break;
        }
        case 2: {
            if (IJSVGAttributeNameEquals(attributeName, length, "dx")) {
                return IJSVGNodeAttributeDX;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "dy")) {
                return IJSVGNodeAttributeDY;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "in")) {
                return IJSVGNodeAttributeIn;
            }
            char c = attributeName[0];
            if (c == 'i' && IJSVGAttributeNameEquals(attributeName, length, "id")) {
                return IJSVGNodeAttributeID;
            }
            if (c == 'c') {
                if (IJSVGAttributeNameEquals(attributeName, length, "cx")) {
                    return IJSVGNodeAttributeCX;
                }
                if (IJSVGAttributeNameEquals(attributeName, length, "cy")) {
                    return IJSVGNodeAttributeCY;
                }
            }
            if (c == 'f') {
                if (IJSVGAttributeNameEquals(attributeName, length, "fx")) {
                    return IJSVGNodeAttributeFX;
                }
                if (IJSVGAttributeNameEquals(attributeName, length, "fy")) {
                    return IJSVGNodeAttributeFY;
                }
                if (IJSVGAttributeNameEquals(attributeName, length, "fr")) {
                    return IJSVGNodeAttributeFR;
                }
            }
            if (c == 'r') {
                if (IJSVGAttributeNameEquals(attributeName, length, "rx")) {
                    return IJSVGNodeAttributeRX;
                }
                if (IJSVGAttributeNameEquals(attributeName, length, "ry")) {
                    return IJSVGNodeAttributeRY;
                }
            }
            if (c == 'x') {
                if (IJSVGAttributeNameEquals(attributeName, length, "x1")) {
                    return IJSVGNodeAttributeX1;
                }
                if (IJSVGAttributeNameEquals(attributeName, length, "x2")) {
                    return IJSVGNodeAttributeX2;
                }
            }
            if (c == 'y') {
                if (IJSVGAttributeNameEquals(attributeName, length, "y1")) {
                    return IJSVGNodeAttributeY1;
                }
                if (IJSVGAttributeNameEquals(attributeName, length, "y2")) {
                    return IJSVGNodeAttributeY2;
                }
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "k1")) {
                return IJSVGNodeAttributeK1;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "k2")) {
                return IJSVGNodeAttributeK2;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "k3")) {
                return IJSVGNodeAttributeK3;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "k4")) {
                return IJSVGNodeAttributeK4;
            }
            break;
        }
        case 3: {
            if (IJSVGAttributeNameEquals(attributeName, length, "in2")) {
                return IJSVGNodeAttributeIn2;
            }
            break;
        }
        case 4: {
            char c = attributeName[0];
            if (c == 'f' && IJSVGAttributeNameEquals(attributeName, length, "fill")) {
                return IJSVGNodeAttributeFill;
            }
            if (c == 'h' && IJSVGAttributeNameEquals(attributeName, length, "href")) {
                return IJSVGNodeAttributeHref;
            }
            if (c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "mask")) {
                return IJSVGNodeAttributeMask;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "bias")) {
                return IJSVGNodeAttributeBias;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "font")) {
                return IJSVGNodeAttributeFont;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "lang")) {
                return IJSVGNodeAttributeLang;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "mode")) {
                return IJSVGNodeAttributeMode;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "path")) {
                return IJSVGNodeAttributePath;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "refX")) {
                return IJSVGNodeAttributeRefX;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "refY")) {
                return IJSVGNodeAttributeRefY;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "seed")) {
                return IJSVGNodeAttributeSeed;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "side")) {
                return IJSVGNodeAttributeSide;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "type")) {
                return IJSVGNodeAttributeType;
            }
            break;
        }
        case 5: {
            if (IJSVGAttributeNameEquals(attributeName, length, "color")) {
                return IJSVGNodeAttributeColor;
            }
            char c = attributeName[0];
            if (c == 'c' && IJSVGAttributeNameEquals(attributeName, length, "class")) {
                return IJSVGNodeAttributeClass;
            }
            if (c == 's' && IJSVGAttributeNameEquals(attributeName, length, "style")) {
                return IJSVGNodeAttributeStyle;
            }
            if (c == 'w' && IJSVGAttributeNameEquals(attributeName, length, "width")) {
                return IJSVGNodeAttributeWidth;
            }
            if (c == 'x' && IJSVGAttributeNameEquals(attributeName, length, "xmlns")) {
                return IJSVGNodeAttributeXMLNS;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "order")) {
                return IJSVGNodeAttributeOrder;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "scale")) {
                return IJSVGNodeAttributeScale;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "slope")) {
                return IJSVGNodeAttributeSlope;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "media")) {
                return IJSVGNodeAttributeMedia;
            }
            break;
        }
        case 6: {
            if (IJSVGAttributeNameEquals(attributeName, length, "result")) {
                return IJSVGNodeAttributeResult;
            }
            char c = attributeName[0];
            if (c == 'f' && IJSVGAttributeNameEquals(attributeName, length, "filter")) {
                return IJSVGNodeAttributeFilter;
            }
            if (c == 'h' && IJSVGAttributeNameEquals(attributeName, length, "height")) {
                return IJSVGNodeAttributeHeight;
            }
            if (c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "marker")) {
                return IJSVGNodeAttributeMarker;
            }
            if (c == 'o' && IJSVGAttributeNameEquals(attributeName, length, "offset")) {
                return IJSVGNodeAttributeOffset;
            }
            if (c == 'p' && IJSVGAttributeNameEquals(attributeName, length, "points")) {
                return IJSVGNodeAttributePoints;
            }
            if (c == 's' && IJSVGAttributeNameEquals(attributeName, length, "stroke")) {
                return IJSVGNodeAttributeStroke;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "method")) {
                return IJSVGNodeAttributeMethod;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "orient")) {
                return IJSVGNodeAttributeOrient;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "radius")) {
                return IJSVGNodeAttributeRadius;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "rotate")) {
                return IJSVGNodeAttributeRotate;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "values")) {
                return IJSVGNodeAttributeValues;
            }
            break;
        }
        case 7: {
            char c = attributeName[0];
            if (c == 'd' && IJSVGAttributeNameEquals(attributeName, length, "display")) {
                return IJSVGNodeAttributeDisplay;
            }
            if (c == 'o' && IJSVGAttributeNameEquals(attributeName, length, "opacity")) {
                return IJSVGNodeAttributeOpacity;
            }
            if (c == 'u' && IJSVGAttributeNameEquals(attributeName, length, "unicode")) {
                return IJSVGNodeAttributeUnicode;
            }
            if (c == 'v') {
                if (IJSVGAttributeNameEquals(attributeName, length, "version")) {
                    return IJSVGNodeAttributeVersion;
                }
                if (IJSVGAttributeNameEquals(attributeName, length, "viewBox")) {
                    return IJSVGNodeAttributeViewBox;
                }
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "azimuth")) {
                return IJSVGNodeAttributeAzimuth;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "divisor")) {
                return IJSVGNodeAttributeDivisor;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "spacing")) {
                return IJSVGNodeAttributeSpacing;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "targetX")) {
                return IJSVGNodeAttributeTargetX;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "targetY")) {
                return IJSVGNodeAttributeTargetY;
            }
            break;
        }
        case 8: {
            if (IJSVGAttributeNameEquals(attributeName, length, "overflow")) {
                return IJSVGNodeAttributeOverflow;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "edgeMode")) {
                return IJSVGNodeAttributeEdgeMode;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "exponent")) {
                return IJSVGNodeAttributeExponent;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "operator")) {
                return IJSVGNodeAttributeOperator;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "xml:lang")) {
                return IJSVGNodeAttributeXMLLang;
            }
            break;
        }
        case 9: {
            char c = attributeName[0];
            if (c == 'i' && IJSVGAttributeNameEquals(attributeName, length, "isolation")) {
                return IJSVGNodeAttributeIsolation;
            }
            if (c == 'c') {
                if (IJSVGAttributeNameEquals(attributeName, length, "clip-path")) {
                    return IJSVGNodeAttributeClipPath;
                }
                if (IJSVGAttributeNameEquals(attributeName, length, "clip-rule")) {
                    return IJSVGNodeAttributeClipRule;
                }
            }
            if (c == 'f' && IJSVGAttributeNameEquals(attributeName, length, "fill-rule")) {
                return IJSVGNodeAttributeFillRule;
            }
            if (c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "mask-type")) {
                return IJSVGNodeAttributeMaskType;
            }
            if (c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "maskUnits")) {
                return IJSVGNodeAttributeMaskUnits;
            }
            if (c == 't' && IJSVGAttributeNameEquals(attributeName, length, "transform")) {
                return IJSVGNodeAttributeTransform;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "amplitude")) {
                return IJSVGNodeAttributeAmplitude;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "direction")) {
                return IJSVGNodeAttributeDirection;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "elevation")) {
                return IJSVGNodeAttributeElevation;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "font-size")) {
                return IJSVGNodeAttributeFontSize;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "intercept")) {
                return IJSVGNodeAttributeIntercept;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "pointsAtX")) {
                return IJSVGNodeAttributePointsAtX;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "pointsAtY")) {
                return IJSVGNodeAttributePointsAtY;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "pointsAtZ")) {
                return IJSVGNodeAttributePointsAtZ;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "xml:space")) {
                return IJSVGNodeAttributeXMLSpace;
            }
            break;
        }
        case 10: {
            if (IJSVGAttributeNameEquals(attributeName, length, "visibility")) {
                return IJSVGNodeAttributeVisibility;
            }
            char c = attributeName[0];
            if (c == 's' && IJSVGAttributeNameEquals(attributeName, length, "stop-color")) {
                return IJSVGNodeAttributeStopColor;
            }
            if (c == 'x' && IJSVGAttributeNameEquals(attributeName, length, "xlink:href")) {
                return IJSVGNodeAttributeXLink;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "font-style")) {
                return IJSVGNodeAttributeFontStyle;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "marker-end")) {
                return IJSVGNodeAttributeMarkerEnd;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "marker-mid")) {
                return IJSVGNodeAttributeMarkerMid;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "numOctaves")) {
                return IJSVGNodeAttributeNumOctaves;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "pathLength")) {
                return IJSVGNodeAttributePathLength;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "textLength")) {
                return IJSVGNodeAttributeTextLength;
            }
            break;
        }
        case 11: {
            if (IJSVGAttributeNameEquals(attributeName, length, "paint-order")) {
                return IJSVGNodeAttributePaintOrder;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "flood-color")) {
                return IJSVGNodeAttributeFloodColor;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "filterUnits")) {
                return IJSVGNodeAttributeFilterUnits;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "xmlns:xlink")) {
                return IJSVGNodeAttributeXMLNSXlink;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "font-family")) {
                return IJSVGNodeAttributeFontFamily;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "font-weight")) {
                return IJSVGNodeAttributeFontWeight;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "inline-size")) {
                return IJSVGNodeAttributeInlineSize;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "line-height")) {
                return IJSVGNodeAttributeLineHeight;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "markerUnits")) {
                return IJSVGNodeAttributeMarkerUnits;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "markerWidth")) {
                return IJSVGNodeAttributeMarkerWidth;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "startOffset")) {
                return IJSVGNodeAttributeStartOffset;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "stitchTiles")) {
                return IJSVGNodeAttributeStitchTiles;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "tableValues")) {
                return IJSVGNodeAttributeTableValues;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "text-anchor")) {
                return IJSVGNodeAttributeTextAnchor;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "white-space")) {
                return IJSVGNodeAttributeWhiteSpace;
            }
            break;
        }
        case 12: {
            if (IJSVGAttributeNameEquals(attributeName, length, "stdDeviation")) {
                return IJSVGNodeAttributeStdDeviation;
            }
            char c = attributeName[0];
            if (c == 'f' && IJSVGAttributeNameEquals(attributeName, length, "fill-opacity")) {
                return IJSVGNodeAttributeFillOpacity;
            }
            if (c == 'p' && IJSVGAttributeNameEquals(attributeName, length, "patternUnits")) {
                return IJSVGNodeAttributePatternUnits;
            }
            if (c == 's') {
                if (IJSVGAttributeNameEquals(attributeName, length, "stroke-width")) {
                    return IJSVGNodeAttributeStrokeWidth;
                }
                if (IJSVGAttributeNameEquals(attributeName, length, "stop-opacity")) {
                    return IJSVGNodeAttributeStopOpacity;
                }
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "font-kerning")) {
                return IJSVGNodeAttributeFontKerning;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "font-stretch")) {
                return IJSVGNodeAttributeFontStretch;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "font-variant")) {
                return IJSVGNodeAttributeFontVariant;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "kernelMatrix")) {
                return IJSVGNodeAttributeKernelMatrix;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "lengthAdjust")) {
                return IJSVGNodeAttributeLengthAdjust;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "marker-start")) {
                return IJSVGNodeAttributeMarkerStart;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "markerHeight")) {
                return IJSVGNodeAttributeMarkerHeight;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "surfaceScale")) {
                return IJSVGNodeAttributeSurfaceScale;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "unicode-bidi")) {
                return IJSVGNodeAttributeUnicodeBidi;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "word-spacing")) {
                return IJSVGNodeAttributeWordSpacing;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "writing-mode")) {
                return IJSVGNodeAttributeWritingMode;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "spreadMethod")) {
                return IJSVGNodeAttributeSpreadMethod;
            }
            break;
        }
        case 13: {
            if (IJSVGAttributeNameEquals(attributeName, length, "transform-box")) {
                return IJSVGNodeAttributeTransformBox;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "flood-opacity")) {
                return IJSVGNodeAttributeFloodOpacity;
            }
            char c = attributeName[0];
            if (c == 'c' && IJSVGAttributeNameEquals(attributeName, length, "clipPathUnits")) {
                return IJSVGNodeAttributeClipPathUnits;
            }
            if (c == 'g' && IJSVGAttributeNameEquals(attributeName, length, "gradientUnits")) {
                return IJSVGNodeAttributeGradientUnits;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "baseFrequency")) {
                return IJSVGNodeAttributeBaseFrequency;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "preserveAlpha")) {
                return IJSVGNodeAttributePreserveAlpha;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "text-overflow")) {
                return IJSVGNodeAttributeTextOverflow;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "vector-effect")) {
                return IJSVGNodeAttributeVectorEffect;
            }
            break;
        }
        case 14: {
            char c = attributeName[0];
            if (c == 'p' && IJSVGAttributeNameEquals(attributeName, length, "primitiveUnits")) {
                return IJSVGNodeAttributePrimitiveUnits;
            }
            if (c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "mix-blend-mode")) {
                return IJSVGNodeAttributeBlendMode;
            }
            if (c == 's') {
                if (IJSVGAttributeNameEquals(attributeName, length, "stroke-linecap")) {
                    return IJSVGNodeAttributeStrokeLineCap;
                }
                if (IJSVGAttributeNameEquals(attributeName, length, "stroke-opacity")) {
                    return IJSVGNodeAttributeStrokeOpacity;
                }
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "baseline-shift")) {
                return IJSVGNodeAttributeBaselineShift;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "letter-spacing")) {
                return IJSVGNodeAttributeLetterSpacing;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "lighting-color")) {
                return IJSVGNodeAttributeLightingColor;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "text-rendering")) {
                return IJSVGNodeAttributeTextRendering;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "text-transform")) {
                return IJSVGNodeAttributeTextTransform;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "systemLanguage")) {
                return IJSVGNodeAttributeSystemLanguage;
            }
            break;
        }
        case 15: {
            if (IJSVGAttributeNameEquals(attributeName, length, "stroke-linejoin")) {
                return IJSVGNodeAttributeStrokeLineJoin;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "diffuseConstant")) {
                return IJSVGNodeAttributeDiffuseConstant;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "text-decoration")) {
                return IJSVGNodeAttributeTextDecoration;
            }
            break;
        }
        case 16: {
            if (IJSVGAttributeNameEquals(attributeName, length, "transform-origin")) {
                return IJSVGNodeAttributeTransformOrigin;
            }
            char c = attributeName[0];
            if (c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "maskContentUnits")) {
                return IJSVGNodeAttributeMaskContentUnits;
            }
            if (c == 'p' && IJSVGAttributeNameEquals(attributeName, length, "patternTransform")) {
                return IJSVGNodeAttributePatternTransform;
            }
            if (c == 's' && IJSVGAttributeNameEquals(attributeName, length, "stroke-dasharray")) {
                return IJSVGNodeAttributeStrokeDashArray;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "background-color")) {
                return IJSVGNodeAttributeBackgroundColor;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "font-size-adjust")) {
                return IJSVGNodeAttributeFontSizeAdjust;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "kernelUnitLength")) {
                return IJSVGNodeAttributeKernelUnitLength;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "specularConstant")) {
                return IJSVGNodeAttributeSpecularConstant;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "specularExponent")) {
                return IJSVGNodeAttributeSpecularExponent;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "text-orientation")) {
                return IJSVGNodeAttributeTextOrientation;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "xChannelSelector")) {
                return IJSVGNodeAttributeXChannelSelector;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "yChannelSelector")) {
                return IJSVGNodeAttributeYChannelSelector;
            }
            break;
        }
        case 17: {
            char c = attributeName[0];
            if (c == 'g' && IJSVGAttributeNameEquals(attributeName, length, "gradientTransform")) {
                return IJSVGNodeAttributeGradientTransform;
            }
            if (c == 's') {
                if (IJSVGAttributeNameEquals(attributeName, length, "stroke-dashoffset")) {
                    return IJSVGNodeAttributeStrokeDashOffset;
                }
                if (IJSVGAttributeNameEquals(attributeName, length, "stroke-miterlimit")) {
                    return IJSVGNodeAttributeStrokeMiterLimit;
                }
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "dominant-baseline")) {
                return IJSVGNodeAttributeDominantBaseline;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "enable-background")) {
                return IJSVGNodeAttributeEnableBackground;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "limitingConeAngle")) {
                return IJSVGNodeAttributeLimitingConeAngle;
            }
            break;
        }
        case 18: {
            if (IJSVGAttributeNameEquals(attributeName, length, "alignment-baseline")) {
                return IJSVGNodeAttributeAlignmentBaseline;
            }
            if (IJSVGAttributeNameEquals(attributeName, length, "requiredExtensions")) {
                return IJSVGNodeAttributeRequiredExtensions;
            }
            break;
        }
        case 19: {
            char c = attributeName[0];
            if (c == 'p') {
                if (IJSVGAttributeNameEquals(attributeName, length, "patternContentUnits")) {
                    return IJSVGNodeAttributePatternContentUnits;
                }
                if (IJSVGAttributeNameEquals(attributeName, length, "preserveAspectRatio")) {
                    return IJSVGNodeAttributePreserveAspectRatio;
                }
            }
            break;
        }
        case 20: {
            if (IJSVGAttributeNameEquals(attributeName, length, "text-decoration-line")) {
                return IJSVGNodeAttributeTextDecorationLine;
            }
            break;
        }
        case 21: {
            if (IJSVGAttributeNameEquals(attributeName, length, "font-feature-settings")) {
                return IJSVGNodeAttributeFontFeatureSettings;
            }
            break;
        }
        case 22: {
            if (IJSVGAttributeNameEquals(attributeName, length, "font-variant-ligatures")) {
                return IJSVGNodeAttributeFontVariantLigatures;
            }
            break;
        }
        case 27: {
            if (IJSVGAttributeNameEquals(attributeName, length, "color-interpolation-filters")) {
                return IJSVGNodeAttributeColorInterpolationFilters;
            }
            break;
        }
    }
    return IJSVGNodeAttributeUnknown;
}
