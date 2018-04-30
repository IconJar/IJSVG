//
//  IJSVGNode.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGNode.h"
#import "IJSVGDef.h"
#import "IJSVGUtils.h"

@implementation IJSVGNode

@synthesize shouldRender;
@synthesize type;
@synthesize name;
@synthesize classNameList;
@synthesize className;
@synthesize unicode;
@synthesize x;
@synthesize y;
@synthesize width;
@synthesize height;
@synthesize fillColor;
@synthesize fillOpacity;
@synthesize strokeColor;
@synthesize strokeOpacity;
@synthesize strokeWidth;
@synthesize opacity;
@synthesize identifier;
@synthesize parentNode;
@synthesize intermediateParentNode;
@synthesize transforms;
@synthesize windingRule;
@synthesize def;
@synthesize fillGradient;
@synthesize fillPattern;
@synthesize strokeGradient;
@synthesize strokePattern;
@synthesize clipPath;
@synthesize lineCapStyle;
@synthesize lineJoinStyle;
@synthesize strokeDashArrayCount;
@synthesize strokeDashArray;
@synthesize strokeDashOffset;
@synthesize usesDefaultFillColor;
@synthesize svg;
@synthesize mask;
@synthesize units;
@synthesize contentUnits;
@synthesize blendMode;

- (void)dealloc
{
    free(strokeDashArray);
    [x release], x = nil;
    [y release], y = nil;
    [width release], width = nil;
    [height release], height = nil;
    [opacity release], opacity = nil;
    [fillOpacity release], fillOpacity = nil;
    [strokeOpacity release], strokeOpacity = nil;
    [strokeWidth release], strokeWidth = nil;
    [strokeDashOffset release], strokeDashOffset = nil;
    [unicode release], unicode = nil;
    [fillGradient release], fillGradient = nil;
    [strokeGradient release], strokeGradient = nil;
    [strokePattern release], strokePattern = nil;
    [transforms release], transforms = nil;
    [fillColor release], fillColor = nil;
    [strokeColor release], strokeColor = nil;
    [identifier release], identifier = nil;
    [def release], def = nil;
    [name release], name = nil;
    [className release], className = nil;
    [classNameList release], classNameList = nil;
    [fillPattern release], fillPattern = nil;
    [clipPath release], clipPath = nil;
    [svg release], svg = nil;
    [mask release], mask = nil;
    [super dealloc];
}

+ (IJSVGNodeType)typeForString:(NSString *)string
                          kind:(NSXMLNodeKind)kind
{
    string = [string lowercaseString];
    if([string isEqualToString:@"style"])
        return IJSVGNodeTypeStyle;
    if([string isEqualToString:@"switch"])
        return IJSVGNodeTypeSwitch;
    if( [string isEqualToString:@"defs"] )
        return IJSVGNodeTypeDef;
    if( [string isEqualToString:@"g"] )
        return IJSVGNodeTypeGroup;
    if( [string isEqualToString:@"path"] )
        return IJSVGNodeTypePath;
    if( [string isEqualToString:@"polygon"] )
        return IJSVGNodeTypePolygon;
    if( [string isEqualToString:@"polyline"] )
        return IJSVGNodeTypePolyline;
    if( [string isEqualToString:@"rect"] )
        return IJSVGNodeTypeRect;
    if( [string isEqualToString:@"line"] )
        return IJSVGNodeTypeLine;
    if( [string isEqualToString:@"circle"] )
        return IJSVGNodeTypeCircle;
    if( [string isEqualToString:@"ellipse"] )
        return IJSVGNodeTypeEllipse;
    if( [string isEqualToString:@"use"] )
        return IJSVGNodeTypeUse;
    if( [string isEqualToString:@"lineargradient"] )
        return IJSVGNodeTypeLinearGradient;
    if( [string isEqualToString:@"radialgradient"] )
        return IJSVGNodeTypeRadialGradient;
    if( [string isEqualToString:@"glyph"] )
        return IJSVGNodeTypeGlyph;
    if( [string isEqualToString:@"font"] )
        return IJSVGNodeTypeFont;
    if( [string isEqualToString:@"clippath"] )
        return IJSVGNodeTypeClipPath;
    if( [string isEqualToString:@"mask"] )
        return IJSVGNodeTypeMask;
    if( [string isEqualToString:@"image"] )
        return IJSVGNodeTypeImage;
    if([string isEqualToString:@"pattern"])
        return IJSVGNodeTypePattern;
    if([string isEqualToString:@"svg"])
        return IJSVGNodeTypeSVG;
    if([string isEqualToString:@"text"])
        return IJSVGNodeTypeText;
    if([string isEqualToString:@"tspan"] || kind == NSXMLTextKind) {
        return IJSVGNodeTypeTextSpan;
    }
    
    // are we commong HTML? - if so just treat as a group
    if(IJSVGIsCommonHTMLElementName(string) == YES) {
        return IJSVGNodeTypeGroup;
    }
    
    return IJSVGNodeTypeNotFound;
}

- (id)init
{
    if( ( self = [self initWithDef:YES] ) != nil )
    {
        self.opacity = [IJSVGUnitLength unitWithFloat:1];
    }
    return self;
}

- (void)applyPropertiesFromNode:(IJSVGNode *)node
{
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
    CGFloat * nStrokeDashArray = (CGFloat *)malloc(node.strokeDashArrayCount*sizeof(CGFloat));
    memcpy( self.strokeDashArray, nStrokeDashArray, node.strokeDashArrayCount*sizeof(CGFloat));
    self.strokeDashArray = nStrokeDashArray;
    self.strokeDashArrayCount = node.strokeDashArrayCount;
    self.strokeDashOffset = node.strokeDashOffset;
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGNode * node = [[self class] allocWithZone:zone];
    [node applyPropertiesFromNode:self];
    return node;
}

- (id)initWithDef:(BOOL)flag
{
    if( ( self = [super init] ) != nil )
    {
        self.opacity = [IJSVGUnitLength unitWithFloat:0.f];
        self.fillOpacity = [IJSVGUnitLength unitWithFloat:1.f];
        
        self.strokeDashOffset = [IJSVGUnitLength unitWithFloat:0.f];
        self.shouldRender = YES;
        
        self.strokeOpacity = [IJSVGUnitLength unitWithFloat:1.f];
        self.strokeOpacity.inherit = YES;
        
        self.strokeWidth = [IJSVGUnitLength unitWithFloat:0.f];
        self.strokeWidth.inherit = YES;
        
        self.windingRule = IJSVGWindingRuleInherit;
        self.lineCapStyle = IJSVGLineCapStyleInherit;
        self.lineJoinStyle = IJSVGLineJoinStyleInherit;
        self.units = IJSVGUnitInherit;
        
        self.blendMode = IJSVGBlendModeNormal;
        
        if( flag ) {
            def = [[IJSVGDef alloc] init];
        }
    }
    return self;
}

- (IJSVGDef *)defForID:(NSString *)anID
{
    IJSVGDef * aDef = nil;
    if( (aDef = [def defForID:anID]) != nil ) {
        return aDef;
    }
    if( parentNode != nil ) {
        return [parentNode defForID:anID];
    }
    return nil;
}

- (void)addDef:(IJSVGNode *)aDef
{
    [def addDef:aDef];
}

// winding rule can inherit..
- (IJSVGWindingRule)windingRule
{
    if(windingRule == IJSVGWindingRuleInherit && parentNode != nil) {
        return parentNode.windingRule;
    }
    return windingRule;
}

- (IJSVGLineCapStyle)lineCapStyle
{
    if( lineCapStyle == IJSVGLineCapStyleInherit ) {
        if( parentNode != nil ) {
            return parentNode.lineCapStyle;
        }
    }
    return lineCapStyle;
}

- (IJSVGLineJoinStyle)lineJoinStyle
{
    if( lineJoinStyle == IJSVGLineJoinStyleInherit ) {
        if( parentNode != nil ) {
            return parentNode.lineJoinStyle;
        }
    }
    return lineJoinStyle;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGUnitLength *)opacity
{
    if(opacity.inherit && parentNode != nil) {
        return parentNode.opacity;
    }
    return opacity;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGUnitLength *)fillOpacity
{
    if(fillOpacity.inherit && parentNode != nil) {
        return parentNode.fillOpacity;
    }
    return fillOpacity;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGUnitLength *)strokeWidth
{
    if(strokeWidth.inherit && parentNode != nil) {
        return parentNode.strokeWidth;
    }
    return strokeWidth;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (NSColor *)strokeColor
{
    if( strokeColor != nil )
        return strokeColor;
    if( strokeColor == nil && parentNode != nil )
        return parentNode.strokeColor;
    return nil;
}

- (IJSVGUnitLength *)strokeOpacity
{
    if(strokeOpacity.inherit && parentNode != nil) {
        return parentNode.strokeOpacity;
    }
    return strokeOpacity;
}

// even though the spec explicity states fill color
// must be on the path, it can also be on the
- (NSColor *)fillColor
{
    if( fillColor == nil && parentNode != nil ) {
        return parentNode.fillColor;
    }
    return fillColor;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGGradient *)fillGradient
{
    if(fillGradient == nil && parentNode != nil) {
        return parentNode.fillGradient;
    }
    return fillGradient;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGPattern *)fillPattern
{
    if(fillPattern == nil && parentNode != nil) {
        return parentNode.fillPattern;
    }
    return fillPattern;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGGradient *)strokeGradient
{
    if(strokeGradient == nil && parentNode != nil) {
        return parentNode.strokeGradient;
    }
    return strokeGradient;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGPattern *)strokePattern
{
    if(strokePattern == nil && parentNode != nil) {
        return parentNode.strokePattern;
    }
    return strokePattern;
}

@end
