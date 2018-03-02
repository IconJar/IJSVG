//
//  IJSVGLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGLayer.h"
#import "IJSVGShapeLayer.h"
#import "IJSVGGroupLayer.h"
#import "IJSVG.h"


@implementation IJSVGLayer

@synthesize gradientFillLayer;
@synthesize patternFillLayer;
@synthesize gradientStrokeLayer;
@synthesize patternStrokeLayer;
@synthesize strokeLayer;
@synthesize requiresBackingScaleHelp;
@synthesize backingScaleFactor;
@synthesize blendingMode;
@synthesize convertMasksToPaths;

- (void)dealloc
{
    IJSVGBeginTransactionLock();
    [_maskingLayer release], _maskingLayer = nil;
    [super dealloc];
    IJSVGEndTransactionLock();
}

+ (NSArray *)deepestSublayersOfLayer:(CALayer *)layer
{
    NSMutableArray * arr = [[[NSMutableArray alloc] init] autorelease];
    for(CALayer * subLayer in layer.sublayers) {
        if(subLayer.sublayers.count != 0) {
            NSArray * moreLayers = [self deepestSublayersOfLayer:(IJSVGLayer *)subLayer];
            [arr addObjectsFromArray:moreLayers];
        } else {
            [arr addObject:subLayer];
        }
    }
    return arr;
}

+ (void)recursivelyWalkLayer:(CALayer *)layer
                   withBlock:(void (^)(CALayer * layer, BOOL isMask))block
{
    // call for layer and mask if there is one
    block(layer, NO);
    
    // do the mask too!
    if(layer.mask != nil) {
        block(layer.mask, YES);
    }
    
    // sublayers!!
    for(CALayer * aLayer in layer.sublayers) {
        [self recursivelyWalkLayer:aLayer
                         withBlock:block];
    }
}

- (void)addSublayer:(CALayer *)layer {
    if([layer isKindOfClass:[IJSVGLayer class]] == NO && 
       [layer isKindOfClass:[IJSVGShapeLayer class]] == NO) { 
        NSString * r = [NSString stringWithFormat:@"The layer must be an instance of IJSVGLayer, %@ given.", 
                        [layer class]]; 
        NSException * exception = [NSException exceptionWithName:@"IJSVGInvalidSublayerException"
                                                          reason:r 
                                                        userInfo:nil];
        @throw exception; 
    }
    [super addSublayer:layer];
} 

- (void)setBackingScaleFactor:(CGFloat)newFactor 
{ 
    if(self.backingScaleFactor == newFactor) {
        return;
    }
    backingScaleFactor = newFactor;
    self.contentsScale = newFactor;
    self.rasterizationScale = newFactor;
    [self setNeedsDisplay];
}

- (void)_customRenderInContext:(CGContextRef)ctx 
{ 
    if(self.convertMasksToPaths == YES && _maskingLayer != nil) {
        CGContextSaveGState(ctx); 
        [self applySublayerMaskToContext:ctx 
                             forSublayer:(IJSVGLayer *)self 
                              withOffset:CGPointZero]; 
        [super renderInContext:ctx]; 
        CGContextRestoreGState(ctx); 
        return; 
    } 
    [super renderInContext:ctx]; 
}

- (void)setConvertMasksToPaths:(BOOL)flag 
{
    if(convertMasksToPaths == flag) { 
        return; 
    } 
    convertMasksToPaths = flag; 
    if(flag == YES) {
        if(_maskingLayer != nil){
            [_maskingLayer release], _maskingLayer = nil;
        }
        _maskingLayer = [(IJSVGLayer *)self.mask retain];
        self.mask = nil; 
    } else { 
        self.mask = _maskingLayer;
        [_maskingLayer release], _maskingLayer = nil;
    } 
} 

- (void)applySublayerMaskToContext:(CGContextRef)context 
                       forSublayer:(IJSVGLayer *)sublayer
                        withOffset:(CGPoint)offset
{
    // apply any transforms needed
    CGPoint layerOffset = offset; 
    CGAffineTransform sublayerTransform = CATransform3DGetAffineTransform(sublayer.transform); 
    CGContextConcatCTM( context, CGAffineTransformInvert(sublayerTransform) );
    
    // walk up the superlayer chain
    CALayer * superlayer = self.superlayer; 
    if (IJSVGIsSVGLayer(superlayer) == YES) {
        [(IJSVGLayer *)superlayer applySublayerMaskToContext:context 
                                                 forSublayer:(IJSVGLayer *)self 
                                                  withOffset:layerOffset]; 
    } 
    
    // grab the masking layer
    IJSVGShapeLayer * maskingLayer = [self maskingLayer];
    
    // if its a group we need to get the lowest level children
    // and walk up the chain again
    if([maskingLayer isKindOfClass:[IJSVGGroupLayer class]]) { 
        NSArray * subs = [IJSVGLayer deepestSublayersOfLayer:maskingLayer]; 
        for(IJSVGLayer * subLayer in subs) { 
            [subLayer applySublayerMaskToContext:context 
                                     forSublayer:(IJSVGLayer *)self 
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

- (IJSVGShapeLayer *)maskingLayer
{ 
    return (IJSVGShapeLayer *)_maskingLayer ?: nil;
} 

- (void)renderInContext:(CGContextRef)ctx 
{ 
    if(self.blendingMode != kCGBlendModeNormal) { 
        CGContextSaveGState(ctx); 
        CGContextSetBlendMode(ctx, self.blendingMode); 
        [self _customRenderInContext:ctx]; 
        CGContextRestoreGState(ctx); 
        return; 
    } 
    [self _customRenderInContext:ctx]; 
}

@end
