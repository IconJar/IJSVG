//
//  IJSVGParserUtils.m
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGCommandParser.h>
#import <IJSVG/IJSVGParserUtils.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGPath.h>
#import <string.h>
#import <IJSVG/IJSVGUtils.h>

static BOOL IJSVGLengthListIsWhitespace(char character)
{
    return character == ' ' || character == '\t' ||
        character == '\r' || character == '\n';
}

static BOOL IJSVGLengthListIsDigit(char character)
{
    return character >= '0' && character <= '9';
}

static BOOL IJSVGParseUnitLengths(NSString* value, BOOL allowNegative, BOOL single,
                                  NSMutableArray<IJSVGUnitLength*>* lengths,
                                  IJSVGUnitLength** singleLength)
{
    const char* string = value.UTF8String;
    if(string == NULL || *string == '\0' ||
       strlen(string) != [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return NO;
    }
    const char* cursor = string;
    IJSVGUnitLength* parsedLength = nil;
    NSUInteger count = 0;
    BOOL valid = YES;
    while(IJSVGLengthListIsWhitespace(*cursor)) {
        cursor++;
    }
    while(*cursor != '\0') {
        const char* number = cursor;
        if(*cursor == '+' || *cursor == '-') {
            cursor++;
        }
        const char* digits = cursor;
        while(IJSVGLengthListIsDigit(*cursor)) {
            cursor++;
        }
        BOOL hasDigits = cursor != digits;
        if(*cursor == '.') {
            digits = ++cursor;
            while(IJSVGLengthListIsDigit(*cursor)) {
                cursor++;
            }
            hasDigits |= cursor != digits;
        }
        if(!hasDigits) {
            valid = NO;
            break;
        }
        // Reject negative nonzero mantissas before conversion can underflow to
        // signed zero. A genuinely zero value remains valid with either sign.
        if(!allowNegative && *number == '-') {
            for(const char* digit = number + 1; digit < cursor; digit++) {
                if(*digit >= '1' && *digit <= '9') {
                    valid = NO;
                    break;
                }
            }
            if(!valid) {
                break;
            }
        }

        // The letter e starts an exponent only when digits follow. em/ex are units.
        if(*cursor == 'e' || *cursor == 'E') {
            const char* exponent = cursor + 1;
            if(*exponent == '+' || *exponent == '-') {
                exponent++;
            }
            if(IJSVGLengthListIsDigit(*exponent)) {
                cursor = exponent + 1;
                while(IJSVGLengthListIsDigit(*cursor)) {
                    cursor++;
                }
            }
        }
        const char* suffix = cursor;
        while(*cursor != '\0' && *cursor != ',' && !IJSVGLengthListIsWhitespace(*cursor)) {
            cursor++;
        }
        size_t suffixLength = cursor - suffix;
        if(suffixLength > 2) {
            valid = NO;
            break;
        }
        char unit[3] = { 0 };
        memcpy(unit, suffix, suffixLength);
        IJSVGUnitLengthType type = IJSVGUnitLengthTypeForCString(unit);
        if(suffixLength != 0 &&
           (type == IJSVGUnitLengthTypeNumber ||
            (type == IJSVGUnitLengthTypePercentage ? suffixLength != 1 : suffixLength != 2))) {
            valid = NO;
            break;
        }
        CGFloat scalar = IJSVGParseFloatWithLength(number, (NSUInteger)(suffix - number));
        scalar = [IJSVGUnitLength convertUnitValue:scalar
                          toBaseFromUnitLengthType:type];
        if(!isfinite(scalar) || (!allowNegative && scalar < 0.f)) {
            valid = NO;
            break;
        }
        count++;
        if(single && count > 1) {
            return NO;
        }
        if(lengths != nil || singleLength != NULL) {
            IJSVGUnitLength* length = [IJSVGUnitLength unitWithFloat:scalar];
            length.originalType = type;
            if(type == IJSVGUnitLengthTypePercentage ||
               type == IJSVGUnitLengthTypeEM || type == IJSVGUnitLengthTypeEX) {
                length.type = type;
            }
            parsedLength = length;
            [lengths addObject:length];
        }
        while(IJSVGLengthListIsWhitespace(*cursor)) {
            cursor++;
        }
        if(*cursor == ',') {
            cursor++;
            while(IJSVGLengthListIsWhitespace(*cursor)) {
                cursor++;
            }
            if(*cursor == '\0') {
                valid = NO;
                break;
            }
        }
    }
    if(singleLength != NULL) {
        *singleLength = valid && count == 1 ? parsedLength : nil;
    }
    return valid && count != 0;
}

NSArray<IJSVGUnitLength*>* IJSVGUnitLengthsFromString(NSString* value)
{
    NSMutableArray<IJSVGUnitLength*>* lengths = [[NSMutableArray alloc] init];
    return IJSVGParseUnitLengths(value, NO, NO, lengths, NULL) ? lengths : nil;
}

BOOL IJSVGAttributeIsGeometryProperty(NSUInteger attribute)
{
    switch(attribute) {
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

static BOOL IJSVGGeometryPropertyAllowsAuto(IJSVGNodeAttribute attribute)
{
    return attribute == IJSVGNodeAttributeWidth || attribute == IJSVGNodeAttributeHeight ||
        attribute == IJSVGNodeAttributeRX || attribute == IJSVGNodeAttributeRY;
}

static BOOL IJSVGGeometryPropertyAllowsNegative(IJSVGNodeAttribute attribute)
{
    return attribute == IJSVGNodeAttributeX || attribute == IJSVGNodeAttributeY ||
        attribute == IJSVGNodeAttributeCX || attribute == IJSVGNodeAttributeCY;
}

typedef NS_ENUM(NSUInteger, IJSVGGeometryKeyword) {
    IJSVGGeometryKeywordNone,
    IJSVGGeometryKeywordInitial,
    IJSVGGeometryKeywordInherit,
    IJSVGGeometryKeywordAuto
};

static IJSVGGeometryKeyword IJSVGGeometryKeywordFromString(NSString* value)
{
    if([value isEqualToString:@"inherit"]) {
        return IJSVGGeometryKeywordInherit;
    }
    if([value isEqualToString:@"initial"] || [value isEqualToString:@"unset"] ||
       [value isEqualToString:@"revert"] || [value isEqualToString:@"revert-layer"]) {
        return IJSVGGeometryKeywordInitial;
    }
    return [value isEqualToString:@"auto"] ? IJSVGGeometryKeywordAuto : IJSVGGeometryKeywordNone;
}

static IJSVGUnitLength* IJSVGGeometryInitialLength(IJSVGNodeAttribute attribute)
{
    return [IJSVGUnitLength unitWithFloat:0.f type:IJSVGGeometryPropertyAllowsAuto(attribute) ?
        IJSVGUnitLengthTypeAuto : IJSVGUnitLengthTypeNumber];
}

static BOOL IJSVGParseGeometryLength(NSString* value, IJSVGNodeAttribute attribute,
                                     IJSVGUnitLength** parsedLength)
{
    const char* chars = value.UTF8String;
    if(chars == NULL) {
        return NO;
    }
    while(IJSVGLengthListIsWhitespace(*chars)) {
        chars++;
    }
    if((*chars >= 'a' && *chars <= 'z') || (*chars >= 'A' && *chars <= 'Z')) {
        NSString* keywordString = [value.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        IJSVGGeometryKeyword keyword = IJSVGGeometryKeywordFromString(keywordString);
        if(keyword == IJSVGGeometryKeywordNone ||
           (keyword == IJSVGGeometryKeywordAuto && !IJSVGGeometryPropertyAllowsAuto(attribute))) {
            return NO;
        }
        if(parsedLength != NULL) {
            IJSVGUnitLength* length = IJSVGGeometryInitialLength(attribute);
            length.inherit = keyword == IJSVGGeometryKeywordInherit;
            *parsedLength = length;
        }
        return YES;
    }
    return IJSVGParseUnitLengths(value, IJSVGGeometryPropertyAllowsNegative(attribute),
        YES, nil, parsedLength);
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

BOOL IJSVGGeometryPropertyAppliesToNode(IJSVGNodeAttribute attribute, IJSVGNode* node)
{
    switch(attribute) {
        case IJSVGNodeAttributeCX:
        case IJSVGNodeAttributeCY:
            return node.type == IJSVGNodeTypeCircle || node.type == IJSVGNodeTypeEllipse;
        case IJSVGNodeAttributeR:
            return node.type == IJSVGNodeTypeCircle;
        case IJSVGNodeAttributeRX:
        case IJSVGNodeAttributeRY:
            return node.type == IJSVGNodeTypeRect || node.type == IJSVGNodeTypeEllipse;
        default:
            return node.type == IJSVGNodeTypeRect || node.type == IJSVGNodeTypeImage ||
                node.type == IJSVGNodeTypeSVG || node.type == IJSVGNodeTypeUse ||
                node.type == IJSVGNodeTypeSymbol || node.type == IJSVGNodeTypeForeignObject;
    }
}

void IJSVGApplyGeometryAttributes(IJSVGNode* node,
                                  NSString* __unsafe_unretained attributeValues[kIJSVGNodeAttributeStorageLength],
                                  IJSVGStyleSheetStyle* style,
                                  IJSVGStyleSheetStyle* inlineStyle)
{
    const IJSVGNodeAttribute attributes[] = {
        IJSVGNodeAttributeX, IJSVGNodeAttributeY, IJSVGNodeAttributeWidth, IJSVGNodeAttributeHeight,
        IJSVGNodeAttributeCX, IJSVGNodeAttributeCY, IJSVGNodeAttributeR,
        IJSVGNodeAttributeRX, IJSVGNodeAttributeRY
    };
    NSString* names[] = {
        IJSVGAttributeX, IJSVGAttributeY, IJSVGAttributeWidth, IJSVGAttributeHeight,
        IJSVGAttributeCX, IJSVGAttributeCY, IJSVGAttributeR, IJSVGAttributeRX,
        IJSVGAttributeRY
    };
    NSMutableDictionary<NSNumber*, IJSVGUnitLength*>* lengths = nil;
    for(NSUInteger index = 0; index < sizeof(attributes) / sizeof(*attributes); index++) {
        IJSVGNodeAttribute attribute = attributes[index];
        NSString* name = names[index];
        NSString* value = [inlineStyle property:name];
        if(value == nil || ([style isPropertyImportant:name] && ![inlineStyle isPropertyImportant:name])) {
            value = [style property:name];
        }
        if(value == nil && attributeValues[attribute] == nil) {
            continue;
        }
        BOOL applies = IJSVGGeometryPropertyAppliesToNode(attribute, node);
        if(value == nil) {
            if(!applies) {
                continue;
            }
            value = attributeValues[attribute];
        }
        IJSVGUnitLength* length = IJSVGGeometryLengthFromString(value, attribute)
            ?: IJSVGGeometryInitialLength(attribute);
        if(length.inherit) {
            length = node.styleParent.geometryLengths[@(attribute)]
                ?: IJSVGGeometryInitialLength(attribute);
        }
        if(lengths == nil) {
            lengths = [[NSMutableDictionary alloc] init];
        }
        lengths[@(attribute)] = length;
        if(!applies) {
            continue;
        }
        IJSVGUnitLength* used = length.type == IJSVGUnitLengthTypeAuto ? nil : length;
        switch(attribute) {
            case IJSVGNodeAttributeX:
                node.x = used;
                break;
            case IJSVGNodeAttributeY:
                node.y = used;
                break;
            case IJSVGNodeAttributeWidth:
                node.width = used;
                break;
            case IJSVGNodeAttributeHeight:
                node.height = used;
                break;
            case IJSVGNodeAttributeCX:
                ((IJSVGPath*)node).cx = used;
                break;
            case IJSVGNodeAttributeCY:
                ((IJSVGPath*)node).cy = used;
                break;
            case IJSVGNodeAttributeR:
                ((IJSVGPath*)node).r = used;
                break;
            case IJSVGNodeAttributeRX:
                ((IJSVGPath*)node).rx = used;
                break;
            case IJSVGNodeAttributeRY:
                ((IJSVGPath*)node).ry = used;
                break;
            default:
                break;
        }
    }
    node.geometryLengths = lengths;
}

IJSVGPaintOrder IJSVGPaintOrderFromString(NSString* value)
{
    value = [value.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if([value isEqualToString:@"normal"] || [value isEqualToString:@"initial"]) {
        return IJSVGPaintOrderNormal;
    }
    NSArray* names = @[@"fill", @"stroke", @"markers"];
    NSUInteger seen = 0, order = 0, count = 0;
    for(NSString* token in [value componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]) {
        if(token.length == 0) {
            continue;
        }
        NSUInteger operation = [names indexOfObject:token];
        if(operation == NSNotFound || (seen & (1 << operation)) != 0) {
            return IJSVGPaintOrderInherit;
        }
        seen |= 1 << operation;
        order |= operation << (2 * count++);
    }
    if(count == 0) {
        return IJSVGPaintOrderInherit;
    }
    for(NSUInteger operation = 0; operation < 3; operation++) {
        if((seen & (1 << operation)) == 0) {
            order |= operation << (2 * count++);
        }
    }
    return (IJSVGPaintOrder)order;
}

NSString* IJSVGStringFromPaintOrder(IJSVGPaintOrder order)
{
    NSArray* names = @[@"fill", @"stroke", @"markers"];
    return [NSString stringWithFormat:@"%@ %@ %@", names[order & 3],
            names[(order >> 2) & 3], names[(order >> 4) & 3]];
}

BOOL IJSVGIsolationFromString(NSString* value, BOOL parentIsolation)
{
    if([value isEqualToString:@"inherit"]) {
        return parentIsolation;
    }
    return [value isEqualToString:@"isolate"];
}

IJSVGUnitLength* IJSVGDimensionFromString(NSString* value, IJSVGNodeType type)
{
    IJSVGUnitLength* length = [IJSVGUnitLength unitWithString:value];
    BOOL viewportUse = type == IJSVGNodeTypeUse || type == IJSVGNodeTypeSymbol;
    if(viewportUse && ([value isEqualToString:@"auto"] || length.value < 0.f)) {
        return nil;
    }
    return length;
}

IJSVGUnitLength* IJSVGSymbolReferenceFromString(NSString* value,
                                                IJSVGNodeAttribute attribute)
{
    if(value == nil) {
        return nil;
    }
    BOOL horizontal;
    switch(attribute) {
        case IJSVGNodeAttributeRefX:
            horizontal = YES;
            break;
        case IJSVGNodeAttributeRefY:
            horizontal = NO;
            break;
        default:
            return nil;
    }
    if([value isEqualToString:horizontal ? @"left" : @"top"]) {
        value = @"0%";
    } else if([value isEqualToString:@"center"]) {
        value = @"50%";
    } else if([value isEqualToString:horizontal ? @"right" : @"bottom"]) {
        value = @"100%";
    }
    return [IJSVGUnitLength unitWithString:value];
}

void IJSVGApplyBackgroundAttribute(IJSVGNode* node, NSString* value)
{
    char* buffer = IJSVGTimmedCharBufferCreate(value.UTF8String);
    if(buffer == NULL) {
        return;
    }
    size_t length = strcspn(buffer, " \t\r\n");
    char* parameters = buffer + length;
    if(*parameters != 0) {
        *parameters++ = 0;
        IJSVGTrimCharBuffer(parameters);
    }
    IJSVGBackgroundEnabled mode = IJSVGBackgroundEnabledUnspecified;
    CGRect bounds = CGRectNull;
    if(IJSVGCharBufferCompare(buffer, "inherit") && *parameters == 0) {
        mode = IJSVGBackgroundEnabledInherit;
    } else if(IJSVGCharBufferCompare(buffer, "accumulate") && *parameters == 0) {
        mode = IJSVGBackgroundEnabledAccumulate;
    } else if(IJSVGCharBufferCompare(buffer, "new")) {
        if(*parameters == 0) {
            mode = IJSVGBackgroundEnabledNew;
            bounds = CGRectInfinite;
        } else {
            NSArray<NSNumber*>* numbers = [IJSVGUtils numbersFromString:@(parameters)];
            if(numbers.count == 4 && numbers[2].doubleValue > 0 && numbers[3].doubleValue > 0) {
                mode = IJSVGBackgroundEnabledNew;
                bounds = CGRectMake(numbers[0].doubleValue, numbers[1].doubleValue,
                                    numbers[2].doubleValue, numbers[3].doubleValue);
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

NSString* IJSVGAttributeValue(NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength],
                              IJSVGNodeAttribute attribute)
{
    return attributeValues[attribute];
}

BOOL IJSVGAttributeHasValue(NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength],
                            IJSVGNodeAttribute attribute, NSString* __autoreleasing* value)
{
    NSString* attributeValue = IJSVGAttributeValue(attributeValues, attribute);
    if(attributeValue.length == 0) {
        return NO;
    }
    if(value != NULL) {
        *value = attributeValue;
    }
    return YES;
}

BOOL IJSVGReadXMLAttribute(NSXMLNode* node, IJSVGBitFlags* activeAttributes,
                           NSUInteger* attribute, NSString* __autoreleasing* value)
{
    NSUInteger index = IJSVGNodeAttributeForName(node.name);
    if(index == NSNotFound ||
       (activeAttributes != nil && ![activeAttributes bitIsSet:(int)index])) {
        return NO;
    }
    NSString* string = node.stringValue;
    if(string.length == 0) {
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

static void IJSVGStorePrioritizedStyleAttributes(IJSVGStyleSheetStyle* style,
                                                 IJSVGStyleSheetStyle* fallback,
                                                 IJSVGBitFlags* activeAttributes,
                                                 NSString* __unsafe_unretained attributeValues[kIJSVGNodeAttributeStorageLength])
{
    NSDictionary* properties = style.properties;
    for(NSString* key in properties) {
        if([fallback isPropertyImportant:key] && ![style isPropertyImportant:key]) {
            continue;
        }
        NSUInteger attribute = IJSVGNodeAttributeForName(key);
        if(attribute == NSNotFound || IJSVGAttributeIsGeometryProperty(attribute) ||
           [activeAttributes bitIsSet:(int)attribute] == NO) {
            continue;
        }
        NSString* value = properties[key];
        if(value.length == 0) {
            continue;
        }
        attributeValues[attribute] = value;
    }
}

void IJSVGStoreStyleAttributes(IJSVGStyleSheetStyle* style,
                               IJSVGBitFlags* activeAttributes,
                               NSString* __unsafe_unretained attributeValues[kIJSVGNodeAttributeStorageLength])
{
    IJSVGStorePrioritizedStyleAttributes(style, nil, activeAttributes, attributeValues);
}

void IJSVGStoreCascadedStyleAttributes(IJSVGStyleSheetStyle* style,
                                       IJSVGStyleSheetStyle* inlineStyle, IJSVGBitFlags* activeAttributes,
                                       NSString* __unsafe_unretained attributeValues[kIJSVGNodeAttributeStorageLength])
{
    IJSVGStorePrioritizedStyleAttributes(style, nil, activeAttributes, attributeValues);
    IJSVGStorePrioritizedStyleAttributes(inlineStyle, style, activeAttributes, attributeValues);
}

void IJSVGApplyTransformAttribute(IJSVGNode* node, NSString* value)
{
    NSMutableArray<IJSVGTransform*>* transforms = [IJSVGTransform transformsForString:value].mutableCopy;
    if(transforms == nil) {
        transforms = [[NSMutableArray alloc] init];
    }
    if(node.transforms != nil) {
        [transforms addObjectsFromArray:node.transforms];
    }
    node.transforms = transforms;
}

static inline BOOL IJSVGAttributeNameEquals(const char* name, size_t length,
                                            const char* expected)
{
    return expected[length] == '\0' && memcmp(name, expected, length) == 0;
}

NSUInteger IJSVGNodeAttributeForName(NSString* name)
{
    if([name isEqualToString:IJSVGAttributeVectorEffect]) {
        return IJSVGNodeAttributeVectorEffect;
    }
    const char* attributeName = name.UTF8String;
    if(attributeName == NULL) {
        return NSNotFound;
    }

    size_t length = strlen(attributeName);
    switch(length) {
        case 1: {
            char c = attributeName[0];
            if(c == 'd') {
                return IJSVGNodeAttributeD;
            }
            if(c == 'x') {
                return IJSVGNodeAttributeX;
            }
            if(c == 'y') {
                return IJSVGNodeAttributeY;
            }
            if(c == 'r') {
                return IJSVGNodeAttributeR;
            }
            break;
        }
        case 2: {
            if(IJSVGAttributeNameEquals(attributeName, length, "dx")) {
                return IJSVGNodeAttributeDX;
            }
            if(IJSVGAttributeNameEquals(attributeName, length, "dy")) {
                return IJSVGNodeAttributeDY;
            }
            if(IJSVGAttributeNameEquals(attributeName, length, "in")) {
                return IJSVGNodeAttributeIn;
            }
            char c = attributeName[0];
            if(c == 'i' && IJSVGAttributeNameEquals(attributeName, length, "id")) {
                return IJSVGNodeAttributeID;
            }
            if(c == 'c') {
                if(IJSVGAttributeNameEquals(attributeName, length, "cx")) {
                    return IJSVGNodeAttributeCX;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "cy")) {
                    return IJSVGNodeAttributeCY;
                }
            }
            if(c == 'f') {
                if(IJSVGAttributeNameEquals(attributeName, length, "fx")) {
                    return IJSVGNodeAttributeFX;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "fy")) {
                    return IJSVGNodeAttributeFY;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "fr")) {
                    return IJSVGNodeAttributeFR;
                }
            }
            if(c == 'r') {
                if(IJSVGAttributeNameEquals(attributeName, length, "rx")) {
                    return IJSVGNodeAttributeRX;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "ry")) {
                    return IJSVGNodeAttributeRY;
                }
            }
            if(c == 'x') {
                if(IJSVGAttributeNameEquals(attributeName, length, "x1")) {
                    return IJSVGNodeAttributeX1;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "x2")) {
                    return IJSVGNodeAttributeX2;
                }
            }
            if(c == 'y') {
                if(IJSVGAttributeNameEquals(attributeName, length, "y1")) {
                    return IJSVGNodeAttributeY1;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "y2")) {
                    return IJSVGNodeAttributeY2;
                }
            }
            break;
        }
        case 4: {
            char c = attributeName[0];
            if(c == 'f' && IJSVGAttributeNameEquals(attributeName, length, "fill")) {
                return IJSVGNodeAttributeFill;
            }
            if(c == 'h' && IJSVGAttributeNameEquals(attributeName, length, "href")) {
                return IJSVGNodeAttributeHref;
            }
            if(c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "mask")) {
                return IJSVGNodeAttributeMask;
            }
            break;
        }
        case 5: {
            char c = attributeName[0];
            if(c == 'c' && IJSVGAttributeNameEquals(attributeName, length, "class")) {
                return IJSVGNodeAttributeClass;
            }
            if(c == 's' && IJSVGAttributeNameEquals(attributeName, length, "style")) {
                return IJSVGNodeAttributeStyle;
            }
            if(c == 'w' && IJSVGAttributeNameEquals(attributeName, length, "width")) {
                return IJSVGNodeAttributeWidth;
            }
            if(c == 'x' && IJSVGAttributeNameEquals(attributeName, length, "xmlns")) {
                return IJSVGNodeAttributeXMLNS;
            }
            break;
        }
        case 6: {
            if(IJSVGAttributeNameEquals(attributeName, length, "result")) {
                return IJSVGNodeAttributeResult;
            }
            char c = attributeName[0];
            if(c == 'f' && IJSVGAttributeNameEquals(attributeName, length, "filter")) {
                return IJSVGNodeAttributeFilter;
            }
            if(c == 'h' && IJSVGAttributeNameEquals(attributeName, length, "height")) {
                return IJSVGNodeAttributeHeight;
            }
            if(c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "marker")) {
                return IJSVGNodeAttributeMarker;
            }
            if(c == 'o' && IJSVGAttributeNameEquals(attributeName, length, "offset")) {
                return IJSVGNodeAttributeOffset;
            }
            if(c == 'p' && IJSVGAttributeNameEquals(attributeName, length, "points")) {
                return IJSVGNodeAttributePoints;
            }
            if(c == 's' && IJSVGAttributeNameEquals(attributeName, length, "stroke")) {
                return IJSVGNodeAttributeStroke;
            }
            break;
        }
        case 7: {
            char c = attributeName[0];
            if(c == 'd' && IJSVGAttributeNameEquals(attributeName, length, "display")) {
                return IJSVGNodeAttributeDisplay;
            }
            if(c == 'o' && IJSVGAttributeNameEquals(attributeName, length, "opacity")) {
                return IJSVGNodeAttributeOpacity;
            }
            if(c == 'u' && IJSVGAttributeNameEquals(attributeName, length, "unicode")) {
                return IJSVGNodeAttributeUnicode;
            }
            if(c == 'v') {
                if(IJSVGAttributeNameEquals(attributeName, length, "version")) {
                    return IJSVGNodeAttributeVersion;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "viewBox")) {
                    return IJSVGNodeAttributeViewBox;
                }
            }
            break;
        }
        case 8: {
            if(IJSVGAttributeNameEquals(attributeName, length, "overflow")) {
                return IJSVGNodeAttributeOverflow;
            }
            break;
        }
        case 9: {
            char c = attributeName[0];
            if(c == 'i' && IJSVGAttributeNameEquals(attributeName, length, "isolation")) {
                return IJSVGNodeAttributeIsolation;
            }
            if(c == 'c') {
                if(IJSVGAttributeNameEquals(attributeName, length, "clip-path")) {
                    return IJSVGNodeAttributeClipPath;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "clip-rule")) {
                    return IJSVGNodeAttributeClipRule;
                }
            }
            if(c == 'f' && IJSVGAttributeNameEquals(attributeName, length, "fill-rule")) {
                return IJSVGNodeAttributeFillRule;
            }
            if(c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "maskUnits")) {
                return IJSVGNodeAttributeMaskUnits;
            }
            if(c == 't' && IJSVGAttributeNameEquals(attributeName, length, "transform")) {
                return IJSVGNodeAttributeTransform;
            }
            break;
        }
        case 10: {
            char c = attributeName[0];
            if(c == 's' && IJSVGAttributeNameEquals(attributeName, length, "stop-color")) {
                return IJSVGNodeAttributeStopColor;
            }
            if(c == 'x' && IJSVGAttributeNameEquals(attributeName, length, "xlink:href")) {
                return IJSVGNodeAttributeXLink;
            }
            break;
        }
        case 11: {
            if(IJSVGAttributeNameEquals(attributeName, length, "paint-order")) {
                return IJSVGNodeAttributePaintOrder;
            }
            if(IJSVGAttributeNameEquals(attributeName, length, "flood-color")) {
                return IJSVGNodeAttributeFloodColor;
            }
            if(IJSVGAttributeNameEquals(attributeName, length, "filterUnits")) {
                return IJSVGNodeAttributeFilterUnits;
            }
            if(IJSVGAttributeNameEquals(attributeName, length, "xmlns:xlink")) {
                return IJSVGNodeAttributeXMLNSXlink;
            }
            break;
        }
        case 12: {
            if(IJSVGAttributeNameEquals(attributeName, length, "stdDeviation")) {
                return IJSVGNodeAttributeStdDeviation;
            }
            char c = attributeName[0];
            if(c == 'f' && IJSVGAttributeNameEquals(attributeName, length, "fill-opacity")) {
                return IJSVGNodeAttributeFillOpacity;
            }
            if(c == 'p' && IJSVGAttributeNameEquals(attributeName, length, "patternUnits")) {
                return IJSVGNodeAttributePatternUnits;
            }
            if(c == 's') {
                if(IJSVGAttributeNameEquals(attributeName, length, "stroke-width")) {
                    return IJSVGNodeAttributeStrokeWidth;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "stop-opacity")) {
                    return IJSVGNodeAttributeStopOpacity;
                }
            }
            break;
        }
        case 13: {
            if(IJSVGAttributeNameEquals(attributeName, length, "flood-opacity")) {
                return IJSVGNodeAttributeFloodOpacity;
            }
            char c = attributeName[0];
            if(c == 'c' && IJSVGAttributeNameEquals(attributeName, length, "clipPathUnits")) {
                return IJSVGNodeAttributeClipPathUnits;
            }
            if(c == 'g' && IJSVGAttributeNameEquals(attributeName, length, "gradientUnits")) {
                return IJSVGNodeAttributeGradientUnits;
            }
            break;
        }
        case 14: {
            char c = attributeName[0];
            if(c == 'p' && IJSVGAttributeNameEquals(attributeName, length, "primitiveUnits")) {
                return IJSVGNodeAttributePrimitiveUnits;
            }
            if(c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "mix-blend-mode")) {
                return IJSVGNodeAttributeBlendMode;
            }
            if(c == 's') {
                if(IJSVGAttributeNameEquals(attributeName, length, "stroke-linecap")) {
                    return IJSVGNodeAttributeStrokeLineCap;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "stroke-opacity")) {
                    return IJSVGNodeAttributeStrokeOpacity;
                }
            }
            break;
        }
        case 15: {
            if(IJSVGAttributeNameEquals(attributeName, length, "stroke-linejoin")) {
                return IJSVGNodeAttributeStrokeLineJoin;
            }
            break;
        }
        case 16: {
            char c = attributeName[0];
            if(c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "maskContentUnits")) {
                return IJSVGNodeAttributeMaskContentUnits;
            }
            if(c == 'p' && IJSVGAttributeNameEquals(attributeName, length, "patternTransform")) {
                return IJSVGNodeAttributePatternTransform;
            }
            if(c == 's' && IJSVGAttributeNameEquals(attributeName, length, "stroke-dasharray")) {
                return IJSVGNodeAttributeStrokeDashArray;
            }
            break;
        }
        case 17: {
            char c = attributeName[0];
            if(c == 'g' && IJSVGAttributeNameEquals(attributeName, length, "gradientTransform")) {
                return IJSVGNodeAttributeGradientTransform;
            }
            if(c == 's') {
                if(IJSVGAttributeNameEquals(attributeName, length, "stroke-dashoffset")) {
                    return IJSVGNodeAttributeStrokeDashOffset;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "stroke-miterlimit")) {
                    return IJSVGNodeAttributeStrokeMiterLimit;
                }
            }
            break;
        }
        case 19: {
            char c = attributeName[0];
            if(c == 'p') {
                if(IJSVGAttributeNameEquals(attributeName, length, "patternContentUnits")) {
                    return IJSVGNodeAttributePatternContentUnits;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "preserveAspectRatio")) {
                    return IJSVGNodeAttributePreserveAspectRatio;
                }
            }
            break;
        }
    }

    static NSDictionary<NSString*, NSNumber*>* attributes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        attributes = @{
            IJSVGAttributeVersion: @(IJSVGNodeAttributeVersion),
            IJSVGAttributeXMLNS: @(IJSVGNodeAttributeXMLNS),
            IJSVGAttributeXMLNSXlink: @(IJSVGNodeAttributeXMLNSXlink),
            IJSVGAttributeViewBox: @(IJSVGNodeAttributeViewBox),
            IJSVGAttributePreserveAspectRatio: @(IJSVGNodeAttributePreserveAspectRatio),
            IJSVGAttributeID: @(IJSVGNodeAttributeID),
            IJSVGAttributeClass: @(IJSVGNodeAttributeClass),
            IJSVGAttributeX: @(IJSVGNodeAttributeX),
            IJSVGAttributeY: @(IJSVGNodeAttributeY),
            IJSVGAttributeWidth: @(IJSVGNodeAttributeWidth),
            IJSVGAttributeHeight: @(IJSVGNodeAttributeHeight),
            IJSVGAttributeOpacity: @(IJSVGNodeAttributeOpacity),
            IJSVGAttributeStrokeOpacity: @(IJSVGNodeAttributeStrokeOpacity),
            IJSVGAttributeStrokeWidth: @(IJSVGNodeAttributeStrokeWidth),
            IJSVGAttributeStrokeDashOffset: @(IJSVGNodeAttributeStrokeDashOffset),
            IJSVGAttributeFillOpacity: @(IJSVGNodeAttributeFillOpacity),
            IJSVGAttributeClipPath: @(IJSVGNodeAttributeClipPath),
            IJSVGAttributeClipPathUnits: @(IJSVGNodeAttributeClipPathUnits),
            IJSVGAttributeClipRule: @(IJSVGNodeAttributeClipRule),
            IJSVGAttributeMask: @(IJSVGNodeAttributeMask),
            IJSVGAttributeGradientUnits: @(IJSVGNodeAttributeGradientUnits),
            IJSVGAttributePatternUnits: @(IJSVGNodeAttributePatternUnits),
            IJSVGAttributePatternContentUnits: @(IJSVGNodeAttributePatternContentUnits),
            IJSVGAttributePatternTransform: @(IJSVGNodeAttributePatternTransform),
            IJSVGAttributeMaskUnits: @(IJSVGNodeAttributeMaskUnits),
            IJSVGAttributeMaskContentUnits: @(IJSVGNodeAttributeMaskContentUnits),
            IJSVGAttributeTransform: @(IJSVGNodeAttributeTransform),
            IJSVGAttributeGradientTransform: @(IJSVGNodeAttributeGradientTransform),
            IJSVGAttributeUnicode: @(IJSVGNodeAttributeUnicode),
            IJSVGAttributeStrokeLineCap: @(IJSVGNodeAttributeStrokeLineCap),
            IJSVGAttributeStrokeLineJoin: @(IJSVGNodeAttributeStrokeLineJoin),
            IJSVGAttributeStroke: @(IJSVGNodeAttributeStroke),
            IJSVGAttributeStrokeDashArray: @(IJSVGNodeAttributeStrokeDashArray),
            IJSVGAttributeStrokeMiterLimit: @(IJSVGNodeAttributeStrokeMiterLimit),
            IJSVGAttributeFill: @(IJSVGNodeAttributeFill),
            IJSVGAttributeFillRule: @(IJSVGNodeAttributeFillRule),
            IJSVGAttributeBlendMode: @(IJSVGNodeAttributeBlendMode),
            IJSVGAttributeIsolation: @(IJSVGNodeAttributeIsolation),
            IJSVGAttributePaintOrder: @(IJSVGNodeAttributePaintOrder),
            IJSVGAttributeVectorEffect: @(IJSVGNodeAttributeVectorEffect),
            IJSVGAttributeDisplay: @(IJSVGNodeAttributeDisplay),
            IJSVGAttributeStyle: @(IJSVGNodeAttributeStyle),
            IJSVGAttributeD: @(IJSVGNodeAttributeD),
            IJSVGAttributeXLink: @(IJSVGNodeAttributeXLink),
            IJSVGAttributeX1: @(IJSVGNodeAttributeX1),
            IJSVGAttributeX2: @(IJSVGNodeAttributeX2),
            IJSVGAttributeY1: @(IJSVGNodeAttributeY1),
            IJSVGAttributeY2: @(IJSVGNodeAttributeY2),
            IJSVGAttributeRX: @(IJSVGNodeAttributeRX),
            IJSVGAttributeRY: @(IJSVGNodeAttributeRY),
            IJSVGAttributeCX: @(IJSVGNodeAttributeCX),
            IJSVGAttributeCY: @(IJSVGNodeAttributeCY),
            IJSVGAttributeR: @(IJSVGNodeAttributeR),
            IJSVGAttributeFX: @(IJSVGNodeAttributeFX),
            IJSVGAttributeFY: @(IJSVGNodeAttributeFY),
            IJSVGAttributeFR: @(IJSVGNodeAttributeFR),
            IJSVGAttributePoints: @(IJSVGNodeAttributePoints),
            IJSVGAttributeOffset: @(IJSVGNodeAttributeOffset),
            IJSVGAttributeStopColor: @(IJSVGNodeAttributeStopColor),
            IJSVGAttributeStopOpacity: @(IJSVGNodeAttributeStopOpacity),
            IJSVGAttributeHref: @(IJSVGNodeAttributeHref),
            IJSVGAttributeOverflow: @(IJSVGNodeAttributeOverflow),
            IJSVGAttributeMarker: @(IJSVGNodeAttributeMarker),
            IJSVGAttributeFilter: @(IJSVGNodeAttributeFilter),
            IJSVGAttributeFilterUnits: @(IJSVGNodeAttributeFilterUnits),
            IJSVGAttributePrimitiveUnits: @(IJSVGNodeAttributePrimitiveUnits),
            IJSVGAttributeDX: @(IJSVGNodeAttributeDX),
            IJSVGAttributeDY: @(IJSVGNodeAttributeDY),
            IJSVGAttributeStdDeviation: @(IJSVGNodeAttributeStdDeviation),
            IJSVGAttributeFloodColor: @(IJSVGNodeAttributeFloodColor),
            IJSVGAttributeFloodOpacity: @(IJSVGNodeAttributeFloodOpacity),
            IJSVGAttributeIn: @(IJSVGNodeAttributeIn),
            IJSVGAttributeResult: @(IJSVGNodeAttributeResult),
            IJSVGAttributeIn2: @(IJSVGNodeAttributeIn2),
            IJSVGAttributeMode: @(IJSVGNodeAttributeMode),
            IJSVGAttributeType: @(IJSVGNodeAttributeType),
            IJSVGAttributeValues: @(IJSVGNodeAttributeValues),
            IJSVGAttributeOperator: @(IJSVGNodeAttributeOperator),
            IJSVGAttributeK1: @(IJSVGNodeAttributeK1),
            IJSVGAttributeK2: @(IJSVGNodeAttributeK2),
            IJSVGAttributeK3: @(IJSVGNodeAttributeK3),
            IJSVGAttributeK4: @(IJSVGNodeAttributeK4),
            IJSVGAttributeOrder: @(IJSVGNodeAttributeOrder),
            IJSVGAttributeKernelMatrix: @(IJSVGNodeAttributeKernelMatrix),
            IJSVGAttributeDivisor: @(IJSVGNodeAttributeDivisor),
            IJSVGAttributeBias: @(IJSVGNodeAttributeBias),
            IJSVGAttributeTargetX: @(IJSVGNodeAttributeTargetX),
            IJSVGAttributeTargetY: @(IJSVGNodeAttributeTargetY),
            IJSVGAttributeEdgeMode: @(IJSVGNodeAttributeEdgeMode),
            IJSVGAttributeKernelUnitLength: @(IJSVGNodeAttributeKernelUnitLength),
            IJSVGAttributePreserveAlpha: @(IJSVGNodeAttributePreserveAlpha),
            IJSVGAttributeSurfaceScale: @(IJSVGNodeAttributeSurfaceScale),
            IJSVGAttributeDiffuseConstant: @(IJSVGNodeAttributeDiffuseConstant),
            IJSVGAttributeSpecularConstant: @(IJSVGNodeAttributeSpecularConstant),
            IJSVGAttributeSpecularExponent: @(IJSVGNodeAttributeSpecularExponent),
            IJSVGAttributeLightingColor: @(IJSVGNodeAttributeLightingColor),
            IJSVGAttributeScale: @(IJSVGNodeAttributeScale),
            IJSVGAttributeXChannelSelector: @(IJSVGNodeAttributeXChannelSelector),
            IJSVGAttributeYChannelSelector: @(IJSVGNodeAttributeYChannelSelector),
            IJSVGAttributeRadius: @(IJSVGNodeAttributeRadius),
            IJSVGAttributeBaseFrequency: @(IJSVGNodeAttributeBaseFrequency),
            IJSVGAttributeNumOctaves: @(IJSVGNodeAttributeNumOctaves),
            IJSVGAttributeSeed: @(IJSVGNodeAttributeSeed),
            IJSVGAttributeStitchTiles: @(IJSVGNodeAttributeStitchTiles),
            IJSVGAttributeTableValues: @(IJSVGNodeAttributeTableValues),
            IJSVGAttributeSlope: @(IJSVGNodeAttributeSlope),
            IJSVGAttributeIntercept: @(IJSVGNodeAttributeIntercept),
            IJSVGAttributeAmplitude: @(IJSVGNodeAttributeAmplitude),
            IJSVGAttributeExponent: @(IJSVGNodeAttributeExponent),
            IJSVGAttributeAzimuth: @(IJSVGNodeAttributeAzimuth),
            IJSVGAttributeElevation: @(IJSVGNodeAttributeElevation),
            IJSVGAttributeZ: @(IJSVGNodeAttributeZ),
            IJSVGAttributePointsAtX: @(IJSVGNodeAttributePointsAtX),
            IJSVGAttributePointsAtY: @(IJSVGNodeAttributePointsAtY),
            IJSVGAttributePointsAtZ: @(IJSVGNodeAttributePointsAtZ),
            IJSVGAttributeLimitingConeAngle: @(IJSVGNodeAttributeLimitingConeAngle),
            IJSVGAttributeColorInterpolationFilters: @(IJSVGNodeAttributeColorInterpolationFilters),
            IJSVGAttributeEnableBackground: @(IJSVGNodeAttributeEnableBackground),
            IJSVGAttributeFont: @(IJSVGNodeAttributeFont),
            IJSVGAttributeFontFamily: @(IJSVGNodeAttributeFontFamily),
            IJSVGAttributeFontSize: @(IJSVGNodeAttributeFontSize),
            IJSVGAttributeFontWeight: @(IJSVGNodeAttributeFontWeight),
            IJSVGAttributeFontStyle: @(IJSVGNodeAttributeFontStyle),
            IJSVGAttributeFontStretch: @(IJSVGNodeAttributeFontStretch),
            IJSVGAttributeFontVariant: @(IJSVGNodeAttributeFontVariant),
            IJSVGAttributeFontVariantLigatures: @(IJSVGNodeAttributeFontVariantLigatures),
            IJSVGAttributeFontFeatureSettings: @(IJSVGNodeAttributeFontFeatureSettings),
            IJSVGAttributeFontKerning: @(IJSVGNodeAttributeFontKerning),
            IJSVGAttributeLetterSpacing: @(IJSVGNodeAttributeLetterSpacing),
            IJSVGAttributeWordSpacing: @(IJSVGNodeAttributeWordSpacing),
            IJSVGAttributeTextAnchor: @(IJSVGNodeAttributeTextAnchor),
            IJSVGAttributeDirection: @(IJSVGNodeAttributeDirection),
            IJSVGAttributeUnicodeBidi: @(IJSVGNodeAttributeUnicodeBidi),
            IJSVGAttributeWritingMode: @(IJSVGNodeAttributeWritingMode),
            IJSVGAttributeTextOrientation: @(IJSVGNodeAttributeTextOrientation),
            IJSVGAttributeDominantBaseline: @(IJSVGNodeAttributeDominantBaseline),
            IJSVGAttributeAlignmentBaseline: @(IJSVGNodeAttributeAlignmentBaseline),
            IJSVGAttributeBaselineShift: @(IJSVGNodeAttributeBaselineShift),
            IJSVGAttributeTextDecoration: @(IJSVGNodeAttributeTextDecoration),
            IJSVGAttributeTextDecorationLine: @(IJSVGNodeAttributeTextDecorationLine),
            IJSVGAttributeWhiteSpace: @(IJSVGNodeAttributeWhiteSpace),
            IJSVGAttributeLineHeight: @(IJSVGNodeAttributeLineHeight),
            IJSVGAttributeInlineSize: @(IJSVGNodeAttributeInlineSize),
            IJSVGAttributeTextTransform: @(IJSVGNodeAttributeTextTransform),
            IJSVGAttributeTextOverflow: @(IJSVGNodeAttributeTextOverflow),
            IJSVGAttributeXMLSpace: @(IJSVGNodeAttributeXMLSpace),
            IJSVGAttributeLang: @(IJSVGNodeAttributeLang),
            IJSVGAttributeXMLLang: @(IJSVGNodeAttributeXMLLang),
            IJSVGAttributeTextRendering: @(IJSVGNodeAttributeTextRendering),
            IJSVGAttributeRotate: @(IJSVGNodeAttributeRotate),
            IJSVGAttributeTextLength: @(IJSVGNodeAttributeTextLength),
            IJSVGAttributeLengthAdjust: @(IJSVGNodeAttributeLengthAdjust),
            IJSVGAttributeStartOffset: @(IJSVGNodeAttributeStartOffset),
            IJSVGAttributeMethod: @(IJSVGNodeAttributeMethod),
            IJSVGAttributeSpacing: @(IJSVGNodeAttributeSpacing),
            IJSVGAttributeSide: @(IJSVGNodeAttributeSide),
            IJSVGAttributePath: @(IJSVGNodeAttributePath),
            IJSVGAttributePathLength: @(IJSVGNodeAttributePathLength),
            IJSVGAttributeMarkerStart: @(IJSVGNodeAttributeMarkerStart),
            IJSVGAttributeMarkerMid: @(IJSVGNodeAttributeMarkerMid),
            IJSVGAttributeMarkerEnd: @(IJSVGNodeAttributeMarkerEnd),
            IJSVGAttributeRefX: @(IJSVGNodeAttributeRefX),
            IJSVGAttributeRefY: @(IJSVGNodeAttributeRefY),
            IJSVGAttributeMarkerWidth: @(IJSVGNodeAttributeMarkerWidth),
            IJSVGAttributeMarkerHeight: @(IJSVGNodeAttributeMarkerHeight),
            IJSVGAttributeMarkerUnits: @(IJSVGNodeAttributeMarkerUnits),
            IJSVGAttributeOrient: @(IJSVGNodeAttributeOrient)
        };
    });
    NSNumber* attribute = attributes[name];
    return attribute == nil ? NSNotFound : attribute.unsignedIntegerValue;
}
