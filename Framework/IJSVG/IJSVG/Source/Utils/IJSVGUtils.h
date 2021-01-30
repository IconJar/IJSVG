//
//  IJSVGUtils.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommand.h"
#import "IJSVGGradientUnitLength.h"
#import "IJSVGStringAdditions.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGUtils : NSObject

CGFloat magnitude(CGPoint point);
CGFloat ratio(CGPoint a, CGPoint b);
CGFloat angle(CGPoint a, CGPoint b);
CGFloat radians_to_degrees(CGFloat radians);
CGFloat degrees_to_radians(CGFloat degrees);

BOOL IJSVGCharBufferHasSuffix(char* s1, char* s2);
void IJSVGTrimCharBuffer(char* buffer);

BOOL IJSVGIsCommonHTMLElementName(NSString* str);
NSArray* IJSVGCommonHTMLElementNames(void);

IJSVGFloatingPointOptions IJSVGFloatingPointOptionsDefault(void);
IJSVGFloatingPointOptions IJSVGFloatingPointOptionsMake(BOOL round, int precision);

NSString* IJSVGCompressFloatParameterArray(NSArray<NSString*>* stringToCompress);
NSString* IJSVGShortFloatStringWithOptions(CGFloat f, IJSVGFloatingPointOptions options);
NSString* IJSVGShortenFloatString(NSString* string);
NSString* IJSVGPointToCommandString(CGPoint point);
NSString* IJSVGShortFloatString(CGFloat f);
NSString* IJSVGShortFloatStringWithPrecision(CGFloat f, NSInteger precision);

BOOL IJSVGIsLegalCommandCharacter(unichar aChar);
BOOL IJSVGIsSVGLayer(CALayer* layer);
+ (IJSVGCommandType)typeForCommandChar:(char)commandChar;
+ (CGFloat*)commandParameters:(NSString*)command
                        count:(NSInteger*)count;
+ (CGFloat*)parseViewBox:(NSString*)string;
+ (IJSVGWindingRule)windingRuleForString:(NSString*)string;
+ (IJSVGLineJoinStyle)lineJoinStyleForString:(NSString*)string;
+ (IJSVGLineCapStyle)lineCapStyleForString:(NSString*)string;
+ (IJSVGUnitType)unitTypeForString:(NSString*)string;
+ (IJSVGBlendMode)blendModeForString:(NSString*)string;
+ (NSString* _Nullable)mixBlendingModeForBlendMode:(IJSVGBlendMode)blendMode;
+ (NSRange)rangeOfParentheses:(NSString*)string;

+ (void)logParameters:(CGFloat*)param
                count:(NSInteger)count;
+ (CGFloat)floatValue:(NSString*)string;
+ (CGFloat)angleBetweenPointA:(NSPoint)point
                       pointb:(NSPoint)point;
+ (NSString* _Nullable)defURL:(NSString*)string;
+ (CGFloat)floatValue:(NSString*)string
    fallBackForPercent:(CGFloat)viewBox;
+ (CGFloat*)scanFloatsFromString:(NSString*)string
                            size:(NSInteger*)length;
+ (CGFloat*)scanFloatsFromCString:(const char*)buffer
                             size:(NSInteger*)length;
+ (CGFloat*)scanFloatsFromCString:(const char*)buffer
                       floatCount:(NSUInteger)floatCount
                        charCount:(NSUInteger)charCount
                             size:(NSInteger*)length;
+ (IJSVGFontTraits)fontStyleStringForString:(NSString*)string;
+ (IJSVGFontTraits)fontWeightTraitForString:(NSString*)string
                                     weight:(CGFloat*)weight;

+ (CGPathRef)newFlippedCGPath:(CGPathRef)path;
@end
NS_ASSUME_NONNULL_END
