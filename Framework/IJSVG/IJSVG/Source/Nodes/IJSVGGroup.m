//
//  IJSVGGroup.m
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGImage.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGGroup

- (IJSVGNodeTypeTraits)nodeTraits
{
    return IJSVGNodeTypeTraitPaint | IJSVGNodeTypeTraitGraphics | IJSVGNodeTypeTraitViewport | IJSVGNodeTypeTraitGroup;
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeGroup;
}

- (id)init
{
    if ((self = [super init]) != nil) {
        _children = [[NSMutableArray alloc] init];
    }
    return self;
}

- (BOOL)containsRelativeUnits
{
    if ([super containsRelativeUnits] == YES) {
        return YES;
    }
    for (IJSVGNode* node in self.children) {
        if (node.containsRelativeUnits == YES) {
            return YES;
        }
    }
    return NO;
}

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style
{
    IJSVGTraitedColorStorage* storage = [super colorsWithStyle:style];
    if (self.shouldRender == NO) {
        return storage;
    }
    for (IJSVGNode* node in self.children) {
        [storage unionColorStorage:[node colorsWithStyle:style]];
    }
    return storage;
}

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style matchingTraits:(IJSVGColorUsageTraits)traits
{
    IJSVGTraitedColorStorage* storage = [self colorsWithStyle:style];
    [storage addTraits:traits];
    return storage;
}

- (void)prepareFromCopy
{
    _children = [[NSMutableArray alloc] init];
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGGroup* node = [super copyWithZone:zone];
    [node prepareFromCopy];

    for (__strong IJSVGNode* childNode in _children) {
        childNode = childNode.copy;

        // A copied child must not remove itself from the source group.
        childNode.parentNode = nil;
        [node addChild:childNode];
    }
    return node;
}

- (void)addChild:(IJSVGNode*)child
{
    if (child == nil || child == self) {
        return;
    }

    // Read the current parent once. Parsing adds every node through here.
    IJSVGGraphicsNode* parent = child.parentNode;
    if (parent == self && [_children containsObject:child]) {
        return;
    }

    if ((parent.nodeTraits & IJSVGNodeTypeTraitGroup) != 0 && parent != self) {
        [(IJSVGGroup*)parent removeChild:child];
    }

    child.parentNode = self;
    [_children addObject:child];
}

- (void)removeChild:(IJSVGNode*)child
{
    if (child.parentNode == self) {
        [child detach];
    }
    [_children removeObject:child];
}

// Snapshots the input because changing parent links can mutate the supplied
// array.
- (void)addChildren:(NSArray<IJSVGNode*>*)children
{
    for (IJSVGNode* node in [children copy]) {
        [self addChild:node];
    }
}

// Snapshots the input because changing parent links can mutate the supplied
// array.
- (void)removeChildren:(NSArray<IJSVGNode*>*)children
{
    for (IJSVGNode* node in [children copy]) {
        [self removeChild:node];
    }
}

- (BOOL)childrenMatchTraits:(IJSVGNodeTraits)traits
{
    for (IJSVGNode* node in self.children) {
        if ([node matchesTraits:traits] == NO) {
            return NO;
        }
    }
    return YES;
}

- (NSArray<IJSVGNode*>*)childrenOfType:(IJSVGNodeType)type
{
    NSMutableArray<IJSVGNode*>* nodes = [[NSMutableArray alloc] init];
    for (IJSVGNode* node in self.children) {
        if (node.type == type) {
            [nodes addObject:node];
        }
    }
    return nodes;
}

- (NSSet<IJSVGNode*>*)childSetOfType:(IJSVGNodeType)type
{
    NSMutableSet<IJSVGNode*>* nodes = [[NSMutableSet alloc] init];
    for (IJSVGNode* node in self.children) {
        if (node.type == type) {
            [nodes addObject:node];
        }
    }
    return nodes;
}

- (BOOL)containsNodesMatchingTraits:(IJSVGNodeTraits)traits
{
    return [self.class node:self containsNodesMatchingTraits:traits];
}

- (NSArray<IJSVGNode*>*)nodesMatchingTraits:(IJSVGNodeTraits)traits
{
    return [self.class node:self nodesMatchingTraits:traits];
}

- (CGRect)bounds
{
    CGRect rect = CGRectNull;
    for (IJSVGNode* node in self.children) {
        CGRect childBounds = node.bounds;
        if (CGRectIsNull(childBounds)) {
            continue;
        }
        if (CGRectIsNull(rect)) {
            rect = childBounds;
        } else {
            rect = CGRectUnion(rect, childBounds);
        }
    }
    return rect;
}

- (NSArray<IJSVGNode*>*)children
{
    return _children;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ - %@", [super description], self.children];
}

@end

#pragma mark - Parsing

@implementation IJSVGGroup (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGeometryInheritance(self, context);
    IJSVGParsePathAttributes(self, context);
    NSString* geometryValue = nil;
    if (IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeX, &geometryValue)) {
        self.x = [IJSVGUnitLength unitWithString:geometryValue];
    }
    if (IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeY, &geometryValue)) {
        self.y = [IJSVGUnitLength unitWithString:geometryValue];
    }
    IJSVGParseBackgroundAttributes(self, context);
    IJSVGParseFilterColorInterpolation(self, context);
    IJSVGParsePaintAttributes(self, context);
    IJSVGParseEffectsAttributes(self, context);
    IJSVGParseTransformAttributes(self, context);
    IJSVGParseDisplayAttributes(self, context);
    IJSVGParseOverflowAttributes(self, context);
    IJSVGParseMarkersAttributes(self, context);
}

@end
