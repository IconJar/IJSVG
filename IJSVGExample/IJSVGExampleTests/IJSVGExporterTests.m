//
//  IJSVGExporterTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGTestHelpers.h"

@interface IJSVGExporterTests : XCTestCase
@end

@implementation IJSVGExporterTests

- (void)testExporterIncludesRootDimensionsAndViewBoxForRequestedSize
{
    IJSVG* svg = IJSVGTestSVGObject(IJSVGTestSVG(@"<rect width=\"8\" height=\"8\" fill=\"#ff0000\"/>"));
    NSString* exportedString = [svg SVGStringWithSize:CGSizeMake(16.f, 12.f)
                                              options:IJSVGExporterOptionRemoveComments];
    NSXMLDocument* document = IJSVGTestXMLDocument(exportedString);
    NSXMLElement* rootElement = document.rootElement;

    XCTAssertEqualObjects([[rootElement attributeForName:@"width"] stringValue], @"16");
    XCTAssertEqualObjects([[rootElement attributeForName:@"height"] stringValue], @"12");
    XCTAssertEqualObjects([[rootElement attributeForName:@"viewBox"] stringValue], @"0 0 8 8");
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
    NSString* body = @"<rect width=\"8\" height=\"8\" fill=\"#ffffff\"/>"
        @"<rect width=\"8\" height=\"8\" fill=\"#ff0000\" display=\"none\"/>";
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
                                                            size:CGSizeMake(8.f, 8.f)
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
                                 floatingPointOptions:IJSVGFloatingPointOptionsMake(YES, 1)];

    XCTAssertTrue([exportedString containsString:@".1"] || [exportedString containsString:@"0.1"]);
    XCTAssertFalse([exportedString containsString:@"0.1234"]);
    XCTAssertFalse([exportedString containsString:@"7.8765"]);
}

- (void)testExporterRoundTripsIntoRenderableSVG
{
    NSString* body = @"<defs><linearGradient id=\"fade\" x1=\"0\" y1=\"0\" x2=\"8\" y2=\"0\" gradientUnits=\"userSpaceOnUse\">"
        @"<stop offset=\"0\" stop-color=\"#ff0000\"/>"
        @"<stop offset=\"1\" stop-color=\"#0000ff\"/>"
        @"</linearGradient></defs>"
        @"<rect width=\"8\" height=\"8\" fill=\"url(#fade)\"/>";
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

@end
