//
//  IJSVGGraphicsNode.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGClipPath.h>
#import <IJSVG/IJSVGGraphicsNode.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVG/IJSVGMask.h>
#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGPolygon.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGUse.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGQuartzRenderer.h>

// Bounded ASCII keyword parsing: no lowercase strings or heap buffers.
static BOOL IJSVGRenderingKeyword(NSString* value, char token[32])
{
    const char* bytes = value.UTF8String;
    if (bytes == NULL) {
        return NO;
    }
    NSUInteger length = [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    while (length && (*bytes == ' ' || *bytes == '\t' || *bytes == '\r' || *bytes == '\n' || *bytes == '\f')) {
        bytes++;
        length--;
    }
    while (length && (bytes[length - 1] == ' ' || bytes[length - 1] == '\t' || bytes[length - 1] == '\r' || bytes[length - 1] == '\n' || bytes[length - 1] == '\f')) {
        length--;
    }
    if (length == 0 || length >= 32) {
        return NO;
    }
    for (NSUInteger index = 0; index < length; index++) {
        unsigned char c = bytes[index];
        if (c == 0 || c > 127) {
            return NO;
        }
        token[index] = c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c;
    }
    token[length] = 0;
    return YES;
}

IJSVGColorInterpolation IJSVGPaintColorInterpolationForString(NSString* value)
{
    char token[32];
    if (!IJSVGRenderingKeyword(value, token)) {
        return IJSVGColorInterpolationUnspecified;
    }
    if (strcmp(token, "srgb") == 0 || strcmp(token, "initial") == 0) {
        return IJSVGColorInterpolationSRGB;
    }
    if (strcmp(token, "linearrgb") == 0) {
        return IJSVGColorInterpolationLinearRGB;
    }
    if (strcmp(token, "auto") == 0) {
        return IJSVGColorInterpolationAuto;
    }
    if (strcmp(token, "inherit") == 0 || strcmp(token, "unset") == 0) {
        return IJSVGColorInterpolationInherit;
    }
    return IJSVGColorInterpolationUnspecified;
}

IJSVGShapeRendering IJSVGShapeRenderingForString(NSString* value)
{
    char token[32];
    if (!IJSVGRenderingKeyword(value, token)) {
        return IJSVGShapeRenderingUnspecified;
    }
    if (strcmp(token, "initial") == 0) {
        return IJSVGShapeRenderingAuto;
    }
    if (strcmp(token, "auto") == 0) {
        return IJSVGShapeRenderingAuto;
    }
    if (strcmp(token, "optimizespeed") == 0) {
        return IJSVGShapeRenderingOptimizeSpeed;
    }
    if (strcmp(token, "crispedges") == 0) {
        return IJSVGShapeRenderingCrispEdges;
    }
    if (strcmp(token, "geometricprecision") == 0) {
        return IJSVGShapeRenderingGeometricPrecision;
    }
    return IJSVGShapeRenderingUnspecified;
}

NSString* IJSVGShapeRenderingString(IJSVGShapeRendering value)
{
    switch (value) {
        case IJSVGShapeRenderingAuto:
            return @"auto";
        case IJSVGShapeRenderingOptimizeSpeed:
            return @"optimizeSpeed";
        case IJSVGShapeRenderingCrispEdges:
            return @"crispEdges";
        case IJSVGShapeRenderingGeometricPrecision:
            return @"geometricPrecision";
        case IJSVGShapeRenderingUnspecified:
            return nil;
    }
    return nil;
}

IJSVGImageRendering IJSVGImageRenderingForString(NSString* value)
{
    char token[32];
    if (!IJSVGRenderingKeyword(value, token)) {
        return IJSVGImageRenderingUnspecified;
    }
    if (strcmp(token, "initial") == 0) {
        return IJSVGImageRenderingAuto;
    }
    if (strcmp(token, "auto") == 0) {
        return IJSVGImageRenderingAuto;
    }
    if (strcmp(token, "optimizespeed") == 0) {
        return IJSVGImageRenderingOptimizeSpeed;
    }
    if (strcmp(token, "optimizequality") == 0) {
        return IJSVGImageRenderingOptimizeQuality;
    }
    return IJSVGImageRenderingUnspecified;
}

NSString* IJSVGImageRenderingString(IJSVGImageRendering value)
{
    switch (value) {
        case IJSVGImageRenderingAuto:
            return @"auto";
        case IJSVGImageRenderingOptimizeSpeed:
            return @"optimizeSpeed";
        case IJSVGImageRenderingOptimizeQuality:
            return @"optimizeQuality";
        case IJSVGImageRenderingUnspecified:
            return nil;
    }
    return nil;
}

static void IJSVGNodeAddColorToStorage(IJSVGTraitedColorStorage* storage, CGColorRef color, IJSVGColorUsageTraits traits)
{
    if (color == nil) {
        return;
    }
    IJSVGTraitedColor* traited = nil;
    traited = [IJSVGTraitedColor colorWithColor:color traits:traits];
    [storage addColor:traited];
}

// Optional feature storage is absent until a value other than the default is assigned.
// Reading or copying an ordinary node does not allocate these objects.
@interface IJSVGMarkerProperties : NSObject
@property (nonatomic, strong) IJSVGMarker* markerStart;
@property (nonatomic, strong) IJSVGMarker* markerMid;
@property (nonatomic, strong) IJSVGMarker* markerEnd;
@end

@implementation IJSVGMarkerProperties

- (BOOL)isEmpty
{
    return _markerStart == nil && _markerMid == nil && _markerEnd == nil;
}

@end

@interface IJSVGEffectProperties : NSObject
@property (nonatomic, strong) IJSVGMask* mask;
@property (nonatomic, copy) NSArray<IJSVGFilter*>* filters;
@property (nonatomic, assign) IJSVGColorInterpolation filterColorInterpolation;
@property (nonatomic, assign) IJSVGBackgroundEnabled backgroundEnabled;
@property (nonatomic, assign) CGRect backgroundBounds;
@end

@implementation IJSVGEffectProperties

- (BOOL)isEmpty
{
    return _mask == nil && _filters == nil && _filterColorInterpolation == IJSVGColorInterpolationUnspecified && _backgroundEnabled == IJSVGBackgroundEnabledUnspecified && CGRectEqualToRect(_backgroundBounds, CGRectZero);
}

@end

@interface IJSVGTransformOriginProperties : NSObject
@property (nonatomic, copy) NSArray<IJSVGUnitLength*>* transformOrigin;
@property (nonatomic, assign) IJSVGTransformBox transformBox;
@end

@implementation IJSVGTransformOriginProperties

- (BOOL)isEmpty
{
    return _transformOrigin == nil && _transformBox == IJSVGTransformBoxUnspecified;
}

@end

@implementation IJSVGGraphicsNode {
    IJSVGMarkerProperties* _markerProperties;
    IJSVGEffectProperties* _effectProperties;
    IJSVGTransformOriginProperties* _transformOriginProperties;
    unsigned char _initializedDefaultLengths;
    uint8_t _paintColorInterpolation;
}

- (IJSVGNodeTypeTraits)nodeTraits
{
    return IJSVGNodeTypeTraitPaint | IJSVGNodeTypeTraitGraphics;
}

@synthesize opacity = _opacity, strokeOpacity = _strokeOpacity, strokeWidth = _strokeWidth;
@synthesize strokeDashOffset = _strokeDashOffset, paintOrder = _paintOrder;
@synthesize stroke = _stroke, strokeDashArray = _strokeDashArray;

- (void)setMarkerStart:(IJSVGMarker*)value
{
    if (_markerProperties == nil) {
        if (value == nil) {
            return;
        }
        _markerProperties = [[IJSVGMarkerProperties alloc] init];
    }
    _markerProperties.markerStart = value;
    if ([_markerProperties isEmpty]) {
        _markerProperties = nil;
    }
}

- (void)setMarkerMid:(IJSVGMarker*)value
{
    if (_markerProperties == nil) {
        if (value == nil) {
            return;
        }
        _markerProperties = [[IJSVGMarkerProperties alloc] init];
    }
    _markerProperties.markerMid = value;
    if ([_markerProperties isEmpty]) {
        _markerProperties = nil;
    }
}

- (void)setMarkerEnd:(IJSVGMarker*)value
{
    if (_markerProperties == nil) {
        if (value == nil) {
            return;
        }
        _markerProperties = [[IJSVGMarkerProperties alloc] init];
    }
    _markerProperties.markerEnd = value;
    if ([_markerProperties isEmpty]) {
        _markerProperties = nil;
    }
}

- (IJSVGMask*)mask
{
    return _effectProperties != nil ? _effectProperties.mask : nil;
}

- (void)setMask:(IJSVGMask*)value
{
    if (_effectProperties == nil) {
        if (value == nil) {
            return;
        }
        _effectProperties = [[IJSVGEffectProperties alloc] init];
    }
    _effectProperties.mask = value;
    if ([_effectProperties isEmpty]) {
        _effectProperties = nil;
    }
}

- (NSArray<IJSVGFilter*>*)filters
{
    return _effectProperties != nil ? _effectProperties.filters : nil;
}

- (void)setFilters:(NSArray<IJSVGFilter*>*)value
{
    if (_effectProperties == nil) {
        if (value == nil) {
            return;
        }
        _effectProperties = [[IJSVGEffectProperties alloc] init];
    }
    _effectProperties.filters = value;
    if ([_effectProperties isEmpty]) {
        _effectProperties = nil;
    }
}

- (IJSVGColorInterpolation)filterColorInterpolation
{
    return _effectProperties != nil ? _effectProperties.filterColorInterpolation : IJSVGColorInterpolationUnspecified;
}

- (void)setFilterColorInterpolation:(IJSVGColorInterpolation)value
{
    if (_effectProperties == nil) {
        if (value == IJSVGColorInterpolationUnspecified) {
            return;
        }
        _effectProperties = [[IJSVGEffectProperties alloc] init];
    }
    _effectProperties.filterColorInterpolation = value;
    if ([_effectProperties isEmpty]) {
        _effectProperties = nil;
    }
}

- (IJSVGBackgroundEnabled)backgroundEnabled
{
    return _effectProperties != nil ? _effectProperties.backgroundEnabled : IJSVGBackgroundEnabledUnspecified;
}

- (void)setBackgroundEnabled:(IJSVGBackgroundEnabled)value
{
    if (_effectProperties == nil) {
        if (value == IJSVGBackgroundEnabledUnspecified) {
            return;
        }
        _effectProperties = [[IJSVGEffectProperties alloc] init];
    }
    _effectProperties.backgroundEnabled = value;
    if ([_effectProperties isEmpty]) {
        _effectProperties = nil;
    }
}

- (CGRect)backgroundBounds
{
    return _effectProperties != nil ? _effectProperties.backgroundBounds : CGRectZero;
}

- (void)setBackgroundBounds:(CGRect)value
{
    if (_effectProperties == nil) {
        if (CGRectEqualToRect(value, CGRectZero)) {
            return;
        }
        _effectProperties = [[IJSVGEffectProperties alloc] init];
    }
    _effectProperties.backgroundBounds = value;
    if ([_effectProperties isEmpty]) {
        _effectProperties = nil;
    }
}

- (NSArray<IJSVGUnitLength*>*)transformOrigin
{
    return _transformOriginProperties != nil ? _transformOriginProperties.transformOrigin : nil;
}

- (void)setTransformOrigin:(NSArray<IJSVGUnitLength*>*)value
{
    if (_transformOriginProperties == nil) {
        if (value == nil) {
            return;
        }
        _transformOriginProperties = [[IJSVGTransformOriginProperties alloc] init];
    }
    _transformOriginProperties.transformOrigin = value;
    if ([_transformOriginProperties isEmpty]) {
        _transformOriginProperties = nil;
    }
}

- (IJSVGTransformBox)transformBox
{
    return _transformOriginProperties != nil ? _transformOriginProperties.transformBox : IJSVGTransformBoxUnspecified;
}

- (void)setTransformBox:(IJSVGTransformBox)value
{
    if (_transformOriginProperties == nil) {
        if (value == IJSVGTransformBoxUnspecified) {
            return;
        }
        _transformOriginProperties = [[IJSVGTransformOriginProperties alloc] init];
    }
    _transformOriginProperties.transformBox = value;
    if ([_transformOriginProperties isEmpty]) {
        _transformOriginProperties = nil;
    }
}

- (void)setDefaults
{
    [super setDefaults];
    _strokeDashArrayCount = IJSVGInheritedIntegerValue;
    _windingRule = IJSVGWindingRuleInherit;
    _clipRule = IJSVGWindingRuleInherit;
    _lineCapStyle = IJSVGLineCapStyleInherit;
    _lineJoinStyle = IJSVGLineJoinStyleInherit;
    _units = IJSVGUnitInherit;
    _contentUnits = IJSVGUnitInherit;
    _blendMode = IJSVGBlendModeNormal;
    _paintOrder = IJSVGPaintOrderInherit;
    _overflowVisibility = IJSVGOverflowVisibilityVisible;
}

- (void)applyPropertiesFromNode:(IJSVGNode*)source
{
    [super applyPropertiesFromNode:source];
    if ((source.nodeTraits & IJSVGNodeTypeTraitGraphics) == 0) {
        return;
    }
    IJSVGGraphicsNode* node = (IJSVGGraphicsNode*)source;
    self.markerStart = node->_markerProperties.markerStart.copy;
    self.markerMid = node->_markerProperties.markerMid.copy;
    self.markerEnd = node->_markerProperties.markerEnd.copy;

    self.x = node.x;
    self.y = node.y;
    self.geometryLengths = node.geometryLengths;
    self.width = node.width;
    self.height = node.height;

    self.stroke = node.stroke;
    self.clipPath = node.clipPath;
    self.mask = node.mask;
    self.filters = node.filters;
    self.filterColorInterpolation = node.filterColorInterpolation;
    self.colorInterpolation = node.colorInterpolation;
    self.shapeRendering = node.shapeRendering;
    self.imageRendering = node.imageRendering;
    self.backgroundEnabled = node.backgroundEnabled;
    self.backgroundBounds = node.backgroundBounds;

    self.units = node.units;
    self.contentUnits = node.contentUnits;

    self.opacity = node.opacity;
    self.strokeWidth = node.strokeWidth;
    self.strokeOpacity = node.strokeOpacity;
    self.strokeMiterLimit = node.strokeMiterLimit;

    self.transforms = node.transforms;
    self.transformOrigin = node.transformOrigin;
    self.transformBox = node.transformBox;
    self.windingRule = node.windingRule;
    self.clipRule = node.clipRule;
    self.lineCapStyle = node.lineCapStyle;
    self.lineJoinStyle = node.lineJoinStyle;

    self.blendMode = node.blendMode;
    self.isolated = node.isolated;
    self.paintOrder = node->_paintOrder;
    self.vectorEffect = node.vectorEffect;
    self.overflowVisibility = node.overflowVisibility;

    // dash array needs physical memory copied
    NSInteger strokeDashArrayCount = node.strokeDashArrayCount;
    CGFloat* strokeDashArray = node.strokeDashArray;
    if (strokeDashArrayCount > 0 && strokeDashArray != NULL) {
        CGFloat* nStrokeDashArray = (CGFloat*)malloc(strokeDashArrayCount * sizeof(CGFloat));
        memcpy(nStrokeDashArray, strokeDashArray, strokeDashArrayCount * sizeof(CGFloat));
        self.strokeDashArray = nStrokeDashArray;
    }
    self.strokeDashArrayCount = strokeDashArrayCount;
    self.strokeDashLengths = node.strokeDashLengths;
    self.strokeDashOffset = node.strokeDashOffset;
}

- (IJSVGPaintOrder)paintOrder
{
    if (_paintOrder == IJSVGPaintOrderInherit) {
        IJSVGGraphicsNode* parent = self.styleParent;
        return parent != nil ? parent.paintOrder : IJSVGPaintOrderNormal;
    }
    return _paintOrder;
}

- (IJSVGVectorEffect)resolvedVectorEffect
{
    if (_vectorEffect == IJSVGVectorEffectInherit) {
        return (self.styleParent ?: self.parentNode).resolvedVectorEffect;
    }
    return _vectorEffect;
}

- (IJSVGFilter*)filter
{
    return self.filters.firstObject;
}

- (void)setFilter:(IJSVGFilter*)filter
{
    self.filters = filter == nil ? @[] : @[ filter ];
}

- (void)dealloc
{
    if (_strokeDashArray != NULL) {
        (void)free(_strokeDashArray), _strokeDashArray = NULL;
    }
}

- (BOOL)containsRelativeUnits
{
    return _x.isRelativeUnit == YES || _y.isRelativeUnit == YES || _width.isRelativeUnit == YES || _height.isRelativeUnit == YES;
}

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style
{
    IJSVGTraitedColorStorage* storage = [[IJSVGTraitedColorStorage alloc] init];
    if (self.shouldRender == NO || [self matchesTraits:IJSVGNodeTraitPathed] == NO) {
        return storage;
    }

    IJSVGNode* fill = self.fill;
    if ((fill.nodeTraits & IJSVGNodeTypeTraitColor) != 0 && ((IJSVGColorNode*)fill).usesCurrentColor) {
        fill = [IJSVGColorNode colorNodeWithColor:self.currentColor];
    }
    if (fill == nil) {
        IJSVGNodeAddColorToStorage(storage, style.fillColor ?: IJSVGColor.blackColor, IJSVGColorUsageTraitFill);
    } else {
        IJSVGTraitedColorStorage* fillStorage = nil;
        fillStorage = [fill colorsWithStyle:style matchingTraits:IJSVGColorUsageTraitFill];
        [storage unionColorStorage:fillStorage];
    }

    if ([self matchesTraits:IJSVGNodeTraitStroked] == YES) {
        IJSVGNode* stroke = self.stroke;
        if ((stroke.nodeTraits & IJSVGNodeTypeTraitColor) != 0 && ((IJSVGColorNode*)stroke).usesCurrentColor) {
            stroke = [IJSVGColorNode colorNodeWithColor:self.currentColor];
        }
        IJSVGTraitedColorStorage* strokeStorage = nil;
        strokeStorage = [stroke colorsWithStyle:style matchingTraits:IJSVGColorUsageTraitStroke];
        [storage unionColorStorage:strokeStorage];
    }
    return storage;
}

- (void)setStroke:(IJSVGNode*)stroke
{
    NSAssert([stroke matchesTraits:IJSVGNodeTraitPaintable] || stroke == nil, @"Stroke must be a paintable node.");
    _stroke = stroke;
}

- (IJSVGColorInterpolation)colorInterpolation
{
    return (IJSVGColorInterpolation)_paintColorInterpolation;
}

- (void)setColorInterpolation:(IJSVGColorInterpolation)value
{
    _paintColorInterpolation = (uint8_t)value;
}

- (IJSVGColorInterpolation)resolvedColorInterpolation
{
    for (IJSVGGraphicsNode* node = self; node != nil; node = node.styleParent) {
        IJSVGColorInterpolation value = node.colorInterpolation;
        if (value != IJSVGColorInterpolationUnspecified && value != IJSVGColorInterpolationInherit) {
            return value;
        }
    }
    return IJSVGColorInterpolationSRGB;
}

- (IJSVGShapeRendering)resolvedShapeRendering
{
    for (IJSVGGraphicsNode* node = self; node != nil; node = node.styleParent) {
        IJSVGShapeRendering value = node.shapeRendering;
        if (value != IJSVGShapeRenderingUnspecified) {
            return value;
        }
    }
    return IJSVGShapeRenderingAuto;
}

- (IJSVGImageRendering)resolvedImageRendering
{
    for (IJSVGGraphicsNode* node = self; node != nil; node = node.styleParent) {
        IJSVGImageRendering value = node.imageRendering;
        if (value != IJSVGImageRenderingUnspecified) {
            return value;
        }
    }
    return IJSVGImageRenderingAuto;
}

- (IJSVGColorInterpolation)resolvedFilterColorInterpolation
{
    for (IJSVGGraphicsNode* node = self; node != nil; node = node.styleParent) {
        switch (node.filterColorInterpolation) {
            case IJSVGColorInterpolationSRGB:
                return IJSVGColorInterpolationSRGB;
            case IJSVGColorInterpolationAuto:
            case IJSVGColorInterpolationLinearRGB:
                return IJSVGColorInterpolationLinearRGB;
            case IJSVGColorInterpolationUnspecified:
            case IJSVGColorInterpolationInherit:
                break;
        }
    }
    return IJSVGColorInterpolationLinearRGB;
}

- (IJSVGMarker*)markerStart
{
    return _markerProperties.markerStart ?: self.styleParent.markerStart;
}

- (IJSVGMarker*)markerMid
{
    return _markerProperties.markerMid ?: self.styleParent.markerMid;
}

- (IJSVGMarker*)markerEnd
{
    return _markerProperties.markerEnd ?: self.styleParent.markerEnd;
}

- (IJSVGWindingRule)windingRule
{
    if (_windingRule == IJSVGWindingRuleInherit) {
        IJSVGGraphicsNode* parent = self.styleParent;
        if (parent != nil) {
            return parent.windingRule;
        }
    }
    return _windingRule;
}

- (IJSVGWindingRule)clipRule
{
    if (_clipRule == IJSVGWindingRuleInherit) {
        IJSVGGraphicsNode* parent = self.styleParent;
        if (parent != nil) {
            return parent.clipRule;
        }
    }
    return _clipRule;
}

- (IJSVGLineCapStyle)lineCapStyle
{
    if (_lineCapStyle == IJSVGLineCapStyleInherit) {
        IJSVGGraphicsNode* parent = self.styleParent;
        if (parent != nil) {
            return parent.lineCapStyle;
        }
    }
    return _lineCapStyle;
}

- (IJSVGLineJoinStyle)lineJoinStyle
{
    if (_lineJoinStyle == IJSVGLineJoinStyleInherit) {
        IJSVGGraphicsNode* parent = self.styleParent;
        if (parent != nil) {
            return parent.lineJoinStyle;
        }
    }
    return _lineJoinStyle;
}

- (CGRect)backgroundRect
{
    if ((self.nodeTraits & IJSVGNodeTypeTraitGroup) == 0) {
        return CGRectNull;
    }
    if (self.backgroundEnabled == IJSVGBackgroundEnabledInherit) {
        return self.parentNode != nil ? self.parentNode.backgroundRect : CGRectNull;
    }
    return self.backgroundEnabled == IJSVGBackgroundEnabledNew ? self.backgroundBounds : CGRectNull;
}

- (void)setOpacity:(IJSVGUnitLength*)value
{
    _initializedDefaultLengths |= 1;
    _opacity = value;
}

- (IJSVGUnitLength*)opacity
{
    if ((_initializedDefaultLengths & 1) == 0) {
        _initializedDefaultLengths |= 1;
        _opacity = IJSVGOneUnitLength;
    }
    if (_opacity.inherit) {
        IJSVGGraphicsNode* parent = self.styleParent;
        if (parent != nil) {
            return parent.opacity;
        }
    }
    return _opacity;
}

- (void)setStrokeWidth:(IJSVGUnitLength*)value
{
    _initializedDefaultLengths |= 8;
    _strokeWidth = value;
}

- (IJSVGUnitLength*)strokeWidth
{
    BOOL needsDefault = (_initializedDefaultLengths & 8) == 0;
    if (needsDefault || _strokeWidth.inherit) {
        IJSVGGraphicsNode* parent = self.styleParent;
        if (parent != nil) {
            return parent.strokeWidth;
        }
    }
    if (needsDefault) {
        _initializedDefaultLengths |= 8;
        _strokeWidth = IJSVGInheritedOneUnitLength;
    }
    return _strokeWidth;
}

- (NSArray<IJSVGUnitLength*>*)strokeDashLengths
{
    if (_strokeDashLengths == nil && _strokeDashArrayCount == IJSVGInheritedIntegerValue) {
        return self.styleParent.strokeDashLengths;
    }
    return _strokeDashLengths;
}

- (NSArray<NSNumber*>*)lineDashPattern
{
    NSInteger count = self.strokeDashArrayCount;
    if (count <= 0) {
        return @[];
    }
    const CGFloat* values = self.strokeDashArray;
    NSMutableArray<NSNumber*>* pattern = [[NSMutableArray alloc] initWithCapacity:count];
    for (NSInteger index = 0; index < count; index++) {
        [pattern addObject:@(values[index])];
    }
    return pattern;
}

- (IJSVGNode*)stroke
{
    return _stroke ?: self.styleParent.stroke;
}

- (void)setStrokeDashArray:(CGFloat*)values
{
    if (_strokeDashArray == values) {
        return;
    }
    free(_strokeDashArray);
    _strokeDashArray = values;
}

- (CGFloat*)strokeDashArray
{
    return _strokeDashArray ?: self.styleParent.strokeDashArray;
}

- (NSInteger)strokeDashArrayCount
{
    if (_strokeDashArrayCount == IJSVGInheritedIntegerValue) {
        IJSVGGraphicsNode* parent = self.styleParent;
        if (parent != nil) {
            return parent.strokeDashArrayCount;
        }
    }
    return _strokeDashArrayCount;
}

- (void)setStrokeDashOffset:(IJSVGUnitLength*)value
{
    _initializedDefaultLengths |= 16;
    _strokeDashOffset = value;
}

- (IJSVGUnitLength*)strokeDashOffset
{
    BOOL needsDefault = (_initializedDefaultLengths & 16) == 0;
    if (needsDefault || _strokeDashOffset.inherit || _strokeDashOffset == nil) {
        IJSVGGraphicsNode* parent = self.styleParent;
        if (parent != nil) {
            return parent.strokeDashOffset;
        }
    }
    if (needsDefault) {
        _initializedDefaultLengths |= 16;
        _strokeDashOffset = IJSVGInheritedZeroUnitLength;
    }
    return _strokeDashOffset;
}

- (void)setStrokeOpacity:(IJSVGUnitLength*)value
{
    _initializedDefaultLengths |= 4;
    _strokeOpacity = value;
}

- (IJSVGUnitLength*)strokeOpacity
{
    BOOL needsDefault = (_initializedDefaultLengths & 4) == 0;
    if (needsDefault || _strokeOpacity.inherit) {
        IJSVGGraphicsNode* parent = self.styleParent;
        if (parent != nil) {
            return parent.strokeOpacity;
        }
    }
    if (needsDefault) {
        _initializedDefaultLengths |= 4;
        _strokeOpacity = IJSVGInheritedOneUnitLength;
    }
    return _strokeOpacity;
}

- (IJSVGUnitType)units
{
    if (_units == IJSVGUnitInherit && self.parentNode != nil) {
        return self.parentNode.units;
    }
    return _units;
}

- (IJSVGUnitType)contentUnits
{
    if (_contentUnits == IJSVGUnitInherit && self.parentNode != nil) {
        return self.parentNode.contentUnits;
    }
    return _contentUnits;
}

- (IJSVGUnitLength*)strokeMiterLimit
{
    return _strokeMiterLimit ?: self.styleParent.strokeMiterLimit;
}

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect*)bounds
{
    IJSVGGraphicsNode* node = nil;
    IJSVGUnitType type = [self contentUnitsWithReferencingNode:&node];
    *bounds = node.parentNode.bounds;
    return type;
}

- (IJSVGUnitType)contentUnitsWithReferencingNode:(IJSVGGraphicsNode**)referencingNode
{
    if (_contentUnits == IJSVGUnitInherit && self.parentNode != nil) {
        return [self.parentNode contentUnitsWithReferencingNode:referencingNode];
    }
    *referencingNode = self;
    return _contentUnits;
}

@end

@implementation IJSVGGraphicsNode (Rendering)

- (IJSVGResolvedStrokeStyle)resolvedStrokeStyle
{
    IJSVGResolvedStrokeStyle style = { .lineCap = IJSVGLineCapStyleInherit, .lineJoin = IJSVGLineJoinStyleInherit, .dashCount = IJSVGInheritedIntegerValue, .vectorEffect = IJSVGVectorEffectInherit };
    BOOL hasWidth = NO;
    BOOL hasOpacity = NO;
    BOOL hasDashOffset = NO;
    BOOL hasDashLengths = NO;

    // Preserve the existing owner choice when ancestors share a length object.
    BOOL trackingWidthOwner = NO;
    BOOL trackingOffsetOwner = NO;
    BOOL trackingLengthsOwner = NO;
    for (IJSVGGraphicsNode* node = self; node != nil;) {
        IJSVGGraphicsNode* parent = node.styleParent;
        Class type = node.class;

        // Custom subclasses can supply computed values through their getters.
        if (type != IJSVGPath.class && type != IJSVGGroup.class && type != IJSVGUse.class && type != IJSVGPolygon.class && type != IJSVGRootNode.class && type != IJSVGClipPath.class && type != IJSVGMask.class) {
            style.usesCustomDashPattern = node == self;
            if (style.vectorEffect == IJSVGVectorEffectInherit) {
                style.vectorEffect = node.resolvedVectorEffect;
            }

            // Custom getters may compute inheritance differently. Use the existing
            // owner lookup for these chains when resolving lengths relative to the font.
            style.widthOwner = nil;
            style.dashOffsetOwner = nil;
            style.dashLengthsOwner = nil;
            style.stroke = style.stroke ?: node.stroke;
            style.width = hasWidth ? style.width : node.strokeWidth;
            style.opacity = hasOpacity ? style.opacity : node.strokeOpacity;
            style.miterLimit = style.miterLimit ?: node.strokeMiterLimit;
            style.lineCap = style.lineCap == IJSVGLineCapStyleInherit ? node.lineCapStyle : style.lineCap;
            style.lineJoin = style.lineJoin == IJSVGLineJoinStyleInherit ? node.lineJoinStyle : style.lineJoin;
            style.dashOffset = hasDashOffset ? style.dashOffset : node.strokeDashOffset;
            style.dashLengths = hasDashLengths ? style.dashLengths : node.strokeDashLengths;
            style.dashArray = style.dashArray ?: node.strokeDashArray;
            style.dashCount = style.dashCount == IJSVGInheritedIntegerValue ? node.strokeDashArrayCount : style.dashCount;
            break;
        }
        if (style.vectorEffect == IJSVGVectorEffectInherit) {
            style.vectorEffect = node->_vectorEffect;
        }
        style.stroke = style.stroke ?: node->_stroke;
        style.miterLimit = style.miterLimit ?: node->_strokeMiterLimit;
        if (style.lineCap == IJSVGLineCapStyleInherit) {
            style.lineCap = node->_lineCapStyle;
        }
        if (style.lineJoin == IJSVGLineJoinStyleInherit) {
            style.lineJoin = node->_lineJoinStyle;
        }
        BOOL defaultWidth = (node->_initializedDefaultLengths & 8) == 0;
        if (parent == nil || (!defaultWidth && !node->_strokeWidth.inherit)) {
            IJSVGUnitLength* width = defaultWidth ? IJSVGInheritedOneUnitLength : node->_strokeWidth;
            if (!hasWidth) {
                style.width = width;
                style.widthOwner = node;
                hasWidth = YES;
                trackingWidthOwner = width.usesFontMetrics && parent != nil;
            } else if (trackingWidthOwner) {
                if (width == style.width) {
                    style.widthOwner = node;
                } else {
                    trackingWidthOwner = NO;
                }
            }
        }
        BOOL defaultOpacity = (node->_initializedDefaultLengths & 4) == 0;
        if (!hasOpacity && (parent == nil || (!defaultOpacity && !node->_strokeOpacity.inherit))) {
            style.opacity = defaultOpacity ? IJSVGInheritedOneUnitLength : node->_strokeOpacity;
            hasOpacity = YES;
        }
        BOOL defaultOffset = (node->_initializedDefaultLengths & 16) == 0;
        if (parent == nil || (!defaultOffset && node->_strokeDashOffset != nil && !node->_strokeDashOffset.inherit)) {
            IJSVGUnitLength* offset = defaultOffset ? IJSVGInheritedZeroUnitLength : node->_strokeDashOffset;
            if (!hasDashOffset) {
                style.dashOffset = offset;
                style.dashOffsetOwner = node;
                hasDashOffset = YES;
                trackingOffsetOwner = offset.usesFontMetrics && parent != nil;
            } else if (trackingOffsetOwner) {
                if (offset == style.dashOffset) {
                    style.dashOffsetOwner = node;
                } else {
                    trackingOffsetOwner = NO;
                }
            }
        }
        if (node->_strokeDashLengths != nil || node->_strokeDashArrayCount != IJSVGInheritedIntegerValue || parent == nil) {
            if (!hasDashLengths) {
                style.dashLengths = node->_strokeDashLengths;
                style.dashLengthsOwner = node;
                hasDashLengths = YES;
                trackingLengthsOwner = style.dashLengths != nil && parent != nil;
            } else if (trackingLengthsOwner) {
                if (node->_strokeDashLengths == style.dashLengths) {
                    style.dashLengthsOwner = node;
                } else {
                    trackingLengthsOwner = NO;
                }
            }
        }
        style.dashArray = style.dashArray ?: node->_strokeDashArray;
        if (style.dashCount == IJSVGInheritedIntegerValue) {
            style.dashCount = node->_strokeDashArrayCount;
        }
        if (style.stroke != nil && style.miterLimit != nil && style.lineCap != IJSVGLineCapStyleInherit && style.lineJoin != IJSVGLineJoinStyleInherit && hasWidth && hasOpacity && hasDashOffset && hasDashLengths && style.dashArray != NULL && style.dashCount != IJSVGInheritedIntegerValue && !trackingWidthOwner && !trackingOffsetOwner && !trackingLengthsOwner && style.vectorEffect != IJSVGVectorEffectInherit) {
            break;
        }
        node = parent;
    }
    if (style.vectorEffect == IJSVGVectorEffectInherit) {
        style.vectorEffect = IJSVGVectorEffectNone;
    }
    return style;
}

- (IJSVGResolvedPaintStyle)resolvedPaintStyle
{
    IJSVGResolvedPaintStyle style = { .windingRule = IJSVGWindingRuleInherit, .paintOrder = IJSVGPaintOrderInherit };
    IJSVGGraphicsNode* node = self;
    for (; node != nil;) {
        IJSVGGraphicsNode* parent = node.styleParent;
        [node addSpecifiedPaintPropertiesToStyle:&style atRoot:parent == nil];
        if (style.complete) {
            break;
        }
        node = parent;
    }

    // A custom getter on this node can deliberately return nil. An inheriting
    // ordinary getter on the child still falls back to black for a nil ancestor.
    if (style.currentColor == nil && node != self) {
        style.currentColor = IJSVGColor.blackColor;
    }
    if (style.visibility == IJSVGVisibilityInherit) {
        style.visibility = IJSVGVisibilityVisible;
    }
    if (!style.complete && style.paintOrder == IJSVGPaintOrderInherit) {
        style.paintOrder = IJSVGPaintOrderNormal;
    }
    style.opacity = self.opacity.value;
    return style;
}

- (void)addSpecifiedPaintPropertiesToStyle:(IJSVGResolvedPaintStyle*)style atRoot:(BOOL)atRoot
{
    Class type = self.class;

    // Preserve custom inherited getters instead of reading their backing storage.
    if (type != IJSVGPath.class && type != IJSVGGroup.class && type != IJSVGUse.class && type != IJSVGPolygon.class && type != IJSVGRootNode.class && type != IJSVGClipPath.class && type != IJSVGMask.class) {
        style->currentColor = style->currentColor ?: self.currentColor;
        if (style->visibility == IJSVGVisibilityInherit) {
            style->visibility = self.visibilityHidden ? IJSVGVisibilityHidden : IJSVGVisibilityVisible;
        }
        if (style->paintOrder == IJSVGPaintOrderInherit) {
            style->paintOrder = self.paintOrder;
        }
        style->fill = style->fill ?: self.fill;
        if (!style->hasFillOpacity) {
            style->fillOpacity = self.fillOpacity;
            style->hasFillOpacity = YES;
        }
        if (style->windingRule == IJSVGWindingRuleInherit) {
            style->windingRule = self.windingRule;
        }
        style->markerStart = style->markerStart ?: self.markerStart;
        style->markerMid = style->markerMid ?: self.markerMid;
        style->markerEnd = style->markerEnd ?: self.markerEnd;
        style->complete = YES;
        return;
    }
    [super addSpecifiedPaintPropertiesToStyle:style atRoot:atRoot];
    if (style->paintOrder == IJSVGPaintOrderInherit) {
        style->paintOrder = _paintOrder;
    }
    if (style->windingRule == IJSVGWindingRuleInherit) {
        style->windingRule = _windingRule;
    }
    style->markerStart = style->markerStart ?: _markerProperties.markerStart;
    style->markerMid = style->markerMid ?: _markerProperties.markerMid;
    style->markerEnd = style->markerEnd ?: _markerProperties.markerEnd;
    style->complete = style->fill != nil && style->hasFillOpacity && style->windingRule != IJSVGWindingRuleInherit && style->markerStart != nil && style->markerMid != nil && style->markerEnd != nil && style->currentColor != nil && style->visibility != IJSVGVisibilityInherit && style->paintOrder != IJSVGPaintOrderInherit;
}

@end
