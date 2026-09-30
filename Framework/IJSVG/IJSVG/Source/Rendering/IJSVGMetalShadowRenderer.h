//
//  IJSVGMetalShadowRenderer.h
//  IJSVG
//
//  Created on 30/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <simd/simd.h>

// Private fixed size descriptors shared by the CPU encoder and Metal kernels.
typedef struct {
    simd_uint4 geometry;
    simd_float4 region;
    simd_float4 offsets[4];
    simd_float4 tints[4];
    simd_uint4 config;
    float weights[128];
} IJSVGMetalShadowParameters;

// Each job owns its pixels; no CALayer, CGContext or thread local state crosses
// the GPU submission. Results are copied before the pooled buffers are released.
@interface IJSVGMetalShadowJob : NSObject
@property (nonatomic, strong) NSData* source;
@property (nonatomic, assign) IJSVGMetalShadowParameters parameters;
@property (nonatomic, readonly) CGImageRef renderedImage;

+ (BOOL)isAvailable;
+ (BOOL)renderJobs:(NSArray<IJSVGMetalShadowJob*>*)jobs;

@end
