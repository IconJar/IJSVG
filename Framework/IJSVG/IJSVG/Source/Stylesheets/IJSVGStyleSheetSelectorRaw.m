//
//  IJSVGStyleSheetSelectorRaw.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetSelectorRaw.h>

@implementation IJSVGStyleSheetSelectorRaw

- (id)init
{
    if((self = [super init]) != nil) {
        _classes = [[NSMutableSet alloc] init];
        _combinator = IJSVGStyleSheetSelectorCombinatorDescendant;
        _combinatorString = @" ";
    }
    return self;
}

- (void)addClassName:(NSString*)className
{
    [_classes addObject:className];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"Combinator: %@, Tag: %@, Classes: %@, Identifier: %@",
            _combinatorString, _tag, _classes, _identifier];
}

@end
