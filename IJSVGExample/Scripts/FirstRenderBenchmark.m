//
//  FirstRenderBenchmark.m
//  IJSVGExample
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

static double Median(double* values, NSUInteger count)
{
    for (NSUInteger i = 1; i < count; i++) {
        double value = values[i];
        NSUInteger j = i;
        while (j > 0 && values[j - 1] > value) {
            values[j] = values[j - 1];
            j--;
        }
        values[j] = value;
    }
    return values[count / 2];
}

// Keep parsing visible as a separate stack in Time Profiler.
__attribute__((noinline)) static IJSVG* ProfileParseDocument(NSString* source)
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:source];
    svg.rootNode.clientSize = CGSizeMake(480, 480);
    return svg;
}

static int ProfileParsing(NSString* fixturePath, NSString* fixtureName, double duration)
{
    if (duration <= 0 || duration > 300) {
        return 2;
    }
    NSArray<NSDictionary<NSString*, NSString*>*>* fixtures = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:fixturePath] options:0 error:nil];
    NSString* source = nil;
    for (NSDictionary<NSString*, NSString*>* fixture in fixtures) {
        if ([fixture[@"id"] isEqualToString:fixtureName]) {
            source = fixture[@"svg"];
            break;
        }
    }
    if (source == nil) {
        return 3;
    }
    double start = CACurrentMediaTime();
    NSUInteger iterations = 0;
    do {
        @autoreleasepool {
            IJSVG* svg = ProfileParseDocument(source);
            if (svg == nil) {
                return 4;
            }
            iterations++;
        }
    } while (CACurrentMediaTime() - start < duration);
    printf("%s,%lu,%.6f\n", fixtureName.UTF8String, iterations, CACurrentMediaTime() - start);
    return 0;
}

int main(int argc, const char** argv)
{
    @autoreleasepool {
        if (argc == 5 && strcmp(argv[1], "--profile-parsing") == 0) {
            return ProfileParsing(@(argv[2]), @(argv[3]), strtod(argv[4], NULL));
        }
        if (argc < 4) {
            return 2;
        }
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            fprintf(stderr, "Metal unavailable; refusing fallback benchmark\n");
            return 6;
        }
        fprintf(stderr, "Metal device: %s\n", device.name.UTF8String);
        NSArray* cases = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[1])] options:0 error:nil];
        NSUInteger size = strtoul(argv[2], NULL, 10);
        if (cases == nil || size == 0 || size > 2048) {
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
        puts("case,size,parse_ms,first_draw_ms,total_ms,warm_draw_ms,initial_parse_"
             "ms,initial_draw_ms,pixel_hash");
        for (NSDictionary* fixture in cases) {
            if (argc > 4 && ![fixture[@"id"] isEqualToString:@(argv[4])]) {
                continue;
            }
            double parses[15], draws[15], totals[15], redraws[15], initialParse = 0, initialDraw = 0;
            for (NSUInteger round = 0; round < 18; round++) {
                @autoreleasepool {
                    CGContextClearRect(context, rect);
                    double start = CACurrentMediaTime();
                    IJSVG* svg = [[IJSVG alloc] initWithSVGString:fixture[@"svg"]];
                    if (svg == nil) {
                        abort();
                    }
                    svg.rootNode.clientSize = rect.size;
                    svg.renderingBackingScaleHelper = ^CGFloat {
                        return 1;
                    };
                    double parsed = (CACurrentMediaTime() - start) * 1000;
                    start = CACurrentMediaTime();
                    [svg drawInRect:rect context:context];
                    double drawn = (CACurrentMediaTime() - start) * 1000;
                    CGContextClearRect(context, rect);
                    start = CACurrentMediaTime();
                    [svg drawInRect:rect context:context];
                    double redraw = (CACurrentMediaTime() - start) * 1000;
                    if (round == 0) {
                        initialParse = parsed;
                        initialDraw = drawn;
                    }
                    if (round >= 3) {
                        redraws[round - 3] = redraw;
                        parses[round - 3] = parsed;
                        draws[round - 3] = drawn;
                        totals[round - 3] = parsed + drawn;
                    }
                }
            }
            NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:size * size * 4];
            NSString* stem = [@(argv[3]) stringByAppendingPathComponent:fixture[@"id"]];
            if (![pixels writeToFile:[stem stringByAppendingString:@".rgba"] atomically:YES]) {
                return 5;
            }
            CGImageRef image = CGBitmapContextCreateImage(context);
            NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
            [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@ {}] writeToFile:[stem stringByAppendingString:@".png"] atomically:YES];
            CGImageRelease(image);
            const unsigned char* bytes = pixels.bytes;
            uint64_t hash = 14695981039346656037ULL;
            for (NSUInteger i = 0; i < pixels.length; i++) {
                hash = (hash ^ bytes[i]) * 1099511628211ULL;
            }
            printf("%s,%lu,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%016llx\n", [fixture[@"id"] UTF8String], size, Median(parses, 15), Median(draws, 15), Median(totals, 15), Median(redraws, 15), initialParse, initialDraw, (unsigned long long)hash);
            fflush(stdout);
        }
        CGContextRelease(context);
    }
    return 0;
}
