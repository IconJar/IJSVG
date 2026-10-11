//
//  IJSVGUnitLength.m
//  IJSVG
//
//  Created by Curtis Hard on 13/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGUnitLength.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGParserUtils.h>

static BOOL IJSVGParseScalarUnit(const char* bytes, CGFloat* value,
                                 IJSVGUnitLengthType* type)
{
    if(bytes == NULL) {
        return NO;
    }
    if(bytes[0] >= '0' && bytes[0] <= '9' && bytes[1] == '\0') {
        *value = bytes[0] - '0';
        *type = IJSVGUnitLengthTypeNumber;
        return YES;
    }
    const char* end = bytes;
    if(!IJSVGParseLengthNumber(&end, YES, value)) {
        return NO;
    }
    if(*end == '\0') {
        *type = IJSVGUnitLengthTypeNumber;
        return YES;
    }
    if(end[0] == '%' && end[1] == '\0') {
        *type = IJSVGUnitLengthTypePercentage;
        return YES;
    }
    return NO;
}

typedef struct {
    CGFloat value;
    IJSVGUnitLengthType originalType;
} IJSVGParsedUnitLength;

static BOOL IJSVGParseUnitBytes(const char* bytes, IJSVGParsedUnitLength* parsed)
{
    if(bytes == NULL) {
        return NO;
    }
    if(IJSVGParseScalarUnit(bytes, &parsed->value, &parsed->originalType)) {
        return YES;
    }
    char* chars = IJSVGTimmedCharBufferCreate(bytes);
    if(chars == NULL) {
        return NO;
    }
    size_t count = strlen(chars);
    if(count == 0 || IJSVGCharBufferCaseInsensitiveCompare(chars, "inherit")) {
        free(chars);
        return NO;
    }
    NSInteger numberCount = 0;
    CGFloat* numbers = [IJSVGUtils scanFloatsFromCString:chars
                                              floatCount:1
                                               charCount:count
                                                    size:&numberCount];
    BOOL valid = numbers != NULL && numberCount > 0;
    if(valid) {
        parsed->value = numbers[0];
        parsed->originalType = IJSVGUnitLengthTypeForCString(chars);
    }
    free(numbers);
    free(chars);
    return valid;
}

@implementation IJSVGUnitLength

+ (IJSVGUnitLength*)zeroUnitLength
{
    return [self unitWithFloat:0.f
                          type:IJSVGUnitLengthTypeNumber];
}

+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number
{
    IJSVGUnitLength* unit = [[self alloc] init];
    unit->_value = number;
    unit->_type = IJSVGUnitLengthTypeNumber;
    return unit;
}

+ (IJSVGUnitLength*)unitWithString:(NSString*)string
                      fromUnitType:(IJSVGUnitType)units
{
    IJSVGUnitLength* length = [self unitWithString:string];
    if(units == IJSVGUnitObjectBoundingBox &&
       length.type != IJSVGUnitLengthTypeEM && length.type != IJSVGUnitLengthTypeEX) {
        length.type = IJSVGUnitLengthTypePercentage;
    }
    return length;
}

+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number
                             type:(IJSVGUnitLengthType)type
{
    IJSVGUnitLength* unit = [[self alloc] init];
    unit->_value = number;
    unit->_type = type;
    unit->_originalType = type;
    return unit;
}

+ (IJSVGUnitLength*)unitWithPercentageFloat:(CGFloat)number
{
    return [self unitWithFloat:number
                          type:IJSVGUnitLengthTypePercentage];
}

+ (IJSVGUnitLength*)unitWithPercentageString:(NSString*)string
{
    IJSVGUnitLength* unit = [self unitWithString:string];
    unit.type = IJSVGUnitLengthTypePercentage;
    return unit;
}

IJSVGUnitLengthType IJSVGUnitLengthTypeForCString(const char* chars)
{
    if(chars == NULL) {
        return IJSVGUnitLengthTypeNumber;
    }
    size_t length = strlen(chars);
    if(length != 0 && chars[length - 1] == '%') {
        return IJSVGUnitLengthTypePercentage;
    }
    if(length < 2) {
        return IJSVGUnitLengthTypeNumber;
    }
    const char* suffix = chars + length - 2;
    switch(IJSVGCharToLower(suffix[0])) {
        case 'c':
            if(IJSVGCharBufferCaseInsensitiveCompare(suffix, "cm")) {
                return IJSVGUnitLengthTypeCM;
            }
            break;
        case 'm':
            if(IJSVGCharBufferCaseInsensitiveCompare(suffix, "mm")) {
                return IJSVGUnitLengthTypeMM;
            }
            break;
        case 'i':
            if(IJSVGCharBufferCaseInsensitiveCompare(suffix, "in")) {
                return IJSVGUnitLengthTypeIN;
            }
            break;
        case 'p':
            if(IJSVGCharBufferCaseInsensitiveCompare(suffix, "pt")) {
                return IJSVGUnitLengthTypePT;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(suffix, "pc")) {
                return IJSVGUnitLengthTypePC;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(suffix, "px")) {
                return IJSVGUnitLengthTypePX;
            }
            break;
        case 'e':
            if(IJSVGCharBufferCaseInsensitiveCompare(suffix, "em")) {
                return IJSVGUnitLengthTypeEM;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(suffix, "ex")) {
                return IJSVGUnitLengthTypeEX;
            }
            break;
    }
    return IJSVGUnitLengthTypeNumber;
}

+ (IJSVGUnitLengthType)typeForString:(NSString*)string
{
    return IJSVGUnitLengthTypeForCString(string.UTF8String);
}

+ (CGFloat)convertUnitValue:(CGFloat)unit
   toBaseFromUnitLengthType:(IJSVGUnitLengthType)type
{
    switch(type) {
        case IJSVGUnitLengthTypeCM: {
            return unit * (96.f / 2.54f);
        }
        case IJSVGUnitLengthTypeMM: {
            return [self convertUnitValue:unit
                 toBaseFromUnitLengthType:IJSVGUnitLengthTypeCM] / 10.f;
        }
        case IJSVGUnitLengthTypePercentage: {
            return unit / 100.f;
        }
        case IJSVGUnitLengthTypeIN: {
            // 1in = 96px
            return unit * 96.f;
        }
        case IJSVGUnitLengthTypePT: {
            // 1pt = 1.333...px
            return unit * 1.3333333f;
        }
        case IJSVGUnitLengthTypePC: {
            // 1pc = 16px
            return unit * 16.f;
        }
        default:
            break;
    }
    return unit;
}

+ (IJSVGUnitLength*)unitWithString:(NSString*)string
{
    IJSVGParsedUnitLength parsed = { 0 };
    if(!IJSVGParseUnitBytes(string.UTF8String, &parsed)) {
        return nil;
    }
    IJSVGUnitLengthType type = parsed.originalType;
    BOOL fontRelative = type == IJSVGUnitLengthTypeEM || type == IJSVGUnitLengthTypeEX;
    CGFloat value = fontRelative ? parsed.value :
                                   [self convertUnitValue:parsed.value
                                 toBaseFromUnitLengthType:type];
    IJSVGUnitLengthType resolvedType = fontRelative ||
        type == IJSVGUnitLengthTypePercentage ? type : IJSVGUnitLengthTypeNumber;
    IJSVGUnitLength* unit = [[self alloc] init];
    unit->_value = value;
    unit->_type = resolvedType;
    unit->_originalType = type;
    return unit;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGUnitLength* length = [[IJSVGUnitLength alloc] init];
    length->_value = self.value;
    length->_type = self.type;
    length->_originalType = self.originalType;
    length->_inherit = self.inherit;
    return length;
}

- (IJSVGUnitLength*)lengthWithUnitType:(IJSVGUnitLengthType)type
{
    return [self.class unitWithFloat:self.value
                                type:type];
}

- (IJSVGUnitLength*)lengthByMatchingPercentage
{
    if(!self.isRelativeUnit && self.value <= 1.f) {
        return [self.class unitWithFloat:self.value
                                    type:IJSVGUnitLengthTypePercentage];
    }
    return [self.class unitWithFloat:self.value
                                type:self.type];
}

- (BOOL)isRelativeUnit
{
    return self.type == IJSVGUnitLengthTypePercentage ||
        self.type == IJSVGUnitLengthTypeEM || self.type == IJSVGUnitLengthTypeEX;
}

- (CGFloat)computeValue:(CGFloat)anotherValue
{
    if(self.type == IJSVGUnitLengthTypePercentage) {
        return ((anotherValue / 100.f) * (_value * 100.f));
    }
    return self.value;
}

- (CGFloat)computeValue:(CGFloat)anotherValue
               fontSize:(CGFloat)fontSize
                xHeight:(CGFloat)xHeight
{
    switch(self.type) {
        case IJSVGUnitLengthTypeEM:
            return self.value * fontSize;
        case IJSVGUnitLengthTypeEX:
            return self.value * xHeight;
        default:
            return [self computeValue:anotherValue];
    }
}

- (CGFloat)valueAsPercentage
{
    return self.value / 100;
}

- (NSString*)stringValue
{
    if(self.type == IJSVGUnitLengthTypeAuto) {
        return @"auto";
    }
    if(self.type == IJSVGUnitLengthTypeEM || self.type == IJSVGUnitLengthTypeEX) {
        NSString* suffix = self.type == IJSVGUnitLengthTypeEM ? @"em" : @"ex";
        return [NSString stringWithFormat:@"%@%@", IJSVGShortFloatString(self.value), suffix];
    }
    if(self.type == IJSVGUnitLengthTypePercentage && self.value != 0.f) {
        return [NSString stringWithFormat:@"%@%%",
                         IJSVGShortFloatString(self.value * 100.f)];
    }
    return IJSVGShortFloatString(self.value);
}

- (NSString*)stringValueWithFloatingPointOptions:(IJSVGFloatingPointOptions)options
{
    if(self.type == IJSVGUnitLengthTypeAuto) {
        return @"auto";
    }
    if(self.type == IJSVGUnitLengthTypeEM || self.type == IJSVGUnitLengthTypeEX) {
        NSString* suffix = self.type == IJSVGUnitLengthTypeEM ? @"em" : @"ex";
        NSString* number = IJSVGShortFloatStringWithOptions(self.value, options);
        return [NSString stringWithFormat:@"%@%@", number, suffix];
    }
    if(_type == IJSVGUnitLengthTypePercentage && self.value != 0.f) {
        return [NSString stringWithFormat:@"%@%%",
                         IJSVGShortFloatStringWithOptions(_value * 100.f, options)];
    }
    return IJSVGShortFloatStringWithOptions(_value, options);
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%f%@",
                     _value, (_value == IJSVGUnitLengthTypePercentage ? @"%" : @"")];
}

@end
