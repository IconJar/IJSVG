//
//  IJSVGFilterPaint.h
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGGroupPaint.h>
#import <IJSVG/IJSVGFilter.h>

@interface IJSVGFilterPaint : IJSVGGroupPaint

@property (nonatomic, strong) IJSVGFilter* filter;
@property (nonatomic, readonly) IJSVGPaint* sourcePaint;
- (instancetype)initWithSourcePaint:(IJSVGPaint*)paint
                              filter:(IJSVGFilter*)filter
                            viewPort:(CGRect)viewPort;
+ (BOOL)shouldRenderPaintDuringCollection:(IJSVGPaint*)paint;

// Eligibility depends on the resolved graph and can be reused until it rebuilds.
+ (NSSet<IJSVGFilterPaint*>*)batchableFiltersForPaint:(IJSVGPaint*)root;
+ (BOOL)renderBatchedPaints:(NSSet<IJSVGFilterPaint*>*)eligiblePaints
                 inContext:(CGContextRef)context
              drawingBlock:(void (^)(CGContextRef))drawingBlock;

@end
