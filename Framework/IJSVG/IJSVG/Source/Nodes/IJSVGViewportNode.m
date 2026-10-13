//
//  IJSVGViewportNode.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGViewportNode.h>

@implementation IJSVGViewportNode

- (void)applyPropertiesFromNode:(IJSVGNode*)source
{
    [super applyPropertiesFromNode:source];
    if ([source isKindOfClass:IJSVGViewportNode.class]) {
        IJSVGViewportNode* node = (IJSVGViewportNode*)source;
        self.viewBox = node.viewBox;
        self.viewBoxAlignment = node.viewBoxAlignment;
        self.viewBoxMeetOrSlice = node.viewBoxMeetOrSlice;
    }
}

@end
