//
//  IJSVGStyleSheetSelectorRaw.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGStyleSheetSelectorRaw.h"

@implementation IJSVGStyleSheetSelectorRaw

@synthesize classes;

- (void)dealloc
{
    (void)([classes release]), classes = nil;
    (void)([_identifier release]), _identifier = nil;
    (void)([_tag release]), _tag = nil;
    (void)([_combinatorString release]), _combinatorString = nil;
    [super dealloc];
}

- (id)init
{
    if ((self = [super init]) != nil) {
        classes = [[NSMutableArray alloc] init];
        _combinator = IJSVGStyleSheetSelectorCombinatorDescendant;
        _combinatorString = @" ";
    }
    return self;
}

- (void)addClassName:(NSString*)className
{
    [classes addObject:className];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"Combinator: %@, Tag: %@, Classes: %@, Identifier: %@",
            _combinatorString, _tag, classes, _identifier];
}

@end
