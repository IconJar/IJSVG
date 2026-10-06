//
//  IJSVGArtworkFittingTests.m
//  IJSVGExampleTests
//
//  Created on 05/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <XCTest/XCTest.h>

@interface IJSVGArtworkFittingTests: XCTestCase
@end

@implementation IJSVGArtworkFittingTests

// Creates a fixed canvas for independently known geometry.
- (IJSVG*)svgWithBody:(NSString*)body
              viewBox:(NSString*)viewBox
{
    NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' "
                                                "height='32' viewBox='%@'>%@</svg>",
                                               viewBox,
                                               body];
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml
                                            error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(svg);
    svg.renderingBackingScaleHelper = ^CGFloat { return 1.f; };
    return svg;
}

// Compares geometry independently of the fitting calculation.
- (void)assertBounds:(CGRect)actual
             equalTo:(CGRect)expected
{
    XCTAssertEqualWithAccuracy(actual.origin.x, expected.origin.x, 0.001);
    XCTAssertEqualWithAccuracy(actual.origin.y, expected.origin.y, 0.001);
    XCTAssertEqualWithAccuracy(actual.size.width, expected.size.width, 0.001);
    XCTAssertEqualWithAccuracy(actual.size.height, expected.size.height, 0.001);
}

// Measures rendered alpha independently of the bounds query.
- (CGRect)paintedPixelsForSVG:(IJSVG*)svg
{
    NSError* error = nil;
    CGImageRef image = [svg newCGImageRefWithSize:CGSizeMake(128, 128)
                                          flipped:NO
                                            error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(image != NULL);
    if(image == NULL) return CGRectNull;
    NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithCGImage:image];
    CGImageRelease(image);
    CGRect bounds = CGRectNull;
    for(NSInteger y = 0; y < bitmap.pixelsHigh; y++) {
        for(NSInteger x = 0; x < bitmap.pixelsWide; x++) {
            if([bitmap colorAtX:x
                              y:y].alphaComponent > 0.1) {
                bounds = CGRectUnion(bounds, CGRectMake(x, y, 1, 1));
            }
        }
    }
    return bounds;
}

// Large translations must not shrink artwork that already fits.
- (void)testTranslatedArtworkKeepsRenderedSize
{
    IJSVG* svg = [self svgWithBody:@"<g transform='translate(-308 -307)'><path d='M312 311h24v24H312z'/>"
                                    "</g>"
                           viewBox:@"0 0 32 32"];
    CGRect expected = CGRectMake(4, 4, 24, 24);
    [self assertBounds:svg.artworkBounds
               equalTo:expected];
    CGRect original = [self paintedPixelsForSVG:svg];
    IJSVGStyle* style = [[IJSVGStyle alloc] init];
    style.lineCapStyle = IJSVGLineCapStyleRound;
    style.lineJoinStyle = IJSVGLineJoinStyleRound;
    svg.style = style;
    [svg fitArtworkToViewBox:YES];
    [self assertBounds:svg.artworkBounds
               equalTo:expected];
    XCTAssertTrue(CGRectEqualToRect([self paintedPixelsForSVG:svg], original));
    XCTAssertEqual(original.size.width, 96);
    XCTAssertEqual(original.size.height, 96);
}

// Nested transforms are measured once in root coordinates.
- (void)testNestedTransformsHaveKnownBounds
{
    IJSVG* svg = [self svgWithBody:@"<g transform='translate(4 6)'><g transform='scale(2)'><path d='M0 "
                                    "0h8v4H0z'/></g></g>"
                           viewBox:@"0 0 32 32"];
    CGRect expected = CGRectMake(4, 6, 16, 8);
    [self assertBounds:svg.artworkBounds
               equalTo:expected];
    [svg fitArtworkToViewBox:YES];
    [self assertBounds:svg.artworkBounds
               equalTo:expected];
}

// Caps contribute to bounds and repeated fitting preserves rendered size.
- (void)testSquareCapsFitAndReset
{
    IJSVG* svg = [self svgWithBody:@"<path d='M2 16H30' fill='none' stroke='black' stroke-width='8' "
                                    "stroke-linecap='square'/>"
                           viewBox:@"0 0 32 32"];
    CGRect original = CGRectMake(-2, 12, 36, 8);
    [self assertBounds:svg.artworkBounds
               equalTo:original];
    [svg fitArtworkToViewBox:YES];
    CGRect expected = CGRectMake(0, 112.0 / 9, 32, 64.0 / 9);
    [self assertBounds:svg.artworkBounds
               equalTo:expected];
    CGRect pixels = [self paintedPixelsForSVG:svg];
    XCTAssertGreaterThanOrEqual(pixels.size.width, 126);
    XCTAssertGreaterThanOrEqual(pixels.size.height, 28);
    XCTAssertLessThanOrEqual(pixels.size.height, 30);
    [svg fitArtworkToViewBox:YES];
    [self assertBounds:svg.artworkBounds
               equalTo:expected];
    XCTAssertTrue(CGRectEqualToRect([self paintedPixelsForSVG:svg], pixels));
    XCTAssertTrue(CGSizeEqualToSize(svg.size, CGSizeMake(32, 32)));
    IJSVGExporter* exporter = [svg exporterWithSize:svg.size
                                            options:0
                               floatingPointOptions:IJSVGFloatingPointOptionsDefault()];
    IJSVG* exported = [[IJSVG alloc] initWithSVGString:exporter.SVGString];
    XCTAssertNotNil(exported);
    XCTAssertGreaterThanOrEqual([self paintedPixelsForSVG:exported].size.width,
                                126);
    [svg fitArtworkToViewBox:NO];
    [self assertBounds:svg.artworkBounds
               equalTo:original];
}

// Tiny fitting scales retain enough precision to keep artwork visible.
- (void)testLargeArtworkRemainsVisible
{
    IJSVG* svg = [self svgWithBody:@"<path d='M-999984 -999984h2000000v2000000H-999984z'/>"
                           viewBox:@"0 0 32 32"];
    [svg fitArtworkToViewBox:YES];
    [self assertBounds:svg.artworkBounds
               equalTo:CGRectMake(0, 0, 32, 32)];
    CGRect pixels = [self paintedPixelsForSVG:svg];
    XCTAssertGreaterThanOrEqual(pixels.size.width, 126);
    XCTAssertGreaterThanOrEqual(pixels.size.height, 126);
}

// Fitting uses the original viewBox center even with a nonzero origin.
- (void)testOffsetViewBoxFitsFilledArtwork
{
    IJSVG* svg = [self svgWithBody:@"<path d='M6 16h40v40H6z'/>"
                           viewBox:@"10 20 32 32"];
    [svg fitArtworkToViewBox:YES];
    [self assertBounds:svg.artworkBounds
               equalTo:CGRectMake(10, 20, 32, 32)];
    XCTAssertGreaterThanOrEqual([self paintedPixelsForSVG:svg].size.width, 126);
}

// Empty artwork remains empty and retains its canvas.
- (void)testEmptyArtworkNeedsNoFitting
{
    IJSVG* svg = [self svgWithBody:@""
                           viewBox:@"0 0 32 32"];
    [svg fitArtworkToViewBox:YES];
    XCTAssertTrue(CGRectIsNull(svg.artworkBounds));
    XCTAssertTrue(CGSizeEqualToSize(svg.size, CGSizeMake(32, 32)));
    [svg fitArtworkToViewBox:NO];
    XCTAssertTrue(CGRectIsNull(svg.artworkBounds));
}

// Loads existing example artwork without duplicating resources in the test target.
- (IJSVG*)exampleSVGNamed:(NSString*)name
{
    NSString* directory = @(__FILE__).stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
    NSString* path = [[directory stringByAppendingPathComponent:@"IJSVGExample"]
                     stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"svg"]];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:path],
                  @"Missing example: %@", path);
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithFilePathURL:[NSURL fileURLWithPath:path]
                                              error:&error];
    XCTAssertNil(error, @"Could not load %@", name);
    XCTAssertNotNil(svg);
    svg.renderingBackingScaleHelper = ^CGFloat { return 1.f; };
    // Fitting measures geometry and deliberately excludes filter effects.
    IJSVGRenderingOptions* options = [[IJSVGRenderingOptions alloc] init];
    options.filtersEnabled = NO;
    svg.renderingOptions = options;
    return svg;
}

// Captures fixed format pixels for exact comparisons across repeated fitting.
- (NSData*)renderedPixelsForSVG:(IJSVG*)svg
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, 128, 128, 8, 512, space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) return nil;
    [svg drawInRect:CGRectMake(0, 0, 128, 128)
            context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context)
                                    length:128 * 512];
    CGContextRelease(context);
    return pixels;
}

// Exercises source files with several line styles and reports each case by name.
- (void)assertExampleFitting:(NSString*)name
{
    NSArray<NSString*>* styles = @[@"butt and bevel", @"round", @"square and miter"];
    for(NSUInteger index = 0; index < styles.count; index++) {
        @autoreleasepool {
            [XCTContext runActivityNamed:[NSString stringWithFormat:@"%@ / %@",
                                                                    name,
                                                                    styles[index]]
                                   block:^(id<XCTActivity> activity) {
                IJSVG* svg = [self exampleSVGNamed:name];
                if(svg == nil) return;
                CGSize size = svg.size;
                CGRect viewport = svg.viewBox;
                CGFloat dimension = MIN(viewport.size.width,
                                        viewport.size.height);
                IJSVGStyle* style = [[IJSVGStyle alloc] init];
                switch(index) {
                    case 0:
                        style.lineCapStyle = IJSVGLineCapStyleButt;
                        style.lineJoinStyle = IJSVGLineJoinStyleBevel;
                        style.lineWidth = dimension * 0.01;
                        break;
                    case 1:
                        style.lineCapStyle = IJSVGLineCapStyleRound;
                        style.lineJoinStyle = IJSVGLineJoinStyleRound;
                        style.lineWidth = dimension * 0.04;
                        break;
                    default:
                        style.lineCapStyle = IJSVGLineCapStyleSquare;
                        style.lineJoinStyle = IJSVGLineJoinStyleMiter;
                        style.lineWidth = dimension * 0.12;
                        break;
                }
                svg.style = style;
                CGRect originalBounds = svg.artworkBounds;
                NSData* originalPixels = [self renderedPixelsForSVG:svg];
                [svg fitArtworkToViewBox:YES];
                CGRect fittedBounds = svg.artworkBounds;
                XCTAssertFalse(CGRectIsEmpty(fittedBounds));
                XCTAssertFalse(CGRectIsInfinite(fittedBounds));
                CGFloat tolerance = MAX(viewport.size.width,
                                        viewport.size.height) * 1e-6;
                XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport,
                                                             -tolerance,
                                                             -tolerance),
                                                 fittedBounds),
                              @"%@ outside %@", NSStringFromRect(fittedBounds),
                              NSStringFromRect(viewport));
                XCTAssertTrue(CGSizeEqualToSize(svg.size, size));
                CGRect coverage = [self paintedPixelsForSVG:svg];
                XCTAssertFalse(CGRectIsEmpty(coverage));
                NSData* fittedPixels = [self renderedPixelsForSVG:svg];
                if(CGRectContainsRect(viewport, originalBounds)) {
                    XCTAssertEqualObjects(fittedPixels, originalPixels,
                                          @"Artwork that already fits must retain its pixels");
                }
                [svg fitArtworkToViewBox:YES];
                [self assertBounds:svg.artworkBounds
                           equalTo:fittedBounds];
                XCTAssertEqualObjects([self renderedPixelsForSVG:svg],
                                      fittedPixels);

                IJSVGExporter* exporter = [svg exporterWithSize:size
                                                        options:0
                                           floatingPointOptions:IJSVGFloatingPointOptionsMake(NO,
                                                                                            8)];
                IJSVG* exported = [[IJSVG alloc] initWithSVGString:exporter.SVGString];
                XCTAssertNotNil(exported);
                if(exported != nil) {
                    exported.renderingBackingScaleHelper = ^CGFloat { return 1.f; };
                    exported.renderingOptions = svg.renderingOptions;
                    CGRect exportedCoverage = [self paintedPixelsForSVG:exported];
                    XCTAssertFalse(CGRectIsEmpty(exportedCoverage));
                    XCTAssertEqualWithAccuracy(exportedCoverage.origin.x,
                                               coverage.origin.x, 2);
                    XCTAssertEqualWithAccuracy(exportedCoverage.origin.y,
                                               coverage.origin.y, 2);
                    XCTAssertEqualWithAccuracy(exportedCoverage.size.width,
                                               coverage.size.width, 2);
                    XCTAssertEqualWithAccuracy(exportedCoverage.size.height,
                                               coverage.size.height, 2);
                }
                [svg fitArtworkToViewBox:NO];
                [self assertBounds:svg.artworkBounds
                           equalTo:originalBounds];
                XCTAssertEqualObjects([self renderedPixelsForSVG:svg],
                                      originalPixels);
            }];
        }
    }
}

// Covers gradients on layered polygon artwork.
- (void)testPaperplaneExampleFitting
{
    [self assertExampleFitting:@"paperplane"];
}

// Covers inherited strokes and several dash patterns.
- (void)testDashedExampleFitting
{
    [self assertExampleFitting:@"dashed"];
}

// Covers skewed geometry and a negative viewBox origin.
- (void)testLinecapExampleFitting
{
    [self assertExampleFitting:@"linecap"];
}

// Covers clip paths, shared definitions, and differing viewport dimensions.
- (void)testClippedExampleFitting
{
    [self assertExampleFitting:@"clipped"];
}

// Covers transformed radial gradients.
- (void)testGradientsExampleFitting
{
    [self assertExampleFitting:@"gradients"];
}

// Covers a larger illustration with nested groups and shared resources.
- (void)testPhoneExampleFitting
{
    [self assertExampleFitting:@"htc_one"];
}

// Covers clip paths and masks while excluding filter effects from geometry checks.
- (void)testClippingAndMasksExampleFitting
{
    [self assertExampleFitting:@"dropshadow-clipping-masks"];
}

// Fitting multiple root children must preserve their order and rendered geometry.
- (void)testFittingMultipleRootChildren
{
    IJSVG* svg = [self svgWithBody:@"<path d='M-4 4h20v24H-4z'/><path d='M16 4h20v24H16z'/>"
                           viewBox:@"0 0 32 32"];
    CGRect original = CGRectMake(-4, 4, 40, 24);
    [self assertBounds:svg.artworkBounds
               equalTo:original];
    XCTAssertNoThrow([svg fitArtworkToViewBox:YES]);
    [self assertBounds:svg.artworkBounds
               equalTo:CGRectMake(0, 6.4, 32, 19.2)];
    CGRect pixels = [self paintedPixelsForSVG:svg];
    XCTAssertGreaterThanOrEqual(pixels.size.width, 126);
    XCTAssertNoThrow([svg fitArtworkToViewBox:YES]);
    XCTAssertTrue(CGRectEqualToRect([self paintedPixelsForSVG:svg], pixels));
    [svg fitArtworkToViewBox:NO];
    [self assertBounds:svg.artworkBounds
               equalTo:original];
}

@end
