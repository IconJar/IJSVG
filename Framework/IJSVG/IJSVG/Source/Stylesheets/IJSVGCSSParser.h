//
//  IJSVGCSSParser.h
//  IJSVG
//
//  Created by Curtis Hard on 12/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGUnitLength.h>

typedef NS_ENUM(uint8_t, IJSVGCSSFunction) {
    IJSVGCSSFunctionUnknown,
    IJSVGCSSFunctionCalc,
    IJSVGCSSFunctionMin,
    IJSVGCSSFunctionMax,
    IJSVGCSSFunctionClamp,
    IJSVGCSSFunctionURL,
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
    IJSVGCSSFunctionEllipse
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
IJSVGCSSFunction IJSVGCSSFunctionForName(const char* name);

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
// The next field is the index after the entire subtree. Names are classified once.
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

typedef struct IJSVGCSSComponents {
    IJSVGCSSComponent* values;
    NSUInteger count;
    const char* bytes;
} IJSVGCSSComponents;

// The caller releases the buffer, including on failure. The source must remain
// alive while accessing component source ranges. Limits: 64 nested blocks, 4096 components, 64 KiB of UTF8.
BOOL IJSVGCSSComponentsCreate(const char* bytes,
                              IJSVGCSSComponents* components);
void IJSVGCSSComponentsRelease(IJSVGCSSComponents* components);

typedef NS_OPTIONS(NSUInteger, IJSVGCSSParserOptions) {
    IJSVGCSSParserOptionNone = 0,
    IJSVGCSSParserOptionSVG = 1 << 0
};

BOOL IJSVGCSSComponentsCreateWithOptions(const char* bytes,
                                         IJSVGCSSParserOptions options,
                                         IJSVGCSSComponents* components);
BOOL IJSVGCSSFunctionIsCalculation(IJSVGCSSFunction function);
char* IJSVGCSSComponentCopyArguments(const IJSVGCSSComponents* components,
                                     const IJSVGCSSComponent* component);
