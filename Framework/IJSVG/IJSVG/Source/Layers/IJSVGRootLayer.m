//
//  IJSVGRootLayer.m
//  IJSVG
//
//  Created by Curtis Hard on 15/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGRootLayer.h"

@implementation IJSVGRootLayer

- (void)performRenderInContext:(CGContextRef)ctx
{
    if(self.viewBox != nil) {
        CGRect viewBox = [self.viewBox computeValue:CGSizeZero];
        dispatch_block_t drawingBlock = ^{
            [super performRenderInContext:ctx];
        };
        [IJSVGViewBox drawViewBox:viewBox
                           inRect:self.boundingBoxBounds
                        alignment:self.viewBoxAlignment
                      meetOrSlice:self.viewBoxMeetOrSlice
                        inContext:ctx
                     drawingBlock:drawingBlock];
        return;
    }
    [super performRenderInContext:ctx];
}

@end
