//
//  IJSVGRootLayer.m
//  IJSVG
//
//  Created by Curtis Hard on 15/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRootLayer.h>

@implementation IJSVGRootLayer

- (void)performRenderInContext:(CGContextRef)ctx
{
    if(self.viewBox != nil) {
        CGRect viewBox = [self.viewBox computeValue:CGSizeZero];
        __weak IJSVGRootLayer* weakSelf = self;
        IJSVGViewBoxDrawingBlock drawingBlock = ^(CGSize size) {
            CGContextSaveGState(ctx);
            CGContextClipToRect(ctx,viewBox);
            // we have to make sure we set the backing scale factor once
            // we know how scale this will be drawn at
            CGFloat nScale = MIN(size.width, size.height);
            nScale += weakSelf.backingScaleFactor;
            weakSelf.backingScaleFactor += nScale;
            
            // perform the actual render now we have computed backing scale
            [super performRenderInContext:ctx];
            CGContextRestoreGState(ctx);
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
    // get nearest .5f
    backingScaleFactor = round(backingScaleFactor * 2.f) / 2.f;
    [super setBackingScaleFactor:backingScaleFactor];
    if(_disableBackingScalePropagation == YES) {
        return;
    }
    [self propagateBackingScalePropertiesToSublayers];
}

- (void)propagateBackingScalePropertiesToSublayers
{
    for(CALayer<IJSVGDrawableLayer>* layer in self.sublayers) {
        [IJSVGLayer setBackingScaleFactor:self.backingScaleFactor
                            renderQuality:self.renderQuality
                       recursivelyToLayer:layer];
    }
}

- (void)renderInContext:(CGContextRef)ctx
               viewPort:(CGRect)viewPort
           backingScale:(CGFloat)backingScale
                quality:(IJSVGRenderQuality)quality
{
    CGRect frame = viewPort;
    self.frame = frame;
    _disableBackingScalePropagation = YES;
    self.backingScaleFactor = backingScale;
    self.renderQuality = quality;
    _disableBackingScalePropagation = NO;
    [self renderInContext:ctx];
}

@end