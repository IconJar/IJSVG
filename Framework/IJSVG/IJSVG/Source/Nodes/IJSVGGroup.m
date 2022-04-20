//
//  IJSVGGroup.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGGroup.h"

@implementation IJSVGGroup

- (id)init
{
    if ((self = [super init]) != nil) {
        _children = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)prepareFromCopy
{
    if(_children != nil) {
        (void)_children, _children = nil;
    }
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
    if(child == nil || (child.parentNode == self && [_children containsObject:child])) {
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

- (CGRect)bounds
{
    CGRect rect = CGRectZero;
    for(IJSVGNode* node in self.children) {
        rect = CGRectUnion(rect, node.bounds);
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
