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
@property (nonatomic, assign) BOOL usesImplicitObjectBoundingBoxViewBox;

@end

@implementation IJSVGPatternLayer

static BOOL IJSVGPatternLayerContainsImageLayer(CALayer<IJSVGDrawableLayer>* layer)
{
    if([layer isKindOfClass:NSClassFromString(@"IJSVGImageLayer")]) {
        return YES;
    }
    for(CALayer<IJSVGDrawableLayer>* sublayer in layer.sublayers) {
        if(IJSVGPatternLayerContainsImageLayer(sublayer) == YES) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)requiresBackingScale
{
    return YES;
}

- (void)setBackingScaleFactor:(CGFloat)backingScaleFactor
{
    [super setBackingScaleFactor:backingScaleFactor];
    [IJSVGLayer setBackingScaleFactor:backingScaleFactor
                        renderQuality:self.renderQuality
                   recursivelyToLayer:self.pattern];
}

void IJSVGPatternDrawingCallBack(void* info, CGContextRef ctx)
{
    // reassign the layer
    IJSVGPatternLayer* layer = (__bridge IJSVGPatternLayer*)info;
    CGSize size = layer.cellSize;
    CGContextSaveGState(ctx);
    CGRect rect = CGRectMake(0.f, 0.f, size.width, size.height);
    CGContextClipToRect(ctx, rect);
    
    IJSVGViewBoxAlignment alignment = layer.patternNode.viewBoxAlignment;
    IJSVGViewBoxMeetOrSlice meetOrSlice = layer.patternNode.viewBoxMeetOrSlice;
    if(layer.usesImplicitObjectBoundingBoxViewBox == YES) {
        alignment = IJSVGViewBoxAlignmentNone;
    }
    CGRect viewBox = layer.viewBox;
    IJSVGViewBoxDrawingBlock drawBlock = ^(CGFloat scale[]) {
        // Pattern content is rendered as a standalone layer subtree, so the
        // root pattern layer's frame origin is otherwise ignored. Preserve
        // that local origin here so stroked or offset pattern content aligns
        // to the tile the same way WebKit does.
        CGRect patternFrame = layer.pattern.frame;
        BOOL hasMeaningfulExtent = isfinite(patternFrame.size.width) &&
                                   isfinite(patternFrame.size.height) &&
                                   patternFrame.size.width > 0.f &&
                                   patternFrame.size.height > 0.f;
        if(layer.usesImplicitObjectBoundingBoxViewBox == NO &&
           hasMeaningfulExtent == YES &&
           (patternFrame.origin.x != 0.f || patternFrame.origin.y != 0.f)) {
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, patternFrame.origin.x, patternFrame.origin.y);
            [IJSVGLayer renderLayer:layer.pattern
                          inContext:ctx
                            options:IJSVGLayerDrawingOptionNone];
            CGContextRestoreGState(ctx);
            return;
        }
        [IJSVGLayer renderLayer:layer.pattern
                      inContext:ctx
                        options:IJSVGLayerDrawingOptionNone];
    };
    IJSVGContextDrawViewBox(ctx, viewBox, rect, alignment, meetOrSlice,
                            drawBlock);
    CGContextRestoreGState(ctx);
};

- (CALayer<IJSVGDrawableLayer>*)referencingLayer
{
    return [super referencingLayer] ?: self.superlayer;
}

- (void)computeCellSize:(CGSize*)cellSize
                viewBox:(CGRect*)viewBox
                 origin:(CGPoint*)origin
{
    CALayer<IJSVGDrawableLayer>* layer = (CALayer<IJSVGDrawableLayer>*)self.referencingLayer;
    CGRect rect = IJSVGLayerGetBoundingBoxBounds(layer);
    self.usesImplicitObjectBoundingBoxViewBox = NO;
    
    // get the bounds, we need these as when we render we might need to swap
    // the coordinates over to objectBoundingBox
    IJSVGUnitLength* xLength = _patternNode.x;
    IJSVGUnitLength* yLength = _patternNode.y;
    IJSVGUnitLength* wLength = _patternNode.width;
    IJSVGUnitLength* hLength = _patternNode.height;
        
    // actually do the swap if required
    if(_patternNode.units == IJSVGUnitObjectBoundingBox) {
        wLength = wLength.lengthByMatchingPercentage;
        hLength = hLength.lengthByMatchingPercentage;
        xLength = xLength.lengthByMatchingPercentage;
        yLength = yLength.lengthByMatchingPercentage;
    }
    
    *origin = CGPointMake([xLength computeValue:rect.size.width],
                          [yLength computeValue:rect.size.height]);
    
    CGFloat width = [wLength computeValue:rect.size.width];
    CGFloat height = [hLength computeValue:rect.size.height];
    *cellSize = CGSizeMake(width, height);
    
    // who knew that patterns have viewBoxes? Not me, but here is an implementation
    // of it anyway
    if(_patternNode.viewBox != nil && _patternNode.viewBox.isZeroRect == NO) {
        IJSVGUnitRect* nViewBox = _patternNode.viewBox;
        if(_patternNode.contentUnits == IJSVGUnitObjectBoundingBox) {
            nViewBox = [nViewBox copyByConvertingToUnitsLengthType:IJSVGUnitLengthTypePercentage];
        }
        *viewBox = [nViewBox computeValue:rect.size];
    } else {
        // Without an explicit viewBox, pattern content defaults to the pattern
        // content coordinate system. For objectBoundingBox content with raster
        // content the implicit viewBox is the OBB tile (0,0,1,1); anything an
        // authored <use> transform or oversized <image> places outside that
        // tile is clipped by the pattern boundary, matching WebKit. Using the
        // children's outer bounding box here instead would re-fit the
        // transformed content back into the tile and cancel out the very
        // transforms that should determine what's visible.
        if(_patternNode.contentUnits == IJSVGUnitObjectBoundingBox) {
            if(IJSVGPatternLayerContainsImageLayer(_pattern) == YES) {
                *viewBox = CGRectMake(0.f, 0.f, 1.f, 1.f);
                self.usesImplicitObjectBoundingBoxViewBox = YES;
            } else {
                *viewBox = CGRectMake(0.f, 0.f, cellSize->width, cellSize->height);
            }
        } else {
            *viewBox = CGRectMake(0.f, 0.f, cellSize->width, cellSize->height);
        }
    }
}

- (void)drawInContext:(CGContextRef)ctx
{
    // holder for callback
    static const CGPatternCallbacks callbacks = { 0, &IJSVGPatternDrawingCallBack, NULL };

    // create base pattern space
    CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern(NULL);
    CGContextSetFillColorSpace(ctx, patternSpace);
    CGColorSpaceRelease(patternSpace);
    
    CALayer<IJSVGDrawableLayer>* layer = (CALayer<IJSVGDrawableLayer>*)self.referencingLayer;
            
    // transform us back into the correct space
    CGAffineTransform transform = CGAffineTransformIdentity;
    if(_patternNode.units == IJSVGUnitUserSpaceOnUse) {
        transform = [IJSVGLayer userSpaceTransformForLayer:layer];
    }
    
    CGPoint origin = CGPointZero;
    [self computeCellSize:&_cellSize
                  viewBox:&_viewBox
                   origin:&origin];
    
    // transform the X and Y shift
    transform = CGAffineTransformConcat(transform, IJSVGConcatTransforms(self.patternNode.transforms));
    transform = CGAffineTransformTranslate(transform, origin.x, origin.y);
    
    // its possible that this layer is shifted inwards due to a stroke on the
    // parent layer
    transform = CGAffineTransformConcat(transform, [IJSVGLayer userSpaceTransformForLayer:self]);

    // Quartz invokes the CGPattern callback in pattern space rather than the
    // caller's transformed user space. Preserve the active context transform
    // in the pattern matrix so userSpaceOnUse tiles track root scaling and
    // element transforms such as rotation.
    CGAffineTransform contextTransform = CGContextGetCTM(ctx);
    if(CGAffineTransformIsIdentity(contextTransform) == NO) {
        transform = CGAffineTransformConcat(transform, contextTransform);
    }

    // create the pattern
    CGRect selfBounds = IJSVGLayerGetBoundingBoxBounds(self);
    CGRect patternBounds = CGRectMake(0.f, 0.f, _cellSize.width, _cellSize.height);
    CGPatternRef ref = CGPatternCreate((void*)self, patternBounds,
        transform, _cellSize.width, _cellSize.height,
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

- (IJSVGTraitedColorStorage*)colors
{
    return _pattern.colors;
}

@end
