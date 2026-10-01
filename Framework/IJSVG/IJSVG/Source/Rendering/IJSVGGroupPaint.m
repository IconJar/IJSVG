//
//  IJSVGGroupPaint.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGGroupPaint.h>

@implementation IJSVGGroupPaint

- (CGRect)innerBoundingBox
{
    return self.outerBoundingBox;
}

@end
