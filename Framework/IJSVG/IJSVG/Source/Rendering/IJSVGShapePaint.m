//
//  IJSVGShapePaint.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGShapePaint.h>

@interface IJSVGShapePaint () {
    NSData* _dashLengths;
}
@end

@implementation IJSVGShapePaint

@synthesize lineDashPattern = _lineDashPattern;

- (void)setLineDashPattern:(NSArray<NSNumber*>*)pattern
{
    _lineDashPattern = pattern.copy;
    NSMutableData* lengths = [NSMutableData dataWithLength:pattern.count * sizeof(CGFloat)];
    CGFloat* values = lengths.mutableBytes;
    for(NSUInteger index = 0; index < pattern.count; index++) {
        values[index] = pattern[index].doubleValue;
    }
    _dashLengths = lengths;
}

- (void)dealloc
{
    CGPathRelease(_path);
    CGColorRelease(_fillColor);
    CGColorRelease(_strokeColor);
}

- (void)setPath:(CGPathRef)path
{
    if(path == _path) {
        return;
    }
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
        if(self.strokeColor != NULL) {
            CGFloat padding = self.lineWidth * (self.lineJoin == kCGLineJoinMiter ? MAX(1.f, self.miterLimit) : 1.f);
            pathBounds = CGRectInset(pathBounds, -padding, -padding);
        }
        bounds = CGRectUnion(bounds, pathBounds);
    }
    return bounds;
}

- (void)drawInContext:(CGContextRef)ctx
{
    if(self.path == NULL) {
        return;
    }
    if(self.fillColor != NULL) {
        CGContextAddPath(ctx, self.path);
        CGContextSetFillColorWithColor(ctx, self.fillColor);
        if(self.fillRule == IJSVGWindingRuleEvenOdd) CGContextEOFillPath(ctx);
        else CGContextFillPath(ctx);
    }
    if(self.strokeColor != NULL && self.lineWidth > 0.f) {
        CGContextAddPath(ctx, self.path);
        CGContextSetStrokeColorWithColor(ctx, self.strokeColor);
        CGContextSetLineWidth(ctx, self.lineWidth);
        CGContextSetLineCap(ctx, self.lineCap);
        CGContextSetLineJoin(ctx, self.lineJoin);
        CGContextSetMiterLimit(ctx, self.miterLimit);
        CGContextSetLineDash(ctx, self.lineDashPhase, _dashLengths.bytes,
                             _dashLengths.length / sizeof(CGFloat));
        CGContextStrokePath(ctx);
    }
}
@end
