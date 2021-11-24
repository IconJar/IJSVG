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
#import "IJSVGGroup.h"

@implementation IJSVGNode

- (void)dealloc
{
    (void)free(_strokeDashArray), _strokeDashArray = NULL;
    (void)([_x release]), _x = nil;
    (void)([_y release]), _y = nil;
    (void)([_width release]), _width = nil;
    (void)([_height release]), _height = nil;
    (void)([_opacity release]), _opacity = nil;
    (void)([_offset release]), _offset = nil;
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
    const char* name = string.UTF8String;
    if(name == NULL) {
        return IJSVGNodeTypeNotFound;
    }
    IJSVGCharBufferToLower((char*)name);
    if (strcmp(name, "style") == 0) {
        return IJSVGNodeTypeStyle;
    }
    if (strcmp(name, "switch") == 0) {
        return IJSVGNodeTypeSwitch;
    }
    if (strcmp(name, "defs") == 0) {
        return IJSVGNodeTypeDef;
    }
    if (strcmp(name, "g") == 0) {
        return IJSVGNodeTypeGroup;
    }
    if (strcmp(name, "path") == 0) {
        return IJSVGNodeTypePath;
    }
    if (strcmp(name, "polygon") == 0) {
        return IJSVGNodeTypePolygon;
    }
    if (strcmp(name, "polyline") == 0) {
        return IJSVGNodeTypePolyline;
    }
    if (strcmp(name, "rect") == 0) {
        return IJSVGNodeTypeRect;
    }
    if (strcmp(name, "line") == 0) {
        return IJSVGNodeTypeLine;
    }
    if (strcmp(name, "circle") == 0) {
        return IJSVGNodeTypeCircle;
    }
    if (strcmp(name, "ellipse") == 0) {
        return IJSVGNodeTypeEllipse;
    }
    if (strcmp(name, "use") == 0) {
        return IJSVGNodeTypeUse;
    }
    if (strcmp(name, "lineargradient") == 0) {
        return IJSVGNodeTypeLinearGradient;
    }
    if (strcmp(name, "radialgradient") == 0) {
        return IJSVGNodeTypeRadialGradient;
    }
    if(strcmp(name, "stop") == 0) {
        return IJSVGNodeTypeStop;
    }
    if (strcmp(name, "glyph") == 0) {
        return IJSVGNodeTypeGlyph;
    }
    if (strcmp(name, "font") == 0) {
        return IJSVGNodeTypeFont;
    }
    if (strcmp(name, "clippath") == 0) {
        return IJSVGNodeTypeClipPath;
    }
    if (strcmp(name, "mask") == 0) {
        return IJSVGNodeTypeMask;
    }
    if (strcmp(name, "image") == 0) {
        return IJSVGNodeTypeImage;
    }
    if (strcmp(name, "pattern") == 0) {
        return IJSVGNodeTypePattern;
    }
    if (strcmp(name, "svg") == 0) {
        return IJSVGNodeTypeSVG;
    }
    if (strcmp(name, "text") == 0) {
        return IJSVGNodeTypeText;
    }
    if (strcmp(name, "tspan") == 0 || kind == NSXMLTextKind) {
        return IJSVGNodeTypeTextSpan;
    }
    if(strcmp(name, "title") == 0) {
        return IJSVGNodeTypeTitle;
    }
    if(strcmp(name, "desc") == 0) {
        return IJSVGNodeTypeDesc;
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

+ (void)walkNodeTree:(IJSVGNode*)node
             handler:(IJSVGNodeWalkHandler)handler
{
    BOOL allowChildNodes = YES;
    BOOL stop = NO;
    [self _walkNodeTree:node
                handler:handler
        allowChildNodes:&allowChildNodes
                   stop:&stop];
}

+ (void)_walkNodeTree:(IJSVGNode*)node
              handler:(IJSVGNodeWalkHandler)handler
      allowChildNodes:(BOOL*)allowChildNodes
                 stop:(BOOL*)stop
{
    // run the handler and instantly stop
    // if stop is set
    handler(node, allowChildNodes, stop);
    if(*stop == YES) {
        return;
    }
    
    // child nodes only work for nodes
    // that are type group
    if(*allowChildNodes == NO ||
       [node isKindOfClass:IJSVGGroup.class] == NO) {
        *allowChildNodes = YES;
        return;
    }
    
    // iterate over the childnodes
    IJSVGGroup* group = (IJSVGGroup*)node;
    for(IJSVGNode* childNode in group.childNodes) {
        [self _walkNodeTree:childNode
                    handler:handler
            allowChildNodes:allowChildNodes
                       stop:stop];
        if(*stop == YES) {
            return;
        }
    }
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
    self.overflowVisibility = node.overflowVisibility;

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
        self.overflowVisibility = IJSVGOverflowVisibilityVisible;

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
