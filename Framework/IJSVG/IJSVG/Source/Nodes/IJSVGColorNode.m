//
//  IJSVGColorNode.m
//  IJSVG
//
//  Created by Curtis Hard on 29/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColorNode.h>
#import <IJSVG/IJSVGStyle.h>

@implementation IJSVGColorNode

- (IJSVGNodeTypeTraits)nodeTraits
{
    return IJSVGNodeTypeTraitColor;
}

- (void)setColor:(CGColorRef)value
{
    CGColorRef retained = CGColorRetain(value);
    CGColorRelease(_color);
    _color = retained;
}

- (void)dealloc
{
    CGColorRelease(_color);
}

+ (IJSVGNode*)colorNodeWithColor:(CGColorRef)color
{
    return [[self alloc] initWithColor:color];
}

- (id)initWithColor:(CGColorRef)color
{
    if ((self = [super init]) != nil) {
        [self addTraits:IJSVGNodeTraitPaintable];
        _color = CGColorRetain(color);
    }
    return self;
}

- (void)applyPropertiesFromNode:(IJSVGNode*)node
{
    [super applyPropertiesFromNode:node];
    if ((node.nodeTraits & IJSVGNodeTypeTraitColor) != 0) {
        IJSVGColorNode* colorNode = (IJSVGColorNode*)node;
        self.color = colorNode.color;
        self.isNoneOrTransparent = colorNode.isNoneOrTransparent;
        self.contextPaint = colorNode.contextPaint;
        self.usesCurrentColor = colorNode.usesCurrentColor;
    }
}

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style matchingTraits:(IJSVGColorUsageTraits)traits
{
    IJSVGTraitedColorStorage* storage = [[IJSVGTraitedColorStorage alloc] init];
    if (self.isNoneOrTransparent == YES) {
        return storage;
    }

    CGColorRef color = self.color ?: IJSVGColor.blackColor;
    if ((traits & IJSVGColorUsageTraitFill) == IJSVGColorUsageTraitFill && style.fillColor != nil) {
        color = style.fillColor;
    } else if ((traits & IJSVGColorUsageTraitStroke) == IJSVGColorUsageTraitStroke && style.strokeColor != nil) {
        color = style.strokeColor;
    } else {
        CGColorRef replacement = [style.colors colorForColor:color matchingTraits:traits];
        color = replacement ?: color;
    }

    IJSVGTraitedColor* traited = nil;
    traited = [IJSVGTraitedColor colorWithColor:color traits:traits];
    [storage addColor:traited];
    return storage;
}

@end
