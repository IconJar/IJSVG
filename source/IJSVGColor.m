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
    [self.class _generateTree];
}

+ (NSColorSpace *)defaultColorSpace
{
    return NSColorSpace.deviceRGBColorSpace;
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
            @"aliceblue":@(0xf0f8ff),
            @"antiquewhite":@(0xfaebd7),
            @"aqua":@(0x00ffff),
            @"aquamarine":@(0x7fffd4),
            @"azure":@(0xf0ffff),
            @"beige":@(0xf5f5dc),
            @"bisque":@(0xffe4c4),
            @"black":@(0x000000),
            @"blanchedalmond":@(0xffebcd),
            @"blue":@(0x0000ff),
            @"blueviolet":@(0x8a2be2),
            @"brown":@(0xa52a2a),
            @"burlywood":@(0xdeb887),
            @"cadetblue":@(0x5f9ea0),
            @"chartreuse":@(0x7fff00),
            @"chocolate":@(0xd2691e),
            @"coral":@(0xff7f50),
            @"cornflowerblue":@(0x6495ed),
            @"cornsilk":@(0xfff8dc),
            @"crimson":@(0xdc143c),
            @"currentcolor":@(0x000000),
            @"cyan":@(0x00ffff),
            @"darkblue":@(0x00008b),
            @"darkcyan":@(0x008b8b),
            @"darkgoldenrod":@(0xb8860b),
            @"darkgray":@(0xa9a9a9),
            @"darkgreen":@(0x006400),
            @"darkgrey":@(0xa9a9a9),
            @"darkkhaki":@(0xbdb76b),
            @"darkmagenta":@(0x8b008b),
            @"darkolivegreen":@(0x556b2f),
            @"darkorange":@(0xff8c00),
            @"darkorchid":@(0x9932cc),
            @"darkred":@(0x8b0000),
            @"darksalmon":@(0xe9967a),
            @"darkseagreen":@(0x8fbc8f),
            @"darkslateblue":@(0x483d8b),
            @"darkslategray":@(0x2f4f4f),
            @"darkturquoise":@(0x00ced1),
            @"darkviolet":@(0x9400d3),
            @"deeppink":@(0xff1493),
            @"deepskyblue":@(0x00bfff),
            @"dimgray":@(0x696969),
            @"dimgrey":@(0x696969),
            @"dodgerblue":@(0x1e90ff),
            @"firebrick":@(0xb22222),
            @"floralwhite":@(0xfffaf0),
            @"forestgreen":@(0x228b22),
            @"fuchsia":@(0xff00ff),
            @"gainsboro":@(0xdcdcdc),
            @"ghostwhite":@(0xf8f8ff),
            @"gold":@(0xffd700),
            @"goldenrod":@(0xdaa520),
            @"gray":@(0x808080),
            @"green":@(0x008000),
            @"greenyellow":@(0xadff2f),
            @"grey":@(0x808080),
            @"honeydew":@(0xf0fff0),
            @"hotpink":@(0xff69b4),
            @"indianred":@(0xcd5c5c),
            @"indigo":@(0x4b0082),
            @"ivory":@(0xfffff0),
            @"khaki":@(0xf0e68c),
            @"lavender":@(0xe6e6fa),
            @"lavenderblush":@(0xfff0f5),
            @"lawngreen":@(0x7cfc00),
            @"lemonchiffon":@(0xfffacd),
            @"lightblue":@(0xadd8e6),
            @"lightcoral":@(0xf08080),
            @"lightcyan":@(0xe0ffff),
            @"lightgoldenrodyellow":@(0xfafad2),
            @"lightgray":@(0xd3d3d3),
            @"lightgreen":@(0x90ee90),
            @"lightgrey":@(0xd3d3d3),
            @"lightpink":@(0xffb6c1),
            @"lightsalmon":@(0xffa07a),
            @"lightseagreen":@(0x20b2aa),
            @"lightskyblue":@(0x87cefa),
            @"lightslategray":@(0x778899),
            @"lightsteelblue":@(0xb0c4de),
            @"lightyellow":@(0xffffe0),
            @"lime":@(0x00ff00),
            @"limegreen":@(0x32cd32),
            @"linen":@(0xfaf0e6),
            @"magenta":@(0xff00ff),
            @"maroon":@(0x800000),
            @"mediumaquamarine":@(0x66cdaa),
            @"mediumblue":@(0x0000cd),
            @"mediumorchid":@(0xba55d3),
            @"mediumpurple":@(0x9370db),
            @"mediumseagreen":@(0x3cb371),
            @"mediumslateblue":@(0x7b68ee),
            @"mediumspringgreen":@(0x00fa9a),
            @"mediumturquoise":@(0x48d1cc),
            @"mediumvioletred":@(0xc71585),
            @"midnightblue":@(0x191970),
            @"mintcream":@(0xf5fffa),
            @"mistyrose":@(0xffe4e1),
            @"moccasin":@(0xffe4b5),
            @"navajowhite":@(0xffdead),
            @"navy":@(0x000080),
            @"oldlace":@(0xfdf5e6),
            @"olive":@(0x808000),
            @"olivedrab":@(0x6b8e23),
            @"orange":@(0xffa500),
            @"orangered":@(0xff4500),
            @"orchid":@(0xda70d6),
            @"palegoldenrod":@(0xeee8aa),
            @"palegreen":@(0x98fb98),
            @"paleturquoise":@(0xafeeee),
            @"palevioletred":@(0xdb7093),
            @"papayawhip":@(0xffefd5),
            @"peachpuff":@(0xffdab9),
            @"peru":@(0xcd853f),
            @"pink":@(0xffc0cb),
            @"plum":@(0xdda0dd),
            @"powderblue":@(0xb0e0e6),
            @"purple":@(0x800080),
            @"red":@(0xff0000),
            @"rosybrown":@(0xbc8f8f),
            @"royalblue":@(0x4169e1),
            @"saddlebrown":@(0x8b4513),
            @"salmon":@(0xfa8072),
            @"sandybrown":@(0xf4a460),
            @"seagreen":@(0x2e8b57),
            @"seashell":@(0xfff5ee),
            @"sienna":@(0xa0522d),
            @"silver":@(0xc0c0c0),
            @"skyblue":@(0x87ceeb),
            @"slateblue":@(0x6a5acd),
            @"slategrey":@(0x708090),
            @"snow":@(0xfffafa),
            @"springgreen":@(0x00ff7f),
            @"steelblue":@(0x4682b4),
            @"tan":@(0xd2b48c),
            @"teal":@(0x008080),
            @"thistle":@(0xd8bfd8),
            @"tomato":@(0xff6347),
            @"turquoise":@(0x40e0d0),
            @"violet":@(0xee82ee),
            @"wheat":@(0xf5deb3),
            @"white":@(0xffffff),
            @"whitesmoke":@(0xf5f5f5),
            @"yellow":@(0xffff00),
            @"yellowgreen":@(0x9acd32)
        } retain];
    });
}

+ (NSColor *)computeColor:(id)colour
{
    if( [colour isKindOfClass:[NSColor class]] )
        return colour;
    return nil;
}

+ (NSColor *)colorFromRString:(NSString *)rString
                      gString:(NSString *)gString
                      bString:(NSString *)bString
                      aString:(NSString *)aString
{
    return [self colorFromRUnit:[IJSVGUnitLength unitWithString:rString]
                          gUnit:[IJSVGUnitLength unitWithString:gString]
                          bUnit:[IJSVGUnitLength unitWithString:bString]
                          aUnit:[IJSVGUnitLength unitWithString:aString]];
}

+ (NSColor *)colorFromRUnit:(IJSVGUnitLength *)rUnit
                      gUnit:(IJSVGUnitLength *)gUnit
                      bUnit:(IJSVGUnitLength *)bUnit
                      aUnit:(IJSVGUnitLength *)aUnit
{
    CGFloat r = rUnit.type == IJSVGUnitLengthTypePercentage ?
        [rUnit computeValue:255.f] : [rUnit computeValue:1.f];
    CGFloat g = gUnit.type == IJSVGUnitLengthTypePercentage ?
        [gUnit computeValue:255.f] : [gUnit computeValue:1.f];
    CGFloat b = bUnit.type == IJSVGUnitLengthTypePercentage ?
        [bUnit computeValue:255.f] : [bUnit computeValue:1.f];
    CGFloat a = [aUnit computeValue:100.f];
    return [self computeColorSpace:[NSColor colorWithDeviceRed:(r/255.f)
                                                         green:(g/255.f)
                                                          blue:(b/255.f)
                                                         alpha:a]];
}

+ (NSColor *)colorFromString:(NSString *)string
{
    NSCharacterSet * set = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    string = [string stringByTrimmingCharactersInSet:set];
    
    if( [string length] < 3 ) {
        return nil;
    }
 
    NSColor * color = nil;
    string = [string lowercaseString];
    if([self.class isHex:string] == NO) {
        color = [self.class colorFromPredefinedColorName:string];
        if( color != nil ) {
            return color;
        }
    }
    
    // is simply a clear color, dont fill
    if( [[string lowercaseString] isEqualToString:@"none"] ) {
        return [self computeColorSpace:NSColor.clearColor];
    }
    
    // is it RGB?
    if( [[string substringToIndex:3] isEqualToString:@"rgb"] ) {
        NSRange range = [IJSVGUtils rangeOfParentheses:string];
        NSString * rgbString = [string substringWithRange:range];
        NSArray * parts = [rgbString componentsSeparatedByChars:","];
        NSString * alpha = @"100%";
        if(parts.count == 4) {
            alpha = parts[3];
        }
        return [self colorFromRString:parts[0]
                              gString:parts[1]
                              bString:parts[2]
                              aString:alpha];
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
        
        color = [self computeColorSpace:color];
        
        // memory clean!
        free(hsb);
        free(params);
        return color;
    }
    
    color = [self.class colorFromHEXString:string alpha:1.f];
    return color;
}

+ (NSColor *)colorFromPredefinedColorName:(NSString *)name
{
    NSNumber * hex = nil;
    name = [name.lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if((hex = _colorTree[name]) == nil ) {
        return nil;
    }
    return [self.class colorFromHEXInteger:hex.integerValue];
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
    return [self computeColorSpace:[NSColor colorWithDeviceRed:[color redComponent]
                                                         green:[color greenComponent]
                                                          blue:[color blueComponent]
                                                         alpha:alphaValue]];
}

+ (BOOL)isColor:(NSString *)string
{
    return [[string substringToIndex:1] isEqualToString:@"#"] ||
    [[string substringToIndex:3] isEqualToString:@"rgb"];
}

+ (BOOL)isHex:(NSString *)string
{
    const char * validList = "0123456789ABCDEFabcdef#";
    for(NSInteger i = 0; i < string.length; i++) {
        char c = [string characterAtIndex:i];
        if(strchr(validList, c) == NULL) {
            return NO;
        }
    }
    return YES;
}

+ (NSColor *)colorFromHEXInteger:(NSInteger)hex
{
    return [self computeColorSpace:[NSColor colorWithDeviceRed:((hex >> 16) & 0xFF) / 255.f
                                                         green:((hex >> 8) & 0xFF) / 255.f
                                                          blue:(hex & 0xFF) / 255.f
                                                         alpha:1.f]];
}

+ (NSColor *)colorFromHEXString:(NSString *)string
                          alpha:(CGFloat)alpha
{
    // absolutely no string
    if( string == nil || string.length == 0 || ![self.class isHex:string] )
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
    
    const char * hexString = [string cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned long hex = strtoul(hexString, NULL, 16);
    return [self computeColorSpace:[NSColor colorWithDeviceRed:((hex>>16) & 0xFF)/255.f
                                                         green:((hex>>8) & 0xFF)/255.f
                                                          blue:(hex & 0xFF)/255.f
                                                         alpha:alpha]];
}

@end
