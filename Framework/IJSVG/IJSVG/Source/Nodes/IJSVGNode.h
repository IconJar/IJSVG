//
//  IJSVGNode.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyle.h>
#import <IJSVG/IJSVGUnitLength.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@class IJSVGNode;
@class IJSVG;
@class IJSVGGroup;
@class IJSVGDef;
@class IJSVGGradient;
@class IJSVGGroup;
@class IJSVGPattern;
@class IJSVGTransform;
@class IJSVGRootNode;

typedef void (^IJSVGNodeWalkHandler)(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop);

typedef NS_ENUM(NSInteger, IJSVGNodeType) {
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
    IJSVGNodeTypeUnknown,
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

@interface IJSVGNode : NSObject <NSCopying>

@property (nonatomic, assign) BOOL renderable;
@property (nonatomic, assign) BOOL adoptable;
@property (nonatomic, assign, readonly) CGRect bounds;
@property (nonatomic, copy) NSString* title;
@property (nonatomic, copy) NSString* desc;
@property (nonatomic, assign) IJSVGNodeType type;
@property (nonatomic, copy) NSString* name;
@property (nonatomic, copy) NSString* className;
@property (nonatomic, retain) NSArray* classNameList;
@property (nonatomic, copy) NSString* unicode;
@property (nonatomic, assign) BOOL shouldRender;
@property (nonatomic, assign) BOOL usesDefaultFillColor;
@property (nonatomic, retain) IJSVGUnitLength* x;
@property (nonatomic, retain) IJSVGUnitLength* y;
@property (nonatomic, retain) IJSVGUnitLength* width;
@property (nonatomic, retain) IJSVGUnitLength* height;
@property (nonatomic, retain) IJSVGUnitLength* opacity;
@property (nonatomic, retain) IJSVGUnitLength* fillOpacity;
@property (nonatomic, retain) IJSVGUnitLength* strokeOpacity;
@property (nonatomic, retain) IJSVGUnitLength* strokeWidth;
@property (nonatomic, retain) IJSVGUnitLength* offset;
@property (nonatomic, retain) NSColor* fillColor;
@property (nonatomic, retain) NSColor* strokeColor;
@property (nonatomic, copy) NSString* identifier;
@property (nonatomic, assign) IJSVGNode* parentNode;
@property (nonatomic, assign) IJSVGNode* intermediateParentNode;
@property (nonatomic, retain) IJSVGGroup* clipPath;
@property (nonatomic, retain) IJSVGGroup* mask;
@property (nonatomic, assign) IJSVGWindingRule windingRule;
@property (nonatomic, assign) IJSVGLineCapStyle lineCapStyle;
@property (nonatomic, assign) IJSVGLineJoinStyle lineJoinStyle;
@property (nonatomic, retain) NSArray<IJSVGTransform*>* transforms;
@property (nonatomic, retain) IJSVGDef* def;
@property (nonatomic, retain) IJSVGGradient* fillGradient;
@property (nonatomic, retain) IJSVGPattern* fillPattern;
@property (nonatomic, retain) IJSVGGradient* strokeGradient;
@property (nonatomic, retain) IJSVGPattern* strokePattern;
@property (nonatomic, assign) CGFloat* strokeDashArray;
@property (nonatomic, assign) NSInteger strokeDashArrayCount;
@property (nonatomic, retain) IJSVGUnitLength* strokeDashOffset;
@property (nonatomic, retain) IJSVG* svg;
@property (nonatomic, assign) IJSVGUnitType contentUnits;
@property (nonatomic, assign) IJSVGUnitType units;
@property (nonatomic, assign) IJSVGBlendMode blendMode;
@property (nonatomic, assign) IJSVGOverflowVisibility overflowVisibility;

+ (void)walkNodeTree:(IJSVGNode*)node
            handler:(IJSVGNodeWalkHandler)handler;

+ (IJSVGNodeType)typeForString:(NSString*)string
                          kind:(NSXMLNodeKind)kind;

- (void)applyPropertiesFromNode:(IJSVGNode*)node;

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect*)bounds;
- (IJSVGUnitType)contentUnitsWithReferencingNode:(IJSVGNode**)referencingNode;

- (instancetype)detach;

@end
