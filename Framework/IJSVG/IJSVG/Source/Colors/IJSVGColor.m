//
//  IJSVGColor.m
//  IJSVG
//
//  Created by Curtis Hard on 31/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGStringAdditions.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGCSSMathExpression.h>
#import <IJSVGCSSParser.h>
#import <IJSVGColorUtils.h>
#import <IJSVGParserUtils.h>
#import <float.h>

NSString* const IJSVGColorCurrentColorName = @"currentColor";

static NSInteger IJSVGParseColorComponents(const IJSVGCSSComponents* components, CGFloat channels[4], BOOL percentages[4], BOOL* legacy)
{
    const IJSVGCSSComponent* root = components->values;
    NSUInteger index = 1;
    *legacy = NO;
    channels[3] = 1;
    for (NSUInteger channel = 0; channel < 4; channel++) {
        if (index >= root->next) {
            return -1;
        }
        const IJSVGCSSComponent* token = components->values + index;
        CGFloat value = token->number;
        BOOL percent = token->kind == IJSVGCSSComponentPercentage;
        if (token->kind == IJSVGCSSComponentFunction) {
            IJSVGCSSNumericValue result;
            if (!IJSVGCSSMathExpressionEvaluateNumber(components, index, 100, &result)) {
                return -1;
            }
            percent = result.percentage;
            value = result.value;
            if (isnan(value)) {
                value = 0;
            }
        } else if (token->kind == IJSVGCSSComponentIdentifier) {
            if (token->numericKeyword != IJSVGCSSNumericKeywordNone) {
                return -1;
            }
            value = 0;
        } else if (token->kind == IJSVGCSSComponentDimension && token->angleUnit != IJSVGCSSAngleUnitNone) {
            BOOL hue = (channel == 0 && (root->function == IJSVGCSSFunctionHSL || root->function == IJSVGCSSFunctionHSLA)) || (channel == 2 && root->function == IJSVGCSSFunctionOKLCH);
            if (!hue) {
                return -1;
            }
            switch (token->angleUnit) {
                case IJSVGCSSAngleUnitRadians: {
                    value *= 180.f / M_PI;
                    break;
                }
                case IJSVGCSSAngleUnitGradians: {
                    value *= .9f;
                    break;
                }
                case IJSVGCSSAngleUnitTurns: {
                    value *= 360.f;
                    break;
                }
                default: {
                    break;
                }
            }
        } else if (token->kind != IJSVGCSSComponentNumber && !percent) {
            return -1;
        }
        channels[channel] = fmin(FLT_MAX, fmax(-FLT_MAX, value));
        percentages[channel] = percent;
        index = token->next;
        if (index == root->next) {
            return channel == 2 || channel == 3 || *legacy ? (NSInteger)channel + 1 : -1;
        }
        const IJSVGCSSComponent* separator = components->values + index;
        if (channel == 0) {
            *legacy = separator->kind == IJSVGCSSComponentDelimiter && separator->symbol == IJSVGCSSSymbolComma;
        }
        if (channel == 3) {
            return -1;
        }
        if (*legacy || channel == 2) {
            IJSVGCSSSymbol symbol = *legacy ? IJSVGCSSSymbolComma : IJSVGCSSSymbolDivide;
            if (separator->kind != IJSVGCSSComponentDelimiter || separator->symbol != symbol) {
                return -1;
            }
            index = separator->next;
        } else if (!separator->precedingWhitespace) {
            return -1;
        }
    }
    return -1;
}

typedef struct {
    const char* name;
    uint32_t rgb;
} IJSVGNamedColor;

static const IJSVGNamedColor IJSVGNamedColors[] = {
    { "aliceblue", 0xf0f8ff },
    { "antiquewhite", 0xfaebd7 },
    { "aqua", 0x00ffff },
    { "aquamarine", 0x7fffd4 },
    { "azure", 0xf0ffff },
    { "beige", 0xf5f5dc },
    { "bisque", 0xffe4c4 },
    { "black", 0x000000 },
    { "blanchedalmond", 0xffebcd },
    { "blue", 0x0000ff },
    { "blueviolet", 0x8a2be2 },
    { "brown", 0xa52a2a },
    { "burlywood", 0xdeb887 },
    { "cadetblue", 0x5f9ea0 },
    { "chartreuse", 0x7fff00 },
    { "chocolate", 0xd2691e },
    { "coral", 0xff7f50 },
    { "cornflowerblue", 0x6495ed },
    { "cornsilk", 0xfff8dc },
    { "crimson", 0xdc143c },
    { "currentcolor", 0x000000 },
    { "cyan", 0x00ffff },
    { "darkblue", 0x00008b },
    { "darkcyan", 0x008b8b },
    { "darkgoldenrod", 0xb8860b },
    { "darkgray", 0xa9a9a9 },
    { "darkgreen", 0x006400 },
    { "darkgrey", 0xa9a9a9 },
    { "darkkhaki", 0xbdb76b },
    { "darkmagenta", 0x8b008b },
    { "darkolivegreen", 0x556b2f },
    { "darkorange", 0xff8c00 },
    { "darkorchid", 0x9932cc },
    { "darkred", 0x8b0000 },
    { "darksalmon", 0xe9967a },
    { "darkseagreen", 0x8fbc8f },
    { "darkslateblue", 0x483d8b },
    { "darkslategray", 0x2f4f4f },
    { "darkturquoise", 0x00ced1 },
    { "darkviolet", 0x9400d3 },
    { "deeppink", 0xff1493 },
    { "deepskyblue", 0x00bfff },
    { "dimgray", 0x696969 },
    { "dimgrey", 0x696969 },
    { "dodgerblue", 0x1e90ff },
    { "firebrick", 0xb22222 },
    { "floralwhite", 0xfffaf0 },
    { "forestgreen", 0x228b22 },
    { "fuchsia", 0xff00ff },
    { "gainsboro", 0xdcdcdc },
    { "ghostwhite", 0xf8f8ff },
    { "gold", 0xffd700 },
    { "goldenrod", 0xdaa520 },
    { "gray", 0x808080 },
    { "green", 0x008000 },
    { "greenyellow", 0xadff2f },
    { "grey", 0x808080 },
    { "honeydew", 0xf0fff0 },
    { "hotpink", 0xff69b4 },
    { "indianred", 0xcd5c5c },
    { "indigo", 0x4b0082 },
    { "ivory", 0xfffff0 },
    { "khaki", 0xf0e68c },
    { "lavender", 0xe6e6fa },
    { "lavenderblush", 0xfff0f5 },
    { "lawngreen", 0x7cfc00 },
    { "lemonchiffon", 0xfffacd },
    { "lightblue", 0xadd8e6 },
    { "lightcoral", 0xf08080 },
    { "lightcyan", 0xe0ffff },
    { "lightgoldenrodyellow", 0xfafad2 },
    { "lightgray", 0xd3d3d3 },
    { "lightgreen", 0x90ee90 },
    { "lightgrey", 0xd3d3d3 },
    { "lightpink", 0xffb6c1 },
    { "lightsalmon", 0xffa07a },
    { "lightseagreen", 0x20b2aa },
    { "lightskyblue", 0x87cefa },
    { "lightslategray", 0x778899 },
    { "lightsteelblue", 0xb0c4de },
    { "lightyellow", 0xffffe0 },
    { "lime", 0x00ff00 },
    { "limegreen", 0x32cd32 },
    { "linen", 0xfaf0e6 },
    { "magenta", 0xff00ff },
    { "maroon", 0x800000 },
    { "mediumaquamarine", 0x66cdaa },
    { "mediumblue", 0x0000cd },
    { "mediumorchid", 0xba55d3 },
    { "mediumpurple", 0x9370db },
    { "mediumseagreen", 0x3cb371 },
    { "mediumslateblue", 0x7b68ee },
    { "mediumspringgreen", 0x00fa9a },
    { "mediumturquoise", 0x48d1cc },
    { "mediumvioletred", 0xc71585 },
    { "midnightblue", 0x191970 },
    { "mintcream", 0xf5fffa },
    { "mistyrose", 0xffe4e1 },
    { "moccasin", 0xffe4b5 },
    { "navajowhite", 0xffdead },
    { "navy", 0x000080 },
    { "oldlace", 0xfdf5e6 },
    { "olive", 0x808000 },
    { "olivedrab", 0x6b8e23 },
    { "orange", 0xffa500 },
    { "orangered", 0xff4500 },
    { "orchid", 0xda70d6 },
    { "palegoldenrod", 0xeee8aa },
    { "palegreen", 0x98fb98 },
    { "paleturquoise", 0xafeeee },
    { "palevioletred", 0xdb7093 },
    { "papayawhip", 0xffefd5 },
    { "peachpuff", 0xffdab9 },
    { "peru", 0xcd853f },
    { "pink", 0xffc0cb },
    { "plum", 0xdda0dd },
    { "powderblue", 0xb0e0e6 },
    { "purple", 0x800080 },
    { "red", 0xff0000 },
    { "rosybrown", 0xbc8f8f },
    { "royalblue", 0x4169e1 },
    { "saddlebrown", 0x8b4513 },
    { "salmon", 0xfa8072 },
    { "sandybrown", 0xf4a460 },
    { "seagreen", 0x2e8b57 },
    { "seashell", 0xfff5ee },
    { "sienna", 0xa0522d },
    { "silver", 0xc0c0c0 },
    { "skyblue", 0x87ceeb },
    { "slateblue", 0x6a5acd },
    { "slategrey", 0x708090 },
    { "snow", 0xfffafa },
    { "springgreen", 0x00ff7f },
    { "steelblue", 0x4682b4 },
    { "tan", 0xd2b48c },
    { "teal", 0x008080 },
    { "thistle", 0xd8bfd8 },
    { "tomato", 0xff6347 },
    { "turquoise", 0x40e0d0 },
    { "violet", 0xee82ee },
    { "wheat", 0xf5deb3 },
    { "white", 0xffffff },
    { "whitesmoke", 0xf5f5f5 },
    { "yellow", 0xffff00 },
    { "yellowgreen", 0x9acd32 },
};

static BOOL IJSVGNamedColorFromBytes(const char* bytes, NSUInteger length, uint32_t* rgb)
{
    if (bytes == NULL || memchr(bytes, 0, length) != NULL) {
        return NO;
    }
    while (length != 0 && isspace((unsigned char)bytes[length - 1])) {
        length--;
    }
    while (length != 0 && isspace((unsigned char)*bytes)) {
        bytes++;
        length--;
    }
    char name[32];
    if (length == 0 || length >= sizeof(name)) {
        return NO;
    }
    memcpy(name, bytes, length);
    name[length] = 0;
    IJSVGCharBufferToLower(name);
    NSUInteger lower = 0;
    NSUInteger upper = sizeof(IJSVGNamedColors) / sizeof(*IJSVGNamedColors);
    while (lower < upper) {
        NSUInteger middle = lower + (upper - lower) / 2;
        int order = strcmp(name, IJSVGNamedColors[middle].name);
        if (order == 0) {
            *rgb = IJSVGNamedColors[middle].rgb;
            return YES;
        }
        if (order < 0) {
            upper = middle;
        } else {
            lower = middle + 1;
        }
    }
    return NO;
}

static BOOL IJSVGParseLegacyHEXBytes(const char* bytes, NSUInteger* hex, BOOL* hasAlpha)
{
    size_t length = bytes != NULL ? strlen(bytes) : 0;
    if (length == 0 || !IJSVGCharBufferIsHEX((char*)bytes)) {
        return NO;
    }
    if (bytes[0] == '#') {
        length--;
        bytes++;
    }
    if (length == 3 || length == 4) {
        char expanded[9] = { 0 };
        for (NSUInteger index = 0; index < length; index++) {
            expanded[index * 2] = expanded[index * 2 + 1] = bytes[index];
        }
        *hex = strtoul(expanded, NULL, 16);
    } else {
        *hex = strtoul(bytes, NULL, 16);
    }
    *hasAlpha = length == 4 || length == 8;
    return YES;
}

@implementation IJSVGColor

+ (CGColorSpaceRef)linearRGBColorSpace
{
    static CGColorSpaceRef space;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        space = CGColorSpaceCreateWithName(kCGColorSpaceLinearSRGB);
    });
    return space;
}

+ (CGColorSpaceRef)defaultColorSpace
{
    static CGColorSpaceRef space;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    });
    return space;
}

+ (CGColorRef)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
    CGFloat components[] = { red, green, blue, alpha };
    CGColorRef color = CGColorCreate(self.defaultColorSpace, components);
    return color == NULL ? NULL : (CGColorRef)CFAutorelease(color);
}

+ (CGColorRef)blackColor
{
    static CGColorRef color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = CGColorRetain([self colorWithRed:0 green:0 blue:0 alpha:1]);
    });
    return color;
}

+ (CGColorRef)whiteColor
{
    static CGColorRef color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = CGColorRetain([self colorWithRed:1 green:1 blue:1 alpha:1]);
    });
    return color;
}

+ (CGColorRef)clearColor
{
    static CGColorRef color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = CGColorRetain([self colorWithRed:0 green:0 blue:0 alpha:0]);
    });
    return color;
}

+ (CGColorRef)computeColorSpace:(CGColorRef)color
{
    if (color == NULL) {
        return NULL;
    }
    CGColorSpaceRef space = CGColorGetColorSpace(color);
    if (space != NULL && CFEqual(space, self.defaultColorSpace)) {
        return color;
    }
    CGColorRef converted = CGColorCreateCopyByMatchingToColorSpace(self.defaultColorSpace, kCGRenderingIntentDefault, color, NULL);
    return converted == NULL ? NULL : (CGColorRef)CFAutorelease(converted);
}

+ (CGColorRef)colorWithHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha
{
    CGFloat sector = (hue - floor(hue)) * 6;
    CGFloat fraction = sector - floor(sector);
    CGFloat p = brightness * (1 - saturation);
    CGFloat q = brightness * (1 - saturation * fraction);
    CGFloat t = brightness * (1 - saturation * (1 - fraction));
    CGFloat red, green, blue;
    switch ((NSUInteger)sector % 6) {
        case 0:
            red = brightness;
            green = t;
            blue = p;
            break;
        case 1:
            red = q;
            green = brightness;
            blue = p;
            break;
        case 2:
            red = p;
            green = brightness;
            blue = t;
            break;
        case 3:
            red = p;
            green = q;
            blue = brightness;
            break;
        case 4:
            red = t;
            green = p;
            blue = brightness;
            break;
        default:
            red = brightness;
            green = p;
            blue = q;
            break;
    }
    return [self colorWithRed:red green:green blue:blue alpha:alpha];
}

+ (CGColorRef)colorFromRString:(NSString*)rString gString:(NSString*)gString bString:(NSString*)bString aString:(NSString*)aString
{
    return [self colorFromRUnit:[IJSVGUnitLength unitWithString:rString] gUnit:[IJSVGUnitLength unitWithString:gString] bUnit:[IJSVGUnitLength unitWithString:bString] aUnit:[IJSVGUnitLength unitWithString:aString]];
}

+ (CGColorRef)colorFromRUnit:(IJSVGUnitLength*)rUnit gUnit:(IJSVGUnitLength*)gUnit bUnit:(IJSVGUnitLength*)bUnit aUnit:(IJSVGUnitLength*)aUnit
{
    CGFloat r = rUnit.type == IJSVGUnitLengthTypePercentage ? [rUnit computeValue:255.f] : [rUnit computeValue:1.f];
    CGFloat g = gUnit.type == IJSVGUnitLengthTypePercentage ? [gUnit computeValue:255.f] : [gUnit computeValue:1.f];
    CGFloat b = bUnit.type == IJSVGUnitLengthTypePercentage ? [bUnit computeValue:255.f] : [bUnit computeValue:1.f];
    CGFloat a = [aUnit computeValue:100.f];
    return [self computeColorSpace:[self colorWithRed:(r / 255.f) green:(g / 255.f) blue:(b / 255.f) alpha:a]];
}

+ (BOOL)isNoneOrTransparent:(NSString*)string
{
    IJSVGStringBytes source = IJSVGStringGetBytes(string);
    const char* str = source.bytes;
    if (str == NULL || strlen(str) != source.length) {
        return NO;
    }
    return IJSVGCharBufferCaseInsensitiveCompare(str, "none") == YES || IJSVGCharBufferCaseInsensitiveCompare(str, "transparent") == YES;
}

+ (CGColorRef)newCGColorFromString:(NSString*)string
{
    IJSVGStringBytes source = IJSVGStringGetBytes(string);
    uint32_t rgba = 0;
    if (!IJSVGParseHexColorBytes(source.bytes, source.length, &rgba)) {
        uint32_t rgb = 0;
        if (!IJSVGNamedColorFromBytes(source.bytes, source.length, &rgb)) {
            return CGColorRetain([self colorFromString:string]);
        }
        rgba = (rgb << 8) | 0xff;
    }
    CGFloat components[] = {
        ((rgba >> 24) & 0xff) / 255.f,
        ((rgba >> 16) & 0xff) / 255.f,
        ((rgba >> 8) & 0xff) / 255.f,
        (rgba & 0xff) / 255.f
    };
    return CGColorCreate(IJSVGColor.defaultColorSpace, components);
}

+ (CGColorRef)colorFromString:(NSString*)string
{
    // swap over to C for performance
    if (string == nil) {
        return nil;
    }

    IJSVGStringBytes source = IJSVGStringGetBytes(string);
    const char* oString = source.bytes;
    if (oString == NULL || oString[0] == '\0' || strlen(oString) != source.length) {
        return nil;
    }

    const char* start = oString;
    NSUInteger length = source.length;
    while (length != 0 && isspace((unsigned char)*start)) {
        start++;
        length--;
    }
    while (length != 0 && isspace((unsigned char)start[length - 1])) {
        length--;
    }
    uint32_t rgba = 0;
    if (IJSVGParseHexColorBytes(start, length, &rgba)) {
        return [self.class colorFromHEXInteger:rgba containsAlphaComponent:YES];
    }

    char* str = IJSVGTimmedCharBufferCreate(oString);
    NSUInteger hex = 0;
    BOOL hasAlpha = NO;
    if (IJSVGParseLegacyHEXBytes(str, &hex, &hasAlpha)) {
        free(str);
        return [self.class colorFromHEXInteger:hex containsAlphaComponent:hasAlpha];
    }

    if (strchr(str, '(') != NULL) {
        IJSVGCSSComponents components;
        BOOL valid = IJSVGCSSComponentsCreate(str, strlen(str), &components);
        CGColorRef color = nil;
        if (valid && components.count != 0 && components.values[0].kind == IJSVGCSSComponentFunction && components.values[0].next == components.count) {
            CGFloat channels[4] = { 0, 0, 0, 1 };
            BOOL percentages[4] = { NO, NO, NO, NO };
            BOOL legacy = NO;
            NSInteger count = IJSVGParseColorComponents(&components, channels, percentages, &legacy);
            IJSVGCSSFunction function = components.values[0].function;
            if (count >= 3) {
                CGFloat alpha = percentages[3] ? channels[3] / 100.f : channels[3];
                alpha = fmin(1.f, fmax(0.f, alpha));
                switch (function) {
                    case IJSVGCSSFunctionRGB:
                    case IJSVGCSSFunctionRGBA: {
                        for (NSUInteger channel = 0; channel < 3; channel++) {
                            CGFloat divisor = percentages[channel] ? 100.f : 255.f;
                            channels[channel] = fmin(1.f, fmax(0.f, channels[channel] / divisor));
                        }
                        color = [self colorWithRed:channels[0] green:channels[1] blue:channels[2] alpha:alpha];
                        break;
                    }
                    case IJSVGCSSFunctionHSL:
                    case IJSVGCSSFunctionHSLA: {
                        CGFloat* hsb = [self.class HSBFromCSSHSLHue:fmod(channels[0], 360.f) saturation:fmin(100.f, fmax(0.f, channels[1])) lightness:fmin(100.f, fmax(0.f, channels[2]))];
                        color = [self colorWithHue:hsb[0] saturation:hsb[1] brightness:hsb[2] alpha:alpha];
                        free(hsb);
                        break;
                    }
                    case IJSVGCSSFunctionOKLCH: {
                        color = [self.class colorFromOKLCHLightness:percentages[0] ? channels[0] / 100.f : channels[0] chroma:percentages[1] ? channels[1] * .004f : channels[1] hue:percentages[2] ? channels[2] * 3.6f : channels[2] alpha:alpha];
                        break;
                    }
                    default: {
                        break;
                    }
                }
            } else if (count > 0 && legacy && (function == IJSVGCSSFunctionRGB || function == IJSVGCSSFunctionRGBA)) {
                color = IJSVGColor.blackColor;
            }
        }
        IJSVGCSSComponentsRelease(&components);
        free(str);
        return color == nil ? nil : [self computeColorSpace:color];
    }

    // is simply a clear color, dont fill
    if (IJSVGCharBufferCompare(str, "none") == YES || IJSVGCharBufferCompare(str, "transparent") == YES) {
        (void)free(str), str = NULL;
        return nil;
    }

    // could return nil
    (void)free(str), str = NULL;
    return [self.class colorFromPredefinedColorName:string];
}

+ (CGColorRef)colorFromPredefinedColorName:(NSString*)name
{
    IJSVGStringBytes source = IJSVGStringGetBytes(name);
    uint32_t rgb = 0;
    if (!IJSVGNamedColorFromBytes(source.bytes, source.length, &rgb)) {
        return nil;
    }
    return [self.class colorFromHEXInteger:rgb containsAlphaComponent:NO];
}

+ (NSString*)colorStringFromColor:(CGColorRef)color
{
    IJSVGColorStringOptions options = IJSVGColorStringOptionDefault;
    return [self colorStringFromColor:color options:options];
}

+ (NSString*)colorStringFromColor:(CGColorRef)color options:(IJSVGColorStringOptions)options
{
    // convert to RGB
    color = [self computeColorSpace:color];
    CGFloat components[4] = { 0 };
    if (color != NULL) {
        memcpy(components, CGColorGetComponents(color), sizeof(components));
    }

    int red = components[0] * 0xFF;
    int green = components[1] * 0xFF;
    int blue = components[2] * 0xFF;
    int alpha = (int)(components[3] * 100);

    BOOL forceHex = (options & IJSVGColorStringOptionForceHEX) != 0;
    BOOL allowShortHand = (options & IJSVGColorStringOptionAllowShortHand) != 0;
    BOOL allowRRGGBBAA = (options & IJSVGColorStringOptionAllowRRGGBBAA) != 0;

    // jsut return none
    if (alpha == 0 && forceHex == NO) {
        return IJSVGStringNone;
    }

    // always return hex unless criteria is met
    if (forceHex == YES || allowRRGGBBAA == YES || alpha == 100 || (red == 0 && green == 0 && blue == 0 && alpha == 0) || (red == 255 && green == 255 && blue == 255 && alpha == 100)) {
        // we need to make sure the last 2 chars
        // are the same or we cant enable shorthand
        if (allowRRGGBBAA == YES) {
            NSString* alphaHexString = [NSString stringWithFormat:@"%02X", (int)(components[3] * 0xFF)];
            if ([alphaHexString characterAtIndex:0] != [alphaHexString characterAtIndex:1]) {
                allowShortHand = NO;
            }
        }

        if (allowShortHand == YES) {
            NSString* r = [NSString stringWithFormat:@"%02X", red];
            NSString* g = [NSString stringWithFormat:@"%02X", green];
            NSString* b = [NSString stringWithFormat:@"%02X", blue];
            if ([r characterAtIndex:0] == [r characterAtIndex:1] && [g characterAtIndex:0] == [g characterAtIndex:1] && [b characterAtIndex:0] == [b characterAtIndex:1]) {
                // allow shorthand alpha
                if (allowRRGGBBAA == YES && alpha != 100) {
                    NSString* a = [NSString stringWithFormat:@"%02X", (int)(components[3] * 0xFF)];
                    return [NSString stringWithFormat:@"#%c%c%c%c", [r characterAtIndex:0], [g characterAtIndex:0], [b characterAtIndex:0], [a characterAtIndex:0]];
                }
                return [NSString stringWithFormat:@"#%c%c%c", [r characterAtIndex:0], [g characterAtIndex:0], [b characterAtIndex:0]];
            }
        }
        if (allowRRGGBBAA == YES && alpha != 100) {
            return [NSString stringWithFormat:@"#%02X%02X%02X%02X", red, green, blue, (int)(components[3] * 0xFF)];
        }
        return [NSString stringWithFormat:@"#%02X%02X%02X", red, green, blue];
    }

    // note the %g, CSS alpha is 0 to 1, not 0 to 100, my bad!
    return [NSString stringWithFormat:@"rgba(%d,%d,%d,%@)", red, green, blue, IJSVGShortFloatString((float)alpha / 100.f)];
}

+ (NSString*)colorNameFromPredefinedColor:(IJSVGPredefinedColor)color
{
    switch (color) {
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

+ (CGColorRef)changeAlphaOnColor:(CGColorRef)color to:(CGFloat)alphaValue
{
    if (color == NULL) {
        return [self colorWithRed:0 green:0 blue:0 alpha:alphaValue];
    }
    CGColorRef result = CGColorCreateCopyWithAlpha(color, alphaValue);
    return result == NULL ? NULL : (CGColorRef)CFAutorelease(result);
}

+ (BOOL)isColor:(NSString*)string
{
    return [string hasPrefix:@"#"] || [string hasPrefix:@"rgb"];
}

+ (BOOL)isHex:(NSString*)string
{
    return string.ijsvg_isHexString;
}

+ (unsigned long)lengthOfHEXInteger:(NSUInteger)hex
{
    char* buffer;
    asprintf(&buffer, "%lX", (long)hex);
    unsigned long length = strlen(buffer);
    free(buffer);
    return length;
}

+ (BOOL)HEXContainsAlphaComponent:(NSUInteger)hex
{
    return [self lengthOfHEXInteger:hex] == 8;
}

+ (CGColorRef)colorFromHEXInteger:(NSInteger)hex
{
    return [self colorFromHEXInteger:hex containsAlphaComponent:[self HEXContainsAlphaComponent:hex]];
}

+ (CGColorRef)colorFromHEXInteger:(NSInteger)hex containsAlphaComponent:(BOOL)containsAlphaComponent
{
    CGFloat alpha = 1.f;
    if (containsAlphaComponent) {
        alpha = (hex & 0xFF) / 255.f;
        hex = hex >> 8;
    }
    return [self computeColorSpace:[self colorWithRed:((hex >> 16) & 0xFF) / 255.f green:((hex >> 8) & 0xFF) / 255.f blue:(hex & 0xFF) / 255.f alpha:alpha]];
}

+ (unsigned long)HEXFromArbitraryHexString:(NSString*)aString
{
    const char* hexString = [aString cStringUsingEncoding:NSUTF8StringEncoding];
    return strtoul(hexString, NULL, 16);
}

+ (CGColorRef)colorFromHEXString:(NSString*)string
{
    return [self colorFromHEXString:string containsAlphaComponent:nil];
}

+ (CGColorRef)colorFromHEXString:(NSString*)string containsAlphaComponent:(BOOL*)containsAlphaComponent
{
    NSUInteger hex = 0;
    BOOL hasAlpha = NO;
    if (!IJSVGParseLegacyHEXBytes(string.UTF8String, &hex, &hasAlpha)) {
        return nil;
    }
    if (containsAlphaComponent != NULL) {
        *containsAlphaComponent = hasAlpha;
    }
    return [self colorFromHEXInteger:hex containsAlphaComponent:hasAlpha];
}

@end
