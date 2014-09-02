//
//  IJSVGNode.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS( NSInteger, IJSVGWindingRule ) {
    IJSVGWindingRuleNonZero,
    IJSVGWindingRuleEvenOdd,
    IJSVGWindingRuleInherit
};

static CGFloat IJSVGInheritedFloatValue = -99.9999991;

@interface IJSVGNode : NSObject {
    
    CGFloat x;
    CGFloat y;
    CGFloat width;
    CGFloat height;
    
    NSColor * fillColor;
    NSColor * strokeColor;
    
    CGFloat opacity;
    CGFloat strokeWidth;
    CGFloat fillOpacity;
    CGFloat strokeOpacity;
    
    NSString * identifier;
    
    IJSVGNode * parentNode;
    NSArray * transforms;
    
    IJSVGWindingRule windingRule;
    
}

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
@property ( nonatomic, assign ) IJSVGWindingRule windingRule;
@property ( nonatomic, retain ) NSArray * transforms;

@end
