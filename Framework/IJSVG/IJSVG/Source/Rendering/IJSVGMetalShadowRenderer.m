//
//  IJSVGMetalShadowRenderer.m
//  IJSVG
//
//  Created on 30/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Metal/Metal.h>
#import <IJSVGMetalShadowRenderer.h>
#import <IJSVG/IJSVGFilterContext.h>

@interface IJSVGMetalShadowJob ()

@property (nonatomic, assign) CGImageRef renderedImage;

@end

@interface IJSVGMetalShadowBuffers : NSObject

@property (nonatomic, assign) BOOL busy;
@property (nonatomic, assign) NSUInteger capacity;
@property (nonatomic, strong) NSArray<id<MTLBuffer>>* buffers;

@end

@implementation IJSVGMetalShadowBuffers
@end

static id<MTLDevice> IJSVGShadowDevice;
static id<MTLCommandQueue> IJSVGShadowQueue;
static NSArray<id<MTLComputePipelineState>>* IJSVGShadowPipelines;
static NSLock* IJSVGShadowPoolLock;
static NSMutableArray<IJSVGMetalShadowBuffers*>* IJSVGShadowPool;

static BOOL IJSVGPrepareMetalShadows(void)
{
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        IJSVGShadowDevice = MTLCreateSystemDefaultDevice();
        if(IJSVGShadowDevice == nil || !IJSVGShadowDevice.hasUnifiedMemory) {
            return;
        }
        // Core Image pixel coordinates increase from bottom to top, while packed
        // Core Graphics bitmap rows run from top to bottom. Translated crops fuse
        // before blur, but the next primitive uses the integral Core Image extent.
        // Keep those two regions distinct to preserve fractional edge coverage.
        NSString* source = IJSVGFilterShaderSource(@"IJSVGInnerShadow");
        if(source == nil) {
            return;
        }
        MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
        options.fastMathEnabled = NO;
        id<MTLLibrary> library = [IJSVGShadowDevice newLibraryWithSource:source
                                                                 options:options
                                                                   error:NULL];
        if(library == nil) {
            return;
        }
        id<MTLFunction> horizontalFunction = [library newFunctionWithName:@"shadowHorizontal"];
        id<MTLFunction> verticalFunction = [library newFunctionWithName:@"shadowVertical"];
        if(horizontalFunction == nil || verticalFunction == nil) {
            return;
        }
        id<MTLComputePipelineState> horizontal =
            [IJSVGShadowDevice newComputePipelineStateWithFunction:horizontalFunction error:NULL];
        id<MTLComputePipelineState> vertical = [IJSVGShadowDevice newComputePipelineStateWithFunction:verticalFunction
                                                                                                error:NULL];
        if(horizontal == nil || vertical == nil) {
            return;
        }
        IJSVGShadowQueue = [IJSVGShadowDevice newCommandQueue];
        IJSVGShadowPipelines = @[horizontal, vertical];
        IJSVGShadowPoolLock = [[NSLock alloc] init];
        IJSVGShadowPool = [[NSMutableArray alloc] init];
    });
    return IJSVGShadowQueue != nil;
}

@implementation IJSVGMetalShadowJob

+ (BOOL)isAvailable
{
    return IJSVGPrepareMetalShadows();
}

- (void)dealloc
{
    if(_renderedImage != NULL) {
        CGImageRelease(_renderedImage);
    }
}

+ (BOOL)renderJobs:(NSArray<IJSVGMetalShadowJob*>*)jobs
{
    if(jobs.count == 0) {
        return YES;
    }
    if(jobs.count > 128 || !IJSVGPrepareMetalShadows()) {
        return NO;
    }
    NSUInteger count = 0, stages = 0;
    for(IJSVGMetalShadowJob* job in jobs) {
        NSUInteger width = job.parameters.geometry.x, height = job.parameters.geometry.y;
        if(width == 0 || height == 0 || width > 512 || height > 512 ||
            job.parameters.config.x == 0 || job.parameters.config.x > 4 ||
            job.source.length != width * height * 4) {
            return NO;
        }
        count += width * height;
        stages = MAX(stages, job.parameters.config.x);
    }
    if(count == 0 || count > 1048576) {
        return NO;
    }
    [IJSVGShadowPoolLock lock];
    IJSVGMetalShadowBuffers* slot = nil;
    for(IJSVGMetalShadowBuffers* candidate in IJSVGShadowPool) {
        if(!candidate.busy) {
            slot = candidate;
            break;
        }
    }
    if(slot == nil && IJSVGShadowPool.count < 6) {
        slot = [[IJSVGMetalShadowBuffers alloc] init];
        [IJSVGShadowPool addObject:slot];
    }
    slot.busy = YES;
    [IJSVGShadowPoolLock unlock];
    if(slot == nil) {
        return NO;
    }
    @try {
        if(slot.capacity < count) {
            NSUInteger capacity = 1024;
            while(capacity < count) {
                capacity *= 2;
            }
            NSUInteger sizes[] = {capacity * 4, capacity * sizeof(float),
                capacity * sizeof(simd_float4), capacity * 4, capacity * sizeof(uint32_t),
                128 * sizeof(IJSVGMetalShadowParameters)};
            NSMutableArray* buffers = [[NSMutableArray alloc] init];
            for(NSUInteger index = 0; index < 6; index++) {
                id<MTLBuffer> buffer = [IJSVGShadowDevice newBufferWithLength:sizes[index]
                                                                      options:MTLResourceStorageModeShared];
                if(buffer == nil) {
                    return NO;
                }
                [buffers addObject:buffer];
            }
            slot.buffers = buffers;
            slot.capacity = capacity;
        }
        uint8_t* source = slot.buffers[0].contents;
        uint32_t* mapping = slot.buffers[4].contents;
        IJSVGMetalShadowParameters* parameters = slot.buffers[5].contents;
        NSUInteger offset = 0;
        for(NSUInteger index = 0; index < jobs.count; index++) {
            IJSVGMetalShadowJob* job = jobs[index];
            parameters[index] = job.parameters;
            parameters[index].geometry.z = (uint32_t)offset;
            NSUInteger pixels = job.parameters.geometry.x * job.parameters.geometry.y;
            memcpy(source + offset * 4, job.source.bytes, pixels * 4);
            for(NSUInteger pixel = 0; pixel < pixels; pixel++) {
                mapping[offset + pixel] = (uint32_t)index;
            }
            offset += pixels;
        }
        id<MTLCommandBuffer> command = [IJSVGShadowQueue commandBuffer];
        if(command == nil) {
            return NO;
        }
        command.label = @"IJSVG inner shadows";
        for(uint32_t stage = 0; stage < stages; stage++) {
            for(id<MTLComputePipelineState> pipeline in IJSVGShadowPipelines) {
                id<MTLComputeCommandEncoder> encoder = [command computeCommandEncoder];
                if(encoder == nil) {
                    return NO;
                }
                [encoder setComputePipelineState:pipeline];
                for(NSUInteger index = 0; index < 6; index++) {
                    [encoder setBuffer:slot.buffers[index] offset:0
                               atIndex:index];
                }
                [encoder setBytes:&stage length:sizeof(stage) atIndex:6];
                NSUInteger threads = MIN(128, pipeline.maxTotalThreadsPerThreadgroup);
                [encoder dispatchThreads:MTLSizeMake(count, 1, 1)
                   threadsPerThreadgroup:MTLSizeMake(threads, 1, 1)];
                [encoder endEncoding];
            }
        }
        [command commit];
        // The public renderer returns a CPU readable CGImage. Wait only once for
        // all independent shadows, before releasing this exclusive buffer lease.
        [command waitUntilCompleted];
        if(command.status != MTLCommandBufferStatusCompleted) {
            return NO;
        }
      
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        const uint8_t* output = slot.buffers[3].contents;
        offset = 0;
        BOOL success = YES;
        for(IJSVGMetalShadowJob* job in jobs) {
            NSUInteger width = job.parameters.geometry.x, height = job.parameters.geometry.y;
            NSData* pixels = [NSData dataWithBytes:output + offset * 4
                                            length:width * height * 4];
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
            CGImageRef image = CGImageCreate(width, height, 8, 32, width * 4, space,
                                             kCGImageAlphaPremultipliedLast, provider,
                                             NULL, false, kCGRenderingIntentDefault);
            CGDataProviderRelease(provider);
            if(job.renderedImage != NULL) {
                CGImageRelease(job.renderedImage);
            }
            job.renderedImage = image;
            success &= image != NULL;
            offset += width * height;
        }
        CGColorSpaceRelease(space);
        return success;
    } @finally {
        // Do not permanently retain unusually large scratch allocations.
        if(slot.capacity > 262144) {
            slot.buffers = nil;
            slot.capacity = 0;
        }
        [IJSVGShadowPoolLock lock];
        slot.busy = NO;
        [IJSVGShadowPoolLock unlock];
    }
}
@end

