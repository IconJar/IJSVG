//
//  IJSVGClipPath.m
//  IJSVG
//
//  Created by Curtis Hard on 29/05/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGClipPath.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGText.h>

static BOOL IJSVGClipPathSupportsNode(IJSVGNode* node)
{
    if([node matchesTraits:IJSVGNodeTraitPathed] || [node isKindOfClass:IJSVGText.class]) {
        return YES;
    }
    if(node.type != IJSVGNodeTypeUse) {
        return NO;
    }
    for(IJSVGNode* child in ((IJSVGGroup*)node).children) {
        if(!IJSVGClipPathSupportsNode(child)) {
            return NO;
        }
    }
    return YES;
}

@implementation IJSVGClipPath

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeClipPath;
}

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* storage = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
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
    for(IJSVGNode* child in self.children.copy) {
        if(!IJSVGClipPathSupportsNode(child)) {
            [self removeChild:child];
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
