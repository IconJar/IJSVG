//
//  QuartzRenderer.m
//  IJSVGExample
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
// Compare the original node graph with its optimized vector export.
static void draw(IJSVG* svg, CGContextRef context, CGRect rect)
{
    CGContextSaveGState(context);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    [svg drawInRect:rect context:context];
    CGContextRestoreGState(context);
}

int main(int argc, char** argv)
{
    @autoreleasepool {
        if(argc < 3) {
            return 1;
        }
        puts("asset,size,original_ms,exported_ms,speedup,max_channel_error,mean_channel_error,changed_pixels_percent,cold_original_ms,cold_exported_ms");
        for(int argument = 2; argument < argc; argument++) {
            for(NSNumber* dimension in @[@64, @256, @900]) {
                @autoreleasepool {
                    NSUInteger width = dimension.unsignedIntegerValue;
                    CGRect rect = CGRectMake(0, 0, width, width);
                    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
                    CGContextRef contexts[2];
                    IJSVG* svgs[2];
                    double cold[2];
                    NSMutableArray<NSNumber*>* times[2] = { [[NSMutableArray alloc] init], [[NSMutableArray alloc] init] };
                    for(int backend = 0; backend < 2; backend++) {
                        NSError* error = nil;
                        svgs[backend] = [[IJSVG alloc] initWithFile:@(argv[argument]) error:&error];
                        if(svgs[backend] == nil) {
                            NSLog(@"%@", error);
                            return 2;
                        }
                        svgs[backend].rootNode.clientSize = rect.size;
                        svgs[backend].renderingBackingScaleHelper = ^CGFloat { return 1.f; };
                        contexts[backend] = CGBitmapContextCreate(NULL, width, width, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
                    }
                    // Include paint preparation in a separate first draw measurement.
                    for(int backend = 0; backend < 2; backend++) {
                        double start = NSProcessInfo.processInfo.systemUptime;
                        if(backend == 1) {
                            NSString* exported = [svgs[backend] SVGStringWithSize:rect.size options:IJSVGExporterOptionAll];
                            svgs[backend] = [[IJSVG alloc] initWithSVGString:exported];
                            if(svgs[backend] == nil) return 3;
                        }
                        draw(svgs[backend], contexts[backend], rect);
                        cold[backend] = (NSProcessInfo.processInfo.systemUptime - start) * 1000;
                    }
                    // Warm both paths and alternate order to reduce timing bias.
                    for(int iteration = -3; iteration < 15; iteration++) {
                        for(int order = 0; order < 2; order++) {
                            @autoreleasepool {
                                int backend = (iteration + 3 + order) % 2;
                                CGContextClearRect(contexts[backend], rect);
                                CFTimeInterval start = NSProcessInfo.processInfo.systemUptime;
                                draw(svgs[backend], contexts[backend], rect);
                                if(iteration >= 0) {
                                    [times[backend] addObject:@((NSProcessInfo.processInfo.systemUptime - start) * 1000)];
                                }
                            }
                        }
                    }
                    unsigned char* a = CGBitmapContextGetData(contexts[0]);
                    unsigned char* b = CGBitmapContextGetData(contexts[1]);
                    NSUInteger maximum = 0, changed = 0;
                    double total = 0;
                    for(NSUInteger pixel = 0; pixel < width * width; pixel++) {
                        BOOL different = NO;
                        for(NSUInteger channel = 0; channel < 4; channel++) {
                            NSUInteger offset = pixel * 4 + channel;
                            NSUInteger delta = abs((int)a[offset] - b[offset]);
                            maximum = MAX(maximum, delta);
                            total += delta;
                            different |= delta > 2;
                        }
                        changed += different;
                    }
                    double medians[2];
                    for(int backend = 0; backend < 2; backend++) {
                        NSArray* sorted = [times[backend] sortedArrayUsingSelector:@selector(compare:)];
                        medians[backend] = [sorted[sorted.count / 2] doubleValue];
                        CGImageRef image = CGBitmapContextCreateImage(contexts[backend]);
                        NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
                        NSString* path = [NSString stringWithFormat:@"%s/%@-%lu-%d.png", argv[1], @(argv[argument]).lastPathComponent, width, backend];
                        [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
                        CGImageRelease(image);
                        CGContextRelease(contexts[backend]);
                    }
                    CGColorSpaceRelease(space);
                    printf("%s,%lu,%.4f,%.4f,%.3f,%lu,%.4f,%.3f,%.4f,%.4f\n", argv[argument], width,
                           medians[0], medians[1], medians[0] / medians[1], maximum,
                           total / (width * width * 4), 100. * changed / (width * width), cold[0], cold[1]);
                    fflush(stdout);
                }
            }
        }
    }
    return 0;
}
