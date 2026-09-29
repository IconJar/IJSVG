//
//  IJSVGFilterLayer.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterLayer.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGFilterGraph.h>
#import <IJSVG/IJSVGLayerTree.h>
#import <CoreImage/CoreImage.h>

static BOOL IJSVGFilterRectIsFinite(CGRect rect)
{
    return isfinite(rect.origin.x) && isfinite(rect.origin.y)
        && isfinite(rect.size.width) && isfinite(rect.size.height);
}

// Nested filters already inherit the drawing transform of the supersampled bitmap.
static _Thread_local NSUInteger IJSVGFilterRenderDepth = 0;

@implementation IJSVGFilterLayer

- (instancetype)initWithSourceLayer:(CALayer<IJSVGDrawableLayer>*)layer
                             filter:(IJSVGFilter*)filter
                           viewPort:(CGRect)viewPort
{
    if((self = [super init]) != nil) {
        _filter = filter;
        _viewPort = viewPort;
        self.boundingBox = layer.boundingBox;
        self.outerBoundingBox = layer.outerBoundingBox;
        [self addSublayer:layer];
    }
    return self;
}

- (CALayer<IJSVGDrawableLayer>*)sourceLayer
{
    return (CALayer<IJSVGDrawableLayer>*)self.sublayers.firstObject;
}

- (BOOL)treatImplicitOriginAsTransform
{
    return self.sourceLayer.treatImplicitOriginAsTransform;
}

- (BOOL)requiresBackingScale
{
    return YES;
}

- (CIImage*)paintImageForStroke:(BOOL)stroke
                          graph:(IJSVGFilterGraph*)graph
{
    IJSVGNode* paint = stroke ? self.sourceNode.stroke : self.sourceNode.fill;
    if(paint == nil) {
        return CIImage.emptyImage;
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(
        NULL, graph.extent.size.width, graph.extent.size.height, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if(bitmap == NULL) {
        return CIImage.emptyImage;
    }
    CGContextConcatCTM(bitmap, graph.imageTransform);
    CGRect region = CGRectApplyAffineTransform(graph.extent, CGAffineTransformInvert(graph.imageTransform));
    IJSVGLayerTree* tree = [[IJSVGLayerTree alloc] init];
    [tree drawPaint:paint
        boundingBox:self.boundingBox
           viewPort:self.viewPort
             region:region
          inContext:bitmap];
    CGImageRef result = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    CIImage* image = result != NULL ? [CIImage imageWithCGImage:result] : CIImage.emptyImage;
    if(result != NULL) {
        CGImageRelease(result);
    }
    return image;
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    if(self.hidden == YES || self.opacity == 0.f) {
        return;
    }
    dispatch_block_t drawingBlock = ^{
        CGContextSaveGState(ctx);
        CGContextSetAlpha(ctx, self.opacity);
        [self drawInContext:ctx];
        CGContextRestoreGState(ctx);
    };
    if(self.maskLayer != nil) {
        [IJSVGLayer clipContextWithMask:self.maskLayer
                                toLayer:self
                              inContext:ctx
                           drawingBlock:drawingBlock];
    } else {
        drawingBlock();
    }
}

- (BOOL)requiresFilterSupersampling
{
    if(self.filter.requiresSupersampling) {
        return YES;
    }
  
    // An outer filter must supply enough source resolution for nested hard alpha effects.
    NSMutableArray<CALayer*>* pending = [self.sublayers mutableCopy];
    while(pending.count != 0) {
        CALayer* layer = pending.lastObject;
        [pending removeLastObject];
        if([layer isKindOfClass:IJSVGFilterLayer.class]) {
            if([(IJSVGFilterLayer*)layer requiresFilterSupersampling]) {
                return YES;
            }
        } else if(layer.sublayers.count != 0) {
            [pending addObjectsFromArray:layer.sublayers];
        }
    }
    return NO;
}

- (void)drawInContext:(CGContextRef)ctx
{
    IJSVGFilterRenderDepth++;
    @try {
        [self drawFilterInContext:ctx];
    } @finally {
        IJSVGFilterRenderDepth--;
    }
}

- (CIImage*)backgroundImageFromContext:(CGContextRef)ctx
                        imageTransform:(CGAffineTransform)imageTransform
{
    // Bitmap destinations can supply their already painted backdrop.
    // Nonbitmap contexts have no readable pixel backing.
    if(CGBitmapContextGetData(ctx) == NULL) {
        return CIImage.emptyImage;
    }
    CGImageRef background = CGBitmapContextCreateImage(ctx);
    if(background == NULL) {
        return CIImage.emptyImage;
    }
    CIImage* image = [CIImage imageWithCGImage:background];
    CGImageRelease(background);
    CGAffineTransform mapping
        = CGAffineTransformConcat(CGAffineTransformInvert(CGContextGetCTM(ctx)), imageTransform);
    return [image imageByApplyingTransform:mapping];
}

- (void)drawFilterInContext:(CGContextRef)ctx
{
    IJSVGFilterGraph* graph = [[IJSVGFilterGraph alloc] init];
    graph.filter = self.filter;
    graph.boundingBox = self.boundingBox;
    graph.viewPort = self.viewPort;
    CGRect region = [graph regionForNode:_filter
                                   units:_filter.units
                           defaultRegion:CGRectZero];
  
    if(IJSVGFilterRectIsFinite(region) == NO || CGRectIsEmpty(region) == YES) {
        return;
    }

    CGRect workRect = CGRectUnion(self.outerBoundingBox, region);
    if(IJSVGFilterRectIsFinite(workRect) == NO || CGRectIsEmpty(workRect) == YES) {
        return;
    }

    // Use the actual drawing transform so zoom, export size and Retina all
    // produce the same effect in SVG units. Bound temporary raster storage.
    CGAffineTransform transform = CGContextGetCTM(ctx);
    CGFloat scale = MAX(hypot(transform.a, transform.b), hypot(transform.c, transform.d));
  
    // Only alpha amplifying matrices need extra coverage samples. Ordinary blurs
    // and shadows retain destination resolution instead of processing 4x the pixels.
    if(IJSVGFilterRenderDepth == 1 && [self requiresFilterSupersampling]) {
        scale *= 2.f;
  
    }
    scale = MIN(scale, 4096.f / MAX(workRect.size.width, workRect.size.height));
  
    // Floating point primitive buffers need four times the source bitmap storage.
    scale = MIN(scale, sqrt(4194304.f / (workRect.size.width * workRect.size.height)));
    if(isfinite(scale) == NO || scale <= 0.f) {
        return;
    }
  
    workRect = CGRectApplyAffineTransform(workRect, CGAffineTransformMakeScale(scale, scale));
    workRect = CGRectIntegral(workRect);
    workRect = CGRectApplyAffineTransform(workRect, CGAffineTransformMakeScale(1.f / scale, 1.f / scale));
    CGSize pixelSize = CGSizeMake(round(workRect.size.width * scale),
                                  round(workRect.size.height * scale));
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, pixelSize.width, pixelSize.height,
                                                8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
  
    if(bitmap == NULL) {
        CGColorSpaceRelease(colorSpace);
        return;
    }
  
    CGContextScaleCTM(bitmap, scale, scale);
    CGContextTranslateCTM(bitmap, -workRect.origin.x, -workRect.origin.y);
    CALayer<IJSVGDrawableLayer>* sourceLayer = self.sourceLayer;
    CGContextTranslateCTM(bitmap, sourceLayer.frame.origin.x, sourceLayer.frame.origin.y);
    [sourceLayer renderInContext:bitmap];
    CGImageRef sourceImage = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
  
    if(sourceImage == NULL) {
        CGColorSpaceRelease(colorSpace);
        return;
    }

    CIImage* source = [CIImage imageWithCGImage:sourceImage];
    CGImageRelease(sourceImage);
    CGRect extent = CGRectMake(0.f, 0.f, pixelSize.width, pixelSize.height);
    // Keep filter coordinates aligned with the source bitmap. The calling context
    // drawing transform handles flipped views and image exports.
    CGAffineTransform imageTransform = CGAffineTransformMake(scale, 0.f, 0.f,
                                                             scale, -workRect.origin.x * scale,
                                                             -workRect.origin.y * scale);
    CIContext* context = IJSVGThreadManager.currentManager.CIContext;
    graph.context = context;
    graph.extent = extent;
    graph.imageTransform = imageTransform;
    __weak IJSVGFilterGraph* weakGraph = graph;
    graph.paintProvider = ^CIImage*(BOOL stroke) {
      return [self paintImageForStroke:stroke
                                 graph:weakGraph];
    };
    graph.backgroundProvider = ^CIImage* {
        return [self backgroundImageFromContext:ctx
                                imageTransform:imageTransform];
    };
  
    CIImage* output = [graph imageByFilteringSource:source];
    CGImageRef image = [context createCGImage:output
                                     fromRect:extent
                                       format:kCIFormatRGBA8
                                   colorSpace:colorSpace];
  
    if(image != NULL) {
        CGContextSaveGState(ctx);
        CGContextClipToRect(ctx, region);
        CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
        CGContextDrawImage(ctx, workRect, image);
        CGContextRestoreGState(ctx);
        CGImageRelease(image);
    }
  
    CGColorSpaceRelease(colorSpace);
}

@end
