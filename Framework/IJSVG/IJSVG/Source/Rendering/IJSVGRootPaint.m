//
//  IJSVGRootPaint.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGRootPaint.h>

@interface IJSVGRootPaint () {
    BOOL _hasPropagatedScale;
    CGFloat _propagatedScale;
    IJSVGRenderQuality _propagatedQuality;
}
@end

@implementation IJSVGRootPaint

- (void)setChildren:(NSArray<IJSVGPaint*>*)children
{
    [super setChildren:children];
    _hasPropagatedScale = NO;
}

- (BOOL)treatImplicitOriginAsTransform
{
    return NO;
}

- (CGRect)transparencyBounds
{
    return CGRectInfinite;
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    if(self.viewBox == nil) {
        [super performRenderInContext:ctx];
        return;
    }
    CGRect viewBox = [self.viewBox computeValue:self.frame.size];
    IJSVGContextDrawViewBox(ctx, viewBox, IJSVGPaintGetBoundingBoxBounds(self), self.viewBoxAlignment,
                            self.viewBoxMeetOrSlice, ^(CGFloat scale[]) {
        CGFloat backingScale = MAX(round((self.backingScaleFactor + MIN(scale[0], scale[1])) * 2.f) / 2.f, .5f);
        // The resolved paints are reused between draws. Only walk them when
        // viewport scale, backing scale or quality actually changes.
        if(!self->_hasPropagatedScale || self->_propagatedScale != backingScale ||
           self->_propagatedQuality != self.renderQuality) {
            for(IJSVGPaint* child in self.children) {
                [IJSVGPaint setBackingScaleFactor:backingScale
                                    renderQuality:self.renderQuality
                               recursivelyToPaint:child];
            }
            self->_propagatedScale = backingScale;
            self->_propagatedQuality = self.renderQuality;
            self->_hasPropagatedScale = YES;
        }
        [super performRenderInContext:ctx];
    });
}
@end
