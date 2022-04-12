//
//  IJSVGPatternLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGPatternLayer.h"
#import "IJSVGTransform.h"

@interface IJSVGPatternLayer ()

@property (nonatomic, assign, readonly) CGSize cellSize;

@end

@implementation IJSVGPatternLayer

- (void)dealloc
{
    (void)([_pattern release]), _pattern = nil;
    (void)([_patternNode release]), _patternNode = nil;
    [super dealloc];
}

- (id)init
{
    if ((self = [super init]) != nil) {
        self.shouldRasterize = YES;
    }
    return self;
}

- (BOOL)requiresBackingScaleHelp
{
    return YES;
}

void IJSVGPatternDrawingCallBack(void* info, CGContextRef ctx)
{
    // reassign the layer
    IJSVGPatternLayer* layer = (IJSVGPatternLayer*)info;
    CGSize size = layer.cellSize;
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, CGRectMake(0.f, 0.f, size.width, size.height));
    [layer.pattern renderInContext:ctx];
    CGContextSaveGState(ctx);
};

- (CALayer<IJSVGDrawableLayer>*)referencingLayer
{
    return [super referencingLayer] ?: self.superlayer;
}

- (void)drawInContext:(CGContextRef)ctx
{
    // holder for callback
    static const CGPatternCallbacks callbacks = { 0, &IJSVGPatternDrawingCallBack, NULL };

    // create base pattern space
    CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern(NULL);
    CGContextSetFillColorSpace(ctx, patternSpace);
    CGColorSpaceRelease(patternSpace);
    
    CGRect rect = self.boundingBox;
    
    IJSVGUnitLength* wLength = _patternNode.width;
    IJSVGUnitLength* hLength = _patternNode.height;
    
    if(self.patternNode.units == IJSVGUnitObjectBoundingBox ||
       self.patternNode.contentUnits == IJSVGUnitObjectBoundingBox) {
        wLength = wLength.lengthByMatchingPercentage;
        hLength = hLength.lengthByMatchingPercentage;
    }
    
    CGFloat width = [wLength computeValue:rect.size.width];
    CGFloat height = [hLength computeValue:rect.size.height];
    _cellSize = CGSizeMake(width, height);
    
    CALayer<IJSVGDrawableLayer>* layer = (CALayer<IJSVGDrawableLayer>*)self.referencingLayer;
        
    // transform us back into the correct space
    CGAffineTransform transform = CGAffineTransformIdentity;
    if (self.patternNode.units == IJSVGUnitUserSpaceOnUse) {
        CGRect frame = layer.frame;
        transform = [IJSVGLayer absoluteTransformForLayer:layer];
        transform = CGAffineTransformTranslate(transform,
                                               -CGRectGetMinX(frame),
                                               -CGRectGetMinY(frame));
    }

    transform = CGAffineTransformConcat(transform, IJSVGConcatTransforms(self.patternNode.transforms));
    // transform the X and Y shift
    transform = CGAffineTransformTranslate(transform,
                                           [_patternNode.x computeValue:rect.size.width],
                                           [_patternNode.y computeValue:rect.size.height]);
    
    // create the pattern
    CGPatternRef ref = CGPatternCreate((void*)self, rect,
        transform, width, height,
        kCGPatternTilingConstantSpacing,
        true, &callbacks);

    // set the pattern then release it
    CGFloat alpha = 1.f;
    CGContextSetFillPattern(ctx, ref, &alpha);
    CGPatternRelease(ref);

    // fill it
    CGContextFillRect(ctx, rect);
}

@end
