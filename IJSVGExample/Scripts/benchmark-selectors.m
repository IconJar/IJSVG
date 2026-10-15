#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGRootNode.h>

// End-to-end XML parsing, selector matching, cascade, and render-node creation.
// Keep the generated input and checksum identical when comparing revisions.
int main(int argc, const char* argv[])
{
    @autoreleasepool {
        NSUInteger groups = argc > 1 ? strtoul(argv[1], NULL, 10) : 30;
        NSUInteger siblings = argc > 2 ? strtoul(argv[2], NULL, 10) : 1000;
        NSUInteger repeats = argc > 3 ? strtoul(argv[3], NULL, 10) : 3;
        NSMutableString* source = [NSMutableString stringWithString:@"<svg xmlns='http://www.w3.org/2000/svg' width='1000' height='1000'><style>"];
        [source appendString:@":where(rect,circle) { fill: red }"
                              "rect:nth-child(2n+1) { stroke-width: 2 }"
                              "rect:nth-last-child(3n+1) { stroke-width: 3 }"
                              "rect:nth-of-type(4n+1) { stroke-width: 4 }"
                              "rect:nth-last-of-type(5n+1) { stroke-width: 5 }"
                              ":is(rect,circle):not(.skip):nth-child(7n) { stroke-width: 7 }"
                              "g:has(> rect:first-child) > rect:last-of-type { stroke-width: 11 }"
                              "rect:empty { opacity: .8 }"
                              "</style>"];
        for (NSUInteger group = 0; group < groups; group++) {
            [source appendString:@"<g>"];
            for (NSUInteger index = 0; index < siblings; index++) {
                if (index % 5 == 4) {
                    [source appendFormat:@"<circle cx='%lu' cy='%lu' r='1'/>", index % 1000, group];
                } else {
                    [source appendFormat:@"<rect x='%lu' y='%lu' width='1' height='1'/>", index % 1000, group];
                }
            }
            [source appendString:@"</g>"];
        }
        [source appendString:@"</svg>"];
        fprintf(stdout, "elements=%lu groups=%lu siblings=%lu bytes=%lu repeats=%lu\n", groups * siblings, groups, siblings, [source lengthOfBytesUsingEncoding:NSUTF8StringEncoding], repeats);
        fflush(stdout);
        for (NSUInteger run = 0; run < repeats + 1; run++) {
            @autoreleasepool {
                CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
                NSError* error = nil;
                IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:&error];
                if (parser == nil) {
                    NSLog(@"%@", error);
                    return 1;
                }
                IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(1000, 1000)];
                double checksum = 0;
                NSUInteger count = 0;
                for (IJSVGGroup* group in root.children) {
                    for (IJSVGGraphicsNode* node in group.children) {
                        checksum += node.strokeWidth.value;
                        count++;
                    }
                }
                double elapsed = CFAbsoluteTimeGetCurrent() - start;
                fprintf(stdout, "%s=%lu seconds=%.6f nodes=%lu checksum=%.0f\n", run == 0 ? "warmup" : "sample", run, elapsed, count, checksum);
                fflush(stdout);
                if (count != groups * siblings) {
                    return 2;
                }
            }
        }
    }
    return 0;
}
