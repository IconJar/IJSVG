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
        __block IJSVGRootLayer* weakSelf = self;
        IJSVGViewBoxDrawingBlock drawingBlock = ^(CGSize size) {
            // we have to make sure we set the backing scale factor once
            // we know how scale this will be drawn at
            weakSelf.backingScaleFactor *= MAX(size.width, size.height);
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

- (void)setBackingScaleFactor:(CGFloat)backingScaleFactor
{
    [super setBackingScaleFactor:backingScaleFactor];
    for(CALayer<IJSVGDrawableLayer>* layer in self.sublayers) {
        [IJSVGLayer recursivelyWalkLayer:layer
                               withBlock:^(CALayer *layer, BOOL isMask, BOOL *stop) {
            IJSVGLayer* propLayer = (IJSVGLayer<IJSVGDrawableLayer>*)layer;
            propLayer.backingScaleFactor = backingScaleFactor;
        }];
    }
}

@end
