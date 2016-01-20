//
//  IJSVGStyleSheetRule.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGStyleSheetRule.h"

@implementation IJSVGStyleSheetRule

@synthesize selectors, style;

- (void)dealloc
{
    [selectors release], selectors = nil;
    [style release], style = nil;
    [super dealloc];
}

- (BOOL)matchesNode:(IJSVGNode *)node
           selector:(IJSVGStyleSheetSelector **)matchedSelector
{
    // interate over each select and work out if
    // it allows us to be applied
    for(IJSVGStyleSheetSelector * selector in selectors) {
        if([selector matchesNode:node]) {
            *matchedSelector = selector;
            return YES;
        }
    }
    return NO;
}

@end
