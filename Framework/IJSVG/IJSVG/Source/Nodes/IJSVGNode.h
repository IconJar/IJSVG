//
//  IJSVGNode.h
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVG/IJSVGTraitedColorStorage.h>
#import <IJSVG/IJSVGUnitLength.h>
#import <IJSVG/IJSVGViewBox.h>
#import <IJSVG/IJSVGBitFlags64.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IJSVGBackgroundEnabled) {
    IJSVGBackgroundEnabledUnspecified,
    IJSVGBackgroundEnabledAccumulate,
    IJSVGBackgroundEnabledNew,
    IJSVGBackgroundEnabledInherit
};

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

typedef NS_ENUM(NSInteger, IJSVGNodeAttribute) {
    IJSVGNodeAttributeVersion,
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
    IJSVGNodeAttributeCount
};

enum { kIJSVGNodeAttributeStorageLength = IJSVGNodeAttributeCount };

typedef NS_OPTIONS(NSInteger, IJSVGIntrinsicDimensions) {
    IJSVGIntrinsicDimensionNone = 0,
    IJSVGIntrinsicDimensionWidth = 1 << 1,
    IJSVGIntrinsicDimensionHeight = 1 << 2,
    IJSVGIntrinsicDimensionBoth = IJSVGIntrinsicDimensionWidth | IJSVGIntrinsicDimensionHeight
};

typedef NS_OPTIONS(NSInteger, IJSVGNodeTraits) {
    IJSVGNodeTraitNone = 0,
    IJSVGNodeTraitStroked = 1 << 0,
    IJSVGNodeTraitPaintable = 1 << 1,
    IJSVGNodeTraitPathed = 1 << 2
};

typedef NS_ENUM(NSInteger, IJSVGNodeType) {
    IJSVGNodeTypeUnknown = 0,
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
    IJSVGNodeTypeAnchor
};

typedef NS_ENUM(NSInteger, IJSVGWindingRule) {
    IJSVGWindingRuleNonZero,
    IJSVGWindingRuleEvenOdd,
    IJSVGWindingRuleInherit
};

typedef NS_ENUM(NSInteger, IJSVGLineCapStyle) {
    IJSVGLineCapStyleNone,
    IJSVGLineCapStyleButt,
    IJSVGLineCapStyleRound,
    IJSVGLineCapStyleSquare,
    IJSVGLineCapStyleInherit
};

typedef NS_ENUM(NSInteger, IJSVGLineJoinStyle) {
    IJSVGLineJoinStyleNone,
    IJSVGLineJoinStyleMiter,
    IJSVGLineJoinStyleRound,
    IJSVGLineJoinStyleBevel,
    IJSVGLineJoinStyleInherit
};

typedef NS_ENUM(NSInteger, IJSVGBlendMode) {
    IJSVGBlendModeNormal = kCGBlendModeNormal,
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
    IJSVGBlendModeLuminosity = kCGBlendModeLuminosity
};

typedef NS_ENUM(NSInteger, IJSVGColorInterpolation) {
    IJSVGColorInterpolationUnspecified,
    IJSVGColorInterpolationInherit,
    IJSVGColorInterpolationAuto,
    IJSVGColorInterpolationSRGB,
    IJSVGColorInterpolationLinearRGB
};

IJSVGColorInterpolation IJSVGColorInterpolationForString(NSString* _Nullable value);
NSString* _Nullable IJSVGColorInterpolationString(IJSVGColorInterpolation value);

typedef NS_ENUM(NSInteger, IJSVGOverflowVisibility) {
    IJSVGOverflowVisibilityHidden,
    IJSVGOverflowVisibilityVisible
};

static CGFloat IJSVGInheritedFloatValue = -99.9999991;
static CGFloat IJSVGInheritedIntegerValue = INT_MIN;

@interface IJSVGNode : NSObject <NSCopying> {
@private
    BOOL _computedTraits;
}

void IJSVGAssertPaintableObject(id object);

@property (nonatomic, assign) IJSVGNodeTraits traits;
@property (nonatomic, assign, readonly) CGRect bounds;
@property (nonatomic, strong, nullable) IJSVGUnitRect* viewBox;
@property (nonatomic, assign) IJSVGViewBoxAlignment viewBoxAlignment;
@property (nonatomic, assign) IJSVGViewBoxMeetOrSlice viewBoxMeetOrSlice;
@property (nonatomic, readonly) BOOL containsRelativeUnits;
@property (nonatomic, copy, nullable) NSString* title;
@property (nonatomic, copy, nullable) NSString* desc;
@property (nonatomic, copy, nullable) NSString* unicode;
// Specified text properties, retained on all elements for inheritance through groups.
@property (nonatomic, copy, nullable) NSDictionary<NSString*, IJSVGTextAttributeValue*>* textStyle;
// Style inheritance can follow the source document independently of rendering.
@property (nonatomic, weak, nullable) IJSVGNode* styleParent;
// nil inherits. An empty marker represents an explicit "none" or invalid reference.
@property (nonatomic, strong, nullable) IJSVGMarker* markerStart;
@property (nonatomic, strong, nullable) IJSVGMarker* markerMid;
@property (nonatomic, strong, nullable) IJSVGMarker* markerEnd;
@property (nonatomic, assign) IJSVGNodeType type;
// An explicit name overrides the canonical SVG name derived from type.
// Setting nil restores the default; unknown types have no default name.
@property (nonatomic, copy, nullable) NSString* name;
@property (nonatomic, copy, nullable) NSString* className;
@property (nonatomic, strong, nullable) NSSet<NSString*>* classNameList;
@property (nonatomic, assign) BOOL shouldRender;
@property (nonatomic, strong, nullable) IJSVGUnitLength* x;
@property (nonatomic, strong, nullable) IJSVGUnitLength* y;
@property (nonatomic, strong, nullable) IJSVGUnitLength* width;
@property (nonatomic, strong, nullable) IJSVGUnitLength* height;
@property (nonatomic, strong, nullable) IJSVGUnitLength* opacity;
@property (nonatomic, strong, nullable) IJSVGUnitLength* fillOpacity;
@property (nonatomic, strong, nullable) IJSVGUnitLength* strokeOpacity;
@property (nonatomic, strong, nullable) IJSVGUnitLength* strokeWidth;
@property (nonatomic, strong, nullable) IJSVGUnitLength* offset;
@property (nonatomic, strong, nullable) IJSVGNode* fill;
@property (nonatomic, strong, nullable) IJSVGNode* stroke;
@property (nonatomic, copy, nullable) NSString* identifier;
@property (nonatomic, assign, nullable) IJSVGNode* parentNode;
@property (nonatomic, strong, nullable) IJSVGClipPath* clipPath;
@property (nonatomic, strong, nullable) IJSVGMask* mask;
@property (nonatomic, strong, nullable) IJSVGFilter* filter;
@property (nonatomic, copy, nullable) NSArray<IJSVGFilter*>* filters;
@property (nonatomic, assign) IJSVGColorInterpolation filterColorInterpolation;
@property (nonatomic, readonly) IJSVGColorInterpolation resolvedFilterColorInterpolation;
@property (nonatomic, assign) IJSVGBackgroundEnabled backgroundEnabled;
@property (nonatomic, assign) CGRect backgroundBounds;
@property (nonatomic, readonly) CGRect backgroundRect;
@property (nonatomic, assign) IJSVGWindingRule windingRule;
@property (nonatomic, assign) IJSVGWindingRule clipRule;
@property (nonatomic, assign) IJSVGLineCapStyle lineCapStyle;
@property (nonatomic, assign) IJSVGLineJoinStyle lineJoinStyle;
@property (nonatomic, strong, nullable) IJSVGUnitLength* strokeMiterLimit;
@property (nonatomic, strong, nullable) NSArray<IJSVGTransform*>* transforms;
@property (nonatomic, assign, nullable) CGFloat* strokeDashArray;
@property (nonatomic, assign) NSInteger strokeDashArrayCount;
@property (nonatomic, readonly) NSArray<NSNumber*>* lineDashPattern;
@property (nonatomic, strong, nullable) IJSVGUnitLength* strokeDashOffset;
@property (nonatomic, strong, nullable) IJSVG* svg;
@property (nonatomic, assign) IJSVGUnitType contentUnits;
@property (nonatomic, assign) IJSVGUnitType units;
@property (nonatomic, assign) IJSVGBlendMode blendMode;
@property (nonatomic, assign) IJSVGOverflowVisibility overflowVisibility;
@property (nonatomic, readonly) BOOL detachedFromParentNode;
@property (nonatomic, readonly, nullable) IJSVGRootNode* rootNode;

+ (IJSVGBitFlags*)computedAllowedAttributes;
+ (uint64_t)computedAllowedAttributeMask;
+ (IJSVGBitFlags*)allowedAttributes;

+ (void)walkNodeTree:(IJSVGNode*)node
             handler:(IJSVGNodeWalkHandler)handler;

+ (NSArray<IJSVGNode*>*)node:(IJSVGNode*)node
         nodesMatchingTraits:(IJSVGNodeTraits)traits;

+ (BOOL)node:(IJSVGNode*)node
containsNodesMatchingTraits:(IJSVGNodeTraits)traits;

// Returns not found for absent names and non element nodes.
+ (IJSVGNodeType)typeForString:(NSString* _Nullable)string
                          kind:(NSXMLNodeKind)kind;
+ (BOOL)typeIsPathable:(IJSVGNodeType)type;

- (BOOL)containsRelativeUnits;

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle* _Nullable)style;
- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle* _Nullable)style
                              matchingTraits:(IJSVGColorUsageTraits)traits;

// Conservative painted extent in parent coordinates, including filter regions.
// The viewport resolves relative units and style supplies rendering overrides.
- (CGRect)extentWithViewPort:(CGRect)viewPort
                       style:(IJSVGStyle* _Nullable)style NS_SWIFT_NAME(extent(in:style:));

// Subclasses with a fixed element identity override this construction default.
+ (IJSVGNodeType)defaultNodeType;

- (void)setDefaults;
- (void)postProcess;
- (void)applyPropertiesFromNode:(IJSVGNode*)node;

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect*)bounds;
- (IJSVGUnitType)contentUnitsWithReferencingNode:(IJSVGNode* _Nonnull * _Nonnull)referencingNode;

- (instancetype)detach;

- (void)addTraits:(IJSVGNodeTraits)traits;
- (void)removeTraits:(IJSVGNodeTraits)traits;
- (BOOL)matchesTraits:(IJSVGNodeTraits)traits;
- (void)computeTraits;

- (NSSet<IJSVGNode*>*)nodesMatchingTypes:(NSIndexSet*)types;

- (nullable instancetype)parentNodeMatchingClass:(Class)someClass;
- (nullable instancetype)rootNodeMatchingClass:(Class)someClass;

@end

NS_ASSUME_NONNULL_END
