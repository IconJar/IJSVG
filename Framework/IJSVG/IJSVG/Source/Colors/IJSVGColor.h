//
//  IJSVGColor.h
//  IconJar
//
//  Created by Curtis Hard on 31/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGPlatform.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSInteger, IJSVGColorStringOptions) {
    IJSVGColorStringOptionNone = 1 << 0,
    IJSVGColorStringOptionForceHEX = 1 << 1,
    IJSVGColorStringOptionAllowShortHand = 1 << 2,
    IJSVGColorStringOptionAllowRRGGBBAA = 1 << 3,
    IJSVGColorStringOptionDefault = IJSVGColorStringOptionAllowShortHand
};

typedef NS_ENUM(NSInteger, IJSVGPredefinedColor) {
    IJSVGColorAliceblue,
    IJSVGColorAntiquewhite,
    IJSVGColorAqua,
    IJSVGColorAquamarine,
    IJSVGColorAzure,
    IJSVGColorBeige,
    IJSVGColorBisque,
    IJSVGColorBlack,
    IJSVGColorBlanchedalmond,
    IJSVGColorBlue,
    IJSVGColorBlueviolet,
    IJSVGColorBrown,
    IJSVGColorBurlywood,
    IJSVGColorCadetblue,
    IJSVGColorChartreuse,
    IJSVGColorChocolate,
    IJSVGColorCoral,
    IJSVGColorCornflowerblue,
    IJSVGColorCornsilk,
    IJSVGColorCrimson,
    IJSVGColorCyan,
    IJSVGColorDarkblue,
    IJSVGColorDarkcyan,
    IJSVGColorDarkgoldenrod,
    IJSVGColorDarkgray,
    IJSVGColorDarkgreen,
    IJSVGColorDarkgrey,
    IJSVGColorDarkkhaki,
    IJSVGColorDarkmagenta,
    IJSVGColorDarkolivegreen,
    IJSVGColorDarkorange,
    IJSVGColorDarkorchid,
    IJSVGColorDarkred,
    IJSVGColorDarksalmon,
    IJSVGColorDarkseagreen,
    IJSVGColorDarkslateblue,
    IJSVGColorDarkslategray,
    IJSVGColorDarkslategrey,
    IJSVGColorDarkturquoise,
    IJSVGColorDarkviolet,
    IJSVGColorDeeppink,
    IJSVGColorDeepskyblue,
    IJSVGColorDimgray,
    IJSVGColorDimgrey,
    IJSVGColorDodgerblue,
    IJSVGColorFirebrick,
    IJSVGColorFloralwhite,
    IJSVGColorForestgreen,
    IJSVGColorFuchsia,
    IJSVGColorGainsboro,
    IJSVGColorGhostwhite,
    IJSVGColorGold,
    IJSVGColorGoldenrod,
    IJSVGColorGray,
    IJSVGColorGreen,
    IJSVGColorGreenyellow,
    IJSVGColorGrey,
    IJSVGColorHoneydew,
    IJSVGColorHotpink,
    IJSVGColorIndianred,
    IJSVGColorIndigo,
    IJSVGColorIvory,
    IJSVGColorKhaki,
    IJSVGColorLavender,
    IJSVGColorLavenderblush,
    IJSVGColorLawngreen,
    IJSVGColorLemonchiffon,
    IJSVGColorLightblue,
    IJSVGColorLightcoral,
    IJSVGColorLightcyan,
    IJSVGColorLightgoldenrodyellow,
    IJSVGColorLightgray,
    IJSVGColorLightgreen,
    IJSVGColorLightgrey,
    IJSVGColorLightpink,
    IJSVGColorLightsalmon,
    IJSVGColorLightseagreen,
    IJSVGColorLightskyblue,
    IJSVGColorLightslategray,
    IJSVGColorLightslategrey,
    IJSVGColorLightsteelblue,
    IJSVGColorLightyellow,
    IJSVGColorLime,
    IJSVGColorLimegreen,
    IJSVGColorLinen,
    IJSVGColorMagenta,
    IJSVGColorMaroon,
    IJSVGColorMediumaquamarine,
    IJSVGColorMediumblue,
    IJSVGColorMediumorchid,
    IJSVGColorMediumpurple,
    IJSVGColorMediumseagreen,
    IJSVGColorMediumslateblue,
    IJSVGColorMediumspringgreen,
    IJSVGColorMediumturquoise,
    IJSVGColorMediumvioletred,
    IJSVGColorMidnightblue,
    IJSVGColorMintcream,
    IJSVGColorMistyrose,
    IJSVGColorMoccasin,
    IJSVGColorNavajowhite,
    IJSVGColorNavy,
    IJSVGColorOldlace,
    IJSVGColorOlive,
    IJSVGColorOlivedrab,
    IJSVGColorOrange,
    IJSVGColorOrangered,
    IJSVGColorOrchid,
    IJSVGColorPalegoldenrod,
    IJSVGColorPalegreen,
    IJSVGColorPaleturquoise,
    IJSVGColorPalevioletred,
    IJSVGColorPapayawhip,
    IJSVGColorPeachpuff,
    IJSVGColorPeru,
    IJSVGColorPink,
    IJSVGColorPlum,
    IJSVGColorPowderblue,
    IJSVGColorPurple,
    IJSVGColorRed,
    IJSVGColorRosybrown,
    IJSVGColorRoyalblue,
    IJSVGColorSaddlebrown,
    IJSVGColorSalmon,
    IJSVGColorSandybrown,
    IJSVGColorSeagreen,
    IJSVGColorSeashell,
    IJSVGColorSienna,
    IJSVGColorSilver,
    IJSVGColorSkyblue,
    IJSVGColorSlateblue,
    IJSVGColorSlategray,
    IJSVGColorSlategrey,
    IJSVGColorSnow,
    IJSVGColorSpringgreen,
    IJSVGColorSteelblue,
    IJSVGColorTan,
    IJSVGColorTeal,
    IJSVGColorThistle,
    IJSVGColorTomato,
    IJSVGColorTurquoise,
    IJSVGColorViolet,
    IJSVGColorWheat,
    IJSVGColorWhite,
    IJSVGColorWhitesmoke,
    IJSVGColorYellow,
    IJSVGColorYellowgreen
};

extern NSString * const IJSVGColorCurrentColorName;

@interface IJSVGColor : NSObject

CGFloat* _Nullable IJSVGColorCSSHSLToHSB(CGFloat hue, CGFloat saturation, CGFloat lightness);
BOOL IJSVGColorGetRGBAComponents(NSColor* _Nullable color,
                                 CGFloat* _Nullable red,
                                 CGFloat* _Nullable green,
                                 CGFloat* _Nullable blue,
                                 CGFloat* _Nullable alpha);
CGFloat IJSVGColorAlphaComponent(NSColor* _Nullable color);

+ (NSColor* _Nullable)computeColorSpace:(NSColor* _Nullable)color;
#if TARGET_OS_IOS
+ (CGColorSpaceRef _Nonnull)defaultColorSpace;
#else
+ (NSColorSpace* _Nonnull)defaultColorSpace;
#endif
+ (BOOL)isColor:(NSString* _Nullable)string;
+ (NSString*)colorStringFromColor:(NSColor* _Nullable)color
                          options:(IJSVGColorStringOptions)options;
+ (NSString*)colorStringFromColor:(NSColor* _Nullable)color;
+ (NSColor*)colorFromHEXInteger:(NSInteger)hex;
+ (NSColor* _Nullable)computeColor:(id _Nullable)colour;
+ (BOOL)isNoneOrTransparent:(NSString* _Nullable)string;
+ (NSColor* _Nullable)colorFromString:(NSString* _Nullable)string;
+ (NSColor* _Nullable)colorFromHEXString:(NSString* _Nullable)string;
+ (NSColor* _Nullable)colorFromHEXString:(NSString* _Nullable)string
        containsAlphaComponent:(BOOL* _Nullable)containsAlphaComponent;
+ (BOOL)HEXContainsAlphaComponent:(NSUInteger)hex;
+ (unsigned long)lengthOfHEXInteger:(NSUInteger)hex;
+ (NSColor*)colorFromRString:(NSString* _Nullable)rString
                     gString:(NSString* _Nullable)gString
                     bString:(NSString* _Nullable)bString
                     aString:(NSString* _Nullable)aString;
+ (NSColor* _Nullable)colorFromPredefinedColorName:(NSString* _Nullable)name;
+ (NSString* _Nullable)colorNameFromPredefinedColor:(IJSVGPredefinedColor)color;
+ (NSColor* _Nullable)changeAlphaOnColor:(NSColor* _Nullable)color
                            to:(CGFloat)alphaValue;

@end

NS_ASSUME_NONNULL_END
