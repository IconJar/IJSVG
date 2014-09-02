//
//  IJSVGUtils.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGUtils.h"

@implementation IJSVGUtils

#define FLOAT_EXP @"[-+]?[0-9]*\\.?[0-9]+"

+ (IJSVGCommandType)typeForCommandString:(NSString *)string
{
    return [string isEqualToString:[string uppercaseString]] ? IJSVGCommandTypeAbsolute : IJSVGCommandTypeRelative;
}

+ (NSRegularExpression *)commandNameRegex
{
    static NSRegularExpression *_commandRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _commandRegex = [[NSRegularExpression alloc] initWithPattern:@"[A-Za-z]"
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

+ (NSWindingRule)windingRuleForString:(NSString *)string
{
    if( [string isEqualToString:@"evenodd"] )
        return IJSVGWindingRuleEvenOdd;
    if( [string isEqualToString:@"inherit"] )
        return IJSVGWindingRuleInherit;
    return IJSVGWindingRuleNonZero;
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
    NSRegularExpression * exp = [[self class] commandRegex];
    NSArray * matches = [exp matchesInString:command
                                     options:0
                                       range:NSMakeRange( 0, command.length)];
    CGFloat * ret = (CGFloat *)malloc(matches.count*sizeof(CGFloat));
    for( NSInteger i = 0; i < matches.count; i++ )
    {
        NSTextCheckingResult * match = [matches objectAtIndex:i];
        NSString * paramString = [command substringWithRange:match.range];
        ret[i] = (CGFloat)[paramString floatValue];
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


@end
