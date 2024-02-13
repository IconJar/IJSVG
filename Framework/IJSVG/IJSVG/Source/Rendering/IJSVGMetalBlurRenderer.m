//
//  IJSVGMetalBlurRenderer.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGMetalBlurRenderer.h>
#import <Metal/Metal.h>
#if SWIFT_PACKAGE
#import <IJSVG/IJSVGFilterContext.h>
#import <IJSVG/IJSVGXEntities.h>
#endif
#import <simd/simd.h>

typedef struct {
    simd_uint4 geometry;
    simd_float4 region;
    simd_uint4 config;
    simd_float4 shadowOffset;
    simd_float4 shadowTint;
    float weights[76];
} IJSVGMetalBlurParameters;

@interface IJSVGMetalBlurJob ()
@property (nonatomic, strong) NSData* source;
@property (nonatomic, strong) NSData* weights;
@property (nonatomic, assign) IJSVGMetalBlurParameters parameters;
@property (nonatomic, strong) XColorSpace* colorSpace;
@property (nonatomic, assign) CGImageRef renderedImage;
@end

@implementation IJSVGMetalBlurJob
- (void)dealloc
{
    if(_renderedImage != NULL) {
        CGImageRelease(_renderedImage);
    }
}
@end

@interface IJSVGMetalBlurBuffers : NSObject
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, assign) NSUInteger capacity;
@property (nonatomic, strong) NSArray<id<MTLBuffer>>* buffers;
@end

@implementation IJSVGMetalBlurBuffers
@end

static id<MTLDevice> IJSVGBlurDevice;
static id<MTLCommandQueue> IJSVGBlurQueue;
static NSArray<id<MTLComputePipelineState>>* IJSVGBlurPipelines;
static NSLock* IJSVGBlurPoolLock;
static NSMutableArray<IJSVGMetalBlurBuffers*>* IJSVGBlurPool;

static BOOL IJSVGPrepareMetalBlur(void)
{
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        IJSVGBlurDevice = MTLCreateSystemDefaultDevice();
        // Shared CPU/GPU storage is the path measured here. Other GPUs use CI.
        if(IJSVGBlurDevice == nil || !IJSVGBlurDevice.hasUnifiedMemory) {
            return;
        }
#if SWIFT_PACKAGE
        // Copy shader sources so both Xcode and command-line package builds work.
        NSString* source = IJSVGFilterShaderSource(@"IJSVGBlur");
        id<MTLLibrary> library = source != nil
            ? [IJSVGBlurDevice newLibraryWithSource:source
                                            options:nil
                                              error:NULL] : nil;
#else
        NSBundle* bundle = [NSBundle bundleForClass:IJSVGMetalBlurRenderer.class];
        id<MTLLibrary> library = [IJSVGBlurDevice newDefaultLibraryWithBundle:bundle error:NULL];
#endif
        if(library == nil) {
            return;
        }
        NSMutableArray* pipelines = [[NSMutableArray alloc] init];
        for(NSString* name in @[@"blurPrepare", @"blurHorizontal", @"blurVertical"]) {
            id<MTLFunction> function = [library newFunctionWithName:name];
            if(function == nil) {
                return;
            }
            id<MTLComputePipelineState> pipeline = [IJSVGBlurDevice newComputePipelineStateWithFunction:function
                                                                                                  error:NULL];
            if(pipeline == nil) {
                return;
            }
            [pipelines addObject:pipeline];
        }
        IJSVGBlurPipelines = pipelines;
        IJSVGBlurPoolLock = [[NSLock alloc] init];
        IJSVGBlurPool = [[NSMutableArray alloc] init];
        IJSVGBlurQueue = [IJSVGBlurDevice newCommandQueue];
    });
    return IJSVGBlurQueue != nil;
}

@implementation IJSVGMetalBlurRenderer

+ (IJSVGMetalBlurJob*)jobForBitmap:(CGContextRef)bitmap
                            region:(CGRect)region
                           weights:(NSData*)weights
                         linearRGB:(BOOL)linearRGB
                       sourceCrops:(NSUInteger)sourceCrops
{
    if(bitmap == NULL) {
        return nil;
    }
    NSUInteger width = CGBitmapContextGetWidth(bitmap), height = CGBitmapContextGetHeight(bitmap);
    NSUInteger taps = weights.length / sizeof(float);
    // Bound allocations and kernel work. This path only accepts packed RGBA8.
    if(width == 0 || height == 0 || width > 2048 || height > 2048 ||
        width * height > 1048576 || weights.length != taps * sizeof(float) ||
        taps == 0 || taps > 75 || taps % 2 == 0 || sourceCrops < 1 || sourceCrops > 2 ||
        CGBitmapContextGetBitsPerComponent(bitmap) != 8 ||
        CGBitmapContextGetBitsPerPixel(bitmap) != 32 ||
        CGBitmapContextGetAlphaInfo(bitmap) != kCGImageAlphaPremultipliedLast ||
        (CGBitmapContextGetBitmapInfo(bitmap) & kCGBitmapByteOrderMask) != kCGBitmapByteOrderDefault ||
        CGBitmapContextGetData(bitmap) == NULL || CGBitmapContextGetBytesPerRow(bitmap) < width * 4 ||
        !isfinite(region.origin.x) || !isfinite(region.origin.y) ||
        !isfinite(CGRectGetMaxX(region)) || !isfinite(CGRectGetMaxY(region)) ||
        CGRectIsEmpty(region) || !IJSVGPrepareMetalBlur()) {
        return nil;
    }
    NSMutableData* source = [NSMutableData dataWithLength:width * height * 4];
    NSUInteger stride = CGBitmapContextGetBytesPerRow(bitmap);
    for(NSUInteger y = 0; y < height; y++) {
        memcpy((uint8_t*)source.mutableBytes + y * width * 4,
               (const uint8_t*)CGBitmapContextGetData(bitmap) + y * stride, width * 4);
    }
    IJSVGMetalBlurJob* job = [[IJSVGMetalBlurJob alloc] init];
    job.source = source;
    job.weights = [weights copy];
    job.colorSpace = [[XColorSpace alloc] initWithCGColorSpace:CGBitmapContextGetColorSpace(bitmap)];
    job.parameters = (IJSVGMetalBlurParameters){
        .geometry = {(uint32_t)width, (uint32_t)height, (uint32_t)taps, (uint32_t)sourceCrops},
        .region = {CGRectGetMinX(region), CGRectGetMinY(region), CGRectGetMaxX(region), CGRectGetMaxY(region)},
        .config = {linearRGB, 0, 0, 0}
    };
    IJSVGMetalBlurParameters parameters = job.parameters;
    memcpy(parameters.weights, weights.bytes, weights.length);
    job.parameters = parameters;
    return job;
}

+ (IJSVGMetalBlurJob*)shadowJobForBitmap:(CGContextRef)bitmap
                                  region:(CGRect)region
                                 weights:(NSData*)weights
                               linearRGB:(BOOL)linearRGB
                                  offset:(CGSize)offset
                                   color:(CGColorRef)color
{
    if(!isfinite(offset.width) || !isfinite(offset.height) || color == NULL ||
        CGColorGetNumberOfComponents(color) != 4) {
        return nil;
    }
    IJSVGMetalBlurJob* job = [self jobForBitmap:bitmap
                                         region:region
                                        weights:weights
                                      linearRGB:linearRGB
                                    sourceCrops:1];
    if(job == nil) {
        return nil;
    }
    const CGFloat* components = CGColorGetComponents(color);
    IJSVGMetalBlurParameters parameters = job.parameters;
    parameters.config.z = 1;
    parameters.shadowOffset = (simd_float4){offset.width, offset.height, 0, 0};
    parameters.shadowTint = (simd_float4){components[0], components[1], components[2], components[3]};
    job.parameters = parameters;
    return job;
}

+ (CGImageRef)newImageForBitmap:(CGContextRef)bitmap
                        region:(CGRect)region
                       weights:(NSData*)weights
                     linearRGB:(BOOL)linearRGB
                   sourceCrops:(NSUInteger)sourceCrops
{
    IJSVGMetalBlurJob* job = [self jobForBitmap:bitmap
                                         region:region
                                        weights:weights
                                      linearRGB:linearRGB
                                    sourceCrops:sourceCrops];
    return job != nil && [self renderJobs:@[job]] ? CGImageRetain(job.renderedImage) : NULL;
}

+ (BOOL)renderJobs:(NSArray<IJSVGMetalBlurJob*>*)jobs
{
    if(jobs.count == 0) {
        return YES;
    }
    if(jobs.count > 128 || !IJSVGPrepareMetalBlur()) {
        return NO;
    }
    NSUInteger count = 0;
    for(IJSVGMetalBlurJob* job in jobs) {
        NSUInteger pixels = (NSUInteger)job.parameters.geometry.x * job.parameters.geometry.y;
        if(pixels == 0 || pixels > 1048576 || job.source.length != pixels * 4) {
            return NO;
        }
        count += pixels;
        if(count > 1048576) {
            return NO;
        }
    }
    [IJSVGBlurPoolLock lock];
    IJSVGMetalBlurBuffers* slot = nil;
    for(IJSVGMetalBlurBuffers* candidate in IJSVGBlurPool) {
        if(!candidate.busy) {
            slot = candidate;
            break;
        }
    }
    if(slot == nil && IJSVGBlurPool.count < 6) {
        slot = [[IJSVGMetalBlurBuffers alloc] init];
        [IJSVGBlurPool addObject:slot];
    }
    slot.busy = YES;
    [IJSVGBlurPoolLock unlock];
    if(slot == nil) {
        return NO;
    }
    @try {
        if(slot.capacity < count) {
            NSUInteger capacity = 1024;
            while(capacity < count) {
                capacity *= 2;
            }
            NSUInteger sizes[] = {capacity * 4, capacity * sizeof(simd_float4),
                capacity * sizeof(simd_float4), capacity * 4,
                capacity * sizeof(uint32_t), 128 * sizeof(IJSVGMetalBlurParameters)};
            NSMutableArray* buffers = [[NSMutableArray alloc] init];
            for(NSUInteger i = 0; i < 6; i++) {
                id<MTLBuffer> buffer = [IJSVGBlurDevice newBufferWithLength:sizes[i]
                                                                    options:MTLResourceStorageModeShared];
                if(buffer == nil) {
                    return NO;
                }
                [buffers addObject:buffer];
            }
            slot.buffers = buffers;
            slot.capacity = capacity;
        }
        NSUInteger offset = 0;
        uint32_t* mapping = slot.buffers[4].contents;
        IJSVGMetalBlurParameters* parameters = slot.buffers[5].contents;
        for(NSUInteger index = 0; index < jobs.count; index++) {
            IJSVGMetalBlurJob* job = jobs[index];
            NSUInteger pixels = job.source.length / 4;
            memcpy((uint8_t*)slot.buffers[0].contents + offset * 4, job.source.bytes, job.source.length);
            parameters[index] = job.parameters;
            parameters[index].config.y = (uint32_t)offset;
            for(NSUInteger pixel = 0; pixel < pixels; pixel++) {
                mapping[offset + pixel] = (uint32_t)index;
            }
            offset += pixels;
        }
        id<MTLCommandBuffer> command = [IJSVGBlurQueue commandBuffer];
        if(command == nil) {
            return NO;
        }
        command.label = @"IJSVG batched Gaussian blurs";
        for(id<MTLComputePipelineState> pipeline in IJSVGBlurPipelines) {
            id<MTLComputeCommandEncoder> encoder = [command computeCommandEncoder];
            if(encoder == nil) {
                return NO;
            }
            [encoder setComputePipelineState:pipeline];
            for(NSUInteger i = 0; i < 4; i++) {
                [encoder setBuffer:slot.buffers[i] offset:0
                           atIndex:i];
            }
            [encoder setBuffer:slot.buffers[5] offset:0 atIndex:4];
            [encoder setBuffer:slot.buffers[4] offset:0 atIndex:5];
            NSUInteger threads = MIN(128, pipeline.maxTotalThreadsPerThreadgroup);
            [encoder dispatchThreads:MTLSizeMake(count, 1, 1)
               threadsPerThreadgroup:MTLSizeMake(threads, 1, 1)];
            [encoder endEncoding];
        }
        [command commit];
        [command waitUntilCompleted];
        if(command.status != MTLCommandBufferStatusCompleted) {
            return NO;
        }
        // Copy every completed slice before releasing the exclusive buffer lease.
        offset = 0;
        for(IJSVGMetalBlurJob* job in jobs) {
            NSUInteger width = job.parameters.geometry.x, height = job.parameters.geometry.y;
            NSData* pixels = [NSData dataWithBytes:(uint8_t*)slot.buffers[3].contents + offset * 4
                                            length:width * height * 4];
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
            if(provider == NULL) {
                return NO;
            }
            CGImageRef result = CGImageCreate(width, height, 8, 32, width * 4,
                job.colorSpace.CGColorSpace, kCGImageAlphaPremultipliedLast,
                provider, NULL, false, kCGRenderingIntentDefault);
            CGDataProviderRelease(provider);
            if(result == NULL) {
                return NO;
            }
            if(job.renderedImage != NULL) {
                CGImageRelease(job.renderedImage);
            }
            job.renderedImage = result;
            offset += width * height;
        }
        return YES;
    } @finally {
        if(slot.capacity > 262144) {
            slot.buffers = nil;
            slot.capacity = 0;
        }
        [IJSVGBlurPoolLock lock];
        slot.busy = NO;
        [IJSVGBlurPoolLock unlock];
    }
}

@end
