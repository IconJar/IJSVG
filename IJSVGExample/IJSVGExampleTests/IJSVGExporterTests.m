//
//  IJSVGExporterTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTestHelpers.h>

@interface IJSVGExporterTests: XCTestCase
@end

@implementation IJSVGExporterTests

- (void)testExporterPreservesSVGBackgroundColor
{
    IJSVG* svg = IJSVGTestSVGObject(@"<svg xmlns='http://www.w3.org/2000/svg' width='8' height='8' "
                                    "style='background-color:#bbffff80'><rect width='2' height='2'/></svg>");
    NSString* xml = [svg SVGStringWithSize:CGSizeMake(8, 8)
                                  options:IJSVGExporterOptionRemoveComments];
    IJSVG* restored = IJSVGTestSVGObject(xml);
    NSColor* expected = [svg.rootNode.backgroundColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    NSColor* actual = [restored.rootNode.backgroundColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    XCTAssertNotNil(actual);
    XCTAssertEqualWithAccuracy(actual.redComponent, expected.redComponent, .005);
    XCTAssertEqualWithAccuracy(actual.greenComponent, expected.greenComponent, .005);
    XCTAssertEqualWithAccuracy(actual.blueComponent, expected.blueComponent, .005);
    XCTAssertEqualWithAccuracy(actual.alphaComponent, expected.alphaComponent, .005);
    IJSVGRootNode* copy = svg.rootNode.copy;
    XCTAssertEqualObjects(copy.backgroundColor, svg.rootNode.backgroundColor);
}


- (void)testExporterIncludesRootDimensionsAndViewBoxForRequestedSize
{
    IJSVG* svg = IJSVGTestSVGObject(IJSVGTestSVG(@"<rect width=\"8\" height=\"8\" fill=\"#ff0000\"/>"));
    NSString* exportedString = [svg SVGStringWithSize:CGSizeMake(16.f, 12.f)
                                              options:IJSVGExporterOptionRemoveComments];
    NSXMLDocument* document = IJSVGTestXMLDocument(exportedString);
    NSXMLElement* rootElement = document.rootElement;

    XCTAssertEqualObjects([[rootElement attributeForName:@"width"] stringValue],
                          @"16");
    XCTAssertEqualObjects([[rootElement attributeForName:@"height"] stringValue],
                          @"12");
    XCTAssertEqualObjects([[rootElement attributeForName:@"viewBox"] stringValue],
                          @"0 0 8 8");
}

- (void)testExporterCanRemoveXMLDeclarationCommentsAndDimensions
{
    IJSVG* svg = IJSVGTestSVGObject(IJSVGTestSVG(@"<rect width=\"8\" height=\"8\" fill=\"#ff0000\"/>"));
    IJSVGExporterOptions options = IJSVGExporterOptionRemoveXMLDeclaration |
        IJSVGExporterOptionRemoveComments |
        IJSVGExporterOptionRemoveWidthHeightAttributes;
    NSString* exportedString = [svg SVGStringWithSize:CGSizeMake(8.f, 8.f)
                                              options:options];
    NSXMLDocument* document = IJSVGTestXMLDocument(exportedString);

    XCTAssertFalse([exportedString hasPrefix:@"<?xml"]);
    XCTAssertFalse([exportedString containsString:@"Generator:"]);
    XCTAssertNil([document.rootElement attributeForName:@"width"]);
    XCTAssertNil([document.rootElement attributeForName:@"height"]);
    XCTAssertNotNil([document.rootElement attributeForName:@"viewBox"]);
}

- (void)testExporterCompressOutputRemovesPrettyPrintedWhitespace
{
    IJSVG* svg = IJSVGTestSVGObject(IJSVGTestSVG(@"<rect width=\"8\" height=\"8\" fill=\"#ff0000\"/>"));
    IJSVGExporterOptions options = IJSVGExporterOptionRemoveXMLDeclaration |
        IJSVGExporterOptionRemoveComments;
    NSString* prettyString = [svg SVGStringWithSize:CGSizeMake(8.f, 8.f)
                                            options:options];
    NSString* compressedString = [svg SVGStringWithSize:CGSizeMake(8.f, 8.f)
                                                options:options | IJSVGExporterOptionCompressOutput];

    XCTAssertTrue([prettyString containsString:@"\n"]);
    XCTAssertFalse([compressedString containsString:@"\n"]);
    XCTAssertLessThan(compressedString.length, prettyString.length);
}

- (void)testExporterRemoveHiddenElementsDropsDisplayNoneNodes
{
    NSString* body = @"<rect width=\"8\" height=\"8\" fill=\"#ffffff\"/><rect width=\"8\" height=\"8\" "
                      "fill=\"#ff0000\" display=\"none\"/>";
    IJSVG* svg = IJSVGTestSVGObject(IJSVGTestSVG(body));
    IJSVGExporterOptions options = IJSVGExporterOptionRemoveXMLDeclaration |
        IJSVGExporterOptionRemoveComments |
        IJSVGExporterOptionRemoveHiddenElements;
    NSString* exportedString = [svg SVGStringWithSize:CGSizeMake(8.f, 8.f)
                                              options:options];
    NSXMLDocument* document = IJSVGTestXMLDocument(exportedString);
    NSArray<NSXMLNode*>* rects = [document nodesForXPath:@"//*[local-name()='rect']"
                                                   error:nil];

    XCTAssertEqual(rects.count, 1);
    XCTAssertFalse([exportedString containsString:@"display=\"none\""]);
}

- (void)testExporterSVGDataAndSVGObjectRoundTrip
{
    IJSVG* svg = IJSVGTestSVGObject(IJSVGTestSVG(@"<rect width=\"8\" height=\"8\" fill=\"#ff0000\"/>"));
    IJSVGExporterOptions options = IJSVGExporterOptionRemoveXMLDeclaration |
        IJSVGExporterOptionRemoveComments |
        IJSVGExporterOptionCompressOutput;
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg
                                                            size:CGSizeMake(8.f,
                                                                            8.f)
                                                         options:options];
    NSData* data = exporter.SVGData;
    NSError* error = nil;
    IJSVG* exportedSVG = [exporter SVG:&error];

    XCTAssertNotNil(data);
    XCTAssertGreaterThan(data.length, 0);
    XCTAssertNil(error);
    XCTAssertNotNil(exportedSVG);
    XCTAssertTrue([IJSVGParser isDataSVG:data]);
}

- (void)testExporterFloatingPointOptionsRoundPathData
{
    NSString* body = @"<path d=\"M0.1234 0.5678 L7.8765 7.4321\" stroke=\"#000000\" fill=\"none\"/>";
    IJSVG* svg = IJSVGTestSVGObject(IJSVGTestSVG(body));
    IJSVGExporterOptions options = IJSVGExporterOptionRemoveXMLDeclaration |
        IJSVGExporterOptionRemoveComments |
        IJSVGExporterOptionCleanupPaths;
    NSString* exportedString = [svg SVGStringWithSize:CGSizeMake(8.f, 8.f)
                                              options:options
                                 floatingPointOptions:IJSVGFloatingPointOptionsMake(YES,
                                                                                    1)];

    XCTAssertTrue([exportedString containsString:@".1"] || [exportedString containsString:@"0.1"]);
    XCTAssertFalse([exportedString containsString:@"0.1234"]);
    XCTAssertFalse([exportedString containsString:@"7.8765"]);
}

- (void)testExporterRoundTripsIntoRenderableSVG
{
    NSString* body = @"<defs><linearGradient id=\"fade\" x1=\"0\" y1=\"0\" x2=\"8\" y2=\"0\" "
                      "gradientUnits=\"userSpaceOnUse\"><stop offset=\"0\" stop-color=\"#ff0000\"/><stop "
                      "offset=\"1\" stop-color=\"#0000ff\"/></linearGradient></defs><rect width=\"8\" "
                      "height=\"8\" fill=\"url(#fade)\"/>";
    IJSVG* svg = IJSVGTestSVGObject(IJSVGTestSVG(body));
    NSString* exportedString = [svg SVGStringWithSize:CGSizeMake(8.f, 8.f)
                                              options:IJSVGExporterOptionAll];
    IJSVG* exportedSVG = IJSVGTestSVGObject(exportedString);
    NSError* error = nil;
    CGImageRef image = [exportedSVG newCGImageRefWithSize:CGSizeMake(8.f, 8.f)
                                                  flipped:NO
                                                    error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil((__bridge id)image);
    CGImageRelease(image);
}


// Reduced sticker backing, nested shadow, reflected alpha mask and paper gradient.
- (NSString*)stickerCurlFixture
{
    return
        @"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 120 100\">"
        "<defs>"
        " <filter id=\"paper\" filterUnits=\"userSpaceOnUse\" primitiveUnits=\"userSpaceOnUse\" x=\"5\" y=\"5\" width=\"110\" height=\"90\" color-interpolation-filters=\"sRGB\">"
        "  <feGaussianBlur in=\"SourceAlpha\" stdDeviation=\"2\" result=\"blur\" x=\"5\" y=\"5\" width=\"110\" height=\"90\"/>"
        "  <feComponentTransfer in=\"blur\" result=\"outline\" x=\"5\" y=\"5\" width=\"110\" height=\"90\"><feFuncA type=\"linear\" slope=\"20\" intercept=\"-1\"/></feComponentTransfer>"
        "  <feFlood flood-color=\"white\" result=\"white\"/>"
        "  <feComposite in=\"white\" in2=\"outline\" operator=\"in\" result=\"backing\"/>"
        "  <feMerge><feMergeNode in=\"backing\"/><feMergeNode in=\"SourceGraphic\"/></feMerge>"
        " </filter>"
        " <filter id=\"shadow\" filterUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"120\" height=\"100\"><feDropShadow stdDeviation=\"1\" dx=\"0\" dy=\"2\" flood-opacity=\".4\"/></filter>"
        " <filter id=\"alpha\" filterUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"120\" height=\"100\"><feColorMatrix values=\"0 0 0 0 1 0 0 0 0 1 0 0 0 0 1 0 0 0 1 0\"/></filter>"
        " <clipPath id=\"canvas\"><path d=\"M10 10H110V90H10Z\"/></clipPath>"
        " <clipPath id=\"retained\"><path d=\"M0 0H120V60L80 100H0Z\"/></clipPath>"
        " <linearGradient id=\"shade\" gradientUnits=\"userSpaceOnUse\" x1=\"110\" y1=\"60\" x2=\"85\" y2=\"85\"><stop stop-color=\"#aaa\"/><stop offset=\"1\" stop-color=\"white\"/></linearGradient>"
        " <mask id=\"flap\" maskUnits=\"userSpaceOnUse\" maskContentUnits=\"userSpaceOnUse\" x=\"80\" y=\"60\" width=\"30\" height=\"30\">"
        "  <g filter=\"url(#alpha)\"><g transform=\"matrix(0 -1 -1 0 170 170)\"><g filter=\"url(#paper)\"><g clip-path=\"url(#canvas)\"><path d=\"M10 10H110V90H10Z\" fill=\"#378cde\"/></g></g></g></g>"
        " </mask>"
        "</defs>"
        "<g transform=\"translate(4 3) scale(.92)\"><g filter=\"url(#shadow)\">"
        " <g clip-path=\"url(#retained)\"><g filter=\"url(#paper)\"><g clip-path=\"url(#canvas)\"><path d=\"M10 10H110V90H10Z\" fill=\"#378cde\"/><path d=\"M20 20H55V65H20Z\" fill=\"#f40\"/></g></g></g>"
        " <g filter=\"url(#shadow)\"><path d=\"M80 60H110L80 90Z\" fill=\"url(#shade)\" mask=\"url(#flap)\"/></g>"
        "</g></g>"
        "</svg>";
}

- (NSData*)exportPixelsForSVG:(IJSVG*)svg size:(NSUInteger)size
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, size, size, 8, size * 4, space,
                                                (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) return nil;
    CGContextTranslateCTM(context, 0, size);
    CGContextScaleCTM(context, 1, -1);
    [svg drawInRect:CGRectMake(0, 0, size, size) context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:size * size * 4];
    CGContextRelease(context);
    return pixels;
}

- (NSString*)assertRenderingOfXML:(NSString*)xml survivesExport:(IJSVGExporterOptions)options
{
    IJSVG* source = IJSVGTestSVGObject(xml);
    NSData* before = [self exportPixelsForSVG:source size:256];
    NSString* exported = [source SVGStringWithSize:CGSizeMake(256, 256) options:options];
    IJSVG* restored = IJSVGTestSVGObject(exported);
    NSData* after = [self exportPixelsForSVG:restored size:256];
    XCTAssertEqual(before.length, after.length);
    NSUInteger differences = 0;
    NSUInteger visiblePixels = 0;
    const uint8_t* expected = before.bytes;
    const uint8_t* actual = after.bytes;
    for(NSUInteger index = 0; index < MIN(before.length, after.length); index++) {
        differences += abs((int)expected[index] - actual[index]) > 1;
        if(index % 4 == 3 && expected[index] != 0) visiblePixels++;
    }
    XCTAssertGreaterThan(visiblePixels, 100u, @"The fixture must render visible artwork");
    XCTAssertEqual(differences, 0u, @"Export options %lu changed %lu channels", options, differences);
    XCTAssertFalse([exported containsString:@"data:image"], @"Effects must remain vector SVG");
    return exported;
}

- (void)testStickerCurlRenderingSurvivesUnoptimizedExport
{
    [self assertRenderingOfXML:self.stickerCurlFixture survivesExport:IJSVGExporterOptionNone];
}

- (void)testStickerCurlRenderingSurvivesCollapseGroups
{
    [self assertRenderingOfXML:self.stickerCurlFixture survivesExport:IJSVGExporterOptionCollapseGroups];
}

- (void)testStickerCurlRenderingSurvivesCollapseGradients
{
    [self assertRenderingOfXML:self.stickerCurlFixture survivesExport:IJSVGExporterOptionCollapseGradients];
}

- (void)testStickerCurlRenderingSurvivesAllOptimizations
{
    [self assertRenderingOfXML:self.stickerCurlFixture survivesExport:IJSVGExporterOptionAll];
}

- (void)testGroupCollapsePreservesRepeatedOpacityAndSiblingCompositing
{
    NSString* xml = @"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\">"
        "<g opacity=\".5\"><g opacity=\".5\"><path d=\"M5 5H65V65H5Z\" fill=\"red\"/></g></g>"
        "<g opacity=\".5\"><path d=\"M35 35H95V95H35Z\" fill=\"blue\"/></g>"
        "<g opacity=\".5\"><path d=\"M50 20H80V80H50Z\" fill=\"green\"/></g></svg>";
    [self assertRenderingOfXML:xml survivesExport:IJSVGExporterOptionCollapseGroups];
    [self assertRenderingOfXML:xml survivesExport:IJSVGExporterOptionAll];
}

- (void)testGradientCollapseSharesStopsWithoutInheritingGeometry
{
    NSString* stops = @"<stop stop-color=\"red\"/><stop offset=\"1\" stop-color=\"blue\"/>";
    NSString* xml = [NSString stringWithFormat:
        @"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\"><defs>"
        "<linearGradient id=\"first\" gradientUnits=\"userSpaceOnUse\" x2=\"40\" gradientTransform=\"translate(10 0)\">%@</linearGradient>"
        "<linearGradient id=\"second\">%@</linearGradient>"
        "<radialGradient id=\"third\">%@</radialGradient></defs>"
        "<path d=\"M0 0H100V30H0Z\" fill=\"url(#first)\"/>"
        "<path d=\"M0 35H100V65H0Z\" fill=\"url(#second)\"/>"
        "<path d=\"M0 70H100V100H0Z\" fill=\"url(#third)\"/></svg>", stops, stops, stops];
    for(NSNumber* option in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionCollapseGroups),
                              @(IJSVGExporterOptionCollapseGradients), @(IJSVGExporterOptionAll)]) {
        NSString* exported = [self assertRenderingOfXML:xml survivesExport:option.unsignedIntegerValue];
        if(option.unsignedIntegerValue & IJSVGExporterOptionCollapseGradients) {
            NSXMLDocument* document = IJSVGTestXMLDocument(exported);
            XCTAssertEqual([document nodesForXPath:@"//*[local-name()='stop']" error:nil].count, 2u);
        }
    }
}

- (void)testReflectionsAndSingularTransformsSurviveExport
{
    for(NSString* transform in @[@"matrix(0 -1 -1 0 100 100)",
                                 @"matrix(-0.0000000000000002 -1 -1 0.0000000000000002 100 100)",
                                 @"matrix(0 0 0 1 50 0)"]) {
        NSString* xml = [NSString stringWithFormat:
            @"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\">"
            "<path d=\"M0 0H100V100H0Z\" fill=\"white\"/>"
            "<g transform=\"%@\"><path d=\"M10 20H60L30 80Z\" fill=\"red\"/></g></svg>", transform];
        [self assertRenderingOfXML:xml survivesExport:IJSVGExporterOptionNone];
        [self assertRenderingOfXML:xml survivesExport:IJSVGExporterOptionAll];
    }
}

@end
