//
//  IJSVGSymbolTests.m
//  IJSVGExampleTests
//
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTestHelpers.h>

@interface IJSVGSymbolTests: XCTestCase
@end

@implementation IJSVGSymbolTests

- (void)assertBody:(NSString*)body matchesBody:(NSString*)expected
{
    CGSize size = CGSizeMake(8.f, 8.f);
    NSData* actualData = IJSVGTestRGBADataForSVG(IJSVGTestSVG(body), size);
    NSData* expectedData = IJSVGTestRGBADataForSVG(IJSVGTestSVG(expected), size);
    XCTAssertNotNil(actualData);
    XCTAssertNotNil(expectedData);
    XCTAssertEqualObjects(actualData, expectedData, @"%@", body);
}

- (void)testDefinitionsDoNotRenderEvenWithDisplayInline
{
    [self assertBody:@"<symbol display=\"inline\"><rect width=\"8\" height=\"8\"/></symbol>"
                     "<g id=\"group\"><symbol id=\"nested\"><rect width=\"8\" height=\"8\"/></symbol></g>"
                     "<use href=\"#group\"/>"
        matchesBody:@""];
}

- (void)testForwardReferencesHaveIndependentSizesAndInheritedColors
{
    [self assertBody:@"<use href=\"#box\" width=\"2\" height=\"2\" fill=\"red\"/>"
                     "<use href=\"#box\" x=\"4\" y=\"4\" width=\"4\" height=\"4\" fill=\"blue\"/>"
                     "<symbol id=\"box\" viewBox=\"0 0 1 1\"><rect width=\"1\" height=\"1\"/></symbol>"
        matchesBody:@"<rect width=\"2\" height=\"2\" fill=\"red\"/>"
                     "<rect x=\"4\" y=\"4\" width=\"4\" height=\"4\" fill=\"blue\"/>"];
}

- (void)testSymbolDimensionsAndPositionAreDefaults
{
    [self assertBody:@"<defs><symbol id=\"box\" x=\"1\" y=\"1\" width=\"2\" height=\"2\" "
                     "viewBox=\"0 0 1 1\"><rect width=\"1\" height=\"1\"/></symbol></defs>"
                     "<use href=\"#box\" x=\"2\" y=\"3\"/>"
        matchesBody:@"<rect x=\"3\" y=\"4\" width=\"2\" height=\"2\"/>"];
}

- (void)testAutoDimensionsAndPercentageChildrenUseViewport
{
    [self assertBody:@"<symbol id=\"box\" width=\"auto\" height=\"auto\">"
                     "<rect width=\"50%\" height=\"50%\"/></symbol>"
                     "<use href=\"#box\" width=\"auto\" height=\"auto\"/>"
        matchesBody:@"<rect width=\"4\" height=\"4\"/>"];
}

- (void)testUseDimensionsOverrideEachAxisIndependently
{
    [self assertBody:@"<symbol id=\"box\" width=\"2\" height=\"4\" viewBox=\"0 0 1 1\" "
                     "preserveAspectRatio=\"none\"><rect width=\"1\" height=\"1\"/></symbol>"
                     "<use href=\"#box\" width=\"50%\"/>"
        matchesBody:@"<rect width=\"4\" height=\"4\"/>"];
}

- (void)testDefaultAspectRatioCentersContent
{
    [self assertBody:@"<symbol id=\"box\" viewBox=\"0 0 2 4\"><rect width=\"2\" height=\"4\"/></symbol>"
                     "<use href=\"#box\" width=\"8\" height=\"8\"/>"
        matchesBody:@"<rect x=\"2\" width=\"4\" height=\"8\"/>"];
}

- (void)testSliceClipsToSymbolViewport
{
    [self assertBody:@"<symbol id=\"box\" viewBox=\"0 0 4 2\" preserveAspectRatio=\"xMaxYMax slice\">"
                     "<rect width=\"4\" height=\"2\"/></symbol>"
                     "<use href=\"#box\" x=\"2\" y=\"2\" width=\"4\" height=\"4\"/>"
        matchesBody:@"<rect x=\"2\" y=\"2\" width=\"4\" height=\"4\"/>"];
}

- (void)testOverflowCanBeMadeVisible
{
    for(NSString* overflow in @[@"hidden", @"visible"]) {
        NSString* body = [NSString stringWithFormat:
            @"<symbol id=\"box\" width=\"2\" height=\"2\" overflow=\"%@\">"
             "<rect width=\"4\" height=\"4\"/></symbol><use href=\"#box\" x=\"2\" y=\"2\"/>", overflow];
        NSString* expected = [overflow isEqualToString:@"hidden"]
            ? @"<rect x=\"2\" y=\"2\" width=\"2\" height=\"2\"/>"
            : @"<rect x=\"2\" y=\"2\" width=\"4\" height=\"4\"/>";
        [self assertBody:body matchesBody:expected];
    }
}

- (void)testZeroDimensionsAndZeroViewBoxDisableRendering
{
    [self assertBody:@"<symbol id=\"box\" viewBox=\"0 0 1 1\"><rect width=\"1\" height=\"1\"/></symbol>"
                     "<use href=\"#box\" width=\"0\"/><use href=\"#box\" height=\"0\"/>"
                     "<symbol id=\"empty\" viewBox=\"0 0 0 1\"><rect width=\"8\" height=\"8\"/></symbol>"
                     "<use href=\"#empty\"/>"
        matchesBody:@""];
}

- (void)testReferencePointKeywordsAndLengths
{
    for(NSString* reference in @[@"refX=\"center\" refY=\"center\"",
                                 @"refX=\"50%\" refY=\"50%\"",
                                 @"refX=\"1\" refY=\"1\""]) {
        NSString* body = [NSString stringWithFormat:
            @"<symbol id=\"box\" viewBox=\"0 0 2 2\" %@><rect width=\"2\" height=\"2\"/></symbol>"
             "<use href=\"#box\" x=\"4\" y=\"4\" width=\"4\" height=\"4\"/>", reference];
        [self assertBody:body matchesBody:@"<rect x=\"2\" y=\"2\" width=\"4\" height=\"4\"/>"];
    }
}

- (void)testAbsentReferenceDiffersFromZeroWithNonzeroViewBoxOrigin
{
    [self assertBody:@"<symbol id=\"box\" viewBox=\"1 1 2 2\"><rect x=\"1\" y=\"1\" width=\"2\" height=\"2\"/></symbol>"
                     "<use href=\"#box\" width=\"2\" height=\"2\"/>"
        matchesBody:@"<rect width=\"2\" height=\"2\"/>"];
    [self assertBody:@"<symbol id=\"box\" viewBox=\"1 1 2 2\" refX=\"0\" refY=\"0\">"
                     "<rect x=\"1\" y=\"1\" width=\"2\" height=\"2\"/></symbol>"
                     "<use href=\"#box\" width=\"2\" height=\"2\"/>"
        matchesBody:@"<rect x=\"1\" y=\"1\" width=\"2\" height=\"2\"/>"];
}

- (void)testNestedUsesAndCycles
{
    [self assertBody:@"<symbol id=\"outer\" width=\"4\" height=\"4\"><use href=\"#inner\"/>"
                     "<symbol><rect width=\"8\" height=\"8\"/></symbol></symbol>"
                     "<symbol id=\"inner\" width=\"2\" height=\"2\"><rect width=\"2\" height=\"2\"/>"
                     "<use href=\"#outer\"/></symbol><use href=\"#outer\"/>"
        matchesBody:@"<rect width=\"2\" height=\"2\"/>"];
}

- (void)testXLinkTransformAndOpacity
{
    [self assertBody:@"<symbol id=\"box\" width=\"2\" height=\"2\"><rect width=\"2\" height=\"2\"/></symbol>"
                     "<use xmlns:xlink=\"http://www.w3.org/1999/xlink\" xlink:href=\"#box\" "
                     "transform=\"translate(2 2)\" opacity=\"0.5\"/>"
        matchesBody:@"<rect x=\"2\" y=\"2\" width=\"2\" height=\"2\" opacity=\"0.5\"/>"];
}

- (void)testStylesheetSizesAndSymbolPresentationOverrideUse
{
    [self assertBody:@"<style>symbol { fill: red; width: 2; height: 2; } use { width: 4; }</style>"
                     "<symbol id=\"box\" viewBox=\"0 0 1 1\" preserveAspectRatio=\"none\">"
                     "<rect width=\"1\" height=\"1\"/></symbol><use href=\"#box\" fill=\"blue\"/>"
        matchesBody:@"<rect width=\"4\" height=\"2\" fill=\"red\"/>"];
}

- (void)testDisplayAppliesToUseButNotInstantiatedSymbol
{
    [self assertBody:@"<symbol id=\"box\" display=\"none\" width=\"2\" height=\"2\">"
                     "<rect width=\"2\" height=\"2\"/></symbol>"
                     "<use href=\"#box\"/><use href=\"#box\" x=\"4\" display=\"none\"/>"
        matchesBody:@"<rect width=\"2\" height=\"2\"/>"];
}

- (void)testInvalidSizesAndMissingReferences
{
    [self assertBody:@"<symbol id=\"box\" width=\"2\" height=\"2\"><rect width=\"2\" height=\"2\"/></symbol>"
                     "<use href=\"#box\" width=\"-1\" height=\"-1\"/>"
                     "<use/><use href=\"\"/><use href=\"#\"/><use href=\"#missing\"/>"
        matchesBody:@"<rect width=\"2\" height=\"2\"/>"];
}

- (void)testSymbolClipPathAndOverflowBothApply
{
    [self assertBody:@"<defs><clipPath id='clip'><rect width='8' height='1'/></clipPath></defs>"
                     "<symbol id='box' width='2' height='2' clip-path='url(#clip)'>"
                     "<rect width='8' height='8'/></symbol><use href='#box' x='2' y='2'/>"
        matchesBody:@"<rect x='2' y='2' width='2' height='1'/>"];
}

- (void)testScaledSymbolClipPathUsesContentCoordinates
{
    [self assertBody:@"<defs><clipPath id='clip'><rect width='1' height='1'/></clipPath></defs>"
                     "<symbol id='box' viewBox='0 0 2 2' clip-path='url(#clip)'>"
                     "<rect width='2' height='2'/></symbol><use href='#box' x='2' y='2' width='4' height='4'/>"
        matchesBody:@"<rect x='2' y='2' width='2' height='2'/>"];
}

- (void)testSymbolMaskAndInheritedGradient
{
    [self assertBody:@"<defs><linearGradient id='paint'><stop stop-color='red'/>"
                     "<stop offset='1' stop-color='blue'/></linearGradient>"
                     "<mask id='mask' maskUnits='userSpaceOnUse' x='0' y='0' width='8' height='8'>"
                     "<rect width='2' height='4' fill='white'/></mask></defs>"
                     "<symbol id='box' width='4' height='4' mask='url(#mask)'>"
                     "<rect width='4' height='4'/></symbol><use href='#box' fill='url(#paint)'/>"
        matchesBody:@"<defs><linearGradient id='paint'><stop stop-color='red'/>"
                     "<stop offset='1' stop-color='blue'/></linearGradient>"
                     "<mask id='mask' maskUnits='userSpaceOnUse' x='0' y='0' width='8' height='8'>"
                     "<rect width='2' height='4' fill='white'/></mask></defs>"
                     "<rect width='4' height='4' fill='url(#paint)' mask='url(#mask)'/>"];
}

- (void)testSymbolExportRoundTripPreservesClippingAndReferences
{
    NSString* source = IJSVGTestSVG(
        @"<symbol id='box' viewBox='0 0 2 2' refX='center' refY='center'>"
         "<rect width='4' height='4'/></symbol>"
         "<use href='#box' x='4' y='4' width='4' height='4' opacity='.5'/>");
    IJSVG* svg = IJSVGTestSVGObject(source);
    for(NSNumber* options in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionAll)]) {
        NSString* exported = [svg SVGStringWithSize:CGSizeMake(8, 8) options:options.unsignedIntegerValue];
        XCTAssertEqualObjects(IJSVGTestRGBADataForSVG(source, CGSizeMake(8, 8)),
                              IJSVGTestRGBADataForSVG(exported, CGSizeMake(8, 8)));
    }
}

- (void)testReferenceOnOnlyOneAxisAndEdgeKeywords
{
    [self assertBody:@"<symbol id='box' viewBox='0 0 2 2' refX='right'>"
                     "<rect width='2' height='2'/></symbol><use href='#box' x='4' y='2' width='2' height='2'/>"
        matchesBody:@"<rect x='2' y='2' width='2' height='2'/>"];
    [self assertBody:@"<symbol id='box' viewBox='0 0 2 2' refX='left' refY='bottom'>"
                     "<rect width='2' height='2'/></symbol><use href='#box' x='2' y='4' width='2' height='2'/>"
        matchesBody:@"<rect x='2' y='2' width='2' height='2'/>"];
}

- (void)testResizingCachedSymbolMatchesFreshRendering
{
    NSString* source = IJSVGTestSVG(
        @"<symbol id='box' viewBox='0 0 2 2' preserveAspectRatio='none'>"
         "<rect width='50%' height='100%'/></symbol><use href='#box' width='50%' height='100%'/>");
    IJSVG* svg = IJSVGTestSVGObject(source);
    svg.renderingBackingScaleHelper = ^CGFloat { return 1.f; };
    for(NSNumber* dimension in @[@8, @16, @4, @8]) {
        CGSize size = CGSizeMake(dimension.doubleValue, dimension.doubleValue);
        IJSVG* fresh = IJSVGTestSVGObject(source);
        fresh.renderingBackingScaleHelper = ^CGFloat { return 1.f; };
        CGImageRef actual = [svg newCGImageRefWithSize:size flipped:NO error:nil];
        CGImageRef expected = [fresh newCGImageRefWithSize:size flipped:NO error:nil];
        XCTAssertNotEqual(actual, NULL);
        XCTAssertNotEqual(expected, NULL);
        if(actual != NULL && expected != NULL) {
            NSData* actualPixels = CFBridgingRelease(CGDataProviderCopyData(CGImageGetDataProvider(actual)));
            NSData* expectedPixels = CFBridgingRelease(CGDataProviderCopyData(CGImageGetDataProvider(expected)));
            XCTAssertEqualObjects(actualPixels, expectedPixels);
        }
        if(actual != NULL) CGImageRelease(actual);
        if(expected != NULL) CGImageRelease(expected);
    }
}

- (void)testSymbolExtentIncludesReferenceOffsetAndViewportClipping
{
    IJSVG* svg = IJSVGTestSVGObject(IJSVGTestSVG(
        @"<symbol id='box' viewBox='0 0 2 2' refX='center' refY='center'>"
         "<rect width='4' height='4'/></symbol><use href='#box' x='4' y='4' width='4' height='4'/>"));
    CGRect extent = [svg.rootNode.children.firstObject extentWithViewPort:CGRectMake(0, 0, 8, 8)
                                                                   style:nil];
    XCTAssertTrue(CGRectEqualToRect(extent, CGRectMake(2, 2, 4, 4)), @"%@", NSStringFromRect(extent));
}

- (void)testNonScalingStrokeInsideScaledSymbol
{
    [self assertBody:@"<symbol id='box' viewBox='0 0 2 2'>"
                     "<path d='M0 1H2' stroke='red' stroke-width='1' vector-effect='non-scaling-stroke'/>"
                     "</symbol><use href='#box' x='2' y='2' width='4' height='4'/>"
        matchesBody:@"<path d='M2 4H6' stroke='red' stroke-width='1'/>"];
}

- (void)testSymbolTransformAndEffectCombinationsMatchExpandedGroups
{
    NSString* definitions = @"<defs>"
        "<clipPath id='viewport'><rect width='4' height='4'/></clipPath>"
        "<clipPath id='clip'><rect x='1' y='2' width='1' height='2'/></clipPath>"
        "<mask id='mask' maskUnits='userSpaceOnUse' x='0' y='0' width='5' height='6'>"
        "<rect x='1' y='2' width='1' height='2' fill='white'/></mask>"
        "<filter id='filter' filterUnits='userSpaceOnUse' x='0' y='0' width='5' height='6'>"
        "<feOffset dx='.5' dy='.5'/></filter>"
        "</defs>";
    NSArray<NSString*>* transforms = @[@"", @"translate(1 0)", @"rotate(90 4 4)",
        @"translate(8 0) scale(-1 1)", @"skewX(15)", @"matrix(1 .2 -.1 1 0 0)"];
    NSArray<NSString*>* effects = @[@"", @"clip-path='url(#clip)'", @"mask='url(#mask)'",
        @"filter='url(#filter)'", @"clip-path='url(#clip)' mask='url(#mask)' filter='url(#filter)'"];
    NSString* artwork = @"<rect x='0' y='1' width='4' height='4' fill='red'/>"
                         "<rect x='1' y='2' width='1' height='1' fill='blue'/>";
    for(NSString* transform in transforms) {
        for(NSString* effect in effects) {
            for(NSNumber* reference in @[@NO, @YES]) {
                for(NSNumber* visible in @[@NO, @YES]) {
                    NSString* referenceAttributes = reference.boolValue ? @"refX='2' refY='3'" : @"";
                    NSString* placement = reference.boolValue ? @"translate(-2 -2)" : @"";
                    NSString* clipping = visible.boolValue ? @"" : @"clip-path='url(#viewport)'";
                    NSString* source = [NSString stringWithFormat:
                        @"%@<symbol id='box' viewBox='1 2 2 2' transform='%@' x='1' y='0' %@ %@ "
                         "overflow='%@' opacity='.75'>%@</symbol>"
                         "<use href='#box' x='1' y='2' width='4' height='4' transform='%@' opacity='.8'/>",
                        definitions, transform, referenceAttributes, effect,
                        visible.boolValue ? @"visible" : @"hidden", artwork, transform];
                    NSString* expanded = [NSString stringWithFormat:
                        @"%@<g transform='%@' opacity='.8'><g transform='translate(1 2)'>"
                         "<g transform='%@'><g transform='translate(1 0)'><g transform='%@'>"
                         "<g %@><g transform='matrix(2 0 0 2 -2 -4)'><g %@ opacity='.75'>%@"
                         "</g></g></g></g></g></g></g></g>",
                        definitions, transform, transform, placement, clipping, effect, artwork];
                    [self assertBody:source matchesBody:expanded];
                    if(transform.length == 0 || [transform isEqualToString:@"rotate(90 4 4)"]) {
                        NSString* document = IJSVGTestSVG(source);
                        IJSVG* svg = IJSVGTestSVGObject(document);
                        NSData* expectedPixels = IJSVGTestRGBADataForSVG(document, CGSizeMake(8, 8));
                        for(NSNumber* options in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionAll)]) {
                            NSString* exported = [svg SVGStringWithSize:CGSizeMake(8, 8)
                                                               options:options.unsignedIntegerValue];
                            XCTAssertEqualObjects(expectedPixels,
                                IJSVGTestRGBADataForSVG(exported, CGSizeMake(8, 8)), @"%@", source);
                        }
                    }
                    // Also exercise the container fast path with fully opaque content.
                    [self assertBody:[source stringByReplacingOccurrencesOfString:@"opacity='.75'"
                                                                       withString:@"opacity='1'"]
                         matchesBody:[expanded stringByReplacingOccurrencesOfString:@"opacity='.75'"
                                                                         withString:@"opacity='1'"]];
                }
            }
        }
    }
}

- (void)testAspectRatioModesMatchExplicitViewportTransforms
{
    NSDictionary<NSString*, NSString*>* mappings = @{
        @"none": @"matrix(2 0 0 1 -2 -2)",
        @"xMinYMin meet": @"matrix(1 0 0 1 -1 -2)",
        @"xMidYMid meet": @"matrix(1 0 0 1 0 -2)",
        @"xMaxYMax meet": @"matrix(1 0 0 1 1 -2)",
        @"xMinYMin slice": @"matrix(2 0 0 2 -2 -4)",
        @"xMidYMid slice": @"matrix(2 0 0 2 -2 -6)",
        @"xMaxYMax slice": @"matrix(2 0 0 2 -2 -8)"
    };
    NSString* artwork = @"<rect x='0' y='1' width='4' height='6' fill='red'/>"
                         "<rect x='1' y='3' width='1' height='2' fill='blue'/>";
    for(NSString* aspectRatio in mappings) {
        NSString* source = [NSString stringWithFormat:
            @"<symbol id='box' viewBox='1 2 2 4' preserveAspectRatio='%@'>%@</symbol>"
             "<use href='#box' x='2' y='2' width='4' height='4'/>", aspectRatio, artwork];
        NSString* expanded = [NSString stringWithFormat:
            @"<defs><clipPath id='viewport'><rect width='4' height='4'/></clipPath></defs>"
             "<g transform='translate(2 2)'><g clip-path='url(#viewport)'><g transform='%@'>%@</g></g></g>",
            mappings[aspectRatio], artwork];
        [self assertBody:source matchesBody:expanded];
    }
}

- (void)testObjectBoundingBoxEffectsFollowScaledSymbolGeometry
{
    NSString* definitions = @"<defs>"
        "<clipPath id='clip' clipPathUnits='objectBoundingBox'><rect width='.5' height='1'/></clipPath>"
        "<mask id='mask' maskContentUnits='objectBoundingBox'><rect width='.5' height='1' fill='white'/></mask>"
        "<filter id='filter' primitiveUnits='objectBoundingBox'><feOffset dx='.25' dy='0'/></filter>"
        "</defs>";
    for(NSString* effect in @[@"clip-path='url(#clip)'", @"mask='url(#mask)'", @"filter='url(#filter)'"]) {
        NSString* source = [NSString stringWithFormat:
            @"%@<symbol id='box' viewBox='0 0 2 2' overflow='visible' %@>"
             "<rect width='2' height='2'/></symbol><use href='#box' x='2' y='2' width='4' height='4'/>",
            definitions, effect];
        NSString* expanded = [NSString stringWithFormat:
            @"%@<g transform='translate(2 2) scale(2)'><g %@><rect width='2' height='2'/></g></g>",
            definitions, effect];
        [self assertBody:source matchesBody:expanded];
    }
}

- (void)testNestedSymbolViewportsKeepIndependentTransformsAndClips
{
    [self assertBody:@"<symbol id='inner' viewBox='0 0 2 2' preserveAspectRatio='none'>"
                     "<rect width='4' height='4'/></symbol>"
                     "<symbol id='outer' viewBox='0 0 4 4'>"
                     "<use href='#inner' x='1' y='1' width='2' height='1'/></symbol>"
                     "<use href='#outer' width='8' height='8' transform='rotate(90 4 4)'/>"
        matchesBody:@"<g transform='rotate(90 4 4)'><rect x='2' y='2' width='4' height='2'/></g>"];
}

- (void)testParserPreservesSymbolTypeAndCopiesReferencePoint
{
    IJSVG* svg = IJSVGTestSVGObject(IJSVGTestSVG(
        @"<symbol id=\"box\" refX=\"center\" viewBox=\"0 0 2 2\"><rect width=\"2\" height=\"2\"/></symbol>"
         "<use href=\"#box\"/><use href=\"#box\"/>"));
    IJSVGGroup* first = (IJSVGGroup*)svg.rootNode.children[0];
    IJSVGGroup* second = (IJSVGGroup*)svg.rootNode.children[1];
    IJSVGRootNode* symbol = (IJSVGRootNode*)first.children.firstObject;
    IJSVGRootNode* copy = symbol.copy;
    XCTAssertEqual(svg.rootNode.children.count, 2);
    XCTAssertEqual(symbol.type, IJSVGNodeTypeSymbol);
    XCTAssertEqualObjects(symbol.name, @"symbol");
    XCTAssertNotEqual(symbol, second.children.firstObject);
    XCTAssertEqual(symbol.parentNode, first);
    XCTAssertEqual(copy.type, IJSVGNodeTypeSymbol);
    XCTAssertNotEqual(copy.refX, symbol.refX);
    XCTAssertEqualWithAccuracy([copy.refX computeValue:8.f], 4.f, 0.001);
}

@end
