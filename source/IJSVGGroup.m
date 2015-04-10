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

- (void)prepareFromCopy
{
    children = [[NSMutableArray alloc] init];
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGGroup * node = [super copyWithZone:zone];
    [node prepareFromCopy];
    
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
    if( child != nil )
        [children addObject:child];
}

- (NSArray *)children
{
    return children;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ - %ld",[super description],self.children.count];
}

@end
