//
//  IJSVGStyleSheetRule.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGStyleSheetRule.h>

@implementation IJSVGStyleSheetRule

- (void)addMatchingSelector:(IJSVGStyleSheetSelector*)selector
{
    IJSVGStyleSheetSelectorRaw* matchingSelector = selector.matchingSelector;
    if(matchingSelector.identifier != nil) {
        if(_matchingIdentifiers == nil) {
            _matchingIdentifiers = [[NSMutableSet alloc] init];
        }
        [_matchingIdentifiers addObject:matchingSelector.identifier];
        return;
    }

    if(matchingSelector.classes.count != 0) {
        if(_matchingClassNames == nil) {
            _matchingClassNames = [[NSMutableSet alloc] init];
        }
        [_matchingClassNames unionSet:matchingSelector.classes];
        return;
    }

    if(matchingSelector.tag != nil) {
        if(_matchingTagNames == nil) {
            _matchingTagNames = [[NSMutableSet alloc] init];
        }
        [_matchingTagNames addObject:matchingSelector.tag];
        return;
    }

    _matchesUniversalSelector = YES;
}

- (BOOL)canMatchNode:(IJSVGNode*)node
{
    if(_matchesUniversalSelector == YES) {
        return YES;
    }
    if(node.identifier != nil && [_matchingIdentifiers containsObject:node.identifier] == YES) {
        return YES;
    }
    if(node.name != nil && [_matchingTagNames containsObject:node.name] == YES) {
        return YES;
    }
    for(NSString* className in node.classNameList) {
        if([_matchingClassNames containsObject:className] == YES) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)matchesNode:(IJSVGNode*)node
           selector:(IJSVGStyleSheetSelector**)matchedSelector
{
    IJSVGStyleSheetSelector* bestSelector = nil;
    for (IJSVGStyleSheetSelector* selector in _selectors) {
        if([selector matchesNode:node] == YES &&
           (bestSelector == nil || selector.specificity > bestSelector.specificity)) {
            bestSelector = selector;
        }
    }

    if(bestSelector != nil) {
        *matchedSelector = bestSelector;
        return YES;
    }
    return NO;
}

@end
