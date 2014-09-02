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

- (void)addChild:(id)child
{
    [children addObject:child];
}

- (NSArray *)children
{
    return children;
}

@end
