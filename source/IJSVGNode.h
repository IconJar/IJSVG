//
//  IJSVGNode.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGStyle.h"

@class IJSVGDef;
@class IJSVGGradient;
@class IJSVGGroup;

typedef NS_OPTIONS( NSInteger, IJSVGNodeType ) {
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
    IJSVGNodeTypeNotFound,
};

typedef NS_OPTIONS( NSInteger, IJSVGWindingRule ) {
    IJSVGWindingRuleNonZero,
    IJSVGWindingRuleEvenOdd,
    IJSVGWindingRuleInherit
};

typedef  NS_OPTIONS( NSInteger, IJSVGLineCapStyle ) {
    IJSVGLineCapStyleButt,
    IJSVGLineCapStyleRound,
    IJSVGLineCapStyleSquare,
    IJSVGLineCapStyleInherit
};

typedef NS_OPTIONS( NSInteger, IJSVGLineJoinStyle ) {
    IJSVGLineJoinStyleMiter,
    IJSVGLineJoinStyleRound,
    IJSVGLineJoinStyleBevel,
    IJSVGLineJoinStyleInherit
};

static CGFloat IJSVGInheritedFloatValue = -99.9999991;

@interface IJSVGNode : NSObject <NSCopying> {
    
    IJSVGNodeType type;
    NSString * name;
    NSString * unicode;
    
    CGFloat x;
    CGFloat y;
    CGFloat width;
    CGFloat height;
    
    IJSVGGradient * fillGradient;
    
    BOOL usesDefaultFillColor;
    BOOL shouldRender;
    
    NSColor * fillColor;
    NSColor * strokeColor;
    
    CGFloat opacity;
    CGFloat strokeWidth;
    CGFloat fillOpacity;
    CGFloat strokeOpacity;
    
    CGFloat * strokeDashArray;
    NSInteger strokeDashArrayCount;
    CGFloat strokeDashOffset;
    
    NSString * identifier;
    
    IJSVGNode * parentNode;
    IJSVGGroup * clipPath;
    NSArray * transforms;
    
    IJSVGWindingRule windingRule;
    IJSVGLineCapStyle lineCapStyle;
    IJSVGLineJoinStyle joinStyle;
    
    IJSVGDef * def;
    
}

@property ( nonatomic, assign ) IJSVGNodeType type;
@property ( nonatomic, copy ) NSString * name;
@property ( nonatomic, copy ) NSString * unicode;
@property ( nonatomic, assign ) BOOL shouldRender;
@property ( nonatomic, assign ) BOOL usesDefaultFillColor;
@property ( nonatomic, assign ) CGFloat x;
@property ( nonatomic, assign ) CGFloat y;
@property ( nonatomic, assign ) CGFloat width;
@property ( nonatomic, assign ) CGFloat height;
@property ( nonatomic, assign ) CGFloat opacity;
@property ( nonatomic, assign ) CGFloat fillOpacity;
@property ( nonatomic, assign ) CGFloat strokeOpacity;
@property ( nonatomic, assign ) CGFloat strokeWidth;
@property ( nonatomic, retain ) NSColor * fillColor;
@property ( nonatomic, retain ) NSColor * strokeColor;
@property ( nonatomic, copy ) NSString * identifier;
@property ( nonatomic, assign ) IJSVGNode * parentNode;
@property ( nonatomic, assign ) IJSVGGroup * clipPath;
@property ( nonatomic, assign ) IJSVGWindingRule windingRule;
@property ( nonatomic, assign ) IJSVGLineCapStyle lineCapStyle;
@property ( nonatomic, assign ) IJSVGLineJoinStyle lineJoinStyle;
@property ( nonatomic, retain ) NSArray * transforms;
@property ( nonatomic, retain ) IJSVGDef * def;
@property ( nonatomic, retain ) IJSVGGradient * fillGradient;
@property ( nonatomic, assign ) CGFloat * strokeDashArray;
@property ( nonatomic, assign ) NSInteger strokeDashArrayCount;
@property ( nonatomic, assign ) CGFloat strokeDashOffset;

+ (IJSVGNodeType)typeForString:(NSString *)string;

- (void)applyPropertiesFromNode:(IJSVGNode *)node;
- (id)initWithDef:(BOOL)flag;
- (void)addDef:(IJSVGNode *)aDef;
- (IJSVGDef *)defForID:(NSString *)anID;

@end
