//
//  IJSVGNode.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGDef.h"
#import "IJSVGNode.h"
#import "IJSVGUtils.h"

@implementation IJSVGNode

- (void)dealloc
{
    (void)free(_strokeDashArray), _strokeDashArray = NULL;
    (void)([_x release]), _x = nil;
    (void)([_y release]), _y = nil;
    (void)([_width release]), _width = nil;
    (void)([_height release]), _height = nil;
    (void)([_opacity release]), _opacity = nil;
    (void)([_fillOpacity release]), _fillOpacity = nil;
    (void)([_strokeOpacity release]), _strokeOpacity = nil;
    (void)([_strokeWidth release]), _strokeWidth = nil;
    (void)([_strokeDashOffset release]), _strokeDashOffset = nil;
    (void)([_unicode release]), _unicode = nil;
    (void)([_fillGradient release]), _fillGradient = nil;
    (void)([_strokeGradient release]), _strokeGradient = nil;
    (void)([_strokePattern release]), _strokePattern = nil;
    (void)([_transforms release]), _transforms = nil;
    (void)([_fillColor release]), _fillColor = nil;
    (void)([_strokeColor release]), _strokeColor = nil;
    (void)([_identifier release]), _identifier = nil;
    (void)([_def release]), _def = nil;
    (void)([_name release]), _name = nil;
    (void)([_title release]), _title = nil;
    (void)([_desc release]), _desc = nil;
    (void)([_className release]), _className = nil;
    (void)([_classNameList release]), _classNameList = nil;
    (void)([_fillPattern release]), _fillPattern = nil;
    (void)([_clipPath release]), _clipPath = nil;
    (void)([_svg release]), _svg = nil;
    (void)([_mask release]), _mask = nil;
    [super dealloc];
}

+ (IJSVGNodeType)typeForString:(NSString*)string
                          kind:(NSXMLNodeKind)kind
{
    string = [string lowercaseString];
    if ([string isEqualToString:@"style"])
        return IJSVGNodeTypeStyle;
    if ([string isEqualToString:@"switch"])
        return IJSVGNodeTypeSwitch;
    if ([string isEqualToString:@"defs"])
        return IJSVGNodeTypeDef;
    if ([string isEqualToString:@"g"])
        return IJSVGNodeTypeGroup;
    if ([string isEqualToString:@"path"])
        return IJSVGNodeTypePath;
    if ([string isEqualToString:@"polygon"])
        return IJSVGNodeTypePolygon;
    if ([string isEqualToString:@"polyline"])
        return IJSVGNodeTypePolyline;
    if ([string isEqualToString:@"rect"])
        return IJSVGNodeTypeRect;
    if ([string isEqualToString:@"line"])
        return IJSVGNodeTypeLine;
    if ([string isEqualToString:@"circle"])
        return IJSVGNodeTypeCircle;
    if ([string isEqualToString:@"ellipse"])
        return IJSVGNodeTypeEllipse;
    if ([string isEqualToString:@"use"])
        return IJSVGNodeTypeUse;
    if ([string isEqualToString:@"lineargradient"])
        return IJSVGNodeTypeLinearGradient;
    if ([string isEqualToString:@"radialgradient"])
        return IJSVGNodeTypeRadialGradient;
    if ([string isEqualToString:@"glyph"])
        return IJSVGNodeTypeGlyph;
    if ([string isEqualToString:@"font"])
        return IJSVGNodeTypeFont;
    if ([string isEqualToString:@"clippath"])
        return IJSVGNodeTypeClipPath;
    if ([string isEqualToString:@"mask"])
        return IJSVGNodeTypeMask;
    if ([string isEqualToString:@"image"])
        return IJSVGNodeTypeImage;
    if ([string isEqualToString:@"pattern"])
        return IJSVGNodeTypePattern;
    if ([string isEqualToString:@"svg"])
        return IJSVGNodeTypeSVG;
    if ([string isEqualToString:@"text"])
        return IJSVGNodeTypeText;
    if ([string isEqualToString:@"tspan"] || kind == NSXMLTextKind) {
        return IJSVGNodeTypeTextSpan;
    }
    if([string isEqualToString:@"title"]) {
        return IJSVGNodeTypeTitle;
    }
    if([string isEqualToString:@"desc"]) {
        return IJSVGNodeTypeDesc;
    }

    // are we commong HTML? - if so just treat as a group
    if (IJSVGIsCommonHTMLElementName(string) == YES) {
        return IJSVGNodeTypeGroup;
    }

    return IJSVGNodeTypeNotFound;
}

- (id)init
{
    if ((self = [self initWithDef:YES]) != nil) {
        self.opacity = [IJSVGUnitLength unitWithFloat:1];
    }
    return self;
}

- (void)applyPropertiesFromNode:(IJSVGNode*)node
{
    self.title = node.title;
    self.desc = node.desc;
    
    self.name = node.name;
    self.type = node.type;
    self.unicode = node.unicode;
    self.className = node.className;
    self.classNameList = node.classNameList;

    self.x = node.x;
    self.y = node.y;
    self.width = node.width;
    self.height = node.height;

    self.fillGradient = node.fillGradient;
    self.fillPattern = node.fillPattern;
    self.strokeGradient = node.strokeGradient;
    self.strokePattern = node.strokePattern;

    self.fillColor = node.fillColor;
    self.strokeColor = node.strokeColor;
    self.clipPath = node.clipPath;

    self.units = node.units;
    self.contentUnits = node.contentUnits;

    self.opacity = node.opacity;
    self.strokeWidth = node.strokeWidth;
    self.fillOpacity = node.fillOpacity;
    self.strokeOpacity = node.strokeOpacity;

    self.identifier = node.identifier;
    self.usesDefaultFillColor = node.usesDefaultFillColor;

    self.transforms = node.transforms;
    self.def = node.def;
    self.windingRule = node.windingRule;
    self.lineCapStyle = node.lineCapStyle;
    self.lineJoinStyle = node.lineJoinStyle;
    self.parentNode = node.parentNode;

    self.shouldRender = node.shouldRender;
    self.blendMode = node.blendMode;

    // dash array needs physical memory copied
    CGFloat* nStrokeDashArray = (CGFloat*)malloc(node.strokeDashArrayCount * sizeof(CGFloat));
    memcpy(self.strokeDashArray, nStrokeDashArray, node.strokeDashArrayCount * sizeof(CGFloat));
    self.strokeDashArray = nStrokeDashArray;
    self.strokeDashArrayCount = node.strokeDashArrayCount;
    self.strokeDashOffset = node.strokeDashOffset;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGNode* node = [self.class allocWithZone:zone];
    [node applyPropertiesFromNode:self];
    return node;
}

- (id)initWithDef:(BOOL)flag
{
    if ((self = [super init]) != nil) {
        self.opacity = [IJSVGUnitLength unitWithFloat:0.f];
        self.fillOpacity = [IJSVGUnitLength unitWithFloat:1.f];
        self.fillOpacity.inherit = YES;

        self.strokeDashOffset = [IJSVGUnitLength unitWithFloat:0.f];
        self.shouldRender = YES;

        self.strokeOpacity = [IJSVGUnitLength unitWithFloat:1.f];
        self.strokeOpacity.inherit = YES;

        self.strokeWidth = [IJSVGUnitLength unitWithFloat:1.f];
        self.strokeWidth.inherit = YES;

        self.windingRule = IJSVGWindingRuleInherit;
        self.lineCapStyle = IJSVGLineCapStyleInherit;
        self.lineJoinStyle = IJSVGLineJoinStyleInherit;
        self.units = IJSVGUnitInherit;

        self.blendMode = IJSVGBlendModeNormal;

        if (flag == YES) {
            _def = [[IJSVGDef alloc] init];
        }
    }
    return self;
}

- (IJSVGDef*)defForID:(NSString*)anID
{
    IJSVGDef* aDef = nil;
    if ((aDef = [_def defForID:anID]) != nil) {
        return aDef;
    }
    if (_parentNode != nil) {
        return [_parentNode defForID:anID];
    }
    return nil;
}

- (void)addDef:(IJSVGNode*)aDef
{
    [_def addDef:aDef];
}

// winding rule can inherit..
- (IJSVGWindingRule)windingRule
{
    if (_windingRule == IJSVGWindingRuleInherit && _parentNode != nil) {
        return _parentNode.windingRule;
    }
    return _windingRule;
}

- (IJSVGLineCapStyle)lineCapStyle
{
    if (_lineCapStyle == IJSVGLineCapStyleInherit) {
        if (_parentNode != nil) {
            return _parentNode.lineCapStyle;
        }
    }
    return _lineCapStyle;
}

- (IJSVGLineJoinStyle)lineJoinStyle
{
    if (_lineJoinStyle == IJSVGLineJoinStyleInherit) {
        if (_parentNode != nil) {
            return _parentNode.lineJoinStyle;
        }
    }
    return _lineJoinStyle;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGUnitLength*)opacity
{
    if (_opacity.inherit && _parentNode != nil) {
        return _parentNode.opacity;
    }
    return _opacity;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGUnitLength*)fillOpacity
{
    if (_fillOpacity.inherit && _parentNode != nil) {
        return _parentNode.fillOpacity;
    }
    return _fillOpacity;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGUnitLength*)strokeWidth
{
    if (_strokeWidth.inherit && _parentNode != nil) {
        return _parentNode.strokeWidth;
    }
    return _strokeWidth;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (NSColor*)strokeColor
{
    if (_strokeColor != nil)
        return _strokeColor;
    if (_strokeColor == nil && _parentNode != nil)
        return _parentNode.strokeColor;
    return nil;
}

- (IJSVGUnitLength*)strokeOpacity
{
    if (_strokeOpacity.inherit && _parentNode != nil) {
        return _parentNode.strokeOpacity;
    }
    return _strokeOpacity;
}

// even though the spec explicity states fill color
// must be on the path, it can also be on the
- (NSColor*)fillColor
{
    if (_fillColor == nil && _parentNode != nil) {
        return _parentNode.fillColor;
    }
    return _fillColor;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGGradient*)fillGradient
{
    if (_fillGradient == nil && _parentNode != nil) {
        return _parentNode.fillGradient;
    }
    return _fillGradient;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGPattern*)fillPattern
{
    if (_fillPattern == nil && _parentNode != nil) {
        return _parentNode.fillPattern;
    }
    return _fillPattern;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGGradient*)strokeGradient
{
    if (_strokeGradient == nil && _parentNode != nil) {
        return _parentNode.strokeGradient;
    }
    return _strokeGradient;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGPattern*)strokePattern
{
    if (_strokePattern == nil && _parentNode != nil) {
        return _parentNode.strokePattern;
    }
    return _strokePattern;
}

@end
