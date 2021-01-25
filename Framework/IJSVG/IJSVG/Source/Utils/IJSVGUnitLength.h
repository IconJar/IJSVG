//
//  IJSVGUnitLength.h
//  IJSVGExample
//
//  Created by Curtis Hard on 13/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
    BOOL round;
    int precision;
} IJSVGFloatingPointOptions;

typedef NS_ENUM(NSInteger, IJSVGUnitLengthType) {
    IJSVGUnitLengthTypeNumber,
    IJSVGUnitLengthTypePercentage,
    IJSVGUnitLengthTypeCM,
    IJSVGUnitLengthTypeMM,
    IJSVGUnitLengthTypeIN,
    IJSVGUnitLengthTypePT,
    IJSVGUnitLengthTypePC,
    IJSVGUnitLengthTypePX
};

typedef NS_ENUM(NSInteger, IJSVGUnitType) {
    IJSVGUnitUserSpaceOnUse,
    IJSVGUnitObjectBoundingBox,
    IJSVGUnitInherit
};

@interface IJSVGUnitLength : NSObject

@property (nonatomic, assign) IJSVGUnitLengthType type;
@property (nonatomic, assign) IJSVGUnitLengthType originalType;
@property (nonatomic, assign) CGFloat value;
@property (nonatomic, assign) BOOL inherit;

+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number;
+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number
                             type:(IJSVGUnitLengthType)type;
+ (IJSVGUnitLength*)unitWithPercentageFloat:(CGFloat)number;
+ (IJSVGUnitLength*)unitWithString:(NSString*)string;
+ (IJSVGUnitLength*)unitWithPercentageString:(NSString*)string;

+ (IJSVGUnitLength*)unitWithString:(NSString*)string
                      fromUnitType:(IJSVGUnitType)units;

- (CGFloat)valueAsPercentage;
- (CGFloat)computeValue:(CGFloat)anotherValue;
- (NSString*)stringValue;
- (NSString*)stringValueWithFloatingPointOptions:(IJSVGFloatingPointOptions)options;

@end
