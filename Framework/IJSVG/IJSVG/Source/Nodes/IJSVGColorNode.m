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

+ (IJSVGNode*)colorNodeWithColor:(NSColor *)color
{
    return [[self alloc] initWithColor:color];
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

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style
                              matchingTraits:(IJSVGColorUsageTraits)traits
{
    IJSVGTraitedColorStorage* storage = [[IJSVGTraitedColorStorage alloc] init];
    if(self.isNoneOrTransparent == YES) {
        return storage;
    }

    NSColor* color = self.color ?: NSColor.blackColor;
    if((traits & IJSVGColorUsageTraitFill) == IJSVGColorUsageTraitFill &&
       style.fillColor != nil) {
        color = style.fillColor;
    } else if((traits & IJSVGColorUsageTraitStroke) == IJSVGColorUsageTraitStroke &&
              style.strokeColor != nil) {
        color = style.strokeColor;
    } else {
        NSColor* replacement = [style.colors colorForColor:color
                                            matchingTraits:traits];
        color = replacement ?: color;
    }

    IJSVGTraitedColor* traited = nil;
    traited = [IJSVGTraitedColor colorWithColor:color
                                         traits:traits];
    [storage addColor:traited];
    return storage;
}

@end
