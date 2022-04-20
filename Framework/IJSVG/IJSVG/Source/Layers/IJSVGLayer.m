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
#import "IJSVGTransformLayer.h"
#import "IJSVGRootLayer.h"

@implementation IJSVGLayer

- (instancetype)init
{
    if((self = [super init]) != nil) {
        _boundingBox = CGRectNull;
        _outerBoundingBox = CGRectNull;
    }
    return self;
}

- (CAShapeLayerFillRule)fillRule
{
    return kCAFillRuleNonZero;
}

- (CAShapeLayerFillRule)clipRule
{
    if(_clipRule == nil) {
        return self.fillRule;
    }
    return _clipRule;
}

+ (IJSVGLayerFillType)fillTypeForFill:(id)fill
{
    if([fill isKindOfClass:IJSVGColorNode.class]) {
        return IJSVGLayerFillTypeColor;
    }
    if([fill isKindOfClass:IJSVGGradient.class]) {
        return IJSVGLayerFillTypeGradient;
    }
    if([fill isKindOfClass:IJSVGPattern.class]) {
        return IJSVGLayerFillTypePattern;
    }
    return IJSVGLayerFillTypeUnknown;
}

+ (void)applyAbsoluteTransformForLayer:(CALayer<IJSVGDrawableLayer>*)layer
                             toContext:(CGContextRef)ctx
{
    CALayer<IJSVGDrawableLayer>* parentLayer = layer;
    while((parentLayer = parentLayer.referencingLayer) != nil) {
        CGContextConcatCTM(ctx, parentLayer.affineTransform);
        
        // only go up until we find a root layer, at that point, we know
        // we can stop looking
        if([parentLayer isKindOfClass:IJSVGRootLayer.class] == YES) {
            break;
        }
    }
    CGContextConcatCTM(ctx, layer.affineTransform);
}

+ (CGAffineTransform)absoluteTransformForLayer:(CALayer<IJSVGDrawableLayer>*)layer
{
    CGAffineTransform identity = CGAffineTransformIdentity;
    CALayer<IJSVGDrawableLayer>* parentLayer = layer;
    while((parentLayer = parentLayer.referencingLayer) != nil) {
        identity = [self absoluteTransformForLayer:parentLayer];
        
        // only go up until we find a root layer, at that point, we know
        // we can stop looking
        if([parentLayer isKindOfClass:IJSVGRootLayer.class] == YES) {
            break;
        }   
    }
    return CGAffineTransformConcat(identity, layer.affineTransform);
}

+ (CALayer<IJSVGDrawableLayer>*)rootLayerForLayer:(CALayer<IJSVGDrawableLayer>*)layer
{
    CALayer<IJSVGDrawableLayer>* parentLayer = (CALayer<IJSVGDrawableLayer>*)layer.referencingLayer;
    while([parentLayer isKindOfClass:IJSVGRootLayer.class] == NO &&
          parentLayer.referencingLayer != nil) {
        parentLayer = (CALayer<IJSVGDrawableLayer>*)parentLayer.referencingLayer;
    }
    return parentLayer;
}

+ (void)performBasicRenderOfLayer:(CALayer<IJSVGDrawableLayer>*)layer
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

+ (void)renderLayer:(CALayer<IJSVGDrawableLayer>*)layer
          inContext:(CGContextRef)ctx
{
    [self performBasicRenderOfLayer:layer
                          inContext:ctx];
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
    if([layer isKindOfClass:IJSVGShapeLayer.class]) {
        [self clipContextWithShapeLayer:(IJSVGShapeLayer*)layer
                              transform:transform
                              inContext:ctx];
        return;
    }
    
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
        [self clipContextWithShapeLayer:shapeLayer
                              transform:transform
                              inContext:ctx];
    }
}

+ (void)clipContextWithShapeLayer:(IJSVGShapeLayer*)shapeLayer
                        transform:(CGAffineTransform)transform
                        inContext:(CGContextRef)ctx
{
    CGAffineTransform drawTransform = CGAffineTransformConcat(transform,
                                                              shapeLayer.affineTransform);
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

+ (void)clipContextWithClip:(CALayer<IJSVGDrawableLayer>*)clipLayer
                    toLayer:(CALayer<IJSVGDrawableLayer>*)layer
                  inContext:(CGContextRef)ctx
               drawingBlock:(dispatch_block_t)drawingBlock
{
    CGContextSaveGState(ctx);
    [self recursivelyClip:clipLayer
                transform:CGAffineTransformIdentity
                inContext:ctx];
    if([layer.clipRule isEqualToString:kCAFillRuleEvenOdd]) {
        CGContextEOClip(ctx);
    } else {
        CGContextClip(ctx);
    }
    drawingBlock();
    CGContextRestoreGState(ctx);
}

+ (void)clipContextWithMask:(CALayer<IJSVGDrawableLayer>*)maskLayer
                    toLayer:(CALayer<IJSVGDrawableLayer>*)layer
                  inContext:(CGContextRef)ctx
               drawingBlock:(dispatch_block_t)drawingBlock
{
    CGContextSaveGState(ctx);
    CGFloat scale = layer.backingScaleFactor;
    CGRect rect = layer.innerBoundingBox;
    CGImageRef maskImage = [self newMaskImageForLayer:maskLayer
                                                scale:scale];

    CGContextClipToMask(ctx, rect, maskImage);
    drawingBlock();
    CGImageRelease(maskImage);
    CGContextRestoreGState(ctx);
}

+ (CGImageRef)newMaskImageForLayer:(CALayer<IJSVGDrawableLayer>*)layer
                             scale:(CGFloat)scale
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGImageRef ref = [self newImageForLayer:layer
                                 colorSpace:colorSpace
                                 bitmapInfo:kCGImageAlphaNone
                                      scale:scale];
    CGColorSpaceRelease(colorSpace);
    return ref;
}

+ (CGImageRef)newImageForLayer:(CALayer<IJSVGDrawableLayer>*)layer
                    colorSpace:(CGColorSpaceRef)colorSpace
                    bitmapInfo:(uint32_t)bitmapInfo
                         scale:(CGFloat)scale
{
    
    CGRect frame = layer.outerBoundingBox;
    CGRect bounds = layer.innerBoundingBox;
    CGContextRef offscreenContext = CGBitmapContextCreate(NULL,
                                                          ceilf(frame.size.width * scale),
                                                          ceilf(frame.size.height * scale),
                                                          8, 0, colorSpace, bitmapInfo);
    CGContextConcatCTM(offscreenContext, [self absoluteTransformForLayer:layer]);
    CGContextScaleCTM(offscreenContext, scale, scale);
    CGContextConcatCTM(offscreenContext, CGAffineTransformMakeTranslation(-bounds.origin.x, -bounds.origin.y));
    [IJSVGLayer renderLayer:layer
                  inContext:offscreenContext];
    CGImageRef image = CGBitmapContextCreateImage(offscreenContext);
    CGContextRelease(offscreenContext);
    return image;
}

+ (CGRect)absoluteFrameForLayer:(CALayer<IJSVGDrawableLayer>*)layer
{
    return (CGRect) {
      .origin = [self absoluteOriginForLayer:layer],
      .size = layer.frame.size
    };
}

+ (CGPoint)absoluteOriginForLayer:(CALayer<IJSVGDrawableLayer>*)layer
{
    CGPoint point = CGPointZero;
    CALayer<IJSVGDrawableLayer>* pLayer = layer;
    while (pLayer != nil) {
        point.x += pLayer.frame.origin.x;
        point.y += pLayer.frame.origin.y;
        pLayer = pLayer.referencingLayer;
    }
    return point;
}

+ (NSArray*)deepestSublayersOfLayer:(CALayer*)layer
{
    NSMutableArray* arr = [[NSMutableArray alloc] init];
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

+ (void)recursivelyWalkLayer:(CALayer<IJSVGBasicLayer>*)layer
                   withBlock:(void (^)(CALayer<IJSVGBasicLayer>* layer, BOOL* stop))block
{
    // call for layer and mask if there is one
    BOOL stop = NO;
    block(layer, &stop);
    if(stop == YES) {
        return;
    }

    // sublayers!!
    for (CALayer<IJSVGBasicLayer>* aLayer in layer.sublayers) {
        [self recursivelyWalkLayer:aLayer
                         withBlock:block];
    }
}

+ (void)setBackingScaleFactor:(CGFloat)scale
                renderQuality:(IJSVGRenderQuality)quality
           recursivelyToLayer:(CALayer<IJSVGDrawableLayer>*)layer
{
    [self recursivelyWalkLayer:layer
                     withBlock:^(CALayer<IJSVGBasicLayer>*sublayer, BOOL *stop) {
        if(sublayer.requiresBackingScale == YES) {
            sublayer.backingScaleFactor = scale;
        }
        sublayer.renderQuality = quality;
    }];
}

+ (void)logLayer:(CALayer<IJSVGDrawableLayer>*)layer
{
    [self logLayer:layer
             depth:0];
}

+ (void)logLayer:(CALayer<IJSVGDrawableLayer>*)layer
           depth:(NSUInteger)depth
{
    NSLog(@"%@ %@ frame: %@ transform: %@",[@"" stringByPaddingToLength:depth
                                    withString:@"- - "
                               startingAtIndex:0],  layer,
          NSStringFromRect(layer.frame),
          [IJSVGTransform affineTransformToSVGTransformComponentString:layer.affineTransform]);
    for(CALayer<IJSVGDrawableLayer>* sublayer in layer.debugLayers) {
        [self logLayer:sublayer
                 depth:depth+1];
    }
}

+ (CGRect)calculateFrameForSublayers:(NSArray<CALayer<IJSVGDrawableLayer>*>*)layers
{
    CGRect rect = CGRectNull;
    for(CALayer<IJSVGDrawableLayer>* layer in layers) {
        CGRect layerFrame = layer.outerBoundingBox;
        // if we are a transform layer, we can just apply its transform
        // to its sublayers and keep going down the tree
        if([layer isKindOfClass:IJSVGTransformLayer.class] == YES) {
            CGRect frame = [self calculateFrameForSublayers:layer.sublayers];
            frame = CGRectApplyAffineTransform(frame, layer.affineTransform);
            layerFrame = frame;
        }
        if(CGRectIsNull(rect)) {
            rect = layerFrame;
            continue;
        }
        rect = CGRectUnion(rect, layerFrame);
    }
    return rect;
}

- (void)setBackingScaleFactor:(CGFloat)newFactor
{
    if (_backingScaleFactor == newFactor) {
        return;
    }
    
    _backingScaleFactor = newFactor;
    self.contentsScale = newFactor;
    self.rasterizationScale = newFactor;
    
    // make sure its applied to any mask or clipPath
    _maskLayer.backingScaleFactor = newFactor;
    _clipLayer.backingScaleFactor = newFactor;
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    if(_maskLayer != nil) {
        [self.class clipContextWithMask:_maskLayer
                                toLayer:self
                              inContext:ctx
                           drawingBlock:^{
            [super renderInContext:ctx];
        }];
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
        _maskingLayer = (IJSVGLayer*)self.mask;
        self.mask = nil;
    } else {
        self.mask = _maskingLayer;
        _maskingLayer = nil;
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

- (CALayer<IJSVGDrawableLayer>*)rootLayer
{
    return [self.class rootLayerForLayer:self];
}

- (CGAffineTransform)absoluteTransform
{
    return [IJSVGLayer absoluteTransformForLayer:self];
}

- (BOOL)requiresBackingScale
{
    return _maskLayer != nil || _clipLayer != nil;
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

- (CGRect)absoluteFrame
{
    return [self.class absoluteFrameForLayer:self];
}

- (CGRect)boundingBox
{
    return CGRectIsNull(_boundingBox) == NO ? _boundingBox : self.frame;
}

- (CGRect)outerBoundingBox
{
    return CGRectIsNull(_outerBoundingBox) == NO ? _outerBoundingBox : self.frame;
}

- (CGRect)boundingBoxBounds
{
    return (CGRect) {
        .origin = CGPointZero,
        .size = self.boundingBox.size
    };
}

- (CGRect)innerBoundingBox
{
    return (CGRect) {
        .origin = CGPointZero,
        .size = self.outerBoundingBox.size
    };
}

- (CGRect)strokeBoundingBox
{
    return self.boundingBox;
}

- (CALayer<IJSVGDrawableLayer> *)referencingLayer
{
    return _referencingLayer ?: self.superlayer;
}

-(NSArray<CALayer<IJSVGDrawableLayer>*>*)debugLayers
{
    return self.sublayers;
}

@end
