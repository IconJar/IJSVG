//
//  IJSVGShapePaint.m
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradient.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGGradientDrawing.h>
#import <IJSVGNodeParsing.h>
#import <IJSVGQuartzRenderer.h>
#import <IJSVGShapePaint.h>

static BOOL IJSVGShapeBoundsAreFinite(CGRect bounds)
{
    return isfinite(bounds.origin.x) && isfinite(bounds.origin.y) && isfinite(bounds.size.width) && isfinite(bounds.size.height);
}

@interface IJSVGShapePaint () {
    NSData* _dashLengths;
    CGGradientRef _resolvedFillGradient;
    BOOL _usesPreparedFillGradient;
    BOOL _hasPointSubpaths;
    BOOL _checkedPointSubpaths;
    CGPathRef _nonScalingStrokeOutline;
    CGFloat _outlineLineWidth;
    CGFloat _outlineMiterLimit;
    CGFloat _outlineDashPhase;
    CGLineCap _outlineLineCap;
    CGLineJoin _outlineLineJoin;
    CGAffineTransform _outlineHostTransform;
}

@end

@implementation IJSVGShapePaint

// Allocation already supplies the class. A static identity
// comparison here avoids object class queries in parsing and drawing, while
// subclasses keep the general implementation.
+ (instancetype)allocWithZone:(NSZone*)zone
{
    IJSVGShapePaint* instance = [super allocWithZone:zone];
    if (self == IJSVGShapePaint.class) {
        instance->_builtInPaintKind = IJSVGBuiltInPaintShape;
    }
    return instance;
}

- (IJSVGPaintTraits)paintTraits
{
    return IJSVGPaintTraitShape;
}

@synthesize lineDashPattern = _lineDashPattern;

- (void)setFillGradient:(IJSVGGradient*)gradient
{
    CGGradientRelease(_resolvedFillGradient);
    _resolvedFillGradient = NULL;
    _fillGradient = gradient;
    _usesPreparedFillGradient = (IJSVGBuiltInNodeType(gradient) == IJSVGNodeTypeLinearGradient)
        && gradient.spreadMethod == IJSVGGradientSpreadMethodPad;
}

- (NSData*)lineDashData
{
    return _dashLengths;
}

- (void)setLineDashData:(NSData*)data
{
    CGPathRelease(_nonScalingStrokeOutline);
    _nonScalingStrokeOutline = NULL;
    _dashLengths = data.copy;
    _lineDashPattern = data.length == 0 && data != nil ? @[] : nil;
}

- (NSArray<NSNumber*>*)lineDashPattern
{
    if (_lineDashPattern == nil && _dashLengths.length != 0) {
        NSUInteger count = _dashLengths.length / sizeof(CGFloat);
        const CGFloat* values = _dashLengths.bytes;
        NSMutableArray<NSNumber*>* pattern = [[NSMutableArray alloc] initWithCapacity:count];
        for (NSUInteger index = 0; index < count; index++) {
            [pattern addObject:@(values[index])];
        }
        _lineDashPattern = pattern.copy;
    }
    return _lineDashPattern;
}

- (void)setLineDashPattern:(NSArray<NSNumber*>*)pattern
{
    NSUInteger count = pattern.count;
    NSMutableData* lengths = count != 0 ? [NSMutableData dataWithLength:count * sizeof(CGFloat)] : nil;
    CGFloat* values = lengths.mutableBytes;
    for (NSUInteger index = 0; index < count; index++) {
        values[index] = pattern[index].doubleValue;
    }
    self.lineDashData = lengths;
    _lineDashPattern = pattern.copy;
}

- (IJSVGPaint*)copyForMarker
{
    IJSVGShapePaint* copy = (IJSVGShapePaint*)[super copyForMarker];
    if (copy == nil) {
        return nil;
    }

    copy.path = _path;
    copy.fillColor = _fillColor;
    copy.fillGradient = _fillGradient;
    copy.directFill = _directFill;
    copy.strokeColor = _strokeColor;
    copy->_lineWidth = _lineWidth;
    copy->_nonScalingStroke = _nonScalingStroke;
    copy->_strokeHostTransform = _strokeHostTransform;
    copy->_lineCap = _lineCap;
    copy->_lineJoin = _lineJoin;
    copy->_miterLimit = _miterLimit;
    copy->_lineDashPattern = _lineDashPattern;
    copy->_dashLengths = _dashLengths;
    copy->_lineDashPhase = _lineDashPhase;
    copy->_primitiveType = _primitiveType;
    NSArray<IJSVGPaint*>* children = self.children;

    for (NSUInteger index = 0; index < children.count; index++) {
        if (children[index] == _fillPaint) {
            copy.fillPaint = copy.children[index];
        }
        if (children[index] == _strokePaint) {
            copy.strokePaint = copy.children[index];
        }
        if (children[index] == _strokeStyle) {
            copy.strokeStyle = (IJSVGShapePaint*)copy.children[index];
        }
    }

    if ((_fillPaint != nil && copy.fillPaint == nil) || (_strokePaint != nil && copy.strokePaint == nil) || (_strokeStyle != nil && copy.strokeStyle == nil)) {
        return nil;
    }
    return copy;
}

// Resolved paint geometry is reused between draws. Retain one outline and
// regenerate it only when an input changes. Viewport changes rebuild the paint.
- (CGPathRef)nonScalingStrokeOutline
{
    if (_nonScalingStrokeOutline == NULL || _outlineLineWidth != _lineWidth || _outlineMiterLimit != _miterLimit || _outlineDashPhase != _lineDashPhase || _outlineLineCap != _lineCap || _outlineLineJoin != _lineJoin || !CGAffineTransformEqualToTransform(_outlineHostTransform, _strokeHostTransform)) {
        CGPathRelease(_nonScalingStrokeOutline);
        _nonScalingStrokeOutline = [IJSVGQuartzRenderer newPathFromStrokedShapePaint:self];
        _outlineLineWidth = _lineWidth;
        _outlineMiterLimit = _miterLimit;
        _outlineDashPhase = _lineDashPhase;
        _outlineLineCap = _lineCap;
        _outlineLineJoin = _lineJoin;
        _outlineHostTransform = _strokeHostTransform;
    }
    return _nonScalingStrokeOutline;
}

- (void)dealloc
{
    CGGradientRelease(_resolvedFillGradient);
    CGPathRelease(_nonScalingStrokeOutline);
    CGPathRelease(_path);
    CGColorRelease(_fillColor);
    CGColorRelease(_strokeColor);
}

- (void)setPath:(CGPathRef)path
{
    if (path == _path) {
        return;
    }
    CGPathRelease(_nonScalingStrokeOutline);
    _nonScalingStrokeOutline = NULL;
    CGPathRelease(_path);
    _path = CGPathRetain(path);
    _checkedPointSubpaths = NO;
}

- (void)setHasPointSubpaths:(BOOL)hasPointSubpaths
{
    _hasPointSubpaths = hasPointSubpaths;
    _checkedPointSubpaths = YES;
}

- (BOOL)hasPointSubpaths
{
    if (!_checkedPointSubpaths) {
        _hasPointSubpaths = IJSVGPathHasPointSubpaths(_path);
        _checkedPointSubpaths = YES;
    }
    return _hasPointSubpaths;
}

- (void)setFillColor:(CGColorRef)color
{
    if (color == _fillColor) {
        return;
    }
    CGColorRelease(_fillColor);
    _fillColor = CGColorRetain(color);
}

- (void)setStrokeColor:(CGColorRef)color
{
    if (color == _strokeColor) {
        return;
    }
    CGColorRelease(_strokeColor);
    _strokeColor = CGColorRetain(color);
}

- (CGRect)innerBoundingBox
{
    return self.bounds;
}

- (CGRect)transparencyBounds
{
    CGRect bounds = [super transparencyBounds];
    if (self.path != NULL && (self.fillColor != NULL || self.fillGradient != nil || self.strokeColor != NULL)) {
        CGRect pathBounds = CGPathGetBoundingBox(self.path);
        if (self.strokeColor != NULL && self.nonScalingStroke) {
            pathBounds = CGRectUnion(pathBounds, CGPathGetBoundingBox([self nonScalingStrokeOutline]));
        } else if (self.strokeColor != NULL) {
            CGFloat padding = self.lineWidth * (self.lineJoin == kCGLineJoinMiter ? MAX(1.f, self.miterLimit) : 1.f);
            pathBounds = CGRectInset(pathBounds, -padding, -padding);
        }
        bounds = CGRectUnion(bounds, pathBounds);
    }
    return bounds;
}

// Control point bounds are conservative and avoid constructing stroke outlines.
// Cull only drawing for this shape. Children and filter source sampling still
// run.
- (BOOL)isPathOutsideClipInContext:(CGContextRef)ctx
{
    if (_nonScalingStroke && _strokeColor != NULL) {
        return NO;
    }
    CGRect bounds = CGPathGetBoundingBox(_path);
    if (!IJSVGShapeBoundsAreFinite(bounds)) {
        return NO;
    }
    if (_strokeColor != NULL && _lineWidth > 0.f) {
        CGFloat padding = _lineWidth * MAX(2.f, _miterLimit);
        bounds = CGRectInset(bounds, -padding, -padding);
    }
    CGAffineTransform transform = CGContextGetCTM(ctx);
    CGFloat determinant = transform.a * transform.d - transform.b * transform.c;
    if (!isfinite(determinant) || determinant == 0.f) {
        return NO;
    }
    CGAffineTransform inverse = CGAffineTransformInvert(transform);
    bounds = CGRectInset(bounds, -2.f * (fabs(inverse.a) + fabs(inverse.c)), -2.f * (fabs(inverse.b) + fabs(inverse.d)));
    CGRect clip = CGContextGetClipBoundingBox(ctx);
    return IJSVGShapeBoundsAreFinite(bounds) && IJSVGShapeBoundsAreFinite(clip) && !CGRectIntersectsRect(bounds, clip);
}

- (void)drawInContext:(CGContextRef)ctx
{
    if (_fillGradient != nil && _path != NULL) {
        CGContextSaveGState(ctx);

        // Preserve the placement operations used by a separate fill paint
        CGRect bounds = self.bounds;
        CGContextTranslateCTM(ctx, CGRectGetMidX(bounds), CGRectGetMidY(bounds));
        CGContextConcatCTM(ctx, CGAffineTransformIdentity);
        CGContextTranslateCTM(ctx, -bounds.size.width * .5f, -bounds.size.height * .5f);
        CGContextAddPath(ctx, _path);
        if (self.fillRule == IJSVGWindingRuleEvenOdd) {
            CGContextEOClip(ctx);
        } else {
            CGContextClip(ctx);
        }
        if (!CGRectIsEmpty(CGContextGetClipBoundingBox(ctx))) {
            if (_usesPreparedFillGradient) {
                // As with separate gradient paints, retain stops for this render tree.
                if (_resolvedFillGradient == NULL) {
                    _resolvedFillGradient = CGGradientRetain(_fillGradient.CGGradient);
                }
                IJSVGDrawLinearGradient((IJSVGLinearGradient*)_fillGradient, _resolvedFillGradient,
                    ctx, IJSVGPaintGetBoundingBoxBounds(self), CGAffineTransformIdentity);
            } else {
                [_fillGradient drawInContextRef:ctx bounds:IJSVGPaintGetBoundingBoxBounds(self) transform:CGAffineTransformIdentity];
            }
        }
        CGContextRestoreGState(ctx);
        return;
    }
    if (_directFill) {
        CGContextSaveGState(ctx);
        CGRect bounds = self.bounds;
        CGContextTranslateCTM(ctx, CGRectGetMidX(bounds), CGRectGetMidY(bounds));
        CGContextConcatCTM(ctx, CGAffineTransformIdentity);
        CGContextTranslateCTM(ctx, -bounds.size.width * .5f, -bounds.size.height * .5f);
        [self drawPathInContext:ctx];
        CGContextRestoreGState(ctx);
        return;
    }
    [self drawPathInContext:ctx];
}

- (void)drawPathInContext:(CGContextRef)ctx
{
    if (_path == NULL || (_fillColor == NULL && _strokeColor == NULL) || [self isPathOutsideClipInContext:ctx]) {
        return;
    }
    if (_fillColor != NULL) {
        CGContextAddPath(ctx, _path);
        CGContextSetFillColorWithColor(ctx, _fillColor);
        if (self.fillRule == IJSVGWindingRuleEvenOdd) {
            CGContextEOFillPath(ctx);
        } else {
            CGContextFillPath(ctx);
        }
    }
    if (_strokeColor != NULL && _lineWidth > 0.f) {
        if (_nonScalingStroke || self.hasPointSubpaths) {
            CGContextAddPath(ctx, [self nonScalingStrokeOutline]);
            CGContextSetFillColorWithColor(ctx, _strokeColor);
            CGContextFillPath(ctx);
            return;
        }
        CGContextAddPath(ctx, _path);
        CGContextSetStrokeColorWithColor(ctx, _strokeColor);
        CGContextSetLineWidth(ctx, _lineWidth);
        CGContextSetLineCap(ctx, _lineCap);
        CGContextSetLineJoin(ctx, _lineJoin);
        CGContextSetMiterLimit(ctx, _miterLimit);
        CGContextSetLineDash(ctx, _lineDashPhase, _dashLengths.bytes, _dashLengths.length / sizeof(CGFloat));
        CGContextStrokePath(ctx);
    }
}

@end
