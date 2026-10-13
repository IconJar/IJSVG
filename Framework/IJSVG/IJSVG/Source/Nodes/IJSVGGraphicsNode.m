//
//  IJSVGGraphicsNode.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGraphicsNode.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGQuartzRenderer.h>

static void IJSVGNodeAddColorToStorage(IJSVGTraitedColorStorage* storage, NSColor* color, IJSVGColorUsageTraits traits)
{
    if (color == nil) {
        return;
    }
    IJSVGTraitedColor* traited = nil;
    traited = [IJSVGTraitedColor colorWithColor:color traits:traits];
    [storage addColor:traited];
}

@implementation IJSVGGraphicsNode {
    unsigned char _initializedDefaultLengths;
}
@synthesize opacity = _opacity, strokeOpacity = _strokeOpacity, strokeWidth = _strokeWidth;
@synthesize strokeDashOffset = _strokeDashOffset, paintOrder = _paintOrder;
@synthesize stroke = _stroke, markerStart = _markerStart, markerMid = _markerMid, markerEnd = _markerEnd;

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
    if (![source isKindOfClass:IJSVGGraphicsNode.class]) {
        return;
    }
    IJSVGGraphicsNode* node = (IJSVGGraphicsNode*)source;
    self.markerStart = node->_markerStart.copy;
    self.markerMid = node->_markerMid.copy;
    self.markerEnd = node->_markerEnd.copy;

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
    if ([fill isKindOfClass:IJSVGColorNode.class] && ((IJSVGColorNode*)fill).usesCurrentColor) {
        fill = [IJSVGColorNode colorNodeWithColor:self.currentColor];
    }
    if (fill == nil) {
        IJSVGNodeAddColorToStorage(storage, style.fillColor ?: NSColor.blackColor, IJSVGColorUsageTraitFill);
    } else {
        IJSVGTraitedColorStorage* fillStorage = nil;
        fillStorage = [fill colorsWithStyle:style matchingTraits:IJSVGColorUsageTraitFill];
        [storage unionColorStorage:fillStorage];
    }

    if ([self matchesTraits:IJSVGNodeTraitStroked] == YES) {
        IJSVGNode* stroke = self.stroke;
        if ([stroke isKindOfClass:IJSVGColorNode.class] && ((IJSVGColorNode*)stroke).usesCurrentColor) {
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
    return _markerStart ?: self.styleParent.markerStart;
}

- (IJSVGMarker*)markerMid
{
    return _markerMid ?: self.styleParent.markerMid;
}

- (IJSVGMarker*)markerEnd
{
    return _markerEnd ?: self.styleParent.markerEnd;
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
    if (![self isKindOfClass:IJSVGGroup.class]) {
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
    NSMutableArray<NSNumber*>* arr = [[NSMutableArray alloc] initWithCapacity:self.strokeDashArrayCount];
    for (NSInteger i = 0; i < self.strokeDashArrayCount; i++) {
        [arr addObject:@((CGFloat)self.strokeDashArray[i])];
    }
    return arr;
}

- (IJSVGNode*)stroke
{
    return _stroke ?: self.styleParent.stroke;
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
