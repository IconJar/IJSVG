//
//  IJSVGMask.m
//  IJSVG
//
//  Created by Curtis Hard on 28/05/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGMask.h>
#import <IJSVG/IJSVGRootNode.h>

@implementation IJSVGMask

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags64* storage = [[IJSVGBitFlags64 alloc] init];
    [storage addBits:[super allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeX];
    [storage setBit:IJSVGNodeAttributeY];
    [storage setBit:IJSVGNodeAttributeWidth];
    [storage setBit:IJSVGNodeAttributeHeight];
    [storage setBit:IJSVGNodeAttributeMaskUnits];
    [storage setBit:IJSVGNodeAttributeMaskContentUnits];
    return storage;
}

- (void)setDefaults
{
    [super setDefaults];
    self.x = [IJSVGUnitLength unitWithPercentageFloat:-.2f];
    self.y = [IJSVGUnitLength unitWithPercentageFloat:-.2f];
    self.width = [IJSVGUnitLength unitWithPercentageFloat:1.2f];
    self.height = [IJSVGUnitLength unitWithPercentageFloat:1.2f];
    self.units = IJSVGUnitObjectBoundingBox;
    self.contentUnits = IJSVGUnitUserSpaceOnUse;
    self.overflowVisibility = IJSVGOverflowVisibilityHidden;
}

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect *)bounds
{
    IJSVGNode* node = nil;
    IJSVGUnitType units = [self contentUnitsWithReferencingNode:&node];
    if(units == IJSVGUnitUserSpaceOnUse) {
        *bounds = node.rootNode.bounds;
    } else {
        *bounds = node.parentNode.bounds;
    }
    return units;
}

@end
