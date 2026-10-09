//
//  IJSVGMarkerTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 09/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGParser.h>
#import <XCTest/XCTest.h>

static NSString* const IJSVGMarkerTestTriangle = @"<path d='M0 -2L6 0L0 2Z' fill='red'/>";

@interface IJSVGMarkerTests : XCTestCase
@end

@implementation IJSVGMarkerTests

- (IJSVG*)svgWithBody:(NSString*)body
{
    NSString* documentFormat = @"<svg xmlns='http://www.w3.org/2000/svg' width='128' height='128' viewBox='0 0 128 128'>%@</svg>";
    NSString* document = [NSString stringWithFormat:documentFormat, body];
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:document error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(svg);
    return svg;
}

- (NSString*)markerWithAttributes:(NSString*)attributes
{
    NSString* format = @"<defs><marker id='m' markerUnits='userSpaceOnUse' overflow='visible' orient='auto' %@>%@</marker></defs>";
    return [NSString stringWithFormat:format, attributes, IJSVGMarkerTestTriangle];
}

- (NSString*)instanceAtX:(CGFloat)x y:(CGFloat)y angle:(CGFloat)angle scale:(CGFloat)scale
{
    NSString* format = @"<g transform='translate(%g %g) rotate(%g) scale(%g)'>%@</g>";
    return [NSString stringWithFormat:format, x, y, angle, scale, IJSVGMarkerTestTriangle];
}

- (NSData*)pixelsForSVG:(IJSVG*)svg
{
    XCTAssertNotNil(svg);
    if(svg == nil) {
        return nil;
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    XCTAssertTrue(space != NULL);
    if(space == NULL) {
        return nil;
    }
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    CGContextRef context = CGBitmapContextCreate(NULL, 256, 256, 8, 1024, space, bitmapInfo);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) {
        return nil;
    }
    CGContextTranslateCTM(context, 0, 256);
    CGContextScaleCTM(context, 2, -2);
    [svg drawInRect:CGRectMake(0, 0, 128, 128) context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:256 * 1024];
    CGContextRelease(context);
    return pixels;
}

- (void)assertPixels:(NSData*)actual equalTo:(NSData*)expected tolerance:(double)tolerance
{
    XCTAssertNotNil(actual);
    XCTAssertNotNil(expected);
    XCTAssertEqual(actual.length, expected.length);
    if(actual == nil || expected == nil || actual.length == 0 || actual.length != expected.length) {
        return;
    }
    const uint8_t* a = actual.bytes;
    const uint8_t* b = expected.bytes;
    NSUInteger difference = 0;
    for(NSUInteger index = 0; index < actual.length; index++) {
        difference += abs((int)a[index] - (int)b[index]);
    }
    XCTAssertLessThan((double)difference / actual.length, tolerance);
}

- (void)compareBody:(NSString*)actual withBody:(NSString*)expected
{
    [self assertPixels:[self pixelsForSVG:[self svgWithBody:actual]]
               equalTo:[self pixelsForSVG:[self svgWithBody:expected]]
             tolerance:0.15];
}

- (void)assertExportsOfSVG:(IJSVG*)svg matchPixels:(NSData*)expected
{
    for(NSNumber* options in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionAll)]) {
        NSString* exported = [svg SVGStringWithSize:CGSizeMake(128, 128) options:options.unsignedIntegerValue];
        IJSVG* imported = [[IJSVG alloc] initWithSVGString:exported];
        XCTAssertNotNil(imported);
        [self assertPixels:[self pixelsForSVG:imported] equalTo:expected tolerance:0.3];
    }
}

- (void)assertCopyPreservesSVG:(IJSVG*)svg
{
    IJSVGRootNode* root = [svg.rootNode copy];
    XCTAssertNotNil(root);
    IJSVG* copy = [[IJSVG alloc] initWithRootNode:root];
    XCTAssertEqualObjects([self pixelsForSVG:copy], [self pixelsForSVG:svg]);
}

- (void)testMarkerKeywordHelpers
{
    XCTAssertEqual([IJSVGUtils markerUnitsForString:nil], IJSVGMarkerUnitsStrokeWidth);
    XCTAssertEqual([IJSVGUtils markerUnitsForString:@"invalid"], IJSVGMarkerUnitsStrokeWidth);
    XCTAssertEqual([IJSVGUtils markerUnitsForString:IJSVGStringStrokeWidth], IJSVGMarkerUnitsStrokeWidth);
    XCTAssertEqual([IJSVGUtils markerUnitsForString:IJSVGStringUserSpaceOnUse], IJSVGMarkerUnitsUserSpaceOnUse);
    XCTAssertEqual([IJSVGUtils markerOrientTypeForString:nil], IJSVGMarkerOrientTypeAngle);
    XCTAssertEqual([IJSVGUtils markerOrientTypeForString:@"invalid"], IJSVGMarkerOrientTypeAngle);
    XCTAssertEqual([IJSVGUtils markerOrientTypeForString:@"90deg"], IJSVGMarkerOrientTypeAngle);
    XCTAssertEqual([IJSVGUtils markerOrientTypeForString:IJSVGStringAuto], IJSVGMarkerOrientTypeAuto);
    IJSVGMarkerOrientType reverse = [IJSVGUtils markerOrientTypeForString:IJSVGStringAutoStartReverse];
    XCTAssertEqual(reverse, IJSVGMarkerOrientTypeAutoStartReverse);
    XCTAssertEqual([IJSVGUtils contextPaintForString:nil], IJSVGContextPaintNone);
    XCTAssertEqual([IJSVGUtils contextPaintForString:@"red"], IJSVGContextPaintNone);
    XCTAssertEqual([IJSVGUtils contextPaintForString:IJSVGStringContextFill], IJSVGContextPaintFill);
    XCTAssertEqual([IJSVGUtils contextPaintForString:IJSVGStringContextStroke], IJSVGContextPaintStroke);
}

- (void)testMarkerAngleHelper
{
    NSDictionary<NSString*, NSNumber*>* cases = @{
        @"45": @45,
        @"-45deg": @-45,
        @"100grad": @90,
        @"1.5707963267948966rad": @90,
        @"-3.141592653589793rad": @-180,
        @" 2e2grad ": @180,
        @"invalid": @0,
        @"12invalid": @0,
        @"1 2": @0,
        @"nan": @0,
        @"1e999rad": @0,
        @"auto": @0,
        @"auto-start-reverse": @0,
        @"": @0
    };
    XCTAssertEqual([IJSVGUtils angleForString:nil], 0);
    for(NSString* value in cases) {
        XCTAssertEqualWithAccuracy([IJSVGUtils angleForString:value], cases[value].doubleValue, .0001, @"%@", value);
    }
}

- (void)testMarkerEnumsSurviveParsingAndCopy
{
    IJSVGMarker* defaults = [[IJSVGMarker alloc] init];
    XCTAssertEqual(defaults.markerUnits, IJSVGMarkerUnitsStrokeWidth);
    XCTAssertEqual(defaults.orientType, IJSVGMarkerOrientTypeAngle);
    XCTAssertEqual(defaults.orientAngle, 0);
    NSArray<NSString*>* orientations = @[@"100grad", IJSVGStringAuto, IJSVGStringAutoStartReverse];
    NSArray<NSNumber*>* types = @[@(IJSVGMarkerOrientTypeAngle), @(IJSVGMarkerOrientTypeAuto),
                                  @(IJSVGMarkerOrientTypeAutoStartReverse)];
    NSString* format = @"<defs><marker id='m' markerUnits='userSpaceOnUse' orient='%@'>"
        "<circle r='2' fill='context-stroke'/></marker></defs>"
        "<path d='M20 20L80 80' stroke='blue' marker-end='url(#m)'/>";
    for(NSUInteger index = 0; index < orientations.count; index++) {
        NSString* body = [NSString stringWithFormat:format, orientations[index]];
        IJSVG* svg = [self svgWithBody:body];
        IJSVGMarker* marker = svg.rootNode.children.lastObject.markerEnd;
        XCTAssertNotNil(marker);
        XCTAssertEqual(marker.markerUnits, IJSVGMarkerUnitsUserSpaceOnUse);
        XCTAssertEqual(marker.orientType, types[index].unsignedIntegerValue);
        XCTAssertEqualWithAccuracy(marker.orientAngle, index == 0 ? 90 : 0, .0001);
        IJSVGMarker* copy = [marker copy];
        XCTAssertEqual(copy.markerUnits, marker.markerUnits);
        XCTAssertEqual(copy.orientType, marker.orientType);
        XCTAssertEqual(copy.orientAngle, marker.orientAngle);
        IJSVGColorNode* fill = (IJSVGColorNode*)copy.children.lastObject.fill;
        XCTAssertEqual(fill.contextPaint, IJSVGContextPaintStroke);
    }
}

- (void)testStartMidEndAndCornerBisector
{
    [self compareBody:[[self markerWithAttributes:@""]
                          stringByAppendingString:@"<path d='M20 20L80 20L80 80' fill='none' marker-start='url(#m)' "
                                                  @"marker-mid='url(#m)' marker-end='url(#m)'/>"]
             withBody:[@[
                 [self instanceAtX:20 y:20 angle:0 scale:1],
                 [self instanceAtX:80 y:20 angle:45 scale:1],
                 [self instanceAtX:80 y:80 angle:90 scale:1]
             ] componentsJoinedByString:@""]];
}

- (void)testArcHasOnlyAuthoredVertices
{
    [self compareBody:
              [[self markerWithAttributes:@""]
                  stringByAppendingString:@"<path d='M20 60A30 30 0 0 1 80 60L100 60' fill='none' marker='url(#m)'/>"]
             withBody:[@[
                 [self instanceAtX:20 y:60 angle:-90 scale:1],
                 [self instanceAtX:80 y:60 angle:45 scale:1],
                 [self instanceAtX:100 y:60 angle:0 scale:1]
             ] componentsJoinedByString:@""]];
}

- (void)testCubicAndQuadraticEndpointTangents
{
    [self compareBody:[[self markerWithAttributes:@""]
                          stringByAppendingString:
                              @"<path d='M20 60C20 20 60 20 60 60Q80 60 80 80' fill='none' marker='url(#m)'/>"]
             withBody:[@[
                 [self instanceAtX:20 y:60 angle:-90 scale:1],
                 [self instanceAtX:60 y:60 angle:45 scale:1],
                 [self instanceAtX:80 y:80 angle:90 scale:1]
             ] componentsJoinedByString:@""]];
}

- (void)testClosedPolygonOrientation
{
    [self compareBody:[[self markerWithAttributes:@""]
                          stringByAppendingString:@"<polygon points='30,30 90,30 90,90' fill='none' marker='url(#m)'/>"]
             withBody:[@[
                 [self instanceAtX:30 y:30 angle:-67.5 scale:1],
                 [self instanceAtX:90 y:30 angle:45 scale:1],
                 [self instanceAtX:90 y:90 angle:157.5 scale:1],
                 [self instanceAtX:30 y:30 angle:-67.5 scale:1]
             ] componentsJoinedByString:@""]];
}

- (void)testMultipleSubpathsUseGlobalStartAndEnd
{
    [self compareBody:
              [[self markerWithAttributes:@""]
                  stringByAppendingString:@"<path d='M20 20L60 20M20 60L60 60' fill='none' marker-mid='url(#m)'/>"]
             withBody:[[self instanceAtX:60 y:20 angle:0
                                   scale:1] stringByAppendingString:[self instanceAtX:20 y:60 angle:0 scale:1]]];
}

- (void)testZeroLengthSegmentsFindAdjacentTangents
{
    [self compareBody:[[self markerWithAttributes:@""]
                          stringByAppendingString:@"<path d='M20 20L20 20L20 80L20 80' fill='none' "
                                                  @"marker-start='url(#m)' marker-end='url(#m)'/>"]
             withBody:[[self instanceAtX:20 y:20 angle:90
                                   scale:1] stringByAppendingString:[self instanceAtX:20 y:80 angle:90 scale:1]]];
}

- (void)testLongZeroLengthRunsResolveDirections
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 20, 20);
    for(NSUInteger index = 0; index < 4000; index++) {
        CGPathAddLineToPoint(path, NULL, 20, 20);
    }
    NSArray<IJSVGMarkerPosition*>* positions = IJSVGMarkerPositions(path, nil);
    XCTAssertEqual(positions.count, 4001);
    for(IJSVGMarkerPosition* position in positions) {
        XCTAssertEqualWithAccuracy(position.angle, 0, .0001);
    }
    CGPathAddLineToPoint(path, NULL, 20, 80);
    positions = IJSVGMarkerPositions(path, nil);
    XCTAssertEqual(positions.count, 4002);
    for(IJSVGMarkerPosition* position in positions) {
        XCTAssertEqualWithAccuracy(position.angle, 90, .0001);
    }
    CGPathRelease(path);
}

- (void)testClosedZeroLengthRunsWrapDirections
{
    [self compareBody:[[self markerWithAttributes:@""]
                          stringByAppendingString:@"<path d='M30 30L30 30L90 30L90 30L90 90L30 30L30 30Z' "
                                                   "fill='none' marker='url(#m)'/>"]
             withBody:[@[
                 [self instanceAtX:30 y:30 angle:-67.5 scale:1],
                 [self instanceAtX:90 y:30 angle:45 scale:1],
                 [self instanceAtX:90 y:90 angle:157.5 scale:1]
             ] componentsJoinedByString:@""]];
}

- (void)testMarkerShorthandCascadeAndInheritance
{
    NSString* styles = @"<style>.marked{marker:url(#m)!important;marker-mid:none!important}</style>";
    NSString* definitions = [[self markerWithAttributes:@""] stringByAppendingString:styles];
    NSString* expected = [[self instanceAtX:20 y:20 angle:0
                                      scale:1] stringByAppendingString:[self instanceAtX:80 y:80 angle:90 scale:1]];
    [self compareBody:[definitions
                          stringByAppendingString:
                              @"<g class='marked'><path d='M20 20L80 20L80 80' fill='none' style='marker:none'/></g>"]
             withBody:@""];
    [self compareBody:[definitions stringByAppendingString:
                                       @"<path class='marked' d='M20 20L80 20L80 80' fill='none' style='marker:none'/>"]
             withBody:expected];
    [self compareBody:[[self markerWithAttributes:@""]
                          stringByAppendingString:@"<g marker='url(#m)'><polyline points='20,20 80,20 80,80' "
                                                  @"fill='none' marker-mid='none'/></g>"]
             withBody:expected];
}

- (void)testDefaultsAndStrokeWidthUnitsWithoutPaintedStroke
{
    NSString* definitionFormat = @"<defs><marker id='m' overflow='visible'>%@</marker></defs>";
    NSString* definition = [NSString stringWithFormat:definitionFormat, IJSVGMarkerTestTriangle];
    [self compareBody:[definition stringByAppendingString:@"<line x1='20' y1='20' x2='60' y2='80' stroke='none' "
                                                          @"stroke-width='3' marker-end='url(#m)'/>"]
             withBody:[self instanceAtX:60 y:80 angle:0 scale:3]];
}

- (void)testReferencePointViewBoxAndClipping
{
    NSString* definition = @"<defs><marker id='m' markerUnits='userSpaceOnUse' markerWidth='20' markerHeight='10' viewBox='0 0 10 10' "
          @"refX='5' refY='5'><rect x='-10' y='-10' width='30' height='30' fill='red'/></marker></defs>";
    [self compareBody:[definition stringByAppendingString:@"<path d='M20 20L60 60' marker-end='url(#m)'/>"]
             withBody:@"<rect x='50' y='55' width='20' height='10' fill='red'/>"];
}

- (void)testMarkerInheritsDefinitionStyleNotReferencingStyle
{
    NSString* definition = @"<defs fill='red'><marker id='m' markerUnits='userSpaceOnUse' overflow='visible'><rect "
                           @"width='6' height='6'/></marker></defs>";
    [self compareBody:[definition stringByAppendingString:@"<path d='M20 20L60 60' fill='blue' marker-end='url(#m)'/>"]
             withBody:@"<rect x='60' y='60' width='6' height='6' fill='red'/>"];
}

- (void)testDefinitionsInvalidReferencesAndDisabledDimensions
{
    [self compareBody:@"<marker id='m'><rect width='100' height='100'/></marker>" withBody:@""];
    [self compareBody:[[self markerWithAttributes:@"markerWidth='0'"]
                          stringByAppendingString:@"<path d='M20 20L80 80' marker='url(#m)'/>"]
             withBody:@""];
    [self compareBody:
              @"<defs><rect id='wrong' width='100' height='100'/></defs><path d='M20 20L80 80' marker='url(#wrong)'/>"
             withBody:@""];
    [self compareBody:@"<path d='M20 20L80 80' marker='url(#missing)'/>" withBody:@""];
}

- (void)testMarkerDisplayDoesNotDisableReferences
{
    [self compareBody:[[self markerWithAttributes:@"display='none'"]
                          stringByAppendingString:@"<path d='M20 20L80 20' marker-end='url(#m)'/>"]
             withBody:[self instanceAtX:80 y:20 angle:0 scale:1]];
}

- (void)testElementOpacityIncludesMarkers
{
    [self compareBody:[[self markerWithAttributes:@""]
                          stringByAppendingString:@"<g transform='translate(5 8)'><path d='M20 20L80 20' opacity='.5' "
                                                  @"marker-end='url(#m)'/></g>"]
             withBody:[NSString stringWithFormat:@"<g transform='translate(5 8)' opacity='.5'>%@</g>",
                                                 [self instanceAtX:80 y:20 angle:0 scale:1]]];
}

- (void)testExportAndCopyPreserveMarkerArtwork
{
    NSString* body = [[self markerWithAttributes:@""]
        stringByAppendingString:@"<path d='M20 60A30 30 0 0 1 80 60L100 60' fill='none' stroke='blue' stroke-width='2' "
                                @"opacity='.6' marker='url(#m)'/>"];
    IJSVG* svg = [self svgWithBody:body];
    NSData* expected = [self pixelsForSVG:svg];
    [self assertExportsOfSVG:svg matchPixels:expected];
    [self assertCopyPreservesSVG:svg];
}

- (void)testPercentageStrokeWidthAndFixedOrientation
{
    NSString* definitionFormat = @"<defs><marker id='m' overflow='visible' orient='100grad'>%@</marker></defs>";
    NSString* definition = [NSString stringWithFormat:definitionFormat, IJSVGMarkerTestTriangle];
    [self compareBody:[definition
                          stringByAppendingString:
                              @"<line x1='20' y1='20' x2='60' y2='80' stroke-width='1.5625%' marker-end='url(#m)'/>"]
             withBody:[self instanceAtX:60 y:80 angle:90 scale:2]];
}

- (void)testCompoundMarkerChildren
{
    NSString* definitions = @"<defs><linearGradient id='gradient'><stop stop-color='red'/><stop offset='1' "
                            @"stop-color='blue'/></linearGradient></defs>";
    NSString* children = @"<g transform='rotate(15)'><rect width='18' height='12' fill='url(#gradient)'/><circle "
                         @"cx='9' cy='6' r='3' fill='white'/><text x='0' y='24' font-size='10'>SVG</text></g>";
    NSString* actualFormat = @"%@<defs><marker id='m' markerUnits='userSpaceOnUse' "
        @"overflow='visible'>%@</marker></defs><path d='M20 20L60 60' marker-end='url(#m)'/>";
    NSString* actual = [NSString stringWithFormat:actualFormat, definitions, children];
    NSString* expectedFormat = @"%@<g transform='translate(60 60)'>%@</g>";
    NSString* expected = [NSString stringWithFormat:expectedFormat, definitions, children];
    [self compareBody:actual withBody:expected];
    NSData* pixels = [self pixelsForSVG:[self svgWithBody:actual]];
    XCTAssertNotEqualObjects(pixels, [self pixelsForSVG:[self svgWithBody:@""]]);
}

- (IJSVG*)mdnFixture:(NSString*)name
{
    NSString* testDirectory = @(__FILE__).stringByDeletingLastPathComponent;
    NSString* directory = [testDirectory stringByAppendingPathComponent:@"Fixtures/MDNMarkers"];
    NSString* path = [directory stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"svg"]];
    NSError* error = nil;
    NSString* xml = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(xml);
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(svg);
    return svg;
}

- (void)assertMDNExample:(NSString*)name svg11:(BOOL)svg11
{
    IJSVG* svg = [self mdnFixture:svg11 ? [name stringByAppendingString:@"-svg11"] : name];
    NSData* expected = [self pixelsForSVG:[self mdnFixture:[name stringByAppendingString:@"-expected"]]];
    [self assertPixels:[self pixelsForSVG:svg] equalTo:expected tolerance:0.15];
    [self assertExportsOfSVG:svg matchPixels:expected];
    [self assertCopyPreservesSVG:svg];
}

// Original examples and SVG 1.1 equivalents share independently authored reference geometry.
// Source and attribution are recorded in Fixtures/MDNMarkers/README.txt.
- (void)testMDNArrowheads
{
    [self assertMDNExample:@"arrowheads" svg11:NO];
}
- (void)testMDNPolymarkers
{
    [self assertMDNExample:@"polymarkers" svg11:NO];
}
- (void)testMDNContextPaint
{
    [self assertMDNExample:@"context-paint" svg11:NO];
}
- (void)testMDNArrowheadsSVG11
{
    [self assertMDNExample:@"arrowheads" svg11:YES];
}
- (void)testMDNPolymarkersSVG11
{
    [self assertMDNExample:@"polymarkers" svg11:YES];
}
- (void)testMDNContextPaintSVG11
{
    [self assertMDNExample:@"context-paint" svg11:YES];
}

- (void)testContextPaintWithoutContextAndCrossChannelInheritance
{
    [self compareBody:@"<rect width='100' height='100' fill='context-fill' stroke='context-stroke'/>" withBody:@""];
    NSString* definitions = @"<defs><marker id='m' markerUnits='userSpaceOnUse' overflow='visible'><g fill='context-stroke' "
          @"stroke='context-fill'><rect width='8' height='8'/></g></marker></defs>";
    [self compareBody:[definitions stringByAppendingString:
                                       @"<path d='M20 20L60 60' fill='red' stroke='blue' marker-end='url(#m)'/>"]
             withBody:@"<path d='M20 20L60 60' fill='red' stroke='blue'/><rect x='60' y='60' width='8' height='8' "
                      @"fill='blue' stroke='red'/>"];
}

- (void)testContextGradientKeepsReferencingCoordinateSpace
{
    for(NSString* units in @[@"gradientUnits='userSpaceOnUse' x1='0' x2='128'", @""]) {
        NSString* definitionsFormat = @"<defs><linearGradient id='g' %@><stop stop-color='red'/><stop offset='1' "
            @"stop-color='blue'/></linearGradient>"
            "<marker id='m' markerUnits='userSpaceOnUse' overflow='visible'><g transform='scale(2)'><rect x='-5' "
            "y='-5' width='10' height='10' fill='context-stroke'/></g></marker></defs>";
        NSString* definitions = [NSString stringWithFormat:definitionsFormat, units];
        NSString* actualBody = @"<path d='M20 20L80 80' fill='none' stroke='url(#g)' marker-end='url(#m)'/>";
        NSString* actual = [definitions stringByAppendingString:actualBody];
        NSString* coordinates = units.length ? @"x1='0' x2='128'" : @"x1='20' x2='80'";
        NSString* expectedFormat = @"%@<defs><linearGradient id='reference' gradientUnits='userSpaceOnUse' %@><stop "
            @"stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs>"
            "<path d='M20 20L80 80' fill='none' stroke='url(#g)'/><rect x='70' y='70' width='20' "
            "height='20' fill='url(#reference)'/>";
        NSString* expected = [NSString stringWithFormat:expectedFormat, definitions, coordinates];
        [self compareBody:actual withBody:expected];
        IJSVG* svg = [self svgWithBody:actual];
        NSString* exportedDocument = [svg SVGStringWithSize:CGSizeMake(128, 128) options:IJSVGExporterOptionAll];
        IJSVG* exported = [[IJSVG alloc] initWithSVGString:exportedDocument];
        [self assertPixels:[self pixelsForSVG:exported]
                   equalTo:[self pixelsForSVG:[self svgWithBody:expected]]
                 tolerance:0.3];
    }
}

- (void)testContextPatternKeepsReferencingCoordinateSpace
{
    NSString* definitions = @"<defs><pattern id='p' patternUnits='userSpaceOnUse' width='8' height='8'><rect width='4' height='8' "
          @"fill='red'/><rect x='4' width='4' height='8' fill='blue'/></pattern>"
           "<marker id='m' markerUnits='userSpaceOnUse' overflow='visible'><g transform='scale(2)'><rect x='-5' y='-5' "
           "width='10' height='10' fill='context-stroke'/></g></marker></defs>";
    NSString* actualBody = @"<path d='M20 20L83 78' fill='none' stroke='url(#p)' marker-end='url(#m)'/>";
    NSString* actual = [definitions stringByAppendingString:actualBody];
    NSString* expectedBody = @"<path d='M20 20L83 78' fill='none' stroke='url(#p)'/><rect x='73' "
        @"y='68' width='20' height='20' fill='url(#p)'/>";
    NSString* expected = [definitions stringByAppendingString:expectedBody];
    [self compareBody:actual withBody:expected];
    IJSVG* svg = [self svgWithBody:actual];
    for(NSNumber* options in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionAll)]) {
        NSString* exportedDocument = [svg SVGStringWithSize:CGSizeMake(128, 128) options:options.unsignedIntegerValue];
        IJSVG* exported = [[IJSVG alloc] initWithSVGString:exportedDocument];
        [self assertPixels:[self pixelsForSVG:exported]
                   equalTo:[self pixelsForSVG:[self svgWithBody:expected]]
                 tolerance:0.3];
    }
}

- (void)testRepeatedMarkerArtworkPreservesStylesAndExport
{
    NSString* artwork = @"<g opacity='.6' transform='translate(-4 -4)'><rect width='8' height='8' fill='red' "
                         "stroke='blue' stroke-width='2' stroke-dasharray='2 1'/><path d='M1 1H7V7H1ZM3 3H5V5H3Z' "
                         "fill='yellow' fill-rule='evenodd'/></g>";
    NSString* actualFormat = @"<defs><marker id='m' markerUnits='userSpaceOnUse' overflow='visible' orient='auto-start-reverse'>%@"
        "</marker></defs><path d='M20 20L80 20L80 80L20 80' fill='none' marker='url(#m)'/>";
    NSString* actual = [NSString stringWithFormat:actualFormat, artwork];
    NSString* expectedFormat = @"<g transform='translate(20 20) rotate(180)'>%@</g><g transform='translate(80 20) rotate(45)'>%@</g>"
        "<g transform='translate(80 80) rotate(135)'>%@</g><g transform='translate(20 80) rotate(180)'>%@</g>";
    NSString* expected = [NSString stringWithFormat:expectedFormat, artwork, artwork, artwork, artwork];
    IJSVG* svg = [self svgWithBody:actual];
    NSData* pixels = [self pixelsForSVG:[self svgWithBody:expected]];
    [self assertPixels:[self pixelsForSVG:svg] equalTo:pixels tolerance:0.15];
    [self assertExportsOfSVG:svg matchPixels:pixels];
    [svg setNeedsDisplay];
    [self assertPixels:[self pixelsForSVG:svg] equalTo:pixels tolerance:0.15];
}

- (void)testRepeatedContextPaintServersKeepInstanceCoordinates
{
    NSArray<NSString*>* servers = @[
        (@"<linearGradient id='p' gradientUnits='userSpaceOnUse' x2='128'><stop stop-color='red'/>"
          "<stop offset='1' stop-color='blue'/></linearGradient>"),
        (@"<pattern id='p' patternUnits='userSpaceOnUse' width='8' height='8'><rect width='4' height='8' "
          "fill='red'/><rect x='4' width='4' height='8' fill='blue'/></pattern>")
    ];
    for(NSString* server in servers) {
        NSString* definitionsFormat = @"<defs>%@<marker id='m' markerUnits='userSpaceOnUse' overflow='visible' orient='auto'>"
            "<circle r='6' fill='context-stroke'/></marker></defs>";
        NSString* definitions = [NSString stringWithFormat:definitionsFormat, server];
        NSString* actualBody = @"<path d='M20 20L80 20L80 80L20 80' fill='none' stroke='url(#p)' marker='url(#m)'/>";
        NSString* actual = [definitions stringByAppendingString:actualBody];
        NSString* expectedBody = @"<path d='M20 20L80 20L80 80L20 80' fill='none' stroke='url(#p)'/>"
            "<circle cx='20' cy='20' r='6' fill='url(#p)'/><circle cx='80' cy='20' r='6' fill='url(#p)'/>"
            "<circle cx='80' cy='80' r='6' fill='url(#p)'/><circle cx='20' cy='80' r='6' fill='url(#p)'/>";
        NSString* expected = [definitions stringByAppendingString:expectedBody];
        IJSVG* svg = [self svgWithBody:actual];
        NSData* pixels = [self pixelsForSVG:[self svgWithBody:expected]];
        [self assertPixels:[self pixelsForSVG:svg] equalTo:pixels tolerance:0.15];
        [self assertExportsOfSVG:svg matchPixels:pixels];
    }
}

- (void)testRepeatedMarkerTextAndMasks
{
    NSArray<NSString*>* artworks = @[
        @"<text x='-4' y='4' font-size='10' fill='red'>SVG</text>",
        @"<g mask='url(#mask)'><rect x='-6' y='-6' width='12' height='12' fill='blue'/></g>",
        @"<g clip-path='url(#clip)'><rect x='-6' y='-6' width='12' height='12' fill='red'/></g>"
    ];
    NSString* resources = @"<defs><mask id='mask' maskUnits='userSpaceOnUse' x='-8' y='-8' width='16' height='16'>"
                          "<circle r='5' fill='white'/></mask><clipPath id='clip'><circle r='5'/></clipPath></defs>";
    for(NSString* artwork in artworks) {
        NSString* actualFormat = @"%@<defs><marker id='m' markerUnits='userSpaceOnUse' overflow='visible' orient='auto'>%@</marker>"
            "</defs><path d='M20 20L80 20L80 80L20 80' fill='none' marker='url(#m)'/>";
        NSString* actual = [NSString stringWithFormat:actualFormat, resources, artwork];
        NSString* expectedFormat = @"%@<g transform='translate(20 20)'>%@</g><g transform='translate(80 20) rotate(45)'>%@</g>"
            "<g transform='translate(80 80) rotate(135)'>%@</g><g transform='translate(20 80) rotate(180)'>%@</g>";
        NSString* expected = [NSString stringWithFormat:expectedFormat, resources, artwork, artwork, artwork, artwork];
        [self compareBody:actual withBody:expected];
    }
}

- (void)testRepeatedMarkersRefreshAfterContextChanges
{
    NSString* document = @"<defs><marker id='m' markerUnits='userSpaceOnUse' overflow='visible'>"
                         "<circle r='4' fill='context-stroke'/></marker></defs>"
                         "<path d='M20 20L80 20L80 80L20 80' fill='none' stroke='red' marker='url(#m)'/>";
    IJSVG* svg = [self svgWithBody:document];
    NSData* before = [self pixelsForSVG:svg];
    IJSVG* expected = [self svgWithBody:[document stringByReplacingOccurrencesOfString:@"stroke='red'"
                                                                           withString:@"stroke='blue'"]];
    svg.rootNode.children.lastObject.stroke = expected.rootNode.children.lastObject.stroke;
    [svg setNeedsDisplay];
    NSData* after = [self pixelsForSVG:svg];
    XCTAssertNotEqualObjects(before, after);
    XCTAssertEqualObjects(after, [self pixelsForSVG:expected]);
}

- (void)testMarker3ProjectResource
{
    NSString* directory = @(__FILE__).stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
    NSString* path = [directory stringByAppendingPathComponent:@"IJSVGExample/marker3.svg"];
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithFilePathURL:[NSURL fileURLWithPath:path]
                                          error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(svg);
    NSData* expected = [self pixelsForSVG:[self mdnFixture:@"context-paint-expected"]];
    [self assertPixels:[self pixelsForSVG:svg] equalTo:expected tolerance:0.15];
    svg.renderingBackingScaleHelper = ^CGFloat {
        return 2.f;
    };
    [self assertPixels:[self pixelsForSVG:svg] equalTo:expected tolerance:0.15];
}

- (void)testRecursiveMarkerTerminates
{
    NSString* body = @"<defs><marker id='m' overflow='visible'><path d='M0 0L4 0' stroke='red' "
                     @"marker-end='url(#m)'/></marker></defs><path d='M20 20L80 80' marker-end='url(#m)'/>";
    NSData* pixels = [self pixelsForSVG:[self svgWithBody:body]];
    XCTAssertNotEqualObjects(pixels, [self pixelsForSVG:[self svgWithBody:@""]]);
}

@end
