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

- (IJSVGWindingRule)clipRule
{
    // we store a flag about walking the tree is clipRule's
    // we inherit and walk up their parents tree in order to find a value,
    // due to that, this method can be called from its child and cause recursion
    // so if it is walking, just return its parent rule
    if(_isCurrentlyWalkingSubtree == YES) {
        return [super clipRule];
    }
    
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
    _isCurrentlyWalkingSubtree = YES;
    [IJSVGNode walkNodeTree:self
                    handler:handler];
    _isCurrentlyWalkingSubtree = NO;
    return rule;
}

@end
