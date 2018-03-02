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

static NSDictionary * _colorTree = nil;

CGFloat * IJSVGColorCSSHSLToHSB(CGFloat hue, CGFloat saturation, CGFloat lightness)
{
    hue *= (1.f/360.f);
    hue = (hue - floorf(hue));
    saturation *= 0.01;
    lightness *= 0.01;
    lightness *= 2.f;
    
    CGFloat s = saturation * ((lightness < 1.f) ? lightness : (2.f - lightness));
    CGFloat brightness = (lightness + s) * .5f;
    if(s != 0.f) {
        s = (2.f * s) / (lightness + s);
    }
    CGFloat * floats = (CGFloat *)malloc(3*sizeof(CGFloat));
    floats[0] = hue;
    floats[1] = s;
    floats[2] = brightness;
    return floats;
};

+ (void)load
{
    [[self class] _generateTree];
}

+ (NSColorSpace *)defaultColorSpace
{
    return [NSColorSpace deviceRGBColorSpace];
}

+ (NSColor *)computeColorSpace:(NSColor *)color
{
    NSColorSpace * space = [self defaultColorSpace];
    if(color.colorSpace != space) {
        color = [color colorUsingColorSpace:space];
    }
    return color;
}

+ (void)_generateTree
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _colorTree = [@{
            @"aliceblue":@"f0f8ff",
            @"antiquewhite":@"faebd7",
            @"aqua":@"00ffff",
            @"aquamarine":@"7fffd4",
            @"azure":@"f0ffff",
            @"beige":@"f5f5dc",
            @"bisque":@"ffe4c4",
            @"black":@"000000",
            @"blanchedalmond":@"ffebcd",
            @"blue":@"0000ff",
            @"blueviolet":@"8a2be2",
            @"brown":@"a52a2a",
            @"burlywood":@"deb887",
            @"cadetblue":@"5f9ea0",
            @"chartreuse":@"7fff00",
            @"chocolate":@"d2691e",
            @"coral":@"ff7f50",
            @"cornflowerblue":@"6495ed",
            @"cornsilk":@"fff8dc",
            @"crimson":@"dc143c",
            @"currentcolor":@"000000",
            @"cyan":@"00ffff",
            @"darkblue":@"00008b",
            @"darkcyan":@"008b8b",
            @"darkgoldenrod":@"b8860b",
            @"darkgray":@"a9a9a9",
            @"darkgreen":@"006400",
            @"darkgrey":@"a9a9a9",
            @"darkkhaki":@"bdb76b",
            @"darkmagenta":@"8b008b",
            @"darkolivegreen":@"556b2f",
            @"darkorange":@"ff8c00",
            @"darkorchid":@"9932cc",
            @"darkred":@"8b0000",
            @"darksalmon":@"e9967a",
            @"darkseagreen":@"8fbc8f",
            @"darkslateblue":@"483d8b",
            @"darkslategray":@"2f4f4f",
            @"darkslategrey":@"2f4f4f",
            @"darkturquoise":@"00ced1",
            @"darkviolet":@"9400d3",
            @"deeppink":@"ff1493",
            @"deepskyblue":@"00bfff",
            @"dimgray":@"696969",
            @"dimgrey":@"696969",
            @"dodgerblue":@"1e90ff",
            @"firebrick":@"b22222",
            @"floralwhite":@"fffaf0",
            @"forestgreen":@"228b22",
            @"fuchsia":@"ff00ff",
            @"gainsboro":@"dcdcdc",
            @"ghostwhite":@"f8f8ff",
            @"gold":@"ffd700",
            @"goldenrod":@"daa520",
            @"gray":@"808080",
            @"green":@"008000",
            @"greenyellow":@"adff2f",
            @"grey":@"808080",
            @"honeydew":@"f0fff0",
            @"hotpink":@"ff69b4",
            @"indianred":@"cd5c5c",
            @"indigo":@"4b0082",
            @"ivory":@"fffff0",
            @"khaki":@"f0e68c",
            @"lavender":@"e6e6fa",
            @"lavenderblush":@"fff0f5",
            @"lawngreen":@"7cfc00",
            @"lemonchiffon":@"fffacd",
            @"lightblue":@"add8e6",
            @"lightcoral":@"f08080",
            @"lightcyan":@"e0ffff",
            @"lightgoldenrodyellow":@"fafad2",
            @"lightgray":@"d3d3d3",
            @"lightgreen":@"90ee90",
            @"lightgrey":@"d3d3d3",
            @"lightpink":@"ffb6c1",
            @"lightsalmon":@"ffa07a",
            @"lightseagreen":@"20b2aa",
            @"lightskyblue":@"87cefa",
            @"lightslategray":@"778899",
            @"lightslategrey":@"778899",
            @"lightsteelblue":@"b0c4de",
            @"lightyellow":@"ffffe0",
            @"lime":@"00ff00",
            @"limegreen":@"32cd32",
            @"linen":@"faf0e6",
            @"magenta":@"ff00ff",
            @"maroon":@"800000",
            @"mediumaquamarine":@"66cdaa",
            @"mediumblue":@"0000cd",
            @"mediumorchid":@"ba55d3",
            @"mediumpurple":@"9370db",
            @"mediumseagreen":@"3cb371",
            @"mediumslateblue":@"7b68ee",
            @"mediumspringgreen":@"00fa9a",
            @"mediumturquoise":@"48d1cc",
            @"mediumvioletred":@"c71585",
            @"midnightblue":@"191970",
            @"mintcream":@"f5fffa",
            @"mistyrose":@"ffe4e1",
            @"moccasin":@"ffe4b5",
            @"navajowhite":@"ffdead",
            @"navy":@"000080",
            @"oldlace":@"fdf5e6",
            @"olive":@"808000",
            @"olivedrab":@"6b8e23",
            @"orange":@"ffa500",
            @"orangered":@"ff4500",
            @"orchid":@"da70d6",
            @"palegoldenrod":@"eee8aa",
            @"palegreen":@"98fb98",
            @"paleturquoise":@"afeeee",
            @"palevioletred":@"db7093",
            @"papayawhip":@"ffefd5",
            @"peachpuff":@"ffdab9",
            @"peru":@"cd853f",
            @"pink":@"ffc0cb",
            @"plum":@"dda0dd",
            @"powderblue":@"b0e0e6",
            @"purple":@"800080",
            @"red":@"ff0000",
            @"rosybrown":@"bc8f8f",
            @"royalblue":@"4169e1",
            @"saddlebrown":@"8b4513",
            @"salmon":@"fa8072",
            @"sandybrown":@"f4a460",
            @"seagreen":@"2e8b57",
            @"seashell":@"fff5ee",
            @"sienna":@"a0522d",
            @"silver":@"c0c0c0",
            @"skyblue":@"87ceeb",
            @"slateblue":@"6a5acd",
            @"slategray":@"708090",
            @"slategrey":@"708090",
            @"snow":@"fffafa",
            @"springgreen":@"00ff7f",
            @"steelblue":@"4682b4",
            @"tan":@"d2b48c",
            @"teal":@"008080",
            @"thistle":@"d8bfd8",
            @"tomato":@"ff6347",
            @"turquoise":@"40e0d0",
            @"violet":@"ee82ee",
            @"wheat":@"f5deb3",
            @"white":@"ffffff",
            @"whitesmoke":@"f5f5f5",
            @"yellow":@"ffff00",
            @"yellowgreen":@"9acd32"
        } retain];
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
    NSCharacterSet * set = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    string = [string stringByTrimmingCharactersInSet:set];
    
    if( [string length] < 3 ) {
        return nil;
    }
 
    string = [string lowercaseString];
    NSColor * color = [[self class] colorFromPredefinedColorName:string];
    if( color != nil ) {
        return color;
    }
    
    if( [[string lowercaseString] isEqualToString:@"none"] ) {
        return [NSColor clearColor];
    }
    
    // is it RGB?
    if( [[string substringToIndex:3] isEqualToString:@"rgb"] ) {
        NSInteger count = 0;
        CGFloat * params = [IJSVGUtils commandParameters:string
                                                   count:&count];
        CGFloat alpha = 1;
        if( count == 4 ) {
            alpha = params[3];
        }
        color = [NSColor colorWithDeviceRed:params[0]/255.f
                                      green:params[1]/255.f
                                       blue:params[2]/255.f
                                      alpha:alpha];
        free(params);
        return color;
    }
    
    // is it HSL?
    if([[string substringToIndex:3] isEqualToString:@"hsl"]) {
        NSInteger count = 0;
        CGFloat * params = [IJSVGUtils commandParameters:string
                                                   count:&count];
        CGFloat alpha = 1;
        if(count == 4) {
            alpha = params[3];
        }
        
        // convert HSL to HSB
        CGFloat * hsb = IJSVGColorCSSHSLToHSB(params[0], params[1], params[2]);
        color = [NSColor colorWithDeviceHue:hsb[0]
                                 saturation:hsb[1]
                                 brightness:hsb[2]
                                      alpha:alpha];
        
        // memory clean!
        free(hsb);
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
    name = [name.lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if( ( hex = [_colorTree objectForKey:name] ) == nil )
        return nil;
    return [[self class] colorFromHEXString:hex
                                      alpha:1.f];
}

+ (NSString *)colorStringFromColor:(NSColor *)color
{
    return [self colorStringFromColor:color
                             forceHex:NO
                       allowShorthand:YES];
}

+ (NSString *)colorStringFromColor:(NSColor *)color
                          forceHex:(BOOL)forceHex
                    allowShorthand:(BOOL)allowShorthand
{
    // convert to RGB
    color = [self computeColorSpace:color];
    
    int red = color.redComponent * 0xFF;
    int green = color.greenComponent * 0xFF;
    int blue = color.blueComponent * 0xFF;
    int alpha = (int)(color.alphaComponent*100);
    
    // jsut return none
    if(alpha == 0 && forceHex == NO) {
        return @"none";
    }
    
    // always return hex unless criteria is met
    if(forceHex || alpha == 100 ||
       (red == 0 && green == 0 && blue == 0 && alpha == 0) ||
       (red == 255 && green == 255 && blue == 255 && alpha == 100)) {
        if(allowShorthand == YES) {
            NSString * r = [NSString stringWithFormat:@"%02X",red];
            NSString * g = [NSString stringWithFormat:@"%02X",green];
            NSString * b = [NSString stringWithFormat:@"%02X",blue];
            if([r characterAtIndex:0] == [r characterAtIndex:1] &&
               [g characterAtIndex:0] == [g characterAtIndex:1] &&
               [b characterAtIndex:0] == [b characterAtIndex:1]) {
                return [NSString stringWithFormat:@"#%c%c%c",[r characterAtIndex:0],
                        [g characterAtIndex:0],[b characterAtIndex:0]];
            }
        }
        return [NSString stringWithFormat:@"#%02X%02X%02X",red,green,blue];
    }
    
    // note the %g, CSS alpha is 0 to 1, not 0 - 100, my bad!
    return [NSString stringWithFormat:@"rgba(%d,%d,%d,%g)",red, green, blue,
            ((float)alpha/100.f)];
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
    color = [self computeColorSpace:color];
    return [NSColor colorWithDeviceRed:[color redComponent]
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
        return [NSColor colorWithDeviceRed:r/255.f
                                     green:g/255.f
                                      blue:b/255.f
                                     alpha:alpha];
    }
    return nil;
}

@end
