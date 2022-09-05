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

+ (NSIndexSet*)allowedAttributes
{
    NSMutableIndexSet* set = [[NSMutableIndexSet alloc] init];
    [set addIndexes:[super allowedAttributes]];
    [set addIndex:IJSVGNodeAttributeX];
    [set addIndex:IJSVGNodeAttributeY];
    [set addIndex:IJSVGNodeAttributeWidth];
    [set addIndex:IJSVGNodeAttributeHeight];
    [set addIndex:IJSVGNodeAttributeMaskUnits];
    [set addIndex:IJSVGNodeAttributeMaskContentUnits];
    return set;
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
