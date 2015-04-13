//
//  IJSVGUtils.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGUtils.h"

@implementation IJSVGUtils

#define FLOAT_EXP @"[-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?"

CGFloat angle( CGPoint a, CGPoint b ) {
    return [IJSVGUtils angleBetweenPointA:a
                                   pointb:b];
}

CGFloat ratio( CGPoint a, CGPoint b ) {
    return (a.x * b.x + a.y * b.y) / (magnitude(a) * magnitude(b));
}

CGFloat magnitude(CGPoint point)
{
    return sqrtf(powf(point.x, 2) + powf(point.y, 2));
}

CGFloat radians_to_degrees(CGFloat radians)
{
    return ((radians) * (180.0 / M_PI));
}

CGFloat degrees_to_radians( CGFloat degrees )
{
    return ( ( degrees ) / 180.0 * M_PI );
}

+ (IJSVGCommandType)typeForCommandString:(NSString *)string
{
    return [string isEqualToString:[string uppercaseString]] ? IJSVGCommandTypeAbsolute : IJSVGCommandTypeRelative;
}

+ (NSRegularExpression *)commandNameRegex
{
    static NSRegularExpression *_commandRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _commandRegex = [[NSRegularExpression alloc] initWithPattern:@"[MmZzLlHhVvCcSsQqTtAa]{1}"
                                                             options:0
                                                               error:nil];
    });
    return _commandRegex;
}

+ (NSRegularExpression *)commandRegex
{
    static NSRegularExpression * _reg = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _reg = [[NSRegularExpression alloc] initWithPattern:FLOAT_EXP
                                                    options:0
                                                      error:nil];
    });
    return _reg;
}

+ (NSString *)cleanCommandString:(NSString *)string
{
    static NSRegularExpression * _reg = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _reg = [[NSRegularExpression alloc] initWithPattern:@"e\\-[0-9]+"
                                                    options:0
                                                      error:nil];
    });
    return [_reg stringByReplacingMatchesInString:string
                                          options:0
                                            range:NSMakeRange( 0, string.length )
                                     withTemplate:@""];
}

+ (NSString *)defURL:(NSString *)string
{
    static NSRegularExpression * _reg = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _reg = [[NSRegularExpression alloc] initWithPattern:@"url\\s?\\(\\s?#(.*?)\\)\\;?"
                                                    options:0
                                                      error:nil];
    });
    __block NSString * foundID = nil;
    [_reg enumerateMatchesInString:string
                           options:0
                             range:NSMakeRange( 0, string.length )
                        usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
     {
         if( ( foundID = [string substringWithRange:[result rangeAtIndex:1]] ) != nil )
             *stop = YES;
     }];
    return foundID;
}

+ (IJSVGWindingRule)windingRuleForString:(NSString *)string
{
    if( [string isEqualToString:@"evenodd"] )
        return IJSVGWindingRuleEvenOdd;
    if( [string isEqualToString:@"inherit"] )
        return IJSVGWindingRuleInherit;
    return IJSVGWindingRuleNonZero;
}

+ (IJSVGLineJoinStyle)lineJoinStyleForString:(NSString *)string
{
    if( [string isEqualToString:@"mitre"] )
        return IJSVGLineJoinStyleMiter;
    if( [string isEqualToString:@"round"] )
        return IJSVGLineJoinStyleRound;
    if( [string isEqualToString:@"bevel"] )
        return IJSVGLineJoinStyleBevel;
    if( [string isEqualToString:@"inherit"] )
        return IJSVGLineJoinStyleInherit;
    return IJSVGLineJoinStyleMiter;
}

+ (IJSVGLineCapStyle)lineCapStyleForString:(NSString *)string
{
    if( [string isEqualToString:@"butt"] )
        return IJSVGLineCapStyleButt;
    if( [string isEqualToString:@"square"] )
        return IJSVGLineCapStyleSquare;
    if( [string isEqualToString:@"round"] )
        return IJSVGLineCapStyleRound;
    if( [string isEqualToString:@"inherit"] )
        return IJSVGLineCapStyleInherit;
    return IJSVGLineCapStyleButt;
}

+ (NSRegularExpression *)viewBoxRegex
{
    static NSRegularExpression * _reg = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _reg = [[NSRegularExpression alloc] initWithPattern:FLOAT_EXP
                                                    options:0
                                                      error:nil];
    });
    return _reg;
}

+ (CGFloat *)commandParameters:(NSString *)command
                         count:(NSInteger *)count
{
    if( [command isKindOfClass:[NSNumber class]] )
    {
        CGFloat * ret = (CGFloat *)malloc(1*sizeof(CGFloat));
        ret[0] = [(NSNumber *)command floatValue];
        *count = 1;
        return ret;
    }
    NSRegularExpression * exp = [[self class] commandRegex];
    NSArray * matches = [exp matchesInString:command
                                     options:0
                                       range:NSMakeRange( 0, command.length)];
    CGFloat * ret = (CGFloat *)malloc(matches.count*sizeof(CGFloat));
    NSDictionary * dict = [NSDictionary dictionaryWithObject:@"."
                                                      forKey:NSLocaleDecimalSeparator];
    for( NSInteger i = 0; i < matches.count; i++ )
    {
        NSTextCheckingResult * match = [matches objectAtIndex:i];
        NSString * paramString = [command substringWithRange:match.range];
        NSDecimalNumber * decimal = nil;
        if( [paramString rangeOfString:@"."].location != NSNotFound )
            decimal = [NSDecimalNumber decimalNumberWithString:paramString
                                                        locale:dict];
        else
            decimal = [NSDecimalNumber decimalNumberWithString:paramString];
        ret[i] = (CGFloat)[decimal floatValue];
        *count += 1;
    }
    return ret;
}

+ (CGFloat *)parseViewBox:(NSString *)string
{
    NSRegularExpression * exp = [[self class] viewBoxRegex];
    NSArray * matches = [exp matchesInString:string
                                     options:0
                                       range:NSMakeRange( 0, string.length)];
    CGFloat * ret = (CGFloat *)malloc(matches.count*sizeof(CGFloat));
    for( NSInteger i = 0; i < matches.count; i++ )
    {
        NSTextCheckingResult * match = [matches objectAtIndex:i];
        NSString * paramString = [string substringWithRange:match.range];
        ret[i] = (CGFloat)[paramString floatValue];
    }
    return ret;
}

+ (CGFloat)floatValue:(NSString *)string
   fallBackForPercent:(CGFloat)fallBack
{
    CGFloat val = [string floatValue];
    if( [string rangeOfString:@"%"].location != NSNotFound )
        val = (fallBack * val)/100;
    return val;
}

+ (void)logParameters:(CGFloat *)param
                count:(NSInteger)count
{
    NSMutableString * str = [[[NSMutableString alloc] init] autorelease];
    for( NSInteger i = 0; i < count; i++ )
    {
        [str appendFormat:@"%f ",param[i]];
    }
    NSLog(@"%@",str);
}

+ (CGFloat)floatValue:(NSString *)string
{
    if( [string isEqualToString:@"inherit"] )
        return IJSVGInheritedFloatValue;
    return [string floatValue];
}

+ (CGFloat)angleBetweenPointA:(NSPoint)point1
                       pointb:(NSPoint)point2
{
    return (point1.x * point2.y < point1.y * point2.x ? -1 : 1) * acosf(ratio(point1, point2));
}

@end
