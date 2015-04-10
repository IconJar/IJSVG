//
//  IJSVGColor.m
//  IconJar
//
//  Created by Curtis Hard on 31/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGColor.h"
#import "IJSVGUtils.h"

@implementation IJSVGColor

static NSMutableDictionary * _colorTree = nil;


+ (void)load
{
    [[self class] _generateTree];
}

+ (void)_generateTree
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        _colorTree = [[NSMutableDictionary alloc] init];
        // add the colours in
        [_colorTree setObject:@"f0f8ff" forKey:@"aliceblue"];
        [_colorTree setObject:@"faebd7" forKey:@"antiquewhite"];
        [_colorTree setObject:@"00ffff" forKey:@"aqua"];
        [_colorTree setObject:@"7fffd4" forKey:@"aquamarine"];
        [_colorTree setObject:@"f0ffff" forKey:@"azure"];
        [_colorTree setObject:@"f5f5dc" forKey:@"beige"];
        [_colorTree setObject:@"ffe4c4" forKey:@"bisque"];
        [_colorTree setObject:@"000000" forKey:@"black"];
        [_colorTree setObject:@"ffebcd" forKey:@"blanchedalmond"];
        [_colorTree setObject:@"0000ff" forKey:@"blue"];
        [_colorTree setObject:@"8a2be2" forKey:@"blueviolet"];
        [_colorTree setObject:@"a52a2a" forKey:@"brown"];
        [_colorTree setObject:@"deb887" forKey:@"burlywood"];
        [_colorTree setObject:@"5f9ea0" forKey:@"cadetblue"];
        [_colorTree setObject:@"7fff00" forKey:@"chartreuse"];
        [_colorTree setObject:@"d2691e" forKey:@"chocolate"];
        [_colorTree setObject:@"ff7f50" forKey:@"coral"];
        [_colorTree setObject:@"6495ed" forKey:@"cornflowerblue"];
        [_colorTree setObject:@"fff8dc" forKey:@"cornsilk"];
        [_colorTree setObject:@"dc143c" forKey:@"crimson"];
        [_colorTree setObject:@"00ffff" forKey:@"cyan"];
        [_colorTree setObject:@"00008b" forKey:@"darkblue"];
        [_colorTree setObject:@"008b8b" forKey:@"darkcyan"];
        [_colorTree setObject:@"b8860b" forKey:@"darkgoldenrod"];
        [_colorTree setObject:@"a9a9a9" forKey:@"darkgray"];
        [_colorTree setObject:@"006400" forKey:@"darkgreen"];
        [_colorTree setObject:@"a9a9a9" forKey:@"darkgrey"];
        [_colorTree setObject:@"bdb76b" forKey:@"darkkhaki"];
        [_colorTree setObject:@"8b008b" forKey:@"darkmagenta"];
        [_colorTree setObject:@"556b2f" forKey:@"darkolivegreen"];
        [_colorTree setObject:@"ff8c00" forKey:@"darkorange"];
        [_colorTree setObject:@"9932cc" forKey:@"darkorchid"];
        [_colorTree setObject:@"8b0000" forKey:@"darkred"];
        [_colorTree setObject:@"e9967a" forKey:@"darksalmon"];
        [_colorTree setObject:@"8fbc8f" forKey:@"darkseagreen"];
        [_colorTree setObject:@"483d8b" forKey:@"darkslateblue"];
        [_colorTree setObject:@"2f4f4f" forKey:@"darkslategray"];
        [_colorTree setObject:@"2f4f4f" forKey:@"darkslategrey"];
        [_colorTree setObject:@"00ced1" forKey:@"darkturquoise"];
        [_colorTree setObject:@"9400d3" forKey:@"darkviolet"];
        [_colorTree setObject:@"ff1493" forKey:@"deeppink"];
        [_colorTree setObject:@"00bfff" forKey:@"deepskyblue"];
        [_colorTree setObject:@"696969" forKey:@"dimgray"];
        [_colorTree setObject:@"696969" forKey:@"dimgrey"];
        [_colorTree setObject:@"1e90ff" forKey:@"dodgerblue"];
        [_colorTree setObject:@"b22222" forKey:@"firebrick"];
        [_colorTree setObject:@"fffaf0" forKey:@"floralwhite"];
        [_colorTree setObject:@"228b22" forKey:@"forestgreen"];
        [_colorTree setObject:@"ff00ff" forKey:@"fuchsia"];
        [_colorTree setObject:@"dcdcdc" forKey:@"gainsboro"];
        [_colorTree setObject:@"f8f8ff" forKey:@"ghostwhite"];
        [_colorTree setObject:@"ffd700" forKey:@"gold"];
        [_colorTree setObject:@"daa520" forKey:@"goldenrod"];
        [_colorTree setObject:@"808080" forKey:@"gray"];
        [_colorTree setObject:@"008000" forKey:@"green"];
        [_colorTree setObject:@"adff2f" forKey:@"greenyellow"];
        [_colorTree setObject:@"808080" forKey:@"grey"];
        [_colorTree setObject:@"f0fff0" forKey:@"honeydew"];
        [_colorTree setObject:@"ff69b4" forKey:@"hotpink"];
        [_colorTree setObject:@"cd5c5c" forKey:@"indianred"];
        [_colorTree setObject:@"4b0082" forKey:@"indigo"];
        [_colorTree setObject:@"fffff0" forKey:@"ivory"];
        [_colorTree setObject:@"f0e68c" forKey:@"khaki"];
        [_colorTree setObject:@"e6e6fa" forKey:@"lavender"];
        [_colorTree setObject:@"fff0f5" forKey:@"lavenderblush"];
        [_colorTree setObject:@"7cfc00" forKey:@"lawngreen"];
        [_colorTree setObject:@"fffacd" forKey:@"lemonchiffon"];
        [_colorTree setObject:@"add8e6" forKey:@"lightblue"];
        [_colorTree setObject:@"f08080" forKey:@"lightcoral"];
        [_colorTree setObject:@"e0ffff" forKey:@"lightcyan"];
        [_colorTree setObject:@"fafad2" forKey:@"lightgoldenrodyellow"];
        [_colorTree setObject:@"d3d3d3" forKey:@"lightgray"];
        [_colorTree setObject:@"90ee90" forKey:@"lightgreen"];
        [_colorTree setObject:@"d3d3d3" forKey:@"lightgrey"];
        [_colorTree setObject:@"ffb6c1" forKey:@"lightpink"];
        [_colorTree setObject:@"ffa07a" forKey:@"lightsalmon"];
        [_colorTree setObject:@"20b2aa" forKey:@"lightseagreen"];
        [_colorTree setObject:@"87cefa" forKey:@"lightskyblue"];
        [_colorTree setObject:@"778899" forKey:@"lightslategray"];
        [_colorTree setObject:@"778899" forKey:@"lightslategrey"];
        [_colorTree setObject:@"b0c4de" forKey:@"lightsteelblue"];
        [_colorTree setObject:@"ffffe0" forKey:@"lightyellow"];
        [_colorTree setObject:@"00ff00" forKey:@"lime"];
        [_colorTree setObject:@"32cd32" forKey:@"limegreen"];
        [_colorTree setObject:@"faf0e6" forKey:@"linen"];
        [_colorTree setObject:@"ff00ff" forKey:@"magenta"];
        [_colorTree setObject:@"800000" forKey:@"maroon"];
        [_colorTree setObject:@"66cdaa" forKey:@"mediumaquamarine"];
        [_colorTree setObject:@"0000cd" forKey:@"mediumblue"];
        [_colorTree setObject:@"ba55d3" forKey:@"mediumorchid"];
        [_colorTree setObject:@"9370db" forKey:@"mediumpurple"];
        [_colorTree setObject:@"3cb371" forKey:@"mediumseagreen"];
        [_colorTree setObject:@"7b68ee" forKey:@"mediumslateblue"];
        [_colorTree setObject:@"00fa9a" forKey:@"mediumspringgreen"];
        [_colorTree setObject:@"48d1cc" forKey:@"mediumturquoise"];
        [_colorTree setObject:@"c71585" forKey:@"mediumvioletred"];
        [_colorTree setObject:@"191970" forKey:@"midnightblue"];
        [_colorTree setObject:@"f5fffa" forKey:@"mintcream"];
        [_colorTree setObject:@"ffe4e1" forKey:@"mistyrose"];
        [_colorTree setObject:@"ffe4b5" forKey:@"moccasin"];
        [_colorTree setObject:@"ffdead" forKey:@"navajowhite"];
        [_colorTree setObject:@"000080" forKey:@"navy"];
        [_colorTree setObject:@"fdf5e6" forKey:@"oldlace"];
        [_colorTree setObject:@"808000" forKey:@"olive"];
        [_colorTree setObject:@"6b8e23" forKey:@"olivedrab"];
        [_colorTree setObject:@"ffa500" forKey:@"orange"];
        [_colorTree setObject:@"ff4500" forKey:@"orangered"];
        [_colorTree setObject:@"da70d6" forKey:@"orchid"];
        [_colorTree setObject:@"eee8aa" forKey:@"palegoldenrod"];
        [_colorTree setObject:@"98fb98" forKey:@"palegreen"];
        [_colorTree setObject:@"afeeee" forKey:@"paleturquoise"];
        [_colorTree setObject:@"db7093" forKey:@"palevioletred"];
        [_colorTree setObject:@"ffefd5" forKey:@"papayawhip"];
        [_colorTree setObject:@"ffdab9" forKey:@"peachpuff"];
        [_colorTree setObject:@"cd853f" forKey:@"peru"];
        [_colorTree setObject:@"ffc0cb" forKey:@"pink"];
        [_colorTree setObject:@"dda0dd" forKey:@"plum"];
        [_colorTree setObject:@"b0e0e6" forKey:@"powderblue"];
        [_colorTree setObject:@"800080" forKey:@"purple"];
        [_colorTree setObject:@"ff0000" forKey:@"red"];
        [_colorTree setObject:@"bc8f8f" forKey:@"rosybrown"];
        [_colorTree setObject:@"4169e1" forKey:@"royalblue"];
        [_colorTree setObject:@"8b4513" forKey:@"saddlebrown"];
        [_colorTree setObject:@"fa8072" forKey:@"salmon"];
        [_colorTree setObject:@"f4a460" forKey:@"sandybrown"];
        [_colorTree setObject:@"2e8b57" forKey:@"seagreen"];
        [_colorTree setObject:@"fff5ee" forKey:@"seashell"];
        [_colorTree setObject:@"a0522d" forKey:@"sienna"];
        [_colorTree setObject:@"c0c0c0" forKey:@"silver"];
        [_colorTree setObject:@"87ceeb" forKey:@"skyblue"];
        [_colorTree setObject:@"6a5acd" forKey:@"slateblue"];
        [_colorTree setObject:@"708090" forKey:@"slategray"];
        [_colorTree setObject:@"708090" forKey:@"slategrey"];
        [_colorTree setObject:@"fffafa" forKey:@"snow"];
        [_colorTree setObject:@"00ff7f" forKey:@"springgreen"];
        [_colorTree setObject:@"4682b4" forKey:@"steelblue"];
        [_colorTree setObject:@"d2b48c" forKey:@"tan"];
        [_colorTree setObject:@"008080" forKey:@"teal"];
        [_colorTree setObject:@"d8bfd8" forKey:@"thistle"];
        [_colorTree setObject:@"ff6347" forKey:@"tomato"];
        [_colorTree setObject:@"40e0d0" forKey:@"turquoise"];
        [_colorTree setObject:@"ee82ee" forKey:@"violet"];
        [_colorTree setObject:@"f5deb3" forKey:@"wheat"];
        [_colorTree setObject:@"ffffff" forKey:@"white"];
        [_colorTree setObject:@"f5f5f5" forKey:@"whitesmoke"];
        [_colorTree setObject:@"ffff00" forKey:@"yellow"];
        [_colorTree setObject:@"9acd32" forKey:@"yellowgreen"];
    });
}

+ (NSColor *)computeColor:(id)colour
{
    if( [colour isKindOfClass:[NSColor class]] )
        return colour;
    return nil;
}

+ (NSColor *)colorFromString:(NSString *)string
{
    if( [string length] < 3 )
        return nil;
 
    string = [string lowercaseString];
    NSColor * color = [[self class] colorFromPredefinedColorName:string];
    if( color != nil )
        return color;
    
    if( [[string lowercaseString] isEqualToString:@"none"] )
        return [NSColor clearColor];
    
    // is it RGB?
    if( [[string substringToIndex:3] isEqualToString:@"rgb"] )
    {
        NSInteger count = 0;
        CGFloat * params = [IJSVGUtils commandParameters:string
                                                   count:&count];
        CGFloat alpha = 1;
        if( count == 4 )
            alpha = params[3];
        color = [NSColor colorWithCalibratedRed:params[0]/255
                                        green:params[1]/255
                                         blue:params[2]/255
                                        alpha:alpha];
        free(params);
        return color;
    }
    
    color = [[self class] colorFromHEXString:string
                                       alpha:1.f];
    return color;
}

+ (NSColor *)colorFromPredefinedColorName:(NSString *)name
{
    NSString * hex = nil;
    if( ( hex = [_colorTree objectForKey:name] ) == nil )
        return nil;
    return [[self class] colorFromHEXString:hex
                                      alpha:1.f];
}

+ (NSString *)colorNameFromPredefinedColor:(IJSVGPredefinedColor)color
{
    switch(color)
    {
        case IJSVGColorAliceblue:
            return @"aliceblue";
        case IJSVGColorAntiquewhite:
            return @"antiquewhite";
        case IJSVGColorAqua:
            return @"aqua";
        case IJSVGColorAquamarine:
            return @"aquamarine";
        case IJSVGColorAzure:
            return @"azure";
        case IJSVGColorBeige:
            return @"beige";
        case IJSVGColorBisque:
            return @"bisque";
        case IJSVGColorBlack:
            return @"black";
        case IJSVGColorBlanchedalmond:
            return @"blanchedalmond";
        case IJSVGColorBlue:
            return @"blue";
        case IJSVGColorBlueviolet:
            return @"blueviolet";
        case IJSVGColorBrown:
            return @"brown";
        case IJSVGColorBurlywood:
            return @"burlywood";
        case IJSVGColorCadetblue:
            return @"cadetblue";
        case IJSVGColorChartreuse:
            return @"chartreuse";
        case IJSVGColorChocolate:
            return @"chocolate";
        case IJSVGColorCoral:
            return @"coral";
        case IJSVGColorCornflowerblue:
            return @"cornflowerblue";
        case IJSVGColorCornsilk:
            return @"cornsilk";
        case IJSVGColorCrimson:
            return @"crimson";
        case IJSVGColorCyan:
            return @"cyan";
        case IJSVGColorDarkblue:
            return @"darkblue";
        case IJSVGColorDarkcyan:
            return @"darkcyan";
        case IJSVGColorDarkgoldenrod:
            return @"darkgoldenrod";
        case IJSVGColorDarkgray:
            return @"darkgray";
        case IJSVGColorDarkgreen:
            return @"darkgreen";
        case IJSVGColorDarkgrey:
            return @"darkgrey";
        case IJSVGColorDarkkhaki:
            return @"darkkhaki";
        case IJSVGColorDarkmagenta:
            return @"darkmagenta";
        case IJSVGColorDarkolivegreen:
            return @"darkolivegreen";
        case IJSVGColorDarkorange:
            return @"darkorange";
        case IJSVGColorDarkorchid:
            return @"darkorchid";
        case IJSVGColorDarkred:
            return @"darkred";
        case IJSVGColorDarksalmon:
            return @"darksalmon";
        case IJSVGColorDarkseagreen:
            return @"darkseagreen";
        case IJSVGColorDarkslateblue:
            return @"darkslateblue";
        case IJSVGColorDarkslategray:
            return @"darkslategray";
        case IJSVGColorDarkslategrey:
            return @"darkslategrey";
        case IJSVGColorDarkturquoise:
            return @"darkturquoise";
        case IJSVGColorDarkviolet:
            return @"darkviolet";
        case IJSVGColorDeeppink:
            return @"deeppink";
        case IJSVGColorDeepskyblue:
            return @"deepskyblue";
        case IJSVGColorDimgray:
            return @"dimgray";
        case IJSVGColorDimgrey:
            return @"dimgrey";
        case IJSVGColorDodgerblue:
            return @"dodgerblue";
        case IJSVGColorFirebrick:
            return @"firebrick";
        case IJSVGColorFloralwhite:
            return @"floralwhite";
        case IJSVGColorForestgreen:
            return @"forestgreen";
        case IJSVGColorFuchsia:
            return @"fuchsia";
        case IJSVGColorGainsboro:
            return @"gainsboro";
        case IJSVGColorGhostwhite:
            return @"ghostwhite";
        case IJSVGColorGold:
            return @"gold";
        case IJSVGColorGoldenrod:
            return @"goldenrod";
        case IJSVGColorGray:
            return @"gray";
        case IJSVGColorGreen:
            return @"green";
        case IJSVGColorGreenyellow:
            return @"greenyellow";
        case IJSVGColorGrey:
            return @"grey";
        case IJSVGColorHoneydew:
            return @"honeydew";
        case IJSVGColorHotpink:
            return @"hotpink";
        case IJSVGColorIndianred:
            return @"indianred";
        case IJSVGColorIndigo:
            return @"indigo";
        case IJSVGColorIvory:
            return @"ivory";
        case IJSVGColorKhaki:
            return @"khaki";
        case IJSVGColorLavender:
            return @"lavender";
        case IJSVGColorLavenderblush:
            return @"lavenderblush";
        case IJSVGColorLawngreen:
            return @"lawngreen";
        case IJSVGColorLemonchiffon:
            return @"lemonchiffon";
        case IJSVGColorLightblue:
            return @"lightblue";
        case IJSVGColorLightcoral:
            return @"lightcoral";
        case IJSVGColorLightcyan:
            return @"lightcyan";
        case IJSVGColorLightgoldenrodyellow:
            return @"lightgoldenrodyellow";
        case IJSVGColorLightgray:
            return @"lightgray";
        case IJSVGColorLightgreen:
            return @"lightgreen";
        case IJSVGColorLightgrey:
            return @"lightgrey";
        case IJSVGColorLightpink:
            return @"lightpink";
        case IJSVGColorLightsalmon:
            return @"lightsalmon";
        case IJSVGColorLightseagreen:
            return @"lightseagreen";
        case IJSVGColorLightskyblue:
            return @"lightskyblue";
        case IJSVGColorLightslategray:
            return @"lightslategray";
        case IJSVGColorLightslategrey:
            return @"lightslategrey";
        case IJSVGColorLightsteelblue:
            return @"lightsteelblue";
        case IJSVGColorLightyellow:
            return @"lightyellow";
        case IJSVGColorLime:
            return @"lime";
        case IJSVGColorLimegreen:
            return @"limegreen";
        case IJSVGColorLinen:
            return @"linen";
        case IJSVGColorMagenta:
            return @"magenta";
        case IJSVGColorMaroon:
            return @"maroon";
        case IJSVGColorMediumaquamarine:
            return @"mediumaquamarine";
        case IJSVGColorMediumblue:
            return @"mediumblue";
        case IJSVGColorMediumorchid:
            return @"mediumorchid";
        case IJSVGColorMediumpurple:
            return @"mediumpurple";
        case IJSVGColorMediumseagreen:
            return @"mediumseagreen";
        case IJSVGColorMediumslateblue:
            return @"mediumslateblue";
        case IJSVGColorMediumspringgreen:
            return @"mediumspringgreen";
        case IJSVGColorMediumturquoise:
            return @"mediumturquoise";
        case IJSVGColorMediumvioletred:
            return @"mediumvioletred";
        case IJSVGColorMidnightblue:
            return @"midnightblue";
        case IJSVGColorMintcream:
            return @"mintcream";
        case IJSVGColorMistyrose:
            return @"mistyrose";
        case IJSVGColorMoccasin:
            return @"moccasin";
        case IJSVGColorNavajowhite:
            return @"navajowhite";
        case IJSVGColorNavy:
            return @"navy";
        case IJSVGColorOldlace:
            return @"oldlace";
        case IJSVGColorOlive:
            return @"olive";
        case IJSVGColorOlivedrab:
            return @"olivedrab";
        case IJSVGColorOrange:
            return @"orange";
        case IJSVGColorOrangered:
            return @"orangered";
        case IJSVGColorOrchid:
            return @"orchid";
        case IJSVGColorPalegoldenrod:
            return @"palegoldenrod";
        case IJSVGColorPalegreen:
            return @"palegreen";
        case IJSVGColorPaleturquoise:
            return @"paleturquoise";
        case IJSVGColorPalevioletred:
            return @"palevioletred";
        case IJSVGColorPapayawhip:
            return @"papayawhip";
        case IJSVGColorPeachpuff:
            return @"peachpuff";
        case IJSVGColorPeru:
            return @"peru";
        case IJSVGColorPink:
            return @"pink";
        case IJSVGColorPlum:
            return @"plum";
        case IJSVGColorPowderblue:
            return @"powderblue";
        case IJSVGColorPurple:
            return @"purple";
        case IJSVGColorRed:
            return @"red";
        case IJSVGColorRosybrown:
            return @"rosybrown";
        case IJSVGColorRoyalblue:
            return @"royalblue";
        case IJSVGColorSaddlebrown:
            return @"saddlebrown";
        case IJSVGColorSalmon:
            return @"salmon";
        case IJSVGColorSandybrown:
            return @"sandybrown";
        case IJSVGColorSeagreen:
            return @"seagreen";
        case IJSVGColorSeashell:
            return @"seashell";
        case IJSVGColorSienna:
            return @"sienna";
        case IJSVGColorSilver:
            return @"silver";
        case IJSVGColorSkyblue:
            return @"skyblue";
        case IJSVGColorSlateblue:
            return @"slateblue";
        case IJSVGColorSlategray:
            return @"slategray";
        case IJSVGColorSlategrey:
            return @"slategrey";
        case IJSVGColorSnow:
            return @"snow";
        case IJSVGColorSpringgreen:
            return @"springgreen";
        case IJSVGColorSteelblue:
            return @"steelblue";
        case IJSVGColorTan:
            return @"tan";
        case IJSVGColorTeal:
            return @"teal";
        case IJSVGColorThistle:
            return @"thistle";
        case IJSVGColorTomato:
            return @"tomato";
        case IJSVGColorTurquoise:
            return @"turquoise";
        case IJSVGColorViolet:
            return @"violet";
        case IJSVGColorWheat:
            return @"wheat";
        case IJSVGColorWhite:
            return @"white";
        case IJSVGColorWhitesmoke:
            return @"whitesmoke";
        case IJSVGColorYellow:
            return @"yellow";
        case IJSVGColorYellowgreen:
            return @"yellowgreen";
    }
    return nil;
}

+ (NSColor *)changeAlphaOnColor:(NSColor *)color
                             to:(CGFloat)alphaValue
{
    color = [color colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
    return [NSColor colorWithCalibratedRed:[color redComponent]
                                     green:[color greenComponent]
                                      blue:[color blueComponent]
                                     alpha:alphaValue];
}

+ (BOOL)isColor:(NSString *)string
{
    return [[string substringToIndex:1] isEqualToString:@"#"] || [[string substringToIndex:3] isEqualToString:@"rgb"];
}

+ (BOOL)isHex:(NSString *)string
{
    NSCharacterSet *chars = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef#"] invertedSet];
    return [string rangeOfCharacterFromSet:chars].location == NSNotFound;
}

+ (NSColor *)colorFromHEXString:(NSString *)string
                          alpha:(CGFloat)alpha
{
    // absolutely no string
    if( string == nil || string.length == 0 || ![[self class] isHex:string] )
        return nil;
    
    if( [[string substringToIndex:1] isEqualToString:@"#"] )
        string = [string substringFromIndex:1];
    
    // whats the length?
    if(string.length == 3) {
        // shorthand...
        NSMutableString * str = [[[NSMutableString alloc] init] autorelease];
        for( NSInteger i = 0; i < string.length; i++ )
        {
            NSString * sub = [string substringWithRange:NSMakeRange( i, 1)];
            [str appendFormat:@"%@%@",sub,sub];
        }
        string = str;
    }
    
    NSScanner * scanner = [NSScanner scannerWithString:string];
    unsigned int hex;
    if( [scanner scanHexInt:&hex] )
    {
        NSInteger r = (hex>>16) & 0xFF;
        NSInteger g = (hex>>8) & 0xFF;
        NSInteger b = (hex) & 0xFF;
        return [NSColor colorWithCalibratedRed:r/255.f
                                         green:g/255.f
                                          blue:b/255.f
                                         alpha:alpha];
    }
    return nil;
}

@end
