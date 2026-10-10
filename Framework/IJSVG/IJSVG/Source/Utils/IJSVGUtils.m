//
//  IJSVGUtils.m
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGExporterPathInstruction.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGParser.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation IJSVGUtils

+ (NSString*)MIMETypeForImageData:(NSData*)data
                        sourceURL:(NSURL*)sourceURL
{
    if([sourceURL.scheme isEqualToString:@"data"]) {
        NSString* string = sourceURL.absoluteString;
        NSRange separator = [string rangeOfString:@";"];
        if(separator.location == NSNotFound) {
            separator = [string rangeOfString:@","];
        }
        if(separator.location != NSNotFound && separator.location > 5) {
            NSString* mimeType = [string substringWithRange:NSMakeRange(5,
                separator.location - 5)];
            if([mimeType hasPrefix:@"image/"]) {
                return mimeType;
            }
        }
    }

    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if(source == NULL) {
        return nil;
    }
    CFStringRef typeIdentifier = CGImageSourceGetType(source);
    NSString* mimeType = nil;
    if(typeIdentifier != NULL) {
        UTType* type = [UTType typeWithIdentifier:(__bridge NSString*)typeIdentifier];
        mimeType = type.preferredMIMEType;
    }
    CFRelease(source);
    return mimeType;
}

CGSize const IJSVG_SIZE_INFINITE = (CGSize) {
    .width = CGFLOAT_MAX,
    .height = CGFLOAT_MAX
};

CGSize const IJSVG_SIZE_INTRINSIC = (CGSize) {
    .width = -1.23f,
    .height = -1.23f
};

// This is based on what the browsers do, 300 x 150, this produces a 2:1 scale
// if the viewBox or intrinisic sized needs to be inferred where there are no
// measurements given from the SVG.
CGSize const IJSVG_SIZE_DEFAULT_CLIENT = (CGSize) {
  .width = 300,
  .height = 150
};

BOOL IJSVGIsValidContextSize(CGSize size) {
  return size.width >= 1.f && size.height >= 1.f;
}

CGColorSpaceRef IJSVGDeviceGrayColorSpace(void) {
    static CGColorSpaceRef colorSpace = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colorSpace = CGColorSpaceCreateDeviceGray();
    });
    return colorSpace;
}

CGColorSpaceRef IJSVGDeviceRGBColorSpace(void) {
    static CGColorSpaceRef colorSpace = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colorSpace = CGColorSpaceCreateDeviceRGB();
    });
    return colorSpace;
}



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
    while(length > 0 && isspace(buffer[length-1])) {
        length--;
    }
    while(start < length && isspace(buffer[start])) {
        start++;
    }
    unsigned long size = length - start;
    char* chars = (char*)malloc(sizeof(char)*(size+1));
    memcpy(chars, &buffer[start], size);
    chars[size] = '\0';
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
    
    const char* parameters = NULL;
    size_t length = 0;
    char quote = 0;
    if(!IJSVGParsingUnwrapArgument(method->parameters, &parameters, &length, &quote)) {
        IJSVGParsingStringMethodsRelease(methods, count);
        return nil;
    }
    if(length > 0 && parameters[0] == '#') {
        parameters++;
        length--;
    }
    NSString* foundID = [[NSString alloc] initWithBytes:parameters
                                                 length:length
                                               encoding:NSUTF8StringEncoding];
    
    // release the stuff
    (void)IJSVGParsingStringMethodsRelease(methods, count), methods = NULL;
    return foundID;
}

+ (NSArray<NSString*>*)defURLs:(NSString*)string
{
    const char* characters = string.UTF8String;
    if(characters == NULL || strlen(characters) != [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return @[];
    }
    NSUInteger count = 0;
    BOOL valid = NO;
    IJSVGParsingStringMethod** methods = IJSVGParsingMethodParseStringWithValidation(characters, &count, &valid);
    NSMutableArray<NSString*>* identifiers = [[NSMutableArray alloc] init];
    for(NSUInteger index = 0; valid && index < count; index++) {
        IJSVGParsingStringMethod* method = methods[index];
        if(IJSVGCharBufferCaseInsensitiveCompare(method->name, "url") == NO) {
            valid = NO;
            break;
        }
        const char* parameters = NULL;
        size_t length = 0;
        char quote = 0;
        if(!IJSVGParsingUnwrapArgument(method->parameters, &parameters, &length, &quote)) {
            valid = NO;
            break;
        }
        BOOL quoted = quote != 0;
        if(length < 2 || parameters[0] != '#') {
            valid = NO;
            break;
        }
        for(NSUInteger offset = 1; offset < length; offset++) {
            unsigned char character = (unsigned char)parameters[offset];
            if(character < ' ' || character == '\x7f' || character == '\\'
                || (quoted && character == quote)
                || (!quoted && (isspace(character) || character == '(' || character == ')'
                    || character == '\'' || character == '"'))) {
                valid = NO;
                break;
            }
        }
        if(valid) {
            NSString* identifier = [[NSString alloc] initWithBytes:parameters + 1
                                                            length:length - 1
                                                          encoding:NSUTF8StringEncoding];
            if(identifier == nil) {
                valid = NO;
                break;
            }
            [identifiers addObject:identifier];
        }
    }
    IJSVGParsingStringMethodsRelease(methods, count);
    return valid ? identifiers : @[];
}

+ (IJSVGMarkerUnits)markerUnitsForString:(NSString*)string
{
    if([string isEqualToString:IJSVGStringUserSpaceOnUse]) {
        return IJSVGMarkerUnitsUserSpaceOnUse;
    }
    return IJSVGMarkerUnitsStrokeWidth;
}

+ (IJSVGMarkerOrientType)markerOrientTypeForString:(NSString*)string
{
    if([string isEqualToString:IJSVGStringAuto]) {
        return IJSVGMarkerOrientTypeAuto;
    }
    if([string isEqualToString:IJSVGStringAutoStartReverse]) {
        return IJSVGMarkerOrientTypeAutoStartReverse;
    }
    return IJSVGMarkerOrientTypeAngle;
}

+ (IJSVGContextPaint)contextPaintForString:(NSString*)string
{
    if([string isEqualToString:IJSVGStringContextFill]) {
        return IJSVGContextPaintFill;
    }
    if([string isEqualToString:IJSVGStringContextStroke]) {
        return IJSVGContextPaintStroke;
    }
    return IJSVGContextPaintNone;
}

+ (CGFloat)angleForString:(NSString*)string
{
    if(string.length == 0) {
        return 0;
    }
    NSCharacterSet* whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSString* number = [string stringByTrimmingCharactersInSet:whitespace];
    NSString* suffix = nil;
    CGFloat multiplier = 1;
    if([number hasSuffix:IJSVGStringGradians]) {
        suffix = IJSVGStringGradians;
        multiplier = .9;
    } else if([number hasSuffix:IJSVGStringRadians]) {
        suffix = IJSVGStringRadians;
        multiplier = 180 / M_PI;
    } else if([number hasSuffix:IJSVGStringDegrees]) {
        suffix = IJSVGStringDegrees;
    }
    if(suffix != nil) {
        number = [number substringToIndex:number.length - suffix.length];
    }
    NSArray<NSNumber*>* values = [self numbersFromString:number];
    if(values.count != 1) {
        return 0;
    }
    CGFloat angle = values.firstObject.doubleValue * multiplier;
    return isfinite(angle) ? angle : 0;
}

+ (IJSVGVectorEffect)vectorEffectForString:(NSString*)string
{
    string = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
    if([string isEqualToString:IJSVGStringNonScalingStroke]) {
        return IJSVGVectorEffectNonScalingStroke;
    }
    if([string isEqualToString:IJSVGStringInherit]) {
        return IJSVGVectorEffectInherit;
    }
    return IJSVGVectorEffectNone;
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
        return @"multiply";
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

+ (CGFloat*)commandParameters:(NSString*)command
                   dataStream:(IJSVGPathDataStream*)dataStream
                        count:(NSInteger*)count
{
    return [self.class scanFloatsFromCString:command.UTF8String
                                  dataStream:dataStream
                                        size:count];
}

+ (NSArray<NSNumber*>*)numbersFromString:(NSString*)string
{
    if(string.length == 0) {
        return @[];
    }
    // The path scanner deliberately tolerates separators and invalid text. Validate
    // attribute grammar first so a partial value cannot replace an SVG default.
    static NSRegularExpression* expression;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString* number = @"[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?";
        NSString* pattern = [NSString stringWithFormat:
            @"\\A[ \\t\\r\\n]*%@(?:[ \\t\\r\\n]*,[ \\t\\r\\n]*%@|[ \\t\\r\\n]+%@)*[ \\t\\r\\n]*\\z",
            number, number, number];
        expression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
    });
    if([expression firstMatchInString:string
                              options:0
                                range:NSMakeRange(0, string.length)] == nil) {
        return @[];
    }
    NSInteger count = 0;
    CGFloat* values = [self scanFloatsFromCString:string.UTF8String
                                       dataStream:IJSVGThreadManager.currentManager.pathDataStream
                                             size:&count];
    NSMutableArray<NSNumber*>* numbers = [[NSMutableArray alloc] initWithCapacity:count];
    for(NSInteger index = 0; index < count; index++) {
        if(isfinite(values[index]) == NO) {
            free(values);
            return @[];
        }
        [numbers addObject:@(values[index])];
    }
    free(values);
    return numbers;
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
    CGFloat* floats = [self.class scanFloatsFromCString:buffer
                                             dataStream:stream
                                                   size:length];
    IJSVGPathDataStreamRelease(stream);
    return floats;
}

+ (CGFloat*)scanFloatsFromCString:(const char*)buffer
                       dataStream:(IJSVGPathDataStream*)dataStream
                             size:(NSInteger*)length
{
    return IJSVGParsePathDataStreamSequence(buffer, strlen(buffer),
        dataStream, NULL, 1, length);
}

+ (CGFloat*)scanFloatsFromCString:(const char*)buffer
                       floatCount:(NSUInteger)floatCount
                        charCount:(NSUInteger)charCount
                             size:(NSInteger*)length
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreate(floatCount, charCount);
    CGFloat* floats = [self.class scanFloatsFromCString:buffer
                                             dataStream:stream
                                                   size:length];
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

CGAffineTransform IJSVGPathFlippingTransform(CGPathRef path)
{
    CGRect bounds = CGPathGetPathBoundingBox(path);
    CGAffineTransform scale = CGAffineTransformMakeScale(1.f, -1.f);
    return CGAffineTransformTranslate(scale, 0.f, bounds.size.height);
}

+ (CGPathRef)newFlippedCGPath:(CGPathRef)path
{
    CGAffineTransform transform = IJSVGPathFlippingTransform(path);
    return CGPathCreateCopyByTransformingPath(path, &transform);
}

#pragma mark CG conversions

+ (CGLineJoin)CGLineJoinForJoinStyle:(IJSVGLineJoinStyle)joinStyle
{
    switch (joinStyle) {
        default:
        case IJSVGLineJoinStyleMiter: {
            return kCGLineJoinMiter;
        }
        case IJSVGLineJoinStyleBevel: {
            return kCGLineJoinBevel;
        }
        case IJSVGLineJoinStyleRound: {
            return kCGLineJoinRound;
        }
    }
}

+ (CGLineCap)CGLineCapForCapStyle:(IJSVGLineCapStyle)capStyle
{
    switch (capStyle) {
        default:
        case IJSVGLineCapStyleButt: {
            return kCGLineCapButt;
        }
        case IJSVGLineCapStyleRound: {
            return kCGLineCapRound;
        }
        case IJSVGLineCapStyleSquare: {
            return kCGLineCapSquare;
        }
    }
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
