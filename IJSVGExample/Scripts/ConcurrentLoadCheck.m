//
//  ConcurrentLoadCheck.m
//  IJSVGExample
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#include <pthread.h>
#include <stdatomic.h>
#include <sys/resource.h>

@interface IJSVGConcurrentLoadResult : NSObject
@property (nonatomic, strong) IJSVG* svg;
@property (nonatomic, copy) NSString* failure;
@property (nonatomic) uint64_t threadID;
@end

@implementation IJSVGConcurrentLoadResult
@end

typedef struct {
    atomic_uint active;
    atomic_uint peak;
} IJSVGConcurrentLoadCounters;

static NSData* RenderPixels(IJSVG* svg)
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, 480, 480, 8, 480 * 4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (context == NULL) {
        return nil;
    }
    CGContextTranslateCTM(context, 0, 480);
    CGContextScaleCTM(context, 1, -1);
    svg.rootNode.clientSize = CGSizeMake(480, 480);
    svg.renderingBackingScaleHelper = ^CGFloat {
        return 1;
    };
    [svg drawInRect:CGRectMake(0, 0, 480, 480) context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:480 * 480 * 4];
    CGContextRelease(context);
    return pixels;
}

int main(int argc, const char** argv)
{
    @autoreleasepool {
        if (argc != 2 || MTLCreateSystemDefaultDevice() == nil) {
            return 2;
        }
        NSError* error = nil;
        NSString* source = [NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:&error];
        if (source == nil) {
            fprintf(stderr, "%s\n", error.description.UTF8String);
            return 3;
        }
        const NSUInteger count = 100;
        NSMutableArray<IJSVGConcurrentLoadResult*>* storage = [[NSMutableArray alloc] initWithCapacity:count];
        for (NSUInteger index = 0; index < count; index++) {
            [storage addObject:[[IJSVGConcurrentLoadResult alloc] init]];
        }
        NSArray<IJSVGConcurrentLoadResult*>* results = storage.copy;
        IJSVGConcurrentLoadCounters counters;
        atomic_init(&counters.active, 0);
        atomic_init(&counters.peak, 0);
        IJSVGConcurrentLoadCounters* sharedCounters = &counters;
        dispatch_queue_t queue = dispatch_queue_create("com.iconjar.IJSVG.concurrentLoadCheck", DISPATCH_QUEUE_CONCURRENT);
        dispatch_group_t group = dispatch_group_create();
        dispatch_suspend(queue);
        for (NSUInteger index = 0; index < count; index++) {
            dispatch_group_async(group, queue, ^{
                @autoreleasepool {
                    IJSVGConcurrentLoadResult* result = results[index];
                    uint64_t threadID = 0;
                    pthread_threadid_np(NULL, &threadID);
                    result.threadID = threadID;
                    unsigned active = atomic_fetch_add(&sharedCounters->active, 1) + 1;
                    unsigned peak = atomic_load(&sharedCounters->peak);
                    while (active > peak && !atomic_compare_exchange_weak(&sharedCounters->peak, &peak, active)) {
                    }
                    @try {
                        NSError* parseError = nil;
                        result.svg = [[IJSVG alloc] initWithSVGString:source error:&parseError];
                        if (result.svg == nil) {
                            result.failure = parseError.description ?: @"Loader returned nil";
                        }
                    } @catch (NSException* exception) {
                        result.failure = exception.description;
                    } @finally {
                        atomic_fetch_sub(&sharedCounters->active, 1);
                    }
                }
            });
        }
        double start = CACurrentMediaTime();
        dispatch_resume(queue);
        if (dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 180 * NSEC_PER_SEC)) != 0) {
            fprintf(stderr, "Concurrent loads timed out\n");
            exit(4);
        }
        double loadSeconds = CACurrentMediaTime() - start;
        fprintf(stderr, "100 blocks finished in %.3f seconds with %u overlapping loads\n", loadSeconds, atomic_load(&counters.peak));
        IJSVG* reference = [[IJSVG alloc] initWithSVGString:source error:&error];
        NSData* referencePixels = reference == nil ? nil : RenderPixels(reference);
        if (referencePixels == nil) {
            return 5;
        }
        NSMutableSet<NSNumber*>* threads = [[NSMutableSet alloc] init];
        NSMutableArray<NSDictionary*>* failures = [[NSMutableArray alloc] init];
        NSUInteger loaded = 0;
        NSUInteger matched = 0;
        for (NSUInteger index = 0; index < count; index++) {
            @autoreleasepool {
                IJSVGConcurrentLoadResult* result = results[index];
                [threads addObject:@(result.threadID)];
                if (result.svg != nil && result.failure == nil) {
                    loaded++;
                    @try {
                        NSData* pixels = RenderPixels(result.svg);
                        if ([pixels isEqualToData:referencePixels]) {
                            matched++;
                        } else {
                            result.failure = @"Pixels differ from the serial reference";
                        }
                    } @catch (NSException* exception) {
                        result.failure = exception.description;
                    }
                }
                if (result.failure != nil) {
                    [failures addObject:@{@"block" : @(index),
                        @"reason" : result.failure}];
                }
                result.svg = nil;
            }
        }
        struct rusage usage = { 0 };
        getrusage(RUSAGE_SELF, &usage);
        NSDictionary* report = @{
            @"svg" : @(argv[1]),
            @"blocks" : @(count),
            @"loaded" : @(loaded),
            @"pixelMatches" : @(matched),
            @"peakConcurrentLoads" : @(atomic_load(&counters.peak)),
            @"workerThreads" : @(threads.count),
            @"loadSeconds" : @(loadSeconds),
            @"peakRSSBytes" : @(usage.ru_maxrss),
            @"failures" : failures
        };
        NSData* json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
        fwrite(json.bytes, 1, json.length, stdout);
        putchar('\n');
        return loaded == count && matched == count && failures.count == 0 ? 0 : 1;
    }
}
