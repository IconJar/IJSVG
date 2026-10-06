//
//  IJSVGFilterTests.m
//  IJSVGExampleTests
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTestHelpers.h>
#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGFilterPrimitive.h>
#import <IJSVG/IJSVGBitFlags64.h>
#import <IJSVG/IJSVGUtils.h>

static const uint8_t* IJSVGFilterPixel(NSData* data, NSInteger x, NSInteger y,
                                       NSInteger scale)
{
    NSUInteger index = ((10 * scale - 1 - y) * 30 * scale + x) * 4;
    NSCAssert(index + 4 <= data.length, @"Pixel lies outside rendered image");
    return (const uint8_t*)data.bytes + index;
}

static BOOL IJSVGFilterPixelEquals(const uint8_t* pixel, int red, int green,
                                   int blue, int alpha)
{
    return pixel[0] == red && pixel[1] == green && pixel[2] == blue && pixel[3] == alpha;
}

static double IJSVGFilterMeanError(NSData* actual, NSData* expected)
{
    if(actual.length == 0 || actual.length != expected.length) {
        return INFINITY;
    }
    const uint8_t* a = actual.bytes;
    const uint8_t* b = expected.bytes;
    double total = 0;
    for(NSUInteger index = 0; index < actual.length; index++) {
        total += abs(a[index] - b[index]);
    }
    return total / actual.length;
}

static double IJSVGFilterMaximumError(NSData* actual, NSData* expected)
{
    if(actual.length == 0 || actual.length != expected.length) {
        return INFINITY;
    }
    const uint8_t* a = actual.bytes;
    const uint8_t* b = expected.bytes;
    int maximum = 0;
    for(NSUInteger index = 0; index < actual.length; index++) {
        maximum = MAX(maximum, abs(a[index] - b[index]));
    }
    return maximum;
}

@interface IJSVGFilterTests: XCTestCase
@end

@implementation IJSVGFilterTests

- (NSString*)document:(NSString*)body
{
    return [NSString stringWithFormat:@"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"30\" "
                                       "height=\"10\" viewBox=\"0 0 30 10\">%@</svg>",
                                      body];
}

- (IJSVGRootNode*)parse:(NSString*)body
{
    NSString* string = [NSString stringWithFormat:@"<svg xmlns=\"http://www.w3.org/2000/svg\" "
                                                   "width=\"30\" height=\"10\">%@</svg>",
                                                  body];
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:string
                                                         fileURL:nil
                                                           error:&error];
    XCTAssertNil(error);
    IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(30, 10)];
    XCTAssertNotNil(root);
    return root;
}

- (NSArray<IJSVGFilterPrimitive*>*)shadows:(NSString*)attributes
{
    IJSVGRootNode* root = [self parse:[NSString stringWithFormat:@"<defs><filter id=\"shadow\">"
                                                                  "<feDropShadow %@/></filter></defs>"
                                                                  "<circle cx=\"5\" cy=\"5\" r=\"4\" "
                                                                  "filter=\"url(#shadow)\"/>",
                                                                 attributes]];
    IJSVGFilter* filter = root.children.firstObject.filter;
    XCTAssertNotNil(filter);
    return filter.primitives;
}

- (NSString*)filtered:(NSString*)primitives
           attributes:(NSString*)attributes
              content:(NSString*)content
{
    return [self document:[NSString stringWithFormat:@"<defs><filter id=\"f\" "
                                                      "filterUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" "
                                                      "width=\"30\" height=\"10\" %@>%@</filter></defs>"
                                                      "<g filter=\"url(#f)\">%@</g>",
                                                     attributes,
                                                     primitives,
                                                     content]];
}

- (NSString*)filtered:(NSString*)primitives
              content:(NSString*)content
{
    return [self filtered:primitives
               attributes:@"color-interpolation-filters=\"sRGB\""
                  content:content];
}

- (NSString*)filtered:(NSString*)primitives
{
    return [self filtered:primitives
                  content:@"<rect x=\"2\" y=\"2\" width=\"4\" height=\"4\" fill=\"red\"/>"];
}

- (NSData*)render:(NSString*)string
            scale:(NSInteger)scale
{
    return [self render:string
                  width:30 * scale
                 height:10 * scale];
}

- (NSData*)render:(NSString*)string
            width:(NSInteger)width
           height:(NSInteger)height
{
    IJSVG* svg = IJSVGTestSVGObject(string);
    svg.renderingBackingScaleHelper = ^CGFloat { return 1; };
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8,
                                                 width * 4, space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) {
        return nil;
    }
    [svg drawInRect:CGRectMake(0, 0, width, height)
            context:context];
    NSData* bytes = [NSData dataWithBytes:CGBitmapContextGetData(context)
                                   length:width * height * 4];
    CGContextRelease(context);
    return bytes;
}

- (NSString*)export:(NSString*)original
              scale:(NSInteger)scale
{
    IJSVG* svg = IJSVGTestSVGObject(original);
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg
                                                            size:CGSizeMake(30 * scale,
                                                                            10 * scale)
                                                         options:IJSVGExporterOptionAll];
    NSString* exported = [exporter SVGString];
    XCTAssertNotNil(exported);
    return exported;
}

- (NSString*)transformElement:(NSString*)element
                        color:(NSString*)color
                   attributes:(NSString*)attributes
{
    NSDictionary<NSString*, NSString*>* formats = @{
        @"rect": @"<rect x=\"-1\" y=\"-1\" width=\"2\" height=\"2\" fill=\"%@\" %@/>",
        @"circle": @"<circle r=\"1\" fill=\"%@\" %@/>",
        @"ellipse": @"<ellipse rx=\"1\" ry=\".7\" fill=\"%@\" %@/>",
        @"polygon": @"<polygon points=\"-1,-1 1,-1 0,1\" fill=\"%@\" %@/>",
        @"line": @"<line x1=\"-1\" y1=\"0\" x2=\"1\" y2=\"0\" stroke=\"%@\" stroke-width=\"1\" %@/>",
        @"polyline": @"<polyline points=\"-1,-1 0,1 1,-1\" fill=\"none\" stroke=\"%@\" "
                      "stroke-width=\".5\" %@/>",
        @"use": @"<use href=\"#shape\" fill=\"%@\" %@/>"
    };
    NSString* format = formats[element] ?: @"<path d=\"M-1-1 H1 V1 H-1 Z\" fill=\"%@\" %@/>";
    return [NSString stringWithFormat:format,
                                      color,
                                      attributes];
}

- (void)expectTransformPixels:(NSData*)actual
                        match:(NSData*)expected
                        scale:(NSInteger)scale
{
    XCTAssertEqual(actual.length, expected.length);
    if(actual.length != expected.length) {
        return;
    }
    const uint8_t* a = actual.bytes;
    const uint8_t* b = expected.bytes;
    NSInteger width = 30 * scale;
    NSUInteger occupied = 0;
    double difference = 0, actualAlpha = 0, expectedAlpha = 0;
    double actualCenter[2] = {0}, expectedCenter[2] = {0};
    // Only occupied pixels count, so an empty canvas cannot hide misplaced geometry.
    for(NSUInteger alpha = 3; alpha < expected.length; alpha += 4) {
        if(a[alpha] == 0 && b[alpha] == 0) {
            continue;
        }
        occupied++;
        actualAlpha += a[alpha];
        expectedAlpha += b[alpha];
        NSInteger x = (alpha / 4) % width;
        NSInteger y = (alpha / 4) / width;
        actualCenter[0] += x * a[alpha];
        actualCenter[1] += y * a[alpha];
        expectedCenter[0] += x * b[alpha];
        expectedCenter[1] += y * b[alpha];
        for(int channel = 0; channel < 4; channel++) {
            difference += abs(a[alpha - channel] - b[alpha - channel]);
        }
        // Solid 5x5 reference neighborhoods must retain their interior color.
        if(b[alpha] == 255 && x >= 2 && x < width - 2 && y >= 2 && y < 10 * scale - 2) {
            BOOL solid = YES;
            for(int dy = -2; dy <= 2 && solid; dy++) {
                for(int dx = -2; dx <= 2 && solid; dx++) {
                    NSInteger neighbor = alpha + (dy * width + dx) * 4;
                    for(int channel = 0; channel < 4; channel++) {
                        solid &= b[neighbor - channel] == b[alpha - channel];
                    }
                }
            }
            if(solid) {
                for(int channel = 0; channel < 4; channel++) {
                    XCTAssertEqualWithAccuracy(a[alpha - channel],
                                               b[alpha - channel], 2);
                }
            }
        }
    }
    XCTAssertGreaterThan(occupied, 50);
    // Rasterization precedes the final transform; allow 3% mean edge error.
    XCTAssertLessThan(difference / MAX(1, occupied * 4), 255 * 0.03);
    XCTAssertGreaterThan(expectedAlpha, 0);
    XCTAssertLessThan(fabs(actualAlpha - expectedAlpha) / MAX(1, expectedAlpha),
                      0.03);
    for(int axis = 0; axis < 2; axis++) {
        XCTAssertLessThan(fabs(actualCenter[axis] / MAX(1, actualAlpha)
            - expectedCenter[axis] / MAX(1, expectedAlpha)), 0.5);
    }
}

- (void)expectTransformExport:(NSString*)original
                       pixels:(NSData*)pixels
                        scale:(NSInteger)scale
{
    NSString* exported = [self export:original
                                scale:scale];
    CXMLDocument* xml = IJSVGTestXMLDocument(exported);
    XCTAssertGreaterThan([xml nodesForXPath:@"//filter"
                                      error:nil].count, 0);
    XCTAssertEqual([xml nodesForXPath:@"//image"
                                error:nil].count, 0);
    [self expectTransformPixels:[self render:exported
                                       scale:scale]
                          match:pixels
                          scale:scale];
}

- (void)wideComponentTransferCoversEveryRow:(NSInteger)height
{
    NSInteger width = 4096;
    NSString* (^image)(BOOL) = ^NSString*(BOOL filtered) {
        return [NSString stringWithFormat:@"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%ld\" "
                                           "height=\"%ld\">    <defs><filter id=\"f\" x=\"0\" y=\"0\" "
                                           "width=\"100%%\" height=\"100%%\"                  "
                                           "color-interpolation-filters=\"sRGB\">        "
                                           "<feComponentTransfer>            <feFuncR type=\"gamma\" "
                                           "amplitude=\".4\" exponent=\"2\"/>            <feFuncG "
                                           "type=\"gamma\" amplitude=\".2\" exponent=\"3\"/>            "
                                           "<feFuncB type=\"gamma\" amplitude=\".6\" exponent=\".5\"/>   "
                                           "     </feComponentTransfer>    </filter></defs>    <rect "
                                           "width=\"100%%\" height=\"100%%\" fill=\"%@\"          %@/>"
                                           "</svg>",
                                          (long)width,
                                          (long)height,
                                          filtered ? @"white" : @"#663399",
                                          filtered ? @"filter=\"url(#f)\"" : @""];
    };
    NSData* actual = [self render:image(YES)
                            width:width
                           height:height];
    NSData* expected = [self render:image(NO)
                              width:width
                             height:height];
    XCTAssertLessThanOrEqual(IJSVGFilterMaximumError(actual, expected), 1);
}

- (void)testWideComponentTransferCoversEveryRowCase116
{
    [self wideComponentTransferCoversEveryRow:16];
}

- (void)testWideComponentTransferCoversEveryRowCase217
{
    [self wideComponentTransferCoversEveryRow:17];
}

- (void)testWideComponentTransferCoversEveryRowCase332
{
    [self wideComponentTransferCoversEveryRow:32];
}

- (void)testWideComponentTransferCoversEveryRowCase463
{
    [self wideComponentTransferCoversEveryRow:63];
}

- (void)testWideComponentTransferCoversEveryRowCase564
{
    [self wideComponentTransferCoversEveryRow:64];
}

- (void)testWideComponentTransferCoversEveryRowCase6127
{
    [self wideComponentTransferCoversEveryRow:127];
}

- (void)testWideComponentTransferCoversEveryRowCase7129
{
    [self wideComponentTransferCoversEveryRow:129];
}

- (void)testHardShadowOffsetColourAndOpacity
{
    NSData* bytes = [self render:[self document:@"<defs><filter id=\"f\" x=\"-100%\" y=\"-100%\" "
                                                 "width=\"300%\" height=\"300%\">    <feDropShadow "
                                                 "dx=\"3\" dy=\"2\" stdDeviation=\"0\" "
                                                 "flood-color=\"cyan\" flood-opacity=\".5\"/></filter>"
                                                 "</defs><rect x=\"2\" y=\"2\" width=\"3\" height=\"3\" "
                                                 "fill=\"red\" filter=\"url(#f)\"/>"]
                           scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 30, 30, 10),
                                         255, 0, 0, 255));
    const uint8_t* shadow = IJSVGFilterPixel(bytes, 65, 55, 10);
    XCTAssertTrue(shadow[0] == 0 && abs((int)(shadow[1]) - 128) <= 1);
    XCTAssertTrue(abs((int)(shadow[2]) - 128) <= 1 && abs((int)(shadow[3]) - 128) <= 1);
    XCTAssertTrue(IJSVGFilterPixel(bytes, 65, 15, 10)[3] == 0);
}

- (void)testAnisotropicBlurAndRegionClipping
{
    NSData* bytes = [self render:[self document:@"<defs><filter id=\"f\" filterUnits=\"userSpaceOnUse\" "
                                                 "x=\"0\" y=\"0\" width=\"8\" height=\"10\">    "
                                                 "<feDropShadow dx=\"0\" dy=\"0\" stdDeviation=\"1 0\" "
                                                 "flood-color=\"cyan\"/></filter></defs><rect x=\"3\" "
                                                 "y=\"3\" width=\"4\" height=\"4\" fill=\"red\" "
                                                 "filter=\"url(#f)\"/>"]
                           scale:10];
    const uint8_t* blurred = IJSVGFilterPixel(bytes, 22, 50, 10);
    XCTAssertTrue(blurred[3] > 0 && blurred[3] < 128);
    XCTAssertTrue(blurred[1] == blurred[3] && blurred[2] == blurred[3]);
    XCTAssertTrue(IJSVGFilterPixel(bytes, 50, 22, 10)[3] == 0);
    XCTAssertTrue(IJSVGFilterPixel(bytes, 85, 50, 10)[3] == 0);
}

- (void)testGroupOpacityAppliesAfterShadowAndNamedInputsWork
{
    NSData* bytes = [self render:[self document:@"<defs><filter id=\"f\" x=\"-100%\" y=\"-100%\" "
                                                 "width=\"400%\" height=\"300%\">    <feDropShadow "
                                                 "dx=\"3\" dy=\"0\" stdDeviation=\"0\" "
                                                 "flood-color=\"cyan\" result=\"first\"/>    "
                                                 "<feDropShadow in=\"first\" dx=\"3\" dy=\"0\" "
                                                 "stdDeviation=\"0\" flood-color=\"blue\"/></filter>"
                                                 "</defs><g filter=\"url(#f)\" opacity=\".5\">    <rect "
                                                 "x=\"2\" y=\"2\" width=\"3\" height=\"3\" fill=\"red\"/>"
                                                 "    <rect x=\"3\" y=\"2\" width=\"1\" height=\"3\" "
                                                 "fill=\"red\"/></g>"]
                           scale:10];
    XCTAssertTrue(abs((int)(IJSVGFilterPixel(bytes, 35, 30, 10)[3]) - 128) <= 1);
    XCTAssertTrue(abs((int)(IJSVGFilterPixel(bytes, 65, 30, 10)[1]) - 128) <= 1);
    XCTAssertTrue(abs((int)(IJSVGFilterPixel(bytes, 95, 30, 10)[2]) - 128) <= 1);
}

- (void)testObjectBoundingBoxUnitsAndPrimitiveRegion
{
    NSData* bytes = [self render:[self document:@"<defs><filter id=\"f\" x=\"-100%\" y=\"-100%\" "
                                                 "width=\"400%\" height=\"400%\" "
                                                 "primitiveUnits=\"objectBoundingBox\">    <feDropShadow "
                                                 "dx=\"1\" dy=\"1\" stdDeviation=\"0\" "
                                                 "flood-color=\"cyan\"        x=\"0\" y=\"0\" "
                                                 "width=\"1.5\" height=\"2\"/></filter></defs><rect "
                                                 "x=\"2\" y=\"2\" width=\"3\" height=\"2\" fill=\"red\" "
                                                 "filter=\"url(#f)\"/>"]
                           scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 30, 30, 10),
                                         255, 0, 0, 255));
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 55, 50, 10), 0,
                                         255, 255, 255));
    XCTAssertTrue(IJSVGFilterPixel(bytes, 70, 50, 10)[3] == 0);
}

- (void)testClipAndMaskApplyToFilteredOutput
{
    for(NSString* attribute in @[@"clip-path=\"url(#c)\"", @"mask=\"url(#m)\""]) {
        NSData* bytes = [self render:[self document:[NSString stringWithFormat:@"<defs>    <filter "
                                                                                "id=\"f\" x=\"-100%%\" "
                                                                                "y=\"-100%%\" "
                                                                                "width=\"400%%\" "
                                                                                "height=\"300%%\">       "
                                                                                " <feDropShadow dx=\"3\" "
                                                                                "dy=\"0\" "
                                                                                "stdDeviation=\"0\" "
                                                                                "flood-color=\"cyan\"/>  "
                                                                                "  </filter>    "
                                                                                "<clipPath id=\"c\">"
                                                                                "<rect x=\"0\" y=\"0\" "
                                                                                "width=\"6\" "
                                                                                "height=\"10\"/>"
                                                                                "</clipPath>    <mask "
                                                                                "id=\"m\" "
                                                                                "maskUnits=\"userSpaceOn"
                                                                                "Use\" x=\"0\" y=\"0\" "
                                                                                "width=\"30\" "
                                                                                "height=\"10\">        "
                                                                                "<rect x=\"0\" y=\"0\" "
                                                                                "width=\"6\" "
                                                                                "height=\"10\" "
                                                                                "fill=\"white\"/>    "
                                                                                "</mask></defs><rect "
                                                                                "x=\"2\" y=\"2\" "
                                                                                "width=\"3\" "
                                                                                "height=\"3\" "
                                                                                "fill=\"red\" "
                                                                                "filter=\"url(#f)\" %@/>",
                                                                               attribute]]
                               scale:10];
        XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 30, 30,
                                                              10), 255, 0, 0,
                                             255));
        XCTAssertTrue(IJSVGFilterPixel(bytes, 55, 30, 10)[3] > 240);
        XCTAssertTrue(IJSVGFilterPixel(bytes, 70, 30, 10)[3] == 0);
    }
}

- (void)testTransformedStrokeShadowSurvivesExport
{
    NSString* original = [self document:@"<defs><filter id=\"f\" x=\"-100%\" y=\"-100%\" width=\"300%\" "
                                         "height=\"300%\" primitiveUnits=\"objectBoundingBox\">    "
                                         "<feDropShadow dx=\".5\" dy=\"0\" stdDeviation=\"0\" "
                                         "flood-color=\"cyan\"/></filter></defs><g "
                                         "transform=\"translate(2 1) scale(1.5 .8)\">    <rect x=\"2\" "
                                         "y=\"2\" width=\"3\" height=\"3\" fill=\"red\" stroke=\"blue\" "
                                         "stroke-width=\"1\" filter=\"url(#f)\"/></g>"];
    IJSVG* svg = IJSVGTestSVGObject(original);
    XCTAssertNotNil(svg);
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg
                                                            size:CGSizeMake(300,
                                                                                     100)
                                                         options:IJSVGExporterOptionAll];
    XCTAssertNotNil(exporter);
    NSString* exported = [exporter SVGString];
    XCTAssertNotNil(exported);
    NSData* before = [self render:original
                            scale:10];
    NSData* after = [self render:exported
                           scale:10];
    XCTAssertLessThan(IJSVGFilterMeanError(before, after), 1);
}

- (void)testExportRetainsFilterDefinitionsAndVectorContent
{
    NSString* original = [self document:@"<defs><filter id=\"f\" x=\"-30%\" y=\"-40%\" width=\"160%\" "
                                         "height=\"180%\">    <feDropShadow in=\"SourceGraphic\" "
                                         "result=\"shadow\" dx=\".2\" dy=\".4\"        stdDeviation=\".2 "
                                         ".3\" flood-color=\"cyan\" flood-opacity=\".5\"/></filter>"
                                         "</defs><circle cx=\"5\" cy=\"5\" r=\"3\" fill=\"pink\" "
                                         "filter=\"url(#f)\"/>"];
    IJSVG* svg = IJSVGTestSVGObject(original);
    XCTAssertNotNil(svg);
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg
                                                            size:CGSizeMake(300,
                                                                                     100)
                                                         options:IJSVGExporterOptionAll];
    XCTAssertNotNil(exporter);
    NSString* exported = [exporter SVGString];
    XCTAssertNotNil(exported);
    CXMLDocument* xml = IJSVGTestXMLDocument(exported);
    XCTAssertTrue([xml nodesForXPath:@"//filter/feDropShadow"
                               error:nil].count == 1);
    XCTAssertTrue([xml nodesForXPath:@"//*[@filter]"
                               error:nil].count == 1);
    XCTAssertTrue([xml nodesForXPath:@"//image"
                               error:nil].count == 0);
    NSData* before = [self render:original
                            scale:10];
    NSData* after = [self render:exported
                           scale:10];
    XCTAssertLessThan(IJSVGFilterMeanError(before, after), 1);
}

- (void)complexFixturesRenderAndSurviveExport:(NSString*)name
{
    NSString* directory = @(__FILE__).stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
    NSString* path = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"Common Example Resources/%@.svg",
                                                                                          name]];
    NSError* error = nil;
    NSString* original = [NSString stringWithContentsOfFile:path
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error];
    XCTAssertNil(error);
    CXMLDocument* withoutFilters = IJSVGTestXMLDocument(original);
    for(CXMLElement* node in [withoutFilters nodesForXPath:@"//*[@filter]"
                                                     error:nil]) {
        [node removeAttributeForName:@"filter"];
    }
    for(NSInteger scale = 10; scale <= 20; scale += 10) {
        NSString* exported = [self export:original
                                    scale:scale];
        CXMLDocument* xml = IJSVGTestXMLDocument(exported);
        XCTAssertGreaterThan([xml nodesForXPath:@"//filter/feDropShadow"
                                          error:nil].count,
                             0);
        XCTAssertEqual([xml nodesForXPath:@"//image"
                                    error:nil].count, 0);
        for(CXMLElement* node in [xml nodesForXPath:@"//*[@filter]"
                                               error:nil]) {
            NSString* reference = [node attributeForName:@"filter"].stringValue;
            XCTAssertNotNil(reference);
            NSString* identifier = [[reference stringByReplacingOccurrencesOfString:@"url(#"
                                                                         withString:@""]
                stringByReplacingOccurrencesOfString:@")"
                                          withString:@""];
            NSString* xpath = [NSString stringWithFormat:@"//filter[@id='%@']",
                                                         identifier];
            XCTAssertEqual([xml nodesForXPath:xpath
                                        error:nil].count, 1);
        }
        NSData* before = [self render:original
                                scale:scale];
        NSData* after = [self render:exported
                               scale:scale];
        NSData* plain = [self render:withoutFilters.XMLString
                               scale:scale];
        const uint8_t* bytes = before.bytes;
        NSUInteger occupied = 0;
        for(NSUInteger index = 3; index < before.length; index += 4) {
            occupied += bytes[index] > 0;
        }
        XCTAssertGreaterThan(occupied, 1000);
        XCTAssertGreaterThan(IJSVGFilterMeanError(before, plain), 1);
        XCTAssertLessThan(IJSVGFilterMeanError(before, after), 1);
    }
}

- (void)testComplexFixturesRenderAndSurviveExportCase1DropshadowNestedTransforms
{
    [self complexFixturesRenderAndSurviveExport:@"dropshadow-nested-transforms"];
}

- (void)testComplexFixturesRenderAndSurviveExportCase2DropshadowChainsUnits
{
    [self complexFixturesRenderAndSurviveExport:@"dropshadow-chains-units"];
}

- (void)testComplexFixturesRenderAndSurviveExportCase3DropshadowClippingMasks
{
    [self complexFixturesRenderAndSurviveExport:@"dropshadow-clipping-masks"];
}

- (void)testComplexFixturesRenderAndSurviveExportCase4DropshadowDeepNesting
{
    [self complexFixturesRenderAndSurviveExport:@"dropshadow-deep-nesting"];
}

- (void)testDropShadowDefaults
{
    IJSVGFilterPrimitive* shadow = [self shadows:@""].firstObject;
    XCTAssertNotNil(shadow);
    XCTAssertTrue(shadow.type == IJSVGNodeTypeFilterDropShadow);
    XCTAssertTrue(shadow.shouldRender == NO);
    NSData* implicit = [self render:[self filtered:@"<feDropShadow/>"]
                              scale:10];
    NSData* explicit = [self render:[self filtered:@"<feDropShadow dx=\"2\" dy=\"2\" stdDeviation=\"2\" "
                                                    "flood-color=\"black\" flood-opacity=\"1\"/>"]
                              scale:10];
    XCTAssertEqualObjects(implicit, explicit);
}

- (void)testExampleShadowValues
{
    IJSVGFilterPrimitive* first = [self shadows:@"dx=\"0.2\" dy=\"0.4\" stdDeviation=\"0.2\""].firstObject;
    XCTAssertNotNil(first);
    XCTAssertEqualObjects(first.parameters[IJSVGAttributeDX], @"0.2");
    XCTAssertEqualObjects(first.parameters[IJSVGAttributeDY], @"0.4");
    XCTAssertEqualObjects(first.parameters[IJSVGAttributeStdDeviation], @"0.2");
    IJSVGFilterPrimitive* second = [self shadows:@"dx=\"0\" dy=\"0\" stdDeviation=\"0.5\" "
                                                  "flood-color=\"cyan\""].firstObject;
    XCTAssertNotNil(second);
    XCTAssertEqualObjects(second.parameters[IJSVGAttributeDX], @"0");
    XCTAssertEqualObjects(second.parameters[IJSVGAttributeDY], @"0");
    XCTAssertEqualObjects(second.parameters[IJSVGAttributeStdDeviation],
                          @"0.5");
    XCTAssertEqualObjects(second.parameters[IJSVGAttributeFloodColor], @"cyan");
    IJSVGFilterPrimitive* third = [self shadows:@"dx=\"-0.8\" dy=\"-0.8\" stdDeviation=\"0\" "
                                                 "flood-color=\"pink\" flood-opacity=\"0.5\""].firstObject;
    XCTAssertNotNil(third);
    XCTAssertEqualObjects(third.parameters[IJSVGAttributeDX], @"-0.8");
    XCTAssertEqualObjects(third.parameters[IJSVGAttributeDY], @"-0.8");
    XCTAssertEqualObjects(third.parameters[IJSVGAttributeStdDeviation], @"0");
    XCTAssertEqualObjects(third.parameters[IJSVGAttributeFloodOpacity], @"0.5");
    XCTAssertEqualObjects(third.parameters[IJSVGAttributeFloodColor], @"pink");
}

- (void)testPrimitiveOrderStylesAndCopying
{
    IJSVGRootNode* root = [self parse:@"<style>filter > feDropShadow { flood-color: cyan; flood-opacity: "
                                       ".25; }</style><defs><filter id=\"shadow\">    <feDropShadow "
                                       "in=\"SourceAlpha\" result=\"first\" stdDeviation=\"1, 2\" "
                                       "flood-color=\"pink\"/>    <feDropShadow in=\"first\" "
                                       "result=\"second\" style=\"flood-color: pink; flood-opacity: "
                                       "50%\"/></filter></defs><circle cx=\"5\" cy=\"5\" r=\"4\" "
                                       "filter=\"url(#shadow)\"/>"];
    IJSVGFilter* filter = root.children.firstObject.filter;
    XCTAssertNotNil(filter);
    XCTAssertTrue(filter.primitives.count == 2);
    IJSVGFilterPrimitive* first = filter.primitives.firstObject;
    XCTAssertNotNil(first);
    IJSVGFilterPrimitive* second = filter.primitives.lastObject;
    XCTAssertNotNil(second);
    XCTAssertEqualObjects(first.input, @"SourceAlpha");
    XCTAssertEqualObjects(first.result, @"first");
    XCTAssertEqualObjects(second.input, @"first");
    XCTAssertEqualObjects(second.result, @"second");
    XCTAssertEqualObjects(first.parameters[IJSVGAttributeStdDeviation],
                          @"1, 2");
    XCTAssertEqualObjects(first.parameters[IJSVGAttributeFloodOpacity], @".25");
    XCTAssertEqualObjects(second.parameters[IJSVGAttributeFloodOpacity],
                          @"50%");
    XCTAssertTrue(first.parentNode == filter);
    IJSVGFilter* copied = [filter copy];
    XCTAssertNotNil(copied);
    IJSVGFilterPrimitive* copiedFirst = copied.primitives.firstObject;
    XCTAssertNotNil(copiedFirst);
    XCTAssertTrue(copiedFirst != first && copiedFirst.parentNode == copied);
    XCTAssertEqualObjects(copiedFirst.input, first.input);
    XCTAssertEqualObjects(copiedFirst.result, first.result);
    XCTAssertEqualObjects(copiedFirst.parameters, first.parameters);
}

- (void)testInvalidNumbersKeepDefaultsAndOpacityIsClamped
{
    NSData* invalid = [self render:[self filtered:@"<feDropShadow dx=\"NaN\" dy=\"1px\" "
                                                   "stdDeviation=\"-1\" flood-opacity=\"2\"/>"]
                             scale:10];
    XCTAssertEqualObjects([self render:[self filtered:@"<feDropShadow/>"]
                                 scale:10],
                          invalid);
    NSData* clear = [self render:[self filtered:@"<feDropShadow stdDeviation=\"1 2 3\" "
                                                 "flood-opacity=\"-1\"/>"]
                           scale:10];
    XCTAssertEqualObjects([self render:[self filtered:@"<feOffset/>"]
                                 scale:10],
                          clear);
}

- (void)testFlagsBeyond64AndMixedStorage
{
    IJSVGBitFlags* flags = [[IJSVGBitFlags alloc] initWithLength:96];
    [flags setBit:0];
    [flags setBit:64];
    [flags setBit:95];
    IJSVGBitFlags* copied = [[IJSVGBitFlags alloc] initWithLength:96];
    [copied addBits:flags];
    XCTAssertTrue([copied bitIsSet:0] && [copied bitIsSet:64] && [copied bitIsSet:95]);
    XCTAssertFalse([copied bitIsSet:1]);
    IJSVGBitFlags64* compact = [[IJSVGBitFlags64 alloc] init];
    [compact setBit:63];
    [copied addBits:compact];
    XCTAssertTrue([copied bitIsSet:63]);
    [copied setAllBits];
    for(int bit = 0; bit < 96; bit++) {
        XCTAssertTrue([copied bitIsSet:bit], @"Bit %d", bit);
    }
}

- (void)testBranchesMergeInOrderAndUseSecondInput
{
    NSData* bytes = [self render:[self filtered:@"<feFlood flood-color=\"cyan\" result=\"paint\"/>"
                                                 "<feComposite in=\"paint\" in2=\"SourceAlpha\" "
                                                 "operator=\"in\" result=\"colored\"/><feOffset "
                                                 "in=\"colored\" dx=\"5\" result=\"moved\"/><feMerge>"
                                                 "<feMergeNode in=\"moved\"/><feMergeNode "
                                                 "in=\"SourceGraphic\"/></feMerge>"]
                           scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 35, 35, 10),
                                         255, 0, 0, 255));
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 85, 35, 10), 0,
                                         255, 255, 255));
    XCTAssertTrue(IJSVGFilterPixel(bytes, 150, 35, 10)[3] == 0);
}

- (void)testMergeOrderAndDuplicateNames
{
    NSData* bytes = [self render:[self filtered:@"<feFlood flood-color=\"blue\" result=\"a\"/><feFlood "
                                                 "flood-color=\"red\" flood-opacity=\".5\" result=\"b\"/>"
                                                 "<feMerge result=\"a\"><feMergeNode in=\"a\"/>"
                                                 "<feMergeNode in=\"b\"/></feMerge><feOffset in=\"a\"/>"]
                           scale:10];
    const uint8_t* value = IJSVGFilterPixel(bytes, 35, 35, 10);
    XCTAssertTrue(abs((int)(value[0])-128) <= 1 && abs((int)(value[2])-128) <= 1 && value[3] == 255);
}

- (void)testInvalidInputNamesUsePreviousResult
{
    NSData* bytes = [self render:[self filtered:@"<feFlood flood-color=\"cyan\"/><feOffset "
                                                 "in=\"not-yet-defined\"/>"]
                           scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 35, 35, 10), 0,
                                         255, 255, 255));
}

- (void)testFilterReferenceArrayPreservesOrder
{
    NSString* body = @"<defs>    <filter id=\"a\" x=\"-100%\" width=\"400%\"><feOffset dx=\"4\"/>"
                      "</filter>    <filter id=\"b\" x=\"-100%\" width=\"400%\"><feColorMatrix "
                      "type=\"matrix\"        values=\"0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 1 0\"/>"
                      "</filter></defs><rect x=\"2\" y=\"2\" width=\"3\" height=\"3\" fill=\"red\" "
                      "filter=\"url('#a') url(#b)\"/>";
    IJSVGRootNode* root = [self parse:body];
    XCTAssertTrue(root.children.firstObject.filters.count == 2);
    NSData* bytes = [self render:[self document:body]
                           scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 75, 35, 10), 0,
                                         255, 0, 255));
    XCTAssertTrue(IJSVGFilterPixel(bytes, 35, 35, 10)[3] == 0);
}

- (void)testColorMatrixAndTransferOperateOnStraightChannels
{
    NSData* bytes = [self render:[self filtered:@"<feColorMatrix type=\"matrix\" values=\"0 0 0 0 0 1 0 "
                                                 "0 0 0 0 0 1 0 0 0 0 0 1 0\"/><feComponentTransfer>    "
                                                 "<feFuncG type=\"linear\" slope=\".5\"/>    <feFuncA "
                                                 "type=\"linear\" slope=\".5\"/></feComponentTransfer>"]
                           scale:10];
    const uint8_t* value = IJSVGFilterPixel(bytes, 35, 35, 10);
    XCTAssertTrue(value[0] == 0 && abs((int)(value[1])-64) <= 1 && value[2] == 0);
    XCTAssertTrue(abs((int)(value[3])-128) <= 1);
}

- (void)testFilterColorSpaceChangesArithmetic
{
    NSString* primitive = @"<feComponentTransfer><feFuncR type=\"linear\" slope=\".5\"/>"
                           "</feComponentTransfer>";
    NSData* srgb = [self render:[self filtered:primitive]
                          scale:10];
    NSData* linear = [self render:[self filtered:primitive
                                      attributes:@""
                                         content:@"<rect x=\"2\" y=\"2\" width=\"4\" height=\"4\" "
                                                  "fill=\"red\"/>"]
                            scale:10];
    XCTAssertTrue(abs((int)(IJSVGFilterPixel(srgb, 35, 35, 10)[0])-128) <= 1);
    XCTAssertTrue(abs((int)(IJSVGFilterPixel(linear, 35, 35, 10)[0])-188) <= 1);
}

- (void)testPrimitiveRegionRestrictsLaterBlurAndTileRepeatsIt
{
    NSData* bytes = [self render:[self filtered:@"<feFlood flood-color=\"cyan\" x=\"2\" y=\"2\" "
                                                 "width=\"2\" height=\"2\" result=\"tile\"/><feTile "
                                                 "in=\"tile\"/>"]
                           scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 15, 15, 10), 0,
                                         255, 255, 255));
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 155, 75, 10),
                                         0, 255, 255, 255));
    NSData* clipped = [self render:[self filtered:@"<feFlood flood-color=\"cyan\" x=\"2\" y=\"2\" "
                                                   "width=\"2\" height=\"2\"/><feGaussianBlur "
                                                   "stdDeviation=\"1\"/>"]
                             scale:10];
    XCTAssertTrue(IJSVGFilterPixel(clipped, 15, 30, 10)[3] == 0);
    XCTAssertTrue(IJSVGFilterPixel(clipped, 30, 30, 10)[3] > 0);
}

- (void)testGaussianBlurPreservesColorAndZeroAxis
{
    NSData* bytes = [self render:[self filtered:@"<feGaussianBlur stdDeviation=\"1 0\"/>"]
                           scale:10];
    const uint8_t* fringe = IJSVGFilterPixel(bytes, 15, 35, 10);
    XCTAssertTrue(fringe[0] == fringe[3] && fringe[3] > 0 && fringe[3] < 128);
    XCTAssertTrue(IJSVGFilterPixel(bytes, 35, 15, 10)[3] == 0);
}

- (void)testMorphologyErodesAndDilates
{
    NSData* dilated = [self render:[self filtered:@"<feMorphology operator=\"dilate\" radius=\"1\"/>"]
                             scale:10];
    NSData* eroded = [self render:[self filtered:@"<feMorphology operator=\"erode\" radius=\"1\"/>"]
                            scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(dilated, 15, 35, 10),
                                         255, 0, 0, 255));
    XCTAssertTrue(IJSVGFilterPixel(eroded, 25, 35, 10)[3] == 0);
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(eroded, 35, 35, 10),
                                         255, 0, 0, 255));
}

- (void)testFilterExportCompressionShortensNumbersAndDefaults
{
    NSString* source = [self document:@"<defs><filter id=\"f\"><feOffset dx=\"+00.000\" dy=\"0.0\" "
                                       "result=\"offsetResult\"/><feGaussianBlur in=\"offsetResult\" "
                                       "stdDeviation=\"00.5000, 00.5000\"/><feColorMatrix values=\"1.000 "
                                       "0 0 0 0.12345678901234567 0 1 0 0 0 0 0 1 0 0 0 0 0 1 0\"/>"
                                       "</filter></defs><rect x=\"2\" y=\"2\" width=\"4\" height=\"4\" "
                                       "fill=\"red\" filter=\"url(#f)\"/>"];
    IJSVG* svg = IJSVGTestSVGObject(source);
    IJSVGExporterOptions options = IJSVGExporterOptionCompressOutput | IJSVGExporterOptionRemoveComments;
    NSString* plain = [svg SVGStringWithSize:CGSizeMake(30, 10)
                                     options:options];
    NSString* compressed = [svg SVGStringWithSize:CGSizeMake(30, 10)
                                          options:options | IJSVGExporterOptionCompressFilters];
    CXMLDocument* document = IJSVGTestXMLDocument(compressed);
    CXMLElement* filter = [document nodesForXPath:@"//*[local-name()='filter']"
                                            error:nil].firstObject;
    XCTAssertNotNil(filter);
    for(NSString* name in @[@"x", @"y", @"width", @"height", @"filterUnits", @"primitiveUnits"]) {
        XCTAssertNil([filter attributeForName:name]);
    }
    CXMLElement* offset = [document nodesForXPath:@"//*[local-name()='feOffset']"
                                            error:nil].firstObject;
    XCTAssertNil([offset attributeForName:@"dx"]);
    XCTAssertNil([offset attributeForName:@"dy"]);
    XCTAssertEqualObjects([offset attributeForName:@"result"].stringValue,
                          @"offsetResult");
    CXMLElement* blur = [document nodesForXPath:@"//*[local-name()='feGaussianBlur']"
                                          error:nil].firstObject;
    XCTAssertEqualObjects([blur attributeForName:@"in"].stringValue,
                          @"offsetResult");
    XCTAssertEqualObjects([blur attributeForName:@"stdDeviation"].stringValue,
                          @".5");
    XCTAssertTrue([plain containsString:@"00.5000, 00.5000"]);
    XCTAssertTrue([compressed containsString:@"0.12345678901234567"] ||
                  [compressed containsString:@".12345678901234567"]);
    XCTAssertLessThan(compressed.length, plain.length);
    XCTAssertLessThanOrEqual(IJSVGFilterMaximumError([self render:compressed
                                                            scale:10],
                                                     [self render:plain
                                                            scale:10]),
                             1.);
}

- (void)testFilterExportCompressionUsesFloatingPointOptionsAndKeepsListSeparators
{
    IJSVG* svg = IJSVGTestSVGObject([self filtered:@"<feOffset dx=\"0.1234\" dy=\"-0.5678\"/>"
                                                    "<feComponentTransfer><feFuncR type=\"table\" "
                                                    "tableValues=\"0.25, -0.5, 1e-3\"/>"
                                                    "</feComponentTransfer>"]);
    NSString* exported = [svg SVGStringWithSize:CGSizeMake(30, 10)
                                        options:IJSVGExporterOptionCompressFilters
                           floatingPointOptions:IJSVGFloatingPointOptionsMake(YES,
                                                                              2)];
    CXMLDocument* document = IJSVGTestXMLDocument(exported);
    CXMLElement* offset = [document nodesForXPath:@"//*[local-name()='feOffset']"
                                            error:nil].firstObject;
    XCTAssertEqualObjects([offset attributeForName:IJSVGAttributeDX].stringValue,
                          @".12");
    XCTAssertEqualObjects([offset attributeForName:IJSVGAttributeDY].stringValue,
                          @"-.57");
    CXMLElement* function = [document nodesForXPath:@"//*[local-name()='feFuncR']"
                                              error:nil].firstObject;
    NSString* values = [function attributeForName:IJSVGAttributeTableValues].stringValue;
    XCTAssertEqualObjects(values, @".25 -.5 0");
    XCTAssertEqual([IJSVGUtils numbersFromString:values].count, 3);
}

- (void)testFilterExportFloatingPointOptionsApplyToRegionsAndParameters
{
    NSString* source = [self document:@"<defs><filter id=\"f\" x=\"-12.3456%\" y=\"-0.1234\" "
                                       "width=\"123.4567%\" height=\"12.3456\"><feFlood "
                                       "flood-opacity=\".4567\"/><feGaussianBlur x=\"1.2345\" "
                                       "y=\"2.3456%\" width=\"12.3456\" height=\"98.7654%\" "
                                       "stdDeviation=\".1234 .5678\"/><feComponentTransfer><feFuncR "
                                       "type=\"linear\" slope=\".4567\"/></feComponentTransfer></filter>"
                                       "</defs><rect x=\"2\" y=\"2\" width=\"4\" height=\"4\" "
                                       "filter=\"url(#f)\"/>"];
    IJSVG* svg = IJSVGTestSVGObject(source);
    for(NSNumber* option in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionCompressFilters)]) {
        NSString* exported = [svg SVGStringWithSize:CGSizeMake(30, 10)
                                            options:option.integerValue
                               floatingPointOptions:IJSVGFloatingPointOptionsMake(YES,
                                                                                  2)];
        CXMLDocument* document = IJSVGTestXMLDocument(exported);
        CXMLElement* filter = [document nodesForXPath:@"//*[local-name()='filter']"
                                                error:nil].firstObject;
        XCTAssertEqualObjects([filter attributeForName:IJSVGAttributeX].stringValue,
                              @"-12.35%");
        XCTAssertEqualObjects([filter attributeForName:IJSVGAttributeY].stringValue,
                              @"-.13");
        XCTAssertEqualObjects([filter attributeForName:IJSVGAttributeWidth].stringValue,
                              @"123.45%");
        XCTAssertEqualObjects([filter attributeForName:IJSVGAttributeHeight].stringValue,
                              @"12.34");
        CXMLElement* blur = [document nodesForXPath:@"//*[local-name()='feGaussianBlur']"
                                              error:nil].firstObject;
        XCTAssertEqualObjects([blur attributeForName:IJSVGAttributeX].stringValue,
                              @"1.23");
        XCTAssertEqualObjects([blur attributeForName:IJSVGAttributeY].stringValue,
                              @"2.34%");
        XCTAssertEqualObjects([blur attributeForName:IJSVGAttributeWidth].stringValue,
                              @"12.34");
        XCTAssertEqualObjects([blur attributeForName:IJSVGAttributeHeight].stringValue,
                              @"98.76%");
        XCTAssertEqualObjects([blur attributeForName:IJSVGAttributeStdDeviation].stringValue,
                              @".12 .56");
        CXMLElement* flood = [document nodesForXPath:@"//*[local-name()='feFlood']"
                                               error:nil].firstObject;
        XCTAssertEqualObjects([flood attributeForName:IJSVGAttributeFloodOpacity].stringValue,
                              @".45");
        CXMLElement* function = [document nodesForXPath:@"//*[local-name()='feFuncR']"
                                                  error:nil].firstObject;
        XCTAssertEqualObjects([function attributeForName:IJSVGAttributeSlope].stringValue,
                              @".45");
    }
}

- (void)testFilterExportCompressionPreservesRegionsAndContextDependentValues
{
    NSString* source = [self filtered:@"<feDropShadow dx=\"0\" dy=\"0\" stdDeviation=\"0\"/>"
                                       "<feGaussianBlur stdDeviation=\"0.5000 1.5000\" x=\"0%\" "
                                       "width=\"100%\" color-interpolation-filters=\"linearRGB\"/>"
                                       "<feConvolveMatrix order=\"1\" kernelMatrix=\"2.000\" "
                                       "divisor=\"1\"/>"];
    IJSVG* svg = IJSVGTestSVGObject(source);
    NSString* compressed = [svg SVGStringWithSize:CGSizeMake(30, 10)
                                          options:IJSVGExporterOptionCompressFilters | IJSVGExporterOptionCompressOutput];
    CXMLDocument* document = IJSVGTestXMLDocument(compressed);
    CXMLElement* filter = [document nodesForXPath:@"//*[local-name()='filter']"
                                            error:nil].firstObject;
    XCTAssertEqualObjects([filter attributeForName:@"filterUnits"].stringValue,
                          @"userSpaceOnUse");
    XCTAssertEqualObjects([filter attributeForName:@"color-interpolation-filters"].stringValue,
                          @"sRGB");
    CXMLElement* shadow = [document nodesForXPath:@"//*[local-name()='feDropShadow']"
                                            error:nil].firstObject;
    for(NSString* name in @[@"dx", @"dy", @"stdDeviation"]) {
        XCTAssertEqualObjects([shadow attributeForName:name].stringValue, @"0");
    }
    CXMLElement* blur = [document nodesForXPath:@"//*[local-name()='feGaussianBlur']"
                                          error:nil].firstObject;
    XCTAssertEqualObjects([blur attributeForName:@"stdDeviation"].stringValue,
                          @".5 1.5");
    XCTAssertNotNil([blur attributeForName:@"x"]);
    XCTAssertNotNil([blur attributeForName:@"width"]);
    XCTAssertEqualObjects([blur attributeForName:@"color-interpolation-filters"].stringValue,
                          @"linearRGB");
    CXMLElement* convolution = [document nodesForXPath:@"//*[local-name()='feConvolveMatrix']"
                                                 error:nil].firstObject;
    XCTAssertEqualObjects([convolution attributeForName:@"divisor"].stringValue,
                          @"1");
    XCTAssertLessThanOrEqual(IJSVGFilterMaximumError([self render:compressed
                                                            scale:10],
                                                     [self render:source
                                                            scale:10]),
                             1.);
}

- (void)testConvolutionZeroDivisorUsesKernelSum
{
    NSString* content = @"<rect x=\"2\" y=\"2\" width=\"4\" height=\"4\" fill=\"#804020\"/>";
    NSData* expected = [self render:[self filtered:@"<feOffset/>"
                                           content:content]
                              scale:10];
    for(NSString* divisor in @[@"", @"divisor=\"0\"", @"divisor=\"2\""]) {
        NSString* primitive = [NSString stringWithFormat:@"<feConvolveMatrix order=\"1\" "
                                                          "kernelMatrix=\"2\" %@/>",
                                                         divisor];
        NSData* actual = [self render:[self filtered:primitive
                                             content:content]
                                scale:10];
        XCTAssertLessThanOrEqual(IJSVGFilterMaximumError(actual, expected), 1.,
                                 @"%@", divisor);
    }
}

- (void)testConvolutionZeroDivisorUsesOneForZeroKernelSum
{
    NSData* expected = [self render:[self filtered:@"<feFlood flood-color=\"#404040\"/><feComposite "
                                                    "in2=\"SourceGraphic\" operator=\"in\"/>"]
                              scale:10];
    for(NSString* divisor in @[@"", @"divisor=\"0\"", @"divisor=\"1\""]) {
        NSString* primitive = [NSString stringWithFormat:@"<feConvolveMatrix order=\"1\" "
                                                          "kernelMatrix=\"0\" bias=\".25\" "
                                                          "preserveAlpha=\"true\" %@/>",
                                                         divisor];
        NSData* actual = [self render:[self filtered:primitive]
                                scale:10];
        XCTAssertLessThanOrEqual(IJSVGFilterMaximumError(actual, expected), 1.,
                                 @"%@", divisor);
    }
}

- (void)testConvolutionIdentityAndBias
{
    NSData* identity = [self render:[self filtered:@"<feConvolveMatrix order=\"1\" kernelMatrix=\"2\" "
                                                    "divisor=\"2\"/>"]
                              scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(identity, 35, 35, 10),
                                         255, 0, 0, 255));
    NSData* biased = [self render:[self filtered:@"<feConvolveMatrix order=\"1\" kernelMatrix=\"0\" "
                                                  "bias=\".5\" preserveAlpha=\"true\"/>"]
                            scale:10];
    const uint8_t* value = IJSVGFilterPixel(biased, 35, 35, 10);
    for(int channel = 0; channel < 3; channel++) {
        XCTAssertEqualWithAccuracy(value[channel], 128, 1);
    }
    XCTAssertTrue(value[3] == 255);
    XCTAssertTrue(IJSVGFilterPixel(biased, 15, 35, 10)[3] == 0);
}

- (void)testDisplacementUsesUnpremultipliedMapChannels
{
    NSData* bytes = [self render:[self filtered:@"<feFlood flood-color=\"red\" flood-opacity=\".5\" "
                                                 "result=\"map\"/><feDisplacementMap "
                                                 "in=\"SourceGraphic\" in2=\"map\" scale=\"4\" "
                                                 "xChannelSelector=\"R\" yChannelSelector=\"A\"/>"]
                           scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 15, 35, 10),
                                         255, 0, 0, 255));
    XCTAssertTrue(IJSVGFilterPixel(bytes, 55, 35, 10)[3] == 0);
}

- (void)testBlendMultiplyAndArithmeticComposite
{
    NSData* multiplied = [self render:[self filtered:@"<feFlood flood-color=\"cyan\" result=\"paint\"/>"
                                                      "<feBlend in=\"SourceGraphic\" in2=\"paint\" "
                                                      "mode=\"multiply\"/>"]
                                scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(multiplied, 35, 35,
                                                          10), 0, 0, 0, 255));
    NSData* arithmetic = [self render:[self filtered:@"<feFlood flood-color=\"blue\" result=\"paint\"/>"
                                                      "<feComposite in=\"SourceGraphic\" in2=\"paint\" "
                                                      "operator=\"arithmetic\" k2=\".5\" k3=\".5\"/>"]
                                scale:10];
    const uint8_t* value = IJSVGFilterPixel(arithmetic, 35, 35, 10);
    XCTAssertTrue(abs((int)(value[0])-128) <= 1 && abs((int)(value[2])-128) <= 1 && value[3] == 255);
}

- (void)turbulenceMatchesOriginalSamples:(BOOL)fractal
                                  stitch:(BOOL)stitch
{
    // Original scalar evaluator samples, before sharing the RGBA lattice.
    const int references[4][4][4] = {
        {{3, 13, 11, 57}, {20, 13, 30, 72}, {41, 26, 36, 115}, {5, 4, 4, 35}},
        {{82, 60, 88, 156}, {84, 74, 49, 158}, {80, 87, 94, 144}, {58, 63, 62, 128}},
        {{3, 13, 11, 56}, {16, 10, 31, 65}, {33, 41, 50, 125}, {8, 13, 12, 59}},
        {{82, 60, 87, 156}, {86, 78, 45, 159}, {74, 98, 107, 153}, {73, 79, 52, 130}}
    };
    const int positions[4][2] = {{0, 0}, {3, 3}, {14, 5}, {29, 9}};
    NSData* bytes = [self render:[self filtered:[NSString stringWithFormat:@"<feTurbulence "
                                                                            "baseFrequency=\".17 .31\" "
                                                                            "seed=\"7\" numOctaves=\"4\" "
                                                                            "   type=\"%@\"    "
                                                                            "stitchTiles=\"%@\"/>",
                                                                           fractal ? @"fractalNoise" : @"turbulence",
                                                                           stitch ? @"stitch" : @"noStitch"]]
                           scale:1];
    for(int index = 0; index < 4; index++) {
        const uint8_t* actual = IJSVGFilterPixel(bytes, positions[index][0],
                                                 positions[index][1], 1);
        for(int channel = 0; channel < 4; channel++) {
            XCTAssertEqualWithAccuracy(actual[channel],
                                       references[fractal + stitch * 2][index][channel],
                                       2);
        }
    }
}

- (void)testTurbulenceMatchesOriginalSamplesCase1FalseFalse
{
    [self turbulenceMatchesOriginalSamples:NO
                                    stitch:NO];
}

- (void)testTurbulenceMatchesOriginalSamplesCase2FalseTrue
{
    [self turbulenceMatchesOriginalSamples:NO
                                    stitch:YES];
}

- (void)testTurbulenceMatchesOriginalSamplesCase3TrueFalse
{
    [self turbulenceMatchesOriginalSamples:YES
                                    stitch:NO];
}

- (void)testTurbulenceMatchesOriginalSamplesCase4TrueTrue
{
    [self turbulenceMatchesOriginalSamples:YES
                                    stitch:YES];
}

- (void)zeroDisplacementPreservesSource:(NSString*)scale
{
    NSString* content = @"<rect x=\"2\" y=\"2\" width=\"4\" height=\"4\" fill=\"#804020\" "
                         "opacity=\".6\"/><circle cx=\"8\" cy=\"5\" r=\"3\" fill=\"blue\" "
                         "opacity=\".4\"/>";
    NSData* actual = [self render:[self filtered:[NSString stringWithFormat:@"<feFlood "
                                                                             "flood-color=\"red\" "
                                                                             "result=\"map\"/>"
                                                                             "<feDisplacementMap "
                                                                             "in=\"SourceGraphic\" "
                                                                             "in2=\"map\" %@    "
                                                                             "xChannelSelector=\"R\" "
                                                                             "yChannelSelector=\"B\"/>",
                                                                            scale]
                                         content:content]
                            scale:10];
    NSData* expected = [self render:[self filtered:@"<feOffset/>"
                                           content:content]
                              scale:10];
    XCTAssertEqualObjects(actual, expected);
}

- (void)testZeroDisplacementPreservesSourceCase1Default
{
    [self zeroDisplacementPreservesSource:@""];
}

- (void)testZeroDisplacementPreservesSourceCase2Scale0
{
    [self zeroDisplacementPreservesSource:@"scale=\"0\""];
}

- (void)testTurbulenceIsSeededAndVaries
{
    NSData* a = [self render:[self filtered:@"<feTurbulence baseFrequency=\".3 .2\" seed=\"7\" "
                                             "numOctaves=\"3\" type=\"fractalNoise\"/>"]
                       scale:10];
    NSData* b = [self render:[self filtered:@"<feTurbulence baseFrequency=\".3 .2\" seed=\"7\" "
                                             "numOctaves=\"3\" type=\"fractalNoise\"/>"]
                       scale:10];
    NSData* c = [self render:[self filtered:@"<feTurbulence baseFrequency=\".3 .2\" seed=\"8\" "
                                             "numOctaves=\"3\" type=\"fractalNoise\"/>"]
                       scale:10];
    XCTAssertEqualObjects(a, b);
    XCTAssertNotEqualObjects(a, c);
    XCTAssertTrue(memcmp(IJSVGFilterPixel(a, 35, 35, 10),
                         IJSVGFilterPixel(a, 155, 75, 10), 4) != 0);
}

- (void)testDiffuseAndSpecularDistantLighting
{
    for(NSString* type in @[@"feDiffuseLighting", @"feSpecularLighting"]) {
        NSData* bytes = [self render:[self filtered:[NSString stringWithFormat:@"<%@ "
                                                                                "lighting-color=\"cyan\">"
                                                                                "<feDistantLight "
                                                                                "elevation=\"90\"/></%@>",
                                                                               type,
                                                                               type]]
                               scale:10];
        XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 40, 40,
                                                              10), 0, 255, 255,
                                             255));
    }
}

- (void)testNestedFilterNodesCopyAndRoundTrip
{
    NSString* original = [self filtered:@"<feFlood flood-color=\"cyan\" result=\"paint\"/><feComposite "
                                         "in=\"paint\" in2=\"SourceAlpha\" operator=\"in\" "
                                         "result=\"colored\"/><feComponentTransfer in=\"colored\">"
                                         "<feFuncA type=\"linear\" slope=\".5\"/></feComponentTransfer>"
                                         "<feMerge><feMergeNode/><feMergeNode in=\"SourceGraphic\"/>"
                                         "</feMerge>"];
    IJSVG* svg = IJSVGTestSVGObject(original);
    XCTAssertNotNil(svg);
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg
                                                            size:CGSizeMake(300,
                                                                                     100)
                                                         options:IJSVGExporterOptionAll];
    XCTAssertNotNil(exporter);
    NSString* exported = [exporter SVGString];
    XCTAssertNotNil(exported);
    CXMLDocument* xml = IJSVGTestXMLDocument(exported);
    XCTAssertTrue([xml nodesForXPath:@"//filter/feMerge/feMergeNode"
                               error:nil].count == 2);
    XCTAssertTrue([xml nodesForXPath:@"//filter/feComponentTransfer/feFuncA"
                               error:nil].count == 1);
    NSData* before = [self render:original
                            scale:10];
    NSData* after = [self render:exported
                           scale:10];
    XCTAssertEqualObjects(before, after);
}

- (void)testReferencedImageRendersAndSurvivesExport
{
    NSString* original = [self document:@"<defs>    <rect id=\"image\" x=\"8\" y=\"2\" width=\"3\" "
                                         "height=\"4\" fill=\"cyan\"/>    <filter id=\"f\" "
                                         "filterUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"30\" "
                                         "height=\"10\">        <feImage href=\"#image\"/>    </filter>"
                                         "</defs><rect x=\"2\" y=\"2\" width=\"3\" height=\"3\" "
                                         "fill=\"red\" filter=\"url(#f)\"/>"];
    NSData* before = [self render:original
                            scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(before, 95, 35, 10),
                                         0, 255, 255, 255));
    XCTAssertTrue(IJSVGFilterPixel(before, 35, 35, 10)[3] == 0);
    IJSVG* svg = IJSVGTestSVGObject(original);
    XCTAssertNotNil(svg);
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg
                                                            size:CGSizeMake(300,
                                                                                     100)
                                                         options:IJSVGExporterOptionAll];
    XCTAssertNotNil(exporter);
    NSString* exported = [exporter SVGString];
    XCTAssertNotNil(exported);
    XCTAssertEqualObjects([self render:exported
                                 scale:10], before);
}

- (void)referencedImagePrimitivePreservesCoordinates:(NSString*)region
{
    NSArray<NSString*>* values = [region componentsSeparatedByString:@" "];
    NSString* attributes = [NSString stringWithFormat:@"x=\"%@\" y=\"%@\" width=\"%@\" height=\"%@\"",
                                                      values[0],
                                                      values[1],
                                                      values[2],
                                                      values[3]];
    NSData* actual = [self render:[self document:[NSString stringWithFormat:@"<defs>    <rect "
                                                                             "id=\"image\" width=\"30\" "
                                                                             "height=\"10\" "
                                                                             "fill=\"#4080c0\" "
                                                                             "opacity=\".6\"/>    "
                                                                             "<filter id=\"f\" "
                                                                             "filterUnits=\"userSpaceOnU"
                                                                             "se\" x=\"0\" y=\"0\" "
                                                                             "width=\"30\" height=\"10\">"
                                                                             "        <feImage "
                                                                             "href=\"#image\" %@/>    "
                                                                             "</filter></defs><rect "
                                                                             "width=\"30\" height=\"10\" "
                                                                             "filter=\"url(#f)\"/>",
                                                                            attributes]]
                            scale:8];
    NSData* expected = [self render:[self document:[NSString stringWithFormat:@"<rect %@ "
                                                                               "fill=\"#4080c0\" "
                                                                               "opacity=\".6\"/>",
                                                                              attributes]]
                              scale:8];
    XCTAssertLessThanOrEqual(IJSVGFilterMaximumError(actual, expected), 1);
}

- (void)testReferencedImagePrimitivePreservesCoordinates_1_8_2Case34
{
    [self referencedImagePrimitivePreservesCoordinates:@"8 2 3 4"];
}

- (void)testReferencedImagePrimitivePreservesCoordinates_2_8_125_2_375_2_25Case25
{
    [self referencedImagePrimitivePreservesCoordinates:@"8.125 2.375 2.25 2.5"];
}

- (void)testReferencedImagePrimitivePreservesCoordinates_3_2_2Case124
{
    [self referencedImagePrimitivePreservesCoordinates:@"-2 2 12 4"];
}

- (void)testReferencedImagePrimitivePreservesCoordinates_4_28_2Case44
{
    [self referencedImagePrimitivePreservesCoordinates:@"28 2 4 4"];
}

- (void)testReferencedImagePrimitivePreservesCoordinates_5_40_2Case34
{
    [self referencedImagePrimitivePreservesCoordinates:@"40 2 3 4"];
}

- (void)testEmbeddedRasterImagePreservesAspectRatio
{
    NSBitmapImageRep* image = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                      pixelsWide:2
                                                                      pixelsHigh:1
                                                                   bitsPerSample:8
                                                                 samplesPerPixel:4
                                                                        hasAlpha:YES
                                                                        isPlanar:NO
                                                                  colorSpaceName:NSDeviceRGBColorSpace
                                                                     bytesPerRow:8
                                                                    bitsPerPixel:32];
    XCTAssertNotNil(image);
    uint8_t* pixels = image.bitmapData;
    XCTAssertTrue(pixels != NULL);
    if(pixels == NULL) {
        return;
    }
    for(int x = 0; x < 2; x++) {
        pixels[x * 4] = 255;
        pixels[x * 4 + 1] = 0;
        pixels[x * 4 + 2] = 0;
        pixels[x * 4 + 3] = 255;
    }
    NSString* png = [[image representationUsingType:NSBitmapImageFileTypePNG
                                         properties:@{}] base64EncodedStringWithOptions:0];
    XCTAssertNotNil(png);
    NSData* bytes = [self render:[self filtered:[NSString stringWithFormat:@"<feImage "
                                                                            "href=\"data:image/png;"
                                                                            "base64,%@\" x=\"8\" y=\"2\" "
                                                                            "width=\"4\" height=\"4\"/>",
                                                                           png]]
                           scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 95, 35, 10),
                                         255, 0, 0, 255));
    XCTAssertEqual(IJSVGFilterPixel(bytes, 95, 25, 10)[3], 0);
    XCTAssertEqual(IJSVGFilterPixel(bytes, 35, 35, 10)[3], 0);
    NSArray<NSString*>* aspects = @[@"xMinYMin meet", @"xMaxYMax meet", @"xMidYMid slice", @"none"];
    for(NSUInteger index = 0; index < aspects.count; index++) {
        NSString* original = [self filtered:[NSString stringWithFormat:@"<feImage href=\"data:image/png;"
                                                                        "base64,%@\" x=\"8\" y=\"2\" "
                                                                        "width=\"4\" height=\"4\" "
                                                                        "preserveAspectRatio=\"%@\"/>",
                                                                       png,
                                                                       aspects[index]]];
        NSData* rendered = [self render:original
                                  scale:10];
        XCTAssertEqual(IJSVGFilterPixel(rendered, 95, 25, 10)[3] == 255,
                       index != 1, @"%@", aspects[index]);
        XCTAssertEqual(IJSVGFilterPixel(rendered, 95, 55, 10)[3] == 255,
                       index != 0, @"%@", aspects[index]);
        XCTAssertEqualObjects([self render:[self export:original
                                                  scale:10]
                                     scale:10],
                              rendered);
    }
}

- (void)testFilterTemplatesAndPrimitiveCopiesAreIndependent
{
    IJSVGRootNode* root = [self parse:@"<defs>    <filter id=\"base\" x=\"-50%\" width=\"200%\">        "
                                       "<feMerge><feMergeNode in=\"SourceGraphic\"/></feMerge>    "
                                       "</filter>    <filter id=\"derived\" href=\"#base\" y=\"-25%\"/>"
                                       "</defs><rect x=\"2\" y=\"2\" width=\"4\" height=\"4\" "
                                       "filter=\"url(#derived)\"/>"];
    IJSVGFilter* filter = root.children.firstObject.filter;
    XCTAssertNotNil(filter);
    XCTAssertEqualObjects([filter.x stringValue], @"-50%");
    XCTAssertEqualObjects([filter.y stringValue], @"-25%");
    IJSVGFilter* copy = [filter copy];
    XCTAssertNotNil(copy);
    IJSVGFilterPrimitive* originalMerge = filter.primitives.firstObject;
    XCTAssertNotNil(originalMerge);
    IJSVGFilterPrimitive* copiedMerge = copy.primitives.firstObject;
    XCTAssertNotNil(copiedMerge);
    XCTAssertTrue(originalMerge != copiedMerge);
    XCTAssertTrue(originalMerge.children.firstObject != copiedMerge.children.firstObject);
    XCTAssertTrue(copiedMerge.children.firstObject.parentNode == copiedMerge);
}

- (void)testConvolutionAndDisplacementRespectVerticalCoordinates
{
    NSData* shifted = [self render:[self filtered:@"<feConvolveMatrix order=\"1 3\" kernelMatrix=\"1 0 "
                                                   "0\" targetY=\"1\" kernelUnitLength=\"1\"    "
                                                   "edgeMode=\"none\"/>"]
                             scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(shifted, 35, 15, 10),
                                         255, 0, 0, 255));
    XCTAssertTrue(IJSVGFilterPixel(shifted, 35, 55, 10)[3] == 0);
    NSData* displaced = [self render:[self filtered:@"<feFlood flood-color=\"lime\" result=\"map\"/>"
                                                     "<feDisplacementMap in=\"SourceGraphic\" "
                                                     "in2=\"map\" scale=\"4\"    xChannelSelector=\"A\" "
                                                     "yChannelSelector=\"G\"/>"]
                               scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(displaced, 15, 15,
                                                          10), 255, 0, 0, 255));
    XCTAssertTrue(IJSVGFilterPixel(displaced, 35, 55, 10)[3] == 0);
}

- (void)testPointAndSpotLightingUseTheirChildParameters
{
    for(NSString* light in @[
        @"<fePointLight x=\"4\" y=\"4\" z=\"100\"/>",
        (@"<feSpotLight x=\"4\" y=\"4\" z=\"100\" pointsAtX=\"4\" pointsAtY=\"4\" pointsAtZ=\"0\" "
          "limitingConeAngle=\"30\"/>")
    ]) {
        NSData* bytes = [self render:[self filtered:[NSString stringWithFormat:@"<feDiffuseLighting "
                                                                                "lighting-color=\"cyan\">"
                                                                                "%@</feDiffuseLighting>",
                                                                               light]]
                               scale:10];
        const uint8_t* value = IJSVGFilterPixel(bytes, 40, 40, 10);
        XCTAssertTrue(value[0] == 0 && value[1] > 250 && value[2] > 250 && value[3] == 255);
    }
}

- (void)testFillAndStrokePaintAreIndependentInputs
{
    NSString* original = [self document:@"<defs><filter id=\"f\" filterUnits=\"userSpaceOnUse\" x=\"0\" "
                                         "y=\"0\" width=\"30\" height=\"10\">    <feOffset "
                                         "in=\"StrokePaint\"/></filter></defs><rect x=\"2\" y=\"2\" "
                                         "width=\"4\" height=\"4\" fill=\"red\" stroke=\"blue\" "
                                         "filter=\"url(#f)\"/>"];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel([self render:original
                                                                 scale:10],
                                                          150, 50, 10), 0, 0,
                                         255, 255));
}

- (void)testFilterReferenceCyclesTerminate
{
    NSString* original = [self document:@"<defs>    <filter id=\"a\" href=\"#b\"/>    <filter id=\"b\" "
                                         "href=\"#a\"/>    <g id=\"self\"><rect width=\"4\" height=\"4\" "
                                         "filter=\"url(#c)\"/></g>    <filter id=\"c\"><feImage "
                                         "href=\"#self\"/></filter></defs><rect x=\"2\" y=\"2\" "
                                         "width=\"4\" height=\"4\" filter=\"url(#a)\"/><rect x=\"8\" "
                                         "y=\"2\" width=\"4\" height=\"4\" filter=\"url(#c)\"/>"];
    NSData* bytes = [self render:original
                           scale:10];
    XCTAssertTrue(bytes.length == 300 * 100 * 4);
}

- (void)testGradientAndPatternPaintInputs
{
    for(NSString* definition in @[
        (@"<linearGradient id=\"p\"><stop stop-color=\"red\"/><stop offset=\"1\" stop-color=\"blue\"/>"
          "</linearGradient>"),
        (@"<pattern id=\"p\" patternUnits=\"userSpaceOnUse\" width=\"2\" height=\"2\"><rect width=\"2\" "
          "height=\"2\" fill=\"cyan\"/></pattern>")
    ]) {
        NSString* original = [self document:[NSString stringWithFormat:@"<defs>%@    <filter id=\"f\" "
                                                                        "filterUnits=\"userSpaceOnUse\" "
                                                                        "x=\"0\" y=\"0\" width=\"30\" "
                                                                        "height=\"10\"><feOffset "
                                                                        "in=\"FillPaint\"/></filter>"
                                                                        "</defs><rect x=\"2\" y=\"2\" "
                                                                        "width=\"4\" height=\"4\" "
                                                                        "fill=\"url(#p)\" "
                                                                        "filter=\"url(#f)\"/>",
                                                                       definition]];
        NSData* before = [self render:original
                                scale:10];
        const uint8_t* outside = IJSVGFilterPixel(before, 155, 55, 10);
        XCTAssertTrue(outside[3] == 255);
        if([definition hasPrefix:@"<linearGradient"]) {
            XCTAssertTrue(outside[2] > 250);
            XCTAssertTrue(IJSVGFilterPixel(before, 25, 35, 10)[0] > IJSVGFilterPixel(before,
                                                                                     55,
                                                                                     35,
                                                                                     10)[0]);
        } else {
            XCTAssertTrue(IJSVGFilterPixelEquals(outside, 0, 255, 255, 255));
        }
        IJSVG* svg = IJSVGTestSVGObject(original);
        XCTAssertNotNil(svg);
        IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg
                                                                size:CGSizeMake(300,
                                                                                         100)
                                                             options:IJSVGExporterOptionAll];
        XCTAssertNotNil(exporter);
        NSString* exported = [exporter SVGString];
        XCTAssertNotNil(exported);
        NSData* after = [self render:exported
                               scale:10];
        XCTAssertLessThan(IJSVGFilterMeanError(before, after), 1);
    }
}

- (void)testBitmapBackgroundInputUsesPreviouslyPaintedContent
{
    NSString* original = [self document:@"<g enable-background=\"new\"><defs><filter id=\"f\" "
                                         "filterUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"30\" "
                                         "height=\"10\">    <feColorMatrix in=\"BackgroundImage\" "
                                         "type=\"matrix\"        values=\"0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 "
                                         "0 0 0 1 0\"/></filter></defs><rect x=\"2\" y=\"2\" width=\"4\" "
                                         "height=\"4\" fill=\"blue\"/><rect x=\"12\" y=\"2\" width=\"4\" "
                                         "height=\"4\" fill=\"red\" filter=\"url(#f)\"/></g>"];
    NSData* bytes = [self render:original
                           scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(bytes, 35, 35, 10), 0,
                                         255, 0, 255));
    XCTAssertTrue(IJSVGFilterPixel(bytes, 135, 35, 10)[3] == 0);
}

- (void)testComponentTransferTableDiscreteAndGamma
{
    NSData* bytes = [self render:[self filtered:@"<feComponentTransfer>    <feFuncR type=\"table\" "
                                                 "tableValues=\".25 .75\"/>    <feFuncG "
                                                 "type=\"discrete\" tableValues=\".5 1\"/>    <feFuncB "
                                                 "type=\"gamma\" amplitude=\"0\" offset=\".25\"/>    "
                                                 "<feFuncA type=\"identity\"/></feComponentTransfer>"]
                           scale:10];
    const uint8_t* value = IJSVGFilterPixel(bytes, 35, 35, 10);
    XCTAssertTrue(abs((int)(value[0])-191) <= 1);
    XCTAssertTrue(abs((int)(value[1])-128) <= 1);
    XCTAssertTrue(abs((int)(value[2])-64) <= 1);
    XCTAssertTrue(value[3] == 255);
}

- (void)testFilterReferencesUseNamespaceAliasesAndHrefPrecedence
{
    for(NSString* reference in @[@"x:href=\"#cyan\"", @"x:href=\"#red\" href=\"#cyan\""]) {
        NSString* original = [self document:[NSString stringWithFormat:@"<defs "
                                                                        "xmlns:x=\"http://www.w3.org/199"
                                                                        "9/xlink\">    <rect id=\"cyan\" "
                                                                        "x=\"8\" y=\"2\" width=\"3\" "
                                                                        "height=\"4\" fill=\"cyan\"/>    "
                                                                        "<rect id=\"red\" x=\"8\" "
                                                                        "y=\"2\" width=\"3\" "
                                                                        "height=\"4\" fill=\"red\"/>    "
                                                                        "<filter id=\"base\" "
                                                                        "filterUnits=\"userSpaceOnUse\" "
                                                                        "x=\"0\" y=\"0\" width=\"30\" "
                                                                        "height=\"10\">        <feImage "
                                                                        "%@/>    </filter>    <filter "
                                                                        "id=\"derived\" "
                                                                        "x:href=\"#base\"/></defs><rect "
                                                                        "x=\"2\" y=\"2\" width=\"3\" "
                                                                        "height=\"3\" "
                                                                        "filter=\"url('#derived')\"/>",
                                                                       reference]];
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:original
                                                             fileURL:nil
                                                               error:nil];
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(30, 10)];
        XCTAssertNotNil(root);
        IJSVGFilter* filter = root.children.firstObject.filter;
        XCTAssertNotNil(filter);
        XCTAssertTrue(filter.primitives.count == 1);
        IJSVGFilterPrimitive* primitive = filter.primitives.firstObject;
        XCTAssertNotNil(primitive);
        IJSVGNode* imageNode = primitive.imageNode;
        XCTAssertNotNil(imageNode);
        XCTAssertTrue(imageNode.x.value == 8);
        XCTAssertTrue(imageNode.width.value == 3);
        XCTAssertTrue(imageNode.shouldRender);
        XCTAssertTrue(filter.units == IJSVGUnitUserSpaceOnUse);
        XCTAssertTrue(filter.width.value == 30);
        NSData* rendered = [self render:original
                                  scale:10];
        XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(rendered, 95, 35,
                                                              10), 0, 255, 255,
                                             255));
        IJSVG* svg = IJSVGTestSVGObject(original);
        XCTAssertNotNil(svg);
        IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg
                                                                size:CGSizeMake(300,
                                                                                         100)
                                                             options:IJSVGExporterOptionAll];
        XCTAssertNotNil(exporter);
        XCTAssertEqualObjects([self render:[exporter SVGString]
                                     scale:10],
                              rendered);
    }
}

- (void)testFilterURLByteParserPreservesIdentifiersAndOrder
{
    NSArray<NSArray*>* cases = @[
        @[@"", @[]],
        @[@" \t\r\n", @[]],
        @[@"url(#first)", @[@"first"]],
        @[@" URL( '#first' )\turl(\"#second\")\nurl(#first) ", @[@"first", @"second", @"first"]],
        @[@"url(#first)url(#second)", @[@"first", @"second"]],
        @[@"url(#éclair) url('#影')", @[@"éclair", @"影"]],
        @[@"url('#shape(1)')", @[@"shape(1)"]]
    ];
    for(NSArray* entry in cases) {
        XCTAssertEqualObjects([IJSVGUtils defURLs:entry[0]], entry[1],
                              @"Input: %@", entry[0]);
    }
}

- (void)testFilterURLByteParserRejectsIncompleteOrInvalidLists
{
    for(NSString* input in @[
        @"u",
        @"ur",
        @"url",
        @"url(",
        @"url(#",
        @"url(#first",
        @"url('#first)",
        @"url(\"#first')",
        @"url()",
        @"url(#)",
        @"url('')",
        @"url('#')",
        @"url(file.svg#first)",
        @"url(#first) trailing",
        @"url(#first) url(#",
        @"url(#first))",
        @"url(#first),url(#second)",
        @"url(#first second)",
        @"url(#first(nested))",
        @"url(#first) blur(2)",
        @"url(#first\\second)",
        @"url(#first)\0url(#second)",
        @"url('#first\nsecond')",
        @"url('#first'junk'#second')",
        @"url('#first' trailing)",
        @"url(#first) ) url(#second)",
        @"url(#first) url(#second) unfinished("
    ]) {
        XCTAssertTrue(([IJSVGUtils defURLs:input].count == 0), @"Input: %@",
                      input);
    }
}

- (void)testFilterURLListRejectsMalformedReferences
{
    for(NSString* reference in @[@"url('#f')", @"url(&quot;#f&quot;)", @"URL(#f) url(#f)"]) {
        IJSVGRootNode* root = [self parse:[NSString stringWithFormat:@"<defs><filter id=\"f\"><feOffset/>"
                                                                      "</filter></defs><rect width=\"4\" "
                                                                      "height=\"4\" filter=\"%@\"/>",
                                                                     reference]];
        XCTAssertTrue(root.children.firstObject.filters.count > 0);
    }
    for(NSString* reference in @[
        @"url(')",
        @"url(#f",
        @"url(#f) trailing",
        @"url(#missing)",
        @"url(file.svg#f)"
    ]) {
        IJSVGRootNode* root = [self parse:[NSString stringWithFormat:@"<defs><filter id=\"f\"><feOffset/>"
                                                                      "</filter></defs><rect width=\"4\" "
                                                                      "height=\"4\" filter=\"%@\"/>",
                                                                     reference]];
        XCTAssertTrue(root.children.firstObject.filters.count == 0);
    }
}

- (void)testCoreImageCompositeOperatorsPreservePremultipliedAlpha
{
    NSArray<NSString*>* operations = @[@"over", @"in", @"out", @"atop", @"xor", @"lighter"];
    const int expected[6][4] = {{128, 0, 64, 191}, {64, 0, 0, 64}, {64, 0, 0, 64},
        {64, 0, 64, 128}, {64, 0, 64, 128}, {128, 0, 128, 255}};
    for(NSUInteger index = 0; index < operations.count; index++) {
        NSString* operation = operations[index];
        NSData* bytes = [self render:[self filtered:[NSString stringWithFormat:@"<feFlood "
                                                                                "flood-color=\"red\" "
                                                                                "flood-opacity=\".5\" "
                                                                                "result=\"a\"/><feFlood "
                                                                                "flood-color=\"blue\" "
                                                                                "flood-opacity=\".5\" "
                                                                                "result=\"b\"/>"
                                                                                "<feComposite in=\"a\" "
                                                                                "in2=\"b\" "
                                                                                "operator=\"%@\" "
                                                                                "color-interpolation-fil"
                                                                                "ters=\"sRGB\"/>",
                                                                               operation]]
                               scale:10];
        const uint8_t* actual = IJSVGFilterPixel(bytes, 35, 35, 10);
        for(int channel = 0; channel < 4; channel++) {
            XCTAssertEqualWithAccuracy(actual[channel],
                                       expected[index][channel], 2,
                                       @"%@, channel %d", operation, channel);
        }
    }
}

- (void)acceleratedShadowMatchesExplicitBlur:(NSString*)deviation
                                  colorSpace:(NSString*)colorSpace
{
    for(NSNumber* scaleValue in @[@2, @20]) {
        NSInteger scale = scaleValue.integerValue;
        NSString* content = @"<rect x=\"4\" y=\"2\" width=\"5\" height=\"5\" fill=\"#804020\" "
                             "opacity=\".6\"/><circle cx=\"13\" cy=\"5\" r=\"3\" fill=\"blue\" "
                             "opacity=\".4\"/>";
        NSData* (^renderEffects)(NSString*) = ^NSData*(NSString* primitives) {
            // Keep blur tails inside the filter region before the explicit offset.
            return [self render:[self document:[NSString stringWithFormat:@"<defs><filter id=\"f\" "
                                                                           "filterUnits=\"userSpaceOnUse"
                                                                           "\"    x=\"-10\" y=\"-10\" "
                                                                           "width=\"50\" height=\"30\" "
                                                                           "color-interpolation-filters="
                                                                           "\"%@\">    %@</filter></defs>"
                                                                           "<g filter=\"url(#f)\">%@</g>",
                                                                          colorSpace,
                                                                          primitives,
                                                                          content]]
                          scale:scale];
        };
        NSData* shadow = renderEffects([NSString stringWithFormat:@"<feDropShadow dx=\"2\" dy=\"-1\" "
                                                                   "stdDeviation=\"%@\"    "
                                                                   "flood-color=\"#4080c0\" "
                                                                   "flood-opacity=\".7\"/>",
                                                                  deviation]);
        NSData* explicit = renderEffects([NSString stringWithFormat:@"<feGaussianBlur in=\"SourceAlpha\" "
                                                                     "stdDeviation=\"%@\"/><feOffset "
                                                                     "dx=\"2\" dy=\"-1\" "
                                                                     "result=\"blur\"/><feFlood "
                                                                     "flood-color=\"#4080c0\" "
                                                                     "flood-opacity=\".7\"/><feComposite "
                                                                     "in2=\"blur\" operator=\"in\" "
                                                                     "result=\"shadow\"/><feMerge>"
                                                                     "<feMergeNode in=\"shadow\"/>"
                                                                     "<feMergeNode in=\"SourceGraphic\"/>"
                                                                     "</feMerge>",
                                                                    deviation]);
        XCTAssertLessThanOrEqual(IJSVGFilterMaximumError(shadow, explicit), 1,
                                 @"%@, %@, scale %ld", deviation, colorSpace,
                                 (long)scale);
    }
}

- (void)testAcceleratedShadowMatchesExplicitBlur_1Case0SRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@"0"
                                    colorSpace:@"sRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_2Case0LinearRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@"0"
                                    colorSpace:@"linearRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_3Case3SRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@".3"
                                    colorSpace:@"sRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_4Case3LinearRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@".3"
                                    colorSpace:@"linearRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_5_1Case7SRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@"1.7"
                                    colorSpace:@"sRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_6_1Case7LinearRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@"1.7"
                                    colorSpace:@"linearRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_7_3Case1SRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@".3 .1"
                                    colorSpace:@"sRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_8_3Case1LinearRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@".3 .1"
                                    colorSpace:@"linearRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_9_3Case0SRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@".3 0"
                                    colorSpace:@"sRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_10_3Case0LinearRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@".3 0"
                                    colorSpace:@"linearRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_11_0Case3SRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@"0 .3"
                                    colorSpace:@"sRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_12_0Case3LinearRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@"0 .3"
                                    colorSpace:@"linearRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_13_1_7Case0SRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@"1.7 0"
                                    colorSpace:@"sRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_14_1_7Case0LinearRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@"1.7 0"
                                    colorSpace:@"linearRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_15_0_1Case7SRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@"0 1.7"
                                    colorSpace:@"sRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_16_0_1Case7LinearRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@"0 1.7"
                                    colorSpace:@"linearRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_17_1_7Case8SRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@"1.7 .8"
                                    colorSpace:@"sRGB"];
}

- (void)testAcceleratedShadowMatchesExplicitBlur_18_1_7Case8LinearRGB
{
    [self acceleratedShadowMatchesExplicitBlur:@"1.7 .8"
                                    colorSpace:@"linearRGB"];
}

- (void)lightingColorReadbackPreservesInterpolation:(NSString*)colorSpace
                                              scale:(NSInteger)scale
{
    NSData* bytes = [self render:[self filtered:@"<feDiffuseLighting surfaceScale=\"0\" "
                                                 "diffuseConstant=\".5\" lighting-color=\"#804020\">    "
                                                 "<feDistantLight elevation=\"90\"/></feDiffuseLighting>"
                                     attributes:[NSString stringWithFormat:@"color-interpolation-filters"
                                                                            "=\"%@\"",
                                                                           colorSpace]
                                        content:@"<rect x=\"2\" y=\"2\" width=\"4\" height=\"4\" "
                                                 "fill=\"red\"/>"]
                           scale:scale];
    const double values[3] = {128, 64, 32};
    const uint8_t* pixels = bytes.bytes;
    for(NSUInteger channel = 0; channel < 3; channel++) {
        double encoded = values[channel] / 255;
        double linear = encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055,
                                                                   2.4);
        double shaded = linear * 0.5;
        double expected = [colorSpace isEqual:@"sRGB"] ? encoded * 0.5
            : (shaded <= 0.0031308 ? shaded * 12.92 : 1.055 * pow(shaded,
                                                                  1 / 2.4) - 0.055);
        double maximumError = 0;
        for(NSUInteger index = channel; index < bytes.length; index += 4) {
            maximumError = MAX(maximumError,
                               fabs(pixels[index] - expected * 255));
        }
        XCTAssertLessThanOrEqual(maximumError, 2, @"Channel %lu",
                                 (unsigned long)channel);
    }
    XCTAssertEqual(IJSVGFilterPixel(bytes, 35, 35, scale)[3], 255);
}

- (void)testLightingColorReadbackPreservesInterpolationCase1SRGB10
{
    [self lightingColorReadbackPreservesInterpolation:@"sRGB"
                                                scale:10];
}

- (void)testLightingColorReadbackPreservesInterpolationCase2SRGB20
{
    [self lightingColorReadbackPreservesInterpolation:@"sRGB"
                                                scale:20];
}

- (void)testLightingColorReadbackPreservesInterpolationCase3LinearRGB10
{
    [self lightingColorReadbackPreservesInterpolation:@"linearRGB"
                                                scale:10];
}

- (void)testLightingColorReadbackPreservesInterpolationCase4LinearRGB20
{
    [self lightingColorReadbackPreservesInterpolation:@"linearRGB"
                                                scale:20];
}

- (void)acceleratedArithmeticMatchesPremultipliedEquation:(BOOL)sameInput
{
    NSData* bytes = [self render:[self filtered:[NSString stringWithFormat:@"<feFlood "
                                                                            "flood-color=\"#804020\" "
                                                                            "flood-opacity=\".5\" "
                                                                            "result=\"a\"/><feFlood "
                                                                            "flood-color=\"#2080c0\" "
                                                                            "flood-opacity=\".75\" "
                                                                            "result=\"b\"/><feComposite "
                                                                            "in=\"a\" in2=\"%@\" "
                                                                            "operator=\"arithmetic\" "
                                                                            "k1=\".4\" k2=\"-.3\" "
                                                                            "k3=\".8\" k4=\".07\"/>",
                                                                           sameInput ? @"a" : @"b"]]
                           scale:10];
    const double a[4] = {128.0 / 255 * 0.5, 64.0 / 255 * 0.5, 32.0 / 255 * 0.5, 0.5};
    const double second[4] = {32.0 / 255 * 0.75, 128.0 / 255 * 0.75, 192.0 / 255 * 0.75, 0.75};
    const double* b = sameInput ? a : second;
    double expected[4];
    for(int channel = 0; channel < 4; channel++) {
        expected[channel] = MIN(1,
                                MAX(0,
                                    0.4 * a[channel] * b[channel] - 0.3 * a[channel] + 0.8 * b[channel] + 0.07));
    }
    const uint8_t* actual = IJSVGFilterPixel(bytes, 35, 35, 10);
    for(int channel = 0; channel < 4; channel++) {
        XCTAssertEqualWithAccuracy(actual[channel],
                                   MIN(expected[channel], expected[3]) * 255,
                                   2);
    }
}

- (void)testAcceleratedArithmeticMatchesPremultipliedEquationCase1False
{
    [self acceleratedArithmeticMatchesPremultipliedEquation:NO];
}

- (void)testAcceleratedArithmeticMatchesPremultipliedEquationCase2True
{
    [self acceleratedArithmeticMatchesPremultipliedEquation:YES];
}

- (void)testAcceleratedIndependentGammaMatchesScalarEquation
{
    NSData* bytes = [self render:[self filtered:@"<feFlood flood-color=\"#4080c0\" flood-opacity=\".5\"/>"
                                                 "<feComponentTransfer>    <feFuncR type=\"gamma\" "
                                                 "exponent=\"1.3\" amplitude=\".8\" offset=\".1\"/>    "
                                                 "<feFuncG type=\"gamma\" exponent=\".7\"/>    <feFuncB "
                                                 "type=\"gamma\" exponent=\"-.5\" amplitude=\".4\"/>    "
                                                 "<feFuncA type=\"gamma\" exponent=\"1.7\"/>"
                                                 "</feComponentTransfer>"]
                           scale:10];
    double alpha = pow(0.5, 1.7);
    const double expected[4] = {0.8 * pow(64.0 / 255, 1.3) + 0.1,
        pow(128.0 / 255, 0.7), 0.4 * pow(192.0 / 255, -0.5), 1};
    const uint8_t* actual = IJSVGFilterPixel(bytes, 35, 35, 10);
    for(int channel = 0; channel < 4; channel++) {
        XCTAssertEqualWithAccuracy(actual[channel],
                                   MIN(1, expected[channel]) * alpha * 255, 2);
    }
    NSData* zero = [self render:[self filtered:@"<feFlood flood-color=\"black\" flood-opacity=\"0\"/>"
                                                "<feComponentTransfer><feFuncA type=\"gamma\" "
                                                "exponent=\"-1\"/></feComponentTransfer>"]
                          scale:10];
    XCTAssertEqualObjects(zero, [NSMutableData dataWithLength:zero.length]);
}

- (void)testAcceleratedConvolutionMatchesScalarReference
{
    NSString* content = @"<rect x=\"0\" y=\"0\" width=\"8\" height=\"8\" fill=\"red\" opacity=\".5\"/>"
                         "<rect x=\"3\" y=\"2\" width=\"8\" height=\"5\" fill=\"blue\" opacity=\".75\"/>";
    const int sizes[2][2] = {{8, 4}, {11, 11}};
    for(int size = 0; size < 2; size++) {
        int width = sizes[size][0], height = sizes[size][1];
        double weights[121] = {0};
        weights[0] = -0.25;
        weights[width + 2] = 0.5;
        weights[width * height - 1] = 0.75;
        NSMutableArray<NSString*>* numbers = [NSMutableArray array];
        for(int index = 0; index < width * height; index++) {
            [numbers addObject:[NSString stringWithFormat:@"%g",
                                                          weights[index]]];
        }
        NSString* kernel = [numbers componentsJoinedByString:@" "];
        for(NSString* edge in @[@"none", @"duplicate", @"wrap"]) {
            for(NSString* preserve in @[@"true", @"false"]) {
                NSString* step = @"1";
                NSString* primitive = [NSString stringWithFormat:@"<feConvolveMatrix order=\"%ld %ld\" "
                                                                  "kernelMatrix=\"%@\"    targetX=\"1\" "
                                                                  "targetY=\"2\" divisor=\"1.25\" "
                                                                  "bias=\".1\"    edgeMode=\"%@\" "
                                                                  "preserveAlpha=\"%@\" "
                                                                  "kernelUnitLength=\"%@\"/>",
                                                                 (long)width,
                                                                 (long)height,
                                                                 kernel,
                                                                 edge,
                                                                 preserve,
                                                                 step];
                NSData* fast = [self render:[self filtered:primitive
                                                   content:content]
                                      scale:1];
                NSData* source = [self render:[self document:content]
                                        scale:1];
                double (^sample)(int, int, int) = ^double(int x, int y,
                                                          int channel) {
                    if([edge isEqual:@"duplicate"]) {
                        x = MIN(29, MAX(0, x));
                        y = MIN(9, MAX(0, y));
                    } else if([edge isEqual:@"wrap"]) {
                        x = (x % 30 + 30) % 30;
                        y = (y % 10 + 10) % 10;
                    }
                    if(x < 0 || x >= 30 || y < 0 || y >= 10) {
                        return 0;
                    }
                    return IJSVGFilterPixel(source, x, y, 1)[channel] / 255.0;
                };
                BOOL preserveAlpha = [preserve isEqual:@"true"];
                double maximumError = 0;
                for(int y = 0; y < 10; y++) {
                    for(int x = 0; x < 30; x++) {
                        double sums[4] = {0};
                        for(int j = 0; j < height; j++) {
                            for(int i = 0; i < width; i++) {
                                double alpha = sample(x + i - 1, y + j - 2, 3);
                                double weight = weights[(height - j - 1) * width + width - i - 1];
                                for(int channel = 0; channel < 4; channel++) {
                                    double value = sample(x + i - 1, y + j - 2,
                                                          channel);
                                    if(preserveAlpha && channel < 3) {
                                        value = alpha > 0 ? value / alpha : 0;
                                    }
                                    sums[channel] += value * weight;
                                }
                            }
                        }
                        double alpha = preserveAlpha ? sample(x, y, 3) : MIN(1,
                                                                             MAX(0,
                                                                                 sums[3] / 1.25 + 0.1));
                        const uint8_t* actual = IJSVGFilterPixel(fast, x, y, 1);
                        for(int channel = 0; channel < 4; channel++) {
                            double expected = alpha;
                            if(channel < 3) {
                                expected = preserveAlpha ? MIN(1,
                                                               MAX(0,
                                                                   sums[channel] / 1.25 + 0.1)) * alpha
                                    : MIN(alpha,
                                          MAX(0,
                                              sums[channel] / 1.25 + 0.1 * alpha));
                            }
                            maximumError = MAX(maximumError,
                                               fabs(actual[channel] - expected * 255));
                        }
                    }
                }
                XCTAssertLessThanOrEqual(maximumError, 3,
                                         @"Kernel %dx%d, %@, preserveAlpha=%@",
                                         width, height, edge, preserve);
            }
        }
    }
}

- (void)testCoreImageConvolutionMatchesGeneralKernels
{
    NSString* content = @"<rect x=\"0\" y=\"0\" width=\"8\" height=\"8\" fill=\"red\" opacity=\".5\"/>"
                         "<rect x=\"3\" y=\"2\" width=\"8\" height=\"5\" fill=\"blue\" opacity=\".75\"/>";
    const int sizes[6][2] = {{3, 3}, {5, 5}, {7, 7}, {9, 1}, {1, 9}, {2, 3}};
    for(int size = 0; size < 6; size++) {
        int width = sizes[size][0], height = sizes[size][1];
        double small[49] = {0}, large[121] = {0};
        small[0] = -0.25;
        small[width * height / 2] = 0.75;
        small[width * height - 1] = 0.5;
        for(int y = 0; y < height; y++) {
            for(int x = 0; x < width; x++) {
                large[(y + 11 - height) * 11 + x + 11 - width] = small[y * width + x];
            }
        }
        for(NSString* edge in @[@"none", @"duplicate", @"wrap"]) {
            NSString* (^primitive)(const double*, int, int) = ^NSString*(const double* weights, int w, int h) {
                NSMutableArray<NSString*>* numbers = [NSMutableArray array];
                for(int index = 0; index < w * h; index++) {
                    [numbers addObject:[NSString stringWithFormat:@"%g",
                                                                  weights[index]]];
                }
                return [NSString stringWithFormat:@"<feConvolveMatrix order=\"%d %d\" "
                                                   "kernelMatrix=\"%@\" targetX=\"0\" targetY=\"0\" "
                                                   "divisor=\"1\" edgeMode=\"%@\"/>",
                                                  w,
                                                  h,
                                                  [numbers componentsJoinedByString:@" "],
                                                  edge];
            };
            NSData* fast = [self render:[self filtered:primitive(small, width,
                                                                 height)
                                               content:content]
                                  scale:1];
            NSData* general = [self render:[self filtered:primitive(large, 11,
                                                                    11)
                                                  content:content]
                                     scale:1];
            XCTAssertLessThanOrEqual(IJSVGFilterMaximumError(fast, general), 2,
                                     @"Kernel %dx%d, %@", width, height, edge);
        }
    }
}

- (void)testCoreImageGammaAndPolynomialRespectAlpha
{
    NSData* bytes = [self render:[self filtered:@"<feFlood flood-color=\"#808080\" flood-opacity=\".5\"/>"
                                                 "<feComponentTransfer>    <feFuncR type=\"gamma\" "
                                                 "exponent=\"1.5\"/>    <feFuncG type=\"gamma\" "
                                                 "exponent=\"1.5\" amplitude=\".5\"/>    <feFuncB "
                                                 "type=\"gamma\" exponent=\"1.5\" offset=\".1\"/>    "
                                                 "<feFuncA type=\"linear\" slope=\".5\"/>"
                                                 "</feComponentTransfer>"]
                           scale:10];
    const uint8_t* value = IJSVGFilterPixel(bytes, 35, 35, 10);
    double gamma = pow(128.0 / 255, 1.5);
    const double expected[4] = {gamma, gamma * 0.5, gamma + 0.1, 1};
    for(int channel = 0; channel < 4; channel++) {
        XCTAssertEqualWithAccuracy(value[channel],
                                   round(expected[channel] * 0.25 * 255), 2);
    }
}

- (void)testNumericFilterAttributesUseSVGNumberSyntax
{
    NSData* expected = [self render:[self filtered:@"<feDropShadow dx=\"2\" dy=\"-1\" stdDeviation=\".5, "
                                                    "1\" flood-opacity=\".5\"/>"]
                              scale:10];
    NSData* scientific = [self render:[self filtered:@"<feDropShadow dx=\"+2e0\" dy=\"-1E+0\" "
                                                      "stdDeviation=\"5e-1, 1e0\" "
                                                      "flood-opacity=\"5e1%\"/>"]
                                scale:10];
    XCTAssertEqualObjects(scientific, expected);
    NSData* defaults = [self render:[self filtered:@"<feDropShadow/>"]
                              scale:10];
    for(NSString* invalid in @[@"1e", @"1,,2", @"1,", @"1px", @"1e999"]) {
        NSData* actual = [self render:[self filtered:[NSString stringWithFormat:@"<feDropShadow "
                                                                                 "dx=\"%@\" "
                                                                                 "stdDeviation=\"%@\"/>",
                                                                                invalid,
                                                                                invalid]]
                                scale:10];
        XCTAssertTrue(([actual isEqual:defaults]),
                      @"Invalid numeric attribute: %@", invalid);
    }
}

- (void)testFilterPresentationAttributesUseSharedStyleCascade
{
    IJSVGRootNode* root = [self parse:@"<style>    feDiffuseLighting { lighting-color: red; "
                                       "color-interpolation-filters: sRGB; }</style><defs><filter "
                                       "id=\"f\">    <feDiffuseLighting lighting-color=\"blue\" "
                                       "surfaceScale=\"2\"        style=\"lighting-color: lime; "
                                       "color-interpolation-filters: linearRGB\">        <fePointLight "
                                       "x=\"1\" y=\"2\" z=\"3\"/>    </feDiffuseLighting></filter></defs>"
                                       "<rect width=\"10\" height=\"10\" filter=\"url(#f)\"/>"];
    IJSVGFilterPrimitive* primitive = root.children.firstObject.filter.primitives.firstObject;
    XCTAssertNotNil(primitive);
    XCTAssertEqualObjects(primitive.parameters[IJSVGAttributeLightingColor],
                          @"lime");
    XCTAssertEqualObjects(primitive.parameters[IJSVGAttributeSurfaceScale],
                          @"2");
    XCTAssertEqual(primitive.filterColorInterpolation, IJSVGColorInterpolationLinearRGB);
    IJSVGFilterPrimitive* light = (IJSVGFilterPrimitive*)primitive.children.firstObject;
    XCTAssertNotNil(light);
    XCTAssertEqualObjects(light.parameters[IJSVGAttributeZ], @"3");
}

- (void)multipleTransformsAndFilterLists:(NSString*)element
                               transform:(NSString*)transform
{
    NSString* definitions = @"<defs>    <path id=\"shape\" d=\"M-1-1 H1 V1 H-1 Z\"/>    <filter "
                             "id=\"offset\" filterUnits=\"userSpaceOnUse\" x=\"-10\" y=\"-10\" "
                             "width=\"40\" height=\"30\">        <feOffset dx=\"2\" dy=\"0\"/>    "
                             "</filter>    <filter id=\"color\" filterUnits=\"userSpaceOnUse\" x=\"-10\" "
                             "y=\"-10\" width=\"40\" height=\"30\">        <feColorMatrix "
                             "type=\"matrix\" values=\"0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 1 0\"/>    "
                             "</filter></defs>";
    NSString* attributes = [NSString stringWithFormat:@"transform=\"%@\" filter=\"url(#offset) "
                                                       "url(#color)\"",
                                                     transform];
    NSString* redElement = [self transformElement:element
                                            color:@"red"
                                       attributes:attributes];
    NSString* originalContent = [NSString stringWithFormat:@"%@\n%@",
                                                          definitions,
                                                          redElement];
    NSString* original = [self document:originalContent];
    // Offset uses local element coordinates before the transform list.
    NSString* greenElement = [self transformElement:element
                                              color:@"lime"
                                         attributes:@""];
    NSString* expectedContent = [NSString stringWithFormat:@"%@<g transform=\"%@\"><g "
                                                            "transform=\"translate(2 0)\">    %@</g></g>",
                                                          definitions,
                                                          transform,
                                                          greenElement];
    NSString* expected = [self document:expectedContent];
    for(NSInteger scale = 10; scale <= 20; scale += 10) {
        NSData* pixels = [self render:original
                                scale:scale];
        [self expectTransformPixels:pixels
                              match:[self render:expected
                                           scale:scale]
                              scale:scale];
        [self expectTransformExport:original
                             pixels:pixels
                              scale:scale];
    }
}

- (void)testMultipleTransformsAndFilterLists_1_rect_translate_8_3_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"rect"
                                 transform:@"translate(8 3) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_2_rect_translate_12_3_rotate_90_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"rect"
                                 transform:@"translate(12 3) rotate(90) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_3_rect_matrix_1_2_3_1_8_3_skewX_15_scale_1Case28
{
    [self multipleTransformsAndFilterLists:@"rect"
                                 transform:@"matrix(1 .2 .3 1 8 3) skewX(15) scale(1.2 .8)"];
}

- (void)testMultipleTransformsAndFilterLists_4_circle_translate_8_3_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"circle"
                                 transform:@"translate(8 3) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_5_circle_translate_12_3_rotate_90_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"circle"
                                 transform:@"translate(12 3) rotate(90) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_6_circle_matrix_1_2_3_1_8_3_skewX_15_scale_1Case28
{
    [self multipleTransformsAndFilterLists:@"circle"
                                 transform:@"matrix(1 .2 .3 1 8 3) skewX(15) scale(1.2 .8)"];
}

- (void)testMultipleTransformsAndFilterLists_7_ellipse_translate_8_3_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"ellipse"
                                 transform:@"translate(8 3) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_8_ellipse_translate_12_3_rotate_90_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"ellipse"
                                 transform:@"translate(12 3) rotate(90) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_9_ellipse_matrix_1_2_3_1_8_3_skewX_15_scale_1Case28
{
    [self multipleTransformsAndFilterLists:@"ellipse"
                                 transform:@"matrix(1 .2 .3 1 8 3) skewX(15) scale(1.2 .8)"];
}

- (void)testMultipleTransformsAndFilterLists_10_path_translate_8_3_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"path"
                                 transform:@"translate(8 3) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_11_path_translate_12_3_rotate_90_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"path"
                                 transform:@"translate(12 3) rotate(90) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_12_path_matrix_1_2_3_1_8_3_skewX_15_scale_1Case28
{
    [self multipleTransformsAndFilterLists:@"path"
                                 transform:@"matrix(1 .2 .3 1 8 3) skewX(15) scale(1.2 .8)"];
}

- (void)testMultipleTransformsAndFilterLists_13_polygon_translate_8_3_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"polygon"
                                 transform:@"translate(8 3) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_14_polygon_translate_12_3_rotate_90_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"polygon"
                                 transform:@"translate(12 3) rotate(90) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_15_polygon_matrix_1_2_3_1_8_3_skewX_15_scale_1Case28
{
    [self multipleTransformsAndFilterLists:@"polygon"
                                 transform:@"matrix(1 .2 .3 1 8 3) skewX(15) scale(1.2 .8)"];
}

- (void)testMultipleTransformsAndFilterLists_16_line_translate_8_3_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"line"
                                 transform:@"translate(8 3) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_17_line_translate_12_3_rotate_90_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"line"
                                 transform:@"translate(12 3) rotate(90) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_18_line_matrix_1_2_3_1_8_3_skewX_15_scale_1Case28
{
    [self multipleTransformsAndFilterLists:@"line"
                                 transform:@"matrix(1 .2 .3 1 8 3) skewX(15) scale(1.2 .8)"];
}

- (void)testMultipleTransformsAndFilterLists_19_polyline_translate_8_3_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"polyline"
                                 transform:@"translate(8 3) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_20_polyline_translate_12_3_rotate_90_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"polyline"
                                 transform:@"translate(12 3) rotate(90) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_21_polyline_matrix_1_2_3_1_8_3_skewX_15_scale_1Case28
{
    [self multipleTransformsAndFilterLists:@"polyline"
                                 transform:@"matrix(1 .2 .3 1 8 3) skewX(15) scale(1.2 .8)"];
}

- (void)testMultipleTransformsAndFilterLists_22_use_translate_8_3_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"use"
                                 transform:@"translate(8 3) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_23_use_translate_12_3_rotate_90_scale_1Case575
{
    [self multipleTransformsAndFilterLists:@"use"
                                 transform:@"translate(12 3) rotate(90) scale(1.5 .75)"];
}

- (void)testMultipleTransformsAndFilterLists_24_use_matrix_1_2_3_1_8_3_skewX_15_scale_1Case28
{
    [self multipleTransformsAndFilterLists:@"use"
                                 transform:@"matrix(1 .2 .3 1 8 3) skewX(15) scale(1.2 .8)"];
}

- (void)transformedElementsInsideFilteredGroups:(NSString*)element
{
    NSString* definitions = @"<defs>    <path id=\"shape\" d=\"M-1-1 H1 V1 H-1 Z\"/>    <filter "
                             "id=\"shadow\" filterUnits=\"userSpaceOnUse\" x=\"-10\" y=\"-10\" "
                             "width=\"40\" height=\"30\">        <feDropShadow dx=\"3\" dy=\"0\" "
                             "stdDeviation=\"0\" flood-color=\"cyan\"/>    </filter>    <filter "
                             "id=\"parent\" filterUnits=\"userSpaceOnUse\" x=\"-10\" y=\"-10\" "
                             "width=\"40\" height=\"30\">        <feOffset dx=\"2\" dy=\"1\"/>    "
                             "</filter></defs>";
    NSString* original = [self document:[NSString stringWithFormat:@"%@<g transform=\"translate(5 1) "
                                                                    "scale(1.2 .8)\" "
                                                                    "filter=\"url(#parent)\">    <g "
                                                                    "transform=\"translate(2 2) "
                                                                    "rotate(15)\">        %@    </g></g>",
                                                                   definitions,
                                                                   [self transformElement:element
                                                                                    color:@"red"
                                                                               attributes:@"transform=\"scale(1."
                                                                                           "5 .8)\" "
                                                                                           "filter=\"url(#shadow"
                                                                                           ")\""]]];
    // The parent offset moves both the source and the shadow of its child together.
    NSString* expected = [self document:[NSString stringWithFormat:@"%@<g transform=\"translate(5 1) "
                                                                    "scale(1.2 .8)\">    <g "
                                                                    "transform=\"translate(2 1)\">       "
                                                                    " <g transform=\"translate(2 2) "
                                                                    "rotate(15)\"><g "
                                                                    "transform=\"scale(1.5 .8)\">        "
                                                                    "    <g transform=\"translate(3 0)\">"
                                                                    "%@</g>            %@        </g></g>"
                                                                    "    </g></g>",
                                                                   definitions,
                                                                   [self transformElement:element
                                                                                    color:@"cyan"
                                                                               attributes:@""],
                                                                   [self transformElement:element
                                                                                    color:@"red"
                                                                               attributes:@""]]];
    NSData* pixels = [self render:original
                            scale:10];
    [self expectTransformPixels:pixels
                          match:[self render:expected
                                       scale:10]
                          scale:10];
    [self expectTransformExport:original
                         pixels:pixels
                          scale:10];
}

- (void)testTransformedElementsInsideFilteredGroupsCase1Rect
{
    [self transformedElementsInsideFilteredGroups:@"rect"];
}

- (void)testTransformedElementsInsideFilteredGroupsCase2Circle
{
    [self transformedElementsInsideFilteredGroups:@"circle"];
}

- (void)testTransformedElementsInsideFilteredGroupsCase3Ellipse
{
    [self transformedElementsInsideFilteredGroups:@"ellipse"];
}

- (void)testTransformedElementsInsideFilteredGroupsCase4Path
{
    [self transformedElementsInsideFilteredGroups:@"path"];
}

- (void)testTransformedElementsInsideFilteredGroupsCase5Polygon
{
    [self transformedElementsInsideFilteredGroups:@"polygon"];
}

- (void)testTransformedElementsInsideFilteredGroupsCase6Line
{
    [self transformedElementsInsideFilteredGroups:@"line"];
}

- (void)testTransformedElementsInsideFilteredGroupsCase7Polyline
{
    [self transformedElementsInsideFilteredGroups:@"polyline"];
}

- (void)testTransformedElementsInsideFilteredGroupsCase8Use
{
    [self transformedElementsInsideFilteredGroups:@"use"];
}

- (void)transformedFilterOrderChangesShadowColor:(BOOL)reverse
{
    NSString* filters = reverse ? @"url(#color) url(#shadow)" : @"url(#shadow) url(#color)";
    NSString* original = [self document:[NSString stringWithFormat:@"<defs>    <filter id=\"shadow\" "
                                                                    "filterUnits=\"userSpaceOnUse\" "
                                                                    "x=\"-10\" y=\"-10\" width=\"40\" "
                                                                    "height=\"30\">        <feDropShadow "
                                                                    "dx=\"3\" dy=\"0\" "
                                                                    "stdDeviation=\"0\" "
                                                                    "flood-color=\"red\"/>    </filter>  "
                                                                    "  <filter id=\"color\" "
                                                                    "filterUnits=\"userSpaceOnUse\" "
                                                                    "x=\"-10\" y=\"-10\" width=\"40\" "
                                                                    "height=\"30\">        "
                                                                    "<feColorMatrix type=\"matrix\" "
                                                                    "values=\"0 0 0 0 0 1 0 0 0 0 0 0 0 "
                                                                    "0 0 0 0 0 1 0\"/>    </filter>"
                                                                    "</defs><g transform=\"translate(6 "
                                                                    "1)\">    <rect x=\"0\" y=\"0\" "
                                                                    "width=\"2\" height=\"2\" "
                                                                    "fill=\"red\"        "
                                                                    "transform=\"translate(2 1) scale(2 "
                                                                    "1)\" filter=\"%@\"/></g>",
                                                                   filters]];
    NSData* pixels = [self render:original
                            scale:10];
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(pixels, 100, 30, 10),
                                         0, 255, 0, 255));
    XCTAssertTrue(IJSVGFilterPixelEquals(IJSVGFilterPixel(pixels, 160, 30, 10),
                                         reverse ? 255 : 0, reverse ? 0 : 255,
                                         0, 255));
    XCTAssertTrue(IJSVGFilterPixel(pixels, 130, 30, 10)[3] == 0);
    [self expectTransformExport:original
                         pixels:pixels
                          scale:10];
}

- (void)testTransformedFilterOrderChangesShadowColorCase1False
{
    [self transformedFilterOrderChangesShadowColor:NO];
}

- (void)testTransformedFilterOrderChangesShadowColorCase2True
{
    [self transformedFilterOrderChangesShadowColor:YES];
}

- (void)largeSamplingFiltersPreserveImageAndRowBoundaries:(NSString*)effect
{
    NSString* content = @"<rect x=\"1\" y=\"1\" width=\"9\" height=\"3\" fill=\"#804020\" "
                         "opacity=\".6\"/><circle cx=\"17\" cy=\"6\" r=\"3\" fill=\"#2080c0\" "
                         "opacity=\".8\"/>";
    NSString* primitive = [effect isEqual:@"displacement"] ? @"<feFlood flood-color=\"white\" "
                                                              "result=\"map\"/><feDisplacementMap "
                                                              "in=\"SourceGraphic\" in2=\"map\" "
                                                              "scale=\"2\"/>" : @"<feConvolveMatrix "
                                                                                 "order=\"1\" "
                                                                                 "kernelMatrix=\"1\" "
                                                                                 "kernelUnitLength=\".07"
                                                                                 "5 .125\" "
                                                                                 "preserveAlpha=\"true\""
                                                                                 "/>";
    NSString* reference = [effect isEqual:@"displacement"] ? @"<feOffset dx=\"-1\" dy=\"-1\"/>" : @"<feOffset/>";
    NSData* actual = [self render:[self filtered:primitive
                                         content:content]
                            scale:20];
    NSData* expected = [self render:[self filtered:reference
                                           content:content]
                              scale:20];
    double maximumError = IJSVGFilterMaximumError(actual, expected);
    XCTAssertTrue(maximumError <= 2);
}

- (void)testLargeSamplingFiltersPreserveImageAndRowBoundariesCase1Displacement
{
    [self largeSamplingFiltersPreserveImageAndRowBoundaries:@"displacement"];
}

- (void)testLargeSamplingFiltersPreserveImageAndRowBoundariesCase2Convolution
{
    [self largeSamplingFiltersPreserveImageAndRowBoundaries:@"convolution"];
}

- (void)largeArithmeticAndTransferMatchEquations:(BOOL)transfer
{
    NSString* primitive = transfer ? @"<feFlood flood-color=\"#4080c0\" flood-opacity=\".5\"/>"
                                      "<feComponentTransfer>    <feFuncR type=\"gamma\" exponent=\"1.3\" "
                                      "amplitude=\".8\" offset=\".1\"/>    <feFuncG type=\"gamma\" "
                                      "exponent=\".7\"/>    <feFuncB type=\"gamma\" exponent=\"-.5\" "
                                      "amplitude=\".4\"/>    <feFuncA type=\"gamma\" exponent=\"1.7\"/>"
                                      "</feComponentTransfer>" : @"<feFlood flood-color=\"#804020\" "
                                                                  "flood-opacity=\".5\" result=\"a\"/>"
                                                                  "<feFlood flood-color=\"#2080c0\" "
                                                                  "flood-opacity=\".75\" result=\"b\"/>"
                                                                  "<feComposite in=\"a\" in2=\"b\" "
                                                                  "operator=\"arithmetic\" k1=\".4\" "
                                                                  "k2=\"-.3\" k3=\".8\" k4=\".07\"/>";
    double expected[4];
    if(transfer) {
        double alpha = pow(0.5, 1.7);
        double values[4] = {0.8 * pow(64.0 / 255, 1.3) + 0.1, pow(128.0 / 255,
                                                                  0.7),
            0.4 * pow(192.0 / 255, -0.5), 1};
        for(int channel = 0; channel < 4; channel++) {
            expected[channel] = MIN(1, values[channel]) * alpha * 255;
        }
    } else {
        double a[4] = {128.0 / 255 * 0.5, 64.0 / 255 * 0.5, 32.0 / 255 * 0.5, 0.5};
        double b[4] = {32.0 / 255 * 0.75, 128.0 / 255 * 0.75, 192.0 / 255 * 0.75, 0.75};
        double values[4];
        for(int channel = 0; channel < 4; channel++) {
            values[channel] = MIN(1,
                                  MAX(0,
                                      0.4 * a[channel] * b[channel] - 0.3 * a[channel] + 0.8 * b[channel] + 0.07));
        }
        for(int channel = 0; channel < 4; channel++) {
            expected[channel] = MIN(values[channel], values[3]) * 255;
        }
    }
    NSData* bytes = [self render:[self filtered:primitive]
                           scale:20];
    const uint8_t* pixels = bytes.bytes;
    double maximumError = 0;
    for(NSUInteger index = 0; index < bytes.length; index++) {
        maximumError = MAX(maximumError,
                           fabs(pixels[index] - expected[index % 4]));
    }
    XCTAssertLessThanOrEqual(maximumError, 2);
}

- (void)testLargeArithmeticAndTransferMatchEquationsCase1False
{
    [self largeArithmeticAndTransferMatchEquations:NO];
}

- (void)testLargeArithmeticAndTransferMatchEquationsCase2True
{
    [self largeArithmeticAndTransferMatchEquations:YES];
}

- (void)testChainedCPUFiltersPreserveVerticalOrientationAndColorSpace
{
    NSString* content = @"<rect x=\"2\" y=\"1\" width=\"6\" height=\"3\" fill=\"#804020\" "
                         "opacity=\".5\"/><rect x=\"10\" y=\"6\" width=\"7\" height=\"3\" "
                         "fill=\"#2080c0\" opacity=\".75\"/>";
    NSString* identity = @"<feConvolveMatrix order=\"1\" kernelMatrix=\"1\" kernelUnitLength=\".075 "
                          ".125\" preserveAlpha=\"true\"/>";
    NSData* actual = [self render:[self filtered:[NSString stringWithFormat:@"<feConvolveMatrix "
                                                                             "order=\"1\" "
                                                                             "kernelMatrix=\"1\" "
                                                                             "kernelUnitLength=\".075 "
                                                                             ".125\"    "
                                                                             "preserveAlpha=\"true\" "
                                                                             "color-interpolation-filter"
                                                                             "s=\"linearRGB\"/>"
                                                                             "%@<feConvolveMatrix "
                                                                             "order=\"1\" "
                                                                             "kernelMatrix=\"1\" "
                                                                             "kernelUnitLength=\".075 "
                                                                             ".125\"    "
                                                                             "preserveAlpha=\"true\" "
                                                                             "color-interpolation-filter"
                                                                             "s=\"linearRGB\"/>",
                                                                            identity]
                                         content:content]
                            scale:20];
    NSData* expected = [self render:[self filtered:@"<feOffset/>"
                                           content:content]
                              scale:20];
    XCTAssertLessThanOrEqual(IJSVGFilterMaximumError(actual, expected), 2);
}

- (void)fractionalSamplingMatchesBilinearReference:(NSString*)mode
{
    NSString* content = @"<rect x=\"1\" y=\"0\" width=\"9\" height=\"5\" fill=\"#804020\" "
                         "opacity=\".6\"/><rect x=\"16\" y=\"6\" width=\"8\" height=\"4\" "
                         "fill=\"#2080c0\" opacity=\".8\"/>";
    NSData* source = [self render:[self document:content]
                            scale:1];
    BOOL displacement = [mode isEqual:@"displacement"];
    NSString* primitive = displacement ? @"<feFlood flood-color=\"white\" flood-opacity=\".25\" "
                                          "result=\"map\"/><feDisplacementMap in=\"clipped\" in2=\"map\" "
                                          "scale=\"3\"/>" : [NSString stringWithFormat:@"<feConvolveMatrix "
                                                                                        "in=\"clipped\" "
                                                                                        "order=\"1 3\" "
                                                                                        "kernelMatrix=\"1 0 "
                                                                                        "0\"    targetY=\"1\" "
                                                                                        "kernelUnitLength=\"."
                                                                                        "75 1.25\" "
                                                                                        "edgeMode=\"%@\"/>",
                                                                                       mode];
    NSData* actual = [self render:[self filtered:[NSString stringWithFormat:@"<feOffset "
                                                                             "in=\"SourceGraphic\" "
                                                                             "x=\"2\" y=\"1\" "
                                                                             "width=\"20\" height=\"8\" "
                                                                             "result=\"clipped\"/>%@",
                                                                            primitive]
                                         content:content]
                            scale:1];
    double (^sample)(int, int, int) = ^double(int x, int y, int channel) {
        if([mode isEqual:@"duplicate"]) {
            x = MIN(21, MAX(2, x));
            y = MIN(8, MAX(1, y));
        } else if([mode isEqual:@"wrap"]) {
            x = 2 + ((x - 2) % 20 + 20) % 20;
            y = 1 + ((y - 1) % 8 + 8) % 8;
        }
        if(x < 2 || x >= 22 || y < 1 || y >= 9) {
            return 0;
        }
        return IJSVGFilterPixel(source, x, y, 1)[channel];
    };
    double maximumError = 0;
    for(int y = 0; y < 10; y++) {
        for(int x = 0; x < 30; x++) {
            double px = x + (displacement ? -0.75 : 0);
            double py = y + (displacement ? -0.75 : 1.25);
            int ix = floor(px), iy = floor(py);
            double fx = px - ix, fy = py - iy;
            const uint8_t* value = IJSVGFilterPixel(actual, x, y, 1);
            for(int channel = 0; channel < 4; channel++) {
                double expected = 0;
                if(displacement || (x >= 2 && x < 22 && y >= 1 && y < 9)) {
                    expected = sample(ix, iy, channel) * (1 - fx) * (1 - fy)
                        + sample(ix + 1, iy, channel) * fx * (1 - fy)
                        + sample(ix, iy + 1, channel) * (1 - fx) * fy
                        + sample(ix + 1, iy + 1, channel) * fx * fy;
                }
                maximumError = MAX(maximumError,
                                   fabs(value[channel] - expected));
            }
        }
    }
    XCTAssertLessThanOrEqual(maximumError, 2);
}

- (void)testFractionalSamplingMatchesBilinearReferenceCase1Displacement
{
    [self fractionalSamplingMatchesBilinearReference:@"displacement"];
}

- (void)testFractionalSamplingMatchesBilinearReferenceCase2None
{
    [self fractionalSamplingMatchesBilinearReference:@"none"];
}

- (void)testFractionalSamplingMatchesBilinearReferenceCase3Duplicate
{
    [self fractionalSamplingMatchesBilinearReference:@"duplicate"];
}

- (void)testFractionalSamplingMatchesBilinearReferenceCase4Wrap
{
    [self fractionalSamplingMatchesBilinearReference:@"wrap"];
}

- (void)testClippedTurbulenceMatchesFullRegionNoise
{
    NSData* full = [self render:[self filtered:@"<feTurbulence baseFrequency=\".17 .31\" seed=\"7\" "
                                                "numOctaves=\"4\" type=\"fractalNoise\"/><feOffset "
                                                "x=\"3.25\" y=\"1.5\" width=\"20.5\" height=\"7\"/>"]
                          scale:20];
    NSData* clipped = [self render:[self filtered:@"<feTurbulence baseFrequency=\".17 .31\" seed=\"7\" "
                                                   "numOctaves=\"4\" type=\"fractalNoise\"    x=\"3.25\" "
                                                   "y=\"1.5\" width=\"20.5\" height=\"7\"/>"]
                             scale:20];
    XCTAssertLessThanOrEqual(IJSVGFilterMaximumError(full, clipped), 1);
}

- (void)clippedCPUFilterMatchesClippedFullOutput:(NSString*)effect
{
    NSString* content = @"<rect x=\"1\" y=\"1\" width=\"12\" height=\"5\" fill=\"#804020\" "
                         "opacity=\".6\"/><circle cx=\"17\" cy=\"6\" r=\"3\" fill=\"#2080c0\" "
                         "opacity=\".8\"/>";
    NSString* bounds = @"x=\"3.25\" y=\"1.5\" width=\"20.5\" height=\"7\"";
    NSString* (^primitive)(NSString*) = ^NSString*(NSString* attributes) {
        if([effect isEqual:@"lighting"]) {
            return [NSString stringWithFormat:@"<feDiffuseLighting surfaceScale=\"2\" "
                                               "lighting-color=\"#804020\" %@>    <fePointLight x=\"10\" "
                                               "y=\"5\" z=\"20\"/></feDiffuseLighting>",
                                              attributes];
        }
        return [NSString stringWithFormat:@"<feFlood flood-color=\"white\" flood-opacity=\".25\" "
                                           "result=\"map\"/><feDisplacementMap in=\"SourceGraphic\" "
                                           "in2=\"map\" scale=\"3\" %@/>",
                                          attributes];
    };
    NSString* fullPrimitives = [primitive(@"") stringByAppendingFormat:@"<feOffset %@/>",
                                                                       bounds];
    NSData* full = [self render:[self filtered:fullPrimitives
                                       content:content]
                          scale:20];
    NSData* clipped = [self render:[self filtered:primitive(bounds)
                                          content:content]
                             scale:20];
    XCTAssertLessThanOrEqual(IJSVGFilterMaximumError(full, clipped), 1);
}

- (void)testClippedCPUFilterMatchesClippedFullOutputCase1Lighting
{
    [self clippedCPUFilterMatchesClippedFullOutput:@"lighting"];
}

- (void)testClippedCPUFilterMatchesClippedFullOutputCase2Displacement
{
    [self clippedCPUFilterMatchesClippedFullOutput:@"displacement"];
}

- (void)longMergeKeepsPrimitiveColorSpace:(NSString*)colorSpace
{
    NSArray<NSString*>* colors = @[@"#804020", @"#2080c0", @"#40c080"];
    NSMutableString* primitives = [NSMutableString string];
    for(NSUInteger index = 0; index < colors.count; index++) {
        [primitives appendFormat:@"<feFlood flood-color=\"%@\" flood-opacity=\".25\" "
                                  "result=\"paint%lu\"/>",
                                 colors[index],
                                 (unsigned long)index];
    }
    [primitives appendString:@"<feMerge>"];
    for(int index = 0; index < 12; index++) {
        [primitives appendFormat:@"<feMergeNode in=\"paint%d\"/>",
                                 index % 3];
    }
    [primitives appendString:@"</feMerge>"];
    NSData* bytes = [self render:[self filtered:primitives
                                     attributes:[NSString stringWithFormat:@"color-interpolation-filters"
                                                                            "=\"%@\"",
                                                                           colorSpace]
                                        content:@"<rect x=\"2\" y=\"2\" width=\"4\" height=\"4\" "
                                                 "fill=\"red\"/>"]
                           scale:10];
    const double values[3][3] = {{128, 64, 32}, {32, 128, 192}, {64, 192, 128}};
    double result[3] = {0}, alpha = 0;
    BOOL srgb = [colorSpace isEqual:@"sRGB"];
    for(int index = 0; index < 12; index++) {
        alpha = 0.25 + alpha * 0.75;
        for(int channel = 0; channel < 3; channel++) {
            double encoded = values[index % 3][channel] / 255;
            double value = srgb ? encoded : (encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055,
                                                                                        2.4));
            result[channel] = value * 0.25 + result[channel] * 0.75;
        }
    }
    const uint8_t* actual = IJSVGFilterPixel(bytes, 35, 35, 10);
    for(int channel = 0; channel < 3; channel++) {
        double straight = result[channel] / alpha;
        double encoded = srgb ? straight : (straight <= 0.0031308 ? straight * 12.92 : 1.055 * pow(straight,
                                                                                                   1 / 2.4) - 0.055);
        XCTAssertEqualWithAccuracy(actual[channel], encoded * alpha * 255, 2);
    }
    XCTAssertEqualWithAccuracy(actual[3], alpha * 255, 1);
}

- (void)testLongMergeKeepsPrimitiveColorSpaceCase1SRGB
{
    [self longMergeKeepsPrimitiveColorSpace:@"sRGB"];
}

- (void)testLongMergeKeepsPrimitiveColorSpaceCase2LinearRGB
{
    [self longMergeKeepsPrimitiveColorSpace:@"linearRGB"];
}

// Renders the same SVG instance so tests exercise cached layer invalidation.
- (NSData*)pixelsForFilterToggleSVG:(IJSVG*)svg
{
    svg.renderingBackingScaleHelper = ^CGFloat { return 1; };
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, 30, 10, 8, 120, space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) {
        return nil;
    }
    [svg drawInRect:CGRectMake(0, 0, 30, 10)
            context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context)
                                    length:1200];
    CGContextRelease(context);
    return pixels;
}

// Disabling and restoring filters rebuilds already rendered paints.
- (void)testFiltersCanBeToggledAfterRendering
{
    NSString* rectangle = @"<rect x=\"2\" y=\"2\" width=\"4\" height=\"4\" fill=\"red\"/>";
    IJSVG* svg = IJSVGTestSVGObject([self filtered:@"<feOffset dx=\"6\"/>"
                                           content:rectangle]);
    XCTAssertTrue(svg.renderingOptions.filtersEnabled);
    NSData* filtered = [self pixelsForFilterToggleSVG:svg];
    IJSVGRootNode* originalNode = svg.rootNode;
    IJSVGRenderingOptions* options = svg.renderingOptions;
    options.filtersEnabled = YES;
    svg.renderingOptions = options;
    XCTAssertEqualObjects([self pixelsForFilterToggleSVG:svg], filtered);
    options.filtersEnabled = NO;
    svg.renderingOptions = options;
    NSData* plain = [self pixelsForFilterToggleSVG:svg];
    XCTAssertEqual(svg.rootNode, originalNode);
    XCTAssertEqualObjects(plain,
                          [self render:[self document:rectangle]
                                 scale:1]);
    XCTAssertNotEqualObjects(filtered, plain);
    options.filtersEnabled = YES;
    svg.renderingOptions = options;
    XCTAssertEqualObjects([self pixelsForFilterToggleSVG:svg], filtered);
}

// Bypasses root and nested filters while preserving opacity and clipping.
- (void)testFiltersCanBeDisabledBeforeRendering
{
    NSString* body = @"<defs><filter id=\"f\"><feOffset dx=\"6\"/></filter><clipPath id=\"clip\"><rect "
                      "x=\"2\" y=\"2\" width=\"2\" height=\"4\"/></clipPath></defs><g filter=\"url(#f)\" "
                      "opacity=\".5\" clip-path=\"url(#clip)\"><rect filter=\"url(#f)\" x=\"2\" y=\"2\" "
                      "width=\"4\" height=\"4\" fill=\"red\"/></g>";
    NSString* document = [[self document:body] stringByReplacingOccurrencesOfString:@"viewBox=\"0 0 30 "
                                                                                     "10\""
                                                                         withString:@"viewBox=\"0 0 30 "
                                                                                     "10\" "
                                                                                     "filter=\"url(#f)\""];
    IJSVG* svg = IJSVGTestSVGObject(document);
    IJSVGRenderingOptions* options = svg.renderingOptions;
    options.filtersEnabled = NO;
    svg.renderingOptions = options;
    NSData* actual = [self pixelsForFilterToggleSVG:svg];
    NSString* reference = [document stringByReplacingOccurrencesOfString:@" filter=\"url(#f)\""
                                                              withString:@""];
    XCTAssertEqualObjects(actual, [self render:reference
                                         scale:1]);
    IJSVG* independent = IJSVGTestSVGObject(document);
    XCTAssertTrue(independent.renderingOptions.filtersEnabled);
}

// Preserves defaults and keeps option snapshots independent across SVG instances.
- (void)testRenderingOptionsAreIndependentSnapshots
{
    IJSVGRenderingOptions* options = [[IJSVGRenderingOptions alloc] init];
    XCTAssertTrue(options.filtersEnabled);
    XCTAssertTrue(options.ignoreIntrinsicSize);
    XCTAssertEqual(options.renderQuality, kIJSVGRenderQualityFullResolution);
    IJSVG* first = IJSVGTestSVGObject([self document:@"<rect width=\"4\" height=\"4\"/>"]);
    IJSVG* second = IJSVGTestSVGObject([self document:@"<rect width=\"4\" height=\"4\"/>"]);
    options.filtersEnabled = NO;
    options.ignoreIntrinsicSize = NO;
    options.renderQuality = kIJSVGRenderQualityOptimized;
    first.renderingOptions = options;
    second.renderingOptions = options;
    options.filtersEnabled = YES;
    options.ignoreIntrinsicSize = YES;
    options.renderQuality = kIJSVGRenderQualityLow;
    XCTAssertFalse(first.renderingOptions.filtersEnabled);
    XCTAssertFalse(first.renderingOptions.ignoreIntrinsicSize);
    XCTAssertEqual(first.renderingOptions.renderQuality,
                   kIJSVGRenderQualityOptimized);

    IJSVGRenderingOptions* snapshot = first.renderingOptions;
    snapshot.filtersEnabled = YES;
    snapshot.ignoreIntrinsicSize = YES;
    snapshot.renderQuality = kIJSVGRenderQualityLow;
    XCTAssertFalse(first.renderingOptions.filtersEnabled);
    XCTAssertFalse(first.renderingOptions.ignoreIntrinsicSize);
    XCTAssertEqual(first.renderingOptions.renderQuality,
                   kIJSVGRenderQualityOptimized);
    first.renderingOptions = snapshot;
    XCTAssertTrue(first.renderingOptions.filtersEnabled);
    XCTAssertTrue(first.renderingOptions.ignoreIntrinsicSize);
    XCTAssertEqual(first.renderingOptions.renderQuality,
                   kIJSVGRenderQualityLow);
    XCTAssertFalse(second.renderingOptions.filtersEnabled);
    XCTAssertFalse(second.renderingOptions.ignoreIntrinsicSize);
    XCTAssertEqual(second.renderingOptions.renderQuality,
                   kIJSVGRenderQualityOptimized);
}

// Changing intrinsic sizing preserves the existing node graph.
- (void)testIntrinsicSizeOptionsPreserveNodes
{
    IJSVG* svg = IJSVGTestSVGObject([self document:@"<rect width=\"4\" height=\"4\"/>"]);
    IJSVGRootNode* node = svg.rootNode;
    IJSVGRenderingOptions* options = svg.renderingOptions;
    options.ignoreIntrinsicSize = NO;
    svg.renderingOptions = options;
    XCTAssertFalse(svg.renderingOptions.ignoreIntrinsicSize);
    XCTAssertEqual(svg.rootNode, node);
}

@end
