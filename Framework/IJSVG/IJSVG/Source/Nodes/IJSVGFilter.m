//
//  IJSVGFilter.m
//  IJSVG
//
//  Created by Curtis Hard on 18/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGFilterEffect.h>
#import <IJSVG/IJSVGFilterEffectGaussianBlur.h>
#import <IJSVG/IJSVGFilterGraph.h>
#import <IJSVG/IJSVGLayer.h>
#import <IJSVG/IJSVGRootLayer.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGImageLayer.h>
#import <IJSVG/IJSVGViewBox.h>
#import <TargetConditionals.h>
#import <math.h>
#include <stdint.h>

#if TARGET_OS_IOS
static const size_t kIJSVGFilterMaxBitmapDimension = 8192;
static const size_t kIJSVGFilterMaxBitmapBytes = 16ull * 1024ull * 1024ull;
#else
static const size_t kIJSVGFilterMaxBitmapDimension = 32768;
static const size_t kIJSVGFilterMaxBitmapBytes = 512ull * 1024ull * 1024ull;
#endif

static inline BOOL IJSVGFilterValueIsFiniteAndPositive(CGFloat value)
{
    return isfinite(value) && value > 0.f;
}

static inline BOOL IJSVGFilterRectHasRenderableExtent(CGRect rect)
{
    return isfinite(rect.origin.x) &&
           isfinite(rect.origin.y) &&
           IJSVGFilterValueIsFiniteAndPositive(rect.size.width) &&
           IJSVGFilterValueIsFiniteAndPositive(rect.size.height);
}

static inline BOOL IJSVGFilterBitmapSizeIsSafe(size_t width, size_t height)
{
    if(width == 0 || height == 0) {
        return NO;
    }
    if(width > kIJSVGFilterMaxBitmapDimension ||
       height > kIJSVGFilterMaxBitmapDimension) {
        return NO;
    }
    if(width > SIZE_MAX / height) {
        return NO;
    }
    size_t pixelCount = width * height;
    if(pixelCount > SIZE_MAX / 4) {
        return NO;
    }
    return pixelCount * 4 <= kIJSVGFilterMaxBitmapBytes;
}

static inline CGFloat IJSVGFilterClampedScaleForBitmapSize(CGFloat width,
                                                           CGFloat height,
                                                           CGFloat scale)
{
    if(IJSVGFilterValueIsFiniteAndPositive(width) == NO ||
       IJSVGFilterValueIsFiniteAndPositive(height) == NO ||
       IJSVGFilterValueIsFiniteAndPositive(scale) == NO) {
        return scale;
    }

    CGFloat bitmapBytesAtScaleOne = width * height * 4.f;
    if(IJSVGFilterValueIsFiniteAndPositive(bitmapBytesAtScaleOne) == NO) {
        return scale;
    }

    CGFloat maxScale = sqrt((CGFloat)kIJSVGFilterMaxBitmapBytes / bitmapBytesAtScaleOne);
    if(IJSVGFilterValueIsFiniteAndPositive(maxScale) == NO) {
        return scale;
    }
    return MIN(scale, maxScale);
}

static CGFloat IJSVGFilterEffectiveScaleForLayer(CALayer<IJSVGDrawableLayer> *layer,
                                                 CGFloat backingScale)
{
    CGFloat effectiveScale = backingScale;
    IJSVGRootLayer *rootLayer = (IJSVGRootLayer *)[IJSVGLayer rootLayerForLayer:layer];
    if([rootLayer isKindOfClass:IJSVGRootLayer.class] == NO ||
       rootLayer.rendersWithViewBoxTransform == NO ||
       rootLayer.viewBox == nil) {
        return effectiveScale;
    }

    CGRect viewBox = [rootLayer.viewBox computeValue:CGSizeZero];
    CGRect drawingRect = rootLayer.bounds;
    if(IJSVGFilterRectHasRenderableExtent(viewBox) == NO ||
       IJSVGFilterRectHasRenderableExtent(drawingRect) == NO) {
        return effectiveScale;
    }

    CGAffineTransform transform = IJSVGViewBoxComputeTransform(viewBox,
                                                               drawingRect,
                                                               rootLayer.viewBoxAlignment,
                                                               rootLayer.viewBoxMeetOrSlice);
    CGFloat scaleX = hypot(transform.a, transform.c);
    CGFloat scaleY = hypot(transform.b, transform.d);
    CGFloat viewBoxScale = MAX(MIN(scaleX, scaleY), 0.f);
    if(viewBoxScale <= 0.f || isfinite(viewBoxScale) == NO) {
        return effectiveScale;
    }
    return effectiveScale * viewBoxScale;
}

@implementation IJSVGFilter

- (void)setDefaults
{
    [super setDefaults];
    self.units = IJSVGUnitObjectBoundingBox;
    self.contentUnits = IJSVGUnitUserSpaceOnUse;
}

- (BOOL)usesSRGBFilterInterpolation
{
    if(self.usesSRGBColorInterpolation == YES) {
        return YES;
    }
    for(IJSVGFilterEffect *effect in self.children) {
        if([effect isKindOfClass:IJSVGFilterEffectGaussianBlur.class] == NO) {
            continue;
        }
        IJSVGFilterEffectGaussianBlur *blurEffect = (IJSVGFilterEffectGaussianBlur *)effect;
        if(blurEffect.usesSRGBColorInterpolation == YES) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)valid
{
    return self.children.count != 0;
}

// Resolve a filter region attribute value against the element bbox dimension.
// In objectBoundingBox mode, percentages and plain numbers are relative to the
// element bbox. In userSpaceOnUse, plain numbers are absolute user-space units.
- (CGFloat)filterRegionValue:(IJSVGUnitLength*)unit forDimension:(CGFloat)dim
{
    if(unit.type == IJSVGUnitLengthTypePercentage) {
        return [unit computeValue:dim];
    }
    if(self.units == IJSVGUnitObjectBoundingBox &&
       unit.type == IJSVGUnitLengthTypeNumber) {
        return unit.value * dim;
    }
    return [unit computeValue:dim];
}

- (CGImageRef)newImageByApplyFilterToLayer:(CALayer<IJSVGDrawableLayer>*)layer
                                     scale:(CGFloat)scale
                               outputFrame:(CGRect*)outFrame
{
    IJSVGFilter* filter = layer.filter;
    layer.filter = nil;
    CGFloat effectiveScale = IJSVGFilterEffectiveScaleForLayer(layer, scale);
    if(outFrame != NULL) {
        *outFrame = CGRectZero;
    }

    // Move layer to origin and clear referencingLayer for bitmap rendering.
    // Store the original SVG position so gradient layers can compute
    // userSpaceOnUse coordinates correctly via IJSVGFilterElementOffset.
    CGRect savedFrame = layer.frame;
    CGRect savedOBB = layer.outerBoundingBox;
    CALayer<IJSVGDrawableLayer>* savedRef = layer.referencingLayer;
    float savedOpacity = layer.opacity;
    IJSVGThreadManager* threadMgr = nil;
    CGColorSpaceRef colorSpace = NULL;
    CGImageRef originalImage = NULL;
    CGImageRef outputImage = NULL;
    CIImage* sourceGraphic = nil;
    IJSVGFilterGraph* graph = nil;
    CIImage* output = nil;
    CIContext* context = nil;
    CGRect outputExtent = CGRectNull;
    BOOL resetLayerState = NO;
    BOOL resetThreadState = NO;

    if(effectiveScale <= 0.f || IJSVGFilterRectHasRenderableExtent(savedOBB) == NO) {
        goto cleanup;
    }

    // Compute the SVG filter region from x/y/width/height attributes.
    // Default filterUnits is objectBoundingBox: values are fractions of the
    // element bbox. Percentages are resolved by computeValue:, but plain
    // numbers (e.g. x="-.16711") must be multiplied by the bbox dimension.
    // SVG defaults: x=-10%, y=-10%, width=120%, height=120%.
    CGFloat elemW = savedOBB.size.width;
    CGFloat elemH = savedOBB.size.height;
    CGFloat frx = self.x != nil ? [self filterRegionValue:self.x forDimension:elemW] : -0.1 * elemW;
    CGFloat fry = self.y != nil ? [self filterRegionValue:self.y forDimension:elemH] : -0.1 * elemH;
    CGFloat frw = self.width != nil ? [self filterRegionValue:self.width forDimension:elemW] : 1.2 * elemW;
    CGFloat frh = self.height != nil ? [self filterRegionValue:self.height forDimension:elemH] : 1.2 * elemH;
    CGFloat regionMinX = frx;
    CGFloat regionMinY = fry;
    if(self.units == IJSVGUnitUserSpaceOnUse) {
        regionMinX -= savedOBB.origin.x;
        regionMinY -= savedOBB.origin.y;
    }
    CGRect localFilterRegion = CGRectMake(regionMinX, regionMinY, frw, frh);
    if(isfinite(frx) == NO ||
       isfinite(fry) == NO ||
       IJSVGFilterValueIsFiniteAndPositive(frw) == NO ||
       IJSVGFilterValueIsFiniteAndPositive(frh) == NO ||
       IJSVGFilterRectHasRenderableExtent(localFilterRegion) == NO) {
        goto cleanup;
    }
    // Padding must cover the filter region extent beyond the element on all sides,
    // and also provide enough room for blur kernels to compute correctly.
    CGFloat padLeft = MAX(0, -CGRectGetMinX(localFilterRegion));
    CGFloat padRight = MAX(0, CGRectGetMaxX(localFilterRegion) - elemW);
    CGFloat padTop = MAX(0, -CGRectGetMinY(localFilterRegion));
    CGFloat padBottom = MAX(0, CGRectGetMaxY(localFilterRegion) - elemH);
    CGFloat unscaledBitmapWidth = elemW + padLeft + padRight;
    CGFloat unscaledBitmapHeight = elemH + padTop + padBottom;
    effectiveScale = IJSVGFilterClampedScaleForBitmapSize(unscaledBitmapWidth,
                                                          unscaledBitmapHeight,
                                                          effectiveScale);
    CGFloat bitmapWidth = ceilf(unscaledBitmapWidth * effectiveScale);
    CGFloat bitmapHeight = ceilf(unscaledBitmapHeight * effectiveScale);
    if(IJSVGFilterValueIsFiniteAndPositive(bitmapWidth) == NO ||
       IJSVGFilterValueIsFiniteAndPositive(bitmapHeight) == NO) {
        goto cleanup;
    }
    size_t bmpW = (size_t)bitmapWidth;
    size_t bmpH = (size_t)bitmapHeight;
    if(IJSVGFilterBitmapSizeIsSafe(bmpW, bmpH) == NO) {
        goto cleanup;
    }

    CFStringRef colorSpaceName = self.usesSRGBFilterInterpolation == YES ?
        kCGColorSpaceSRGB : kCGColorSpaceLinearSRGB;
    colorSpace = CGColorSpaceCreateWithName(colorSpaceName);
    if(colorSpace == NULL) {
        goto cleanup;
    }
    uint32_t info = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little;

    if([layer isKindOfClass:IJSVGImageLayer.class]) {
        // Image layers can bypass the generic layer-tree renderer here and
        // draw their content directly into the padded filter bitmap.
        CGContextRef bmpCtx = CGBitmapContextCreate(NULL, bmpW, bmpH, 8, 0, colorSpace, info);
        if(bmpCtx == NULL) {
            goto cleanup;
        }
        CGContextScaleCTM(bmpCtx, effectiveScale, effectiveScale);
        CGContextTranslateCTM(bmpCtx, padLeft, padTop);
        [(IJSVGImageLayer *)layer drawInContext:bmpCtx];
        originalImage = CGBitmapContextCreateImage(bmpCtx);
        CGContextRelease(bmpCtx);
    } else {
        // Move layer to origin for rendering (standard approach)
        layer.frame = CGRectMake(0, 0, savedFrame.size.width, savedFrame.size.height);
        layer.outerBoundingBox = CGRectMake(0, 0, savedOBB.size.width, savedOBB.size.height);
        layer.referencingLayer = nil;
        resetLayerState = YES;

        layer.opacity = 1.0f;

        threadMgr = IJSVGThreadManager.currentManager;
        [threadMgr setUserInfoObject:@YES forKey:@"IJSVGFilterRendering"];
        [threadMgr setUserInfoObject:[NSValue valueWithPoint:NSMakePoint(savedOBB.origin.x, savedOBB.origin.y)]
                              forKey:@"IJSVGFilterElementOffset"];
        resetThreadState = YES;

        CGContextRef bmpCtx = CGBitmapContextCreate(NULL, bmpW, bmpH, 8, 0, colorSpace, info);
        if(bmpCtx == NULL) {
            goto cleanup;
        }
        CGContextScaleCTM(bmpCtx, effectiveScale, effectiveScale);
        CGContextTranslateCTM(bmpCtx, padLeft, padTop);
        [IJSVGLayer renderLayer:layer
                      inContext:bmpCtx
                        options:IJSVGLayerDrawingOptionNone];
        originalImage = CGBitmapContextCreateImage(bmpCtx);
        CGContextRelease(bmpCtx);
    }

    if(originalImage == NULL) {
        goto cleanup;
    }

    sourceGraphic = [CIImage imageWithCGImage:originalImage];
    if(sourceGraphic == nil) {
        goto cleanup;
    }

    graph = [[IJSVGFilterGraph alloc] initWithSourceGraphic:sourceGraphic scale:effectiveScale];
    graph.elementSVGOrigin = CGPointMake(savedOBB.origin.x - padLeft,
                                         savedOBB.origin.y - padTop);

    for(IJSVGFilterEffect* effect in self.children) {
        [effect processWithGraph:graph];
    }

    output = [graph lastResult];
    CGRect pixelFilterRegion = CGRectMake((padLeft + CGRectGetMinX(localFilterRegion)) * effectiveScale,
                                          (padTop + CGRectGetMinY(localFilterRegion)) * effectiveScale,
                                          frw * effectiveScale,
                                          frh * effectiveScale);
    if(IJSVGFilterRectHasRenderableExtent(pixelFilterRegion) == NO) {
        output = nil;
    } else if(output == nil || output == sourceGraphic) {
        output = [sourceGraphic imageByCroppingToRect:pixelFilterRegion];
    } else {
        output = [output imageByCroppingToRect:pixelFilterRegion];
    }

    outputExtent = output != nil ? output.extent : CGRectNull;
    if(IJSVGFilterRectHasRenderableExtent(outputExtent) == NO) {
        goto cleanup;
    }

    if(outFrame != NULL) {
        // Map the CIImage output extent from pixel space back to user-space
        // coordinates. Effects like feOffset shift the extent relative to the
        // pixel filter region; we must reflect that shift in the drawing frame
        // so the result is positioned correctly.
        *outFrame = CGRectMake(
            localFilterRegion.origin.x + (outputExtent.origin.x - pixelFilterRegion.origin.x) / effectiveScale,
            localFilterRegion.origin.y + (outputExtent.origin.y - pixelFilterRegion.origin.y) / effectiveScale,
            outputExtent.size.width / effectiveScale,
            outputExtent.size.height / effectiveScale
        );
    }

    context = IJSVGThreadManager.currentManager.CIContext;
#if TARGET_OS_IOS
    outputImage = [context createCGImage:output
                                fromRect:outputExtent
                                  format:kCIFormatRGBA8
                              colorSpace:colorSpace];
#else
    outputImage = [context createCGImage:output
                                fromRect:outputExtent];
#endif
    if(outputImage == NULL) {
        outputImage = CGImageCreateCopy(originalImage);
    }

cleanup:
    if(resetThreadState == YES) {
        [threadMgr setUserInfoObject:nil forKey:@"IJSVGFilterRendering"];
        [threadMgr setUserInfoObject:nil forKey:@"IJSVGFilterElementOffset"];
    }
    if(resetLayerState == YES) {
        layer.frame = savedFrame;
        layer.outerBoundingBox = savedOBB;
        layer.referencingLayer = savedRef;
        layer.opacity = savedOpacity;
    }
    if(colorSpace != NULL) {
        CGColorSpaceRelease(colorSpace);
    }
    if(originalImage != NULL) {
        CGImageRelease(originalImage);
    }
    layer.filter = filter;
    return outputImage;
}

- (void)addChild:(IJSVGNode*)child
{
    if([child isKindOfClass:IJSVGFilterEffect.class] == NO) {
        return;
    }
    [super addChild:child];
}

@end
