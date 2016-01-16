//
//  IJSVGStyleSheetSelectorRaw.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGStyleSheetSelectorRaw.h"

@implementation IJSVGStyleSheetSelectorRaw

@synthesize classes, identifier, tag;

- (void)dealloc
{
    [classes release], classes = nil;
    [identifier release], identifier = nil;
    [tag release], tag = nil;
    [super dealloc];
}

- (id)init
{
    if( ( self = [super init] ) != nil )
    {
        classes = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addClassName:(NSString *)className
{
    [classes addObject:className];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Tag: %@, Classes: %@, Identifier: %@", tag, classes, identifier];
}

@end
