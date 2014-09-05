//
//  IJSVGStyle.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGStyle.h"
#import "IJSVGUtils.h"

@implementation IJSVGStyle

- (void)dealloc
{
    [_dict release], _dict = nil;
    [super dealloc];
}

- (id)init
{
    if( ( self = [super init] ) != nil )
    {
        _dict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)setPropertyValue:(id)value
             forProperty:(NSString *)key
{
    [_dict setObject:value
              forKey:key];
}

- (id)property:(NSString *)key
{
    return [_dict objectForKey:key];
}

+ (IJSVGStyle *)parseStyleString:(NSString *)string
{
    static NSRegularExpression * _reg = nil;
    static dispatch_once_t onceToken;
    IJSVGStyle * style = [[[[self class] alloc] init] autorelease];
    dispatch_once(&onceToken, ^{
        _reg = [[NSRegularExpression alloc] initWithPattern:@"([a-zA-Z\\-]+)\\:([^;]+)\\;?"
                                                    options:0
                                                      error:nil];
    });
    [_reg enumerateMatchesInString:string
                           options:0
                             range:NSMakeRange( 0, string.length )
                        usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
    {
        NSString * key = [string substringWithRange:[result rangeAtIndex:1]];
        NSString * value = [string substringWithRange:[result rangeAtIndex:2]];
        [[self class] computeStyleProperty:key
                                     value:value
                                     style:style];
    }];
    return style;
}

+ (NSString *)trimString:(NSString *)string
{
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (void)computeStyleProperty:(NSString *)key
                     value:(NSString *)value
                     style:(IJSVGStyle *)style
{
    key = [[self class] trimString:key];
    value = [[self class] trimString:value];
    id val = nil;
    if( [value length] > 4 )
    {
        // is RGBA value
        if( [[value substringToIndex:3] isEqualToString:@"rgb"] )
        {
            NSInteger count = 0;
            CGFloat * params = [IJSVGUtils commandParameters:value
                                                       count:&count];
            CGFloat alpha = 1;
            if( count == 4 )
                alpha = params[3];
            val = [NSColor colorWithCalibratedRed:params[0]/255
                                            green:params[1]/255
                                             blue:params[2]/255
                                            alpha:alpha];
            free(params);
        } else if( [[value substringToIndex:1] isEqualToString:@"#"] ) {
            // hex value
            val = [IJSVGColor colorFromHEXString:value
                                           alpha:1.f];
        }
    }
    
    // value is numeric, convert to a float
    if( [[self class] isNumeric:value] )
        val = @([value floatValue]);

    // set the value
    if( val != nil )
        [style setPropertyValue:val
                    forProperty:key];
    
}

+ (BOOL)isNumeric:(NSString *)string
{
    NSCharacterSet * nonNumbers = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return [string rangeOfCharacterFromSet:nonNumbers].location == NSNotFound;
}

- (NSString *)description
{
    return [_dict description];
}

@end
