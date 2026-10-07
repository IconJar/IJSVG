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

@implementation IJSVGUnitLength

+ (IJSVGUnitLength*)zeroUnitLength
{
    return [self unitWithFloat:0.f
                          type:IJSVGUnitLengthTypeNumber];
}

+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number
{
    IJSVGUnitLength* unit = [[self alloc] init];
    unit.value = number;
    unit.type = IJSVGUnitLengthTypeNumber;
    return unit;
}

+ (IJSVGUnitLength*)unitWithString:(NSString*)string
                      fromUnitType:(IJSVGUnitType)units
{
    if(units == IJSVGUnitObjectBoundingBox) {
        return [self unitWithPercentageString:string];
    }
    return [self unitWithString:string];
}

+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number
                             type:(IJSVGUnitLengthType)type
{
    IJSVGUnitLength* unit = [[self alloc] init];
    unit.value = number;
    unit.type = type;
    unit.originalType = type;
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
    // just return noting for inherit, node will deal
    // with the rest...hopefully
    if(string == nil) {
        return nil;
    }
    
    char* chars = IJSVGTimmedCharBufferCreate(string.UTF8String);

    // is inherit or just nothing
    size_t strl = strlen(chars);
    if(IJSVGCharBufferCaseInsensitiveCompare(chars, "inherit") == YES || strl == 0) {
        (void)free(chars), chars = NULL;
        return nil;
    }
    
    // grab the float value from the string
    NSInteger length;
    CGFloat* floats = [IJSVGUtils scanFloatsFromCString:chars
                                             floatCount:1
                                              charCount:(NSUInteger)strl
                                                   size:&length];
    // not sure how this ended up but nothing returned
    // even though there should had been
    if(length == 0) {
        (void)free(floats), floats = NULL;
        (void)free(chars), chars = NULL;
        return nil;
    }
    
    IJSVGUnitLength* unit = [[self alloc] init];
    unit.value = floats[0];
    unit.type = IJSVGUnitLengthTypeNumber;
    
    
    IJSVGUnitLengthType type = IJSVGUnitLengthTypeForCString(chars);
    unit.originalType = type;
    
    // memory free
    (void)(free(floats)), floats = NULL;
    (void)free(chars), chars = NULL;
    
    switch(type) {
        case IJSVGUnitLengthTypeEM:
        case IJSVGUnitLengthTypeEX:
            // Keep font relative values until the font metrics are known.
            unit.type = type;
            break;
        case IJSVGUnitLengthTypePercentage: {
            unit.value = [self convertUnitValue:unit.value
                       toBaseFromUnitLengthType:type];
            unit.type = IJSVGUnitLengthTypePercentage;
            break;
        }
        default:
            unit.value = [self convertUnitValue:unit.value
                       toBaseFromUnitLengthType:type];
            break;
    }
    return unit;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGUnitLength* length = [[IJSVGUnitLength alloc] init];
    length.value = self.value;
    length.type = self.type;
    length.originalType = self.originalType;
    length.inherit = self.inherit;
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
