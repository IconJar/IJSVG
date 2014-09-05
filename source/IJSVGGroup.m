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
    [children release], children = nil;
    [super dealloc];
}

- (id)init
{
    if( ( self = [super init] ) != nil )
    {
        children = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGGroup * node = [[self class] allocWithZone:zone];
    for( IJSVGNode * childNode in self.children )
    {
        childNode = [[childNode copy] autorelease];
        childNode.parentNode = node;
        [node addChild:childNode];
    }
    return node;
}

- (void)purgeChildren
{
    [children removeAllObjects];
}

- (void)addChild:(id)child
{
    [children addObject:child];
}

- (NSArray *)children
{
    return children;
}

@end
