//
//  IJSVGVisibilityTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 08/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <XCTest/XCTest.h>

@interface IJSVGVisibilityTests : XCTestCase
@end

@implementation IJSVGVisibilityTests

- (IJSVG*)svgWithBody:(NSString*)body viewBox:(NSString*)viewBox
{
    NSString* xml = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100' viewBox='%@'>%@</svg>",
        viewBox, body];
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml error:&error];
    XCTAssertNotNil(svg);
    XCTAssertNil(error);
    svg.renderingBackingScaleHelper = ^CGFloat { return 1.f; };
    return svg;
}

- (void)testCompoundBorderOutsideViewport
{
    // Exact border geometry from 77-essential-icons-camera.svg.
    IJSVG* svg = [self svgWithBody:
        @"<rect x='9' y='20' width='82' height='60'/>"
         "<g><g><path fill='#0000FF' d='M1364-650v1684H-420V-650H1364 M1372-658H-428v1700h1800V-658L1372-658z'/></g></g>"
        viewBox:@"0 0 100 100"];
    IJSVGRootNode* root = svg.rootNode;
    IJSVGGroup* border = (IJSVGGroup*)root.children[1];
    IJSVGGroup* borderGroup = (IJSVGGroup*)border.children[0];
    XCTAssertFalse([svg isNodeOutsideViewBox:root.children[0]]);
    XCTAssertTrue([svg isNodeOutsideViewBox:border]);
    XCTAssertTrue([svg isNodeOutsideViewBox:borderGroup.children[0]]);
    CGImageRef before = [svg newCGImageRefWithSize:CGSizeMake(100, 100) flipped:NO error:nil];
    [root removeChild:border];
    [svg fitArtworkToViewBox:YES];
    XCTAssertTrue(CGRectEqualToRect(svg.artworkBounds, CGRectMake(9, 20, 82, 60)));
    CGImageRef after = [svg newCGImageRefWithSize:CGSizeMake(100, 100) flipped:NO error:nil];
    XCTAssertNotEqual(before, NULL);
    XCTAssertNotEqual(after, NULL);
    if(before != NULL && after != NULL) {
        NSData* beforeData = CFBridgingRelease(CGDataProviderCopyData(CGImageGetDataProvider(before)));
        NSData* afterData = CFBridgingRelease(CGDataProviderCopyData(CGImageGetDataProvider(after)));
        XCTAssertEqualObjects(beforeData, afterData);
    }
    CGImageRelease(before);
    CGImageRelease(after);
}

- (void)testPaintedGeometry
{
    NSArray<NSArray*>* cases = @[
        @[@"<rect x='-50' y='-50' width='200' height='200' fill='none' stroke='blue' stroke-width='8'/>", @YES],
        @[@"<rect x='-50' y='-50' width='200' height='200'/>", @NO],
        @[@"<path fill-rule='evenodd' d='M-50-50h200v200h-200z M-20-20h140v140h-140z'/>", @YES],
        @[@"<path fill-rule='nonzero' d='M-50-50h200v200h-200z M-20-20h140v140h-140z'/>", @NO],
        @[@"<path d='M-5 10v80' fill='none' stroke='black' stroke-width='12'/>", @NO],
        @[@"<rect x='99' y='20' width='100' height='20'/>", @NO],
        @[@"<rect x='101' y='20' width='100' height='20'/>", @YES]
    ];
    for(NSArray* entry in cases) {
        IJSVG* svg = [self svgWithBody:entry[0] viewBox:@"0 0 100 100"];
        XCTAssertEqual([svg isNodeOutsideViewBox:svg.rootNode.children[0]],
                       [entry[1] boolValue], @"%@", entry[0]);
    }
}

- (void)testAncestorTransformsAndNonzeroViewBox
{
    NSString* body = @"<g transform='translate(200 300)'><rect x='10' y='10' width='20' height='20'/></g>";
    IJSVG* svg = [self svgWithBody:body viewBox:@"200 300 100 100"];
    IJSVGGroup* group = (IJSVGGroup*)svg.rootNode.children[0];
    XCTAssertFalse([svg isNodeOutsideViewBox:group.children[0]]);
    IJSVG* outside = [self svgWithBody:body viewBox:@"0 0 100 100"];
    IJSVGGroup* outsideGroup = (IJSVGGroup*)outside.rootNode.children[0];
    XCTAssertTrue([outside isNodeOutsideViewBox:outsideGroup.children[0]]);
}

- (void)testFiltersRemainConservative
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' x='-1000%' width='2000%'><feOffset dx='-200'/></filter></defs>"
         "<g filter='url(#f)'><rect x='210' y='10' width='20' height='20'/></g>"
        viewBox:@"0 0 100 100"];
    IJSVGGroup* group = (IJSVGGroup*)svg.rootNode.children.lastObject;
    XCTAssertFalse([svg isNodeOutsideViewBox:group]);
    XCTAssertFalse([svg isNodeOutsideViewBox:group.children[0]]);
    IJSVGRenderingOptions* options = svg.renderingOptions;
    options.filtersEnabled = NO;
    svg.renderingOptions = options;
    XCTAssertTrue([svg isNodeOutsideViewBox:group.children[0]]);
}

- (void)testUnrelatedNodeIsUnknown
{
    IJSVG* svg = [self svgWithBody:@"<rect x='200' width='20' height='20'/>" viewBox:@"0 0 100 100"];
    IJSVG* other = [self svgWithBody:@"<rect x='200' width='20' height='20'/>" viewBox:@"0 0 100 100"];
    XCTAssertFalse([svg isNodeOutsideViewBox:other.rootNode.children[0]]);
}

- (void)testCacheInvalidation
{
    IJSVG* svg = [self svgWithBody:@"<path d='M-5 10v80' fill='none' stroke='black' stroke-width='2'/>"
                         viewBox:@"0 0 100 100"];
    IJSVGNode* node = svg.rootNode.children[0];
    XCTAssertTrue([svg isNodeOutsideViewBox:node]);
    svg.style.lineWidth = 12;
    [svg setNeedsDisplay];
    XCTAssertFalse([svg isNodeOutsideViewBox:node]);
    IJSVGStyle* style = [[IJSVGStyle alloc] init];
    style.lineWidth = 2;
    svg.style = style;
    XCTAssertTrue([svg isNodeOutsideViewBox:node]);
    [svg fitArtworkToViewBox:YES];
    XCTAssertFalse([svg isNodeOutsideViewBox:node]);
    [svg fitArtworkToViewBox:NO];
    XCTAssertTrue([svg isNodeOutsideViewBox:node]);
    [(IJSVGGroup*)node.parentNode removeChild:node];
    [svg setNeedsDisplay];
    XCTAssertFalse([svg isNodeOutsideViewBox:node]);
}

- (void)testMixedGroupAndFillStroke
{
    IJSVG* svg = [self svgWithBody:
        @"<g><rect x='200' width='20' height='20'/><rect x='10' y='10' width='20' height='20'/></g>"
         "<path d='M-5 10v80' fill='none' stroke='black' stroke-width='12'/>"
        viewBox:@"0 0 100 100"];
    IJSVGGroup* group = (IJSVGGroup*)svg.rootNode.children[0];
    XCTAssertFalse([svg isNodeOutsideViewBox:group]);
    XCTAssertTrue([svg isNodeOutsideViewBox:group.children[0]]);
    XCTAssertFalse([svg isNodeOutsideViewBox:group.children[1]]);
    XCTAssertFalse([svg isNodeOutsideViewBox:svg.rootNode.children[1]]);
}

- (IJSVG*)cameraBoundsFixture
{
    return [self svgWithBody:
        @"<rect x='9' y='20' width='82' height='60'/>"
         "<path fill='#0000FF' d='M1364-650v1684H-420V-650H1364 M1372-658H-428v1700h1800V-658L1372-658z'/>"
        viewBox:@"0 0 100 100"];
}

- (void)testFittingIgnoresOutsideNodesAndRestoresThem
{
    IJSVG* svg = [self cameraBoundsFixture];
    IJSVGNode* border = svg.rootNode.children[1];
    CGRect originalBounds = svg.artworkBounds;
    for(NSUInteger repeat = 0; repeat < 3; repeat++) {
        [svg fitArtworkToViewBox:YES ignoringNodesOutsideViewBox:YES];
        XCTAssertFalse(border.shouldRender);
        XCTAssertTrue(CGRectEqualToRect(svg.artworkBounds, CGRectMake(9, 20, 82, 60)));
    }
    [svg fitArtworkToViewBox:NO];
    XCTAssertTrue(border.shouldRender);
    XCTAssertTrue(CGRectEqualToRect(svg.artworkBounds, originalBounds));
    [svg fitArtworkToViewBox:YES ignoringNodesOutsideViewBox:YES];
    [svg fitArtworkToViewBox:YES];
    XCTAssertTrue(border.shouldRender);
    XCTAssertLessThan(svg.artworkBounds.size.width, originalBounds.size.width);
}

- (void)testFittingRetainsPartiallyVisibleNodes
{
    IJSVG* svg = [self svgWithBody:
        @"<rect x='-10' y='10' width='40' height='40'/>"
         "<rect x='-50' y='-50' width='200' height='200' fill='none' stroke='blue'/>"
         "<rect x='20' y='20' width='10' height='10' display='none'/>"
        viewBox:@"0 0 100 100"];
    IJSVGNode* partial = svg.rootNode.children[0];
    IJSVGNode* border = svg.rootNode.children[1];
    IJSVGNode* hidden = svg.rootNode.children[2];
    for(NSUInteger repeat = 0; repeat < 2; repeat++) {
        [svg fitArtworkToViewBox:YES includingFilters:YES ignoringNodesOutsideViewBox:YES];
        XCTAssertTrue(partial.shouldRender);
        XCTAssertFalse(border.shouldRender);
        XCTAssertFalse(hidden.shouldRender);
        XCTAssertEqualWithAccuracy(svg.artworkBounds.size.width, 100.f / 3.f, 0.001);
    }
    [svg fitArtworkToViewBox:NO];
    XCTAssertTrue(border.shouldRender);
    XCTAssertFalse(hidden.shouldRender);
}

- (void)testExportRemovesOutsideNodesWithoutMutatingSource
{
    IJSVG* svg = [self cameraBoundsFixture];
    CGRect originalBounds = svg.artworkBounds;
    NSString* unchanged = [svg SVGStringWithOptions:IJSVGExporterOptionNone];
    IJSVG* unchangedSVG = [[IJSVG alloc] initWithSVGString:unchanged];
    XCTAssertNotNil(unchangedSVG);
    XCTAssertEqualWithAccuracy(unchangedSVG.artworkBounds.size.width, originalBounds.size.width, 0.01);
    NSString* cleaned = [svg SVGStringWithOptions:IJSVGExporterOptionRemoveNodesOutsideViewBox];
    IJSVG* cleanedSVG = [[IJSVG alloc] initWithSVGString:cleaned];
    XCTAssertNotNil(cleanedSVG);
    XCTAssertTrue(CGRectEqualToRect(cleanedSVG.artworkBounds, CGRectMake(9, 20, 82, 60)));
    XCTAssertTrue(CGRectEqualToRect(svg.artworkBounds, originalBounds));
    XCTAssertTrue(svg.rootNode.children[1].shouldRender);
    [svg fitArtworkToViewBox:YES ignoringNodesOutsideViewBox:YES];
    NSString* fitted = [svg SVGStringWithOptions:IJSVGExporterOptionRemoveNodesOutsideViewBox];
    IJSVG* fittedSVG = [[IJSVG alloc] initWithSVGString:fitted];
    XCTAssertTrue(CGRectEqualToRect(fittedSVG.artworkBounds, CGRectMake(9, 20, 82, 60)));
    // The ignored border must be omitted, rather than merely exported hidden.
    NSXMLDocument* xml = [[NSXMLDocument alloc] initWithXMLString:fitted options:0 error:nil];
    XCTAssertEqual([[xml nodesForXPath:@"//*[@display='none']" error:nil] count], 0U);
}

- (void)testSharedArtworkRendererKeepsFilterModesAndDrawingIndependent
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' x='-50%' y='-50%' width='200%' height='200%'>"
         "<feGaussianBlur stdDeviation='2'/></filter></defs>"
         "<rect x='20' y='30' width='40' height='20' filter='url(#f)'/>"
        viewBox:@"0 0 100 100"];
    IJSVGNode* node = svg.rootNode.children.lastObject;
    CGImageRef before = [svg newCGImageRefWithSize:CGSizeMake(100, 100) flipped:NO error:nil];
    for(NSUInteger pass = 0; pass < 3; pass++) {
        XCTAssertTrue(CGRectEqualToRect(svg.artworkBounds, CGRectMake(20, 30, 40, 20)));
        XCTAssertTrue(CGRectEqualToRect(svg.artworkExtent, CGRectMake(0, 20, 80, 40)));
        XCTAssertFalse([svg isNodeOutsideViewBox:node]);
        XCTAssertTrue(CGRectEqualToRect(svg.artworkBounds, CGRectMake(20, 30, 40, 20)));
    }
    CGImageRef after = [svg newCGImageRefWithSize:CGSizeMake(100, 100) flipped:NO error:nil];
    XCTAssertNotEqual(before, NULL);
    XCTAssertNotEqual(after, NULL);
    if(before != NULL && after != NULL) {
        NSData* first = CFBridgingRelease(CGDataProviderCopyData(CGImageGetDataProvider(before)));
        NSData* second = CFBridgingRelease(CGDataProviderCopyData(CGImageGetDataProvider(after)));
        XCTAssertEqualObjects(first, second);
    }
    CGImageRelease(before);
    CGImageRelease(after);
    IJSVGRenderingOptions* options = svg.renderingOptions;
    options.filtersEnabled = NO;
    svg.renderingOptions = options;
    XCTAssertTrue(CGRectEqualToRect(svg.artworkExtent, svg.artworkBounds));
    options.filtersEnabled = YES;
    svg.renderingOptions = options;
    XCTAssertTrue(CGRectEqualToRect(svg.artworkExtent, CGRectMake(0, 20, 80, 40)));
    node.shouldRender = NO;
    [svg setNeedsDisplay];
    XCTAssertTrue(CGRectIsNull(svg.artworkBounds));
    XCTAssertTrue(CGRectIsNull(svg.artworkExtent));
}

- (void)testColdVisibilityFittingAndExport
{
    NSMutableString* body = [NSMutableString string];
    for(NSUInteger index = 0; index < 100; index++) {
        [body appendString:
            @"<path d='M-50-50h200v200h-200z M-20-20v140h140v-140z'/>"
             "<rect x='-50' y='-50' width='200' height='200' fill='none' stroke='blue' stroke-width='8'/>"
             "<path d='M10 10h10v10h-10z'/>"];
    }
    for(NSUInteger sample = 0; sample < 5; sample++) {
        IJSVG* svg = [self svgWithBody:body viewBox:@"0 0 100 100"];
        NSArray<IJSVGNode*>* nodes = svg.rootNode.children;
        NSUInteger outside = 0;
        for(IJSVGNode* node in nodes) {
            outside += [svg isNodeOutsideViewBox:node];
        }
        XCTAssertEqual(outside, 200U);
        [svg setNeedsDisplay];
        [svg fitArtworkToViewBox:YES ignoringNodesOutsideViewBox:YES];
        XCTAssertTrue(CGRectEqualToRect(svg.artworkBounds, CGRectMake(10, 10, 10, 10)));
        [svg fitArtworkToViewBox:NO];
        NSString* output = [svg SVGStringWithOptions:IJSVGExporterOptionRemoveNodesOutsideViewBox];
        XCTAssertGreaterThan(output.length, 0U);

    }
}

- (void)testOutsideStrokeClassificationDoesNotDiscardRenderedPixels
{
    NSUInteger outsideCount = 0;
    for(NSString* transform in @[@"translate(-200 -200)", @"translate(50 50)",
                                 @"translate(-8 25) rotate(30)", @"translate(110 50) scale(0.5 2)",
                                 @"translate(200 0) skewX(30)", @"translate(90 90) rotate(45)"]) {
        for(NSString* cap in @[@"butt", @"round", @"square"]) {
            for(NSString* dash in @[@"", @"stroke-dasharray='3 7'"]) {
                NSString* body = [NSString stringWithFormat:
                    @"<path d='M-20 0L0-20L20 0L0 20' transform='%@' fill='none' "
                     "stroke='black' stroke-width='8' stroke-linecap='%@' stroke-linejoin='miter' "
                     "stroke-miterlimit='20' %@/>", transform, cap, dash];
                IJSVG* svg = [self svgWithBody:body viewBox:@"0 0 100 100"];
                BOOL outside = [svg isNodeOutsideViewBox:svg.rootNode.children[0]];
                if(!outside) {
                    continue;
                }
                outsideCount++;
                CGImageRef image = [svg newCGImageRefWithSize:CGSizeMake(100, 100) flipped:NO error:nil];
                XCTAssertNotEqual(image, NULL);
                if(image == NULL) {
                    continue;
                }
                NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithCGImage:image];
                CGImageRelease(image);
                BOOL hasPixels = NO;
                for(NSInteger y = 0; y < bitmap.pixelsHigh && !hasPixels; y++) {
                    for(NSInteger x = 0; x < bitmap.pixelsWide; x++) {
                        if([bitmap colorAtX:x y:y].alphaComponent > 0) {
                            hasPixels = YES;
                            break;
                        }
                    }
                }
                XCTAssertFalse(hasPixels, @"%@", body);
            }
        }
    }
    XCTAssertGreaterThan(outsideCount, 0U);
}

- (void)testStrokeVisibilityClassification
{
    NSMutableString* body = [NSMutableString string];
    for(NSUInteger index = 0; index < 1000; index++) {
        [body appendFormat:@"<path d='M%lu 40h10v10h-10z' fill='none' stroke='black' stroke-width='2'/>",
            index % 2 == 0 ? 40UL : 200UL];
    }
    for(NSUInteger sample = 0; sample < 5; sample++) {
        IJSVG* svg = [self svgWithBody:body viewBox:@"0 0 100 100"];
        NSUInteger outside = 0;
        for(IJSVGNode* node in svg.rootNode.children) {
            outside += [svg isNodeOutsideViewBox:node];
        }

        XCTAssertEqual(outside, 500U);
    }
}

- (void)testFilteredExtentAfterInvalidation
{
    NSMutableString* body = [NSMutableString stringWithString:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='100' height='100'>"
         "<feGaussianBlur stdDeviation='2'/></filter></defs><g filter='url(#f)'>"];
    for(NSUInteger index = 0; index < 1000; index++) {
        [body appendString:@"<path d='M40 40h10v10h-10z' fill='none' stroke='black' stroke-width='2'/>"];
    }
    [body appendString:@"</g>"];
    IJSVG* svg = [self svgWithBody:body viewBox:@"0 0 100 100"];
    for(NSUInteger sample = 0; sample < 5; sample++) {
        [svg setNeedsDisplay];
        CGRect extent = svg.artworkExtent;

        XCTAssertTrue(CGRectEqualToRect(extent, CGRectMake(0, 0, 100, 100)));
    }
}

- (void)testRepeatedArtworkMeasurements
{
    NSMutableString* body = [NSMutableString string];
    for(NSUInteger index = 0; index < 1000; index++) {
        [body appendFormat:@"<path d='M%lu 10h10v10h-10z'/>", index % 2 == 0 ? 10UL : 200UL];
    }
    IJSVG* svg = [self svgWithBody:body viewBox:@"0 0 100 100"];
    CGRect expected = CGRectMake(10, 10, 200, 10);
    XCTAssertTrue(CGRectEqualToRect(svg.artworkBounds, expected));
    XCTAssertTrue(CGRectEqualToRect(svg.artworkExtent, expected));
    for(NSUInteger sample = 0; sample < 3; sample++) {
        CGFloat sum = 0;
        for(NSUInteger index = 0; index < 1000; index++) {
            sum += svg.artworkBounds.size.width;
            sum += svg.artworkExtent.size.width;
        }

        XCTAssertEqual(sum, 400000);
    }
    // Both cached results must refresh after a geometry edit.
    [svg.rootNode removeChildren:svg.rootNode.children];
    [svg setNeedsDisplay];
    XCTAssertTrue(CGRectIsNull(svg.artworkBounds));
    XCTAssertTrue(CGRectIsNull(svg.artworkExtent));
}

- (void)testQueryingEveryPath
{
    NSMutableString* body = [NSMutableString string];
    for(NSUInteger index = 0; index < 1000; index++) {
        [body appendFormat:@"<path d='M%lu 10h10v10h-10z'/>", index % 2 == 0 ? 10UL : 200UL];
    }
    IJSVG* svg = [self svgWithBody:body viewBox:@"0 0 100 100"];
    NSArray<IJSVGNode*>* nodes = svg.rootNode.children;
    NSUInteger outsideCount = 0;
    for(NSUInteger pass = 0; pass < 2; pass++) {
        for(IJSVGNode* node in nodes) {
            outsideCount += [svg isNodeOutsideViewBox:node] ? 1 : 0;
        }
    }

    XCTAssertEqual(outsideCount, 1000U);


}

@end
