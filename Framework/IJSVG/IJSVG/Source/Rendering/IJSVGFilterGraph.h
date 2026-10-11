//
//  IJSVGFilterGraph.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGRendering.h>
#import <CoreImage/CoreImage.h>
#import <IJSVGMetalShadowRenderer.h>
#import <IJSVGMetalBlurRenderer.h>

@interface IJSVGFilterGraph : NSObject

@property (nonatomic, strong) IJSVGFilter* filter;
@property (nonatomic, copy) IJSVGRenderingOptions* renderingOptions;
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

// A single matrix producing white with unchanged source alpha. Returns NULL otherwise.
// The source must be a renderer owned RGBA8 bitmap and stays unchanged.
- (CGImageRef)newCGImageForWhiteAlpha:(CGContextRef)bitmap;

// Plans direct blur/shadow rendering, choosing CPU or Metal by working set size.
// Returns NULL when Core Image is required.
- (CGImageRef)newCGImageForDirectBlur:(CGContextRef)bitmap;
- (IJSVGMetalShadowJob*)metalShadowJobForBitmap:(CGContextRef)bitmap;
- (IJSVGMetalBlurJob*)metalBlurJobForBitmap:(CGContextRef)bitmap;

@end
