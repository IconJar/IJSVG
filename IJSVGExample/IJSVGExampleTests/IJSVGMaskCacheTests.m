//
//  IJSVGMaskCacheTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 03/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <XCTest/XCTest.h>
#import <IJSVGPaint.h>
#import <IJSVGRootPaint.h>
#import <IJSVGQuartzRenderer.h>
#import <mach/mach_time.h>

// Private measurement entry point used only by the local benchmark subclass.
@interface IJSVGQuartzRenderer (MaskBenchmark)
- (CGRect)filterCoverageBoundsForPaint:(IJSVGPaint*)paint;
@end

// During rootPaintForRootNode: the new mask-coverage calculation is the only
// caller of this entry point. Skipping it reproduces the old geometry coverage.
// This is an approximation of the old implementation: the new property/branch
// and allocation clipping remain, so this is not two separately built binaries.
// No global swizzling or production switches are involved.
@interface IJSVGLegacyMaskBenchmarkRenderer : IJSVGQuartzRenderer
@end

@implementation IJSVGLegacyMaskBenchmarkRenderer
- (CGRect)filterCoverageBoundsForPaint:(IJSVGPaint*)paint
{
    return CGRectNull;
}
@end

static double IJSVGMaskBenchmarkSeconds(void)
{
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    return (double)mach_absolute_time() * info.numer / info.denom / 1.e9;
}

static double IJSVGMaskBenchmarkMedian(NSArray<NSNumber*>* values)
{
    return [values sortedArrayUsingSelector:@selector(compare:)][values.count / 2].doubleValue;
}

@interface IJSVGMaskCacheTests: XCTestCase
@end

@implementation IJSVGMaskCacheTests

- (NSString*)document
{
    return @"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'><defs>"
            "<linearGradient id='fade'><stop stop-color='white'/><stop offset='1' stop-color='black'/>"
            "</linearGradient><mask id='m' maskUnits='userSpaceOnUse' x='0' y='0' width='32' height='32'>"
            "<circle cx='16' cy='16' r='13' fill='url(#fade)'/></mask></defs><rect width='32' "
            "height='32' fill='#ef4732' mask='url(#m)'/></svg>";
}

- (NSData*)render:(IJSVG*)svg
             size:(CGSize)size
            scale:(CGFloat)scale
       translated:(BOOL)translated
{
    svg.renderingBackingScaleHelper = ^CGFloat { return scale; };
    size_t width = (size_t)ceil((size.width + 8.f) * scale);
    size_t height = (size_t)ceil((size.height + 8.f) * scale);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8,
                                                 width * 4, space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) return nil;
    CGContextScaleCTM(context, scale, scale);
    CGPoint origin = translated ? CGPointMake(2.25f, 1.75f) : CGPointZero;
    [svg drawInRect:(CGRect){ origin, size }
            context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context)
                                    length:width * height * 4];
    CGContextRelease(context);
    return pixels;
}

- (void)testRedrawAtDifferentSizesAndBackingScalesMatchesFreshRendering
{
    IJSVG* reused = [[IJSVG alloc] initWithSVGString:self.document];
    XCTAssertNotNil(reused);
    const CGSize sizes[] = {
        {32, 32}, {32, 32}, {160, 160}, {160, 160},
        {47, 83}, {23, 23}, {32, 32}
    };
    const CGFloat scales[] = {1, 1, 1, 2, 2, 1, 1};
    for(NSUInteger index = 0; index < sizeof(scales) / sizeof(scales[0]); index++) {
        for(NSNumber* translated in @[@NO, @YES]) {
            IJSVG* fresh = [[IJSVG alloc] initWithSVGString:self.document];
            XCTAssertNotNil(fresh);
            NSData* actual = [self render:reused
                                     size:sizes[index]
                                    scale:scales[index]
                               translated:translated.boolValue];
            NSData* expected = [self render:fresh
                                       size:sizes[index]
                                      scale:scales[index]
                                 translated:translated.boolValue];
            XCTAssertNotNil(actual);
            XCTAssertEqualObjects(actual, expected, @"Step %lu, translated %@",
                                  index, translated);
        }
    }
}

- (void)testChangingRenderQualityMatchesFreshRendering
{
    IJSVG* reused = [[IJSVG alloc] initWithSVGString:self.document];
    NSArray<NSNumber*>* qualities = @[@(kIJSVGRenderQualityFullResolution),
        @(kIJSVGRenderQualityLow), @(kIJSVGRenderQualityOptimized),
        @(kIJSVGRenderQualityFullResolution)];
    for(NSNumber* quality in qualities) {
        IJSVGRenderingOptions* options = reused.renderingOptions;
        options.renderQuality = quality.integerValue;
        reused.renderingOptions = options;
        IJSVG* fresh = [[IJSVG alloc] initWithSVGString:self.document];
        fresh.renderingOptions = options;
        CGSize size = CGSizeMake(79, 79);
        NSData* actual = [self render:reused
                                 size:size
                                scale:2.f
                           translated:NO];
        NSData* expected = [self render:fresh
                                   size:size
                                  scale:2.f
                             translated:NO];
        XCTAssertNotNil(actual);
        XCTAssertEqualObjects(actual, expected);
    }
}

- (void)testArtworkInvalidationRebuildsMask
{
    IJSVG* reused = [[IJSVG alloc] initWithSVGString:self.document];
    XCTAssertNotNil(reused);
    CGSize size = CGSizeMake(64, 64);
    NSData* before = [self render:reused
                             size:size
                            scale:1.f
                       translated:NO];
    IJSVGPath* circle = (IJSVGPath*)reused.rootNode.children.firstObject.mask.children.firstObject;
    XCTAssertTrue([circle isKindOfClass:IJSVGPath.class]);
    XCTAssertNotNil(circle.r);
    circle.r.value = 6.f;
    [reused setNeedsDisplay];
    NSData* after = [self render:reused
                            size:size
                           scale:1.f
                      translated:NO];
    IJSVG* fresh = [[IJSVG alloc] initWithSVGString:self.document];
    IJSVGPath* freshCircle = (IJSVGPath*)fresh.rootNode.children.firstObject.mask.children.firstObject;
    freshCircle.r.value = 6.f;
    NSData* expected = [self render:fresh
                               size:size
                              scale:1.f
                         translated:NO];
    XCTAssertNotNil(before);
    XCTAssertNotNil(after);
    XCTAssertNotEqualObjects(before, after);
    XCTAssertEqualObjects(after, expected);
}


/// Builds matching masks with either generated filter coverage or explicit geometry.
- (NSString*)expandedMaskDocumentWithFilter:(BOOL)filtered
                                 reflected:(BOOL)reflected
                                   clipped:(BOOL)clipped
{
    NSString* content = filtered ?
        @"<rect x='12' y='12' width='4' height='4' filter='url(#coverage)'/>" :
        @"<rect x='4' y='6' width='24' height='20' fill='white'/>";
    NSString* transform = reflected ? @"matrix(0 -1 -1 0 32 32)" : @"matrix(1 0 0 1 0 0)";
    NSString* region = clipped ? @"x='8' y='8' width='16' height='16'" :
        @"x='0' y='0' width='32' height='32'";
    return [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'>"
         "<defs><filter id='coverage' filterUnits='userSpaceOnUse' x='4' y='6' width='24' height='20'>"
         "<feFlood flood-color='white'/></filter>"
         "<mask id='expanded' maskUnits='userSpaceOnUse' maskContentUnits='userSpaceOnUse' %@>"
         "<g transform='%@'>%@</g></mask></defs>"
         "<rect width='32' height='32' fill='#ef4732' mask='url(#expanded)'/></svg>",
        region, transform, content];
}

/// Checks filter coverage against an independent mask with the same visible geometry.
- (void)assertExpandedMaskReflected:(BOOL)reflected clipped:(BOOL)clipped
{
    IJSVG* actualSVG = [[IJSVG alloc] initWithSVGString:
        [self expandedMaskDocumentWithFilter:YES reflected:reflected clipped:clipped]];
    IJSVG* expectedSVG = [[IJSVG alloc] initWithSVGString:
        [self expandedMaskDocumentWithFilter:NO reflected:reflected clipped:clipped]];
    XCTAssertNotNil(actualSVG);
    XCTAssertNotNil(expectedSVG);
    // Revisit each scale to exercise cached mask replacement and reuse.
    for(NSNumber* scale in @[@1, @2, @1, @1]) {
        NSData* actual = [self render:actualSVG size:CGSizeMake(32, 32)
                               scale:scale.doubleValue translated:NO];
        NSData* expected = [self render:expectedSVG size:CGSizeMake(32, 32)
                                 scale:scale.doubleValue translated:NO];
        XCTAssertNotNil(actual);
        XCTAssertNotNil(expected);
        XCTAssertEqualObjects(actual, expected, @"Scale %@", scale);
        const unsigned char* pixels = expected.bytes;
        NSUInteger coveredPixels = 0;
        for(NSUInteger offset = 3; offset < expected.length; offset += 4) {
            if(pixels[offset] != 0) coveredPixels++;
        }
        XCTAssertGreaterThan(coveredPixels, 0u);
    }
}

// Reports timings instead of asserting wall-clock thresholds, which are noisy
// under the debugger/CI. Compare medians and absolute costs in the test output.
- (void)testMaskCoveragePerformanceComparison
{
    NSMutableString* strokes = [NSMutableString string];
    for(NSUInteger index = 0; index < 100; index++) {
        [strokes appendFormat:@"<path d='M 2 %lu C 6 0 20 32 30 %lu' fill='none' "
                              "stroke='white' stroke-width='.3' stroke-dasharray='.5 .3'/>",
                              index % 32, (index * 7) % 32];
    }
    NSString* (^document)(NSString*, NSString*) = ^NSString*(NSString* content, NSString* filter) {
        return [NSString stringWithFormat:
            @"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'>"
             "<defs>%@<mask id='m' maskUnits='userSpaceOnUse' x='0' y='0' width='32' height='32'>"
             "%@</mask></defs><rect width='32' height='32' fill='red' mask='url(#m)'/></svg>",
             filter, content];
    };
    NSDictionary<NSString*, NSString*>* fixtures = @{
        @"gradient": self.document,
        @"100-dashed-strokes": document(strokes, @""),
        @"expanded-filter": [self expandedMaskDocumentWithFilter:YES reflected:NO clipped:NO],
        @"clipped-reflected-filter": [self expandedMaskDocumentWithFilter:YES reflected:YES clipped:YES],
        // Unclipped coverage exceeds the 4 MB mask-cache limit even at 1x.
        // Allocation should now be bounded by the much smaller mask region.
        @"oversized-filter": document(@"<rect x='12' y='12' width='4' height='4' filter='url(#f)'/>",
            @"<filter id='f' filterUnits='userSpaceOnUse' x='-1024' y='-1024' width='2304' height='2304'>"
             "<feFlood flood-color='white'/></filter>")
    };
    NSMutableString* report = [NSMutableString stringWithString:
        @"Mask coverage benchmark: approximate legacy coverage vs fixed; median microseconds/op.\n"
         "Parsing excluded; cold includes tree construction + first draw; warm reuses the tree.\n"
         "Expanded-filter outputs intentionally differ: legacy clips required pixels.\n"];
    for(NSString* name in [[fixtures allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        IJSVG* svg = [[IJSVG alloc] initWithSVGString:fixtures[name]];
        XCTAssertNotNil(svg);
        for(NSNumber* scaleValue in @[@1, @2]) {
            CGFloat scale = scaleValue.doubleValue;
            CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            CGContextRef context = CGBitmapContextCreate(NULL, 32 * scale, 32 * scale, 8, 0,
                space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
            CGColorSpaceRelease(space);
            XCTAssertTrue(context != NULL);
            if(context == NULL) continue;
            CGContextScaleCTM(context, scale, scale);
            BOOL oversized = [name isEqualToString:@"oversized-filter"];
            NSUInteger iterations = oversized ? 3 : 30;
            for(NSString* phase in @[@"build", @"cold", @"warm"]) {
                NSMutableArray<NSNumber*>* samples[2] = {
                    [NSMutableArray array], [NSMutableArray array]
                };
                // Round zero warms the code paths; alternate order to reduce bias.
                for(NSUInteger round = 0; round < 8; round++) {
                    for(NSUInteger turn = 0; turn < 2; turn++) {
                        NSUInteger mode = (round + turn) % 2;
                        @autoreleasepool {
                            IJSVGQuartzRenderer* renderer = mode == 0 ?
                                [[IJSVGLegacyMaskBenchmarkRenderer alloc] init] :
                                [[IJSVGQuartzRenderer alloc] init];
                            renderer.style = svg.style;
                            renderer.renderingOptions = svg.renderingOptions;
                            renderer.backingScale = scale;
                            BOOL warm = [phase isEqualToString:@"warm"];
                            BOOL buildOnly = [phase isEqualToString:@"build"];
                            IJSVGRootPaint* reused = nil;
                            if(warm) {
                                reused = [renderer rootPaintForRootNode:svg.rootNode];
                                [IJSVGPaint setBackingScaleFactor:scale
                                    renderQuality:kIJSVGRenderQualityFullResolution recursivelyToPaint:reused];
                                [reused renderInContext:context];
                            }
                            double start = IJSVGMaskBenchmarkSeconds();
                            for(NSUInteger iteration = 0; iteration < iterations; iteration++) {
                                @autoreleasepool {
                                    IJSVGRootPaint* paint = warm ? reused :
                                        [renderer rootPaintForRootNode:svg.rootNode];
                                    if(!buildOnly) {
                                        if(!warm) {
                                            [IJSVGPaint setBackingScaleFactor:scale
                                                renderQuality:kIJSVGRenderQualityFullResolution
                                                recursivelyToPaint:paint];
                                        }
                                        CGContextClearRect(context, CGRectMake(0, 0, 32, 32));
                                        [paint renderInContext:context];
                                    }
                                }
                            }
                            double elapsed = (IJSVGMaskBenchmarkSeconds() - start) * 1.e6 / iterations;
                            if(round != 0) [samples[mode] addObject:@(elapsed)];
                        }
                    }
                }
                double legacy = IJSVGMaskBenchmarkMedian(samples[0]);
                double fixed = IJSVGMaskBenchmarkMedian(samples[1]);
                [report appendFormat:@"%@ %@x %@: legacy %.2f, fixed %.2f us/op (%+.1f%%)\n",
                    name, scaleValue, phase, legacy, fixed, (fixed / legacy - 1.) * 100.];
            }
            CGContextRelease(context);
        }
    }
    NSLog(@"%@", report);
    XCTAttachment* attachment = [XCTAttachment attachmentWithString:report];
    attachment.name = @"Mask coverage performance comparison";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

// Large filter regions must still produce the right pixels when allocation is
// restricted to the mask region, including reflected and fractional placement.
- (void)testOversizedFilterMaskMatchesExplicitCoverage
{
    for(NSNumber* reflected in @[@NO, @YES]) {
        for(NSNumber* clipped in @[@NO, @YES]) {
            NSString* actualDocument = [[self expandedMaskDocumentWithFilter:YES
                reflected:reflected.boolValue clipped:clipped.boolValue]
                stringByReplacingOccurrencesOfString:@"x='4' y='6' width='24' height='20'"
                withString:@"x='-1024' y='-1024' width='2304' height='2304'"];
            NSString* expectedDocument = [[self expandedMaskDocumentWithFilter:NO
                reflected:reflected.boolValue clipped:clipped.boolValue]
                stringByReplacingOccurrencesOfString:@"x='4' y='6' width='24' height='20'"
                withString:@"x='0' y='0' width='32' height='32'"];
            IJSVG* actualSVG = [[IJSVG alloc] initWithSVGString:actualDocument];
            IJSVG* expectedSVG = [[IJSVG alloc] initWithSVGString:expectedDocument];
            XCTAssertNotNil(actualSVG);
            XCTAssertNotNil(expectedSVG);
            for(NSNumber* scale in @[@1, @2, @1]) {
                for(NSNumber* translated in @[@NO, @YES]) {
                    NSData* actual = [self render:actualSVG size:CGSizeMake(32, 32)
                        scale:scale.doubleValue translated:translated.boolValue];
                    NSData* expected = [self render:expectedSVG size:CGSizeMake(32, 32)
                        scale:scale.doubleValue translated:translated.boolValue];
                    XCTAssertNotNil(actual);
                    XCTAssertNotNil(expected);
                    XCTAssertEqualObjects(actual, expected,
                        @"Reflected %@, clipped %@, scale %@, translated %@",
                        reflected, clipped, scale, translated);
                    const unsigned char* pixels = expected.bytes;
                    NSUInteger covered = 0;
                    for(NSUInteger offset = 3; offset < expected.length; offset += 4) {
                        if(pixels[offset] != 0) covered++;
                    }
                    XCTAssertGreaterThan(covered, 0u);
                }
            }
        }
    }
}

/// Preserves generated pixels beyond every edge of the mask source geometry.
- (void)testMaskIncludesFilterOutputOutsideSourceBounds
{
    [self assertExpandedMaskReflected:NO clipped:NO];
}

/// Preserves expanded coverage after reflection across a diagonal crease.
- (void)testReflectedMaskIncludesFilterOutputOutsideSourceBounds
{
    [self assertExpandedMaskReflected:YES clipped:NO];
}

/// Keeps the declared mask region authoritative when filter coverage expands.
- (void)testExpandedReflectedMaskRespectsMaskRegion
{
    [self assertExpandedMaskReflected:YES clipped:YES];
}

@end
