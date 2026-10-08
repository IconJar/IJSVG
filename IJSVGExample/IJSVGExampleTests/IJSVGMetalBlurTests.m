//
//  IJSVGMetalBlurTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterTestHelpers.h>
#import <IJSVGFilterSIMD.h>

@interface IJSVGMetalBlurTests: XCTestCase
@end

@implementation IJSVGMetalBlurTests

- (NSData*)renderDocument:(NSString*)document
                     size:(NSUInteger)size
                  flipped:(BOOL)flipped
{
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:document
                                            error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(svg);
    if(svg == nil) {
        return nil;
    }
    svg.renderingBackingScaleHelper = ^CGFloat { return 1; };
    CGContextRef bitmap = [self newBitmapWithSize:size
                                          flipped:flipped];
    if(bitmap == NULL) {
        return nil;
    }
    [svg drawInRect:CGRectMake(0, 0, size, size)
            context:bitmap];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(bitmap)
                                    length:size * size * 4];
    CGContextRelease(bitmap);
    return pixels;
}

- (NSString*)documentWithRadius:(double)radius
                     colorSpace:(NSString*)colorSpace
                 explicitRegion:(BOOL)explicitRegion
               transparentBlend:(BOOL)transparentBlend
{
    NSString* region = @"x='.175' y='.31' width='319.2' height='318.5'";
    NSString* prefix = transparentBlend
        ? @"<feFlood flood-opacity='0' result='empty'/><feBlend in='SourceGraphic' in2='empty' "
           "mode='normal'/>"
        : @"";
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='320' height='320'>"
                                       "<defs><filter id='f' filterUnits='userSpaceOnUse' %@ "
                                       "color-interpolation-filters='%@'>%@<feGaussianBlur "
                                       "stdDeviation='%.9g' %@/></filter></defs><g filter='url(#f)' "
                                       "opacity='.8'><rect width='175' height='315' fill='#e03080' "
                                       "opacity='.37'/><circle cx='190' cy='167' r='147' fill='#2090d0' "
                                       "opacity='.63'/><rect x='121.3' y='2.4' width='190' height='58.7' "
                                       "fill='#20f040'/></g></svg>",
                                      region,
                                      colorSpace,
                                      prefix,
                                      radius,
                                      explicitRegion ? region : @""];
}

- (void)testWideCPUBoxBlurPreservesGaussianProfile
{
    for(NSNumber* sizeValue in @[@32, @64]) {
        NSUInteger size = sizeValue.unsignedIntegerValue;
        for(NSNumber* radius in @[@9, @12]) {
            for(NSString* space in @[@"sRGB", @"linearRGB"]) {
                for(NSNumber* flipped in @[@NO, @YES]) {
                    NSMutableArray<NSData*>* results = [NSMutableArray array];
                    for(NSNumber* reference in @[@NO, @YES]) {
                        NSString* bounds = @"x='0' y='0' width='64' height='64'";
                        NSString* document = [NSString stringWithFormat:@"<svg "
                                                                         "xmlns='http://www.w3.org/2000/"
                                                                         "svg' width='64' height='64'>"
                                                                         "<defs><filter id='f' "
                                                                         "filterUnits='userSpaceOnUse' "
                                                                         "%@ "
                                                                         "color-interpolation-filters='%"
                                                                         "@'><feGaussianBlur "
                                                                         "stdDeviation='%@' %@/></filter>"
                                                                         "</defs><g filter='url(#f)'>"
                                                                         "<rect width='36' height='64' "
                                                                         "fill='#e03080' opacity='.37'/>"
                                                                         "<circle cx='39' cy='33' r='29' "
                                                                         "fill='#2090d0' opacity='.63'/>"
                                                                         "</g></svg>",
                                                                        bounds,
                                                                        space,
                                                                        @(radius.doubleValue * 64 / size),
                                                                        reference.boolValue ? bounds : @""];
                        [results addObject:[self renderDocument:document
                                                           size:size
                                                        flipped:flipped.boolValue]];
                    }
                    // Wide box filters approximate the Gaussian profile. Bound both
                    // worst-pixel error and total error, including edges of the crop.
                    XCTAssertLessThanOrEqual([self maximumDifference:results[0]
                                                               other:results[1]],
                                             8);
                    const uint8_t* a = results[0].bytes;
                    const uint8_t* b = results[1].bytes;
                    double total = 0;
                    for(NSUInteger i = 0; i < results[0].length; i++) {
                        total += abs(a[i] - b[i]);
                    }
                    XCTAssertLessThanOrEqual(total / results[0].length, 1.0);
                    XCTAssertTrue([self containsPaintedPixels:results[0]]);
                }
            }
        }
    }
}

- (void)testMatchesCoreImage
{
    for(NSNumber* radius in @[@0.2, @0.5, @1.3, @2.67857143, @4.0, @4.1, @6.0, @8.0, @12.0]) {
        for(NSString* space in @[@"sRGB", @"linearRGB"]) {
            for(NSNumber* flipped in @[@NO, @YES]) {
                NSString* name = [NSString stringWithFormat:@"radius=%@ space=%@ flipped=%@",
                                                            radius,
                                                            space,
                                                            flipped];
                [XCTContext runActivityNamed:name
                                       block:^(id<XCTActivity> activity) {
                    NSData* actual = [self renderDocument:[self documentWithRadius:radius.doubleValue
                                                                        colorSpace:space
                                                                    explicitRegion:NO
                                                                  transparentBlend:NO]
                                                     size:320
                                                  flipped:flipped.boolValue];
                    NSData* expected = [self renderDocument:[self documentWithRadius:radius.doubleValue
                                                                          colorSpace:space
                                                                      explicitRegion:YES
                                                                    transparentBlend:NO]
                                                       size:320
                                                    flipped:flipped.boolValue];
                    XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                               other:expected],
                                             2);
                    XCTAssertTrue([self containsPaintedPixels:actual]);
                }];
            }
        }
    }
}

- (void)testTransparentBlendAndConcurrentRenders
{
    NSData* reference = [self renderDocument:[self documentWithRadius:2
                                                           colorSpace:@"sRGB"
                                                       explicitRegion:YES
                                                     transparentBlend:YES]
                                        size:320
                                     flipped:NO];
    [self runWorkers:12
        freshThreads:NO
               block:^(NSUInteger index) {
        NSData* pixels = [self renderDocument:[self documentWithRadius:2
                                                            colorSpace:@"sRGB"
                                                        explicitRegion:NO
                                                      transparentBlend:YES]
                                         size:320
                                      flipped:NO];
        XCTAssertLessThanOrEqual([self maximumDifference:pixels
                                                   other:reference],
                                 2);
    }];
}

- (NSString*)batchDocumentWithColorSpace:(NSString*)colorSpace
                          explicitRegion:(BOOL)explicitRegion
{
    NSMutableString* definitions = [[NSMutableString alloc] init];
    NSMutableString* artwork = [[NSMutableString alloc] init];
    const double radii[] = {0.2, 0.5, 1.3, 2.0, 2.67857143, 4.0};
    for(NSUInteger index = 0; index < 6; index++) {
        NSUInteger width = 39 + index * 7, height = 61 - index * 5;
        NSString* region = [NSString stringWithFormat:@"x='.175' y='.31' width='%lu.2' height='%lu.5'",
                                                      (unsigned long)width,
                                                      (unsigned long)height];
        [definitions appendFormat:@"<filter id='f%lu' filterUnits='userSpaceOnUse' %@ "
                                   "color-interpolation-filters='%@'><feGaussianBlur stdDeviation='%.9g' "
                                   "%@/></filter>",
                                  (unsigned long)index,
                                  region,
                                  colorSpace,
                                  radii[index],
                                  explicitRegion ? region : @""];
        [artwork appendFormat:@"<g transform='translate(%lu,%lu)' opacity='.73'><g filter='url(#f%lu)'>"
                               "<rect width='%lu' height='%lu' fill='#f02080' opacity='.4'/><circle "
                               "cx='29' cy='21' r='27' fill='#30c0e0' opacity='.7'/></g></g>",
                              (unsigned long)(index * 37),
                              (unsigned long)(index * 29),
                              (unsigned long)index,
                              (unsigned long)width,
                              (unsigned long)height];
    }
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='320' height='320'>"
                                       "<defs>%@</defs>%@</svg>",
                                      definitions,
                                      artwork];
}

- (void)testBatchedSmallBlursMatchCoreImage
{
    for(NSString* space in @[@"sRGB", @"linearRGB"]) {
        for(NSNumber* flipped in @[@NO, @YES]) {
            NSString* name = [NSString stringWithFormat:@"space=%@ flipped=%@",
                                                        space,
                                                        flipped];
            [XCTContext runActivityNamed:name
                                   block:^(id<XCTActivity> activity) {
                NSData* actual = [self renderDocument:[self batchDocumentWithColorSpace:space
                                                                         explicitRegion:NO]
                                                 size:320
                                              flipped:flipped.boolValue];
                NSData* expected = [self renderDocument:[self batchDocumentWithColorSpace:space
                                                                           explicitRegion:YES]
                                                   size:320
                                                flipped:flipped.boolValue];
                XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                           other:expected],
                                         2);
                XCTAssertTrue([self containsPaintedPixels:actual]);
            }];
        }
    }
}

- (void)testConcurrentBatchesKeepIndependentPixels
{
    NSData* expected = [self renderDocument:[self batchDocumentWithColorSpace:@"linearRGB"
                                                               explicitRegion:YES]
                                       size:320
                                    flipped:NO];
    [self runWorkers:12
        freshThreads:NO
               block:^(NSUInteger index) {
        NSData* actual = [self renderDocument:[self batchDocumentWithColorSpace:@"linearRGB"
                                                                 explicitRegion:NO]
                                         size:320
                                      flipped:NO];
        XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                   other:expected],
                                 2);
    }];
}

- (NSString*)largeBatchDocumentWithCount:(NSUInteger)count
                                   width:(NSUInteger)width
                                  serial:(BOOL)serial
                                  ciOnly:(BOOL)ciOnly
{
    NSMutableString* definitions = [NSMutableString stringWithString:@"<clipPath id='canvas'><rect "
                                                                      "width='900' height='900'/>"
                                                                      "</clipPath>"];
    NSMutableString* artwork = [[NSMutableString alloc] init];
    for(NSUInteger index = 0; index < count; index++) {
        NSUInteger radius = ciOnly || index % 2 == 0 ? 13 : 2;
        [definitions appendFormat:@"<filter id='large%lu' filterUnits='userSpaceOnUse' x='.175' y='.31' "
                                   "width='%lu.2' height='400.5' color-interpolation-filters='linearRGB'>"
                                   "<feGaussianBlur stdDeviation='%lu'/></filter>",
                                  (unsigned long)index,
                                  (unsigned long)width,
                                  (unsigned long)radius];
        [artwork appendFormat:@"<g transform='translate(%lu,%lu)' opacity='.63'><g "
                               "filter='url(#large%lu)'><rect width='%lu' height='400' fill='#e05020' "
                               "opacity='.27'/><circle cx='300' cy='230' r='147' fill='#2090f0' "
                               "opacity='.51'/></g></g>",
                              (unsigned long)(index * 11),
                              (unsigned long)(index * 17),
                              (unsigned long)index,
                              (unsigned long)width];
    }
    // A canvas sized clip selects the independent renderer without changing pixels.
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='900' height='900'>"
                                       "<defs>%@</defs><g %@>%@</g></svg>",
                                      definitions,
                                      serial ? @"clip-path='url(#canvas)'" : @"",
                                      artwork];
}

- (void)testLargeChunksAndBudgetFallbackMatchIndependentRendering
{
    // Six jobs exceed one chunk; twenty exercise the larger replay budget;
    // forty exceed it and must fall back before drawing sources.
    for(NSNumber* count in @[@6, @20, @40]) {
        for(NSNumber* flipped in @[@NO, @YES]) {
            NSString* name = [NSString stringWithFormat:@"count=%@ flipped=%@",
                                                        count,
                                                        flipped];
            [XCTContext runActivityNamed:name
                                   block:^(id<XCTActivity> activity) {
                NSData* actual = [self renderDocument:[self largeBatchDocumentWithCount:count.unsignedIntegerValue
                                                                                  width:600
                                                                                 serial:NO
                                                                                 ciOnly:NO]
                                                 size:900
                                              flipped:flipped.boolValue];
                NSData* expected = [self renderDocument:[self largeBatchDocumentWithCount:count.unsignedIntegerValue
                                                                                    width:600
                                                                                   serial:YES
                                                                                   ciOnly:NO]
                                                   size:900
                                                flipped:flipped.boolValue];
                XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                           other:expected],
                                         2);
            }];
        }
    }
}

- (void)testAtlasPaddingSplitsWithoutChangingPixels
{
    // The source pixels fit in one chunk but the packed atlas exceeds one megapixel.
    NSData* actual = [self renderDocument:[self largeBatchDocumentWithCount:3
                                                                      width:800
                                                                     serial:NO
                                                                     ciOnly:YES]
                                     size:900
                                  flipped:NO];
    NSData* expected = [self renderDocument:[self largeBatchDocumentWithCount:3
                                                                        width:800
                                                                       serial:YES
                                                                       ciOnly:YES]
                                       size:900
                                    flipped:NO];
    XCTAssertLessThanOrEqual([self maximumDifference:actual
                                               other:expected], 2);
}

- (void)testUnsupportedRadiiKeepCoreImageOutput
{
    for(NSNumber* radius in @[@0.0, @0.1, @12.1, @24.0]) {
        [XCTContext runActivityNamed:[NSString stringWithFormat:@"radius=%@",
                                                                radius]
                               block:^(id<XCTActivity> activity) {
            NSData* actual = [self renderDocument:[self documentWithRadius:radius.doubleValue
                                                                colorSpace:@"linearRGB"
                                                            explicitRegion:NO
                                                          transparentBlend:NO]
                                             size:320
                                          flipped:NO];
            NSData* expected = [self renderDocument:[self documentWithRadius:radius.doubleValue
                                                                  colorSpace:@"linearRGB"
                                                              explicitRegion:YES
                                                            transparentBlend:NO]
                                               size:320
                                            flipped:NO];
            XCTAssertNotNil(actual);
            XCTAssertNotNil(expected);
            XCTAssertEqualObjects(actual, expected);
        }];
    }
}

- (void)testFusedBoxBlurMatchesFloatReferenceWithFullHalo
{
    for(NSArray<NSNumber*>* dimensions in @[@[@1, @1], @[@7, @5], @[@32, @23]]) {
        NSUInteger width = dimensions[0].unsignedIntegerValue;
        NSUInteger height = dimensions[1].unsignedIntegerValue;
        for(NSArray<NSNumber*>* kernels in @[@[@1, @1, @1], @[@3, @5, @3], @[@19, @21, @19]]) {
            NSUInteger sides[3] = {kernels[0].unsignedIntegerValue,
                kernels[1].unsignedIntegerValue, kernels[2].unsignedIntegerValue};
            NSUInteger padding = sides[0] / 2 + sides[1] / 2 + sides[2] / 2;
            NSUInteger paddedWidth = width + 2 * padding;
            NSUInteger paddedHeight = height + 2 * padding;
            for(NSUInteger pattern = 0; pattern < 2; pattern++) {
                NSMutableData* source = [NSMutableData dataWithLength:width * height * 4 * sizeof(float)];
                NSMutableData* actual = [NSMutableData dataWithLength:source.length];
                float* samples = source.mutableBytes;
                for(NSUInteger i = 0; i < width * height * 4; i++) {
                    samples[i] = pattern == 0 ? (i < 4 ? 1.f : 0.f) : (i * 71 % 256) / 255.f;
                }
                NSMutableData* first = [NSMutableData dataWithLength:paddedWidth * paddedHeight * 4 * sizeof(float)];
                NSMutableData* second = [NSMutableData dataWithLength:first.length];
                for(NSUInteger y = 0; y < height; y++) {
                    memcpy((float*)first.mutableBytes + ((y + padding) * paddedWidth + padding) * 4,
                           samples + y * width * 4, width * 4 * sizeof(float));
                }
                // An intentionally simple reference retains the entire halo and
                // computes each box independently, without running sums.
                for(NSUInteger stage = 0; stage < 3; stage++) {
                    NSInteger radius = sides[stage] / 2;
                    for(NSUInteger axis = 0; axis < 2; axis++) {
                        const float* input = first.bytes;
                        float* output = second.mutableBytes;
                        for(NSUInteger y = 0; y < paddedHeight; y++) {
                            for(NSUInteger x = 0; x < paddedWidth; x++) {
                                for(NSUInteger channel = 0; channel < 4; channel++) {
                                    double sum = 0;
                                    for(NSInteger offset = -radius; offset <= radius; offset++) {
                                        NSInteger sx = (NSInteger)x + (axis == 0 ? offset : 0);
                                        NSInteger sy = (NSInteger)y + (axis == 1 ? offset : 0);
                                        if(sx >= 0 && sx < (NSInteger)paddedWidth &&
                                            sy >= 0 && sy < (NSInteger)paddedHeight) {
                                            sum += input[(sy * paddedWidth + sx) * 4 + channel];
                                        }
                                    }
                                    output[(y * paddedWidth + x) * 4 + channel] = sum / sides[stage];
                                }
                            }
                        }
                        NSMutableData* swap = first;
                        first = second;
                        second = swap;
                    }
                }
                XCTAssertTrue(IJSVGFilterSIMDThreeBoxBlur(source.bytes,
                                                          actual.mutableBytes,
                                                          width, height, sides));
                const float* expected = first.bytes;
                const float* result = actual.bytes;
                float maximumError = 0;
                for(NSUInteger y = 0; y < height; y++) {
                    for(NSUInteger x = 0; x < width * 4; x++) {
                        float reference = expected[((y + padding) * paddedWidth + padding) * 4 + x];
                        maximumError = fmaxf(maximumError,
                                             fabsf(result[y * width * 4 + x] - reference));
                    }
                }
                XCTAssertLessThanOrEqual(maximumError, 0.00002f,
                                         @"%@ %@ pattern %lu", dimensions,
                                         kernels, (unsigned long)pattern);
            }
        }
    }
}

- (void)testFusedBoxBlurRejectsInvalidInputs
{
    float source[4] = {0};
    float output[4] = {0};
    NSUInteger even[3] = {3, 2, 3};
    NSUInteger valid[3] = {3, 3, 3};
    XCTAssertFalse(IJSVGFilterSIMDThreeBoxBlur(source, output, 1, 1, even));
    XCTAssertFalse(IJSVGFilterSIMDThreeBoxBlur(source, source, 1, 1, valid));
    XCTAssertFalse(IJSVGFilterSIMDThreeBoxBlur(NULL, output, 1, 1, valid));
    XCTAssertFalse(IJSVGFilterSIMDThreeBoxBlur(source, output, 0, 1, valid));
}

@end
