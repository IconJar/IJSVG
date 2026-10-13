//
//  IJSVGNode.h
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGBitFlags64.h>
#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVG/IJSVGTraitedColorStorage.h>
#import <IJSVG/IJSVGUnitLength.h>
#import <IJSVG/IJSVGViewBox.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IJSVGVisibility) { IJSVGVisibilityInherit,
    IJSVGVisibilityVisible,
    IJSVGVisibilityHidden };

typedef NS_ENUM(NSUInteger, IJSVGBackgroundEnabled) { IJSVGBackgroundEnabledUnspecified,
    IJSVGBackgroundEnabledAccumulate,
    IJSVGBackgroundEnabledNew,
    IJSVGBackgroundEnabledInherit };

@class IJSVGTextAttributeValue;
@class IJSVGNode;
@class IJSVG;
@class IJSVGGroup;
@class IJSVGGradient;
@class IJSVGGroup;
@class IJSVGPattern;
@class IJSVGTransform;
@class IJSVGRootNode;
@class IJSVGUnitRect;
@class IJSVGMask;
@class IJSVGFilter;
@class IJSVGMarker;
@class IJSVGClipPath;
@class IJSVGThreadManager;
@class IJSVGStyle;

typedef void (^IJSVGNodeWalkHandler)(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop);

typedef NS_ENUM(NSInteger, IJSVGNodeAttribute) { IJSVGNodeAttributeVersion,
    IJSVGNodeAttributeXMLNS,
    IJSVGNodeAttributeXMLNSXlink,
    IJSVGNodeAttributeViewBox,
    IJSVGNodeAttributePreserveAspectRatio,
    IJSVGNodeAttributeID,
    IJSVGNodeAttributeClass,
    IJSVGNodeAttributeX,
    IJSVGNodeAttributeY,
    IJSVGNodeAttributeWidth,
    IJSVGNodeAttributeHeight,
    IJSVGNodeAttributeOpacity,
    IJSVGNodeAttributeStrokeOpacity,
    IJSVGNodeAttributeStrokeWidth,
    IJSVGNodeAttributeStrokeDashOffset,
    IJSVGNodeAttributeFillOpacity,
    IJSVGNodeAttributeClipPath,
    IJSVGNodeAttributeClipPathUnits,
    IJSVGNodeAttributeClipRule,
    IJSVGNodeAttributeMask,
    IJSVGNodeAttributeGradientUnits,
    IJSVGNodeAttributePatternUnits,
    IJSVGNodeAttributePatternContentUnits,
    IJSVGNodeAttributePatternTransform,
    IJSVGNodeAttributeMaskUnits,
    IJSVGNodeAttributeMaskContentUnits,
    IJSVGNodeAttributeTransform,
    IJSVGNodeAttributeGradientTransform,
    IJSVGNodeAttributeUnicode,
    IJSVGNodeAttributeStrokeLineCap,
    IJSVGNodeAttributeStrokeLineJoin,
    IJSVGNodeAttributeStroke,
    IJSVGNodeAttributeStrokeDashArray,
    IJSVGNodeAttributeStrokeMiterLimit,
    IJSVGNodeAttributeFill,
    IJSVGNodeAttributeFillRule,
    IJSVGNodeAttributeBlendMode,
    IJSVGNodeAttributeDisplay,
    IJSVGNodeAttributeStyle,
    IJSVGNodeAttributeD,
    IJSVGNodeAttributeXLink,
    IJSVGNodeAttributeX1,
    IJSVGNodeAttributeX2,
    IJSVGNodeAttributeY1,
    IJSVGNodeAttributeY2,
    IJSVGNodeAttributeRX,
    IJSVGNodeAttributeRY,
    IJSVGNodeAttributeCX,
    IJSVGNodeAttributeCY,
    IJSVGNodeAttributeR,
    IJSVGNodeAttributeFX,
    IJSVGNodeAttributeFY,
    IJSVGNodeAttributeFR,
    IJSVGNodeAttributePoints,
    IJSVGNodeAttributeOffset,
    IJSVGNodeAttributeStopColor,
    IJSVGNodeAttributeStopOpacity,
    IJSVGNodeAttributeHref,
    IJSVGNodeAttributeOverflow,
    IJSVGNodeAttributeMarker,
    IJSVGNodeAttributeFilter,
    IJSVGNodeAttributeFilterUnits,
    IJSVGNodeAttributePrimitiveUnits,
    IJSVGNodeAttributeDX,
    IJSVGNodeAttributeDY,
    IJSVGNodeAttributeStdDeviation,
    IJSVGNodeAttributeFloodColor,
    IJSVGNodeAttributeFloodOpacity,
    IJSVGNodeAttributeIn,
    IJSVGNodeAttributeResult,
    IJSVGNodeAttributeIn2,
    IJSVGNodeAttributeMode,
    IJSVGNodeAttributeType,
    IJSVGNodeAttributeValues,
    IJSVGNodeAttributeOperator,
    IJSVGNodeAttributeK1,
    IJSVGNodeAttributeK2,
    IJSVGNodeAttributeK3,
    IJSVGNodeAttributeK4,
    IJSVGNodeAttributeOrder,
    IJSVGNodeAttributeKernelMatrix,
    IJSVGNodeAttributeDivisor,
    IJSVGNodeAttributeBias,
    IJSVGNodeAttributeTargetX,
    IJSVGNodeAttributeTargetY,
    IJSVGNodeAttributeEdgeMode,
    IJSVGNodeAttributeKernelUnitLength,
    IJSVGNodeAttributePreserveAlpha,
    IJSVGNodeAttributeSurfaceScale,
    IJSVGNodeAttributeDiffuseConstant,
    IJSVGNodeAttributeSpecularConstant,
    IJSVGNodeAttributeSpecularExponent,
    IJSVGNodeAttributeLightingColor,
    IJSVGNodeAttributeScale,
    IJSVGNodeAttributeXChannelSelector,
    IJSVGNodeAttributeYChannelSelector,
    IJSVGNodeAttributeRadius,
    IJSVGNodeAttributeBaseFrequency,
    IJSVGNodeAttributeNumOctaves,
    IJSVGNodeAttributeSeed,
    IJSVGNodeAttributeStitchTiles,
    IJSVGNodeAttributeTableValues,
    IJSVGNodeAttributeSlope,
    IJSVGNodeAttributeIntercept,
    IJSVGNodeAttributeAmplitude,
    IJSVGNodeAttributeExponent,
    IJSVGNodeAttributeAzimuth,
    IJSVGNodeAttributeElevation,
    IJSVGNodeAttributeZ,
    IJSVGNodeAttributePointsAtX,
    IJSVGNodeAttributePointsAtY,
    IJSVGNodeAttributePointsAtZ,
    IJSVGNodeAttributeLimitingConeAngle,
    IJSVGNodeAttributeColorInterpolationFilters,
    IJSVGNodeAttributeEnableBackground,
    IJSVGNodeAttributeBackgroundColor,
    IJSVGNodeAttributeFont,
    IJSVGNodeAttributeFontFamily,
    IJSVGNodeAttributeFontSize,
    IJSVGNodeAttributeFontWeight,
    IJSVGNodeAttributeFontStyle,
    IJSVGNodeAttributeFontStretch,
    IJSVGNodeAttributeFontVariant,
    IJSVGNodeAttributeFontVariantLigatures,
    IJSVGNodeAttributeFontFeatureSettings,
    IJSVGNodeAttributeFontKerning,
    IJSVGNodeAttributeLetterSpacing,
    IJSVGNodeAttributeWordSpacing,
    IJSVGNodeAttributeTextAnchor,
    IJSVGNodeAttributeDirection,
    IJSVGNodeAttributeUnicodeBidi,
    IJSVGNodeAttributeWritingMode,
    IJSVGNodeAttributeTextOrientation,
    IJSVGNodeAttributeDominantBaseline,
    IJSVGNodeAttributeAlignmentBaseline,
    IJSVGNodeAttributeBaselineShift,
    IJSVGNodeAttributeTextDecoration,
    IJSVGNodeAttributeTextDecorationLine,
    IJSVGNodeAttributeWhiteSpace,
    IJSVGNodeAttributeLineHeight,
    IJSVGNodeAttributeInlineSize,
    IJSVGNodeAttributeTextTransform,
    IJSVGNodeAttributeTextOverflow,
    IJSVGNodeAttributeXMLSpace,
    IJSVGNodeAttributeLang,
    IJSVGNodeAttributeXMLLang,
    IJSVGNodeAttributeFontSizeAdjust,
    IJSVGNodeAttributeRotate,
    IJSVGNodeAttributeTextLength,
    IJSVGNodeAttributeLengthAdjust,
    IJSVGNodeAttributeStartOffset,
    IJSVGNodeAttributeMethod,
    IJSVGNodeAttributeSpacing,
    IJSVGNodeAttributeSide,
    IJSVGNodeAttributePath,
    IJSVGNodeAttributePathLength,
    IJSVGNodeAttributeTextRendering,
    IJSVGNodeAttributeMarkerStart,
    IJSVGNodeAttributeMarkerMid,
    IJSVGNodeAttributeMarkerEnd,
    IJSVGNodeAttributeRefX,
    IJSVGNodeAttributeRefY,
    IJSVGNodeAttributeMarkerWidth,
    IJSVGNodeAttributeMarkerHeight,
    IJSVGNodeAttributeMarkerUnits,
    IJSVGNodeAttributeOrient,
    IJSVGNodeAttributeVectorEffect,
    IJSVGNodeAttributeIsolation,
    IJSVGNodeAttributePaintOrder,
    IJSVGNodeAttributeColor,
    IJSVGNodeAttributeVisibility,
    IJSVGNodeAttributeMaskType,
    IJSVGNodeAttributeTransformOrigin,
    IJSVGNodeAttributeTransformBox,
    IJSVGNodeAttributeCount };

enum { kIJSVGNodeAttributeStorageLength = IJSVGNodeAttributeCount };

typedef NS_OPTIONS(NSInteger, IJSVGIntrinsicDimensions) { IJSVGIntrinsicDimensionNone = 0,
    IJSVGIntrinsicDimensionWidth = 1 << 1,
    IJSVGIntrinsicDimensionHeight = 1 << 2,
    IJSVGIntrinsicDimensionBoth = IJSVGIntrinsicDimensionWidth | IJSVGIntrinsicDimensionHeight };

typedef NS_OPTIONS(NSInteger, IJSVGNodeTraits) { IJSVGNodeTraitNone = 0,
    IJSVGNodeTraitStroked = 1 << 0,
    IJSVGNodeTraitPaintable = 1 << 1,
    IJSVGNodeTraitPathed = 1 << 2 };

typedef NS_ENUM(NSInteger, IJSVGNodeType) { IJSVGNodeTypeUnknown = 0,
    IJSVGNodeTypeGroup,
    IJSVGNodeTypePath,
    IJSVGNodeTypeDef,
    IJSVGNodeTypePolygon,
    IJSVGNodeTypePolyline,
    IJSVGNodeTypeRect,
    IJSVGNodeTypeLine,
    IJSVGNodeTypeCircle,
    IJSVGNodeTypeEllipse,
    IJSVGNodeTypeUse,
    IJSVGNodeTypeLinearGradient,
    IJSVGNodeTypeRadialGradient,
    IJSVGNodeTypeClipPath,
    IJSVGNodeTypeFont,
    IJSVGNodeTypeGlyph,
    IJSVGNodeTypeMask,
    IJSVGNodeTypeImage,
    IJSVGNodeTypePattern,
    IJSVGNodeTypeSVG,
    IJSVGNodeTypeText,
    IJSVGNodeTypeTextSpan,
    IJSVGNodeTypeStyle,
    IJSVGNodeTypeSwitch,
    IJSVGNodeTypeTitle,
    IJSVGNodeTypeDesc,
    IJSVGNodeTypeStop,
    IJSVGNodeTypeNotFound,
    IJSVGNodeTypeForeignObject,
    IJSVGNodeTypeFilter,
    IJSVGNodeTypeFilterDropShadow,
    IJSVGNodeTypeMarker,
    IJSVGNodeTypeFilterBlend,
    IJSVGNodeTypeFilterColorMatrix,
    IJSVGNodeTypeFilterComponentTransfer,
    IJSVGNodeTypeFilterComposite,
    IJSVGNodeTypeFilterConvolveMatrix,
    IJSVGNodeTypeFilterDiffuseLighting,
    IJSVGNodeTypeFilterDisplacementMap,
    IJSVGNodeTypeFilterFlood,
    IJSVGNodeTypeFilterGaussianBlur,
    IJSVGNodeTypeFilterImage,
    IJSVGNodeTypeFilterMerge,
    IJSVGNodeTypeFilterMorphology,
    IJSVGNodeTypeFilterOffset,
    IJSVGNodeTypeFilterSpecularLighting,
    IJSVGNodeTypeFilterTile,
    IJSVGNodeTypeFilterTurbulence,
    IJSVGNodeTypeFilterMergeNode,
    IJSVGNodeTypeFilterFuncR,
    IJSVGNodeTypeFilterFuncG,
    IJSVGNodeTypeFilterFuncB,
    IJSVGNodeTypeFilterFuncA,
    IJSVGNodeTypeFilterDistantLight,
    IJSVGNodeTypeFilterPointLight,
    IJSVGNodeTypeFilterSpotLight,
    IJSVGNodeTypeTextPath,
    IJSVGNodeTypeAnchor,
    IJSVGNodeTypeSymbol };

FOUNDATION_EXPORT IJSVGNodeType IJSVGNodeTypeForString(NSString* _Nullable string, NSXMLNodeKind kind);

typedef NS_ENUM(NSInteger, IJSVGWindingRule) { IJSVGWindingRuleNonZero,
    IJSVGWindingRuleEvenOdd,
    IJSVGWindingRuleInherit };

typedef NS_ENUM(NSInteger, IJSVGVectorEffect) { IJSVGVectorEffectNone,
    IJSVGVectorEffectNonScalingStroke,
    IJSVGVectorEffectInherit };

typedef NS_ENUM(NSInteger, IJSVGLineCapStyle) { IJSVGLineCapStyleNone,
    IJSVGLineCapStyleButt,
    IJSVGLineCapStyleRound,
    IJSVGLineCapStyleSquare,
    IJSVGLineCapStyleInherit };

typedef NS_ENUM(NSInteger, IJSVGLineJoinStyle) { IJSVGLineJoinStyleNone,
    IJSVGLineJoinStyleMiter,
    IJSVGLineJoinStyleRound,
    IJSVGLineJoinStyleBevel,
    IJSVGLineJoinStyleInherit };

// Two bits per operation: fill = 0, stroke = 1, markers = 2.
typedef NS_ENUM(NSInteger, IJSVGPaintOrder) { IJSVGPaintOrderInherit = -1,
    IJSVGPaintOrderNormal = 0x24,
    IJSVGPaintOrderFillMarkersStroke = 0x18,
    IJSVGPaintOrderStrokeFillMarkers = 0x21,
    IJSVGPaintOrderStrokeMarkersFill = 0x09,
    IJSVGPaintOrderMarkersFillStroke = 0x12,
    IJSVGPaintOrderMarkersStrokeFill = 0x06 };

typedef NS_ENUM(NSInteger, IJSVGBlendMode) { IJSVGBlendModeNormal = kCGBlendModeNormal,
    IJSVGBlendModeMultiply = kCGBlendModeMultiply,
    IJSVGBlendModeScreen = kCGBlendModeScreen,
    IJSVGBlendModeOverlay = kCGBlendModeOverlay,
    IJSVGBlendModeDarken = kCGBlendModeDarken,
    IJSVGBlendModeLighten = kCGBlendModeLighten,
    IJSVGBlendModeColorDodge = kCGBlendModeColorDodge,
    IJSVGBlendModeColorBurn = kCGBlendModeColorBurn,
    IJSVGBlendModeHardLight = kCGBlendModeHardLight,
    IJSVGBlendModeSoftLight = kCGBlendModeSoftLight,
    IJSVGBlendModeDifference = kCGBlendModeDifference,
    IJSVGBlendModeExclusion = kCGBlendModeExclusion,
    IJSVGBlendModeHue = kCGBlendModeHue,
    IJSVGBlendModeSaturation = kCGBlendModeSaturation,
    IJSVGBlendModeColor = kCGBlendModeColor,
    IJSVGBlendModeLuminosity = kCGBlendModeLuminosity };

typedef NS_ENUM(NSInteger, IJSVGColorInterpolation) { IJSVGColorInterpolationUnspecified,
    IJSVGColorInterpolationInherit,
    IJSVGColorInterpolationAuto,
    IJSVGColorInterpolationSRGB,
    IJSVGColorInterpolationLinearRGB };

IJSVGColorInterpolation IJSVGColorInterpolationForString(NSString* _Nullable value);
NSString* _Nullable IJSVGColorInterpolationString(IJSVGColorInterpolation value);

typedef NS_ENUM(NSInteger, IJSVGOverflowVisibility) { IJSVGOverflowVisibilityHidden,
    IJSVGOverflowVisibilityVisible };

static CGFloat IJSVGInheritedFloatValue = -99.9999991;
static CGFloat IJSVGInheritedIntegerValue = INT_MIN;

@class IJSVGGraphicsNode;
@class IJSVGGroup;

@interface IJSVGNode : NSObject <NSCopying> {
@private
    BOOL _computedTraits;
}

void IJSVGAssertPaintableObject(id object);

@property (nonatomic, assign) IJSVGNodeTraits traits;
@property (nonatomic, assign, readonly) CGRect bounds;
@property (nonatomic, readonly) BOOL containsRelativeUnits;
@property (nonatomic, copy, nullable) NSString* title;
@property (nonatomic, copy, nullable) NSString* desc;
// Specified text properties, retained on all elements for inheritance through
// groups.
@property (nonatomic, copy, nullable) NSDictionary<NSString*, IJSVGTextAttributeValue*>* textStyle;
// Style inheritance can follow the source document independently of rendering.
@property (nonatomic, weak, nullable) IJSVGGraphicsNode* styleParent;
// nil inherits. An empty marker represents an explicit "none" or invalid
// reference.
@property (nonatomic, assign) IJSVGNodeType type;
// An explicit name overrides the canonical SVG name derived from type.
// Setting nil restores the default, unknown types have no default name.
@property (nonatomic, copy, nullable) NSString* name;
@property (nonatomic, copy, nullable) NSString* className;
@property (nonatomic, strong, nullable) NSSet<NSString*>* classNameList;
@property (nonatomic, assign) BOOL shouldRender;
@property (nonatomic, strong, nullable) NSColor* currentColor;
@property (nonatomic, assign) IJSVGVisibility visibility;
@property (nonatomic, readonly) BOOL visibilityHidden;
@property (nonatomic, copy, nullable) NSString* identifier;
@property (nonatomic, assign, nullable) IJSVGGraphicsNode* parentNode;
@property (nonatomic, readonly) BOOL detachedFromParentNode;
@property (nonatomic, readonly, nullable) IJSVGRootNode* rootNode;

+ (IJSVGBitFlags*)computedAllowedAttributes;
+ (uint64_t)computedAllowedAttributeMask;

+ (void)walkNodeTree:(IJSVGNode*)node handler:(IJSVGNodeWalkHandler)handler;

+ (NSArray<IJSVGNode*>*)node:(IJSVGNode*)node nodesMatchingTraits:(IJSVGNodeTraits)traits;

+ (BOOL)node:(IJSVGNode*)node containsNodesMatchingTraits:(IJSVGNodeTraits)traits;

// Returns not found for absent names and non element nodes.
+ (IJSVGNodeType)typeForString:(NSString* _Nullable)string kind:(NSXMLNodeKind)kind;
+ (BOOL)typeIsPathable:(IJSVGNodeType)type;

- (BOOL)containsRelativeUnits;

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle* _Nullable)style;
- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle* _Nullable)style matchingTraits:(IJSVGColorUsageTraits)traits;

// Conservative painted extent in parent coordinates, including filter regions.
// The viewport resolves relative units and style supplies rendering overrides.
- (CGRect)extentWithViewPort:(CGRect)viewPort style:(IJSVGStyle* _Nullable)style NS_SWIFT_NAME(extent(in:style:));

// Subclasses with a fixed element identity override this construction default.
+ (IJSVGNodeType)defaultNodeType;

- (void)setDefaults;
- (void)postProcess;
- (void)applyPropertiesFromNode:(IJSVGNode*)node;

- (instancetype)detach;

- (void)addTraits:(IJSVGNodeTraits)traits;
- (void)removeTraits:(IJSVGNodeTraits)traits;
- (BOOL)matchesTraits:(IJSVGNodeTraits)traits;
- (void)computeTraits;

- (NSSet<IJSVGNode*>*)nodesMatchingTypes:(NSIndexSet*)types;

- (nullable instancetype)parentNodeMatchingClass:(Class)someClass;
- (nullable instancetype)rootNodeMatchingClass:(Class)someClass;

@end

// Element schemas are implemented in the parsing section of each node.
@interface IJSVGNode (AttributeSchema)
+ (IJSVGBitFlags*)allowedAttributes;
@end

NS_ASSUME_NONNULL_END
