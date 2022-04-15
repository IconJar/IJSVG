//
//  IJSVGGroupLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGGroupLayer.h"
#import "IJSVGViewBox.h"
#import "IJSVGUnitRect.h"
#import "IJSVGLayer.h"

@implementation IJSVGGroupLayer

- (void)performRenderInContext:(CGContextRef)ctx
{
    if(_viewBox != nil) {
        CGRect subLayerBounds = [IJSVGLayer calculateFrameForSublayers:self.sublayers];
        CGRect viewBox = [_viewBox computeValue:CGSizeZero];
        dispatch_block_t drawingBlock = ^{
            [super performRenderInContext:ctx];
        };
        [IJSVGViewBox drawViewBox:viewBox
                           inRect:self.boundingBoxBounds
                    contentBounds:subLayerBounds
                        alignment:_viewBoxAlignment
                      meetOrSlice:_viewBoxMeetOrSlice
                        inContext:ctx
                     drawingBlock:drawingBlock];
        return;
    }
    [super performRenderInContext:ctx];
}

@end
