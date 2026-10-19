//
//  IJSVGRegionTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 19/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGUmbrella.h>
#import <XCTest/XCTest.h>

@interface IJSVGRegionTests : XCTestCase
@end

@implementation IJSVGRegionTests

- (IJSVG*)svgWithBody:(NSString*)body
{
    NSString* source = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' viewBox='0 0 100 100'>%@</svg>", body];
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:source error:&error];
    XCTAssertNotNil(svg);
    XCTAssertNil(error);
    return svg;
}

- (IJSVGRegion*)regionForIdentifier:(NSString*)identifier svg:(IJSVG*)svg rect:(CGRect)rect coordinateSpace:(IJSVGRegionCoordinateSpace)space
{
    NSArray<IJSVGRegion*>* regions = [svg regionsForIdentifier:identifier inRect:rect coordinateSpace:space];
    XCTAssertEqual(regions.count, 1u);
    return regions.firstObject;
}

- (void)assertRegion:(IJSVGRegion*)region hasRect:(CGRect)rect
{
    XCTAssertNotNil(region);
    XCTAssertEqual(region.rect.origin.x, rect.origin.x);
    XCTAssertEqual(region.rect.origin.y, rect.origin.y);
    XCTAssertEqual(region.rect.size.width, rect.size.width);
    XCTAssertEqual(region.rect.size.height, rect.size.height);
}

- (void)testDeepFilteredGroupsPreserveLocalBounds
{
    NSMutableString* body = [NSMutableString stringWithString:@"<defs><filter id='blur'><feGaussianBlur stdDeviation='8'/></filter></defs>"];
    for (NSUInteger index = 0; index < 100; index++) {
        [body appendFormat:@"<g id='g%lu' transform='translate(1 2)' filter='url(#blur)'>", (unsigned long)index];
    }
    [body appendString:@"<a href='https://example.org/'><rect id='shape' x='3' y='4' width='5' height='6'/></a>"];
    for (NSUInteger index = 0; index < 100; index++) {
        [body appendString:@"</g>"];
    }
    IJSVG* svg = [self svgWithBody:body];
    NSArray<IJSVGRegion*>* regions = [svg regionsInRect:CGRectMake(0, 0, 100, 100) coordinateSpace:IJSVGRegionCoordinateSpaceLocal nodeTypes:nil];
    NSUInteger groups = 0;
    for (IJSVGRegion* region in regions) {
        if ([region.identifier hasPrefix:@"g"]) {
            NSUInteger index = [[region.identifier substringFromIndex:1] integerValue];
            [self assertRegion:region hasRect:CGRectMake(102 - index, 202 - 2 * index, 5, 6)];
            groups++;
        }
    }
    XCTAssertEqual(groups, 100u);
    [self assertRegion:[self regionForIdentifier:@"shape" svg:svg rect:CGRectMake(0, 0, 100, 100) coordinateSpace:IJSVGRegionCoordinateSpaceUser] hasRect:CGRectMake(103, 204, 5, 6)];
}

- (void)testDeepFilteredViewportsPreserveLocalBounds
{
    NSMutableString* body = [NSMutableString stringWithString:@"<defs><filter id='blur'><feGaussianBlur stdDeviation='8'/></filter></defs>"];
    for (NSUInteger index = 0; index < 40; index++) {
        [body appendFormat:@"<svg id='v%lu' x='1' y='2' width='100' height='100' viewBox='0 0 100 100' filter='url(#blur)'>", (unsigned long)index];
    }
    [body appendString:@"<rect x='3' y='4' width='5' height='6'/>"];
    for (NSUInteger index = 0; index < 40; index++) {
        [body appendString:@"</svg>"];
    }
    IJSVG* svg = [self svgWithBody:body];
    NSArray<IJSVGRegion*>* regions = [svg regionsInRect:CGRectMake(0, 0, 100, 100) coordinateSpace:IJSVGRegionCoordinateSpaceLocal nodeTypes:nil];
    NSUInteger viewports = 0;
    for (IJSVGRegion* region in regions) {
        if ([region.identifier hasPrefix:@"v"]) {
            NSUInteger index = [[region.identifier substringFromIndex:1] integerValue];
            [self assertRegion:region hasRect:CGRectMake(42 - index, 82 - 2 * index, 5, 6)];
            viewports++;
        }
    }
    XCTAssertEqual(viewports, 40u);
}

- (void)testRegionStyleInheritanceRemainsIsolatedAndReflectsEdits
{
    IJSVG* svg = [self svgWithBody:@"<g fill='none'><rect id='empty' width='10' height='10'/><rect id='filled' x='20' width='10' height='10' fill='red'/><g stroke='blue' stroke-width='2'><rect id='stroked' x='40' y='10' width='10' height='10'/></g></g>"];
    CGRect rect = CGRectMake(0, 0, 100, 100);
    NSArray<IJSVGRegion*>* regions = [svg regionsInRect:rect coordinateSpace:IJSVGRegionCoordinateSpaceUser nodeTypes:@[ @(IJSVGNodeTypeRect) ]];
    XCTAssertEqual(regions.count, 2u);
    [self assertRegion:regions[0] hasRect:CGRectMake(20, 0, 10, 10)];
    [self assertRegion:regions[1] hasRect:CGRectMake(39, 9, 12, 12)];
    regions[0].node.visibility = IJSVGVisibilityHidden;
    regions = [svg regionsInRect:rect coordinateSpace:IJSVGRegionCoordinateSpaceUser nodeTypes:@[ @(IJSVGNodeTypeRect) ]];
    XCTAssertEqual(regions.count, 1u);
    XCTAssertEqualObjects(regions.firstObject.identifier, @"stroked");
}

- (void)testLocalStrokeBoundsRemainIndependentOfViewportClipping
{
    IJSVG* svg = [self svgWithBody:@"<svg id='viewport' width='20' height='20' viewBox='0 0 20 20'><g id='group' transform='translate(2 0)'><rect id='shape' x='15' y='5' width='10' height='10' stroke='black' stroke-width='4'/></g></svg>"];
    NSArray<IJSVGRegion*>* regions = [svg regionsInRect:CGRectMake(0, 0, 100, 100) coordinateSpace:IJSVGRegionCoordinateSpaceLocal nodeTypes:nil];
    XCTAssertEqual(regions.count, 4u);
    [self assertRegion:regions[0] hasRect:CGRectMake(15, 3, 5, 14)];
    [self assertRegion:regions[1] hasRect:CGRectMake(15, 3, 14, 14)];
    [self assertRegion:regions[2] hasRect:CGRectMake(13, 3, 14, 14)];
    [self assertRegion:regions[3] hasRect:CGRectMake(13, 3, 14, 14)];
}

- (void)testAnchorRegionsUseDestinationCoordinates
{
    IJSVG* svg = [self svgWithBody:@"<a href='https://example.org/' transform='translate(5 10)'><rect x='10' y='20' width='30' height='15'/></a>"];
    NSArray<IJSVGRegion*>* regions = [svg regionsInRect:CGRectMake(7, 11, 200, 200)];
    IJSVGRegion* region = regions.firstObject;
    XCTAssertEqual(regions.count, 1u);
    XCTAssertEqual(region.type, IJSVGNodeTypeAnchor);
    XCTAssertEqualObjects(region.value, @"https://example.org/");
    [self assertRegion:region hasRect:CGRectMake(37, 71, 60, 30)];
}

- (void)testAnchorRegionsRespectAspectRatioAndViewportClipping
{
    IJSVG* svg = [self svgWithBody:@"<a href='#target'><rect x='-10' y='-10' width='30' height='30'/></a>"];
    IJSVGRegion* region = [svg regionsInRect:CGRectMake(0, 0, 200, 100)].firstObject;
    XCTAssertEqualObjects(region.value, @"#target");
    [self assertRegion:region hasRect:CGRectMake(40, 0, 30, 20)];
}

- (void)testAnchorRegionsExcludeHiddenAndPlaceholderLinks
{
    IJSVG* svg = [self svgWithBody:@"<a><rect width='10' height='10'/></a>"
                                    "<a href='hidden' display='none'><rect width='10' height='10'/></a>"
                                    "<a href='transparent' opacity='0'><rect width='10' height='10'/></a>"
                                    "<a href='invisible' visibility='hidden'><rect width='10' height='10'/></a>"
                                    "<a href='empty'/><a href='outside'><rect x='110' width='10' height='10'/></a>"
                                    "<a xlink:href='../page'><rect width='10' height='10'/></a>"];
    NSArray<IJSVGRegion*>* regions = [svg regionsInRect:CGRectMake(0, 0, 100, 100)];
    XCTAssertEqual(regions.count, 1u);
    XCTAssertEqualObjects(regions.firstObject.value, @"../page");
}

- (void)testAnchorRegionsKeepSeparateUseInstances
{
    IJSVG* svg = [self svgWithBody:@"<defs><a id='link' href='#target'><rect width='10' height='20'/></a></defs>"
                                    "<use href='#link' x='5' y='10'/><use href='#link' x='40' y='50'/>"];
    NSArray<IJSVGRegion*>* regions = [svg regionsInRect:CGRectMake(0, 0, 100, 100)];
    XCTAssertEqual(regions.count, 2u);
    XCTAssertEqualObjects(regions.firstObject.value, @"#target");
    XCTAssertEqualObjects(regions.lastObject.value, @"#target");
    [self assertRegion:regions.firstObject hasRect:CGRectMake(5, 10, 10, 20)];
    [self assertRegion:regions.lastObject hasRect:CGRectMake(40, 50, 10, 20)];
}

- (void)testInlineAnchorRegionsUseOnlyLinkedGlyphs
{
    IJSVG* svg = [self svgWithBody:@"<text x='5' y='30' font-family='Helvetica' font-size='12'>before<a href='text'>link<tspan dy='15'>span</tspan></a>after</text>"];
    IJSVGRegion* region = [svg regionsInRect:CGRectMake(0, 0, 100, 100)].firstObject;
    XCTAssertNotNil(region);
    XCTAssertEqualObjects(region.value, @"text");
    XCTAssertGreaterThan(CGRectGetMinX(region.rect), 30);
    XCTAssertLessThan(CGRectGetMaxX(region.rect), 85);
    XCTAssertGreaterThan(CGRectGetMinY(region.rect), 15);
    XCTAssertGreaterThan(CGRectGetMaxY(region.rect), 40);
    IJSVGRegion* scaled = [svg regionsInRect:CGRectMake(0, 0, 200, 200)].firstObject;
    XCTAssertNotNil(scaled);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(scaled.rect), CGRectGetMinX(region.rect) * 2, 1);
    XCTAssertEqualWithAccuracy(scaled.rect.size.height, region.rect.size.height * 2, 1);
}

- (void)testAnchorRegionsRespectRectangularClipsAndIgnoreNestedLinks
{
    IJSVG* svg = [self svgWithBody:@"<defs><clipPath id='clip'><rect x='10' y='15' width='20' height='25'/></clipPath></defs>"
                                    "<a href='outer' clip-path='url(#clip)'><a href='inner'><rect width='80' height='80'/></a></a>"];
    NSArray<IJSVGRegion*>* regions = [svg regionsInRect:CGRectMake(0, 0, 100, 100)];
    XCTAssertEqual(regions.count, 1u);
    XCTAssertEqualObjects(regions.firstObject.value, @"outer");
    [self assertRegion:regions.firstObject hasRect:CGRectMake(10, 15, 20, 25)];
}

- (void)testRegionQueryRejectsInvalidDestination
{
    IJSVG* svg = [self svgWithBody:@"<a href='link'><rect width='10' height='10'/></a>"];
    XCTAssertEqual([svg regionsInRect:CGRectZero].count, 0u);
    XCTAssertEqual([svg regionsInRect:CGRectNull].count, 0u);
    XCTAssertEqual([svg regionsInRect:CGRectInfinite].count, 0u);
}

- (void)testAnchorRegionsRespectNestedViewportsAndRotation
{
    IJSVG* svg = [self svgWithBody:@"<svg x='10' y='20' width='40' height='20' viewBox='0 0 20 10'>"
                                    "<a href='nested'><rect x='5' y='2' width='5' height='3'/></a></svg>"
                                    "<a href='rotated' transform='translate(40 0) rotate(90)'><rect x='10' width='10' height='20'/></a>"];
    NSArray<IJSVGRegion*>* regions = [svg regionsInRect:CGRectMake(0, 0, 100, 100)];
    XCTAssertEqual(regions.count, 2u);
    [self assertRegion:regions.firstObject hasRect:CGRectMake(20, 24, 10, 6)];
    IJSVGRegion* rotated = regions.lastObject;
    XCTAssertNotNil(rotated);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(rotated.rect), 20, .001);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(rotated.rect), 10, .001);
    XCTAssertEqualWithAccuracy(rotated.rect.size.width, 20, .001);
    XCTAssertEqualWithAccuracy(rotated.rect.size.height, 10, .001);
}

- (void)testAnchorRegionsIncludeStrokesAndGroupChildren
{
    IJSVG* svg = [self svgWithBody:@"<a href='group'><rect x='10' y='10' width='10' height='10' fill='none' stroke='black' stroke-width='4'/><rect x='30' y='30' width='10' height='10'/></a>"];
    [self assertRegion:[svg regionsInRect:CGRectMake(0, 0, 100, 100)].firstObject hasRect:CGRectMake(8, 8, 32, 32)];
}

- (void)testRegionValuesAreImmutableSnapshots
{
    NSMutableString* value = [NSMutableString stringWithString:@"original"];
    IJSVGRegion* region = [[IJSVGRegion alloc] initWithRect:CGRectMake(1, 2, 3, 4) type:IJSVGNodeTypeAnchor value:value];
    [value setString:@"changed"];
    XCTAssertEqualObjects(region.value, @"original");
    XCTAssertEqual(region.type, IJSVGNodeTypeAnchor);
}

- (void)testNodeRegionsHaveExplicitCoordinateSpaces
{
    IJSVG* svg = [self svgWithBody:@"<g id='group' transform='translate(10 20)'><rect id='shape' x='5' y='6' width='10' height='12' transform='scale(2)'/></g>"];
    CGRect rect = CGRectMake(7, 11, 200, 200);
    IJSVGRegion* local = [self regionForIdentifier:@"shape" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceLocal];
    [self assertRegion:local hasRect:CGRectMake(5, 6, 10, 12)];
    XCTAssertEqual(local.coordinateSpace, IJSVGRegionCoordinateSpaceLocal);
    XCTAssertEqualObjects(local.identifier, @"shape");
    XCTAssertNil(local.value);
    [self assertRegion:[self regionForIdentifier:@"shape" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceUser] hasRect:CGRectMake(20, 32, 20, 24)];
    [self assertRegion:[self regionForIdentifier:@"shape" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceDestination] hasRect:CGRectMake(47, 75, 40, 48)];
    [self assertRegion:[self regionForIdentifier:@"group" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceLocal] hasRect:CGRectMake(10, 12, 20, 24)];
    XCTAssertNotNil(local.node);
    [self assertRegion:[svg regionsForNode:local.node inRect:rect coordinateSpace:IJSVGRegionCoordinateSpaceLocal].firstObject hasRect:local.rect];
}

- (void)testRegionTypeFiltersAndInstancesPreserveSourceIdentity
{
    IJSVG* svg = [self svgWithBody:@"<defs><g id='item'><rect id='shape' width='10' height='10'/></g></defs><use href='#item' x='10'/><use href='#item' x='30'/>"];
    CGRect rect = CGRectMake(0, 0, 100, 100);
    NSArray<IJSVGRegion*>* instances = [svg regionsForIdentifier:@"shape" inRect:rect coordinateSpace:IJSVGRegionCoordinateSpaceUser];
    XCTAssertEqual(instances.count, 2u);
    XCTAssertEqual(instances.firstObject.instanceIndex, 0u);
    XCTAssertEqual(instances.lastObject.instanceIndex, 1u);
    XCTAssertEqual(CGRectGetMinX(instances.firstObject.rect), 10);
    XCTAssertEqual(CGRectGetMinX(instances.lastObject.rect), 30);
    XCTAssertEqual([svg regionsInRect:rect coordinateSpace:IJSVGRegionCoordinateSpaceUser nodeTypes:@[]].count, 0u);
    NSArray<IJSVGRegion*>* shapes = [svg regionsInRect:rect coordinateSpace:IJSVGRegionCoordinateSpaceUser nodeTypes:@[ @(IJSVGNodeTypeRect) ]];
    XCTAssertEqual(shapes.count, 2u);
    for (IJSVGRegion* shape in shapes) {
        XCTAssertEqual(shape.type, IJSVGNodeTypeRect);
    }
}

- (void)testLocalRegionsDoNotInvertAncestorBounds
{
    IJSVG* svg = [self svgWithBody:@"<g transform='translate(40 40) rotate(45)'><rect id='shape' x='5' y='6' width='10' height='12'/></g>"];
    [self assertRegion:[self regionForIdentifier:@"shape" svg:svg rect:CGRectMake(0, 0, 100, 100) coordinateSpace:IJSVGRegionCoordinateSpaceLocal] hasRect:CGRectMake(5, 6, 10, 12)];
}

- (void)testUserRegionsRemainOutsideDestinationClip
{
    IJSVG* svg = [self svgWithBody:@"<rect id='outside' x='120' y='10' width='20' height='10'/>"];
    CGRect rect = CGRectMake(0, 0, 100, 100);
    XCTAssertEqual([svg regionsForIdentifier:@"outside" inRect:rect coordinateSpace:IJSVGRegionCoordinateSpaceDestination].count, 0u);
    [self assertRegion:[self regionForIdentifier:@"outside" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceUser] hasRect:CGRectMake(120, 10, 20, 10)];
}

- (void)testTextRegionsRetainOriginalTypesAndNodes
{
    IJSVG* svg = [self svgWithBody:@"<text id='text' x='5' y='30' font-size='12'>before<tspan id='span'>after</tspan></text>"];
    CGRect rect = CGRectMake(0, 0, 100, 100);
    IJSVGRegion* text = [self regionForIdentifier:@"text" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceUser];
    IJSVGRegion* span = [self regionForIdentifier:@"span" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceUser];
    XCTAssertEqual(text.type, IJSVGNodeTypeText);
    XCTAssertEqual(span.type, IJSVGNodeTypeTextSpan);
    XCTAssertTrue(CGRectContainsRect(text.rect, span.rect));
    XCTAssertNotNil(span.node);
    XCTAssertEqual([svg regionsForNode:span.node inRect:rect coordinateSpace:IJSVGRegionCoordinateSpaceUser].count, 1u);
}

- (void)testRegionSpacesHandleViewBoxOriginsAndNestedViewports
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' id='root' viewBox='20 30 100 100'><rect id='shape' x='25' y='36' width='10' height='12'/><svg id='nested' x='40' y='50' width='40' height='20' viewBox='0 0 20 10'><rect id='inner' x='5' y='2' width='5' height='3'/></svg></svg>"];
    XCTAssertNotNil(svg);
    CGRect rect = CGRectMake(7, 11, 200, 200);
    [self assertRegion:[self regionForIdentifier:@"shape" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceUser] hasRect:CGRectMake(25, 36, 10, 12)];
    [self assertRegion:[self regionForIdentifier:@"shape" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceDestination] hasRect:CGRectMake(17, 23, 20, 24)];
    [self assertRegion:[self regionForIdentifier:@"nested" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceLocal] hasRect:CGRectMake(5, 2, 5, 3)];
    [self assertRegion:[self regionForIdentifier:@"inner" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceUser] hasRect:CGRectMake(50, 54, 10, 6)];
    IJSVGRegion* root = [self regionForIdentifier:@"root" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceLocal];
    XCTAssertEqual(CGRectGetMinX(root.rect), 25);
    XCTAssertEqual(CGRectGetMinY(root.rect), 36);
}

- (void)testLocalRegionsSurviveSingularTransforms
{
    IJSVG* svg = [self svgWithBody:@"<g transform='scale(0)'><rect id='shape' x='5' y='6' width='10' height='12'/></g>"];
    CGRect rect = CGRectMake(0, 0, 100, 100);
    [self assertRegion:[self regionForIdentifier:@"shape" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceLocal] hasRect:CGRectMake(5, 6, 10, 12)];
    XCTAssertEqual([svg regionsForIdentifier:@"shape" inRect:rect coordinateSpace:IJSVGRegionCoordinateSpaceDestination].count, 0u);
}

- (void)testLocalRegionsIgnoreAncestorClipping
{
    IJSVG* svg = [self svgWithBody:@"<defs><clipPath id='clip'><rect width='10' height='10'/></clipPath></defs><g clip-path='url(#clip)'><rect id='shape' x='30' y='30' width='10' height='12'/></g>"];
    CGRect rect = CGRectMake(0, 0, 100, 100);
    [self assertRegion:[self regionForIdentifier:@"shape" svg:svg rect:rect coordinateSpace:IJSVGRegionCoordinateSpaceLocal] hasRect:CGRectMake(30, 30, 10, 12)];
    XCTAssertEqual([svg regionsForIdentifier:@"shape" inRect:rect coordinateSpace:IJSVGRegionCoordinateSpaceDestination].count, 0u);
}

@end
