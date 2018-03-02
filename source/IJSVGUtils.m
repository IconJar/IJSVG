//
//  IJSVGUtils.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGUtils.h"
#import "IJSVGLayer.h"
#import "IJSVGShapeLayer.h"

@implementation IJSVGUtils

BOOL IJSVGIsCommonHTMLElementName(NSString * str)
{
    str = str.lowercaseString;
    return [IJSVGCommonHTMLElementNames() containsObject:str];
};

NSArray * IJSVGCommonHTMLElementNames()
{
    static NSArray * names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = [@[@"a",
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
                  @"wbr"] retain];
    });
    return names;
};

NSString * IJSVGShortFloatString(CGFloat f)
{
    return [NSString stringWithFormat:@"%g",f];
};

NSString * IJSVGShortFloatStringWithPrecision(CGFloat f, NSInteger precision)
{
    NSString * format = [NSString stringWithFormat:@"%@.%ld%@",@"%",precision,@"f"];
    NSString * ret = [NSString stringWithFormat:format,f];
    // can it be reduced even more?
    if(ret.floatValue == (float)ret.integerValue) {
        ret = [NSString stringWithFormat:@"%ld",ret.integerValue];
    }
    return ret;
};

BOOL IJSVGIsLegalCommandCharacter(unichar aChar)
{
    char * validChars = "MmZzLlHhVvCcSsQqTtAa";
    NSUInteger length = strlen(validChars);
    for(NSUInteger i = 0; i < length; i++) {
        if(aChar == validChars[i]) {
            return YES;
        }
    }
    return NO;
}

BOOL IJSVGIsSVGLayer(CALayer * layer)
{
    return [layer isKindOfClass:IJSVGLayer.class] ||
        [layer isKindOfClass:IJSVGShapeLayer.class];
}

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

+ (IJSVGFontTraits)fontWeightTraitForString:(NSString *)string
                                     weight:(CGFloat *)weight
{
    *weight = string.floatValue;
    if([string isEqualToString:@"bold"])
        return IJSVGFontTraitBold;
    return IJSVGFontTraitNone;
}

+ (IJSVGFontTraits)fontStyleStringForString:(NSString *)string
{
    if([string isEqualToString:@"italic"])
        return IJSVGFontTraitItalic;
    return IJSVGFontTraitNone;
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

+ (IJSVGUnitType)unitTypeForString:(NSString *)string
{
    if([string isEqualToString:@"userSpaceOnUse"]) {
        return IJSVGUnitUserSpaceOnUse;
    }
    return IJSVGUnitObjectBoundingBox;
}

+ (IJSVGBlendMode)blendModeForString:(NSString *)string
{
    string = string.lowercaseString;
    if([string isEqualToString:@"normal"])
        return IJSVGBlendModeNormal;
    if([string isEqualToString:@"multiply"])
        return IJSVGBlendModeMultiply;
    if([string isEqualToString:@"screen"])
        return IJSVGBlendModeScreen;
    if([string isEqualToString:@"overlay"])
        return IJSVGBlendModeOverlay;
    if([string isEqualToString:@"darken"])
        return IJSVGBlendModeDarken;
    if([string isEqualToString:@"lighten"])
        return IJSVGBlendModeLighten;
    if([string isEqualToString:@"color-dodge"])
        return IJSVGBlendModeColorDodge;
    if([string isEqualToString:@"color-burn"])
        return IJSVGBlendModeColorBurn;
    if([string isEqualToString:@"hard-light"])
        return IJSVGBlendModeHardLight;
    if([string isEqualToString:@"soft-light"])
        return IJSVGBlendModeSoftLight;
    if([string isEqualToString:@"difference"])
        return IJSVGBlendModeDifference;
    if([string isEqualToString:@"exclusion"])
        return IJSVGBlendModeExclusion;
    if([string isEqualToString:@"hue"])
        return IJSVGBlendModeHue;
    if([string isEqualToString:@"saturation"])
        return IJSVGBlendModeSaturation;
    if([string isEqualToString:@"color"])
        return IJSVGBlendModeColor;
    if([string isEqualToString:@"luminosity"])
        return IJSVGBlendModeLuminosity;
    return IJSVGBlendModeNormal;
}

+ (NSString *)mixBlendingModeForBlendMode:(IJSVGBlendMode)blendMode
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

+ (CGFloat *)scanFloatsFromString:(NSString *)string
                             size:(NSInteger *)length
{
    // default sizes and memory
    // sizes for the string buffer
    NSInteger defSize = 50;
    NSInteger size = defSize;
    
    // default memory size for the floats
    NSInteger defFloatSize = 100;
    NSInteger floatSize = defFloatSize;
    
    NSInteger i = 0;
    NSInteger counter = 0;
    
    const char * cString = [string cStringUsingEncoding:NSUTF8StringEncoding];
    const char * validChars = "0123456789eE+-.";
    
    NSInteger sLength = strlen(cString);
    
    // buffer for the returned floats
    CGFloat * floats = (CGFloat *)malloc(sizeof(CGFloat)*defFloatSize);
    
    char * buffer = NULL;
    bool isDecimal = false;
    int bufferCount = 0;
    
    while(i < sLength) {
        char currentChar = cString[i];
        
        // work out next char
        char nextChar = (char)0;
        if(i < (sLength-1)) {
            nextChar = cString[i+1];
        }
        
        bool isValid = strchr(validChars, currentChar);
        
        // in order to work out the split, its either because the next char is
        // a  hyphen or a plus, or next char is a decimal and the current number is a decimal
        bool isE = currentChar == 'e' || currentChar == 'E';
        bool wantsEnd = nextChar == '-' || nextChar == '+' ||
            (nextChar == '.' && isDecimal);
        
        // could be a float like 5.334e-5 so dont break on the hypen
        if(wantsEnd && isE && (nextChar == '-' || nextChar == '+')) {
            wantsEnd = false;
        }
        
        // make sure its a valid string
        if(isValid) {
            // alloc the buffer if needed
            if(buffer == NULL) {
                buffer = (char *)calloc(sizeof(char),size);
            } else if((bufferCount+1) == size) {
                // realloc the buffer, incase the string is overflowing the
                // allocated memory
                size += defSize;
                buffer = (char *)realloc(buffer, sizeof(char)*size);
            }
            // set the actual char against it
            if(currentChar == '.') {
                isDecimal = true;
            }
            buffer[bufferCount++] = currentChar;
        } else {
            // if its an invalid char, just stop it
            wantsEnd = true;
        }
        
        // is at end of string, or wants to be stopped
        // buffer has to actually exist or its completly
        // useless and will cause a crash
        if(buffer != NULL && (wantsEnd || i == sLength-1)) {
            // make sure there is enough room in the float pool
            if((counter+1) == floatSize) {
                floatSize += defFloatSize;
                floats = (CGFloat *)realloc(floats, sizeof(CGFloat)*floatSize);
            }
            
            // add the float
            floats[counter++] = atof(buffer);
            
            // memory clean and counter resets
            free(buffer);
            size = defSize;
            isDecimal = false;
            bufferCount = 0;
            buffer = NULL;
        }
        i++;
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

+ (CGPathRef)newFlippedCGPath:(CGPathRef)path
{
    CGRect boundingBox = CGPathGetPathBoundingBox(path);
    CGAffineTransform scale = CGAffineTransformMakeScale(1.f, -1.f);
    CGAffineTransform translate = CGAffineTransformTranslate(scale, 0.f, boundingBox.size.height);
    CGPathRef transformPath = CGPathCreateCopyByTransformingPath(path, &translate);
    return transformPath;
}

+ (CGPathRef)newCGPathFromBezierPath:(NSBezierPath *)bezPath
{
    CGPathRef immutablePath = NULL;
    // Then draw the path elements.
    NSInteger numElements = bezPath.elementCount;
    if (numElements > 0) {
        CGMutablePathRef    path = CGPathCreateMutable();
        NSPoint             points[3];
        BOOL                didClosePath = YES;
        
        for (NSInteger i = 0; i < numElements; i++) {
            switch ([bezPath elementAtIndex:i associatedPoints:points]) {
                case NSMoveToBezierPathElement: {
                    CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
                    break;
                }
                    
                case NSLineToBezierPathElement: {
                    CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
                    didClosePath = NO;
                    break;
                }
                    
                case NSCurveToBezierPathElement: {
                    CGPathAddCurveToPoint(path, NULL, points[0].x, points[0].y,
                                          points[1].x, points[1].y,
                                          points[2].x, points[2].y);
                    didClosePath = NO;
                    break;
                }
                    
                case NSClosePathBezierPathElement: {
                    CGPathCloseSubpath(path);
                    didClosePath = YES;
                    break;
                }
            }
        }
        
        // Be sure the path is closed or Quartz may not do valid hit detection.
        if (didClosePath == NO) {
            CGPathCloseSubpath(path);
        }
     
        // memory clean
        immutablePath = CGPathCreateCopy(path);
        CGPathRelease(path);
    }
    return immutablePath;
}

@end
