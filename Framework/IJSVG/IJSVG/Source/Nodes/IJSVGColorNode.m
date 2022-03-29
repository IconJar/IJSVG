//
//  IJSVGColorNode.m
//  IJSVG
//
//  Created by Curtis Hard on 29/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGColorNode.h"

@implementation IJSVGColorNode

- (void)dealloc
{
    (void)[_color release], _color = nil;
    [super dealloc];
}

+ (IJSVGNode*)colorNodeWithColor:(NSColor *)color
{
    return [[[self alloc] initWithColor:color] autorelease];
}

- (id)initWithColor:(NSColor*)color {
    if((self = [super init]) != nil) {
        [self addTraits:IJSVGNodeTraitPaintable];
        self.color = color;
    }
    return self;
}

- (void)applyPropertiesFromNode:(IJSVGNode*)node
{
    if([node isKindOfClass:self.class]) {
        self.color = ((IJSVGColorNode*)node).color;
    }
}

@end
