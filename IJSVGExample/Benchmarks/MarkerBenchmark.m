//
//  MarkerBenchmark.m
//  IJSVGExample
//
//  Created by Curtis Hard on 09/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <QuartzCore/QuartzCore.h>

static double MedianTime(NSUInteger iterations, void (^operation)(void))
{
    NSMutableArray<NSNumber*>* samples = [[NSMutableArray alloc] initWithCapacity:7];
    operation();
    for(NSUInteger sample = 0; sample < 7; sample++) {
        double start = CACurrentMediaTime();
        for(NSUInteger iteration = 0; iteration < iterations; iteration++) {
            @autoreleasepool {
                operation();
            }
        }
        [samples addObject:@((CACurrentMediaTime() - start) * 1000 / iterations)];
    }
    [samples sortUsingSelector:@selector(compare:)];
    return samples[3].doubleValue;
}

static NSString* DenseDocument(NSUInteger vertices, BOOL contextPaint, BOOL zeroLength)
{
    NSMutableString* path = [[NSMutableString alloc] initWithCapacity:vertices * 18];
    for(NSUInteger index = 0; index < vertices; index++) {
        [path appendFormat:@"%c%lu %lu", index == 0 ? 'M' : 'L',
            (unsigned long)(zeroLength ? 64 : 8 + index % 100 * 5),
            (unsigned long)(zeroLength ? 64 : 8 + index / 100 * 10)];
    }
    NSString* format = @"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><defs>"
        "<marker id='m' markerUnits='userSpaceOnUse' overflow='visible' orient='auto'>"
        "<circle r='2' fill='%@'/></marker></defs><path d='%@' fill='none' stroke='blue' marker='url(#m)'/></svg>";
    NSString* fill = contextPaint ? @"context-stroke" : @"red";
    return [NSString stringWithFormat:format, fill, path];
}

int main(int argc, const char** argv)
{
    @autoreleasepool {
        if(argc != 2) return 2;
        NSString* marker3 = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
        if(marker3 == nil) return 3;
        NSArray<NSString*>* names = @[@"marker3", @"solid1000", @"context1000", @"solid4000", @"zero4000"];
        NSArray<NSString*>* documents = @[marker3, DenseDocument(1000, NO, NO),
            DenseDocument(1000, YES, NO), DenseDocument(4000, NO, NO), DenseDocument(4000, NO, YES)];
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef context = CGBitmapContextCreate(NULL, 512, 512, 8, 2048, space,
            (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(space);
        if(context == NULL) return 4;
        CGContextTranslateCTM(context, 0, 512);
        CGContextScaleCTM(context, 1, -1);
        CGRect viewport = CGRectMake(0, 0, 512, 512);
        printf("case,parse_ms,cold_draw_ms,warm_draw_ms,export_ms,pixel_hash\n");
        for(NSUInteger index = 0; index < names.count; index++) {
            NSString* document = documents[index];
            double parse = MedianTime(5, ^{
                IJSVG* parsed = [[IJSVG alloc] initWithSVGString:document];
                if(parsed == nil) abort();
            });
            IJSVG* svg = [[IJSVG alloc] initWithSVGString:document];
            double cold = MedianTime(3, ^{
                [svg setNeedsDisplay];
                CGContextClearRect(context, viewport);
                [svg drawInRect:viewport context:context];
            });
            double warm = MedianTime(10, ^{
                CGContextClearRect(context, viewport);
                [svg drawInRect:viewport context:context];
            });
            double export = MedianTime(1, ^{
                NSString* output = [svg SVGStringWithSize:viewport.size options:IJSVGExporterOptionNone];
                if(output.length == 0) abort();
            });
            CGContextClearRect(context, viewport);
            [svg drawInRect:viewport context:context];
            const unsigned char* pixels = CGBitmapContextGetData(context);
            uint64_t hash = 14695981039346656037ULL;
            for(NSUInteger byte = 0; byte < 512 * 2048; byte++) {
                hash = (hash ^ pixels[byte]) * 1099511628211ULL;
            }
            printf("%s,%.4f,%.4f,%.4f,%.4f,%016llx\n", names[index].UTF8String,
                parse, cold, warm, export, (unsigned long long)hash);
            fflush(stdout);
        }
        CGContextRelease(context);
    }
    return 0;
}
