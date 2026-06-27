//
//  IJSVGStyleSheetRule.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetRule.h>

@implementation IJSVGStyleSheetRule

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
