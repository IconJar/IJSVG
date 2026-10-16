#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGStyleSheet.h>
#import <time.h>

static double now(void)
{
    struct timespec time;
    clock_gettime(CLOCK_MONOTONIC, &time);
    return time.tv_sec + time.tv_nsec / 1e9;
}

int main(void)
{
    @autoreleasepool {
        const NSUInteger shapes = 30000, rules = 2000, samples = 9;
        NSArray<NSString*>* names = @[ @"plain", @"one-block", @"per-rule", @"nested-and-skipped" ];
        NSMutableArray<NSString*>* styles = [NSMutableArray array];
        NSMutableArray<NSString*>* documents = [NSMutableArray array];
        NSMutableString* body = [NSMutableString string];
        double expected = 0;
        for (NSUInteger index = 0; index < shapes; index++) {
            NSUInteger rule = index % rules;
            expected += rule % 7 + 1;
            [body appendFormat:@"<rect class='c%lu' x='%lu' y='%lu' width='1' height='1'/>", rule, index % 1000, index / 1000];
        }
        for (NSUInteger variant = 0; variant < names.count; variant++) {
            NSMutableString* css = [NSMutableString string];
            if (variant == 1) {
                [css appendString:@"@media screen and (min-width:600px){"];
            }
            for (NSUInteger index = 0; index < rules; index++) {
                NSString* rule = [NSString stringWithFormat:@".c%lu{stroke-width:%lu}", index, index % 7 + 1];
                if (variant == 2) {
                    [css appendFormat:@"@media screen and (min-width:600px){%@}", rule];
                } else if (variant == 3) {
                    [css appendFormat:@"@media screen{@media (min-width:600px){@media (orientation:landscape){%@}}}@media print{.c%lu{stroke-width:99}}", rule, index];
                } else {
                    [css appendString:rule];
                }
            }
            if (variant == 1) {
                [css appendString:@"}"];
            }
            [styles addObject:css];
            [documents addObject:[NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='1000' height='500'><style>%@</style>%@</svg>", css, body]];
            printf("variant=%s shapes=%lu rules=%lu css_bytes=%lu document_bytes=%lu\n", names[variant].UTF8String, shapes, rules, [css lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [documents.lastObject lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
        }
        // Rotate variant order to reduce systematic cache and thermal bias.
        // Input construction and output verification are outside timed regions.
        for (NSUInteger run = 0; run < samples + 2; run++) {
            for (NSUInteger order = 0; order < names.count; order++) {
                @autoreleasepool {
                    NSUInteger variant = (run + order) % names.count;
                    double start = now();
                    IJSVGStyleSheet* sheet = [[IJSVGStyleSheet alloc] init];
                    [sheet parseStyleBlock:styles[variant] viewport:CGSizeMake(1000, 500)];
                    double cssTime = now() - start;
                    if (sheet.ruleCount != rules) {
                        fprintf(stderr, "Unexpected active rule count\n");
                        return 1;
                    }
                    start = now();
                    NSError* error = nil;
                    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:documents[variant] fileURL:nil error:&error];
                    double parsed = now();
                    IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(1000, 500)];
                    double built = now();
                    double checksum = 0;
                    for (IJSVGGraphicsNode* node in root.children) {
                        checksum += node.strokeWidth.value;
                    }
                    if (error != nil || root.children.count != shapes || checksum != expected) {
                        fprintf(stderr, "Invalid output: nodes=%lu checksum=%.0f expected=%.0f error=%s\n", root.children.count, checksum, expected, error.description.UTF8String);
                        return 2;
                    }
                    printf("%s=%lu variant=%s css_ms=%.3f xml_ms=%.3f build_ms=%.3f total_ms=%.3f nodes=%lu checksum=%.0f\n", run < 2 ? "warmup" : "sample", run, names[variant].UTF8String, cssTime * 1000, (parsed - start) * 1000, (built - parsed) * 1000, (built - start) * 1000, root.children.count, checksum);
                    fflush(stdout);
                }
            }
        }
    }
    return 0;
}
