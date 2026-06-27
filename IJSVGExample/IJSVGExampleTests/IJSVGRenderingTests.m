//
//  IJSVGRenderingTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGTestHelpers.h"

@interface IJSVGRenderingTests : XCTestCase
@end

@implementation IJSVGRenderingTests

- (void)testRenderingUsesPresentationAttributes
{
    NSString* svg = IJSVGTestSVG(@"<rect width=\"8\" height=\"8\" fill=\"#ff0000\"/>");
    NSColor* color = IJSVGTestColorFromSVGAtPoint(svg, CGPointMake(4.f, 4.f));

    IJSVGAssertColorComponents(color, 1.f, 0.f, 0.f, 1.f);
}

- (void)testRenderingUsesStyleSheetFill
{
    NSString* body = @"<style>.target { fill: #00ff00; }</style><rect class=\"target\" width=\"8\" height=\"8\" fill=\"#ff0000\"/>";
    NSColor* color = IJSVGTestColorFromSVGAtPoint(IJSVGTestSVG(body), CGPointMake(4.f, 4.f));

    IJSVGAssertColorComponents(color, 0.f, 1.f, 0.f, 1.f);
}

- (void)testRenderingInlineStyleOverridesStyleSheetFill
{
    NSString* body = @"<style>rect { fill: #00ff00; }</style><rect width=\"8\" height=\"8\" style=\"fill: #ff0000;\"/>";
    NSColor* color = IJSVGTestColorFromSVGAtPoint(IJSVGTestSVG(body), CGPointMake(4.f, 4.f));

    IJSVGAssertColorComponents(color, 1.f, 0.f, 0.f, 1.f);
}

- (void)testRenderingRespectsDisplayNoneFromStyleSheet
{
    NSString* body = @"<style>.hidden { display: none; }</style><rect width=\"8\" height=\"8\" fill=\"#ffffff\"/><rect class=\"hidden\" width=\"8\" height=\"8\" fill=\"#ff0000\"/>";
    NSColor* color = IJSVGTestColorFromSVGAtPoint(IJSVGTestSVG(body), CGPointMake(4.f, 4.f));

    IJSVGAssertColorComponents(color, 1.f, 1.f, 1.f, 1.f);
}

- (void)testRenderingMaintainsBasicGeometryPlacement
{
    NSString* body = @"<rect width=\"8\" height=\"8\" fill=\"#ffffff\"/><path d=\"M0 0 H4 V8 H0 Z\" fill=\"#0000ff\"/>";
    NSColor* leftColor = IJSVGTestColorFromSVGAtPoint(IJSVGTestSVG(body), CGPointMake(1.f, 4.f));
    NSColor* rightColor = IJSVGTestColorFromSVGAtPoint(IJSVGTestSVG(body), CGPointMake(6.f, 4.f));

    IJSVGAssertColorComponents(leftColor, 0.f, 0.f, 1.f, 1.f);
    IJSVGAssertColorComponents(rightColor, 1.f, 1.f, 1.f, 1.f);
}

- (void)testRenderingGeneratedImageMatchesExpectedQuadrants
{
    NSString* body = @"<rect width=\"8\" height=\"8\" fill=\"#ffffff\"/>"
        @"<path d=\"M0 0 H4 V4 H0 Z\" fill=\"#ff0000\"/>"
        @"<path d=\"M4 0 H8 V4 H4 Z\" fill=\"#00ff00\"/>"
        @"<path d=\"M0 4 H4 V8 H0 Z\" fill=\"#0000ff\"/>"
        @"<path d=\"M4 4 H8 V8 H4 Z\" fill=\"#000000\"/>";
    NSDictionary* palette = @{
        @"R": [NSColor colorWithCalibratedRed:1.f green:0.f blue:0.f alpha:1.f],
        @"G": [NSColor colorWithCalibratedRed:0.f green:1.f blue:0.f alpha:1.f],
        @"B": [NSColor colorWithCalibratedRed:0.f green:0.f blue:1.f alpha:1.f],
        @"K": [NSColor colorWithCalibratedRed:0.f green:0.f blue:0.f alpha:1.f]
    };

    IJSVGAssertRenderedSVGMatchesMap(IJSVGTestSVG(body),
                                     @[ @"RRRRGGGG",
                                        @"RRRRGGGG",
                                        @"RRRRGGGG",
                                        @"RRRRGGGG",
                                        @"BBBBKKKK",
                                        @"BBBBKKKK",
                                        @"BBBBKKKK",
                                        @"BBBBKKKK" ],
                                     palette);
}

- (void)testRenderingGeneratedImageReflectsStyleSheetMatching
{
    NSString* body = @"<style>#canvas > rect.hot { fill: #ff0000; } rect.cool { fill: #0000ff; } .hidden { display: none; }</style>"
        @"<rect width=\"8\" height=\"8\" fill=\"#ffffff\"/>"
        @"<g id=\"canvas\">"
        @"<rect class=\"hot\" x=\"0\" y=\"0\" width=\"2\" height=\"8\"/>"
        @"<rect class=\"cool\" x=\"2\" y=\"0\" width=\"2\" height=\"8\"/>"
        @"<rect class=\"hidden\" x=\"4\" y=\"0\" width=\"2\" height=\"8\" fill=\"#00ff00\"/>"
        @"</g>";
    NSDictionary* palette = @{
        @"R": [NSColor colorWithCalibratedRed:1.f green:0.f blue:0.f alpha:1.f],
        @"B": [NSColor colorWithCalibratedRed:0.f green:0.f blue:1.f alpha:1.f],
        @"W": [NSColor colorWithCalibratedRed:1.f green:1.f blue:1.f alpha:1.f]
    };

    IJSVGAssertRenderedSVGMatchesMap(IJSVGTestSVG(body),
                                     @[ @"RRBBWWWW",
                                        @"RRBBWWWW",
                                        @"RRBBWWWW",
                                        @"RRBBWWWW",
                                        @"RRBBWWWW",
                                        @"RRBBWWWW",
                                        @"RRBBWWWW",
                                        @"RRBBWWWW" ],
                                     palette);
}

- (void)testRenderingAppliesFillOpacityToGeneratedImage
{
    NSString* svg = IJSVGTestSVG(@"<rect width=\"8\" height=\"8\" fill=\"#ff0000\" fill-opacity=\"0.5\"/>");
    NSColor* color = IJSVGTestColorFromSVGAtPoint(svg, CGPointMake(4.f, 4.f));

    IJSVGAssertColorComponents(color, 0.5f, 0.f, 0.f, 0.5f);
}

- (void)testRenderingAppliesTransformsToGeneratedImage
{
    NSString* body = @"<rect width=\"8\" height=\"8\" fill=\"#ffffff\"/>"
        @"<g transform=\"translate(4,0)\"><path d=\"M0 0 H4 V8 H0 Z\" fill=\"#0000ff\"/></g>";
    NSDictionary* palette = @{
        @"B": [NSColor colorWithCalibratedRed:0.f green:0.f blue:1.f alpha:1.f],
        @"W": [NSColor colorWithCalibratedRed:1.f green:1.f blue:1.f alpha:1.f]
    };

    IJSVGAssertRenderedSVGMatchesMap(IJSVGTestSVG(body),
                                     @[ @"WWWWBBBB",
                                        @"WWWWBBBB",
                                        @"WWWWBBBB",
                                        @"WWWWBBBB",
                                        @"WWWWBBBB",
                                        @"WWWWBBBB",
                                        @"WWWWBBBB",
                                        @"WWWWBBBB" ],
                                     palette);
}

- (void)testRenderingLinearGradientProducesExpectedEndColors
{
    NSString* body = @"<defs><linearGradient id=\"fade\" x1=\"0\" y1=\"0\" x2=\"8\" y2=\"0\" gradientUnits=\"userSpaceOnUse\">"
        @"<stop offset=\"0\" stop-color=\"#ff0000\"/>"
        @"<stop offset=\"1\" stop-color=\"#0000ff\"/>"
        @"</linearGradient></defs>"
        @"<rect width=\"8\" height=\"8\" fill=\"url(#fade)\"/>";
    NSColor* leftColor = IJSVGTestColorFromSVGAtPoint(IJSVGTestSVG(body), CGPointMake(0.f, 4.f));
    NSColor* rightColor = IJSVGTestColorFromSVGAtPoint(IJSVGTestSVG(body), CGPointMake(7.f, 4.f));
    NSColor* middleColor = IJSVGTestColorFromSVGAtPoint(IJSVGTestSVG(body), CGPointMake(4.f, 4.f));
    NSColor* leftRGBColor = [leftColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
    NSColor* rightRGBColor = [rightColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
    NSColor* middleRGBColor = [middleColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];

    XCTAssertGreaterThan(leftRGBColor.redComponent, leftRGBColor.blueComponent);
    XCTAssertGreaterThan(rightRGBColor.blueComponent, rightRGBColor.redComponent);
    XCTAssertGreaterThan(middleRGBColor.redComponent, 0.2f);
    XCTAssertGreaterThan(middleRGBColor.blueComponent, 0.2f);
}

@end
