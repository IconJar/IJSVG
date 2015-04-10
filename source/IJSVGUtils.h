//
//  IJSVGUtils.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGCommand.h"

@interface IJSVGUtils : NSObject

+ (IJSVGCommandType)typeForCommandString:(NSString *)string;
+ (NSRegularExpression *)commandNameRegex;
+ (NSRegularExpression *)commandRegex;
+ (CGFloat *)commandParameters:(NSString *)command
                         count:(NSInteger *)count;
+ (CGFloat *)parseViewBox:(NSString *)string;
+ (IJSVGWindingRule)windingRuleForString:(NSString *)string;
+ (IJSVGLineCapStyle)lineCapStyleForString:(NSString *)string;
+ (NSString *)cleanCommandString:(NSString *)string;
+ (void)logParameters:(CGFloat *)param
                count:(NSInteger)count;
+ (CGFloat)floatValue:(NSString *)string;
+ (CGFloat)angleBetweenPointA:(NSPoint)point
                       pointb:(NSPoint)point;
+ (NSString *)defURL:(NSString *)string;
+ (CGFloat)floatValue:(NSString *)string
   fallBackForPercent:(CGFloat)viewBox;

@end
