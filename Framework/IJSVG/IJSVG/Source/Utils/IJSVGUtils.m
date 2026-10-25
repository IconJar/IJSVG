//
//  IJSVGUtils.m
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGExporterPathInstruction.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGCSSParser.h>
#import <IJSVGParserUtils.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

typedef struct {
    CGPoint start;
    BOOL active;
    BOOL hasLength;
    BOOL found;
} IJSVGPointSubpathState;

static void IJSVGCheckPointSubpath(void* info, const CGPathElement* element)
{
    IJSVGPointSubpathState* state = info;
    if (state->found) {
        return;
    }
    if (element->type == kCGPathElementMoveToPoint) {
        state->found = state->active && !state->hasLength;
        state->start = element->points[0];
        state->active = YES;
        state->hasLength = NO;
        return;
    }
    if (state->hasLength) {
        return;
    }
    NSUInteger count = element->type == kCGPathElementAddCurveToPoint ? 3 : element->type == kCGPathElementAddQuadCurveToPoint ? 2
        : element->type == kCGPathElementAddLineToPoint                                                                        ? 1
                                                                                                                               : 0;
    for (NSUInteger index = 0; index < count; index++) {
        if (!CGPointEqualToPoint(state->start, element->points[index])) {
            state->hasLength = YES;
            break;
        }
    }
}

BOOL IJSVGPathHasPointSubpaths(CGPathRef path)
{
    if (path == NULL) {
        return NO;
    }
    IJSVGPointSubpathState state = { 0 };
    CGPathApply(path, &state, IJSVGCheckPointSubpath);
    return state.found || (state.active && !state.hasLength);
}

@implementation IJSVGUtils

+ (NSString*)MIMETypeForImageData:(NSData*)data sourceURL:(NSURL*)sourceURL
{
    if ([sourceURL.scheme isEqualToString:@"data"]) {
        NSString* string = sourceURL.absoluteString;
        NSRange separator = [string rangeOfString:@";"];
        if (separator.location == NSNotFound) {
            separator = [string rangeOfString:@","];
        }
        if (separator.location != NSNotFound && separator.location > 5) {
            NSString* mimeType = [string substringWithRange:NSMakeRange(5, separator.location - 5)];
            if ([mimeType hasPrefix:@"image/"]) {
                return mimeType;
            }
        }
    }

    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (source == NULL) {
        return nil;
    }
    CFStringRef typeIdentifier = CGImageSourceGetType(source);
    NSString* mimeType = nil;
    if (typeIdentifier != NULL) {
        UTType* type = [UTType typeWithIdentifier:(__bridge NSString*)typeIdentifier];
        mimeType = type.preferredMIMEType;
    }
    CFRelease(source);
    return mimeType;
}

CGSize const IJSVG_SIZE_INFINITE = (CGSize) { .width = CGFLOAT_MAX, .height = CGFLOAT_MAX };

CGSize const IJSVG_SIZE_INTRINSIC = (CGSize) { .width = -1.23f, .height = -1.23f };

// This is based on what the browsers do, 300 x 150, this produces a 2:1 scale
// if the viewBox or intrinisic sized needs to be inferred where there are no
// measurements given from the SVG.
CGSize const IJSVG_SIZE_DEFAULT_CLIENT = (CGSize) { .width = 300, .height = 150 };

BOOL IJSVGIsValidContextSize(CGSize size)
{
    return size.width >= 1.f && size.height >= 1.f;
}

CGColorSpaceRef IJSVGDeviceGrayColorSpace(void)
{
    static CGColorSpaceRef colorSpace = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colorSpace = CGColorSpaceCreateDeviceGray();
    });
    return colorSpace;
}

CGColorSpaceRef IJSVGDeviceRGBColorSpace(void)
{
    static CGColorSpaceRef colorSpace = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colorSpace = CGColorSpaceCreateDeviceRGB();
    });
    return colorSpace;
}

BOOL IJSVGCharBufferIsHEX(char* buffer)
{
    char c;
    while ((c = *buffer++)) {
        BOOL flag = ((c == '#') || (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'));
        if (flag == NO) {
            return NO;
        }
    }
    return YES;
}

inline BOOL IJSVGCharBufferHasPrefix(char* str, char* pre)
{
    return strncmp(pre, str, strlen(pre)) == 0;
}

inline BOOL IJSVGCharBufferHasSuffix(char* s1, char* s2)
{
    size_t slen = strlen(s1);
    size_t tlen = strlen(s2);
    if (tlen > slen) {
        return NO;
    }
    return strcmp(s1 + slen - tlen, s2) == 0;
}

char* IJSVGTimmedCharBufferCreate(const char* buffer)
{
    unsigned long start = 0;
    unsigned long length = strlen(buffer);
    while (length > 0 && isspace(buffer[length - 1])) {
        length--;
    }
    while (start < length && isspace(buffer[start])) {
        start++;
    }
    unsigned long size = length - start;
    char* chars = (char*)malloc(sizeof(char) * (size + 1));
    memcpy(chars, &buffer[start], size);
    chars[size] = '\0';
    return chars;
}

void IJSVGTrimCharBuffer(char* buffer)
{
    char* ptr = buffer;
    unsigned long length = strlen(ptr);
    while (length - 1 > 0 && isspace(ptr[length - 1])) {
        ptr[--length] = '\0';
    }
    while (*ptr && isspace(*ptr)) {
        ++ptr;
        --length;
    }
    memmove(buffer, ptr, length + 1);
}

inline char IJSVGCharToLower(char c)
{
    if (c >= 'A' && c <= 'Z') {
        return c - ('A' - 'a');
    }
    return c;
}

BOOL IJSVGCharBufferCaseInsensitiveCompare(const char* str1, const char* str2)
{
    if (str1 == str2) {
        return YES;
    }

    const char* p1 = str1;
    const char* p2 = str2;
    int result = 0;

    while ((result = IJSVGCharToLower(*p1) - IJSVGCharToLower(*p2++)) == 0) {
        if (*p1++ == '\0') {
            break;
        }
    }
    return result == 0;
}

inline BOOL IJSVGCharBufferCompare(const char* str1, const char* str2)
{
    if (str1[0] != str2[0]) {
        return NO;
    }
    return strcmp(str1, str2) == 0;
}

inline void IJSVGCharBufferToLower(char* buffer)
{
    for (char* p = buffer; *p; p++) {
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
    return (IJSVGFloatingPointOptions) { .round = round, .precision = precision };
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
    // %g emits integers below one million without an exponent. These values
    // occur frequently in default geometry and filter parameters.
    if (f == 0.f) {
        return signbit(f) ? @"-0" : @"0";
    }
    if (f == 1.f) {
        return @"1";
    }
    if (f > -1000000.f && f < 1000000.f) {
        int integer = (int)f;
        if ((CGFloat)integer == f) {
            char digits[8];
            char* end = digits + sizeof(digits);
            char* cursor = end;
            unsigned int magnitude = integer < 0 ? (unsigned int)-integer : (unsigned int)integer;
            do {
                *--cursor = (char)('0' + magnitude % 10);
                magnitude /= 10;
            } while (magnitude != 0);
            if (integer < 0) {
                *--cursor = '-';
            }
            return [[NSString alloc] initWithBytes:cursor length:(NSUInteger)(end - cursor) encoding:NSASCIIStringEncoding];
        }
    }
    char buffer[64];
    int length = snprintf(buffer, sizeof(buffer), "%g", f);

    // Keep the Foundation fallback for errors or a numeric locale other than C.
    if (length < 0 || length >= sizeof(buffer) || strchr(buffer, ',') != NULL) {
        return IJSVGShortenFloatString([NSString stringWithFormat:@"%g", f]);
    }
    const char* output = buffer;
    if (buffer[0] == '-' && buffer[1] == '0' && strchr(buffer, '.') != NULL) {
        buffer[1] = '-';
        output++;
    } else if (buffer[0] == '0' && buffer[1] == '.') {
        output++;
    }
    return [NSString stringWithUTF8String:output];
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
    // Format both coordinates in one buffer, avoiding two temporary NSStrings
    // and the object formatting machinery in Foundation for every polygon vertex.
    char buffer[128];
    int length = snprintf(buffer, sizeof(buffer), "%g %g", point.x, point.y);
    if (length < 0 || length >= sizeof(buffer) || strchr(buffer, ',') != NULL) {
        return [NSString stringWithFormat:@"%@ %@", IJSVGShortFloatString(point.x), IJSVGShortFloatString(point.y)];
    }
    char* output = buffer;
    for (const char* input = buffer; *input != 0;) {
        if (*input == '-') {
            *output++ = *input++;
        }
        if (input[0] == '0' && input[1] == '.') {
            input++;
        }
        while (*input != 0 && *input != ' ') {
            *output++ = *input++;
        }
        if (*input == ' ') {
            *output++ = *input++;
        }
    }
    return [[NSString alloc] initWithBytes:buffer length:(NSUInteger)(output - buffer) encoding:NSUTF8StringEncoding];
};

BOOL IJSVGIsLegalCommandCharacter(unichar aChar)
{
    if ((aChar | ('M' ^ 'm')) == 'm' || (aChar | ('Z' ^ 'z')) == 'z' || (aChar | ('C' ^ 'c')) == 'c' || (aChar | ('L' ^ 'l')) == 'l' || (aChar | ('S' ^ 's')) == 's' || (aChar | ('Q' ^ 'q')) == 'q' || (aChar | ('H' ^ 'h')) == 'h' || (aChar | ('V' ^ 'v')) == 'v' || (aChar | ('T' ^ 't')) == 't' || (aChar | ('A' ^ 'a')) == 'a') {
        return YES;
    }
    return NO;
}

void IJSVGPathGetLastQuadraticCommandPointEnumerationCallback(void* info, const CGPathElement* element)
{
    // this will just iterate over the path and keep changing the point
    // when we come across a quad curve, we cant break when we find one as we
    // dont know when the last one is.
    CGPoint* point = (CGPoint*)info;
    if (element->type == kCGPathElementAddQuadCurveToPoint) {
        CGPoint curvePoint = element->points[0];
        point->x = curvePoint.x;
        point->y = curvePoint.y;
    }
}

CGPoint IJSVGPathGetLastQuadraticCommandPoint(CGPathRef path)
{
    CGPoint point = CGPointZero;
    CGPathApply(path, &point, IJSVGPathGetLastQuadraticCommandPointEnumerationCallback);
    return point;
}

CGFloat IJSVGAngle(CGPoint a, CGPoint b)
{
    return [IJSVGUtils angleBetweenPointA:a pointb:b];
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

NSString* IJSVGCSSURLIdentifier(const IJSVGCSSComponents* components, const IJSVGCSSComponent* component, BOOL requireFragment)
{
    if (component->kind != IJSVGCSSComponentFunction || component->function != IJSVGCSSFunctionURL) {
        return nil;
    }
    const char* start = components->bytes + component->argumentOffset;
    const char* end = start + component->argumentLength;
    while (start < end && isspace((unsigned char)*start)) {
        start++;
    }
    while (end > start && isspace((unsigned char)end[-1])) {
        end--;
    }
    char quote = 0;
    if (end > start && (*start == '\'' || *start == '"')) {
        quote = *start++;
        end--;
    }
    if (start == end || (requireFragment && (*start != '#' || end - start < 2))) {
        return nil;
    }
    if (*start == '#') {
        start++;
    }
    if (requireFragment) {
        for (const char* cursor = start; cursor < end; cursor++) {
            unsigned char character = (unsigned char)*cursor;
            if (character < ' ' || character == '\x7f' || character == '\\' || (quote != 0 && character == quote) || (quote == 0 && (isspace(character) || character == '(' || character == ')' || character == '\'' || character == '"'))) {
                return nil;
            }
        }
    }
    return [[NSString alloc] initWithBytes:start length:end - start encoding:NSUTF8StringEncoding];
}

NSString* IJSVGDefURLFromBytes(const char* bytes, NSUInteger length)
{
    if (bytes == NULL || length == 0) {
        return nil;
    }
    IJSVGStringBytes source = { bytes, length };
    if (source.length != 0 && source.bytes[0] == '#') {
        return nil;
    }

    // Simple fragment URLs need no CSS component allocation.
    if (source.length > 6 && memcmp(source.bytes, "url(#", 5) == 0 && source.bytes[source.length - 1] == ')') {
        BOOL simple = YES;
        for (NSUInteger index = 5; index < source.length - 1; index++) {
            unsigned char character = source.bytes[index];
            if (!((character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z') || (character >= '0' && character <= '9') || character == '_' || character == '-' || character == '.')) {
                simple = NO;
                break;
            }
        }
        if (simple) {
            return [[NSString alloc] initWithBytes:source.bytes + 5 length:source.length - 6 encoding:NSUTF8StringEncoding];
        }
    }
    IJSVGCSSComponents components;
    BOOL valid = IJSVGCSSComponentsCreateWithOptions(source.bytes, source.length, IJSVGCSSParserOptionLeadingURL, &components);
    NSString* identifier = valid && components.count != 0 ? IJSVGCSSURLIdentifier(&components, components.values, NO) : nil;
    IJSVGCSSComponentsRelease(&components);
    return identifier;
}

+ (NSString* _Nullable)defURL:(NSString*)string
{
    IJSVGStringBytes source = IJSVGStringGetBytes(string);
    return IJSVGDefURLFromBytes(source.bytes, source.length);
}

+ (NSArray<NSString*>*)defURLs:(NSString*)string
{
    IJSVGStringBytes source = IJSVGStringGetBytes(string);
    IJSVGCSSComponents components;
    BOOL valid = IJSVGCSSComponentsCreateWithOptions(source.bytes, source.length, IJSVGCSSParserOptionLeadingURL, &components);
    if (!valid || components.count == 0) {
        IJSVGCSSComponentsRelease(&components);
        return @[];
    }
    NSMutableArray<NSString*>* identifiers = [[NSMutableArray alloc] initWithCapacity:components.count];
    for (NSUInteger index = 0; index < components.count;) {
        const IJSVGCSSComponent* component = components.values + index;
        NSString* identifier = IJSVGCSSURLIdentifier(&components, component, YES);
        if (identifier == nil) {
            valid = NO;
            break;
        }
        [identifiers addObject:identifier];
        index = component->next;
    }
    IJSVGCSSComponentsRelease(&components);
    return valid ? identifiers : @[];
}

+ (IJSVGMarkerUnits)markerUnitsForString:(NSString*)string
{
    if ([string isEqualToString:IJSVGStringUserSpaceOnUse]) {
        return IJSVGMarkerUnitsUserSpaceOnUse;
    }
    return IJSVGMarkerUnitsStrokeWidth;
}

IJSVGMarkerOrientType IJSVGMarkerOrientTypeFromString(NSString* string)
{
    if ([string isEqualToString:IJSVGStringAuto]) {
        return IJSVGMarkerOrientTypeAuto;
    }
    if ([string isEqualToString:IJSVGStringAutoStartReverse]) {
        return IJSVGMarkerOrientTypeAutoStartReverse;
    }
    return IJSVGMarkerOrientTypeAngle;
}

IJSVGContextPaint IJSVGContextPaintFromString(NSString* string)
{
    if ([string isEqualToString:IJSVGStringContextFill]) {
        return IJSVGContextPaintFill;
    }
    if ([string isEqualToString:IJSVGStringContextStroke]) {
        return IJSVGContextPaintStroke;
    }
    return IJSVGContextPaintNone;
}

static NSString* IJSVGNormalizeUnicodeKeyword(NSString* string, BOOL trim)
{
    const unsigned char* bytes = (const unsigned char*)string.UTF8String;
    if (bytes != NULL) {
        for (; *bytes != 0; bytes++) {
            if (*bytes >= 128) {
                NSString* normalized = string.lowercaseString;
                return trim ? [normalized stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : normalized;
            }
        }
    }
    return string;
}

CGFloat IJSVGAngleFromString(NSString* string)
{
    __attribute__((objc_precise_lifetime)) NSString* owner = string;
    const unsigned char* characters = (const unsigned char*)owner.UTF8String;
    if (characters == NULL) {
        return 0;
    }
    for (; *characters != 0; characters++) {
        if (*characters >= 128) {
            owner = [owner stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            break;
        }
    }
    IJSVGStringBytes source = IJSVGStringGetBytes(owner);
    if (source.bytes == NULL || memchr(source.bytes, 0, source.length) != NULL) {
        return 0;
    }
    char* number = IJSVGTimmedCharBufferCreate(source.bytes);
    NSUInteger length = strlen(number);
    CGFloat multiplier = 1;
    if (IJSVGCharBufferHasSuffix(number, "grad")) {
        length -= 4;
        multiplier = .9;
    } else if (IJSVGCharBufferHasSuffix(number, "rad")) {
        length -= 3;
        multiplier = 180 / M_PI;
    } else if (IJSVGCharBufferHasSuffix(number, "deg")) {
        length -= 3;
    }
    __block NSUInteger count = 0;
    __block CGFloat angle = 0;
    BOOL valid = IJSVGEnumerateNumbersFromBytes(number, length, ^(CGFloat value) {
        angle = value * multiplier;
        count++;
    });
    free(number);
    return valid && count == 1 && isfinite(angle) ? angle : 0;
}

IJSVGVectorEffect IJSVGVectorEffectFromString(NSString* string)
{
    __attribute__((objc_precise_lifetime)) NSString* owner = IJSVGNormalizeUnicodeKeyword(string, YES);
    IJSVGStringBytes source = IJSVGStringGetBytes(owner);
    if (source.bytes == NULL || memchr(source.bytes, 0, source.length) != NULL) {
        return IJSVGVectorEffectNone;
    }
    char* keyword = IJSVGTimmedCharBufferCreate(source.bytes);
    IJSVGVectorEffect effect = IJSVGVectorEffectNone;
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "non-scaling-stroke")) {
        effect = IJSVGVectorEffectNonScalingStroke;
    } else if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "inherit")) {
        effect = IJSVGVectorEffectInherit;
    }
    free(keyword);
    return effect;
}

IJSVGWindingRule IJSVGWindingRuleFromString(NSString* string)
{
    if ([string isEqualToString:IJSVGStringEvenOdd]) {
        return IJSVGWindingRuleEvenOdd;
    }
    if ([string isEqualToString:IJSVGStringInherit]) {
        return IJSVGWindingRuleInherit;
    }
    return IJSVGWindingRuleNonZero;
}

/// Copies a short keyword candidate into a buffer of UTF16 code units.
/// Returns zero when the string is missing or longer than the buffer.
static NSUInteger IJSVGCopyShortKeyword(NSString* string, unichar buffer[8])
{
    NSUInteger length = string.length;
    if (length == 0 || length > 8) {
        return 0;
    }
    [string getCharacters:buffer range:NSMakeRange(0, length)];
    return length;
}

/// Compares copied code units with an ASCII keyword, matching the exact
/// comparison of isEqualToString.
static BOOL IJSVGShortKeywordEquals(const unichar* buffer, NSUInteger length, const char* keyword)
{
    for (NSUInteger index = 0; index < length; index++) {
        if (keyword[index] == '\0' || buffer[index] != (unichar)keyword[index]) {
            return NO;
        }
    }
    return keyword[length] == '\0';
}

/// Resolves stroke line join keywords. Universal stylesheet rules apply this to
/// every element, so it avoids object comparisons for each candidate keyword.
IJSVGLineJoinStyle IJSVGLineJoinStyleFromString(NSString* string)
{
    unichar buffer[8];
    NSUInteger length = IJSVGCopyShortKeyword(string, buffer);
    if (IJSVGShortKeywordEquals(buffer, length, "miter")) {
        return IJSVGLineJoinStyleMiter;
    }
    if (IJSVGShortKeywordEquals(buffer, length, "round")) {
        return IJSVGLineJoinStyleRound;
    }
    if (IJSVGShortKeywordEquals(buffer, length, "bevel")) {
        return IJSVGLineJoinStyleBevel;
    }
    if (IJSVGShortKeywordEquals(buffer, length, "inherit")) {
        return IJSVGLineJoinStyleInherit;
    }
    return IJSVGLineJoinStyleMiter;
}

/// Resolves stroke line cap keywords without object comparisons.
IJSVGLineCapStyle IJSVGLineCapStyleFromString(NSString* string)
{
    unichar buffer[8];
    NSUInteger length = IJSVGCopyShortKeyword(string, buffer);
    if (IJSVGShortKeywordEquals(buffer, length, "butt")) {
        return IJSVGLineCapStyleButt;
    }
    if (IJSVGShortKeywordEquals(buffer, length, "square")) {
        return IJSVGLineCapStyleSquare;
    }
    if (IJSVGShortKeywordEquals(buffer, length, "round")) {
        return IJSVGLineCapStyleRound;
    }
    if (IJSVGShortKeywordEquals(buffer, length, "inherit")) {
        return IJSVGLineCapStyleInherit;
    }
    return IJSVGLineCapStyleButt;
}

+ (IJSVGLineCapStyle)lineCapStyleForCGLineCap:(CGLineCap)lineCap
{
    switch (lineCap) {
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
    switch (lineJoin) {
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

IJSVGUnitType IJSVGUnitTypeFromString(NSString* string)
{
    if ([string isEqualToString:IJSVGStringUserSpaceOnUse]) {
        return IJSVGUnitUserSpaceOnUse;
    }
    return IJSVGUnitObjectBoundingBox;
}

IJSVGBlendMode IJSVGBlendModeFromString(NSString* string)
{
    __attribute__((objc_precise_lifetime)) NSString* owner = IJSVGNormalizeUnicodeKeyword(string, NO);
    IJSVGStringBytes source = IJSVGStringGetBytes(owner);
    if (source.bytes == NULL || memchr(source.bytes, 0, source.length) != NULL) {
        return IJSVGBlendModeNormal;
    }
    const char* keyword = source.bytes;
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "normal")) {
        return IJSVGBlendModeNormal;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "multiply")) {
        return IJSVGBlendModeMultiply;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "screen")) {
        return IJSVGBlendModeScreen;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "overlay")) {
        return IJSVGBlendModeOverlay;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "darken")) {
        return IJSVGBlendModeDarken;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "lighten")) {
        return IJSVGBlendModeLighten;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "color-dodge")) {
        return IJSVGBlendModeColorDodge;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "color-burn")) {
        return IJSVGBlendModeColorBurn;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "hard-light")) {
        return IJSVGBlendModeHardLight;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "soft-light")) {
        return IJSVGBlendModeSoftLight;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "difference")) {
        return IJSVGBlendModeDifference;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "exclusion")) {
        return IJSVGBlendModeExclusion;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "hue")) {
        return IJSVGBlendModeHue;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "saturation")) {
        return IJSVGBlendModeSaturation;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "color")) {
        return IJSVGBlendModeColor;
    }
    if (IJSVGCharBufferCaseInsensitiveCompare(keyword, "luminosity")) {
        return IJSVGBlendModeLuminosity;
    }
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

+ (CGFloat*)commandParameters:(NSString*)command count:(NSInteger*)count
{
    return [self.class scanFloatsFromString:command size:count];
}

+ (CGFloat*)commandParameters:(NSString*)command dataStream:(IJSVGPathDataStream*)dataStream count:(NSInteger*)count
{
    return [self.class scanFloatsFromCString:command.UTF8String dataStream:dataStream size:count];
}

typedef struct {
    CGFloat* values;
    NSUInteger count;
    NSUInteger capacity;
    CGFloat storage[32];
} IJSVGNumberList;

static BOOL IJSVGNumberListAppend(IJSVGNumberList* list, CGFloat value)
{
    if (list->count == list->capacity) {
        NSUInteger capacity = list->capacity * 2;
        CGFloat* values = malloc(capacity * sizeof(*values));
        if (values == NULL) {
            return NO;
        }
        memcpy(values, list->values, list->count * sizeof(*values));
        if (list->values != list->storage) {
            free(list->values);
        }
        list->values = values;
        list->capacity = capacity;
    }
    list->values[list->count++] = value;
    return YES;
}

static const char* IJSVGNumberListSkipWhitespace(const char* cursor, const char* end)
{
    while (cursor < end && (*cursor == ' ' || *cursor == '\t' || *cursor == '\r' || *cursor == '\n')) {
        cursor++;
    }
    return cursor;
}

static BOOL IJSVGNumberListParse(const char* cursor, const char* end, IJSVGNumberList* list)
{
    cursor = IJSVGNumberListSkipWhitespace(cursor, end);
    for (;;) {
        CGFloat value;
        if (!IJSVGParseLengthNumberInRange(&cursor, end, YES, &value) || !IJSVGNumberListAppend(list, value)) {
            return NO;
        }
        const char* numberEnd = cursor;
        cursor = IJSVGNumberListSkipWhitespace(cursor, end);
        if (cursor == end) {
            return YES;
        }
        if (*cursor == ',') {
            cursor = IJSVGNumberListSkipWhitespace(cursor + 1, end);
        } else if (cursor == numberEnd) {
            return NO;
        }
    }
}

BOOL IJSVGEnumerateNumbersFromBytes(const char* bytes, NSUInteger length, void (^handler)(CGFloat))
{
    if (bytes == NULL || length == 0 || memchr(bytes, 0, length) != NULL) {
        return NO;
    }
    IJSVGNumberList list;
    list.values = list.storage;
    list.count = 0;
    list.capacity = sizeof(list.storage) / sizeof(*list.storage);
    BOOL valid = IJSVGNumberListParse(bytes, bytes + length, &list);
    if (valid) {
        for (NSUInteger index = 0; index < list.count; index++) {
            handler(list.values[index]);
        }
    }
    if (list.values != list.storage) {
        free(list.values);
    }
    return valid;
}

BOOL IJSVGEnumerateNumbersFromCString(const char* string, void (^handler)(CGFloat))
{
    return IJSVGEnumerateNumbersFromBytes(string, string == NULL ? 0 : strlen(string), handler);
}

BOOL IJSVGEnumerateNumbers(NSString* string, void (^handler)(CGFloat))
{
    __attribute__((objc_precise_lifetime)) NSString* owner = string;
    IJSVGStringBytes source = IJSVGStringGetBytes(owner);
    return IJSVGEnumerateNumbersFromBytes(source.bytes, source.length, handler);
}

+ (NSArray<NSNumber*>*)numbersFromString:(NSString*)string
{
    NSMutableArray<NSNumber*>* numbers = [[NSMutableArray alloc] init];
    BOOL valid = IJSVGEnumerateNumbers(string, ^(CGFloat value) {
        [numbers addObject:@(value)];
    });
    return valid ? numbers : @[];
}

+ (CGFloat*)scanFloatsFromString:(NSString*)string size:(NSInteger*)length
{
    return [self.class scanFloatsFromCString:string.UTF8String size:length];
}

+ (CGFloat*)scanFloatsFromCString:(const char*)buffer size:(NSInteger*)length
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
    CGFloat* floats = [self.class scanFloatsFromCString:buffer dataStream:stream size:length];
    IJSVGPathDataStreamRelease(stream);
    return floats;
}

+ (CGFloat*)scanFloatsFromCString:(const char*)buffer dataStream:(IJSVGPathDataStream*)dataStream size:(NSInteger*)length
{
    return IJSVGParsePathDataStreamSequence(buffer, strlen(buffer), dataStream, NULL, 1, length);
}

+ (CGFloat*)scanFloatsFromCString:(const char*)buffer floatCount:(NSUInteger)floatCount charCount:(NSUInteger)charCount size:(NSInteger*)length
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreate(floatCount, charCount);
    CGFloat* floats = [self.class scanFloatsFromCString:buffer dataStream:stream size:length];
    IJSVGPathDataStreamRelease(stream);
    return floats;
}

+ (CGFloat*)parseViewBox:(NSString*)string
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreate(4, IJSVG_STREAM_CHAR_BLOCK_SIZE);
    const char* str = string.UTF8String;
    CGFloat* floats = IJSVGParsePathDataStreamSequence(str, strlen(str), stream, NULL, 1, NULL);
    IJSVGPathDataStreamRelease(stream);
    return floats;
}

+ (CGFloat)floatValue:(NSString*)string fallBackForPercent:(CGFloat)fallBack
{
    CGFloat val = [string floatValue];
    if ([string rangeOfString:@"%"].location != NSNotFound) {
        val = (fallBack * val) / 100;
    }
    return val;
}

+ (CGFloat)floatValue:(NSString*)string
{
    if ([string isEqualToString:IJSVGStringInherit]) {
        return IJSVGInheritedFloatValue;
    }
    return [string floatValue];
}

+ (CGFloat)angleBetweenPointA:(CGPoint)point1 pointb:(CGPoint)point2
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

@end

CGImageRef IJSVGCreateResizedCGImage(CGImageRef image, CGSize size)
{
    if (image == NULL || !isfinite(size.width) || !isfinite(size.height)
        || size.width < 1 || size.height < 1 || size.width > INT_MAX || size.height > INT_MAX) {
        return NULL;
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, (size_t)size.width, (size_t)size.height, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (context == NULL) {
        return NULL;
    }
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextDrawImage(context, (CGRect) { CGPointZero, size }, image);
    CGImageRef result = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return result;
}
