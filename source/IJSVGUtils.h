//
//  IJSVGUtils.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <xlocale.h>
#import "IJSVGCommand.h"
#import "IJSVGGradientUnitLength.h"
#import "IJSVGStringAdditions.h"

@interface IJSVGUtils : NSObject

CGFloat magnitude(CGPoint point);
CGFloat ratio( CGPoint a, CGPoint b );
CGFloat angle( CGPoint a, CGPoint b );
CGFloat radians_to_degrees( CGFloat radians);
CGFloat degrees_to_radians( CGFloat degrees );

BOOL IJSVGIsCommonHTMLElementName(NSString * str);
NSArray * IJSVGCommonHTMLElementNames(void);

NSString * IJSVGShortFloatString(CGFloat f);
NSString * IJSVGShortFloatStringWithPrecision(CGFloat f, NSInteger precision);

BOOL IJSVGIsLegalCommandCharacter(unichar aChar);
BOOL IJSVGIsSVGLayer(CALayer * layer);
+ (IJSVGCommandType)typeForCommandString:(NSString *)string;
+ (CGFloat *)commandParameters:(NSString *)command
                         count:(NSInteger *)count;
+ (CGFloat *)parseViewBox:(NSString *)string;
+ (IJSVGWindingRule)windingRuleForString:(NSString *)string;
+ (IJSVGLineJoinStyle)lineJoinStyleForString:(NSString *)string;
+ (IJSVGLineCapStyle)lineCapStyleForString:(NSString *)string;
+ (IJSVGUnitType)unitTypeForString:(NSString *)string;
+ (IJSVGBlendMode)blendModeForString:(NSString *)string;
+ (NSString *)mixBlendingModeForBlendMode:(IJSVGBlendMode)blendMode;
+ (NSRange)rangeOfParentheses:(NSString *)string;

+ (void)logParameters:(CGFloat *)param
                count:(NSInteger)count;
+ (CGFloat)floatValue:(NSString *)string;
+ (CGFloat)angleBetweenPointA:(NSPoint)point
                       pointb:(NSPoint)point;
+ (NSString *)defURL:(NSString *)string;
+ (CGFloat)floatValue:(NSString *)string
   fallBackForPercent:(CGFloat)viewBox;
+ (CGFloat *)scanFloatsFromString:(NSString *)string
                             size:(NSInteger *)length;
+ (IJSVGFontTraits)fontStyleStringForString:(NSString *)string;
+ (IJSVGFontTraits)fontWeightTraitForString:(NSString *)string
                                     weight:(CGFloat *)weight;

+ (CGPathRef)newFlippedCGPath:(CGPathRef)path;
+ (CGPathRef)newCGPathFromBezierPath:(NSBezierPath *)bezPath;
@end
