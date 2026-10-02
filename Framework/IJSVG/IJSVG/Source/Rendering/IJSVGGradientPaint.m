//
//  IJSVGGradientPaint.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGGradientPaint.h>
#import <IJSVGRootPaint.h>

@implementation IJSVGGradientPaint

- (void)drawInContext:(CGContextRef)ctx
{
    // nothing to do :(
    if(self.gradient == nil) {
        return;
    }

    // perform the draw
    CGRect bounds = CGRectZero;
    CGAffineTransform transform = CGAffineTransformIdentity;
    IJSVGPaint* paint = (IJSVGPaint*)self.referencingPaint;
    if(self.gradient.units == IJSVGUnitUserSpaceOnUse) {
        IJSVGRootPaint* rootNode = (IJSVGRootPaint*)[IJSVGPaint rootPaintForPaint:self];
        bounds = [rootNode.viewBox computeValue:rootNode.frame.size];
        transform = [IJSVGPaint userSpaceTransformForPaint:paint];
    } else {
        bounds = IJSVGPaintGetBoundingBoxBounds(paint);
    }

    // its possible that this paint is shifted inwards due to a stroke on the
    // parent paint
    transform = CGAffineTransformConcat(transform, [IJSVGPaint userSpaceTransformForPaint:self]);

    [self.gradient drawInContextRef:ctx
                             bounds:bounds
                          transform:transform];
}

- (CGRect)transparencyBounds
{
    return self.clipPath != NULL ? CGPathGetBoundingBox(self.clipPath) : CGRectInfinite;
}

@end
