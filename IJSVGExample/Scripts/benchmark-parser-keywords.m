#import <Foundation/Foundation.h>
#import <IJSVGParserUtils.h>
#import <IJSVGParserTextUtils.h>
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
        NSArray* orders = @[ @"stroke fill markers", @"MARKERS FILL", @"normal", @"  FILL\tstroke  ", @"stroke stroke", @"markers" ];
        NSArray* geometry = @[ @" AUTO ", @"initial", @"INHERIT", @"unset", @"revert-layer", @"invalid" ];
        NSArray* positions = @[ @"1 2 3 4 5 6 7 8", @"10px, 20%, -2em, 3ex", @"1in 2cm 3mm", @"0,0,0,0", @"invalid 1 2", @"1e2 -3.5 .2" ];
        NSArray* features = @[ @"'kern' on, 'liga' off, 'dlig' 2", @"'kern' 1", @"'liga' 0, 'ss01' 3", @"normal", @"'kern', 'liga'", @"'kern' OFF, 'liga' ON" ];
        for (NSUInteger run = 0; run < 11; run++) {
            for (NSUInteger kind = 0; kind < 4; kind++) {
                double checksum = 0;
                double start = now();
                for (NSUInteger batch = 0; batch < 100; batch++) {
                    @autoreleasepool {
                        for (NSUInteger index = 0; index < 200; index++) {
                            NSUInteger fixture = index % 6;
                            if (kind == 0) {
                                checksum += IJSVGPaintOrderFromString(orders[fixture]);
                            } else if (kind == 1) {
                                IJSVGUnitLength* length = IJSVGGeometryLengthFromString(geometry[fixture], IJSVGNodeAttributeWidth);
                                checksum += length != nil;
                                checksum += length.inherit;
                            } else if (kind == 2) {
                                IJSVGTextAttributeValue* value = IJSVGParseTextAttribute(positions[fixture], IJSVGNodeAttributeX);
                                checksum += value.lengths.count;
                                for (IJSVGTextAttributeValue* item in value.lengths) {
                                    checksum += item.number + item.string.length + item.lengthBasis;
                                }
                            } else {
                                IJSVGTextAttributeValue* value = IJSVGParseTextAttribute(features[fixture], IJSVGNodeAttributeFontFeatureSettings);
                                checksum += value.features.count;
                                for (NSNumber* setting in value.features.allValues) {
                                    checksum += setting.doubleValue;
                                }
                            }
                        }
                    }
                }
                printf("%s=%lu kind=%lu ms=%.3f checksum=%.6f\n", run < 2 ? "warmup" : "sample", run, kind, (now() - start) * 1000, checksum);
                fflush(stdout);
            }
        }
    }
}
