//
//  IJSVGText.h
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>

NS_ASSUME_NONNULL_BEGIN

// Parsed SVG/CSS text keywords. Numeric values and names retain their own data.
typedef NS_ENUM(NSUInteger, IJSVGTextKeyword) {
    IJSVGTextKeywordUnspecified,
    IJSVGTextKeywordInherit,
    IJSVGTextKeywordUnset,
    IJSVGTextKeywordInitial,
    IJSVGTextKeywordNormal,
    IJSVGTextKeywordNone,
    IJSVGTextKeywordAuto,
    IJSVGTextKeywordItalic,
    IJSVGTextKeywordOblique,
    IJSVGTextKeywordBold,
    IJSVGTextKeywordBolder,
    IJSVGTextKeywordLighter,
    IJSVGTextKeywordSmallCaps,
    IJSVGTextKeywordCondensed,
    IJSVGTextKeywordExpanded,
    IJSVGTextKeywordSmaller,
    IJSVGTextKeywordLarger,
    IJSVGTextKeywordXXSmall,
    IJSVGTextKeywordXSmall,
    IJSVGTextKeywordSmall,
    IJSVGTextKeywordMedium,
    IJSVGTextKeywordLarge,
    IJSVGTextKeywordXLarge,
    IJSVGTextKeywordXXLarge,
    IJSVGTextKeywordLTR,
    IJSVGTextKeywordRTL,
    IJSVGTextKeywordHorizontalTB,
    IJSVGTextKeywordVerticalRL,
    IJSVGTextKeywordVerticalLR,
    IJSVGTextKeywordSuper,
    IJSVGTextKeywordSub,
    IJSVGTextKeywordBaseline,
    IJSVGTextKeywordMiddle,
    IJSVGTextKeywordCentral,
    IJSVGTextKeywordHanging,
    IJSVGTextKeywordTextBeforeEdge,
    IJSVGTextKeywordBeforeEdge,
    IJSVGTextKeywordTextTop,
    IJSVGTextKeywordTextAfterEdge,
    IJSVGTextKeywordAfterEdge,
    IJSVGTextKeywordIdeographic,
    IJSVGTextKeywordTextBottom,
    IJSVGTextKeywordMathematical,
    IJSVGTextKeywordPre,
    IJSVGTextKeywordPreWrap,
    IJSVGTextKeywordBreakSpaces,
    IJSVGTextKeywordPreserve,
    IJSVGTextKeywordPreLine,
    IJSVGTextKeywordUppercase,
    IJSVGTextKeywordLowercase,
    IJSVGTextKeywordCapitalize,
    IJSVGTextKeywordNoCommonLigatures,
    IJSVGTextKeywordEmbed,
    IJSVGTextKeywordBidiOverride,
    IJSVGTextKeywordIsolate,
    IJSVGTextKeywordIsolateOverride,
    IJSVGTextKeywordPlaintext,
    IJSVGTextKeywordSpacing,
    IJSVGTextKeywordSpacingAndGlyphs,
    IJSVGTextKeywordStart,
    IJSVGTextKeywordEnd,
    IJSVGTextKeywordLeft,
    IJSVGTextKeywordRight,
    IJSVGTextKeywordMixed,
    IJSVGTextKeywordUpright,
    IJSVGTextKeywordSideways,
    IJSVGTextKeywordAlign,
    IJSVGTextKeywordStretch,
    IJSVGTextKeywordExact,
    IJSVGTextKeywordUnderline,
    IJSVGTextKeywordOverline,
    IJSVGTextKeywordLineThrough,
    IJSVGTextKeywordOn,
    IJSVGTextKeywordOff,
    IJSVGTextKeywordUltraCondensed,
    IJSVGTextKeywordExtraCondensed,
    IJSVGTextKeywordSemiCondensed,
    IJSVGTextKeywordSemiExpanded,
    IJSVGTextKeywordExtraExpanded,
    IJSVGTextKeywordUltraExpanded,
    IJSVGTextKeywordGeometricPrecision,
    IJSVGTextKeywordOptimizeLegibility,
    IJSVGTextKeywordOptimizeSpeed
};

typedef NS_ENUM(NSUInteger, IJSVGTextLengthBasis) {
    IJSVGTextLengthBasisAbsolute,
    IJSVGTextLengthBasisFontSize,
    IJSVGTextLengthBasisXHeight,
    IJSVGTextLengthBasisPercentage
};

typedef NS_OPTIONS(NSUInteger, IJSVGTextDecoration) {
    IJSVGTextDecorationNone = 0,
    IJSVGTextDecorationUnderline = 1 << 0,
    IJSVGTextDecorationOverline = 1 << 1,
    IJSVGTextDecorationLineThrough = 1 << 2
};

// Parser produced values are shared unchanged when styles inherit.
@interface IJSVGTextAttributeValue: NSObject

@property (nonatomic, copy) NSString* string;
@property (nonatomic, assign) IJSVGTextKeyword keyword;
@property (nonatomic, assign) IJSVGTextLengthBasis lengthBasis;
@property (nonatomic, assign) CGFloat number;
@property (nonatomic, assign) BOOL unitless;
@property (nonatomic, assign) IJSVGTextDecoration decorations;
@property (nonatomic, copy) NSArray<IJSVGTextAttributeValue*>* lengths;
@property (nonatomic, copy) NSArray<NSString*>* families;
@property (nonatomic, copy) NSDictionary<NSString*, NSNumber*>* features;

@end

// Retains mixed XML content in document order. Strings are never replaced by outlines.
@interface IJSVGText: IJSVGGroup

@property (nonatomic, copy) NSArray* textContent;

// Whether this node owns text rather than only containing styled child spans.
@property (nonatomic, readonly) BOOL hasTextContent;
@property (nonatomic, copy) NSDictionary<NSString*, IJSVGTextAttributeValue*>* positioning;
@property (nonatomic, strong, nullable) IJSVGPath* textPath;
@property (nonatomic, assign) BOOL isTextPath;

@end

NS_ASSUME_NONNULL_END
