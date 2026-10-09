//
//  IJSVGShapePaint.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGShapePaint.h>
#import <IJSVGQuartzRenderer.h>

@interface IJSVGShapePaint () {
    NSData* _dashLengths;
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

@synthesize lineDashPattern = _lineDashPattern;

- (void)setLineDashPattern:(NSArray<NSNumber*>*)pattern
{
    CGPathRelease(_nonScalingStrokeOutline);
    _nonScalingStrokeOutline = NULL;
    _lineDashPattern = pattern.copy;
    NSMutableData* lengths = [NSMutableData dataWithLength:pattern.count * sizeof(CGFloat)];
    CGFloat* values = lengths.mutableBytes;
    for(NSUInteger index = 0; index < pattern.count; index++) {
        values[index] = pattern[index].doubleValue;
    }
    _dashLengths = lengths;
}

- (IJSVGPaint*)copyForMarker
{
    IJSVGShapePaint* copy = (IJSVGShapePaint*)[super copyForMarker];
    if(copy == nil) {
        return nil;
    }

    copy.path = _path;
    copy.fillColor = _fillColor;
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

    for(NSUInteger index = 0; index < children.count; index++) {
        if(children[index] == _fillPaint) {
            copy.fillPaint = copy.children[index];
        }
        if(children[index] == _strokePaint) {
            copy.strokePaint = copy.children[index];
        }
        if(children[index] == _strokeStyle) {
            copy.strokeStyle = (IJSVGShapePaint*)copy.children[index];
        }
    }

    if((_fillPaint != nil && copy.fillPaint == nil) ||
       (_strokePaint != nil && copy.strokePaint == nil) ||
       (_strokeStyle != nil && copy.strokeStyle == nil)) {
        return nil;
    }
    return copy;
}

// Resolved paint geometry is reused between draws. Retain one outline and
// regenerate it only when an input changes. Viewport changes rebuild the paint.
- (CGPathRef)nonScalingStrokeOutline
{
    if(_nonScalingStrokeOutline == NULL ||
       _outlineLineWidth != _lineWidth || _outlineMiterLimit != _miterLimit ||
       _outlineDashPhase != _lineDashPhase || _outlineLineCap != _lineCap ||
       _outlineLineJoin != _lineJoin ||
       !CGAffineTransformEqualToTransform(_outlineHostTransform, _strokeHostTransform)) {
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
    CGPathRelease(_nonScalingStrokeOutline);
    CGPathRelease(_path);
    CGColorRelease(_fillColor);
    CGColorRelease(_strokeColor);
}

- (void)setPath:(CGPathRef)path
{
    if(path == _path) {
        return;
    }
    CGPathRelease(_nonScalingStrokeOutline);
    _nonScalingStrokeOutline = NULL;
    CGPathRelease(_path);
    _path = CGPathRetain(path);
}

- (void)setFillColor:(CGColorRef)color
{
    if(color == _fillColor) {
        return;
    }
    CGColorRelease(_fillColor);
    _fillColor = CGColorRetain(color);
}

- (void)setStrokeColor:(CGColorRef)color
{
    if(color == _strokeColor) {
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
    if(self.path != NULL && (self.fillColor != NULL || self.strokeColor != NULL)) {
        CGRect pathBounds = CGPathGetBoundingBox(self.path);
        if(self.strokeColor != NULL && self.nonScalingStroke) {
            pathBounds = CGRectUnion(pathBounds, CGPathGetBoundingBox([self nonScalingStrokeOutline]));
        } else if(self.strokeColor != NULL) {
            CGFloat padding = self.lineWidth * (self.lineJoin == kCGLineJoinMiter ? MAX(1.f, self.miterLimit) : 1.f);
            pathBounds = CGRectInset(pathBounds, -padding, -padding);
        }
        bounds = CGRectUnion(bounds, pathBounds);
    }
    return bounds;
}

- (void)drawInContext:(CGContextRef)ctx
{
    if(_path == NULL) {
        return;
    }
    if(_fillColor != NULL) {
        CGContextAddPath(ctx, _path);
        CGContextSetFillColorWithColor(ctx, _fillColor);
        if(self.fillRule == IJSVGWindingRuleEvenOdd) {
            CGContextEOFillPath(ctx);
        } else {
            CGContextFillPath(ctx);
        }
    }
    if(_strokeColor != NULL && _lineWidth > 0.f) {
        if(_nonScalingStroke) {
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
        CGContextSetLineDash(ctx, _lineDashPhase, _dashLengths.bytes,
                             _dashLengths.length / sizeof(CGFloat));
        CGContextStrokePath(ctx);
    }
}
@end
