//
//  benchmark-exporter.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGExporter.h>
#import <mach/mach_time.h>

@import libxml2;

static double IJSVGBenchmarkSeconds(uint64_t start, uint64_t end)
{
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    return (double)(end - start) * timebase.numer / timebase.denom / 1e9;
}

// Parse once, then time fresh exporters independently of input parsing. Each
// sample includes its autorelease pool and exporter destruction. The second
// phase reuses the generated tree to isolate serialization and its allocations.
int main(int argc, const char* argv[])
{
    @autoreleasepool {
        if (argc < 3) {
            fprintf(stderr, "Usage: benchmark-exporter repeats file.svg [file.svg ...]\n");
            return 1;
        }
        NSUInteger repeats = strtoul(argv[1], NULL, 10);
        if (repeats == 0) {
            return 1;
        }
        fprintf(stdout, "fixture,input_bytes,options,phase,run,milliseconds,output_bytes\n");
        for (int file = 2; file < argc; file++) {
            @autoreleasepool {
                NSString* path = [NSString stringWithUTF8String:argv[file]];
                NSError* error = nil;
                NSData* source = [NSData dataWithContentsOfFile:path options:0 error:&error];
                NSString* string = [[NSString alloc] initWithData:source encoding:NSUTF8StringEncoding];
                IJSVG* svg = [[IJSVG alloc] initWithSVGString:string error:&error];
                if (svg == nil) {
                    NSLog(@"Unable to load %@: %@", path, error);
                    return 2;
                }
                for (NSUInteger mode = 0; mode < 2; mode++) {
                    IJSVGExporterOptions options = mode == 0 ? IJSVGExporterOptionCompressOutput | IJSVGExporterOptionRemoveComments | IJSVGExporterOptionRemoveXMLDeclaration : IJSVGExporterOptionAll;
                    IJSVGExporter* cached = [[IJSVGExporter alloc] initWithSVG:svg size:CGSizeZero options:options];
                    NSData* reference = cached.SVGData;
                    xmlDocPtr checked = xmlReadMemory(reference.bytes, (int)reference.length, NULL, NULL, XML_PARSE_NONET);
                    if (checked == NULL) {
                        fprintf(stderr, "Invalid export for %s\n", argv[file]);
                        return 3;
                    }
                    xmlFreeDoc(checked);
                    for (NSUInteger phase = 0; phase < 2; phase++) {
                        for (NSUInteger run = 0; run < repeats + 2; run++) {
                            NSUInteger bytes = 0;
                            uint64_t start = mach_continuous_time();
                            @autoreleasepool {
                                IJSVGExporter* exporter = phase == 0 ? [[IJSVGExporter alloc] initWithSVG:svg size:CGSizeZero options:options] : cached;
                                bytes = exporter.SVGData.length;
                            }
                            double elapsed = IJSVGBenchmarkSeconds(start, mach_continuous_time());
                            if (bytes != reference.length) {
                                fprintf(stderr, "Unstable output size for %s\n", argv[file]);
                                return 4;
                            }
                            if (run >= 2) {
                                fprintf(stdout, "%s,%lu,%s,%s,%lu,%.6f,%lu\n", path.lastPathComponent.UTF8String, source.length, mode == 0 ? "compact" : "all", phase == 0 ? "fresh" : "serialize", run - 1, elapsed * 1000, bytes);
                                fflush(stdout);
                            }
                        }
                    }
                }
            }
        }
    }
    return 0;
}
