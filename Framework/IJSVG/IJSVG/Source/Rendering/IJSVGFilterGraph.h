//
//  IJSVGFilterGraph.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilter.h>
#import <CoreImage/CoreImage.h>
#import "IJSVGMetalShadowRenderer.h"
#import "IJSVGMetalBlurRenderer.h"

@interface IJSVGFilterGraph : NSObject

@property (nonatomic, strong) IJSVGFilter* filter;
@property (nonatomic, assign) CGRect boundingBox;
@property (nonatomic, assign) CGRect viewPort;
@property (nonatomic, assign) CGRect extent;
@property (nonatomic, assign) CGAffineTransform imageTransform;
@property (nonatomic, strong) CIContext* context;
@property (nonatomic, assign) BOOL supportsMetalKernels;
@property (nonatomic, assign) BOOL hasNestedFilters;
@property (nonatomic, copy) CIImage* (^imageProvider)(IJSVGFilterPrimitive* primitive, CGRect region);
@property (nonatomic, copy) CIImage* (^paintProvider)(BOOL stroke);
@property (nonatomic, copy) CIImage* (^backgroundProvider)(void);

- (CGRect)regionForNode:(IJSVGNode*)node
                  units:(IJSVGUnitType)units
          defaultRegion:(CGRect)region;
- (CIImage*)imageByFilteringSource:(CIImage*)source;

// Returns NULL when the graph needs the general evaluator.
- (CGImageRef)newCGImageForSmallBlur:(CGContextRef)bitmap;
- (IJSVGMetalShadowJob*)metalShadowJobForBitmap:(CGContextRef)bitmap;
- (IJSVGMetalBlurJob*)metalBlurJobForBitmap:(CGContextRef)bitmap;

@end
