//
//  IJSVGFilterSamplerTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 30/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterContext.h>
#import <IJSVGTestHelpers.h>

// Exercise the internal sampler without exposing its implementation in the
// public API.
extern float IJSVGFilterSample(const float* pixels, NSInteger width, NSInteger height, CGFloat x, CGFloat y, NSUInteger channel, CGRect region, IJSVGFilterEdgeMode edgeMode);

@interface IJSVGFilterSamplerTests : XCTestCase
@end

@implementation IJSVGFilterSamplerTests

- (void)testVectorPixelsMatchScalarChannelsAcrossEdgesAndUnalignedBuffers
{
    for (NSNumber* widthValue in @[ @1, @2, @7, @17 ]) {
        NSInteger width = widthValue.integerValue, height = 5;
        NSMutableData* storage = [NSMutableData dataWithLength:(width * height * 4 + 1) * sizeof(float)];
        float* pixels = (float*)storage.mutableBytes + 1;
        for (NSInteger i = 0; i < width * height * 4; i++) {
            pixels[i] = ((i * 37) % 101) / 100.f;
        }
        CGRect regions[] = { CGRectMake(0, 0, width, height), CGRectMake(.25, 1.25, width - .5, 2.5), CGRectZero };
        for (NSUInteger region = 0; region < 3; region++) {
            for (NSNumber* edge in @[ @(IJSVGFilterEdgeModeNone), @(IJSVGFilterEdgeModeDuplicate), @(IJSVGFilterEdgeModeWrap) ]) {
                IJSVGFilterSampler sampler = IJSVGFilterSamplerMake(pixels, width, height, regions[region], edge.integerValue);
                double xs[] = { -1000000.25, -1, -.25, 0, .25, width - 1., width - .25, width, 1000000.25, NAN, INFINITY };
                double ys[] = { -2, -.25, 0, 1.75, 4, 4.5, 5, NAN, -INFINITY };
                for (NSUInteger x = 0; x < sizeof(xs) / sizeof(xs[0]); x++) {
                    for (NSUInteger y = 0; y < sizeof(ys) / sizeof(ys[0]); y++) {
                        float output[] = { -123, 0, 0, 0, 0, -456 };
                        IJSVGFilterSamplerPixel(&sampler, xs[x], ys[y], output + 1);
                        XCTAssertEqual(output[0], -123);
                        XCTAssertEqual(output[5], -456);
                        for (NSUInteger c = 0; c < 4; c++) {
                            float expected = IJSVGFilterSamplerValue(&sampler, xs[x], ys[y], c);
                            XCTAssertEqualWithAccuracy(output[c + 1], expected, 1e-7, @"width %@ edge %@ region %lu", widthValue, edge, (unsigned long)region);
                        }
                    }
                }
            }
        }
    }
}

- (void)testWrappedSamplesPreserveInteriorAndPeriodicEdges
{
    float pixels[4 * 4 * 4];
    for (NSUInteger y = 0; y < 4; y++) {
        for (NSUInteger x = 0; x < 4; x++) {
            for (NSUInteger channel = 0; channel < 4; channel++) {
                pixels[(y * 4 + x) * 4 + channel] = y * 10 + x + channel * 100;
            }
        }
    }

    // Only the central four pixels participate. The other pixels catch
    // accidental sampling outside the primitive input region.
    CGRect region = CGRectMake(1, 1, 2, 2);
    const double cases[][3] = { { 1, 1, 11 }, { 2, 2, 22 }, { 1.25, 1.5, 16.25 }, { 2.5, 1.5, 16.5 }, { 0.5, 1.5, 16.5 }, { 3.25, 3.5, 16.25 }, { -0.75, -0.5, 16.25 }, { 1000001.25, 1000001.5, 16.25 }, { -999998.75, -999998.5, 16.25 }, { nextafter(1., 0.), 1, 11 }, { nextafter(1., 2.), 1, 11 }, { nextafter(3., 2.), 1, 11 }, { nextafter(3., 4.), 1, 11 } };
    for (NSUInteger index = 0; index < sizeof(cases) / sizeof(cases[0]); index++) {
        for (NSUInteger channel = 0; channel < 4; channel++) {
            float actual = IJSVGFilterSample(pixels, 4, 4, cases[index][0], cases[index][1], channel, region, IJSVGFilterEdgeModeWrap);
            XCTAssertEqualWithAccuracy(actual, cases[index][2] + channel * 100, 0.00001, @"case=%lu channel=%lu", (unsigned long)index, (unsigned long)channel);
        }
    }
}

- (void)testWrappedSamplesRejectNonfiniteCoordinatesAndEmptyRegions
{
    float pixels[4] = { 1, 1, 1, 1 };
    CGRect region = CGRectMake(0, 0, 1, 1);
    for (NSNumber* value in @[ @(NAN), @(INFINITY), @(-INFINITY) ]) {
        XCTAssertEqual(IJSVGFilterSample(pixels, 1, 1, value.doubleValue, 0, 0, region, IJSVGFilterEdgeModeWrap), 0);
        XCTAssertEqual(IJSVGFilterSample(pixels, 1, 1, 0, value.doubleValue, 0, region, IJSVGFilterEdgeModeWrap), 0);
    }
    XCTAssertEqual(IJSVGFilterSample(pixels, 1, 1, 0, 0, 0, CGRectZero, IJSVGFilterEdgeModeWrap), 0);
}

@end
