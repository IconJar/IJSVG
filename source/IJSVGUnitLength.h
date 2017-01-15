//
//  IJSVGUnitLength.h
//  IJSVGExample
//
//  Created by Curtis Hard on 13/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, IJSVGUnitLengthType) {
    IJSVGUnitLengthTypeNumber,
    IJSVGUnitLengthTypePercentage
};

@interface IJSVGUnitLength : NSObject

@property (nonatomic, assign) IJSVGUnitLengthType type;
@property (nonatomic, assign) CGFloat value;
@property (nonatomic, assign) BOOL inherit;

+ (IJSVGUnitLength *)unitWithFloat:(CGFloat)number;
+ (IJSVGUnitLength *)unitWithFloat:(CGFloat)number
                              type:(IJSVGUnitLengthType)type;
+ (IJSVGUnitLength *)unitWithPercentageFloat:(CGFloat)number;
+ (IJSVGUnitLength *)unitWithString:(NSString *)string;
+ (IJSVGUnitLength *)unitWithPercentageString:(NSString *)string;

- (CGFloat)valueAsPercentage;
- (CGFloat)computeValue:(CGFloat)anotherValue;
- (NSString *)stringValue;

@end
