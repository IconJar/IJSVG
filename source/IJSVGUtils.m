//
//  IJSVGUtils.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGUtils.h"

@implementation IJSVGUtils

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
    return [[self class] scanFloatsFromString:command
                                         size:count];
}

static NSCharacterSet * _invertedCharSet = nil;

+ (CGFloat *)scanFloatsFromString:(NSString *)string
                             size:(NSInteger *)length
{
    if(_invertedCharSet == nil) {
        NSCharacterSet * tSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789-e."];
        _invertedCharSet = [tSet.invertedSet retain];
    }
    NSArray * pieces = [string componentsSeparatedByCharactersInSet:_invertedCharSet];
    NSInteger defSize = 500;
    NSInteger size = defSize;
    NSInteger counter = 0;
    CGFloat * floats = (CGFloat *)malloc(sizeof(CGFloat)*size);
    for(NSString * piece in pieces) {
        if(piece.length == 0) {
            continue;
        }
        const char * chars = [piece cStringUsingEncoding:NSUTF8StringEncoding];
        float foundFloat;
        int offset;
        while(sscanf(chars, "%f%n", &foundFloat, &offset) > 0) {
            if(counter+1 == size) {
                floats = (CGFloat *)realloc(floats, sizeof(CGFloat)*size);
            }
            floats[counter++] = foundFloat;
            chars += offset;
        }
    }
    *length = counter;
    return floats;
}

+ (CGFloat *)parseViewBox:(NSString *)string
{
    NSInteger size = 0;
    return [[self class] scanFloatsFromString:string
                                         size:&size];
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
