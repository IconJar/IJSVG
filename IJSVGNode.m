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

@synthesize type;
@synthesize name;
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
@synthesize windingRule;
@synthesize def;
@synthesize fillGradient;
@synthesize clipPath;

- (void)dealloc
{
    [fillGradient release], fillGradient = nil;
    [transforms release], transforms = nil;
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
    if( [string isEqualToString:@"clippath"] )
        return IJSVGNodeTypeClipPath;
    return IJSVGNodeTypeNotFound;
}

- (id)init
{
    if( ( self = [self initWithDef:YES] ) != nil )
    {
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGNode * node = [[self class] allocWithZone:zone];
    node.name = self.name;
    node.type = self.type;
    
    node.x = self.x;
    node.y = self.y;
    node.width = self.width;
    node.height = self.height;
    
    node.fillGradient = self.fillGradient;
    
    node.fillColor = self.fillColor;
    node.strokeColor = self.strokeColor;
    node.clipPath = self.clipPath;
    
    node.opacity = self.opacity;
    node.strokeWidth = self.strokeWidth;
    node.fillOpacity = self.fillOpacity;
    node.strokeOpacity = self.strokeOpacity;
    
    node.identifier = self.identifier;
    
    node.transforms = self.transforms;
    node.def = self.def;
    node.windingRule = self.windingRule;
    node.parentNode = self.parentNode;
    
    return node;
}

- (id)initWithDef:(BOOL)flag
{
    if( ( self = [super init] ) != nil )
    {
        self.opacity = 0.f;
        self.fillOpacity = 1.f;
        self.strokeOpacity = 1.f;
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
    switch(windingRule)
    {
        case IJSVGWindingRuleEvenOdd:
            return NSEvenOddWindingRule;
        case IJSVGWindingRuleNonZero:
            return NSNonZeroWindingRule;
        case IJSVGWindingRuleInherit:
            if( parentNode != nil )
                return parentNode.windingRule;
    }
    return IJSVGWindingRuleNonZero;
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