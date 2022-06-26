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
        IJSVGViewBoxDrawingBlock drawingBlock = ^(CGFloat scale[]) {
            CGContextSaveGState(ctx);
            // we have to make sure we set the backing scale factor once
            // we know how scale this will be drawn at
            CGFloat nScale = MIN(scale[0], scale[1]);
            nScale *= weakSelf.backingScaleFactor;
            weakSelf.backingScaleFactor = nScale;
            
            // perform the actual render now we have computed backing scale
            [super performRenderInContext:ctx];
            CGContextRestoreGState(ctx);
        };
        
        IJSVGContextDrawViewBox(ctx, viewBox, IJSVGLayerGetBoundingBoxBounds(self),
                                self.viewBoxAlignment,
                                self.viewBoxMeetOrSlice, drawingBlock);
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
    ignoreIntrinsicSize:(BOOL)ignoreIntrinsicSize
{
    CGRect frame = viewPort;
    IJSVGUnitSize* size = nil;
    
    // The SVG might have an intrinsic size against it, if so, we need to use
    // that instead of the viewPort size to make sure we obey the render correctly.
    if(ignoreIntrinsicSize == NO && (size = self.intrinsicSize) != nil) {
        CGFloat width = 0.f;
        CGFloat height = 0.f;
        if((width = [size.width computeValue:frame.size.width]) != 0.f) {
            frame.size.width = width;
        }
        if((height = [size.height computeValue:frame.size.height]) != 0.f) {
            frame.size.height = height;
        }
    }
    self.frame = frame;
    _disableBackingScalePropagation = YES;
    self.backingScaleFactor = backingScale;
    self.renderQuality = quality;
    _disableBackingScalePropagation = NO;
    [self renderInContext:ctx];
}

- (BOOL)treatImplicitOriginAsTransform
{
    return NO;
}

@end
