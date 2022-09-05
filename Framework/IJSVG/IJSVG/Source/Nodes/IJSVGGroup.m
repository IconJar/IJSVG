//
//  IJSVGGroup.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGImage.h>

@implementation IJSVGGroup

- (id)init
{
    if((self = [super init]) != nil) {
        _children = [[NSMutableArray alloc] init];
    }
    return self;
}

+ (NSIndexSet*)allowedAttributes
{
    NSMutableIndexSet* set = [[NSMutableIndexSet alloc] init];
    [set addIndexes:[super allowedAttributes]];
    [set addIndexes:[IJSVGPath allowedAttributes]];
    [set addIndexes:[IJSVGImage allowedAttributes]];
    return set;
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
        childNode.parentNode = node;
        [node addChild:childNode];
    }
    return node;
}

- (void)addChild:(IJSVGNode*)child
{
    if(child == nil || child == self ||
       (child.parentNode == self && [_children containsObject:child])) {
        return;
    }
    child.parentNode = self;
    [_children addObject:child];
}

- (void)removeChild:(IJSVGNode*)child
{
    if(child.parentNode == self) {
        [child detach];
    }
    [_children removeObject:child];
}

- (void)addChildren:(NSArray<IJSVGNode*>*)children
{
    for(IJSVGNode* node in children) {
        [self addChild:node];
    }
}

- (void)removeChildren:(NSArray<IJSVGNode*>*)children
{
    for(IJSVGNode* node in children) {
        [self removeChild:node];
    }
}

- (BOOL)childrenMatchTraits:(IJSVGNodeTraits)traits
{
    for(IJSVGNode* node in _children) {
        if([node matchesTraits:traits] == NO) {
            return NO;
        }
    }
    return YES;
}

- (NSSet<IJSVGNode*>*)childrenOfType:(IJSVGNodeType)type
{
    NSMutableSet<IJSVGNode*>* nodes = [[NSMutableSet alloc] init];
    for(IJSVGNode* node in self.children) {
        if(node.type == type) {
            [nodes addObject:node];
        }
    }
    return nodes;
}

- (BOOL)containsNodesMatchingTraits:(IJSVGNodeTraits)traits
{
    return [self.class node:self
containsNodesMatchingTraits:traits];
}

- (NSArray<IJSVGNode*>*)nodesMatchingTraits:(IJSVGNodeTraits)traits
{
    return [self.class node:self
        nodesMatchingTraits:traits];
}

- (CGRect)bounds
{
    CGRect rect = CGRectNull;
    for(IJSVGNode* node in self.children) {
        if(CGRectIsNull(rect)) {
            rect = node.bounds;
        } else {
            rect = CGRectUnion(rect, node.bounds);
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
    return [NSString stringWithFormat:@"%@ - %@",
            [super description], self.children];
}

@end
