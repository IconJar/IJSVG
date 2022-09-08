//
//  IJSVGClipPath.m
//  IJSVG
//
//  Created by Curtis Hard on 29/05/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGClipPath.h>
#import <IJSVG/IJSVGRootNode.h>

@implementation IJSVGClipPath

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags64* storage = [[IJSVGBitFlags64 alloc] init];
    [storage addBits:[super allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeX];
    [storage setBit:IJSVGNodeAttributeY];
    [storage setBit:IJSVGNodeAttributeWidth];
    [storage setBit:IJSVGNodeAttributeHeight];
    [storage setBit:IJSVGNodeAttributeClipPathUnits];
    [storage setBit:IJSVGNodeAttributeClipRule];
    return storage;
}

- (void)setDefaults
{
    self.units = IJSVGUnitObjectBoundingBox;
    self.contentUnits = IJSVGUnitUserSpaceOnUse;
    self.windingRule = IJSVGWindingRuleNonZero;
    self.overflowVisibility = IJSVGOverflowVisibilityHidden;
    self.fill = [IJSVGColorNode colorNodeWithColor:NSColor.whiteColor];
}

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect*)bounds
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

- (void)postProcess
{
    // clip paths only allow shapes in them, nothing else, we can simply
    // check the node types for the trait of pathed
    IJSVGNodeTraits childTraits = IJSVGNodeTraitPathed;
    for(IJSVGNode* childNode in self.children.copy) {
        if([childNode matchesTraits:childTraits] == NO) {
            BOOL remove = YES;
            IJSVGNodeType type = childNode.type;
            if(type == IJSVGNodeTypeUse) {
                remove = [(IJSVGGroup*)childNode childrenMatchTraits:childTraits] == NO;
            }
            if(remove == YES) {
                [self removeChild:childNode];
            }
        }
    }
}

- (IJSVGWindingRule)computedClipRule
{
    // find the first use of a clipRule that is useful
    __block IJSVGWindingRule rule = IJSVGWindingRuleInherit;
    __weak IJSVGClipPath* weakSelf = self;
    IJSVGNodeWalkHandler handler = ^(IJSVGNode *node, BOOL *allowChildNodes,
                                     BOOL *stop) {
        if(node == weakSelf) {
            return;
        }
        IJSVGWindingRule clipRule = node.clipRule;
        if(clipRule != IJSVGWindingRuleInherit) {
            rule = clipRule;
            *stop = YES;
        }
    };
    [IJSVGNode walkNodeTree:self
                    handler:handler];
    return rule;
}

@end
