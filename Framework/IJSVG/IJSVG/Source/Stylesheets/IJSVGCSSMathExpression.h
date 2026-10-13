//
//  IJSVGCSSMathExpression.h
//  IJSVG
//
//  Created by Curtis Hard on 12/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVGCSSParser.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    CGFloat percentage;
    CGFloat fontSize;
    CGFloat xHeight;
} IJSVGCSSCalculationContext;

BOOL IJSVGCSSMathExpressionIsValid(const IJSVGCSSComponents* components, NSUInteger index);

typedef struct {
    CGFloat value;
    BOOL percentage;
} IJSVGCSSNumericValue;

BOOL IJSVGCSSMathExpressionEvaluateNumber(const IJSVGCSSComponents* components, NSUInteger index, CGFloat percentage, IJSVGCSSNumericValue* result);

// Owns one immutable C arena. Parsing, type checking, simplification and
// evaluation use C nodes. Objective C provides ownership and the API boundary.
@interface IJSVGCSSMathExpression : NSObject

@property (nonatomic, readonly) NSInteger lengthExponent;
@property (nonatomic, readonly) BOOL usesPercentage;
@property (nonatomic, readonly) BOOL usesFontMetrics;
@property (nonatomic, readonly) BOOL usesLength;
@property (nonatomic, readonly, copy) NSString* stringValue;

+ (nullable instancetype)expressionWithComponents:(const IJSVGCSSComponents*)components atIndex:(NSUInteger)index;
- (CGFloat)evaluate:(IJSVGCSSCalculationContext)context;
- (IJSVGCSSMathExpression*)expressionByResolvingFontSize:(CGFloat)fontSize xHeight:(CGFloat)xHeight;
- (IJSVGCSSMathExpression*)expressionByScalingLengths:(CGFloat)scale;

@end

NS_ASSUME_NONNULL_END
