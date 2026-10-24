#import <IJSVG/IJSVG.h>
#import <XCTest/XCTest.h>

static NSString* const IJSVGNestedPatternScaleSource = @"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"768\" height=\"768\" viewBox=\"0 0 32 32\">\n"
                                                        "  <title>Nested pattern filter resolution reproduction</title>\n"
                                                        "  <desc>A fine pattern is blurred inside a larger pattern and then drawn through a shadow filter. The small viewBox is enlarged 24 times. The fine shapes should remain distinct.</desc>\n"
                                                        "  <defs>\n"
                                                        "    <pattern id=\"flakes\" width=\"2\" height=\"2\" patternUnits=\"userSpaceOnUse\">\n"
                                                        "      <rect width=\"2\" height=\"2\" fill=\"#a4a8ad\"/>\n"
                                                        "      <path d=\"M.1 .15 L.55 .08 L.7 .45 L.28 .65 Z\" fill=\"#c3ffff\"/>\n"
                                                        "      <path d=\"M1.15 .12 L1.65 .2 L1.82 .58 L1.4 .75 L1.08 .48 Z\" fill=\"#ffffc0\"/>\n"
                                                        "      <path d=\"M.18 1.15 L.62 1 L.8 1.4 L.42 1.8 L.08 1.55 Z\" fill=\"#ffc4f2\"/>\n"
                                                        "      <path d=\"M1.12 1.2 L1.62 1.03 L1.88 1.52 L1.45 1.85 Z\" fill=\"#fff\"/>\n"
                                                        "    </pattern>\n"
                                                        "    <filter id=\"soften\" x=\"0\" y=\"0\" width=\"32\" height=\"32\"\n"
                                                        "            filterUnits=\"userSpaceOnUse\" primitiveUnits=\"userSpaceOnUse\"\n"
                                                        "            color-interpolation-filters=\"sRGB\">\n"
                                                        "      <feGaussianBlur in=\"SourceGraphic\" stdDeviation=\".02\"/>\n"
                                                        "    </filter>\n"
                                                        "    <pattern id=\"surface\" x=\"0\" y=\"0\" width=\"32\" height=\"32\"\n"
                                                        "             patternUnits=\"userSpaceOnUse\" viewBox=\"0 0 32 32\">\n"
                                                        "      <rect width=\"32\" height=\"32\" fill=\"url(#flakes)\" filter=\"url(#soften)\"/>\n"
                                                        "    </pattern>\n"
                                                        "    <filter id=\"shadow\" x=\"0\" y=\"0\" width=\"32\" height=\"32\"\n"
                                                        "            filterUnits=\"userSpaceOnUse\" primitiveUnits=\"userSpaceOnUse\">\n"
                                                        "      <feDropShadow dx=\"0\" dy=\".35\" stdDeviation=\".3\" flood-opacity=\".3\"/>\n"
                                                        "    </filter>\n"
                                                        "  </defs>\n"
                                                        "  <rect width=\"32\" height=\"32\" fill=\"white\"/>\n"
                                                        "  <rect x=\"2\" y=\"2\" width=\"28\" height=\"28\" rx=\"2\"\n"
                                                        "        fill=\"url(#surface)\" filter=\"url(#shadow)\"/>\n"
                                                        "</svg>\n";

@interface IJSVGPatternScaleTests : XCTestCase
@end

@implementation IJSVGPatternScaleTests

- (NSData*)pixelsForSVG:(IJSVG*)svg size:(NSUInteger)size
{
    XCTAssertNotNil(svg);
    if (svg == nil) {
        return nil;
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, size, size, 8, size * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if (context == NULL) {
        return nil;
    }
    [svg drawInRect:CGRectMake(0, 0, size, size) context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:size * size * 4];
    CGContextRelease(context);
    return pixels;
}

- (void)checkNestedPatternWithTranslatedViewBox:(BOOL)translatedViewBox
{
    NSString* source = IJSVGNestedPatternScaleSource;
    if (translatedViewBox) {
        // Shift the viewBox and its contents together to preserve the image
        // while exercising the complete viewBox mapping.
        source = [source stringByReplacingOccurrencesOfString:@"patternUnits=\"userSpaceOnUse\" viewBox=\"0 0 32 32\""
                                                   withString:@"patternUnits=\"userSpaceOnUse\" viewBox=\"5 7 32 32\""];
        source = [source stringByReplacingOccurrencesOfString:@"<rect width=\"32\" height=\"32\" fill=\"url(#flakes)\" filter=\"url(#soften)\"/>"
                                                   withString:@"<g transform=\"translate(5 7)\"><rect width=\"32\" height=\"32\" fill=\"url(#flakes)\" filter=\"url(#soften)\"/></g>"];
    }

    // Compare against the equivalent interior without the outer pattern callback.
    // Ignore the perimeter where filter clipping differs.
    NSString* referenceSource = [IJSVGNestedPatternScaleSource stringByReplacingOccurrencesOfString:@"fill=\"url(#surface)\" filter=\"url(#shadow)\"/>"
                                                                                         withString:@"fill=\"url(#flakes)\" filter=\"url(#soften)\"/>"];
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:source];
    for (NSNumber* sizeValue in @[ @384, @768, @1536, @384 ]) {
        @autoreleasepool {
            NSUInteger size = sizeValue.unsignedIntegerValue;
            NSData* actual = [self pixelsForSVG:svg size:size];
            NSData* reference = [self pixelsForSVG:[[IJSVG alloc] initWithSVGString:referenceSource] size:size];
            NSData* fresh = [self pixelsForSVG:[[IJSVG alloc] initWithSVGString:source] size:size];
            if (actual == nil || reference == nil || fresh == nil) {
                return;
            }
            XCTAssertEqualObjects(actual, fresh, @"Reused renderer differs at size %@", sizeValue);
            const UInt8* actualBytes = actual.bytes;
            const UInt8* referenceBytes = reference.bytes;
            NSUInteger difference = 0;
            NSUInteger samples = 0;
            for (NSUInteger y = size / 4; y < size * 3 / 4; y++) {
                for (NSUInteger x = size / 4; x < size * 3 / 4; x++) {
                    for (NSUInteger channel = 0; channel < 3; channel++) {
                        NSUInteger index = (y * size + x) * 4 + channel;
                        difference += abs((int)actualBytes[index] - (int)referenceBytes[index]);
                        samples++;
                    }
                }
            }
            double meanDifference = (double)difference / samples;
            XCTAssertLessThan(meanDifference, 2., @"Nested pattern loses detail at size %@: %f", sizeValue, meanDifference);
        }
    }
}

- (void)testNestedPatternFiltersPreserveResolution
{
    [self checkNestedPatternWithTranslatedViewBox:NO];
}

- (void)testTranslatedViewBoxPreservesNestedPatternResolution
{
    [self checkNestedPatternWithTranslatedViewBox:YES];
}

@end
