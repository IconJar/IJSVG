//
//  IJSVGGroupPaint.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGGroupPaint.h>
#import <IJSVGFilterPaint.h>

@implementation IJSVGGroupPaint

- (void)performRenderInContext:(CGContextRef)ctx
{
    if(self.sourceNode != nil && !CGRectIsNull(self.sourceNode.backgroundRect)) {
        [IJSVGFilterPaint drawBackgroundForPaint:self context:ctx
                                    drawingBlock:^(CGContextRef bitmap) {
            [self drawContentsInContext:bitmap];
        }];
    } else {
        [super performRenderInContext:ctx];
    }
}

- (CGRect)innerBoundingBox
{
    return self.outerBoundingBox;
}

@end
