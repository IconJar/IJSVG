//
//  IJSVGNode.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGNode.h"
#import "IJSVGDef.h"

@implementation IJSVGNode

@synthesize shouldRender;
@synthesize type;
@synthesize name;
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
@synthesize transforms;
@synthesize gradientTransforms;
@synthesize windingRule;
@synthesize def;
@synthesize fillGradient;
@synthesize clipPath;
@synthesize lineCapStyle;
@synthesize lineJoinStyle;
@synthesize strokeDashArrayCount;
@synthesize strokeDashArray;
@synthesize strokeDashOffset;
@synthesize usesDefaultFillColor;

- (void)dealloc
{
    free(strokeDashArray);
    [unicode release], unicode = nil;
    [fillGradient release], fillGradient = nil;
    [transforms release], transforms = nil;
    [gradientTransforms release], gradientTransforms = nil;
    [fillColor release], fillColor = nil;
    [strokeColor release], strokeColor = nil;
    [identifier release], identifier = nil;
    [def release], def = nil;
    [name release], name = nil;
    [super dealloc];
}

+ (IJSVGNodeType)typeForString:(NSString *)string
{
    string = [string lowercaseString];
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
    return IJSVGNodeTypeNotFound;
}

- (id)init
{
    if( ( self = [self initWithDef:YES] ) != nil )
    {
    }
    return self;
}

- (void)applyPropertiesFromNode:(IJSVGNode *)node
{
    self.name = node.name;
    self.type = node.type;
    self.unicode = node.unicode;
    
    self.x = node.x;
    self.y = node.y;
    self.width = node.width;
    self.height = node.height;
    
    self.fillGradient = node.fillGradient;
    
    self.fillColor = node.fillColor;
    self.strokeColor = node.strokeColor;
    self.clipPath = node.clipPath;
    
    self.opacity = node.opacity;
    self.strokeWidth = node.strokeWidth;
    self.fillOpacity = node.fillOpacity;
    self.strokeOpacity = node.strokeOpacity;
    
    self.identifier = node.identifier;
    self.usesDefaultFillColor = node.usesDefaultFillColor;
    
    self.transforms = node.transforms;
    self.gradientTransforms = node.gradientTransforms;
    self.def = node.def;
    self.windingRule = node.windingRule;
    self.lineCapStyle = node.lineCapStyle;
    self.lineJoinStyle = node.lineJoinStyle;
    self.parentNode = node.parentNode;
    
    self.shouldRender = node.shouldRender;
    
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
        self.opacity = 0.f;
        self.fillOpacity = 1.f;
        self.strokeOpacity = 1.f;
        self.strokeDashOffset = 0.f;
        self.shouldRender = YES;
        self.strokeWidth = IJSVGInheritedFloatValue;
        self.windingRule = IJSVGWindingRuleInherit;
        self.lineCapStyle = IJSVGLineCapStyleInherit;
        self.lineJoinStyle = IJSVGLineJoinStyleInherit;
        if( flag )
            def = [[IJSVGDef alloc] init];
    }
    return self;
}

- (IJSVGDef *)defForID:(NSString *)anID
{
    IJSVGDef * aDef = nil;
    if( (aDef = [def defForID:anID]) != nil )
        return aDef;
    if( parentNode != nil )
        return [parentNode defForID:anID];
    return nil;
}

- (void)addDef:(IJSVGNode *)aDef
{
    [def addDef:aDef];
}

// winding rule can inherit..
- (IJSVGWindingRule)windingRule
{
    if( windingRule == IJSVGWindingRuleInherit && parentNode != nil )
        return parentNode.windingRule;
    return windingRule;
}

- (IJSVGLineCapStyle)lineCapStyle
{
    if( lineCapStyle == IJSVGLineCapStyleInherit )
    {
        if( parentNode != nil )
            return parentNode.lineCapStyle;
    }
    return lineCapStyle;
}

- (IJSVGLineJoinStyle)lineJoinStyle
{
    if( lineJoinStyle == IJSVGLineJoinStyleInherit )
    {
        if( parentNode != nil )
            return parentNode.lineJoinStyle;
    }
    return lineJoinStyle;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (CGFloat)opacity
{
    if( opacity == IJSVGInheritedFloatValue && parentNode != nil )
        return parentNode.opacity;
    if( opacity != 0.f )
        return opacity;
    return 0.f;
}

- (CGFloat)fillOpacity
{
    if( fillOpacity == IJSVGInheritedFloatValue && parentNode != nil )
        return parentNode.fillOpacity;
    if( fillOpacity != 0.f )
        return fillOpacity;
    return 0.f;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (CGFloat)strokeWidth
{
    if( strokeWidth == IJSVGInheritedFloatValue && parentNode != nil )
        return parentNode.strokeWidth;
    if( strokeWidth != 0.f )
        return strokeWidth;
    return 0;
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

- (CGFloat)strokeOpacity
{
    if( strokeOpacity == IJSVGInheritedFloatValue && parentNode != nil )
        return parentNode.strokeOpacity;
    if( strokeOpacity != 0.f )
        return strokeOpacity;
    return 0.f;
}

// even though the spec explicity states fill color
// must be on the path, it can also be on the
- (NSColor *)fillColor
{
    if( fillColor == nil && parentNode != nil )
        return parentNode.fillColor;
    return fillColor;
}

@end