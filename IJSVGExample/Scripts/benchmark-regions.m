//
//  benchmark regions.m
//  IJSVGExample
//
//  Created by Curtis Hard on 20/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVG.h>
#import <mach/mach_time.h>

int main(int argc, const char* argv[])
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        NSUInteger count = argc > 1 ? strtoul(argv[1], NULL, 10) : 10000;
        NSUInteger depth = argc > 2 ? strtoul(argv[2], NULL, 10) : 20;
        NSUInteger repeats = argc > 3 ? strtoul(argv[3], NULL, 10) : 10;
        BOOL filters = argc > 4 && strtoul(argv[4], NULL, 10) != 0;
        BOOL viewports = argc > 5 && strtoul(argv[5], NULL, 10) != 0;
        BOOL fresh = argc <= 6 || strtoul(argv[6], NULL, 10) != 0;
        NSMutableString* source = [NSMutableString stringWithString:@"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1000 1000'>"];
        [source appendString:@"<defs><filter id='blur'><feGaussianBlur stdDeviation='3'/><feColorMatrix type='saturate' values='.5'/></filter></defs>"];
        for (NSUInteger i = 0; i < depth; i++) {
            if (viewports) {
                [source appendFormat:@"<svg x='.1' y='.1' width='1000' height='1000' viewBox='0 0 1000 1000' %@>", filters ? @"filter='url(#blur)'" : @""];
                continue;
            }
            [source appendString:filters ? @"<g transform='translate(.1 .1)' filter='url(#blur)'>" : @"<g transform='translate(.1 .1)'>"];
        }
        for (NSUInteger i = 0; i < count; i++) {
            [source appendFormat:@"<a href='https://example.com/%lu'><rect id='r%lu' x='%lu' y='%lu' width='4' height='4' stroke='black' stroke-width='.5'/></a>", (unsigned long)i, (unsigned long)i, (unsigned long)(i % 200 * 5), (unsigned long)(i / 200 % 200 * 5)];
        }
        for (NSUInteger i = 0; i < depth; i++) {
            [source appendString:viewports ? @"</svg>" : @"</g>"];
        }
        [source appendString:@"</svg>"];
        IJSVG* svg = [[IJSVG alloc] initWithSVGString:source];
        if (svg == nil || count == 0 || repeats == 0) {
            return 1;
        }
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        puts("shapes,depth,filters,viewports,fresh,space,run,ms,regions,checksum");
        for (NSUInteger space = 0; space < 4; space++) {
            for (NSUInteger run = 0; run < repeats + 2; run++) {
                @autoreleasepool {
                    if (fresh) {
                        svg = [[IJSVG alloc] initWithSVGString:source];
                    }
                    uint64_t start = mach_continuous_time();
                    NSArray<IJSVGRegion*>* regions = space == 3 ? [svg regionsInRect:CGRectMake(0, 0, 1000, 1000)] : [svg regionsInRect:CGRectMake(0, 0, 1000, 1000) coordinateSpace:space nodeTypes:nil];
                    double ms = (mach_continuous_time() - start) * (double)timebase.numer / timebase.denom / 1e6;
                    double checksum = 0;
                    for (IJSVGRegion* region in regions) {
                        CGRect rect = region.rect;
                        checksum += rect.origin.x + rect.origin.y + rect.size.width + rect.size.height + region.instanceIndex + region.type;
                    }
                    if (run >= 2) {
                        printf("%lu,%lu,%d,%d,%d,%lu,%lu,%.3f,%lu,%.9f\n", (unsigned long)count, (unsigned long)depth, filters, viewports, fresh, (unsigned long)space, (unsigned long)(run - 2), ms, (unsigned long)regions.count, checksum);
                    }
                }
            }
        }
    }
    return 0;
}
