//
//  IJSVGFilter.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGFilterEffect.h>

@implementation IJSVGFilter

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* storage = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
    [storage addBits:[IJSVGNode allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeX];
    [storage setBit:IJSVGNodeAttributeY];
    [storage setBit:IJSVGNodeAttributeWidth];
    [storage setBit:IJSVGNodeAttributeHeight];
    [storage setBit:IJSVGNodeAttributeFilterUnits];
    [storage setBit:IJSVGNodeAttributePrimitiveUnits];
    return storage;
}

- (void)setDefaults
{
    [super setDefaults];
    self.x = [IJSVGUnitLength unitWithPercentageFloat:-.1f];
    self.y = [IJSVGUnitLength unitWithPercentageFloat:-.1f];
    self.width = [IJSVGUnitLength unitWithPercentageFloat:1.2f];
    self.height = [IJSVGUnitLength unitWithPercentageFloat:1.2f];
    self.units = IJSVGUnitObjectBoundingBox;
    self.contentUnits = IJSVGUnitUserSpaceOnUse;
    self.shouldRender = NO;
}

- (NSArray<IJSVGFilterPrimitive*>*)primitives
{
    NSMutableArray<IJSVGFilterPrimitive*>* primitives = [[NSMutableArray alloc] init];
    for(IJSVGNode* node in self.children) {
        if([node isKindOfClass:IJSVGFilterPrimitive.class]) {
            [primitives addObject:(IJSVGFilterPrimitive*)node];
        }
    }
    return primitives.copy;
}

- (NSSet<NSString*>*)inputNames
{
    NSMutableSet<NSString*>* inputNames = [[NSMutableSet alloc] init];
    for(IJSVGFilterPrimitive* primitive in self.primitives) {
        if(primitive.input != nil) {
            [inputNames addObject:primitive.input];
        }
        if(primitive.input2 != nil) {
            [inputNames addObject:primitive.input2];
        }
        for(IJSVGFilterPrimitive* child in primitive.children) {
            if(child.input != nil) {
                [inputNames addObject:child.input];
            }
        }
    }
    return inputNames.copy;
}

- (BOOL)requiresSupersampling
{
    for(IJSVGFilterPrimitive* primitive in self.primitives) {
        IJSVGFilterEffect* effect = [IJSVGFilterEffect effectForType:primitive.type];
        if([effect requiresSupersamplingForPrimitive:primitive]) {
            return YES;
        }
    }
    return NO;
}

@end
