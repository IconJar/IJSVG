//
//  IJSVGOutlineTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <XCTest/XCTest.h>

@interface IJSVGOutlineTests : XCTestCase
@end

@implementation IJSVGOutlineTests

- (IJSVG*)svgWithBody:(NSString*)body
{
    return [self svgWithBody:body viewBox:@"0 0 100 100"];
}

- (IJSVG*)svgWithBody:(NSString*)body viewBox:(NSString*)viewBox
{
    NSString* xml = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100' viewBox='%@'>%@</svg>",
        viewBox, body];
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(svg);
    return svg;
}

- (void)assertPath:(CGPathRef)path contains:(CGPoint)point expected:(BOOL)expected
{
    XCTAssertTrue(path != NULL);
    if(path != NULL) {
        XCTAssertEqual(CGPathContainsPoint(path, NULL, point, false), expected,
            @"Unexpected coverage at %@", NSStringFromPoint(point));
    }
}

- (void)assertPath:(CGPathRef)path bounds:(CGRect)expected
{
    XCTAssertTrue(path != NULL);
    if(path == NULL) {
        return;
    }
    CGRect actual = CGPathGetPathBoundingBox(path);
    XCTAssertEqualWithAccuracy(actual.origin.x, expected.origin.x, 0.001);
    XCTAssertEqualWithAccuracy(actual.origin.y, expected.origin.y, 0.001);
    XCTAssertEqualWithAccuracy(actual.size.width, expected.size.width, 0.001);
    XCTAssertEqualWithAccuracy(actual.size.height, expected.size.height, 0.001);
}

- (void)testEvenOddHoleAndDisconnectedIsland
{
    IJSVG* svg = [self svgWithBody:
        @"<path fill-rule='evenodd' d='M10 10h40v40H10z M20 20h20v20H20z'/>"
         "<rect x='70' y='10' width='10' height='10'/>"];
    for(NSNumber* filters in @[@NO, @YES]) {
        CGPathRef preserved = [svg outlinePathIncludingFilterExtents:filters.boolValue preservingHoles:YES];
        CGPathRef filled = [svg outlinePathIncludingFilterExtents:filters.boolValue preservingHoles:NO];
        [self assertPath:preserved contains:CGPointMake(30, 30) expected:NO];
        [self assertPath:filled contains:CGPointMake(30, 30) expected:YES];
        [self assertPath:filled contains:CGPointMake(75, 15) expected:YES];
        [self assertPath:filled contains:CGPointMake(60, 15) expected:NO];
    }
}

- (void)testNonzeroWindingAndReflectedHoles
{
    IJSVG* svg = [self svgWithBody:
        @"<g transform='translate(60 0) scale(-1 1)'>"
         "<path d='M10 10h40v40H10z M20 20v20h20V20z'/></g>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(45, 15) expected:YES];
    [self assertPath:path contains:CGPointMake(30, 30) expected:NO];
    CGPathRef filled = [svg outlinePathIncludingFilterExtents:NO preservingHoles:NO];
    [self assertPath:filled contains:CGPointMake(30, 30) expected:YES];
}

- (void)testOverlappingOppositeWindingShapesUnionWithoutCancellation
{
    IJSVG* svg = [self svgWithBody:
        @"<path d='M10 10h30v30H10z'/><path d='M20 10v30h30V10z'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:path bounds:CGRectMake(10, 10, 40, 30)];
    [self assertPath:path contains:CGPointMake(30, 25) expected:YES];
}

- (void)testHoleFillingOccursAfterUnion
{
    IJSVG* svg = [self svgWithBody:
        @"<rect x='10' y='10' width='40' height='5'/>"
         "<rect x='10' y='45' width='40' height='5'/>"
         "<rect x='10' y='15' width='5' height='30'/>"
         "<rect x='45' y='15' width='5' height='30'/>"];
    [self assertPath:[svg outlinePathIncludingFilterExtents:NO preservingHoles:YES]
           contains:CGPointMake(30, 30) expected:NO];
    [self assertPath:[svg outlinePathIncludingFilterExtents:NO preservingHoles:NO]
           contains:CGPointMake(30, 30) expected:YES];
}

- (void)testNestedTransformsAndOffsetViewBox
{
    IJSVG* svg = [self svgWithBody:
        @"<g transform='translate(10 20)'><g transform='scale(2)'>"
         "<rect x='2' y='3' width='4' height='5'/></g></g>"
        viewBox:@"10 20 100 100"];
    [self assertPath:[svg outlinePathIncludingFilterExtents:NO preservingHoles:YES]
             bounds:CGRectMake(14, 26, 8, 10)];
}

- (void)testClipUsesResolvedGeometry
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><clipPath id='c'><path d='M10 10H50V50z'/></clipPath></defs>"
         "<rect x='10' y='10' width='40' height='40' clip-path='url(#c)'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(40, 20) expected:YES];
    [self assertPath:path contains:CGPointMake(20, 40) expected:NO];
}

- (void)testObjectBoundingBoxClip
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><clipPath id='c' clipPathUnits='objectBoundingBox'>"
         "<rect width='.5' height='1'/></clipPath></defs>"
         "<rect x='20' y='30' width='40' height='20' clip-path='url(#c)'/>"];
    [self assertPath:[svg outlinePathIncludingFilterExtents:NO preservingHoles:YES]
             bounds:CGRectMake(20, 30, 20, 20)];
}

- (void)testOuterArtworkAndNestedViewportClipping
{
    IJSVG* svg = [self svgWithBody:
        @"<rect x='-10' y='10' width='5' height='5'/>"
         "<svg x='20' y='20' width='20' height='20' viewBox='0 0 10 10' overflow='hidden'>"
         "<rect x='-5' y='-5' width='20' height='20'/></svg>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(-8, 12) expected:YES];
    [self assertPath:path contains:CGPointMake(30, 30) expected:YES];
    [self assertPath:path contains:CGPointMake(45, 30) expected:NO];
}

- (void)testDashedStrokeCoverage
{
    IJSVG* svg = [self svgWithBody:
        @"<path d='M10 20H90' fill='none' stroke='black' stroke-width='4' stroke-dasharray='10 10'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(15, 20) expected:YES];
    [self assertPath:path contains:CGPointMake(25, 20) expected:NO];
    [self assertPath:path contains:CGPointMake(15, 25) expected:NO];
}

- (void)testFillAndStrokeAreUnited
{
    IJSVG* svg = [self svgWithBody:
        @"<rect x='20' y='20' width='20' height='20' fill='black' stroke='black' stroke-width='4'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(30, 30) expected:YES];
    [self assertPath:path contains:CGPointMake(19, 30) expected:YES];
    [self assertPath:path bounds:CGRectMake(18, 18, 24, 24)];
}

- (void)testVisibleAndTransparentGradients
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><linearGradient id='visible'><stop stop-color='red'/>"
         "<stop offset='1' stop-color='blue' stop-opacity='0'/></linearGradient>"
         "<linearGradient id='empty'><stop stop-opacity='0'/><stop offset='1' stop-opacity='0'/>"
         "</linearGradient></defs>"
         "<rect x='10' y='10' width='20' height='20' fill='url(#visible)'/>"
         "<rect x='60' y='10' width='20' height='20' fill='url(#empty)'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(29, 20) expected:YES];
    [self assertPath:path contains:CGPointMake(70, 20) expected:NO];
}

- (void)testVisibilityAndOpacity
{
    IJSVG* svg = [self svgWithBody:
        @"<g visibility='hidden'><rect width='20' height='20'/>"
         "<rect x='30' width='20' height='20' visibility='visible'/></g>"
         "<g opacity='0'><rect x='60' width='20' height='20'/></g>"
         "<rect y='40' width='20' height='20' display='none'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(10, 10) expected:NO];
    [self assertPath:path contains:CGPointMake(40, 10) expected:YES];
    [self assertPath:path contains:CGPointMake(70, 10) expected:NO];
    [self assertPath:path contains:CGPointMake(10, 50) expected:NO];
}

- (void)testStyleInvalidationAndRetainedPathLifetime
{
    IJSVG* svg = [self svgWithBody:
        @"<path d='M10 20H30' fill='none' stroke='black' stroke-width='4'/>"];
    CGPathRef original = CGPathRetain([svg outlinePathIncludingFilterExtents:NO preservingHoles:YES]);
    [self assertPath:original bounds:CGRectMake(10, 18, 20, 4)];
    svg.style.lineCapStyle = IJSVGLineCapStyleSquare;
    [svg setNeedsDisplay];
    [self assertPath:[svg outlinePathIncludingFilterExtents:NO preservingHoles:YES]
             bounds:CGRectMake(8, 18, 24, 4)];
    svg = nil;
    [self assertPath:original bounds:CGRectMake(10, 18, 20, 4)];
    CGPathRelease(original);
}

- (void)testBlurIsLocalAndFilterRegionClips
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='17' y='17' width='16' height='16'>"
         "<feGaussianBlur stdDeviation='2'/></filter></defs>"
         "<rect x='20' y='20' width='10' height='10' filter='url(#f)'/>"
         "<rect x='70' y='70' width='10' height='10'/>"];
    CGPathRef geometry = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    CGPathRef filtered = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    [self assertPath:geometry contains:CGPointMake(18, 25) expected:NO];
    [self assertPath:filtered contains:CGPointMake(18, 25) expected:YES];
    [self assertPath:filtered contains:CGPointMake(16, 25) expected:NO];
    [self assertPath:filtered contains:CGPointMake(69, 75) expected:NO];
    [self assertPath:filtered contains:CGPointMake(75, 75) expected:YES];
}

- (void)testOffsetShadowKeepsSourceAndTranslatedCopy
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='100' height='100'>"
         "<feDropShadow dx='20' dy='10' stdDeviation='0'/></filter></defs>"
         "<rect x='10' y='10' width='10' height='10' filter='url(#f)'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(15, 15) expected:YES];
    [self assertPath:path contains:CGPointMake(35, 25) expected:YES];
    [self assertPath:path contains:CGPointMake(25, 20) expected:NO];
    [self assertPath:path bounds:CGRectMake(10, 10, 30, 20)];
}

- (void)testFilteredGroupTransformsObjectBoundingBoxOffsets
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' primitiveUnits='objectBoundingBox'"
         " x='0' y='0' width='100' height='100'>"
         "<feDropShadow dx='1' dy='1' stdDeviation='0'/></filter></defs>"
         "<g transform='translate(5 7) scale(2)' filter='url(#f)'>"
         "<rect x='10' y='10' width='20' height='10'/></g>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(45, 37) expected:YES];
    [self assertPath:path contains:CGPointMake(85, 57) expected:YES];
    [self assertPath:path bounds:CGRectMake(25, 27, 80, 40)];
}

- (void)testUnknownFilterInputUsesPreviousResultLikeRenderer
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='100' height='100'>"
         "<feOffset dx='10'/><feOffset in='missing' dx='20'/></filter></defs>"
         "<rect x='10' y='20' width='10' height='10' filter='url(#f)'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    [self assertPath:path bounds:CGRectMake(40, 20, 10, 10)];
}

- (void)testNamedShadowBranches
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='100' height='100'>"
         "<feOffset in='SourceAlpha' dx='30' result='shadow'/>"
         "<feMerge><feMergeNode in='shadow'/><feMergeNode in='SourceGraphic'/></feMerge>"
         "</filter></defs><rect x='10' y='10' width='10' height='10' filter='url(#f)'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(15, 15) expected:YES];
    [self assertPath:path contains:CGPointMake(45, 15) expected:YES];
    [self assertPath:path contains:CGPointMake(30, 15) expected:NO];
}

- (void)testEmptySupportedArtworkReturnsPath
{
    for(NSString* body in @[@"", @"<rect width='20' height='20' fill='none'/>",
                            @"<rect width='20' height='20' opacity='0'/>"]) {
        IJSVG* svg = [self svgWithBody:body];
        for(NSNumber* filters in @[@NO, @YES]) {
            for(NSNumber* holes in @[@NO, @YES]) {
                CGPathRef path = [svg outlinePathIncludingFilterExtents:filters.boolValue
                                                      preservingHoles:holes.boolValue];
                XCTAssertTrue(path != NULL);
                if(path != NULL) XCTAssertTrue(CGPathIsEmpty(path));
            }
        }
    }
}

- (void)testTransparentFloodHasNoCoverage
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f'><feFlood flood-color='transparent'/></filter></defs>"
         "<rect x='10' y='10' width='20' height='20' filter='url(#f)'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    XCTAssertTrue(path != NULL);
    if(path != NULL) XCTAssertTrue(CGPathIsEmpty(path));
}

- (void)testFloodOpacityUnitsAndDefaults
{
    NSArray<NSString*>* attributes = [[NSArray alloc] initWithObjects:
        @"", @"flood-opacity='50%'", @"flood-opacity='0%'",
        @"flood-opacity='0'", @"flood-opacity='invalid'",
        @"flood-opacity='0 1'", @"flood-opacity='0px'", nil];
    for(NSUInteger index = 0; index < attributes.count; index++) {
        NSString* body = [NSString stringWithFormat:
            @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='100' height='100'>"
             "<feFlood %@/></filter></defs>"
             "<rect x='10' y='10' width='20' height='20' filter='url(#f)'/>", attributes[index]];
        IJSVG* svg = [self svgWithBody:body];
        BOOL visible = index != 2 && index != 3;
        for(NSUInteger holes = 0; holes < 2; holes++) {
            CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:holes != 0];
            [self assertPath:path contains:CGPointMake(50, 50) expected:visible];
            if(!visible && path != NULL) XCTAssertTrue(CGPathIsEmpty(path));
        }
    }
}

- (void)testTransparentShadowDoesNotExpandCoverage
{
    NSArray<NSString*>* attributes = [[NSArray alloc] initWithObjects:
        @"flood-color='transparent'", @"flood-color='rgba(0,0,0,0)'",
        @"flood-opacity='0%'", nil];
    for(NSString* attribute in attributes) {
        NSString* body = [NSString stringWithFormat:
            @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='100' height='100'>"
             "<feDropShadow dx='30' dy='20' stdDeviation='5' %@/></filter></defs>"
             "<rect x='10' y='10' width='20' height='20' filter='url(#f)'/>", attribute];
        IJSVG* svg = [self svgWithBody:body];
        CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
        [self assertPath:path bounds:CGRectMake(10, 10, 20, 20)];
    }
}

- (void)testMasksNeverReturnPartialArtwork
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><mask id='m'><rect width='100' height='100' fill='white'/></mask></defs>"
         "<rect width='20' height='20'/><rect x='40' width='20' height='20' mask='url(#m)'/>"];
    for(NSNumber* filters in @[@NO, @YES]) {
        XCTAssertTrue([svg outlinePathIncludingFilterExtents:filters.boolValue preservingHoles:YES] == NULL);
        XCTAssertTrue([svg outlinePathIncludingFilterExtents:filters.boolValue preservingHoles:NO] == NULL);
    }
}

- (void)testBitmapNeverReturnsPartialArtwork
{
    NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:2 pixelsHigh:2 bitsPerSample:8
        samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
        bytesPerRow:0 bitsPerPixel:0];
    [bitmap setColor:NSColor.blackColor atX:0 y:0];
    NSData* png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSString* body = [NSString stringWithFormat:
        @"<rect width='20' height='20'/><image x='40' width='20' height='20' href='data:image/png;base64,%@'/>",
        [png base64EncodedStringWithOptions:0]];
    IJSVG* svg = [self svgWithBody:body];
    XCTAssertTrue([svg outlinePathIncludingFilterExtents:NO preservingHoles:YES] == NULL);
    XCTAssertTrue([svg outlinePathIncludingFilterExtents:YES preservingHoles:NO] == NULL);
}

- (void)testUnsupportedFilterIsIgnoredOnlyWhenRequested
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f'><feTurbulence baseFrequency='.1'/></filter></defs>"
         "<rect width='20' height='20'/><rect x='40' width='20' height='20' filter='url(#f)'/>"];
    XCTAssertTrue([svg outlinePathIncludingFilterExtents:YES preservingHoles:YES] == NULL);
    [self assertPath:[svg outlinePathIncludingFilterExtents:NO preservingHoles:YES]
           contains:CGPointMake(50, 10) expected:YES];
}

- (void)testFourCacheModesInvalidateTogether
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='100' height='100'>"
         "<feDropShadow dx='50' dy='0' stdDeviation='0'/></filter></defs>"
         "<path filter='url(#f)' fill-rule='evenodd' d='M10 10h30v30H10z M20 20h10v10H20z'/>"];
    for(NSNumber* filters in @[@NO, @YES]) {
        for(NSNumber* holes in @[@NO, @YES]) {
            CGPathRef path = [svg outlinePathIncludingFilterExtents:filters.boolValue preservingHoles:holes.boolValue];
            XCTAssertEqual(path, [svg outlinePathIncludingFilterExtents:filters.boolValue preservingHoles:holes.boolValue]);
            [self assertPath:path contains:CGPointMake(25, 25) expected:!holes.boolValue];
            [self assertPath:path contains:CGPointMake(65, 15) expected:filters.boolValue];
        }
    }
    svg.rootNode.shouldRender = NO;
    [svg setNeedsDisplay];
    for(NSNumber* filters in @[@NO, @YES]) {
        for(NSNumber* holes in @[@NO, @YES]) {
            CGPathRef path = [svg outlinePathIncludingFilterExtents:filters.boolValue preservingHoles:holes.boolValue];
            XCTAssertTrue(path != NULL);
            if(path != NULL) XCTAssertTrue(CGPathIsEmpty(path));
        }
    }
}

- (void)testCoveredFilterRegionIsRedundant
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='25' y='25' width='20' height='20'>"
         "<feGaussianBlur stdDeviation='2'/></filter></defs>"
         "<rect x='30' y='30' width='10' height='10' filter='url(#f)'/>"
         "<rect x='10' y='10' width='70' height='70'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    [self assertPath:path bounds:CGRectMake(10, 10, 70, 70)];
    [self assertPath:path contains:CGPointMake(35, 35) expected:YES];
    [self assertPath:path contains:CGPointMake(9, 35) expected:NO];
}

- (void)testCoveringBoundsDoNotHideFilterInsideHole
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='35' y='35' width='30' height='30'>"
         "<feGaussianBlur stdDeviation='2'/></filter></defs>"
         "<path fill-rule='evenodd' d='M0 0h100v100H0z M20 20h60v60H20z'/>"
         "<rect x='40' y='40' width='20' height='20' filter='url(#f)'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(50, 50) expected:YES];
    [self assertPath:path contains:CGPointMake(38, 50) expected:YES];
    [self assertPath:path contains:CGPointMake(25, 50) expected:NO];
}

- (void)testCoveredUnsupportedContentStillReturnsNil
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f'><feTurbulence baseFrequency='.1'/></filter>"
         "<mask id='m'><rect width='100' height='100' fill='white'/></mask></defs>"
         "<rect width='100' height='100'/>"
         "<rect x='20' y='20' width='10' height='10' filter='url(#f)'/>"];
    XCTAssertTrue([svg outlinePathIncludingFilterExtents:YES preservingHoles:NO] == NULL);
    IJSVG* masked = [self svgWithBody:
        @"<defs><mask id='m'><rect width='100' height='100' fill='white'/></mask></defs>"
         "<rect width='100' height='100'/>"
         "<rect x='20' y='20' width='10' height='10' mask='url(#m)'/>"];
    XCTAssertTrue([masked outlinePathIncludingFilterExtents:NO preservingHoles:NO] == NULL);
}

- (void)testCurvedHoleAtLargeCoordinates
{
    IJSVG* svg = [self svgWithBody:
        @"<g transform='translate(1000000 1000000)'>"
         "<path fill-rule='evenodd' d='M10 30A20 20 0 1 0 50 30A20 20 0 1 0 10 30Z "
         "M20 30A10 10 0 1 0 40 30A10 10 0 1 0 20 30Z'/></g>"
        viewBox:@"1000000 1000000 100 100"];
    [self assertPath:[svg outlinePathIncludingFilterExtents:NO preservingHoles:YES]
           contains:CGPointMake(1000030, 1000030) expected:NO];
    CGPathRef filled = [svg outlinePathIncludingFilterExtents:NO preservingHoles:NO];
    [self assertPath:filled contains:CGPointMake(1000030, 1000030) expected:YES];
    [self assertPath:filled contains:CGPointMake(1000005, 1000030) expected:NO];
}

- (void)testBlurKeepsCurvedSourceAndExpandsConservatively
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='100' height='100'>"
         "<feGaussianBlur stdDeviation='2'/></filter></defs>"
         "<circle cx='50' cy='50' r='10' filter='url(#f)'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(50, 50) expected:YES];
    [self assertPath:path contains:CGPointMake(64, 50) expected:YES];
    [self assertPath:path contains:CGPointMake(90, 50) expected:NO];
}

- (void)testParallelFilterOutlinesPreserveHolesAndRebuildDeterministically
{
    NSMutableString* body = [[NSMutableString alloc] initWithString:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='-10' y='-10' width='20' height='20'>"
         "<feGaussianBlur stdDeviation='.1'/></filter></defs>"];
    for(NSUInteger index = 0; index < 32; index++) {
        [body appendFormat:
            @"<g transform='translate(%lu %lu)' filter='url(#f)'>"
             "<path fill-rule='evenodd' d='M-4 0A4 4 0 1 0 4 0A4 4 0 1 0-4 0Z "
             "M-2 0A2 2 0 1 0 2 0A2 2 0 1 0-2 0Z'/></g>",
            8 + (index % 8) * 12, 8 + (index / 8) * 24];
    }
    IJSVG* svg = [self svgWithBody:body];
    CGPathRef first = CGPathRetain([svg outlinePathIncludingFilterExtents:YES preservingHoles:YES]);
    for(NSUInteger index = 0; index < 32; index++) {
        CGFloat x = 8 + (index % 8) * 12;
        CGFloat y = 8 + (index / 8) * 24;
        [self assertPath:first contains:CGPointMake(x, y) expected:NO];
        [self assertPath:first contains:CGPointMake(x + 4.2, y) expected:YES];
        [self assertPath:first contains:CGPointMake(x + 6, y) expected:NO];
    }
    [svg setNeedsDisplay];
    CGPathRef rebuilt = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    XCTAssertTrue(first != NULL && rebuilt != NULL && CGPathEqualToPath(first, rebuilt));
    CGPathRef filled = [svg outlinePathIncludingFilterExtents:YES preservingHoles:NO];
    [self assertPath:filled contains:CGPointMake(8, 8) expected:YES];
    CGPathRelease(first);
}

- (void)testBlurOfDegenerateFillHasNoCoverage
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f'><feGaussianBlur stdDeviation='2'/></filter></defs>"
         "<path d='M10 10L50 50L10 10Z' filter='url(#f)'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    XCTAssertTrue(path != NULL && CGPathIsEmpty(path));
}

- (void)testParallelFilteredNodesRespectEmptyClips
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f'><feGaussianBlur stdDeviation='1'/></filter>"
         "<clipPath id='empty'><path d='M0 0'/></clipPath></defs>"
         "<g clip-path='url(#empty)'>"
         "<circle cx='10' cy='10' r='4' filter='url(#f)'/>"
         "<circle cx='30' cy='10' r='4' filter='url(#f)'/>"
         "<circle cx='50' cy='10' r='4' filter='url(#f)'/>"
         "<circle cx='70' cy='10' r='4' filter='url(#f)'/></g>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    XCTAssertTrue(path != NULL && CGPathIsEmpty(path));
}

- (void)testTinyFilledContourRetainsBlurCoverage
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='100' height='100'>"
         "<feGaussianBlur stdDeviation='10'/></filter></defs>"
         "<circle cx='50' cy='50' r='.01' filter='url(#f)'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:YES preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(50, 50) expected:YES];
    [self assertPath:path contains:CGPointMake(70, 50) expected:YES];
}

- (void)testLateBackgroundCoversContainedShapesButKeepsOutsideStroke
{
    NSMutableString* body = [[NSMutableString alloc] initWithString:@"<g transform='translate(15 15)'>"];
    for(NSUInteger index = 0; index < 64; index++) {
        [body appendFormat:@"<circle cx='%lu' cy='%lu' r='1'/>",
            2 + index % 8 * 4, 2 + index / 8 * 4];
    }
    [body appendString:
        @"</g><path d='M55 35h15' fill='none' stroke='black' stroke-width='6' stroke-linecap='square'/>"
         "<rect x='10' y='10' width='50' height='50'/>"];
    IJSVG* svg = [self svgWithBody:body];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(30, 30) expected:YES];
    [self assertPath:path contains:CGPointMake(72, 35) expected:YES];
    [self assertPath:path contains:CGPointMake(72, 40) expected:NO];
}

- (void)testRotatedBackgroundBoundsDoNotHideOutsideShapes
{
    IJSVG* svg = [self svgWithBody:
        @"<circle cx='30' cy='30' r='2'/>"
         "<rect x='30' y='30' width='40' height='40' transform='rotate(45 50 50)'/>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(30, 30) expected:YES];
    [self assertPath:path contains:CGPointMake(50, 50) expected:YES];
    [self assertPath:path contains:CGPointMake(25, 25) expected:NO];
}

- (void)testBackgroundDoesNotHideNestedVisibleOverflow
{
    IJSVG* svg = [self svgWithBody:
        @"<rect width='60' height='60'/>"
         "<svg x='20' y='20' width='20' height='20' viewBox='0 0 20 20' overflow='visible'>"
         "<circle cx='60' cy='10' r='3'/></svg>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:path contains:CGPointMake(80, 30) expected:YES];
    [self assertPath:path contains:CGPointMake(70, 30) expected:NO];
}

- (void)testNonScalingStrokeUsesClientViewportAndInvalidatesWithSize
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:
        @"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'>"
         "<path d='M10 50H40' transform='scale(2 1)' fill='none' stroke='black' "
         "stroke-width='4' vector-effect='non-scaling-stroke'/></svg>"];
    svg.rootNode.clientSize = CGSizeMake(200, 200);
    CGPathRef first = CGPathRetain([svg outlinePathIncludingFilterExtents:NO preservingHoles:YES]);
    [self assertPath:first bounds:CGRectMake(20, 49, 60, 2)];
    svg.rootNode.clientSize = CGSizeMake(100, 100);
    CGPathRef second = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:second bounds:CGRectMake(20, 48, 60, 4)];
    CGPathRelease(first);
}

- (void)testChangingClientSizeInvalidatesPercentageGeometry
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='100%' height='100%'>"
         "<rect width='50%' height='50%'/></svg>"];
    XCTAssertNotNil(svg);
    svg.rootNode.clientSize = CGSizeMake(100, 100);
    CGPathRef first = CGPathRetain([svg outlinePathIncludingFilterExtents:NO preservingHoles:YES]);
    svg.rootNode.clientSize = CGSizeMake(200, 200);
    CGPathRef second = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    [self assertPath:first bounds:CGRectMake(0, 0, 50, 50)];
    [self assertPath:second bounds:CGRectMake(0, 0, 100, 100)];
    CGPathRelease(first);
}

@end
