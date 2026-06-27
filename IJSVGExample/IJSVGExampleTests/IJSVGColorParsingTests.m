//
//  IJSVGColorParsingTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGTestHelpers.h"
#import <IJSVG/IJSVGColor.h>

@interface IJSVGColorParsingTests : XCTestCase
@end

@implementation IJSVGColorParsingTests

- (NSColor*)deviceRGBColor:(NSColor*)color
{
    return [color colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
}

- (void)assertColor:(NSColor*)color
                red:(CGFloat)red
              green:(CGFloat)green
               blue:(CGFloat)blue
              alpha:(CGFloat)alpha
{
    NSColor* converted = [self deviceRGBColor:color];
    XCTAssertEqualWithAccuracy(converted.redComponent, red, 0.002f);
    XCTAssertEqualWithAccuracy(converted.greenComponent, green, 0.002f);
    XCTAssertEqualWithAccuracy(converted.blueComponent, blue, 0.002f);
    XCTAssertEqualWithAccuracy(converted.alphaComponent, alpha, 0.002f);
}

- (void)testColorFromStringParsesSixDigitHEX
{
    NSColor* color = [IJSVGColor colorFromString:@"#336699"];

    [self assertColor:color
                  red:0x33 / 255.f
                green:0x66 / 255.f
                 blue:0x99 / 255.f
                alpha:1.f];
}

- (void)testColorFromStringParsesThreeDigitHEX
{
    NSColor* color = [IJSVGColor colorFromString:@"#3A7"];

    [self assertColor:color
                  red:0x33 / 255.f
                green:0xAA / 255.f
                 blue:0x77 / 255.f
                alpha:1.f];
}

- (void)testColorFromStringParsesEightDigitHEXWithAlpha
{
    BOOL containsAlpha = NO;
    NSColor* color = [IJSVGColor colorFromHEXString:@"#33669980"
                             containsAlphaComponent:&containsAlpha];

    XCTAssertTrue(containsAlpha);
    [self assertColor:color
                  red:0x33 / 255.f
                green:0x66 / 255.f
                 blue:0x99 / 255.f
                alpha:0x80 / 255.f];
}

- (void)testColorFromStringParsesFourDigitHEXWithAlpha
{
    BOOL containsAlpha = NO;
    NSColor* color = [IJSVGColor colorFromHEXString:@"#3A78"
                             containsAlphaComponent:&containsAlpha];

    XCTAssertTrue(containsAlpha);
    [self assertColor:color
                  red:0x33 / 255.f
                green:0xAA / 255.f
                 blue:0x77 / 255.f
                alpha:0x88 / 255.f];
}

- (void)testColorFromStringParsesNamedColorsCaseInsensitively
{
    NSColor* color = [IJSVGColor colorFromString:@"  CornFlowerBlue  "];

    [self assertColor:color
                  red:0x64 / 255.f
                green:0x95 / 255.f
                 blue:0xED / 255.f
                alpha:1.f];
}

- (void)testColorFromStringParsesRGBIntegerComponents
{
    NSColor* color = [IJSVGColor colorFromString:@"rgb(51, 102, 153)"];

    [self assertColor:color
                  red:51.f / 255.f
                green:102.f / 255.f
                 blue:153.f / 255.f
                alpha:1.f];
}

- (void)testColorFromStringParsesRGBPercentageComponents
{
    NSColor* color = [IJSVGColor colorFromString:@"rgb(20%, 40%, 60%)"];

    [self assertColor:color
                  red:0.2f
                green:0.4f
                 blue:0.6f
                alpha:1.f];
}

- (void)testColorFromStringParsesRGBAAlphaAsNumber
{
    NSColor* color = [IJSVGColor colorFromString:@"rgba(51, 102, 153, .5)"];

    [self assertColor:color
                  red:51.f / 255.f
                green:102.f / 255.f
                 blue:153.f / 255.f
                alpha:0.5f];
}

- (void)testColorFromStringFallsBackToBlackForIncompleteRGB
{
    NSColor* color = [IJSVGColor colorFromString:@"rgb(51, 102)"];

    [self assertColor:color
                  red:0.f
                green:0.f
                 blue:0.f
                alpha:1.f];
}

- (void)testColorFromStringParsesHSLAndHSLA
{
    NSColor* green = [IJSVGColor colorFromString:@"hsl(120, 100%, 50%)"];
    NSColor* translucentBlue = [IJSVGColor colorFromString:@"hsla(240, 100%, 50%, .25)"];

    [self assertColor:green
                  red:0.f
                green:1.f
                 blue:0.f
                alpha:1.f];
    [self assertColor:translucentBlue
                  red:0.f
                green:0.f
                 blue:1.f
                alpha:0.25f];
}

- (void)testColorFromStringParsesOKLCHWithAlpha
{
    NSColor* color = [IJSVGColor colorFromString:@"oklch(62.8% 0.25 29.23 / 50%)"];

    XCTAssertNotNil(color);
    XCTAssertEqualWithAccuracy([self deviceRGBColor:color].alphaComponent, 0.5f, 0.002f);
}

- (void)testColorFromStringRejectsInvalidOKLCHInput
{
    XCTAssertNil([IJSVGColor colorFromString:@"oklch(62.8% 0.25)"]);
    XCTAssertNil([IJSVGColor colorFromString:@"oklch(nope 0.25 29.23)"]);
}

- (void)testNoneTransparentEmptyAndUnknownColorsReturnNil
{
    XCTAssertNil([IJSVGColor colorFromString:nil]);
    XCTAssertNil([IJSVGColor colorFromString:@""]);
    XCTAssertNil([IJSVGColor colorFromString:@"none"]);
    XCTAssertNil([IJSVGColor colorFromString:@"transparent"]);
    XCTAssertNil([IJSVGColor colorFromString:@"not-a-real-color"]);
    XCTAssertTrue([IJSVGColor isNoneOrTransparent:@"none"]);
    XCTAssertTrue([IJSVGColor isNoneOrTransparent:@"transparent"]);
    XCTAssertFalse([IJSVGColor isNoneOrTransparent:@"red"]);
}

- (void)testColorStringFromColorUsesShorthandWhenAllowed
{
    NSColor* color = [NSColor colorWithDeviceRed:0x33 / 255.f
                                           green:0xAA / 255.f
                                            blue:0x77 / 255.f
                                           alpha:1.f];

    XCTAssertEqualObjects([IJSVGColor colorStringFromColor:color], @"#3A7");
}

- (void)testColorStringFromColorSerializesAlphaAsRGBAByDefault
{
    NSColor* color = [NSColor colorWithDeviceRed:51.f / 255.f
                                           green:102.f / 255.f
                                            blue:153.f / 255.f
                                           alpha:0.5f];

    XCTAssertEqualObjects([IJSVGColor colorStringFromColor:color], @"rgba(51,102,153,.5)");
}

- (void)testColorStringFromColorCanForceRRGGBBAAOutput
{
    NSColor* color = [NSColor colorWithDeviceRed:0x33 / 255.f
                                           green:0x66 / 255.f
                                            blue:0x99 / 255.f
                                           alpha:0x80 / 255.f];
    IJSVGColorStringOptions options = IJSVGColorStringOptionAllowRRGGBBAA;

    XCTAssertEqualObjects([IJSVGColor colorStringFromColor:color
                                                   options:options], @"#33669980");
}

- (void)testChangeAlphaKeepsRGBComponents
{
    NSColor* color = [IJSVGColor colorFromString:@"#336699"];
    NSColor* changed = [IJSVGColor changeAlphaOnColor:color
                                                   to:0.25f];

    [self assertColor:changed
                  red:0x33 / 255.f
                green:0x66 / 255.f
                 blue:0x99 / 255.f
                alpha:0.25f];
}

- (void)testParserCreatesColorNodesForFillStrokeAndNone
{
    NSString* body = @"<rect id=\"a\" width=\"5\" height=\"5\" fill=\"#336699\" stroke=\"rgba(255,0,0,.5)\"/><rect id=\"b\" x=\"5\" width=\"5\" height=\"5\" fill=\"none\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body)
                                                         fileURL:nil
                                                           error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(10.f, 5.f)];
    IJSVGPath* first = (IJSVGPath*)rootNode.children[0];
    IJSVGPath* second = (IJSVGPath*)rootNode.children[1];
    IJSVGColorNode* fill = (IJSVGColorNode*)first.fill;
    IJSVGColorNode* stroke = (IJSVGColorNode*)first.stroke;
    IJSVGColorNode* noneFill = (IJSVGColorNode*)second.fill;

    XCTAssertTrue([fill isKindOfClass:IJSVGColorNode.class]);
    XCTAssertTrue([stroke isKindOfClass:IJSVGColorNode.class]);
    XCTAssertTrue([noneFill isKindOfClass:IJSVGColorNode.class]);
    [self assertColor:fill.color
                  red:0x33 / 255.f
                green:0x66 / 255.f
                 blue:0x99 / 255.f
                alpha:1.f];
    [self assertColor:stroke.color
                  red:1.f
                green:0.f
                 blue:0.f
                alpha:0.5f];
    XCTAssertNil(noneFill.color);
    XCTAssertTrue(noneFill.isNoneOrTransparent);
}

- (void)testParserAppliesStopColorAndStopOpacityToGradientStops
{
    NSString* body = @"<defs><linearGradient id=\"g\"><stop offset=\"0\" stop-color=\"#336699\" stop-opacity=\"25%\"/><stop offset=\"1\" stop-color=\"hsl(120,100%,50%)\"/></linearGradient></defs><rect width=\"10\" height=\"10\" fill=\"url(#g)\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body)
                                                         fileURL:nil
                                                           error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(10.f, 10.f)];
    IJSVGPath* rect = (IJSVGPath*)rootNode.children.firstObject;
    IJSVGLinearGradient* gradient = (IJSVGLinearGradient*)rect.fill;
    IJSVGStop* firstStop = (IJSVGStop*)gradient.children[0];
    IJSVGStop* secondStop = (IJSVGStop*)gradient.children[1];
    IJSVGColorNode* firstColor = (IJSVGColorNode*)firstStop.fill;
    IJSVGColorNode* secondColor = (IJSVGColorNode*)secondStop.fill;

    [self assertColor:firstColor.color
                  red:0x33 / 255.f
                green:0x66 / 255.f
                 blue:0x99 / 255.f
                alpha:0.25f];
    [self assertColor:secondColor.color
                  red:0.f
                green:1.f
                 blue:0.f
                alpha:1.f];
}

@end
