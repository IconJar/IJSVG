//
//  IJSVGPaint.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGPaint.h>
#import <IJSVGTransformPaint.h>
#import <IJSVGRootPaint.h>
#import <IJSVGPatternPaint.h>
#import <IJSVGGradientPaint.h>
#import <IJSVGFilterPaint.h>
#import <IJSVG/IJSVGColorNode.h>
#import <IJSVG/IJSVGUtils.h>

CGRect IJSVGPaintGetBoundingBoxBounds(IJSVGPaint* paint)
{
    return (CGRect) { .origin = CGPointZero, .size = paint.boundingBox.size };
}

@implementation IJSVGPaint

@synthesize frame = _frame;

+ (instancetype)paint
{
    return [[self alloc] init];
}

- (instancetype)init
{
    if((self = [super init]) != nil) {
        _opacity = 1.f;
        _backingScaleFactor = 1.f;
        _affineTransform = CGAffineTransformIdentity;
        _boundingBox = CGRectNull;
        _outerBoundingBox = CGRectNull;
        _children = @[];
    }
    return self;
}

- (void)dealloc
{
    CGPathRelease(_clipPath);
}

- (void)setClipPath:(CGPathRef)path
{
    if(path == _clipPath) {
        return;
    }
    CGPathRelease(_clipPath);
    _clipPath = CGPathRetain(path);
}

- (CGRect)bounds
{
    return (CGRect) { .origin = CGPointZero, .size = _frame.size };
}

- (CGRect)frame
{
    CGAffineTransform transform = CGAffineTransformMakeTranslation(CGRectGetMidX(_frame),
                                                                   CGRectGetMidY(_frame));
    transform = CGAffineTransformConcat(_affineTransform, transform);
    return CGRectApplyAffineTransform(CGRectMake(-_frame.size.width * .5f, -_frame.size.height * .5f,
                                                _frame.size.width, _frame.size.height), transform);
}

- (void)setFrame:(CGRect)frame
{
    // Mask placement adjusts the origin of a paint in parent space. Preserve the
    // underlying geometry when that paint already carries a transform.
    CGRect currentFrame = self.frame;
    if(!CGAffineTransformIsIdentity(_affineTransform) &&
        CGSizeEqualToSize(frame.size, currentFrame.size)) {
        _frame.origin.x += frame.origin.x - currentFrame.origin.x;
        _frame.origin.y += frame.origin.y - currentFrame.origin.y;
    } else {
        _frame = frame;
    }
}

- (CGRect)boundingBox
{
    return CGRectIsNull(_boundingBox) ? self.frame : _boundingBox;
}

- (CGRect)outerBoundingBox
{
    return CGRectIsNull(_outerBoundingBox) ? self.frame : _outerBoundingBox;
}

- (CGRect)innerBoundingBox
{
    return (CGRect) { .origin = CGPointZero, .size = self.outerBoundingBox.size };
}

- (IJSVGPaint*)referencingPaint
{
    return _referencingPaint ?: _parentPaint;
}

- (BOOL)treatImplicitOriginAsTransform
{
    return YES;
}

- (void)setChildren:(NSArray<IJSVGPaint*>*)children
{
    for(IJSVGPaint* child in _children) {
        if(child.parentPaint == self) {
            child.parentPaint = nil;
        }
    }
    _children = children.copy;
    for(IJSVGPaint* child in _children) {
        child.parentPaint = self;
    }
}

- (void)addChild:(IJSVGPaint*)paint
{
    self.children = [self.children arrayByAddingObject:paint];
}

+ (IJSVGPaintFillType)fillTypeForFill:(id)fill
{
    if([fill isKindOfClass:IJSVGColorNode.class]) {
        return IJSVGPaintFillTypeColor;
    }
    if([fill isKindOfClass:IJSVGGradient.class]) {
        return IJSVGPaintFillTypeGradient;
    }
    if([fill isKindOfClass:IJSVGPattern.class]) {
        return IJSVGPaintFillTypePattern;
    }
    return IJSVGPaintFillTypeUnknown;
}

+ (CGRect)calculateFrameForChildren:(NSArray<IJSVGPaint*>*)children
{
    CGRect rect = CGRectNull;
    for(IJSVGPaint* child in children) {
        CGRect bounds = child.outerBoundingBox;
        if([child isKindOfClass:IJSVGTransformPaint.class]) {
            bounds = CGRectApplyAffineTransform([self calculateFrameForChildren:child.children],
                                                child.affineTransform);
        }
        rect = CGRectUnion(rect, bounds);
    }
    return rect;
}

+ (CGAffineTransform)userSpaceTransformForPaint:(IJSVGPaint*)paint
{
    return CGAffineTransformMakeTranslation(-paint.outerBoundingBox.origin.x,
                                            -paint.outerBoundingBox.origin.y);
}

+ (IJSVGPaint*)rootPaintForPaint:(IJSVGPaint*)paint
{
    IJSVGPaint* parent = paint.referencingPaint;
    while(parent.referencingPaint != nil && ![parent isKindOfClass:IJSVGRootPaint.class]) {
        parent = parent.referencingPaint;
    }
    return parent;
}

+ (void)setBackingScaleFactor:(CGFloat)scale
                renderQuality:(IJSVGRenderQuality)quality
           recursivelyToPaint:(IJSVGPaint*)paint
{
    paint.backingScaleFactor = scale;
    paint.renderQuality = quality;
    for(IJSVGPaint* child in paint.children) {
        [self setBackingScaleFactor:scale
                      renderQuality:quality
                 recursivelyToPaint:child];
    }
    if(paint.maskPaint != nil) {
        [self setBackingScaleFactor:scale
                      renderQuality:quality
                 recursivelyToPaint:paint.maskPaint];
    }
    if([paint isKindOfClass:IJSVGPatternPaint.class]) {
        [self setBackingScaleFactor:scale
                      renderQuality:quality
                 recursivelyToPaint:((IJSVGPatternPaint*)paint).pattern];
    }
}

+ (void)renderPaint:(IJSVGPaint*)paint
          inContext:(CGContextRef)ctx
            options:(IJSVGPaintDrawingOptions)options
{
    [paint renderInContext:ctx];
}

+ (void)clipContextWithMask:(IJSVGPaint*)mask
                    toPaint:(IJSVGPaint*)paint
                  inContext:(CGContextRef)ctx
               drawingBlock:(dispatch_block_t)drawingBlock
{
    CGRect frame = mask.outerBoundingBox;
    CGFloat scale = MAX(paint.backingScaleFactor, 1.f);
    if(!IJSVGIsValidContextSize(frame.size)) {
        return;
    }
    CGRect bounds = CGRectApplyAffineTransform(mask.innerBoundingBox,
                       [self userSpaceTransformForPaint:mask.referencingPaint ?: mask]);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, ceil(frame.size.width * scale),
                                                ceil(frame.size.height * scale), 8, 0,
                                                IJSVGDeviceGrayColorSpace(), (CGBitmapInfo)kCGImageAlphaNone);
    if(bitmap == NULL) {
        return;
    }
    CGContextScaleCTM(bitmap, scale, scale);
    CGContextTranslateCTM(bitmap, -bounds.origin.x, -bounds.origin.y);
    [mask renderInContext:bitmap];
    CGImageRef image = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    if(image == NULL) {
        return;
    }
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, mask.maskingClippingRect);
    CGContextClipToMask(ctx, mask.maskingBoundingBox, image);
    drawingBlock();
    CGContextRestoreGState(ctx);
    CGImageRelease(image);
}

- (CGRect)transparencyBounds
{
    CGRect rect = CGRectNull;
    for(IJSVGPaint* child in self.children) {
        CGRect bounds = child.transparencyBounds;
        if(CGRectIsInfinite(bounds)) {
            return CGRectInfinite;
        }
        CGAffineTransform transform = CGAffineTransformMakeTranslation(CGRectGetMidX(child->_frame),
                                                                       CGRectGetMidY(child->_frame));
        transform = CGAffineTransformConcat(child.affineTransform, transform);
        bounds = CGRectOffset(bounds, -child->_frame.size.width * .5f, -child->_frame.size.height * .5f);
        rect = CGRectUnion(rect, CGRectApplyAffineTransform(bounds, transform));
    }
    return rect;
}

- (void)renderInContext:(CGContextRef)ctx
{
    [self renderInContext:ctx applyingPlacement:NO];
}

- (void)renderInContext:(CGContextRef)ctx
      applyingPlacement:(BOOL)applyingPlacement
{
    if(self.hidden || self.opacity == 0.f || ![IJSVGFilterPaint shouldRenderPaintDuringCollection:self]) {
        return;
    }
    CGContextSaveGState(ctx);
    @try {
        if(applyingPlacement) {
            CGContextTranslateCTM(ctx, CGRectGetMidX(_frame), CGRectGetMidY(_frame));
            CGContextConcatCTM(ctx, _affineTransform);
            CGContextTranslateCTM(ctx, -_frame.size.width * .5f, -_frame.size.height * .5f);
        }
        if(self.clipPath != NULL) {
            CGContextAddPath(ctx, self.clipPath);
            if(self.clipRule == IJSVGWindingRuleEvenOdd) {
                CGContextEOClip(ctx);
            } else {
                CGContextClip(ctx);
            }
        }
        CGContextSetBlendMode(ctx, self.blendingMode);
        if(_maskPaint != nil) {
            [IJSVGPaint clipContextWithMask:_maskPaint
                                    toPaint:self
                                  inContext:ctx
                               drawingBlock:^{
                [self performRenderInContext:ctx];
            }];
        } else {
            [self performRenderInContext:ctx];
        }
    } @finally {
        CGContextRestoreGState(ctx);
    }
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    BOOL isolated = self.opacity != 1.f && self.children.count != 0;
    if(self.opacity != 1.f) {
        CGContextSetAlpha(ctx, self.opacity);
    }
    if(isolated) {
        CGRect bounds = self.transparencyBounds;
        if(!CGRectIsNull(bounds) && !CGRectIsInfinite(bounds)) {
            // Keep antialiasing coverage around the surface at any zoom level.
            CGAffineTransform transform = CGContextGetCTM(ctx);
            CGFloat scale = MIN(hypot(transform.a, transform.b), hypot(transform.c, transform.d));
            if(scale > 0.f) {
                CGContextClipToRect(ctx, CGRectInset(bounds, -2.f / scale, -2.f / scale));
            }
        }
        CGContextBeginTransparencyLayer(ctx, NULL);
    }
    [self drawContentsInContext:ctx];
    if(isolated) {
        CGContextEndTransparencyLayer(ctx);
    }
}

- (void)drawContentsInContext:(CGContextRef)ctx
{
    [self drawInContext:ctx];
    for(IJSVGPaint* child in self.children) {
        [child renderInContext:ctx
             applyingPlacement:YES];
    }
}

- (void)drawInContext:(CGContextRef)ctx
{
}

@end
