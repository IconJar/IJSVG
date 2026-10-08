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

// Cache entries own only pixels, never the paint graph. A new graph gets a new
// key; size, scale, placement and quality changes replace that key's snapshot.
@interface IJSVGMaskCachedImage : NSObject
@property (nonatomic, assign) CGImageRef image;
@property (nonatomic, assign) CGSize size;
@property (nonatomic, assign) CGRect bounds;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign) IJSVGRenderQuality quality;
@end

@implementation IJSVGMaskCachedImage
- (void)dealloc
{
    CGImageRelease(_image);
}
@end

static NSCache<NSObject*, IJSVGMaskCachedImage*>* IJSVGMaskImageCache(void)
{
    static NSCache* cache;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 128;
        cache.totalCostLimit = 16 * 1024 * 1024;
    });
    return cache;
}

@interface IJSVGPaint () {
    NSObject* _maskCacheKey;
}
@end

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
        _maskingSourceBounds = CGRectNull;
        _children = @[];
    }
    return self;
}

- (void)dealloc
{
    CGPathRelease(_clipPath);
    if(_maskCacheKey != nil) {
        [IJSVGMaskImageCache() removeObjectForKey:_maskCacheKey];
    }
}

- (void)prepareMaskCaching
{
    if(_maskCacheKey != nil) {
        [IJSVGMaskImageCache() removeObjectForKey:_maskCacheKey];
        _maskCacheKey = nil;
    }
    // Filters can read the destination or another SVG; patterns can contain
    // those dependencies too. Keep their existing per-draw behavior.
    NSMutableArray<IJSVGPaint*>* pending = [NSMutableArray arrayWithObject:self];
    NSMutableSet<IJSVGPaint*>* visited = [[NSMutableSet alloc] init];
    while(pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        if([visited containsObject:paint]) {
            continue;
        }
        [visited addObject:paint];
        if([paint isKindOfClass:IJSVGFilterPaint.class] ||
           [paint isKindOfClass:IJSVGPatternPaint.class] ||
            (paint.sourceNode != nil && !CGRectIsNull(paint.sourceNode.backgroundRect))) {
            return;
        }
        [pending addObjectsFromArray:paint.children];
        if(paint.maskPaint != nil) {
            [pending addObject:paint.maskPaint];
        }
    }
    _maskCacheKey = [[NSObject alloc] init];
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

// Uses the stored frame because the public frame already includes the transform.
- (CGAffineTransform)placementTransform
{
    CGAffineTransform placement = CGAffineTransformMakeTranslation(CGRectGetMidX(_frame),
                                                                   CGRectGetMidY(_frame));
    placement = CGAffineTransformConcat(_affineTransform, placement);
    return CGAffineTransformConcat(CGAffineTransformMakeTranslation(-_frame.size.width / 2.f,
                                                                    -_frame.size.height / 2.f),
                                   placement);
}

- (void)setFrame:(CGRect)frame
{
    // Mask placement adjusts the origin of a paint in parent space. Preserve the
    // underlying geometry when that paint already carries a transform.
    // Untransformed paints can accept the frame directly. Their current frame
    // is otherwise calculated and discarded for every assignment.
    if(CGAffineTransformIsIdentity(_affineTransform)) {
        _frame = frame;
        return;
    }
    CGRect currentFrame = self.frame;
    if(CGSizeEqualToSize(frame.size, currentFrame.size)) {
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
    CGFloat scale = MAX(paint.backingScaleFactor, 1.f);
    CGAffineTransform grid = CGAffineTransformMakeScale(scale, scale);
    // Keep raster coverage separate from the geometry used to position the mask.
    CGRect sourceBounds = CGRectIsNull(mask.maskingSourceBounds) ?
        mask.outerBoundingBox : mask.maskingSourceBounds;
    // Clip in raster source coordinates before allocation. ClipToMask below maps
    // source pixels by this translation, the declared mask region remains the
    // final clip. This avoids giant bitmaps for mostly out of region filters.
    CGRect sourceClip = CGRectOffset(mask.maskingClippingRect,
        mask.outerBoundingBox.origin.x - mask.maskingBoundingBox.origin.x,
        mask.outerBoundingBox.origin.y - mask.maskingBoundingBox.origin.y);
    sourceBounds = CGRectIntersection(sourceBounds, sourceClip);
    if(CGRectIsNull(sourceBounds) || CGRectIsEmpty(sourceBounds)) {
        return;
    }
    CGRect bounds = CGRectIntegral(CGRectApplyAffineTransform(sourceBounds, grid));
    bounds = CGRectApplyAffineTransform(bounds, CGAffineTransformInvert(grid));
    CGRect frame = bounds;
    if(!IJSVGIsValidContextSize(frame.size)) {
        return;
    }
    IJSVGMaskCachedImage* cached = mask->_maskCacheKey == nil ? nil :
        [IJSVGMaskImageCache() objectForKey:mask->_maskCacheKey];
    CGImageRef image = NULL;
    if(cached != nil && cached.scale == scale &&
        cached.quality == mask.renderQuality &&
        CGSizeEqualToSize(cached.size, frame.size) &&
        CGRectEqualToRect(cached.bounds, bounds)) {
        image = CGImageRetain(cached.image);
    } else {
        CGContextRef bitmap = CGBitmapContextCreate(NULL, ceil(frame.size.width * scale),
                                                    ceil(frame.size.height * scale), 8, 0,
                                                    IJSVGDeviceGrayColorSpace(), (CGBitmapInfo)kCGImageAlphaNone);
        if(bitmap == NULL) {
            return;
        }
        size_t stride = CGBitmapContextGetBytesPerRow(bitmap);
        size_t height = CGBitmapContextGetHeight(bitmap);
        @try {
            CGContextScaleCTM(bitmap, scale, scale);
            CGContextTranslateCTM(bitmap, -bounds.origin.x, -bounds.origin.y);
            [mask renderInContext:bitmap];
            image = CGBitmapContextCreateImage(bitmap);
        } @finally {
            CGContextRelease(bitmap);
        }
        if(image == NULL) {
            return;
        }
        if(mask->_maskCacheKey != nil) {
            // Keep at most one size per mask and avoid retaining large export
            // surfaces. Quartz still renders those at their requested scale.
            [IJSVGMaskImageCache() removeObjectForKey:mask->_maskCacheKey];
            if(height != 0 && stride <= (4 * 1024 * 1024) / height) {
                cached = [[IJSVGMaskCachedImage alloc] init];
                cached.image = CGImageRetain(image);
                cached.size = frame.size;
                cached.bounds = bounds;
                cached.scale = scale;
                cached.quality = mask.renderQuality;
                [IJSVGMaskImageCache() setObject:cached
                                          forKey:mask->_maskCacheKey
                                          cost:stride * height];
            }
        }
    }
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, mask.maskingClippingRect);
    CGRect maskBounds = mask.maskingBoundingBox;
    maskBounds.origin.x += bounds.origin.x - mask.outerBoundingBox.origin.x;
    maskBounds.origin.y += bounds.origin.y - mask.outerBoundingBox.origin.y;
    maskBounds.size.width = CGImageGetWidth(image) / scale;
    maskBounds.size.height = CGImageGetHeight(image) / scale;
    CGContextClipToMask(ctx, maskBounds, image);
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
    if(_hidden || _opacity == 0.f || ![IJSVGFilterPaint shouldRenderPaintDuringCollection:self]) {
        return;
    }
    CGContextSaveGState(ctx);
    @try {
        if(applyingPlacement) {
            CGContextTranslateCTM(ctx, CGRectGetMidX(_frame), CGRectGetMidY(_frame));
            CGContextConcatCTM(ctx, _affineTransform);
            CGContextTranslateCTM(ctx, -_frame.size.width * .5f, -_frame.size.height * .5f);
        }
        if(_clipPath != NULL) {
            CGContextAddPath(ctx, _clipPath);
            if(_clipRule == IJSVGWindingRuleEvenOdd) {
                CGContextEOClip(ctx);
            } else {
                CGContextClip(ctx);
            }
        }
        CGContextSetBlendMode(ctx, _blendingMode);
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
    BOOL isolated = _opacity != 1.f && _children.count != 0;
    if(_opacity != 1.f) {
        CGContextSetAlpha(ctx, _opacity);
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
    for(IJSVGPaint* child in _children) {
        [child renderInContext:ctx
             applyingPlacement:YES];
    }
}

- (void)drawInContext:(CGContextRef)ctx
{
}

@end
