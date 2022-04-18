//
//  IJSVGPatternLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGPatternLayer.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGViewBox.h>

@interface IJSVGPatternLayer ()

@property (nonatomic, assign, readonly) CGSize cellSize;
@property (nonatomic, assign) CGRect viewBox;

@end

@implementation IJSVGPatternLayer

- (void)dealloc
{
    (void)([_pattern release]), _pattern = nil;
    (void)([_patternNode release]), _patternNode = nil;
    [super dealloc];
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
    CGRect rect = CGRectMake(0.f, 0.f, size.width, size.height);
    CGContextClipToRect(ctx, rect);
    
    IJSVGViewBoxAlignment alignment = layer.patternNode.viewBoxAlignment;
    IJSVGViewBoxMeetOrSlice meetOrSlice = layer.patternNode.viewBoxMeetOrSlice;
    CGRect viewBox = layer.viewBox;
    
    [IJSVGViewBox drawViewBox:viewBox
                       inRect:rect
                    alignment:alignment
                  meetOrSlice:meetOrSlice
                    inContext:ctx
                 drawingBlock:^(CGSize size) {
        [layer.pattern renderInContext:ctx];
    }];
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
    
    CGRect rect = self.referencingLayer.boundingBoxBounds;
    
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
        CGRect frame = layer.boundingBox;
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
    
    // who knew that patterns have viewBoxes? Not me, but here is an implementation
    // of it anyway
    if(_patternNode.viewBox != nil && _patternNode.viewBox.isZeroRect == NO) {
        if(_patternNode.units == IJSVGUnitObjectBoundingBox) {
            IJSVGUnitRect* viewBox = nil;
            viewBox = [[_patternNode.viewBox copyByConvertingToUnitsLengthType:IJSVGUnitLengthTypePercentage] autorelease];
            _viewBox = [viewBox computeValue:rect.size];
        }
    }
        
    // create the pattern
    CGRect selfBounds = self.boundingBoxBounds;
    CGPatternRef ref = CGPatternCreate((void*)self, selfBounds,
        transform, width, height,
        kCGPatternTilingConstantSpacing,
        true, &callbacks);

    // set the pattern then release it
    CGFloat alpha = 1.f;
    CGContextSetFillPattern(ctx, ref, &alpha);
    CGPatternRelease(ref);

    // fill it
    CGContextFillRect(ctx, selfBounds);
}

- (NSArray<CALayer<IJSVGDrawableLayer>*>*)debugLayers
{
    return @[self.pattern];
}

@end
