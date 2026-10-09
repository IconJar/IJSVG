//
//  IJSVGUtils.h
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGCommand.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVG/IJSVGColorNode.h>
#import <IJSVG/IJSVGGradientUnitLength.h>
#import <IJSVG/IJSVGStringAdditions.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGUtils : NSObject

CG_EXTERN const CGSize IJSVG_SIZE_INFINITE;
CG_EXTERN const CGSize IJSVG_SIZE_INTRINSIC;
CG_EXTERN const CGSize IJSVG_SIZE_DEFAULT_CLIENT;

CGFloat IJSVGMagnitude(CGPoint point);
CGFloat IJSVGRatio(CGPoint a, CGPoint b);
CGFloat IJSVGAngle(CGPoint a, CGPoint b);
CGFloat IJSVGRadiansToDegrees(CGFloat radians);
CGFloat IJSVGDegreesToRadians(CGFloat degrees);
BOOL IJSVGIsValidContextSize(CGSize size);

// These are expensive to create and are hit on every offscreen pass,
// so they are created lazily once and reused. The returned reference is owned
// by IJSVG, callers must _NOT_ release it.
CGColorSpaceRef IJSVGDeviceGrayColorSpace(void) CF_RETURNS_NOT_RETAINED;
CGColorSpaceRef IJSVGDeviceRGBColorSpace(void) CF_RETURNS_NOT_RETAINED;

char IJSVGCharToLower(char c);
BOOL IJSVGCharBufferCaseInsensitiveCompare(const char* str1, const char* str2);
BOOL IJSVGCharBufferCompare(const char* str1, const char* str2);
BOOL IJSVGCharBufferIsHEX(char* buffer);
BOOL IJSVGCharBufferHasPrefix(char* pre, char* str);
BOOL IJSVGCharBufferHasSuffix(char* s1, char* s2);
char* IJSVGTimmedCharBufferCreate(const char* buffer);
void IJSVGTrimCharBuffer(char* buffer);
void IJSVGCharBufferToLower(char* buffer);
size_t IJSVGCharBufferHash(char* buffer);
CGPoint IJSVGPathGetLastQuadraticCommandPoint(CGPathRef path);
CGAffineTransform IJSVGPathFlippingTransform(CGPathRef path);

IJSVGFloatingPointOptions IJSVGFloatingPointOptionsDefault(void);
IJSVGFloatingPointOptions IJSVGFloatingPointOptionsMake(BOOL round, int precision);

NSString* IJSVGCompressFloatParameterArray(NSArray<NSString*>* stringToCompress);
NSString* IJSVGShortFloatStringWithOptions(CGFloat f, IJSVGFloatingPointOptions options);
NSString* IJSVGShortenFloatString(NSString* string);
NSString* IJSVGPointToCommandString(CGPoint point);
NSString* IJSVGShortFloatString(CGFloat f);
NSString* IJSVGShortFloatStringWithPrecision(CGFloat f, NSInteger precision);

BOOL IJSVGIsLegalCommandCharacter(unichar aChar);
+ (IJSVGCommandType)typeForCommandChar:(char)commandChar;
+ (CGFloat*)commandParameters:(NSString*)command
                        count:(NSInteger*)count;
+ (CGFloat*)commandParameters:(NSString*)command
                   dataStream:(IJSVGPathDataStream*)dataStream
                        count:(NSInteger*)count;
+ (CGFloat*)parseViewBox:(NSString*)string;
+ (IJSVGWindingRule)windingRuleForString:(NSString*)string;
+ (IJSVGLineJoinStyle)lineJoinStyleForString:(NSString*)string;
+ (IJSVGLineCapStyle)lineCapStyleForString:(NSString*)string;
+ (IJSVGLineJoinStyle)lineJoinStyleForCGLineJoin:(CGLineJoin)lineJoin;
+ (IJSVGLineCapStyle)lineCapStyleForCGLineCap:(CGLineCap)lineCap;
+ (IJSVGUnitType)unitTypeForString:(NSString*)string;
+ (IJSVGMarkerUnits)markerUnitsForString:(NSString* _Nullable)string;
+ (IJSVGMarkerOrientType)markerOrientTypeForString:(NSString* _Nullable)string;
+ (IJSVGContextPaint)contextPaintForString:(NSString* _Nullable)string;
+ (CGFloat)angleForString:(NSString* _Nullable)string;
+ (IJSVGBlendMode)blendModeForString:(NSString*)string;
+ (NSString* _Nullable)mixBlendingModeForBlendMode:(IJSVGBlendMode)blendMode;
+ (NSString* _Nullable)MIMETypeForImageData:(NSData*)data
                                  sourceURL:(NSURL*)sourceURL;

+ (CGFloat)floatValue:(NSString*)string;
+ (CGFloat)angleBetweenPointA:(NSPoint)point
                       pointb:(NSPoint)point;
+ (NSString* _Nullable)defURL:(NSString*)string;
+ (NSArray<NSString*>*)defURLs:(NSString*)string;
+ (CGFloat)floatValue:(NSString*)string
   fallBackForPercent:(CGFloat)viewBox;

// Parses a complete SVG number list, malformed values, infinities or NaNs return an empty array.
+ (NSArray<NSNumber*>*)numbersFromString:(NSString*)string;
+ (CGFloat*)scanFloatsFromString:(NSString*)string
                            size:(NSInteger*)length;
+ (CGFloat*)scanFloatsFromCString:(const char*)buffer
                             size:(NSInteger*)length;
+ (CGFloat*)scanFloatsFromCString:(const char*)buffer
                       dataStream:(IJSVGPathDataStream*)dataStream
                             size:(NSInteger*)length;
+ (CGFloat*)scanFloatsFromCString:(const char*)buffer
                       floatCount:(NSUInteger)floatCount
                        charCount:(NSUInteger)charCount
                             size:(NSInteger*)length;
+ (CGPathRef)newFlippedCGPath:(CGPathRef)path CF_RETURNS_RETAINED NS_SWIFT_NAME(flippedPath(_:));

+ (CGLineJoin)CGLineJoinForJoinStyle:(IJSVGLineJoinStyle)joinStyle;
+ (CGLineCap)CGLineCapForCapStyle:(IJSVGLineCapStyle)capStyle;


+ (NSImage*)resizeImage:(NSImage*)anImage
                 toSize:(CGSize)size;

@end
NS_ASSUME_NONNULL_END
