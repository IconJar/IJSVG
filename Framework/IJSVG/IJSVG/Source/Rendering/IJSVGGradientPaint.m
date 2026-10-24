//
//  IJSVGGradientPaint.m
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGRadialGradient.h>
#import <IJSVGFilterPaint.h>
#import <IJSVGGradientPaint.h>
#import <IJSVGRootPaint.h>

typedef NS_ENUM(NSUInteger, IJSVGResolvedGradientKind) {
    IJSVGResolvedGradientKindCustom,
    IJSVGResolvedGradientKindLinear,
    IJSVGResolvedGradientKindRadial
};

@interface IJSVGGradientPaint () {
    BOOL _hasResolvedPlacement;
    __weak IJSVGRootPaint* _gradientRoot;
    CGRect _resolvedViewport;
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

- (IJSVGPaintTraits)paintTraits
{
    return IJSVGPaintTraitGradient;
}

- (void)setGradient:(IJSVGGradient*)gradient
{
    _gradient = gradient;
    _gradientRoot = nil;
    _hasResolvedPlacement = NO;
    _resolvedGradientTransforms = nil;
    _gradientKind = [gradient isMemberOfClass:IJSVGLinearGradient.class] ? IJSVGResolvedGradientKindLinear : ([gradient isMemberOfClass:IJSVGRadialGradient.class] ? IJSVGResolvedGradientKindRadial : IJSVGResolvedGradientKindCustom);
}

- (void)drawInContext:(CGContextRef)ctx
{
    if (_gradient == nil) {
        return;
    }

    // Resolved paint geometry is reused until the renderer is invalidated.
    // Userspace gradients also depend on the root viewport, which can resize.
    BOOL userSpace = _gradient.units == IJSVGUnitUserSpaceOnUse;
    IJSVGRootPaint* root = _gradientRoot;
    if (userSpace && root == nil) {
        IJSVGPaint* ancestor = [IJSVGPaint rootPaintForPaint:self];
        if ((ancestor.paintTraits & IJSVGPaintTraitRoot) != 0) {
            root = (IJSVGRootPaint*)ancestor;
            _gradientRoot = root;
            _hasResolvedPlacement = NO;
        }
    }

    // Detached feImage subtrees have no SVG root. The resolver supplies their
    // userspace viewport here, shape bounds cannot resolve percentage lengths.
    CGRect viewport = CGRectZero;
    if (userSpace) {
        viewport = root != nil ? (root.viewBox != nil ? [root.viewBox computeValue:root.frame.size] : root.frame) : self.viewBox;
    }
    if (!_hasResolvedPlacement || !CGRectEqualToRect(viewport, _resolvedViewport)) {
        IJSVGPaint* paint = self.referencingPaint;
        CGAffineTransform transform = CGAffineTransformIdentity;
        if (userSpace) {
            _resolvedBounds = viewport;

            // Undo paint local placement, not the viewport origin: absolute
            // gradient coordinates remain in the referencing nodes user space.
            transform = [IJSVGPaint userSpaceTransformForPaint:paint];
        } else {
            _resolvedBounds = IJSVGPaintGetBoundingBoxBounds(paint);
        }
        _resolvedTransform = CGAffineTransformConcat(transform, [IJSVGPaint userSpaceTransformForPaint:self]);
        CGFloat width = userSpace ? _resolvedBounds.size.width : 1.f;
        CGFloat height = userSpace ? _resolvedBounds.size.height : 1.f;
        if (_gradientKind == IJSVGResolvedGradientKindLinear) {
            _startPoint = CGPointMake([_gradient.x1 computeValue:width], [_gradient.y1 computeValue:height]);
            _endPoint = CGPointMake([_gradient.x2 computeValue:width], [_gradient.y2 computeValue:height]);
        } else if (_gradientKind == IJSVGResolvedGradientKindRadial) {
            IJSVGRadialGradient* radial = (IJSVGRadialGradient*)_gradient;
            _startPoint = CGPointMake([radial.fx computeValue:width], [radial.fy computeValue:height]);
            _endPoint = CGPointMake([radial.cx computeValue:width], [radial.cy computeValue:height]);
            _startRadius = [radial.fr computeValue:MIN(width, height)];
            _endRadius = [radial.r computeValue:MIN(width, height)];
        }
        NSMutableData* matrices = [NSMutableData dataWithLength:_gradient.transforms.count * sizeof(CGAffineTransform)];
        CGAffineTransform* values = matrices.mutableBytes;
        NSUInteger index = 0;
        for (IJSVGTransform* item in _gradient.transforms) {
            values[index++] = item.CGAffineTransform;
        }
        _resolvedGradientTransforms = matrices;
        _resolvedViewport = viewport;
        _hasResolvedPlacement = YES;
    }
    if (_gradientKind == IJSVGResolvedGradientKindCustom) {
        [_gradient drawInContextRef:ctx bounds:_resolvedBounds transform:_resolvedTransform];
        return;
    }
    if (_gradientKind == IJSVGResolvedGradientKindRadial) {
        CGContextSaveGState(ctx);
    }
    CGContextConcatCTM(ctx, userSpace ? _resolvedTransform : CGAffineTransformMakeScale(_resolvedBounds.size.width, _resolvedBounds.size.height));

    // Replay each matrix in its original order. Combining them changes
    // floating point rounding and can move antialiased edge pixels.
    const CGAffineTransform* matrices = _resolvedGradientTransforms.bytes;
    NSUInteger count = _resolvedGradientTransforms.length / sizeof(CGAffineTransform);
    for (NSUInteger index = 0; index < count; index++) {
        CGContextConcatCTM(ctx, matrices[index]);
    }

    // The planning bitmap is discarded before drawing the actual source.
    // Replace only gradients that cover the whole clip with opaque alpha.
    // In particular, focal radial gradients outside the end circle leave holes.
    if (IJSVGFilterIsPlanningAlphaOcclusionInContext(ctx)) {
        BOOL coversClip = _gradientKind == IJSVGResolvedGradientKindLinear
            ? !CGPointEqualToPoint(_startPoint, _endPoint)
            : _startRadius == 0.f && _endRadius > 0.f && hypot(_startPoint.x - _endPoint.x, _startPoint.y - _endPoint.y) < _endRadius;
        BOOL opaque = coversClip && _gradient.colors.count != 0;
        for (id color in _gradient.colors) {
            if (CGColorGetAlpha((__bridge CGColorRef)color) != 1.f) {
                opaque = NO;
                break;
            }
        }
        CGAffineTransform transform = CGContextGetCTM(ctx);
        CGRect clip = CGContextGetClipBoundingBox(ctx);
        CGFloat determinant = transform.a * transform.d - transform.b * transform.c;
        if (opaque && isfinite(determinant) && determinant != 0.f
            && isfinite(clip.origin.x) && isfinite(clip.origin.y)
            && isfinite(clip.size.width) && isfinite(clip.size.height)
            && isfinite(_startPoint.x) && isfinite(_startPoint.y)
            && isfinite(_endPoint.x) && isfinite(_endPoint.y)
            && isfinite(_endRadius)) {
            CGContextSetRGBFillColor(ctx, 1.f, 1.f, 1.f, 1.f);
            CGContextFillRect(ctx, clip);
            if (_gradientKind == IJSVGResolvedGradientKindRadial) {
                CGContextRestoreGState(ctx);
            }
            return;
        }
    }
    if ([_gradient drawSpreadInContext:ctx startPoint:_startPoint endPoint:_endPoint startRadius:_startRadius endRadius:_endRadius radial:_gradientKind == IJSVGResolvedGradientKindRadial]) {
        if (_gradientKind == IJSVGResolvedGradientKindRadial) {
            CGContextRestoreGState(ctx);
        }
        return;
    }
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    if (_gradientKind == IJSVGResolvedGradientKindLinear) {
        CGContextDrawLinearGradient(ctx, _gradient.CGGradient, _startPoint, _endPoint, options);
    } else {
        CGContextDrawRadialGradient(ctx, _gradient.CGGradient, _startPoint, _startRadius, _endPoint, _endRadius, options);
        CGContextRestoreGState(ctx);
    }
}

- (CGRect)transparencyBounds
{
    return self.clipPath != NULL ? CGPathGetBoundingBox(self.clipPath) : CGRectInfinite;
}

@end
