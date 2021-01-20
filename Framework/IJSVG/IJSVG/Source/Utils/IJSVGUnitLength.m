//
//  IJSVGUnitLength.m
//  IJSVGExample
//
//  Created by Curtis Hard on 13/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGNode.h"
#import "IJSVGUnitLength.h"
#import "IJSVGUtils.h"

@implementation IJSVGUnitLength

@synthesize value;
@synthesize type;
@synthesize inherit;
@synthesize originalType;

+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number
{
    IJSVGUnitLength* unit = [[[self alloc] init] autorelease];
    unit.value = number;
    unit.type = IJSVGUnitLengthTypeNumber;
    return unit;
}

+ (IJSVGUnitLength*)unitWithString:(NSString*)string
                      fromUnitType:(IJSVGUnitType)units
{
    if (units == IJSVGUnitObjectBoundingBox) {
        return [self unitWithPercentageString:string];
    }
    return [self unitWithString:string];
}

+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number
                             type:(IJSVGUnitLengthType)type
{
    IJSVGUnitLength* unit = [[[self alloc] init] autorelease];
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
    NSCharacterSet* cSet = NSCharacterSet.whitespaceCharacterSet;
    string = [string stringByTrimmingCharactersInSet:cSet];

    if ([string isEqualToString:@"inherit"]) {
        return nil;
    }

    IJSVGUnitLength* unit = [[[self alloc] init] autorelease];
    unit.value = string.floatValue;
    unit.type = IJSVGUnitLengthTypeNumber;
    
    IJSVGUnitLengthType type = [self typeForString:string];
    unit.originalType = type;
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

- (CGFloat)computeValue:(CGFloat)anotherValue
{
    if (self.type == IJSVGUnitLengthTypePercentage) {
        return ((anotherValue / 100.f) * (self.value * 100.f));
    }
    return self.value;
}

- (CGFloat)valueAsPercentage
{
    return self.value / 100;
}

- (NSString*)stringValue
{
    if (self.type == IJSVGUnitLengthTypePercentage) {
        return [NSString stringWithFormat:@"%@%%",
                         IJSVGShortFloatString(self.value * 100.f)];
    }
    return IJSVGShortFloatString(self.value);
}

- (NSString*)stringValueWithFloatingPointOptions:(IJSVGFloatingPointOptions)options
{
    if (self.type == IJSVGUnitLengthTypePercentage) {
        return [NSString stringWithFormat:@"%@%%",
                         IJSVGShortFloatStringWithOptions(self.value * 100.f, options)];
    }
    return IJSVGShortFloatStringWithOptions(self.value, options);
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%f%@",
                     self.value, (self.type == IJSVGUnitLengthTypePercentage ? @"%" : @"")];
}

@end
