//
//  IJSVGGroup.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGGroup.h"

@implementation IJSVGGroup

- (void)dealloc
{
    (void)([_childNodes release]), _childNodes = nil;
    [super dealloc];
}

- (id)init
{
    if ((self = [super init]) != nil) {
        _childNodes = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)prepareFromCopy
{
    if(_childNodes != nil) {
        (void)[_childNodes release], _childNodes = nil;
    }
    _childNodes = [[NSMutableArray alloc] init];
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGGroup* node = [super copyWithZone:zone];
    [node prepareFromCopy];

    for (IJSVGNode* childNode in _childNodes) {
        childNode = [[childNode copy] autorelease];
        childNode.parentNode = node;
        [node addChild:childNode];
    }
    return node;
}

- (void)purgeChildren
{
    [_childNodes removeAllObjects];
}

- (void)addChild:(IJSVGNode*)child
{
    if (child != nil) {
        [_childNodes addObject:child];
    }
}

- (NSArray<IJSVGNode*>*)childNodes
{
    return _childNodes;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ - %@",
            [super description], self.childNodes];
}

@end
