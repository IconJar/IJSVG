//
//  IJSVGLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVG.h"
#import "IJSVGGroupLayer.h"
#import "IJSVGLayer.h"
#import "IJSVGShapeLayer.h"

@implementation IJSVGLayer

- (void)dealloc
{
    (void)([_clipLayer release]), _clipLayer = nil;
    (void)([_maskingLayer release]), _maskingLayer = nil;
    [super dealloc];
}

+ (void)renderLayer:(CALayer<IJSVGDrawableLayer>*)layer
          inContext:(CGContextRef)ctx
{
    dispatch_block_t drawingBlock = ^{
        [layer performRenderInContext:ctx];
    };
    [self applyBlendingMode:layer.blendingMode
                  toContext:ctx
               drawingBlock:^{
        // we need to clip first
        if(layer.clipLayer == nil) {
            drawingBlock();
            return;
        }
        [self clipContextWithClip:layer.clipLayer
                          toLayer:layer
                        inContext:ctx
                     drawingBlock:drawingBlock];
    }];
}

+ (void)applyBlendingMode:(CGBlendMode)blendMode
                toContext:(CGContextRef)ctx
             drawingBlock:(dispatch_block_t)drawingBlock
{
    if (blendMode != kCGBlendModeNormal) {
        CGContextSaveGState(ctx);
        CGContextSetBlendMode(ctx, blendMode);
        drawingBlock();
        CGContextRestoreGState(ctx);
        return;
    }
    drawingBlock();
}

/// Shape layers are the only thing we can clip, as they contain a path, however
/// the layer passed to us from a clip could have groups contained with in it that
/// have transforms on them, so simply recursively iterate over them and concat
/// their transforms down to the path and clip at the end with the path.
+ (void)recursivelyClip:(CALayer<IJSVGDrawableLayer>*)layer
              transform:(CGAffineTransform)transform
              inContext:(CGContextRef)ctx
{
    for(CALayer<IJSVGDrawableLayer>* drawableLayer in layer.sublayers) {
        CGAffineTransform drawTransform = CGAffineTransformConcat(transform,
                                                                  drawableLayer.affineTransform);
        
        // If its not a shape layer, just go down the tree until we find one
        if([drawableLayer isKindOfClass:IJSVGShapeLayer.class] == NO) {
            [self recursivelyClip:drawableLayer
                        transform:drawTransform
                        inContext:ctx];
            continue;
        }
        IJSVGShapeLayer* shapeLayer = (IJSVGShapeLayer*)drawableLayer;
        
        // Shape layers paths are reset back to 0,0 origin, so in order to be
        // correct path, we need to shift it back to where it belongs.
        drawTransform = CGAffineTransformTranslate(transform,
                                               shapeLayer.frame.origin.x,
                                               shapeLayer.frame.origin.y);
        CGPathRef path = CGPathCreateCopyByTransformingPath(shapeLayer.path,
                                                            &drawTransform);
        CGContextAddPath(ctx, path);
        CGPathRelease(path);
    }
}

+ (void)clipContextWithClip:(CALayer<IJSVGDrawableLayer>*)clipLayer
                    toLayer:(CALayer<IJSVGDrawableLayer>*)layer
                  inContext:(CGContextRef)ctx
               drawingBlock:(dispatch_block_t)drawingBlock
{
    CGContextSaveGState(ctx);
    [self recursivelyClip:clipLayer
                transform:CGAffineTransformIdentity
                inContext:ctx];
    CGContextClip(ctx);
    drawingBlock();
    CGContextRestoreGState(ctx);
}

+ (void)clipContextWithMask:(CALayer<IJSVGDrawableLayer>*)maskLayer
                    toLayer:(CALayer<IJSVGDrawableLayer>*)layer
                  inContext:(CGContextRef)ctx
               drawingBlock:(dispatch_block_t)drawingBlock
{    
    CGContextSaveGState(ctx);
    CGRect bounds = layer.bounds;
    CGFloat scale = layer.contentsScale;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef offscreenContext = CGBitmapContextCreate(NULL, bounds.size.width * scale,
                                                          bounds.size.height * scale, 8, 0,
                                                          colorSpace, kCGImageAlphaNone);
    
    CGContextScaleCTM(offscreenContext, scale, scale);
    CGContextTranslateCTM(offscreenContext, maskLayer.frame.origin.x, maskLayer.frame.origin.y);

    [maskLayer renderInContext:offscreenContext];
    CGImageRef maskImage = CGBitmapContextCreateImage(offscreenContext);
    CGContextClipToMask(ctx, CGRectMake(0.f, 0.f,
                                        bounds.size.width,
                                        bounds.size.height), maskImage);
    
    CGImageRelease(maskImage);
    CGContextRelease(offscreenContext);
    CGColorSpaceRelease(colorSpace);
    
    drawingBlock();
    
    CGContextRestoreGState(ctx);
}

+ (NSArray*)deepestSublayersOfLayer:(CALayer*)layer
{
    NSMutableArray* arr = [[[NSMutableArray alloc] init] autorelease];
    for (CALayer* subLayer in layer.sublayers) {
        if (subLayer.sublayers.count != 0) {
            NSArray* moreLayers = [self deepestSublayersOfLayer:(IJSVGLayer*)subLayer];
            [arr addObjectsFromArray:moreLayers];
        } else {
            [arr addObject:subLayer];
        }
    }
    return arr;
}

+ (void)recursivelyWalkLayer:(CALayer*)layer
                   withBlock:(void (^)(CALayer* layer, BOOL isMask, BOOL* stop))block
{
    // call for layer and mask if there is one
    BOOL stop = NO;
    block(layer, NO, &stop);
    if(stop == YES) {
        return;
    }

    // do the mask too!
    if (layer.mask != nil) {
        block(layer.mask, YES, &stop);
        if(stop == YES) {
            return;
        }
    }

    // sublayers!!
    for (CALayer* aLayer in layer.sublayers) {
        [self recursivelyWalkLayer:aLayer
                         withBlock:block];
    }
}

- (void)setBackingScaleFactor:(CGFloat)newFactor
{
    if (_backingScaleFactor == newFactor) {
        return;
    }
    _backingScaleFactor = newFactor;
    self.contentsScale = newFactor;
    self.rasterizationScale = newFactor;
    if(self.mask != nil) {
        self.mask.contentsScale = newFactor;
        self.mask.rasterizationScale = newFactor;
        [self.mask setNeedsDisplay];
    }
    [self setNeedsDisplay];
}

- (void)performRenderInContext:(CGContextRef)ctx
{
//    if (_convertMasksToPaths == YES && _maskingLayer != nil) {
//        CGContextSaveGState(ctx);
//        [self applySublayerMaskToContext:ctx
//                             forSublayer:(IJSVGLayer*)self
//                              withOffset:CGPointZero];
//        [super renderInContext:ctx];
//        CGContextRestoreGState(ctx);
//        return;
//    }
//    if(CGRectEqualToRect(self.bounds, CGRectZero)) {
//        [super renderInContext:ctx];
//        return;
//    }
    if(self.mask != nil) {
        IJSVGLayer* mask = self.mask;
        self.mask = nil;
        [self.class clipContextWithMask:mask
                                toLayer:self
                              inContext:ctx
                           drawingBlock:^{
            [super renderInContext:ctx];
        }];
        self.mask = mask;
        return;
    }
    [super renderInContext:ctx];
}

- (void)setConvertMasksToPaths:(BOOL)flag
{
    if (_convertMasksToPaths == flag) {
        return;
    }
    _convertMasksToPaths = flag;
    if (flag == YES) {
        if (_maskingLayer != nil) {
            (void)([_maskingLayer release]), _maskingLayer = nil;
        }
        _maskingLayer = [(IJSVGLayer*)self.mask retain];
        self.mask = nil;
    } else {
        self.mask = _maskingLayer;
        (void)([_maskingLayer release]), _maskingLayer = nil;
    }
}

- (void)applySublayerMaskToContext:(CGContextRef)context
                       forSublayer:(IJSVGLayer*)sublayer
                        withOffset:(CGPoint)offset
{
    // apply any transforms needed
    CGPoint layerOffset = offset;
    CGAffineTransform sublayerTransform = CATransform3DGetAffineTransform(sublayer.transform);
    CGContextConcatCTM(context, CGAffineTransformInvert(sublayerTransform));

    // walk up the superlayer chain
    CALayer* superlayer = self.superlayer;
    if (IJSVGIsSVGLayer(superlayer) == YES) {
        [(IJSVGLayer*)superlayer applySublayerMaskToContext:context
                                                forSublayer:(IJSVGLayer*)self
                                                 withOffset:layerOffset];
    }

    // grab the masking layer
    IJSVGShapeLayer* maskingLayer = [self maskingLayer];

    // if its a group we need to get the lowest level children
    // and walk up the chain again
    if ([maskingLayer isKindOfClass:[IJSVGGroupLayer class]]) {
        NSArray* subs = [IJSVGLayer deepestSublayersOfLayer:maskingLayer];
        for (IJSVGLayer* subLayer in subs) {
            [subLayer applySublayerMaskToContext:context
                                     forSublayer:(IJSVGLayer*)self
                                      withOffset:layerOffset];
        }
    } else if ([maskingLayer isKindOfClass:[IJSVGShapeLayer class]]) {
        // is a shape, go for it!
        CGPathRef maskPath = maskingLayer.path;
        CGContextTranslateCTM(context, -layerOffset.x, -layerOffset.y);
        CGContextAddPath(context, maskPath);
        CGContextClip(context);
        CGContextTranslateCTM(context, layerOffset.x, layerOffset.y);
    }
    CGContextConcatCTM(context, sublayerTransform);
}

- (IJSVGShapeLayer*)maskingLayer
{
    return (IJSVGShapeLayer*)_maskingLayer ?: nil;
}

- (void)renderInContext:(CGContextRef)ctx
{
    [IJSVGLayer renderLayer:self
                  inContext:ctx];
}

- (id<CAAction>)actionForKey:(NSString*)event
{
    return nil;
}

@end
