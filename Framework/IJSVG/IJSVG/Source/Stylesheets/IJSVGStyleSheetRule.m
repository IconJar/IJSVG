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
    // interate over each select and work out if
    // it allows us to be applied
    for (IJSVGStyleSheetSelector* selector in _selectors) {
        if ([selector matchesNode:node]) {
            *matchedSelector = selector;
            return YES;
        }
    }
    return NO;
}

@end
