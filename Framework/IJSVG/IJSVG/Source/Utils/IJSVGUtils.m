//
//  IJSVGUtils.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGLayer.h"
#import "IJSVGShapeLayer.h"
#import "IJSVGUtils.h"
#import "IJSVGExporterPathInstruction.h"

@implementation IJSVGUtils

BOOL IJSVGIsCommonHTMLElementName(NSString* str)
{
    str = str.lowercaseString;
    return [IJSVGCommonHTMLElementNames() containsObject:str];
};

NSArray* IJSVGCommonHTMLElementNames(void)
{
    static NSArray* names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = [@[ @"a",
            @"abbr",
            @"acronym",
            @"abbr",
            @"address",
            @"applet",
            @"embed",
            @"object",
            @"area",
            @"article",
            @"aside",
            @"audio",
            @"b",
            @"base",
            @"basefont",
            @"bdi",
            @"bdo",
            @"big",
            @"blockquote",
            @"body",
            @"br",
            @"button",
            @"canvas",
            @"caption",
            @"center",
            @"cite",
            @"code",
            @"col",
            @"colgroup",
            @"colgroup",
            @"datalist",
            @"dd",
            @"del",
            @"details",
            @"dfn",
            @"dialog",
            @"dir",
            @"ul",
            @"div",
            @"dl",
            @"dt",
            @"em",
            @"embed",
            @"fieldset",
            @"figcaption",
            @"figure",
            @"figure",
            @"font",
            @"footer",
            @"form",
            @"frame",
            @"frameset",
            @"h1",
            @"h6",
            @"head",
            @"header",
            @"hr",
            @"html",
            @"i",
            @"iframe",
            @"img",
            @"input",
            @"ins",
            @"kbd",
            @"label",
            @"input",
            @"legend",
            @"fieldset",
            @"li",
            @"link",
            @"main",
            @"map",
            @"mark",
            @"menu",
            @"menuitem",
            @"meta",
            @"meter",
            @"nav",
            @"noframes",
            @"noscript",
            @"object",
            @"ol",
            @"optgroup",
            @"option",
            @"output",
            @"p",
            @"param",
            @"picture",
            @"pre",
            @"progress",
            @"q",
            @"rp",
            @"rt",
            @"ruby",
            @"s",
            @"samp",
            @"script",
            @"section",
            @"select",
            @"small",
            @"source",
            @"video",
            @"audio",
            @"span",
            @"strike",
            @"del",
            @"s",
            @"strong",
            @"style",
            @"sub",
            @"summary",
            @"details",
            @"sup",
            @"table",
            @"tbody",
            @"td",
            @"template",
            @"textarea",
            @"tfoot",
            @"th",
            @"thead",
            @"time",
            @"title",
            @"tr",
            @"track",
            @"video",
            @"audio",
            @"tt",
            @"u",
            @"ul",
            @"var",
            @"video",
            @"wbr" ] retain];
    });
    return names;
};

NSString* IJSVGShortenFloatString(NSString* string)
{
    const char* chars = string.UTF8String;
    if (chars[0] == '-' && chars[1] == '0' && strstr(chars, ".") != NULL) {
        return [NSString stringWithFormat:@"-%@", [string substringFromIndex:2]];
    } else if (chars[0] == '0' && chars[1] == '.') {
        return [string substringFromIndex:1];
    }
    return string;
}

IJSVGFloatingPointOptions IJSVGFloatingPointOptionsDefault(void)
{
    return IJSVGFloatingPointOptionsMake(NO, kIJSVGExporterPathInstructionFloatPrecision);
}

IJSVGFloatingPointOptions IJSVGFloatingPointOptionsMake(BOOL round, int precision)
{
    return (IJSVGFloatingPointOptions) {
        .round = round,
        .precision = precision
    };
}

NSString* IJSVGShortFloatStringWithOptions(CGFloat f, IJSVGFloatingPointOptions options)
{
    if (options.round == YES) {
        f = IJSVGExporterPathFloatToFixed(f, options.precision);
    }
    return IJSVGShortFloatString(f);
};

NSString* IJSVGShortFloatString(CGFloat f)
{
    return IJSVGShortenFloatString([NSString stringWithFormat:@"%g", f]);
};

NSString* IJSVGCompressFloatParameterArray(NSArray<NSString*>* strings)
{
    char* lastCommandChars = NULL;
    NSInteger index = 0;
    NSMutableString* string = [[[NSMutableString alloc] init] autorelease];
    for (NSString* dataString in strings) {
        const char* chars = dataString.UTF8String;

        // work out if the command is signed and or decimal
        BOOL isSigned = chars[0] == '-';
        BOOL isDecimal = (isSigned == NO && chars[0] == '.') || (isSigned == YES && chars[1] == '.');

        // we also need to know if the previous command was a decimal or not
        BOOL lastWasDecimal = NO;
        if (lastCommandChars != NULL) {
            lastWasDecimal = strchr(lastCommandChars, '.') != NULL;
        }

        // we only need a space if the current command is not signed
        // a decimal and the previous command was decimal too
        if (index++ == 0 || isSigned || (isDecimal == YES && lastWasDecimal == YES)) {
            [string appendString:dataString];
        } else {
            [string appendFormat:@" %@", dataString];
        }

        // store last command chars
        lastCommandChars = (char*)chars;
    }
    return string;
};

NSString* IJSVGShortFloatStringWithPrecision(CGFloat f, NSInteger precision)
{
    NSString* format = [NSString stringWithFormat:@"%@.%ld%@", @"%", precision, @"f"];
    NSString* ret = [NSString stringWithFormat:format, f];
    if (ret.floatValue == (float)ret.integerValue) {
        ret = [NSString stringWithFormat:@"%ld", ret.integerValue];
    }
    return IJSVGShortenFloatString(ret);
};

NSString* IJSVGPointToCommandString(CGPoint point)
{
    return [NSString stringWithFormat:@"%@ %@",
                     IJSVGShortFloatString(point.x),
                     IJSVGShortFloatString(point.y)];
};

BOOL IJSVGIsLegalCommandCharacter(unichar aChar)
{
    if ((aChar | ('M' ^ 'm')) == 'm' || (aChar | ('Z' ^ 'z')) == 'z' || (aChar | ('C' ^ 'c')) == 'c' || (aChar | ('L' ^ 'l')) == 'l' || (aChar | ('S' ^ 's')) == 's' || (aChar | ('Q' ^ 'q')) == 'q' || (aChar | ('H' ^ 'h')) == 'h' || (aChar | ('V' ^ 'v')) == 'v' || (aChar | ('T' ^ 't')) == 't' || (aChar | ('A' ^ 'a')) == 'a') {
        return YES;
    }
    return NO;
}

BOOL IJSVGIsSVGLayer(CALayer* layer)
{
    return [layer isKindOfClass:IJSVGLayer.class] ||
        [layer isKindOfClass:IJSVGShapeLayer.class];
}

CGFloat angle(CGPoint a, CGPoint b)
{
    return [IJSVGUtils angleBetweenPointA:a
                                   pointb:b];
}

CGFloat ratio(CGPoint a, CGPoint b)
{
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

CGFloat degrees_to_radians(CGFloat degrees)
{
    return ((degrees) / 180.0 * M_PI);
}

+ (IJSVGCommandType)typeForCommandChar:(char)commandChar
{
    return isupper(commandChar) ? kIJSVGCommandTypeAbsolute : kIJSVGCommandTypeRelative;
}

+ (NSRange)rangeOfParentheses:(NSString*)string
{
    NSRange range = NSMakeRange(NSNotFound, 0);
    const char* characters = string.UTF8String;
    unsigned long length = strlen(characters);
    for (NSInteger i = 0; i < length; i++) {
        char c = characters[i];
        if (c == '(') {
            range.location = i + 1;
        } else if (c == ')') {
            range.length = i - range.location;
        }
    }
    return range;
}

+ (NSString* _Nullable)defURL:(NSString*)string
{
    // insta check for URL
    NSCharacterSet* set = NSCharacterSet.whitespaceCharacterSet;
    string = [string stringByTrimmingCharactersInSet:set];
    NSString* check = [string substringToIndex:3].lowercaseString;
    if ([check isEqualToString:@"url"] == NO) {
        return nil;
    }

    static NSRegularExpression* _reg = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _reg = [[NSRegularExpression alloc] initWithPattern:@"url\\(['\"]?([^)]+?)['\"]?\\)"
                                                    options:0
                                                      error:nil];
    });
    __block NSString* foundID = nil;
    [_reg enumerateMatchesInString:string
                           options:0
                             range:NSMakeRange(0, string.length)
                        usingBlock:^(NSTextCheckingResult* result,
                            NSMatchingFlags flags, BOOL* stop) {
                            if ((foundID = [string substringWithRange:[result rangeAtIndex:1]]) != nil) {
                                *stop = YES;
                            }
                        }];
    if ([foundID hasPrefix:@"#"] == YES) {
        foundID = [foundID substringFromIndex:1];
    }
    return foundID;
}

+ (IJSVGFontTraits)fontWeightTraitForString:(NSString*)string
                                     weight:(CGFloat*)weight
{
    *weight = string.floatValue;
    if ([string isEqualToString:@"bold"])
        return IJSVGFontTraitBold;
    return IJSVGFontTraitNone;
}

+ (IJSVGFontTraits)fontStyleStringForString:(NSString*)string
{
    if ([string isEqualToString:@"italic"])
        return IJSVGFontTraitItalic;
    return IJSVGFontTraitNone;
}

+ (IJSVGWindingRule)windingRuleForString:(NSString*)string
{
    if ([string isEqualToString:@"evenodd"])
        return IJSVGWindingRuleEvenOdd;
    if ([string isEqualToString:@"inherit"])
        return IJSVGWindingRuleInherit;
    return IJSVGWindingRuleNonZero;
}

+ (IJSVGLineJoinStyle)lineJoinStyleForString:(NSString*)string
{
    if ([string isEqualToString:@"mitre"])
        return IJSVGLineJoinStyleMiter;
    if ([string isEqualToString:@"round"])
        return IJSVGLineJoinStyleRound;
    if ([string isEqualToString:@"bevel"])
        return IJSVGLineJoinStyleBevel;
    if ([string isEqualToString:@"inherit"])
        return IJSVGLineJoinStyleInherit;
    return IJSVGLineJoinStyleMiter;
}

+ (IJSVGLineCapStyle)lineCapStyleForString:(NSString*)string
{
    if ([string isEqualToString:@"butt"])
        return IJSVGLineCapStyleButt;
    if ([string isEqualToString:@"square"])
        return IJSVGLineCapStyleSquare;
    if ([string isEqualToString:@"round"])
        return IJSVGLineCapStyleRound;
    if ([string isEqualToString:@"inherit"])
        return IJSVGLineCapStyleInherit;
    return IJSVGLineCapStyleButt;
}

+ (IJSVGUnitType)unitTypeForString:(NSString*)string
{
    if ([string isEqualToString:@"userSpaceOnUse"]) {
        return IJSVGUnitUserSpaceOnUse;
    }
    return IJSVGUnitObjectBoundingBox;
}

+ (IJSVGBlendMode)blendModeForString:(NSString*)string
{
    string = string.lowercaseString;
    if ([string isEqualToString:@"normal"])
        return IJSVGBlendModeNormal;
    if ([string isEqualToString:@"multiply"])
        return IJSVGBlendModeMultiply;
    if ([string isEqualToString:@"screen"])
        return IJSVGBlendModeScreen;
    if ([string isEqualToString:@"overlay"])
        return IJSVGBlendModeOverlay;
    if ([string isEqualToString:@"darken"])
        return IJSVGBlendModeDarken;
    if ([string isEqualToString:@"lighten"])
        return IJSVGBlendModeLighten;
    if ([string isEqualToString:@"color-dodge"])
        return IJSVGBlendModeColorDodge;
    if ([string isEqualToString:@"color-burn"])
        return IJSVGBlendModeColorBurn;
    if ([string isEqualToString:@"hard-light"])
        return IJSVGBlendModeHardLight;
    if ([string isEqualToString:@"soft-light"])
        return IJSVGBlendModeSoftLight;
    if ([string isEqualToString:@"difference"])
        return IJSVGBlendModeDifference;
    if ([string isEqualToString:@"exclusion"])
        return IJSVGBlendModeExclusion;
    if ([string isEqualToString:@"hue"])
        return IJSVGBlendModeHue;
    if ([string isEqualToString:@"saturation"])
        return IJSVGBlendModeSaturation;
    if ([string isEqualToString:@"color"])
        return IJSVGBlendModeColor;
    if ([string isEqualToString:@"luminosity"])
        return IJSVGBlendModeLuminosity;
    return IJSVGBlendModeNormal;
}

+ (NSString* _Nullable)mixBlendingModeForBlendMode:(IJSVGBlendMode)blendMode
{
    switch (blendMode) {
    case IJSVGBlendModeMultiply: {
        return @"multiple";
    }
    case IJSVGBlendModeScreen: {
        return @"screen";
    }
    case IJSVGBlendModeOverlay: {
        return @"overlay";
    }
    case IJSVGBlendModeDarken: {
        return @"darken";
    }
    case IJSVGBlendModeLighten: {
        return @"lighten";
    }
    case IJSVGBlendModeColorDodge: {
        return @"color-dodge";
    }
    case IJSVGBlendModeColorBurn: {
        return @"color-burn";
    }
    case IJSVGBlendModeHardLight: {
        return @"hard-light";
    }
    case IJSVGBlendModeSoftLight: {
        return @"soft-light";
    }
    case IJSVGBlendModeDifference: {
        return @"difference";
    }
    case IJSVGBlendModeExclusion: {
        return @"exclusion";
    }
    case IJSVGBlendModeHue: {
        return @"hue";
    }
    case IJSVGBlendModeSaturation: {
        return @"saturation";
    }
    case IJSVGBlendModeColor: {
        return @"color";
    }
    case IJSVGBlendModeLuminosity: {
        return @"luminosity";
    }
    case IJSVGBlendModeNormal:
    default: {
        return nil;
    }
    }
}

+ (CGFloat*)commandParameters:(NSString*)command
                        count:(NSInteger*)count
{
    return [self.class scanFloatsFromString:command
                                       size:count];
}

+ (CGFloat*)scanFloatsFromString:(NSString*)string
                            size:(NSInteger*)length
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
    CGFloat* floats = IJSVGParsePathDataStreamSequence(string.UTF8String, string.length,
        stream, NULL, 1, length);
    IJSVGPathDataStreamRelease(stream);
    return floats;
}

+ (CGFloat*)parseViewBox:(NSString*)string
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreate(4,
        IJSVG_STREAM_CHAR_BLOCK_SIZE);
    CGFloat* floats = IJSVGParsePathDataStreamSequence(string.UTF8String,
        string.length, stream, NULL, 1, NULL);
    IJSVGPathDataStreamRelease(stream);
    return floats;
}

+ (CGFloat)floatValue:(NSString*)string
    fallBackForPercent:(CGFloat)fallBack
{
    CGFloat val = [string floatValue];
    if ([string rangeOfString:@"%"].location != NSNotFound)
        val = (fallBack * val) / 100;
    return val;
}

+ (void)logParameters:(CGFloat*)param
                count:(NSInteger)count
{
    NSMutableString* str = [[[NSMutableString alloc] init] autorelease];
    for (NSInteger i = 0; i < count; i++) {
        [str appendFormat:@"%f ", param[i]];
    }
    NSLog(@"%@", str);
}

+ (CGFloat)floatValue:(NSString*)string
{
    if ([string isEqualToString:@"inherit"])
        return IJSVGInheritedFloatValue;
    return [string floatValue];
}

+ (CGFloat)angleBetweenPointA:(NSPoint)point1
                       pointb:(NSPoint)point2
{
    return (point1.x * point2.y < point1.y * point2.x ? -1 : 1) * acosf(ratio(point1, point2));
}

+ (CGPathRef)newFlippedCGPath:(CGPathRef)path
{
    CGRect boundingBox = CGPathGetPathBoundingBox(path);
    CGAffineTransform scale = CGAffineTransformMakeScale(1.f, -1.f);
    CGAffineTransform translate = CGAffineTransformTranslate(scale, 0.f, boundingBox.size.height);
    CGPathRef transformPath = CGPathCreateCopyByTransformingPath(path, &translate);
    return transformPath;
}

@end
