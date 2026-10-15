//
//  IJSVGFilterGraph.h
//  IJSVG
//
//  Created by Curtis Hard on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <CoreImage/CoreImage.h>
#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGRendering.h>
#import <IJSVGMetalBlurRenderer.h>
#import <IJSVGMetalShadowRenderer.h>

typedef NS_OPTIONS(NSUInteger, IJSVGFilterInputs) {
    IJSVGFilterInputSourceAlpha = 1 << 0,
    IJSVGFilterInputBackgroundImage = 1 << 1,
    IJSVGFilterInputBackgroundAlpha = 1 << 2,
    IJSVGFilterInputFillPaint = 1 << 3,
    IJSVGFilterInputStrokePaint = 1 << 4
};

@interface IJSVGFilterMetadata : NSObject
@property (nonatomic, strong, readonly) IJSVGFilter* filter;
@property (nonatomic, copy, readonly) NSArray<IJSVGFilterPrimitive*>* primitives;
@property (nonatomic, readonly) IJSVGFilterInputs inputs;
@property (nonatomic, readonly) BOOL usesBackdropAddition;
- (instancetype)initWithFilter:(IJSVGFilter*)filter;
@end

@interface IJSVGFilterGraph : NSObject

@property (nonatomic, strong) IJSVGFilter* filter;

// Supply metadata only for a resolved immutable filter.
@property (nonatomic, strong) IJSVGFilterMetadata* resolvedMetadata;
@property (nonatomic, readonly) NSArray<IJSVGFilterPrimitive*>* filterPrimitives;
@property (nonatomic, readonly) IJSVGFilterInputs filterInputs;
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

- (CGRect)regionForNode:(IJSVGGraphicsNode*)node units:(IJSVGUnitType)units defaultRegion:(CGRect)region;
- (CIImage*)imageByFilteringSource:(CIImage*)source;

// A single matrix producing white with unchanged source alpha. Returns NULL
// otherwise. The source must be a renderer owned RGBA8 bitmap and stays
// unchanged.
- (CGImageRef)newCGImageForWhiteAlpha:(CGContextRef)bitmap;

// Plans direct blur/shadow rendering, choosing CPU or Metal by working set
// size. Returns NULL when Core Image is required.
- (CGImageRef)newCGImageForDirectBlur:(CGContextRef)bitmap;
- (IJSVGMetalShadowJob*)metalShadowJobForBitmap:(CGContextRef)bitmap;
- (IJSVGMetalBlurJob*)metalBlurJobForBitmap:(CGContextRef)bitmap;

@end
