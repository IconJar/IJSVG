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
    (void)(classes), classes = nil;
    (void)(_identifier), _identifier = nil;
    (void)(_tag), _tag = nil;
    (void)(_combinatorString), _combinatorString = nil;
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
