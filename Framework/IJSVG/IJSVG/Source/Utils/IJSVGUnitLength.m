//
//  IJSVGUnitLength.m
//  IJSVGExample
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

+ (IJSVGUnitLengthType)typeForCString:(const char*)chars
{
    if(IJSVGCharBufferHasSuffix((char*)chars, "%")) {
        return IJSVGUnitLengthTypePercentage;
    }
    if(IJSVGCharBufferHasSuffix((char*)chars, "cm")) {
        return IJSVGUnitLengthTypeCM;
    }
    if(IJSVGCharBufferHasSuffix((char*)chars, "mm")) {
        return IJSVGUnitLengthTypeMM;
    }
    if(IJSVGCharBufferHasSuffix((char*)chars, "in")) {
        return IJSVGUnitLengthTypeIN;
    }
    if(IJSVGCharBufferHasSuffix((char*)chars, "pt")) {
        return IJSVGUnitLengthTypePT;
    }
    if(IJSVGCharBufferHasSuffix((char*)chars, "pc")) {
        return IJSVGUnitLengthTypePC;
    }
    if(IJSVGCharBufferHasSuffix((char*)chars, "px")) {
        return IJSVGUnitLengthTypePX;
    }
    return IJSVGUnitLengthTypeNumber;
}

+ (IJSVGUnitLengthType)typeForString:(NSString*)string
{
    if([string hasSuffix:@"%"] == YES) {
        return IJSVGUnitLengthTypePercentage;
    }
    if([string hasSuffix:@"cm"] == YES) {
        return IJSVGUnitLengthTypeCM;
    }
    if([string hasSuffix:@"mm"] == YES) {
        return IJSVGUnitLengthTypeMM;
    }
    if([string hasSuffix:@"in"] == YES) {
        return IJSVGUnitLengthTypeIN;
    }
    if([string hasSuffix:@"pt"] == YES) {
        return IJSVGUnitLengthTypePT;
    }
    if([string hasSuffix:@"pc"] == YES) {
        return IJSVGUnitLengthTypePC;
    }
    if([string hasSuffix:@"px"] == YES) {
        return IJSVGUnitLengthTypePX;
    }
    return IJSVGUnitLengthTypeNumber;
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
    if(strcmp(chars, "inherit") == 0 || strl == 0) {
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
        return nil;
    }
    
    IJSVGUnitLength* unit = [[self alloc] init];
    unit.value = floats[0];
    unit.type = IJSVGUnitLengthTypeNumber;
    
    
    IJSVGUnitLengthType type = [self typeForCString:chars];
    unit.originalType = type;
    
    // memory free
    (void)(free(floats)), floats = NULL;
    (void)free(chars), chars = NULL;
    
    switch(type) {
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
    if(self.type != IJSVGUnitLengthTypePercentage && self.value <= 1.f) {
        return [self.class unitWithFloat:self.value
                                    type:IJSVGUnitLengthTypePercentage];
    }
    return [self.class unitWithFloat:self.value
                                type:self.type];
}

- (CGFloat)computeValue:(CGFloat)anotherValue
{
    if(self.type == IJSVGUnitLengthTypePercentage) {
        return ((anotherValue / 100.f) * (_value * 100.f));
    }
    return self.value;
}

- (CGFloat)valueAsPercentage
{
    return self.value / 100;
}

- (NSString*)stringValue
{
    if(self.type == IJSVGUnitLengthTypePercentage) {
        return [NSString stringWithFormat:@"%@%%",
                         IJSVGShortFloatString(self.value * 100.f)];
    }
    return IJSVGShortFloatString(self.value);
}

- (NSString*)stringValueWithFloatingPointOptions:(IJSVGFloatingPointOptions)options
{
    if(_type == IJSVGUnitLengthTypePercentage) {
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
