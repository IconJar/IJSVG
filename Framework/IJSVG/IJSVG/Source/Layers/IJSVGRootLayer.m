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
    if(self.rendersWithViewBoxTransform == YES && self.viewBox != nil) {
        CGRect viewBox = [self.viewBox computeValue:CGSizeZero];
        BOOL hasViewBox = (isfinite(CGRectGetWidth(viewBox)) &&
                           isfinite(CGRectGetHeight(viewBox)) &&
                           CGRectGetWidth(viewBox) > 0.f &&
                           CGRectGetHeight(viewBox) > 0.f);
        // For SVGs without an explicit viewBox, the parser synthesises one
        // from the intrinsic width/height. When such an SVG is rendered into
        // a viewport of different aspect, browsers embedding it via <img>
        // stretch the canvas to fill the box (object-fit: fill default), so
        // use IJSVGViewBoxAlignmentNone here. Otherwise — explicit viewBox
        // — honour the SVG's own preserveAspectRatio settings.
        IJSVGViewBoxAlignment alignment = self.hasExplicitViewBox
            ? self.viewBoxAlignment
            : IJSVGViewBoxAlignmentNone;
        IJSVGViewBoxMeetOrSlice meetOrSlice = self.viewBoxMeetOrSlice;
        if(hasViewBox == YES) {
            __weak IJSVGRootLayer* weakSelf = self;
            IJSVGViewBoxDrawingBlock drawingBlock = ^(CGFloat scale[]) {
                CGContextSaveGState(ctx);
                CGFloat nScale = MIN(scale[0], scale[1]);
                nScale += weakSelf.backingScaleFactor;
                weakSelf.backingScaleFactor = nScale;
                [super performRenderInContext:ctx];
                CGContextRestoreGState(ctx);
            };
            IJSVGContextDrawViewBox(ctx, viewBox, IJSVGLayerGetBoundingBoxBounds(self),
                                    alignment, meetOrSlice, drawingBlock);
            return;
        }
    }
    [super performRenderInContext:ctx];
}

- (void)setBackingScaleFactor:(CGFloat)backingScaleFactor
{
    // get nearest .5f
    backingScaleFactor = MAX(round(backingScaleFactor * 2.f) / 2.f, .5f);
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

    // For SVGs *without* an explicit viewBox we keep the frame at the
    // viewport rect, so the implicit viewBox synthesised in
    // performRenderInContext: actually scales content into the requested
    // rect (matching <img>-style fill). For SVGs *with* an explicit viewBox
    // we preserve the original behaviour and use the intrinsic size as the
    // frame — that's the existing render path the broader sweep corpus
    // relies on and it would regress here otherwise.
    if(ignoreIntrinsicSize == NO &&
       self.hasExplicitViewBox == YES &&
       (size = self.intrinsicSize) != nil) {
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
