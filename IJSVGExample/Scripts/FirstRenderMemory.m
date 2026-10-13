//
//  FirstRenderMemory.m
//  IJSVGExample
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

// Isolated process memory measurements for the same complete SVG loader and
// first render workload as FirstRenderBenchmark.m. Run separately from timing.
#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <Metal/Metal.h>
#import <mach/mach.h>
#import <sys/resource.h>

static uint64_t Footprint(void)
{
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    return task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) == KERN_SUCCESS ? info.phys_footprint : 0;
}

int main(int argc, const char** argv)
{
    @autoreleasepool {
        if (argc != 3 || MTLCreateSystemDefaultDevice() == nil) {
            return 2;
        }
        NSString* source = [NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:nil];
        NSUInteger size = strtoul(argv[2], NULL, 10);
        if (source == nil || size == 0 || size > 2048) {
            return 3;
        }
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef context = CGBitmapContextCreate(NULL, size, size, 8, size * 4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space);
        if (context == NULL) {
            return 4;
        }
        CGContextTranslateCTM(context, 0, size);
        CGContextScaleCTM(context, 1, -1);
        CGRect rect = CGRectMake(0, 0, size, size);

        // Initialize common runtime/rendering state before taking the baseline.
        @autoreleasepool {
            IJSVG* warmup = [[IJSVG alloc] initWithSVGString:@"<svg width='10' height='10'><rect width='10' height='10'/></svg>"];
            warmup.rootNode.clientSize = rect.size;
            warmup.renderingBackingScaleHelper = ^CGFloat {
                return 1;
            };
            [warmup drawInRect:rect context:context];
        }
        CGContextClearRect(context, rect);
        uint64_t before = Footprint();
        __attribute__((objc_precise_lifetime)) IJSVG* svg = nil;
        @autoreleasepool {
            svg = [[IJSVG alloc] initWithSVGString:source];
            if (svg == nil) {
                return 5;
            }
            svg.rootNode.clientSize = rect.size;
            svg.renderingBackingScaleHelper = ^CGFloat {
                return 1;
            };
        }
        uint64_t parsed = Footprint();
        @autoreleasepool {
            [svg drawInRect:rect context:context];
        }
        uint64_t rendered = Footprint();
        struct rusage usage = { 0 };
        getrusage(RUSAGE_SELF, &usage);
        printf("{\"before_bytes\":%llu,\"parsed_bytes\":%llu,\"rendered_bytes\":%llu,\"peak_rss_bytes\":%llu}\n", (unsigned long long)before, (unsigned long long)parsed, (unsigned long long)rendered, (unsigned long long)usage.ru_maxrss);
        CGContextRelease(context);
    }
    return 0;
}
