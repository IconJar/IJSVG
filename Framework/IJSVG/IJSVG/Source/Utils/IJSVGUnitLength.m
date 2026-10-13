//
//  IJSVGUnitLength.m
//  IJSVG
//
//  Created by Curtis Hard on 13/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGUnitLength.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGCSSMathExpression.h>
#import <IJSVGParserUtils.h>
#import <float.h>

static BOOL IJSVGParseScalarUnit(const char* bytes, CGFloat* value, IJSVGUnitLengthType* type)
{
    if (bytes == NULL) {
        return NO;
    }
    if (bytes[0] >= '0' && bytes[0] <= '9' && bytes[1] == '\0') {
        *value = bytes[0] - '0';
        *type = IJSVGUnitLengthTypeNumber;
        return YES;
    }
    const char* end = bytes;
    if (!IJSVGParseLengthNumber(&end, YES, value)) {
        return NO;
    }
    if (*end == '\0') {
        *type = IJSVGUnitLengthTypeNumber;
        return YES;
    }
    if (end[0] == '%' && end[1] == '\0') {
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
    if (bytes == NULL) {
        return NO;
    }
    if (IJSVGParseScalarUnit(bytes, &parsed->value, &parsed->originalType)) {
        return YES;
    }
    char* chars = IJSVGTimmedCharBufferCreate(bytes);
    if (chars == NULL) {
        return NO;
    }
    size_t count = strlen(chars);
    if (count == 0 || IJSVGCharBufferCaseInsensitiveCompare(chars, "inherit")) {
        free(chars);
        return NO;
    }
    NSInteger numberCount = 0;
    CGFloat* numbers = [IJSVGUtils scanFloatsFromCString:chars floatCount:1 charCount:count size:&numberCount];
    BOOL valid = numbers != NULL && numberCount > 0;
    if (valid) {
        parsed->value = numbers[0];
        parsed->originalType = IJSVGUnitLengthTypeForCString(chars);
    }
    free(numbers);
    free(chars);
    return valid;
}

IJSVGUnitLength* IJSVGThreeUnitLength;
IJSVGUnitLength* IJSVGHalfPercentageUnitLength;
IJSVGUnitLength* IJSVGOnePercentageUnitLength;
IJSVGUnitLength* IJSVGNegativeTenPercentageUnitLength;
IJSVGUnitLength* IJSVGOneHundredTwentyPercentageUnitLength;
IJSVGUnitLength* IJSVGZeroBoundingBoxUnitLength;
IJSVGUnitLength* IJSVGAutoUnitLength;
IJSVGUnitLength* IJSVGInheritedAutoUnitLength;
IJSVGUnitLength* IJSVGDefaultViewportWidthUnitLength;
IJSVGUnitLength* IJSVGDefaultViewportHeightUnitLength;
IJSVGUnitLength* IJSVGZeroUnitLength;
IJSVGUnitLength* IJSVGOneUnitLength;
IJSVGUnitLength* IJSVGFourUnitLength;
IJSVGUnitLength* IJSVGInheritedZeroUnitLength;
IJSVGUnitLength* IJSVGInheritedOneUnitLength;
IJSVGUnitLength* IJSVGZeroPercentageUnitLength;

@interface IJSVGUnitLength ()

@property (nonatomic, strong) IJSVGCSSMathExpression* calculation;
@property (nonatomic) BOOL calculationNonnegative;
@property (nonatomic) BOOL calculationObjectUnits;

@end

@implementation IJSVGUnitLength

+ (void)load
{
    // Direct global reads do not trigger +initialize, so create defaults at
    // framework load.
    IJSVGThreeUnitLength = [IJSVGUnitLength unitWithFloat:3.f type:IJSVGUnitLengthTypeNumber originalType:IJSVGUnitLengthTypeNumber inherit:NO];
    IJSVGHalfPercentageUnitLength = [IJSVGUnitLength unitWithFloat:.5f type:IJSVGUnitLengthTypePercentage originalType:IJSVGUnitLengthTypePercentage inherit:NO];
    IJSVGOnePercentageUnitLength = [IJSVGUnitLength unitWithFloat:1.f type:IJSVGUnitLengthTypePercentage originalType:IJSVGUnitLengthTypePercentage inherit:NO];
    IJSVGNegativeTenPercentageUnitLength = [IJSVGUnitLength unitWithFloat:-.1f type:IJSVGUnitLengthTypePercentage originalType:IJSVGUnitLengthTypePercentage inherit:NO];
    IJSVGOneHundredTwentyPercentageUnitLength = [IJSVGUnitLength unitWithFloat:1.2f type:IJSVGUnitLengthTypePercentage originalType:IJSVGUnitLengthTypePercentage inherit:NO];
    IJSVGZeroBoundingBoxUnitLength = [IJSVGUnitLength unitWithFloat:0.f type:IJSVGUnitLengthTypePercentage originalType:IJSVGUnitLengthTypeNumber inherit:NO];
    IJSVGAutoUnitLength = [IJSVGUnitLength unitWithFloat:0.f type:IJSVGUnitLengthTypeAuto originalType:IJSVGUnitLengthTypeAuto inherit:NO];
    IJSVGInheritedAutoUnitLength = [IJSVGUnitLength unitWithFloat:0.f type:IJSVGUnitLengthTypeAuto originalType:IJSVGUnitLengthTypeAuto inherit:YES];
    IJSVGDefaultViewportWidthUnitLength = [IJSVGUnitLength unitWithFloat:IJSVG_SIZE_DEFAULT_CLIENT.width type:IJSVGUnitLengthTypeNumber originalType:IJSVGUnitLengthTypeNumber inherit:NO];
    IJSVGDefaultViewportHeightUnitLength = [IJSVGUnitLength unitWithFloat:IJSVG_SIZE_DEFAULT_CLIENT.height type:IJSVGUnitLengthTypeNumber originalType:IJSVGUnitLengthTypeNumber inherit:NO];
    IJSVGZeroUnitLength = [IJSVGUnitLength unitWithFloat:0.f type:IJSVGUnitLengthTypeNumber originalType:IJSVGUnitLengthTypeNumber inherit:NO];
    IJSVGOneUnitLength = [IJSVGUnitLength unitWithFloat:1.f type:IJSVGUnitLengthTypeNumber originalType:IJSVGUnitLengthTypeNumber inherit:NO];
    IJSVGFourUnitLength = [IJSVGUnitLength unitWithFloat:4.f type:IJSVGUnitLengthTypeNumber originalType:IJSVGUnitLengthTypeNumber inherit:NO];
    IJSVGInheritedZeroUnitLength = [IJSVGUnitLength unitWithFloat:0.f type:IJSVGUnitLengthTypeNumber originalType:IJSVGUnitLengthTypeNumber inherit:YES];
    IJSVGInheritedOneUnitLength = [IJSVGUnitLength unitWithFloat:1.f type:IJSVGUnitLengthTypeNumber originalType:IJSVGUnitLengthTypeNumber inherit:YES];
    IJSVGZeroPercentageUnitLength = [IJSVGUnitLength unitWithFloat:0.f type:IJSVGUnitLengthTypePercentage originalType:IJSVGUnitLengthTypePercentage inherit:NO];
}

+ (BOOL)accessInstanceVariablesDirectly
{
    // Shared immutable values must not be modified through KVC either.
    return NO;
}

+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number type:(IJSVGUnitLengthType)type originalType:(IJSVGUnitLengthType)originalType inherit:(BOOL)inherit
{
    IJSVGUnitLength* unit = [[self alloc] init];
    unit->_value = number;
    unit->_type = type;
    unit->_originalType = originalType;
    unit->_inherit = inherit;
    return unit;
}

- (IJSVGUnitLength*)lengthWithValue:(CGFloat)value
{
    if (!self.isCalculated && value == self.value && signbit(value) == signbit(self.value) && !self.inherit) {
        return self;
    }
    return [self.class unitWithFloat:value type:self.isCalculated ? IJSVGUnitLengthTypeNumber : self.type originalType:self.isCalculated ? IJSVGUnitLengthTypeNumber : self.originalType inherit:NO];
}

- (IJSVGUnitLength*)lengthWithInheritance:(BOOL)inherit
{
    if (inherit == self.inherit) {
        return self;
    }
    IJSVGUnitLength* result = [self.class unitWithFloat:self.value type:self.type originalType:self.originalType inherit:inherit];
    result.calculation = _calculation;
    result.calculationNonnegative = _calculationNonnegative;
    result.calculationObjectUnits = _calculationObjectUnits;
    return result;
}

- (IJSVGUnitLength*)lengthBySettingType:(IJSVGUnitLengthType)type
{
    if (type == self.type) {
        return self;
    }
    IJSVGUnitLength* result = [self.class unitWithFloat:self.value type:type originalType:self.originalType inherit:self.inherit];
    result.calculation = _calculation;
    result.calculationNonnegative = _calculationNonnegative;
    result.calculationObjectUnits = _calculationObjectUnits || type == IJSVGUnitLengthTypePercentage;
    return result;
}

+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number
{
    return [self unitWithFloat:number type:IJSVGUnitLengthTypeNumber originalType:IJSVGUnitLengthTypeNumber inherit:NO];
}

+ (IJSVGUnitLength*)unitWithString:(NSString*)string fromUnitType:(IJSVGUnitType)units
{
    IJSVGUnitLength* length = [self unitWithString:string];
    if (units == IJSVGUnitObjectBoundingBox && length.type != IJSVGUnitLengthTypeEM && length.type != IJSVGUnitLengthTypeEX) {
        length = [length lengthBySettingType:IJSVGUnitLengthTypePercentage];
    }
    return length;
}

+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number type:(IJSVGUnitLengthType)type
{
    return [self unitWithFloat:number type:type originalType:type inherit:NO];
}

+ (IJSVGUnitLength*)unitWithPercentageFloat:(CGFloat)number
{
    return [self unitWithFloat:number type:IJSVGUnitLengthTypePercentage];
}

+ (IJSVGUnitLength*)unitWithPercentageString:(NSString*)string
{
    IJSVGUnitLength* unit = [self unitWithString:string];
    unit = [unit lengthBySettingType:IJSVGUnitLengthTypePercentage];
    return unit;
}

IJSVGUnitLengthType IJSVGUnitLengthTypeForCString(const char* chars)
{
    if (chars == NULL) {
        return IJSVGUnitLengthTypeNumber;
    }
    size_t length = strlen(chars);
    if (length != 0 && chars[length - 1] == '%') {
        return IJSVGUnitLengthTypePercentage;
    }
    if (length < 2) {
        return IJSVGUnitLengthTypeNumber;
    }
    const char* suffix = chars + length - 2;
    switch (IJSVGCharToLower(suffix[0])) {
        case 'c':
            if (IJSVGCharBufferCaseInsensitiveCompare(suffix, "cm")) {
                return IJSVGUnitLengthTypeCM;
            }
            break;
        case 'm':
            if (IJSVGCharBufferCaseInsensitiveCompare(suffix, "mm")) {
                return IJSVGUnitLengthTypeMM;
            }
            break;
        case 'i':
            if (IJSVGCharBufferCaseInsensitiveCompare(suffix, "in")) {
                return IJSVGUnitLengthTypeIN;
            }
            break;
        case 'p':
            if (IJSVGCharBufferCaseInsensitiveCompare(suffix, "pt")) {
                return IJSVGUnitLengthTypePT;
            }
            if (IJSVGCharBufferCaseInsensitiveCompare(suffix, "pc")) {
                return IJSVGUnitLengthTypePC;
            }
            if (IJSVGCharBufferCaseInsensitiveCompare(suffix, "px")) {
                return IJSVGUnitLengthTypePX;
            }
            break;
        case 'e':
            if (IJSVGCharBufferCaseInsensitiveCompare(suffix, "em")) {
                return IJSVGUnitLengthTypeEM;
            }
            if (IJSVGCharBufferCaseInsensitiveCompare(suffix, "ex")) {
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

CGFloat IJSVGConvertUnitValue(CGFloat unit, IJSVGUnitLengthType type)
{
    switch (type) {
        case IJSVGUnitLengthTypeCM: {
            return unit * (96.f / 2.54f);
        }
        case IJSVGUnitLengthTypeMM: {
            return IJSVGConvertUnitValue(unit, IJSVGUnitLengthTypeCM) / 10.f;
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

+ (CGFloat)convertUnitValue:(CGFloat)unit toBaseFromUnitLengthType:(IJSVGUnitLengthType)type
{
    return IJSVGConvertUnitValue(unit, type);
}

+ (IJSVGUnitLength*)unitWithString:(NSString*)string
{
    // Never let the legacy float scanner extract a number from an unsupported
    // function.
    IJSVGStringBytes source = IJSVGStringGetBytes(string);
    const char* bytes = source.bytes;
    if (bytes == NULL || strlen(bytes) != source.length || strchr(bytes, '(') != NULL) {
        return nil;
    }
    IJSVGParsedUnitLength parsed = { 0 };
    if (!IJSVGParseUnitBytes(bytes, &parsed)) {
        return nil;
    }
    IJSVGUnitLengthType type = parsed.originalType;
    BOOL fontRelative = type == IJSVGUnitLengthTypeEM || type == IJSVGUnitLengthTypeEX;
    CGFloat value = fontRelative ? parsed.value : [self convertUnitValue:parsed.value toBaseFromUnitLengthType:type];
    IJSVGUnitLengthType resolvedType = fontRelative || type == IJSVGUnitLengthTypePercentage ? type : IJSVGUnitLengthTypeNumber;
    return [self unitWithFloat:value type:resolvedType originalType:type inherit:NO];
}

- (id)copyWithZone:(NSZone*)zone
{
    return self;
}

- (IJSVGUnitLength*)lengthWithUnitType:(IJSVGUnitLengthType)type
{
    return self.isCalculated ? [self lengthBySettingType:type] : [self.class unitWithFloat:self.value type:type];
}

- (IJSVGUnitLength*)lengthByMatchingPercentage
{
    if (self.isCalculated) {
        return [self lengthBySettingType:IJSVGUnitLengthTypePercentage];
    }
    if (!self.isRelativeUnit && self.value <= 1.f) {
        return [self.class unitWithFloat:self.value type:IJSVGUnitLengthTypePercentage];
    }
    return [self.class unitWithFloat:self.value type:self.type];
}

- (BOOL)isRelativeUnit
{
    return self.usesPercentage || self.usesFontMetrics;
}

- (CGFloat)computeValue:(CGFloat)anotherValue
{
    if (_calculation != nil) {
        return [self computeValue:anotherValue fontSize:0 xHeight:0];
    }
    if (self.type == IJSVGUnitLengthTypePercentage) {
        return ((anotherValue / 100.f) * (_value * 100.f));
    }
    return self.value;
}

- (CGFloat)computeValue:(CGFloat)anotherValue fontSize:(CGFloat)fontSize xHeight:(CGFloat)xHeight
{
    if (_calculation != nil) {
        CGFloat basis = _calculationObjectUnits ? 1.f : anotherValue;
        CGFloat result = [_calculation evaluate:(IJSVGCSSCalculationContext) { basis, fontSize, xHeight }];
        if (_calculationObjectUnits) {
            result *= anotherValue;
        }
        // CSS censors NaN/signed zero at the top level and clamps to the supported
        // range.
        if (isnan(result) || result == 0.f) {
            return 0.f;
        }
        result = fmax(-FLT_MAX, fmin(FLT_MAX, result));
        return _calculationNonnegative ? fmax(0.f, result) : result;
    }
    switch (self.type) {
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
    if (_calculation != nil) {
        NSString* expression = _calculation.stringValue;
        return [expression containsString:@"("] ? expression : [NSString stringWithFormat:@"calc(%@)", expression];
    }
    if (self.type == IJSVGUnitLengthTypeAuto) {
        return @"auto";
    }
    if (self.type == IJSVGUnitLengthTypeEM || self.type == IJSVGUnitLengthTypeEX) {
        NSString* suffix = self.type == IJSVGUnitLengthTypeEM ? @"em" : @"ex";
        return [NSString stringWithFormat:@"%@%@", IJSVGShortFloatString(self.value), suffix];
    }
    if (self.type == IJSVGUnitLengthTypePercentage && self.value != 0.f) {
        return [NSString stringWithFormat:@"%@%%", IJSVGShortFloatString(self.value * 100.f)];
    }
    return IJSVGShortFloatString(self.value);
}

- (NSString*)stringValueWithFloatingPointOptions:(IJSVGFloatingPointOptions)options
{
    if (_calculation != nil) {
        return self.stringValue;
    }
    if (self.type == IJSVGUnitLengthTypeAuto) {
        return @"auto";
    }
    if (self.type == IJSVGUnitLengthTypeEM || self.type == IJSVGUnitLengthTypeEX) {
        NSString* suffix = self.type == IJSVGUnitLengthTypeEM ? @"em" : @"ex";
        NSString* number = IJSVGShortFloatStringWithOptions(self.value, options);
        return [NSString stringWithFormat:@"%@%@", number, suffix];
    }
    if (_type == IJSVGUnitLengthTypePercentage && self.value != 0.f) {
        return [NSString stringWithFormat:@"%@%%", IJSVGShortFloatStringWithOptions(_value * 100.f, options)];
    }
    return IJSVGShortFloatStringWithOptions(_value, options);
}

+ (IJSVGUnitLength*)unitWithCalculationString:(NSString*)string allowNegative:(BOOL)allowNegative
{
    IJSVGStringBytes source = IJSVGStringGetBytes(string);
    IJSVGCSSComponents components;
    IJSVGUnitLength* result = nil;
    if (IJSVGCSSComponentsCreate(source.bytes, source.length, &components) && components.count != 0 && components.values[0].next == components.count) {
        result = [self unitWithCalculationComponents:&components atIndex:0 allowNegative:allowNegative];
    }
    IJSVGCSSComponentsRelease(&components);
    return result;
}

+ (IJSVGUnitLength*)unitWithCalculationComponents:(const IJSVGCSSComponents*)components atIndex:(NSUInteger)index allowNegative:(BOOL)allowNegative
{
    IJSVGCSSMathExpression* expression = [IJSVGCSSMathExpression expressionWithComponents:components atIndex:index];
    if (expression == nil) {
        return nil;
    }
    BOOL percentageOnly = expression.usesPercentage && !expression.usesLength && expression.lengthExponent == 1;
    IJSVGUnitLength* result = [self unitWithFloat:0 type:percentageOnly ? IJSVGUnitLengthTypePercentage : IJSVGUnitLengthTypeCalculation];
    result.calculation = expression;
    result.calculationNonnegative = !allowNegative;
    if (!expression.usesPercentage && !expression.usesFontMetrics) {
        result->_value = [result computeValue:0];
    }
    return result;
}

- (IJSVGUnitLength*)lengthByScalingAbsoluteUnits:(CGFloat)scale
{
    if (_calculation == nil) {
        return self.type == IJSVGUnitLengthTypePercentage ? self : [self lengthWithValue:self.value * scale];
    }
    IJSVGUnitLength* result = [self.class unitWithFloat:0 type:self.type originalType:self.originalType inherit:self.inherit];
    result.calculation = [_calculation expressionByScalingLengths:scale];
    result.calculationNonnegative = _calculationNonnegative;
    result.calculationObjectUnits = _calculationObjectUnits;
    if (!result.isRelativeUnit) {
        result->_value = [result computeValue:0];
    }
    return result;
}

- (BOOL)isCalculated
{
    return _calculation != nil;
}

- (BOOL)usesFontMetrics
{
    return _calculation.usesFontMetrics || self.type == IJSVGUnitLengthTypeEM || self.type == IJSVGUnitLengthTypeEX;
}

- (BOOL)usesPercentage
{
    return _calculation.usesPercentage || self.type == IJSVGUnitLengthTypePercentage;
}

- (IJSVGUnitLength*)lengthByResolvingFontSize:(CGFloat)fontSize xHeight:(CGFloat)xHeight
{
    if (!self.usesFontMetrics) {
        return self;
    }
    if (_calculation == nil) {
        return [self.class unitWithFloat:[self computeValue:0 fontSize:fontSize xHeight:xHeight]];
    }
    IJSVGUnitLength* result = [self.class unitWithFloat:0 type:self.type originalType:self.originalType inherit:self.inherit];
    result.calculation = [_calculation expressionByResolvingFontSize:fontSize xHeight:xHeight];
    result.calculationNonnegative = _calculationNonnegative;
    result.calculationObjectUnits = _calculationObjectUnits;
    if (!result.usesPercentage) {
        result->_value = [result computeValue:0];
    }
    return result;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%f%@", _value, (_value == IJSVGUnitLengthTypePercentage ? @"%" : @"")];
}

@end
