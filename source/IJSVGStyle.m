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
    if( ( self = [super init] ) != nil ) {
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

- (NSDictionary *)properties
{
    return _dict;
}

- (id)property:(NSString *)key
{
    return [_dict objectForKey:key];
}

+ (IJSVGStyle *)parseStyleString:(NSString *)string
{
    IJSVGStyle * style = [[[[self class] alloc] init] autorelease];
    NSInteger length = string.length;
    NSInteger index = 0;
    NSString * key = nil;
    NSString * value = nil;
    
    // iterate over the string - its actually really simple what we need
    // to do
    for(NSInteger i = 0; i < length; i++) {
        unichar c = [string characterAtIndex:i];
        
        // find the key
        if(c == ':') {
            key = [string substringWithRange:NSMakeRange(index, (i-index))];
            index = i+1;
        }
        
        // find the value
        else if(c == ';' || i == (length-1)) {
            NSInteger chomp;
            if(i == (length-1) && c != ';') {
                chomp = (i-(index-1));
            } else {
                chomp = (i-index);
            }
            value = [string substringWithRange:NSMakeRange(index, chomp)];
            index = i+1;
        }
        
        // set the propery if it actually exists
        if(key != nil && value != nil) {
            [style setPropertyValue:[[self class] trimString:value]
                        forProperty:[[self class] trimString:key]];
            key = nil;
            value = nil;
        }
    }
    return style;
}

+ (NSString *)trimString:(NSString *)string
{
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSArray *)allowedColourKeys
{
    return @[@"fill",@"stroke-colour",@"stop-color",@"stroke"];
}

+ (BOOL)isNumeric:(NSString *)string
{
    return [[NSScanner scannerWithString:string] scanFloat:NULL];
}

- (void)setProperties:(NSDictionary *)properties
           replaceAll:(BOOL)flag
{
    if(flag) {
        [_dict removeAllObjects];
    }
    [_dict addEntriesFromDictionary:properties];
}

- (NSString *)description
{
    return [_dict description];
}

- (IJSVGStyle *)mergedStyle:(IJSVGStyle *)style
{
    // create the new style
    IJSVGStyle * newStyle = [[[IJSVGStyle alloc] init] autorelease];
    
    // grab the current style
    NSMutableDictionary * dict = [[[self properties] mutableCopy] autorelease];
    
    // overwride the style with the new styles
    [dict addEntriesFromDictionary:[style properties]];
    
    // add the styles to the style
    [newStyle setProperties:dict
                 replaceAll:YES];
    return newStyle;
}

@end
