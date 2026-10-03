//
//  IJSVGGradientPaint.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGGradientPaint.h>
#import <IJSVGRootPaint.h>
#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGRadialGradient.h>

typedef NS_ENUM(NSUInteger, IJSVGResolvedGradientKind) {
    IJSVGResolvedGradientKindCustom,
    IJSVGResolvedGradientKindLinear,
    IJSVGResolvedGradientKindRadial
};

@interface IJSVGGradientPaint () {
    BOOL _hasResolvedPlacement;
    __weak IJSVGRootPaint* _gradientRoot;
    CGSize _resolvedRootSize;
    CGRect _resolvedBounds;
    CGAffineTransform _resolvedTransform;
    NSData* _resolvedGradientTransforms;
    CGPoint _startPoint;
    CGPoint _endPoint;
    CGFloat _startRadius;
    CGFloat _endRadius;
    IJSVGResolvedGradientKind _gradientKind;
}
@end

@implementation IJSVGGradientPaint

- (void)setGradient:(IJSVGGradient*)gradient
{
    _gradient = gradient;
    _gradientRoot = nil;
    _hasResolvedPlacement = NO;
    _resolvedGradientTransforms = nil;
    _gradientKind = [gradient isMemberOfClass:IJSVGLinearGradient.class] ? IJSVGResolvedGradientKindLinear :
        ([gradient isMemberOfClass:IJSVGRadialGradient.class] ? IJSVGResolvedGradientKindRadial :
            IJSVGResolvedGradientKindCustom);
}

- (void)drawInContext:(CGContextRef)ctx
{
    if(_gradient == nil) {
        return;
    }

    // Resolved paint geometry is reused until the renderer is invalidated.
    // User-space gradients also depend on the root viewport, which can resize.
    BOOL userSpace = _gradient.units == IJSVGUnitUserSpaceOnUse;
    IJSVGRootPaint* root = _gradientRoot;
    if(userSpace && root == nil) {
        root = (IJSVGRootPaint*)[IJSVGPaint rootPaintForPaint:self];
        _gradientRoot = root;
        _hasResolvedPlacement = NO;
    }
    CGSize rootSize = userSpace ? root.frame.size : CGSizeZero;
    if(!_hasResolvedPlacement || !CGSizeEqualToSize(rootSize, _resolvedRootSize)) {
        IJSVGPaint* paint = self.referencingPaint;
        CGAffineTransform transform = CGAffineTransformIdentity;
        if(userSpace) {
            _resolvedBounds = [root.viewBox computeValue:rootSize];
            transform = [IJSVGPaint userSpaceTransformForPaint:paint];
        } else {
            _resolvedBounds = IJSVGPaintGetBoundingBoxBounds(paint);
        }
        _resolvedTransform = CGAffineTransformConcat(transform,
            [IJSVGPaint userSpaceTransformForPaint:self]);
        CGFloat width = userSpace ? _resolvedBounds.size.width : 1.f;
        CGFloat height = userSpace ? _resolvedBounds.size.height : 1.f;
        if(_gradientKind == IJSVGResolvedGradientKindLinear) {
            _startPoint = CGPointMake([_gradient.x1 computeValue:width],
                                      [_gradient.y1 computeValue:height]);
            _endPoint = CGPointMake([_gradient.x2 computeValue:width],
                                    [_gradient.y2 computeValue:height]);
        } else if(_gradientKind == IJSVGResolvedGradientKindRadial) {
            IJSVGRadialGradient* radial = (IJSVGRadialGradient*)_gradient;
            _startPoint = CGPointMake([radial.fx computeValue:width],
                                      [radial.fy computeValue:height]);
            _endPoint = CGPointMake([radial.cx computeValue:width],
                                    [radial.cy computeValue:height]);
            _startRadius = [radial.fr computeValue:MIN(width, height)];
            _endRadius = [radial.r computeValue:MIN(width, height)];
        }
        NSMutableData* matrices = [NSMutableData dataWithLength:
            _gradient.transforms.count * sizeof(CGAffineTransform)];
        CGAffineTransform* values = matrices.mutableBytes;
        NSUInteger index = 0;
        for(IJSVGTransform* item in _gradient.transforms) {
            values[index++] = item.CGAffineTransform;
        }
        _resolvedGradientTransforms = matrices;
        _resolvedRootSize = rootSize;
        _hasResolvedPlacement = YES;
    }
    if(_gradientKind == IJSVGResolvedGradientKindCustom) {
        [_gradient drawInContextRef:ctx
                             bounds:_resolvedBounds
                          transform:_resolvedTransform];
        return;
    }
    if(_gradientKind == IJSVGResolvedGradientKindRadial) {
        CGContextSaveGState(ctx);
    }
    CGContextConcatCTM(ctx, userSpace ? _resolvedTransform :
        CGAffineTransformMakeScale(_resolvedBounds.size.width, _resolvedBounds.size.height));
    // Replay each matrix in its original order. Combining them changes
    // floating-point rounding and can move antialiased edge pixels.
    const CGAffineTransform* matrices = _resolvedGradientTransforms.bytes;
    NSUInteger count = _resolvedGradientTransforms.length / sizeof(CGAffineTransform);
    for(NSUInteger index = 0; index < count; index++) {
        CGContextConcatCTM(ctx, matrices[index]);
    }
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    if(_gradientKind == IJSVGResolvedGradientKindLinear) {
        CGContextDrawLinearGradient(ctx, _gradient.CGGradient, _startPoint,
                                    _endPoint, options);
    } else {
        CGContextDrawRadialGradient(ctx, _gradient.CGGradient, _startPoint, _startRadius,
                                    _endPoint, _endRadius, options);
        CGContextRestoreGState(ctx);
    }
}

- (CGRect)transparencyBounds
{
    return self.clipPath != NULL ? CGPathGetBoundingBox(self.clipPath) : CGRectInfinite;
}

@end
