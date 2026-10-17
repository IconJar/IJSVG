//
//  IJSVGCSSParser.h
//  IJSVG
//
//  Created by Curtis Hard on 12/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGUnitLength.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(uint8_t, IJSVGCSSWideKeyword) {
    IJSVGCSSWideKeywordUnknown,
    IJSVGCSSWideKeywordInherit,
    IJSVGCSSWideKeywordInitial,
    IJSVGCSSWideKeywordUnset,
    IJSVGCSSWideKeywordRevert,
    IJSVGCSSWideKeywordRevertLayer
};

IJSVGCSSWideKeyword IJSVGCSSWideKeywordFromString(NSString* _Nullable value);

typedef NS_ENUM(uint8_t, IJSVGCSSFunction) {
    IJSVGCSSFunctionUnknown,
    IJSVGCSSFunctionCalc,
    IJSVGCSSFunctionMin,
    IJSVGCSSFunctionMax,
    IJSVGCSSFunctionClamp,
    IJSVGCSSFunctionURL,
    IJSVGCSSFunctionPath,
    IJSVGCSSFunctionInset,
    IJSVGCSSFunctionRect,
    IJSVGCSSFunctionXYWH,
    IJSVGCSSFunctionPolygon,
    IJSVGCSSFunctionShape,
    IJSVGCSSFunctionRGB,
    IJSVGCSSFunctionRGBA,
    IJSVGCSSFunctionHSL,
    IJSVGCSSFunctionHSLA,
    IJSVGCSSFunctionOKLCH,
    IJSVGCSSFunctionMatrix,
    IJSVGCSSFunctionTranslate,
    IJSVGCSSFunctionTranslateX,
    IJSVGCSSFunctionTranslateY,
    IJSVGCSSFunctionScale,
    IJSVGCSSFunctionRotate,
    IJSVGCSSFunctionSkewX,
    IJSVGCSSFunctionSkewY,
    IJSVGCSSFunctionCircle,
    IJSVGCSSFunctionEllipse,
    IJSVGCSSFunctionVar,
    IJSVGCSSFunctionBrightness,
    IJSVGCSSFunctionContrast,
    IJSVGCSSFunctionGrayscale,
    IJSVGCSSFunctionHueRotate,
    IJSVGCSSFunctionInvert,
    IJSVGCSSFunctionOpacity,
    IJSVGCSSFunctionSaturate,
    IJSVGCSSFunctionSepia,
    IJSVGCSSFunctionBlur,
    IJSVGCSSFunctionDropShadow
};

typedef NS_ENUM(uint8_t, IJSVGCSSNumericKeyword) {
    IJSVGCSSNumericKeywordUnknown,
    IJSVGCSSNumericKeywordPi,
    IJSVGCSSNumericKeywordE,
    IJSVGCSSNumericKeywordInfinity,
    IJSVGCSSNumericKeywordNegativeInfinity,
    IJSVGCSSNumericKeywordNaN,
    IJSVGCSSNumericKeywordNone
};

typedef NS_ENUM(uint8_t, IJSVGCSSAngleUnit) {
    IJSVGCSSAngleUnitNone,
    IJSVGCSSAngleUnitDegrees,
    IJSVGCSSAngleUnitRadians,
    IJSVGCSSAngleUnitGradians,
    IJSVGCSSAngleUnitTurns
};

typedef NS_ENUM(char, IJSVGCSSSymbol) {
    IJSVGCSSSymbolNone = 0,
    IJSVGCSSSymbolAdd = '+',
    IJSVGCSSSymbolSubtract = '-',
    IJSVGCSSSymbolMultiply = '*',
    IJSVGCSSSymbolDivide = '/',
    IJSVGCSSSymbolComma = ',',
    IJSVGCSSSymbolParenthesis = '(',
    IJSVGCSSSymbolBracket = '[',
    IJSVGCSSSymbolBrace = '{'
};

// Classify ASCII names at the text boundary without case sensitivity.
IJSVGCSSFunction IJSVGCSSFunctionForName(const char* _Nullable name);

typedef NS_ENUM(uint8_t, IJSVGCSSComponentKind) {
    IJSVGCSSComponentNumber,
    IJSVGCSSComponentDimension,
    IJSVGCSSComponentPercentage,
    IJSVGCSSComponentIdentifier,
    IJSVGCSSComponentFunction,
    IJSVGCSSComponentBlock,
    IJSVGCSSComponentDelimiter,
    IJSVGCSSComponentString
};

// A flat, immutable component tree. Children immediately follow their parent.
// The next field is the index after the entire subtree. Names are classified
// once.
typedef struct {
    IJSVGCSSComponentKind kind;
    IJSVGCSSFunction function;
    IJSVGCSSNumericKeyword numericKeyword;
    IJSVGCSSSymbol symbol;
    IJSVGUnitLengthType unit;
    CGFloat number;
    NSUInteger next;
    BOOL precedingWhitespace;
    BOOL negativeNonzero;
    IJSVGCSSAngleUnit angleUnit;
    uint32_t offset;
    uint32_t length;
    uint32_t argumentOffset;
    uint32_t argumentLength;
} IJSVGCSSComponent;

enum {
    IJSVGCSSParserInlineCapacity = 32
};

// Keep common expressions in caller storage and grow only for larger trees.
// This owns its storage and must not be copied by value.
typedef struct IJSVGCSSComponents {
    IJSVGCSSComponent* _Nullable values;
    NSUInteger count;
    const char* _Nullable bytes;
    IJSVGCSSComponent inlineValues[IJSVGCSSParserInlineCapacity];
} IJSVGCSSComponents;

// The source is a borrowed UTF8 span. A NUL terminator is not required.
// Embedded NUL bytes are rejected. The caller releases
// the buffer, including on failure. The source must remain alive while
// accessing component source ranges. Limits: 64 nested blocks, 4096 components,
// 64 KiB of UTF8.
BOOL IJSVGCSSComponentsCreate(const char* _Nullable bytes, NSUInteger length, IJSVGCSSComponents* components);
void IJSVGCSSComponentsRelease(IJSVGCSSComponents* components);

// Read an already tokenized URL without reparsing its source.
NSString* _Nullable IJSVGCSSURLIdentifier(const IJSVGCSSComponents* components, const IJSVGCSSComponent* component, BOOL requireFragment);

typedef NS_OPTIONS(NSUInteger, IJSVGCSSParserOptions) {
    IJSVGCSSParserOptionNone = 0,
    IJSVGCSSParserOptionSVG = 1 << 0,
    IJSVGCSSParserOptionLeadingURL = 1 << 1
};

BOOL IJSVGCSSComponentsCreateWithOptions(const char* _Nullable bytes, NSUInteger length, IJSVGCSSParserOptions options, IJSVGCSSComponents* components);
BOOL IJSVGCSSFunctionIsCalculation(IJSVGCSSFunction function);
BOOL IJSVGCSSPathDataIsValid(NSString* _Nullable value);
NSString* _Nullable IJSVGCSSPathDataFromString(NSString* _Nullable value);
char* _Nullable IJSVGCSSComponentCopyArguments(const IJSVGCSSComponents* components, const IJSVGCSSComponent* component);

NS_ASSUME_NONNULL_END
