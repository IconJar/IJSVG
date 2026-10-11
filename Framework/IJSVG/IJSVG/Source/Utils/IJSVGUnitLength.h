//
//  IJSVGUnitLength.h
//  IJSVG
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
    IJSVGUnitLengthTypePX,
    IJSVGUnitLengthTypeEM,
    IJSVGUnitLengthTypeEX,
    IJSVGUnitLengthTypeAuto
};

IJSVGUnitLengthType IJSVGUnitLengthTypeForCString(const char* chars);

typedef NS_ENUM(NSInteger, IJSVGUnitType) {
    IJSVGUnitUserSpaceOnUse,
    IJSVGUnitObjectBoundingBox,
    IJSVGUnitInherit
};

@interface IJSVGUnitLength: NSObject <NSCopying>

@property (nonatomic, readonly) IJSVGUnitLengthType type;
@property (nonatomic, readonly) IJSVGUnitLengthType originalType;
@property (nonatomic, readonly) CGFloat value;
@property (nonatomic, readonly) BOOL inherit;
@property (nonatomic, readonly) BOOL isRelativeUnit;

+ (CGFloat)convertUnitValue:(CGFloat)unit
   toBaseFromUnitLengthType:(IJSVGUnitLengthType)type;

// Immutable values may be shared. Replace the length on a node to change it.
+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number
                             type:(IJSVGUnitLengthType)type
                     originalType:(IJSVGUnitLengthType)originalType
                          inherit:(BOOL)inherit;

// Replacement helpers preserve unit metadata. Setting a value makes it explicit.
- (IJSVGUnitLength*)lengthWithValue:(CGFloat)value;
- (IJSVGUnitLength*)lengthWithInheritance:(BOOL)inherit;
- (IJSVGUnitLength*)lengthBySettingType:(IJSVGUnitLengthType)type;

+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number;
+ (IJSVGUnitLength*)unitWithFloat:(CGFloat)number
                             type:(IJSVGUnitLengthType)type;
+ (IJSVGUnitLength*)unitWithPercentageFloat:(CGFloat)number;
+ (IJSVGUnitLength*)unitWithString:(NSString*)string;
+ (IJSVGUnitLength*)unitWithPercentageString:(NSString*)string;

+ (IJSVGUnitLength*)unitWithString:(NSString*)string
                      fromUnitType:(IJSVGUnitType)units;

- (IJSVGUnitLength*)lengthWithUnitType:(IJSVGUnitLengthType)type;
- (IJSVGUnitLength*)lengthByMatchingPercentage;
- (CGFloat)valueAsPercentage;
- (CGFloat)computeValue:(CGFloat)anotherValue;
// Supply font metrics when resolving em and ex values.
- (CGFloat)computeValue:(CGFloat)anotherValue
               fontSize:(CGFloat)fontSize
                xHeight:(CGFloat)xHeight;
- (NSString*)stringValue;
- (NSString*)stringValueWithFloatingPointOptions:(IJSVGFloatingPointOptions)options;

@end

// Shared immutable defaults, initialized when the framework loads. Do not reassign.
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGThreeUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGHalfPercentageUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGOnePercentageUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGNegativeTenPercentageUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGOneHundredTwentyPercentageUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGZeroBoundingBoxUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGAutoUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGInheritedAutoUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGDefaultViewportWidthUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGDefaultViewportHeightUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGZeroUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGOneUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGFourUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGInheritedZeroUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGInheritedOneUnitLength;
FOUNDATION_EXPORT IJSVGUnitLength* IJSVGZeroPercentageUnitLength;
