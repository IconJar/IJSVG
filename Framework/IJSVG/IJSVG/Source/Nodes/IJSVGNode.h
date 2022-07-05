//
//  IJSVGNode.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVG/IJSVGUnitLength.h>
#import <IJSVG/IJSVGViewBox.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@class IJSVGNode;
@class IJSVG;
@class IJSVGGroup;
@class IJSVGGradient;
@class IJSVGGroup;
@class IJSVGPattern;
@class IJSVGTransform;
@class IJSVGRootNode;
@class IJSVGUnitRect;
@class IJSVGFilter;
@class IJSVGMask;
@class IJSVGClipPath;

typedef void (^IJSVGNodeWalkHandler)(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop);

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
    IJSVGNodeTypeFilter,
    IJSVGNodeTypeFilterEffect,
    IJSVGNodeTypeForeignObject
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

typedef NS_OPTIONS(NSInteger, IJSVGFontTraits) {
    IJSVGFontTraitNone = 1 << 0,
    IJSVGFontTraitBold = 1 << 1,
    IJSVGFontTraitItalic = 1 << 2
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
@property (nonatomic, strong) IJSVGUnitRect* viewBox;
@property (nonatomic, assign) IJSVGViewBoxAlignment viewBoxAlignment;
@property (nonatomic, assign) IJSVGViewBoxMeetOrSlice viewBoxMeetOrSlice;
@property (nonatomic, copy) NSString* title;
@property (nonatomic, copy) NSString* desc;
@property (nonatomic, assign) IJSVGNodeType type;
@property (nonatomic, copy) NSString* name;
@property (nonatomic, copy) NSString* className;
@property (nonatomic, strong) NSSet<NSString*>* classNameList;
@property (nonatomic, copy) NSString* unicode;
@property (nonatomic, assign) BOOL shouldRender;
@property (nonatomic, strong) IJSVGUnitLength* x;
@property (nonatomic, strong) IJSVGUnitLength* y;
@property (nonatomic, strong) IJSVGUnitLength* width;
@property (nonatomic, strong) IJSVGUnitLength* height;
@property (nonatomic, strong) IJSVGUnitLength* opacity;
@property (nonatomic, strong) IJSVGUnitLength* fillOpacity;
@property (nonatomic, strong) IJSVGUnitLength* strokeOpacity;
@property (nonatomic, strong) IJSVGUnitLength* strokeWidth;
@property (nonatomic, strong) IJSVGUnitLength* offset;
@property (nonatomic, strong) IJSVGNode* fill;
@property (nonatomic, strong) IJSVGNode* stroke;
@property (nonatomic, copy) NSString* identifier;
@property (nonatomic, assign) IJSVGNode* parentNode;
@property (nonatomic, strong) IJSVGClipPath* clipPath;
@property (nonatomic, strong) IJSVGMask* mask;
@property (nonatomic, assign) IJSVGWindingRule windingRule;
@property (nonatomic, assign) IJSVGWindingRule clipRule;
@property (nonatomic, assign) IJSVGLineCapStyle lineCapStyle;
@property (nonatomic, assign) IJSVGLineJoinStyle lineJoinStyle;
@property (nonatomic, strong) IJSVGUnitLength* strokeMiterLimit;
@property (nonatomic, strong) NSArray<IJSVGTransform*>* transforms;
@property (nonatomic, strong) IJSVGFilter* filter;
@property (nonatomic, assign) CGFloat* strokeDashArray;
@property (nonatomic, assign) NSInteger strokeDashArrayCount;
@property (nonatomic, readonly) NSArray<NSNumber*>* lineDashPattern;
@property (nonatomic, strong) IJSVGUnitLength* strokeDashOffset;
@property (nonatomic, strong) IJSVG* svg;
@property (nonatomic, assign) IJSVGUnitType contentUnits;
@property (nonatomic, assign) IJSVGUnitType units;
@property (nonatomic, assign) IJSVGBlendMode blendMode;
@property (nonatomic, assign) IJSVGOverflowVisibility overflowVisibility;
@property (nonatomic, readonly) BOOL detachedFromParentNode;
@property (nonatomic, readonly) IJSVGRootNode* rootNode;


+ (void)walkNodeTree:(IJSVGNode*)node
             handler:(IJSVGNodeWalkHandler)handler;

+ (BOOL)node:(IJSVGNode*)node
containsNodesMatchingTraits:(IJSVGNodeTraits)traits;

+ (IJSVGNodeType)typeForString:(NSString*)string
                          kind:(NSXMLNodeKind)kind;
+ (BOOL)typeIsPathable:(IJSVGNodeType)type;

- (void)setDefaults;
- (void)postProcess;
- (void)applyPropertiesFromNode:(IJSVGNode*)node;

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect*)bounds;
- (IJSVGUnitType)contentUnitsWithReferencingNode:(IJSVGNode**)referencingNode;

- (instancetype)detach;

- (void)addTraits:(IJSVGNodeTraits)traits;
- (void)removeTraits:(IJSVGNodeTraits)traits;
- (BOOL)matchesTraits:(IJSVGNodeTraits)traits;
- (void)computeTraits;

- (NSSet<IJSVGNode*>*)nodesMatchingTypes:(NSIndexSet*)types;

- (instancetype)parentNodeMatchingClass:(Class)class;
- (instancetype)rootNodeMatchingClass:(Class)class;

@end
