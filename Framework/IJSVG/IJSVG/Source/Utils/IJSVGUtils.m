//
//  IJSVGUtils.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLayer.h>
#import <IJSVG/IJSVGShapeLayer.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGExporterPathInstruction.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGUtils

CGSize const IJSVGSizeInfinite = (CGSize) {
    .width = CGFLOAT_MAX,
    .height = CGFLOAT_MAX
};

CGSize const IJSVGSizeIntrinsic = (CGSize) {
    .width = -1.23f,
    .height = -1.23f
};

BOOL IJSVGCharBufferIsHEX(char* buffer) {
    char c;
    while((c = *buffer++)) {
        BOOL flag = ((c == '#') ||
         (c >= '0' && c <= '9') ||
         (c >= 'a' && c <= 'f') ||
         (c >= 'A' && c <= 'F'));
        if(flag == NO) {
            return NO;
        }
    }
    return YES;
}

inline BOOL IJSVGCharBufferHasPrefix(char *str, char *pre)
{
    return strncmp(pre, str, strlen(pre)) == 0;
}

inline BOOL IJSVGCharBufferHasSuffix(char* s1, char* s2)
{
    size_t slen = strlen(s1);
    size_t tlen = strlen(s2);
    if(tlen > slen) {
        return NO;
    }
    return strcmp(s1 + slen - tlen, s2) == 0;
}

char* IJSVGTimmedCharBufferCreate(const char* buffer)
{
    unsigned long start = 0;
    unsigned long length = strlen(buffer);
    while(length-1 > 0 && isspace(buffer[length-1])) {
        length--;
    }
    while(isspace(buffer[start]) && start < length) {
        start++;
    }
    char* chars = (char*)malloc(sizeof(char)*((length-start)+1) ?: sizeof(char));
    memcpy(chars, &buffer[start], length-start);
    chars[length] = '\0';
    return chars;
}

void IJSVGTrimCharBuffer(char* buffer) {
    char* ptr = buffer;
    unsigned long length = strlen(ptr);
    while(length-1 > 0 && isspace(ptr[length-1])) {
        ptr[--length] = '\0';
    }
    while(*ptr && isspace(*ptr)) {
        ++ptr;
        --length;
    }
    memmove(buffer, ptr, length+1);
}

inline char IJSVGCharToLower(char c)
{
    if(c >= 'A' && c <= 'Z') {
        return c - ('A' - 'a');
    }
    return c;
}

BOOL IJSVGCharBufferCaseInsensitiveCompare(const char* str1, const char* str2)
{
    if(str1 == str2) {
        return YES;
    }
    
    const char *p1 = str1;
    const char *p2 = str2;
    int result = 0;
    
    while((result = IJSVGCharToLower(*p1) - IJSVGCharToLower(*p2++)) == 0) {
        if(*p1++ == '\0') {
            break;
        }
    }
    return result == 0;
}

inline BOOL IJSVGCharBufferCompare(const char* str1, const char* str2)
{
    if(str1[0] != str2[0]) {
        return NO;
    }
    return strcmp(str1, str2) == 0;
}

inline void IJSVGCharBufferToLower(char* buffer)
{
    for(char *p = buffer; *p; p++) {
        *p = IJSVGCharToLower(*p);
    }
}

size_t IJSVGCharBufferHash(char* buffer)
{
    unsigned long hash = 5381;
    int c;
    while ((c = *buffer++)) {
        hash = ((hash << 5) + hash) + c;
    }
    return hash;
}

NSString* IJSVGShortenFloatString(NSString* string)
{
    const char* chars = string.UTF8String;
    if(chars[0] == '-' && chars[1] == '0' && strstr(chars, ".") != NULL) {
        return [NSString stringWithFormat:@"-%@", [string substringFromIndex:2]];
    } else if(chars[0] == '0' && chars[1] == '.') {
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
    if(options.round == YES) {
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
    NSMutableString* string = [[NSMutableString alloc] init];
    for (NSString* dataString in strings) {
        const char* chars = dataString.UTF8String;

        // work out if the command is signed and or decimal
        BOOL isSigned = chars[0] == '-';
        BOOL isDecimal = (isSigned == NO && chars[0] == '.') || (isSigned == YES && chars[1] == '.');

        // we also need to know if the previous command was a decimal or not
        BOOL lastWasDecimal = NO;
        if(lastCommandChars != NULL) {
            lastWasDecimal = strchr(lastCommandChars, '.') != NULL;
        }

        // we only need a space if the current command is not signed
        // a decimal and the previous command was decimal too
        if(index++ == 0 || isSigned || (isDecimal == YES && lastWasDecimal == YES)) {
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
    if(ret.floatValue == (float)ret.integerValue) {
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
    if((aChar | ('M' ^ 'm')) == 'm' ||
        (aChar | ('Z' ^ 'z')) == 'z' ||
        (aChar | ('C' ^ 'c')) == 'c' ||
        (aChar | ('L' ^ 'l')) == 'l' ||
        (aChar | ('S' ^ 's')) == 's' ||
        (aChar | ('Q' ^ 'q')) == 'q' ||
        (aChar | ('H' ^ 'h')) == 'h' ||
        (aChar | ('V' ^ 'v')) == 'v' ||
        (aChar | ('T' ^ 't')) == 't' ||
        (aChar | ('A' ^ 'a')) == 'a') {
        return YES;
    }
    return NO;
}

void IJSVGPathGetLastQuadraticCommandPointEnumerationCallback(void *info, const CGPathElement *element)
{
    // this will just iterate over the path and keep changing the point
    // when we come across a quad curve, we cant break when we find one as we
    // dont know when the last one is.
    CGPoint* point = (CGPoint*)info;
    if(element->type == kCGPathElementAddQuadCurveToPoint) {
        CGPoint curvePoint = element->points[0];
        point->x = curvePoint.x;
        point->y = curvePoint.y;
    }
}

CGPoint IJSVGPathGetLastQuadraticCommandPoint(CGPathRef path)
{
    CGPoint point = CGPointZero;
    CGPathApply(path, &point,
                IJSVGPathGetLastQuadraticCommandPointEnumerationCallback);
    return point;
}

BOOL IJSVGIsSVGLayer(CALayer* layer)
{
    return [layer isKindOfClass:IJSVGLayer.class] ||
        [layer isKindOfClass:IJSVGShapeLayer.class];
}

CGFloat IJSVGAngle(CGPoint a, CGPoint b)
{
    return [IJSVGUtils angleBetweenPointA:a
                                   pointb:b];
}

CGFloat IJSVGRatio(CGPoint a, CGPoint b)
{
    return (a.x * b.x + a.y * b.y) / (IJSVGMagnitude(a) * IJSVGMagnitude(b));
}

CGFloat IJSVGMagnitude(CGPoint point)
{
    return sqrtf(powf(point.x, 2) + powf(point.y, 2));
}

CGFloat IJSVGRadiansToDegrees(CGFloat radians)
{
    return ((radians) * (180.0 / M_PI));
}

CGFloat IJSVGDegreesToRadians(CGFloat degrees)
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
        char c = *characters++;
        if(c == '(') {
            range.location = i + 1;
        } else if(c == ')') {
            range.length = i - range.location;
        }
    }
    return range;
}

+ (NSString* _Nullable)defURL:(NSString*)string
{
    const char* str = string.UTF8String;
    NSUInteger count = 0;
    IJSVGParsingStringMethod** methods;
    methods = IJSVGParsingMethodParseString(str, &count);
    if(count == 0) {
        IJSVGParsingStringMethodsRelease(methods, count);
        return nil;
    }
    
    // what type of method is it?
    IJSVGParsingStringMethod* method = methods[0];
    if(IJSVGCharBufferCaseInsensitiveCompare(method->name, "url") == NO) {
        (void)IJSVGParsingStringMethodsRelease(methods, count), methods = NULL;
        return nil;
    }
    
    // remove the #
    char* parameters = method->parameters;
    if(parameters[0] == '#') {
        parameters++;
    }
    
    // make the nsstring
    NSString* foundID = [NSString stringWithUTF8String:parameters];
    
    // release the stuff
    (void)IJSVGParsingStringMethodsRelease(methods, count), methods = NULL;
    return foundID;
}

+ (IJSVGFontTraits)fontWeightTraitForString:(NSString*)string
                                     weight:(CGFloat*)weight
{
    *weight = string.floatValue;
    if([string isEqualToString:@"bold"])
        return IJSVGFontTraitBold;
    return IJSVGFontTraitNone;
}

+ (IJSVGFontTraits)fontStyleStringForString:(NSString*)string
{
    if([string isEqualToString:@"italic"])
        return IJSVGFontTraitItalic;
    return IJSVGFontTraitNone;
}

+ (IJSVGWindingRule)windingRuleForString:(NSString*)string
{
    if([string isEqualToString:IJSVGStringEvenOdd])
        return IJSVGWindingRuleEvenOdd;
    if([string isEqualToString:IJSVGStringInherit])
        return IJSVGWindingRuleInherit;
    return IJSVGWindingRuleNonZero;
}

+ (IJSVGLineJoinStyle)lineJoinStyleForString:(NSString*)string
{
    if([string isEqualToString:IJSVGStringMiter])
        return IJSVGLineJoinStyleMiter;
    if([string isEqualToString:IJSVGStringRound])
        return IJSVGLineJoinStyleRound;
    if([string isEqualToString:IJSVGStringBevel])
        return IJSVGLineJoinStyleBevel;
    if([string isEqualToString:IJSVGStringInherit])
        return IJSVGLineJoinStyleInherit;
    return IJSVGLineJoinStyleMiter;
}

+ (IJSVGLineCapStyle)lineCapStyleForString:(NSString*)string
{
    if([string isEqualToString:IJSVGStringButt])
        return IJSVGLineCapStyleButt;
    if([string isEqualToString:IJSVGStringSquare])
        return IJSVGLineCapStyleSquare;
    if([string isEqualToString:IJSVGStringRound])
        return IJSVGLineCapStyleRound;
    if([string isEqualToString:IJSVGStringInherit])
        return IJSVGLineCapStyleInherit;
    return IJSVGLineCapStyleButt;
}

+ (IJSVGLineCapStyle)lineCapStyleForCGLineCap:(CGLineCap)lineCap
{
    switch(lineCap) {
        case kCGLineCapButt: {
            return IJSVGLineCapStyleButt;
        }
        case kCGLineCapRound: {
            return IJSVGLineCapStyleRound;
        }
        case kCGLineCapSquare: {
            return IJSVGLineCapStyleSquare;
        }
        default: {
            return IJSVGLineCapStyleInherit;
        }
    }
}

+ (IJSVGLineJoinStyle)lineJoinStyleForCGLineJoin:(CGLineJoin)lineJoin
{
    switch(lineJoin) {
        case kCGLineJoinRound: {
            return IJSVGLineJoinStyleRound;
        }
        case kCGLineJoinMiter: {
            return IJSVGLineJoinStyleMiter;
        }
        case kCGLineJoinBevel: {
            return IJSVGLineJoinStyleBevel;
        }
        default: {
            return IJSVGLineJoinStyleInherit;
        }
    }
}

+ (IJSVGUnitType)unitTypeForString:(NSString*)string
{
    if([string isEqualToString:IJSVGStringUserSpaceOnUse]) {
        return IJSVGUnitUserSpaceOnUse;
    }
    return IJSVGUnitObjectBoundingBox;
}

+ (IJSVGBlendMode)blendModeForString:(NSString*)string
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
    return [self.class scanFloatsFromCString:string.UTF8String
                                        size:length];
}

+ (CGFloat*)scanFloatsFromCString:(const char*)buffer
                             size:(NSInteger*)length
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
    CGFloat* floats = IJSVGParsePathDataStreamSequence(buffer, strlen(buffer),
        stream, NULL, 1, length);
    IJSVGPathDataStreamRelease(stream);
    return floats;
}

+ (CGFloat*)scanFloatsFromCString:(const char*)buffer
                       floatCount:(NSUInteger)floatCount
                        charCount:(NSUInteger)charCount
                             size:(NSInteger*)length
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreate(floatCount, charCount);
    CGFloat* floats = IJSVGParsePathDataStreamSequence(buffer, strlen(buffer),
        stream, NULL, 1, length);
    IJSVGPathDataStreamRelease(stream);
    return floats;
}

+ (CGFloat*)parseViewBox:(NSString*)string
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreate(4,
        IJSVG_STREAM_CHAR_BLOCK_SIZE);
    const char* str = string.UTF8String;
    CGFloat* floats = IJSVGParsePathDataStreamSequence(str, strlen(str),
                                                       stream, NULL, 1, NULL);
    IJSVGPathDataStreamRelease(stream);
    return floats;
}

+ (CGFloat)floatValue:(NSString*)string
    fallBackForPercent:(CGFloat)fallBack
{
    CGFloat val = [string floatValue];
    if([string rangeOfString:@"%"].location != NSNotFound) {
        val = (fallBack * val) / 100;
    }
    return val;
}

+ (void)logParameters:(CGFloat*)param
                count:(NSInteger)count
{
    NSMutableString* str = [[NSMutableString alloc] init];
    for (NSInteger i = 0; i < count; i++) {
        [str appendFormat:@"%f ", param[i]];
    }
    NSLog(@"%@", str);
}

+ (CGFloat)floatValue:(NSString*)string
{
    if([string isEqualToString:IJSVGStringInherit]) {
        return IJSVGInheritedFloatValue;
    }
    return [string floatValue];
}

+ (CGFloat)angleBetweenPointA:(NSPoint)point1
                       pointb:(NSPoint)point2
{
    return (point1.x * point2.y < point1.y * point2.x ? -1 : 1) * acosf(IJSVGRatio(point1, point2));
}

+ (CGPathRef)newFlippedCGPath:(CGPathRef)path
{
    CGRect boundingBox = CGPathGetPathBoundingBox(path);
    CGAffineTransform scale = CGAffineTransformMakeScale(1.f, -1.f);
    CGAffineTransform translate = CGAffineTransformTranslate(scale, 0.f, boundingBox.size.height);
    CGPathRef transformPath = CGPathCreateCopyByTransformingPath(path, &translate);
    return transformPath;
}

#pragma mark CG conversions

+ (CAShapeLayerLineJoin)CGLineJoinForJoinStyle:(IJSVGLineJoinStyle)joinStyle
{
    switch (joinStyle) {
        default:
        case IJSVGLineJoinStyleMiter: {
            return kCALineJoinMiter;
        }
        case IJSVGLineJoinStyleBevel: {
            return kCALineJoinBevel;
        }
        case IJSVGLineJoinStyleRound: {
            return kCALineJoinRound;
        }
    }
}

+ (CAShapeLayerLineCap)CGLineCapForCapStyle:(IJSVGLineCapStyle)capStyle
{
    switch (capStyle) {
        default:
        case IJSVGLineCapStyleButt: {
            return kCALineCapButt;
        }
        case IJSVGLineCapStyleRound: {
            return kCALineCapRound;
        }
        case IJSVGLineCapStyleSquare: {
            return kCALineCapSquare;
        }
    }
}

+ (CAShapeLayerFillRule)CGFillRuleForWindingRule:(IJSVGWindingRule)rule
{
    switch (rule) {
        case IJSVGWindingRuleEvenOdd: {
            return kCAFillRuleEvenOdd;
        }
        default: {
            return kCAFillRuleNonZero;
        }
    }
}

+ (CGLineCap)CGLineCapForCALineCap:(CAShapeLayerLineCap)lineCap
{
    if([lineCap isEqualToString:kCALineCapButt]) {
        return kCGLineCapButt;
    }
    if([lineCap isEqualToString:kCALineCapRound]) {
        return kCGLineCapRound;
    }
    return kCGLineCapSquare;
}

+ (CGLineJoin)CGLineJoinForCALineJoin:(CAShapeLayerLineCap)lineJoin
{
    if([lineJoin isEqualToString:kCALineJoinBevel]) {
        return kCGLineJoinBevel;
    }
    if([lineJoin isEqualToString:kCALineJoinMiter]) {
        return kCGLineJoinMiter;
    }
    return kCGLineJoinRound;
}

+ (NSImage*)resizeImage:(NSImage*)anImage
                 toSize:(CGSize)size
{
    NSImage* image = [[NSImage alloc] initWithSize:size];
    [image lockFocus];
    [anImage drawInRect:NSMakeRect(0.f, 0.f, size.width, size.height)
               fromRect:NSMakeRect(0.f, 0.f, anImage.size.width, anImage.size.height)
              operation:NSCompositingOperationCopy
               fraction:1.f];
    [image unlockFocus];
    return image;
}

@end
