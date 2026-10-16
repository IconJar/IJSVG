#import <Foundation/Foundation.h>
#import <IJSVGParserUtils.h>
#import <IJSVGParserTextUtils.h>
#import <time.h>
#import <IJSVGStyleSheetUtils.h>
#import <IJSVG/IJSVGImage.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGViewBox.h>

@interface IJSVGBenchmarkImage : IJSVGImage
@property (nonatomic) NSUInteger URLLength;
@end
@implementation IJSVGBenchmarkImage
- (void)loadFromURL:(NSURL*)url
{
    self.URLLength = url.absoluteString.length;
}
@end

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
        NSArray* angles = @[ @"90deg", @" 1.5rad ", @"100grad", @"-45", @"invalid", @"1,2" ];
        NSArray* colors = @[ @"red", @" LIGHTBLUE ", @"rebeccapurple", @"black", @"yellowgreen", @"unknown" ];
        NSArray* ligatures = @[ @"normal", @"no-common-ligatures contextual", @"NO-COMMON-LIGATURES", @"none", @"common-ligatures", @"invalid" ];
        NSArray* decorations = @[ @"underline overline line-through", @"UNDERLINE", @"none", @"overline underline", @"line-through", @"invalid" ];
        NSArray* aspects = @[ @"xMidYMid meet", @"xMaxYMin slice", @"none", @"xMinYMax", @"xMidYMax slice", @"invalid meet" ];
        NSArray* vectors = @[ @"non-scaling-stroke", @" NON-SCALING-STROKE ", @"inherit", @"none", @"INITIAL", @"invalid" ];
        NSArray* blends = @[ @"multiply", @"COLOR-DODGE", @"normal", @"luminosity", @"screen", @"invalid" ];
        NSArray* classes = @[ @"one two three", @"one one", @"café icon", @" a  b\t c ", @"single", @"" ];
        NSArray* hexColors = @[ @"#abc", @" #123456 ", @"#12345678", @"#abcd", @"red", @"rgb(10 20 30)" ];
        NSArray* origins = @[ @"center", @"10px 20%", @"top right", @"left 2em", @"10px 20px 0", @"left right" ];
        NSArray* properties = @[ @"fill", @"STROKE", @"stroke-width", @"TRANSFORM-BOX", @"--Custom", @"unknown" ];
        NSArray* propertyValues = @[ @"red", @"blue", @"2px", @"fill-box", @"value", @"value" ];
        NSMutableString* imageURL = [@"data:image/png;base64," mutableCopy];
        for (NSUInteger index = 0; index < 4096; index++) {
            [imageURL appendString:@"AAAA AAAA\n"];
        }
        IJSVGBenchmarkImage* imageNode = [[IJSVGBenchmarkImage alloc] init];
        for (NSUInteger run = 0; run < 11; run++) {
            for (NSUInteger kind = 0; kind < 16; kind++) {
                double checksum = 0;
                double start = now();
                for (NSUInteger batch = 0; batch < (kind == 15 ? 1 : 100); batch++) {
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
                            } else if (kind == 3) {
                                IJSVGTextAttributeValue* value = IJSVGParseTextAttribute(features[fixture], IJSVGNodeAttributeFontFeatureSettings);
                                checksum += value.features.count;
                                for (NSNumber* setting in value.features.allValues) {
                                    checksum += setting.doubleValue;
                                }
                            } else if (kind == 4) {
                                checksum += IJSVGAngleFromString(angles[fixture]);
                            } else if (kind == 5) {
                                CGColorRef color = [IJSVGColor newCGColorFromString:colors[fixture]];
                                if (color != NULL) {
                                    const CGFloat* channels = CGColorGetComponents(color);
                                    checksum += channels[0] + channels[1] + channels[2] + channels[3];
                                    CGColorRelease(color);
                                }
                            } else if (kind == 6 || kind == 7) {
                                IJSVGTextAttributeValue* value = IJSVGParseTextAttribute(kind == 6 ? ligatures[fixture] : decorations[fixture], kind == 6 ? IJSVGNodeAttributeFontVariantLigatures : IJSVGNodeAttributeTextDecoration);
                                checksum += value.keyword + value.decorations;
                            } else if (kind == 8) {
                                IJSVGViewBoxMeetOrSlice mode;
                                checksum += IJSVGViewBoxParseAspectRatio(aspects[fixture], &mode);
                                checksum += mode;
                            } else if (kind == 9) {
                                checksum += IJSVGVectorEffectFromString(vectors[fixture]);
                            } else if (kind == 10) {
                                checksum += IJSVGBlendModeFromString(blends[fixture]);
                            } else if (kind == 11) {
                                checksum += IJSVGClassNameList(classes[fixture]).count;
                            } else if (kind == 12) {
                                CGColorRef color = [IJSVGColor colorFromString:hexColors[fixture]];
                                if (color != NULL) {
                                    const CGFloat* channels = CGColorGetComponents(color);
                                    checksum += channels[0] + channels[1] + channels[2] + channels[3];
                                }
                            } else if (kind == 13) {
                                NSDictionary* expanded = nil;
                                checksum += IJSVGStyleSheetResolveDeclaration(@"transform-origin", origins[fixture], &expanded) != nil;
                            } else if (kind == 14) {
                                NSDictionary* expanded = nil;
                                NSString* name = IJSVGStyleSheetResolveDeclaration(properties[fixture], propertyValues[fixture], &expanded);
                                checksum += name.length;
                            } else {
                                [imageNode loadFromString:imageURL];
                                checksum += imageNode.URLLength;
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
