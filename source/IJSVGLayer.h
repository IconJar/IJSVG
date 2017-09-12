//
//  IJSVGLayer.h
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "IJSVGTransaction.h"

@class IJSVGShapeLayer;
@class IJSVGGradientLayer;
@class IJSVGPatternLayer;
@class IJSVGStrokeLayer;

#define IJSVG_LAYER_ADD_SUBVIEW_DEFAULT_IMPLEMENTATION \
- (void)addSublayer:(CALayer *)layer { \
    if([layer isKindOfClass:[IJSVGLayer class]] == NO && \
       [layer isKindOfClass:[IJSVGShapeLayer class]] == NO) { \
        NSString * r = [NSString stringWithFormat:@"The layer must be an instance of IJSVGLayer, %@ given.", \
                [layer class]]; \
        NSException * exception = [NSException exceptionWithName:@"IJSVGInvalidSublayerException"\
            reason:r \
            userInfo:nil];\
        @throw exception; \
    }\
    [super addSublayer:layer];\
} \
\
- (void)setBackingScaleFactor:(CGFloat)newFactor \
{ \
    if(self.backingScaleFactor == newFactor) { \
        return; \
    } \
    backingScaleFactor = newFactor; \
    self.contentsScale = newFactor; \
    self.rasterizationScale = newFactor; \
    [self setNeedsDisplay]; \
} \
\
- (void)_customRenderInContext:(CGContextRef)ctx \
{ \
   if(self.convertMasksToPaths == YES && self._tempMaskLayer != nil) { \
        CGContextSaveGState(ctx); \
        [self _clipContext:ctx  \
             withMaskLayer:_tempMaskLayer];\
        [super renderInContext:ctx]; \
        CGContextRestoreGState(ctx); \
        return; \
   } \
   [super renderInContext:ctx]; \
}\
\
- (void)setConvertMasksToPath:(BOOL)flag \
{ \
    if(convertMasksToPaths == flag) { \
        return; \
    } \
    convertMasksToPaths = flag; \
    if(flag == YES) { \
        self._tempMaskLayer = (IJSVGLayer *)self.mask; \
    } else { \
        self.mask = self._tempMaskLayer; \
        [_tempMaskLayer release], _tempMaskLayer = nil; \
    } \
} \
\
- (void)_clipContext:(CGContextRef)ctx  \
       withMaskLayer:(IJSVGLayer *)layer \
{ \
} \
\
- (void)renderInContext:(CGContextRef)ctx \
{ \
    if(self.blendingMode != kCGBlendModeNormal) { \
        CGContextSaveGState(ctx); \
        CGContextSetBlendMode(ctx, self.blendingMode); \
        [self _customRenderInContext:ctx]; \
        CGContextRestoreGState(ctx); \
        return; \
    } \
    [self _customRenderInContext:ctx]; \
} \
\
- (CGPoint)absoluteOrigin \
{\
    CGPoint point = CGPointZero; \
    CALayer * pLayer = self; \
    while(pLayer != nil) { \
        point.x += pLayer.frame.origin.x; \
        point.y += pLayer.frame.origin.y; \
        pLayer = pLayer.superlayer; \
    } \
    return point;\
}\

#define IJSVG_LAYER_DEFAULT_PROPERTIES \
@property (nonatomic, assign) IJSVGGradientLayer * gradientFillLayer; \
@property (nonatomic, assign) IJSVGPatternLayer * patternFillLayer; \
@property (nonatomic, assign) IJSVGStrokeLayer * strokeLayer; \
@property (nonatomic, assign) IJSVGGradientLayer * gradientStrokeLayer; \
@property (nonatomic, assign) IJSVGPatternLayer * patternStrokeLayer; \
@property (nonatomic, assign) BOOL requiresBackingScaleHelp; \
@property (nonatomic, assign) CGFloat backingScaleFactor; \
@property (nonatomic, assign) CGBlendMode blendingMode; \
@property (nonatomic, assign) CGPoint absoluteOrigin; \
@property (nonatomic, assign) BOOL convertMasksToPaths; \
@property (nonatomic, retain) IJSVGLayer * _tempMaskLayer; \

#define IJSVG_LAYER_DEFAULT_SYNTHESIZE \
@synthesize gradientFillLayer; \
@synthesize patternFillLayer; \
@synthesize gradientStrokeLayer; \
@synthesize patternStrokeLayer; \
@synthesize strokeLayer; \
@synthesize requiresBackingScaleHelp; \
@synthesize backingScaleFactor; \
@synthesize blendingMode; \
@synthesize convertMasksToPaths; \
@synthesize _tempMaskLayer;

#define IJSVG_LAYER_DEFAULT_DEALLOC_INSTRUCTIONS \
IJSVGBeginTransactionLock(); \
    [_tempMaskLayer release], _tempMaskLayer = nil; \
    [super dealloc]; \
IJSVGEndTransactionLock();

@interface IJSVGLayer : CALayer {
    
}

IJSVG_LAYER_DEFAULT_PROPERTIES

@end
