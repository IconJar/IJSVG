#import <Foundation/Foundation.h>
#import <IJSVG/IJSVG.h>
#import <mach/mach_time.h>

static double milliseconds(uint64_t start, uint64_t end)
{
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    return (double)(end - start) * timebase.numer / timebase.denom / 1e6;
}

static uint64_t pixelHash(CGImageRef image)
{
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    const UInt8* bytes = CFDataGetBytePtr(data);
    uint64_t hash = UINT64_C(14695981039346656037);
    for (CFIndex index = 0; index < CFDataGetLength(data); index++) {
        hash = (hash ^ bytes[index]) * UINT64_C(1099511628211);
    }
    CFRelease(data);
    return hash;
}

// Load the input before timing. Each sample constructs a fresh parser and SVG.
// the redraw phase reuses its paints. Exclude verification and teardown from
// timings, and discard five warmup samples in each process.
int main(int argc, const char* argv[])
{
    @autoreleasepool {
        if (argc != 3) {
            fprintf(stderr, "Usage: benchmark-rendering repeats file.svg\n");
            return 1;
        }
        NSUInteger repeats = strtoul(argv[1], NULL, 10);
        NSData* source = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]];
        if (repeats == 0 || source == nil) {
            return 1;
        }
        CGSize size = CGSizeMake(1024, 768);
        fprintf(stdout, "run,xml_ms,nodes_ms,parse_ms,first_render_ms,redraw_ms,pixel_hash\n");
        for (NSUInteger run = 0; run < repeats + 5; run++) {
            @autoreleasepool {
                uint64_t start = mach_continuous_time();
                IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGData:source fileURL:nil error:nil];
                uint64_t xmlEnd = mach_continuous_time();
                IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeZero];
                IJSVG* svg = [[IJSVG alloc] initWithRootNode:root];
                uint64_t parseEnd = mach_continuous_time();
                if (parser == nil || root == nil || svg == nil) {
                    return 2;
                }
                CGImageRef image = [svg newCGImageRefWithSize:size flipped:NO error:nil];
                uint64_t renderEnd = mach_continuous_time();
                if (image == NULL) {
                    return 3;
                }
                uint64_t hash = pixelHash(image);
                CGImageRelease(image);
                uint64_t redrawStart = mach_continuous_time();
                for (NSUInteger index = 0; index < 5; index++) {
                    CGImageRef redrawn = [svg newCGImageRefWithSize:size flipped:NO error:nil];
                    if (redrawn == NULL) {
                        return 3;
                    }
                    CGImageRelease(redrawn);
                }
                uint64_t redrawEnd = mach_continuous_time();
                if (run >= 5) {
                    fprintf(stdout, "%lu,%.6f,%.6f,%.6f,%.6f,%.6f,%016llx\n", (unsigned long)(run - 4), milliseconds(start, xmlEnd), milliseconds(xmlEnd, parseEnd), milliseconds(start, parseEnd), milliseconds(parseEnd, renderEnd), milliseconds(redrawStart, redrawEnd) / 5, (unsigned long long)hash);
                    fflush(stdout);
                }
            }
        }
    }
    return 0;
}
