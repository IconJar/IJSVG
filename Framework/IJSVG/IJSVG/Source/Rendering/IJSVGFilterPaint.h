//
//  IJSVGFilterPaint.h
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGGroupPaint.h>
#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGRendering.h>

@interface IJSVGFilterPaint : IJSVGGroupPaint

@property (nonatomic, strong) IJSVGFilter* filter;
@property (nonatomic, copy) IJSVGRenderingOptions* renderingOptions;
@property (nonatomic, readonly) BOOL usesBackground;

// Only enable for resolved, immutable paint graphs. Rebuild the graph to invalidate.
@property (nonatomic, assign) BOOL cachesRenderedOutput;
@property (nonatomic, readonly) IJSVGPaint* sourcePaint;
- (instancetype)initWithSourcePaint:(IJSVGPaint*)paint
                              filter:(IJSVGFilter*)filter
                            viewPort:(CGRect)viewPort;

// Registers storage owned by the renderer; never probe an arbitrary display/PDF context.
+ (void)renderPaint:(IJSVGPaint*)paint inBitmapContext:(CGContextRef)context;
+ (BOOL)isRegisteredBitmapContext:(CGContextRef)context;
// Start a separate background for a container that requests one.
+ (void)drawBackgroundForPaint:(IJSVGPaint*)paint
                      context:(CGContextRef)context
                 drawingBlock:(void (^)(CGContextRef))drawingBlock;
+ (BOOL)shouldRenderPaintDuringCollection:(IJSVGPaint*)paint;

// Pass the destination pixel mapping through the complete drawing operation.
+ (void)drawInContext:(CGContextRef)context
      pixelTransform:(CGAffineTransform)pixelTransform
        drawingBlock:(void (^)(void))drawingBlock;

// Eligibility depends on the resolved graph and can be reused until it rebuilds.
+ (NSSet<IJSVGFilterPaint*>*)batchableFiltersForPaint:(IJSVGPaint*)root;
+ (BOOL)renderBatchedPaints:(NSSet<IJSVGFilterPaint*>*)eligiblePaints
                 inContext:(CGContextRef)context
              drawingBlock:(void (^)(CGContextRef))drawingBlock;

@end
