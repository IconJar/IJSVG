//
//  IJSVGColorParsingTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>
#import <IJSVGTestHelpers.h>

@interface IJSVGColorParsingTests : XCTestCase
@end

@implementation IJSVGColorParsingTests

- (CGColorRef)deviceRGBColor:(CGColorRef)color
{
    return [IJSVGColor computeColorSpace:color];
}

- (void)assertColor:(CGColorRef)color red:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
    CGColorRef converted = [self deviceRGBColor:color];
    XCTAssertEqualWithAccuracy(CGColorGetComponents(converted)[0], red, 0.002f);
    XCTAssertEqualWithAccuracy(CGColorGetComponents(converted)[1], green, 0.002f);
    XCTAssertEqualWithAccuracy(CGColorGetComponents(converted)[2], blue, 0.002f);
    XCTAssertEqualWithAccuracy(CGColorGetAlpha(converted), alpha, 0.002f);
}

- (void)testAlphaHEXColorsPreserveLeadingZeros
{
    NSArray<NSString*>* values = @[ @"#00FF00A0", @"#0000FFA0", @"#00000080", @"#00000000", @"#0F0A", @"#00FA", @"#0008", @"#0000" ];
    const CGFloat components[][4] = { { 0, 1, 0, 160.f / 255 }, { 0, 0, 1, 160.f / 255 }, { 0, 0, 0, 128.f / 255 }, { 0, 0, 0, 0 }, { 0, 1, 0, 170.f / 255 }, { 0, 0, 1, 170.f / 255 }, { 0, 0, 0, 136.f / 255 }, { 0, 0, 0, 0 } };
    for (NSUInteger index = 0; index < values.count; index++) {
        BOOL alpha = NO;
        CGColorRef color = [IJSVGColor colorFromHEXString:values[index] containsAlphaComponent:&alpha];
        XCTAssertTrue(alpha, @"%@", values[index]);
        [self assertColor:color red:components[index][0] green:components[index][1] blue:components[index][2] alpha:components[index][3]];
    }
}

- (void)testColorFromStringParsesSixDigitHEX
{
    CGColorRef color = [IJSVGColor colorFromString:@"#336699"];

    [self assertColor:color red:0x33 / 255.f green:0x66 / 255.f blue:0x99 / 255.f alpha:1.f];
}

- (void)testColorFromStringParsesThreeDigitHEX
{
    CGColorRef color = [IJSVGColor colorFromString:@"#3A7"];

    [self assertColor:color red:0x33 / 255.f green:0xAA / 255.f blue:0x77 / 255.f alpha:1.f];
}

- (void)testColorFromStringParsesEightDigitHEXWithAlpha
{
    BOOL containsAlpha = NO;
    CGColorRef color = [IJSVGColor colorFromHEXString:@"#33669980" containsAlphaComponent:&containsAlpha];

    XCTAssertTrue(containsAlpha);
    [self assertColor:color red:0x33 / 255.f green:0x66 / 255.f blue:0x99 / 255.f alpha:0x80 / 255.f];
}

- (void)testColorFromStringParsesFourDigitHEXWithAlpha
{
    BOOL containsAlpha = NO;
    CGColorRef color = [IJSVGColor colorFromHEXString:@"#3A78" containsAlphaComponent:&containsAlpha];

    XCTAssertTrue(containsAlpha);
    [self assertColor:color red:0x33 / 255.f green:0xAA / 255.f blue:0x77 / 255.f alpha:0x88 / 255.f];
}

- (void)testColorFromStringParsesNamedColorsCaseInsensitively
{
    CGColorRef color = [IJSVGColor colorFromString:@"  CornFlowerBlue  "];

    [self assertColor:color red:0x64 / 255.f green:0x95 / 255.f blue:0xED / 255.f alpha:1.f];
}

- (void)testModernRGBWhitespaceAndAlpha
{
    for (NSString* source in @[ @"rgb(51 102 153 / .5)", @"rgba(20% 40% 60% / 50%)", @"rgb(51 40% 153/.5)", @"rgb(5.1e1\t102\n153 / .5)" ]) {
        [self assertColor:[IJSVGColor colorFromString:source] red:0.2f green:0.4f blue:0.6f alpha:0.5f];
    }
    [self assertColor:[IJSVGColor colorFromString:@"rgb(300 -5 50%)"] red:1.f green:0.f blue:0.5f alpha:1.f];
    [self assertColor:[IJSVGColor colorFromString:@"rgb(none 0 0 / none)"] red:0.f green:0.f blue:0.f alpha:0.f];
    for (NSString* source in @[ @"rgb(1 2)", @"rgb(1 2 3 4)", @"rgb(1 2 3 /)", @"rgb(1 2 3 / .5 junk)", @"rgb(1-2 3)", @"rgb(nan 0 0)" ]) {
        XCTAssertEqual([IJSVGColor colorFromString:source], NULL, @"%@", source);
    }
}

- (void)testColorFromStringParsesRGBIntegerComponents
{
    CGColorRef color = [IJSVGColor colorFromString:@"rgb(51, 102, 153)"];

    [self assertColor:color red:51.f / 255.f green:102.f / 255.f blue:153.f / 255.f alpha:1.f];
}

- (void)testColorFromStringParsesRGBPercentageComponents
{
    CGColorRef color = [IJSVGColor colorFromString:@"rgb(20%, 40%, 60%)"];

    [self assertColor:color red:0.2f green:0.4f blue:0.6f alpha:1.f];
}

- (void)testColorFromStringParsesRGBAAlphaAsNumber
{
    CGColorRef color = [IJSVGColor colorFromString:@"rgba(51, 102, 153, .5)"];

    [self assertColor:color red:51.f / 255.f green:102.f / 255.f blue:153.f / 255.f alpha:0.5f];
}

- (void)testColorFromStringFallsBackToBlackForIncompleteRGB
{
    CGColorRef color = [IJSVGColor colorFromString:@"rgb(51, 102)"];

    [self assertColor:color red:0.f green:0.f blue:0.f alpha:1.f];
}

- (void)testColorFromStringParsesHSLAndHSLA
{
    CGColorRef green = [IJSVGColor colorFromString:@"hsl(120, 100%, 50%)"];
    CGColorRef translucentBlue = [IJSVGColor colorFromString:@"hsla(240, 100%, 50%, .25)"];

    [self assertColor:green red:0.f green:1.f blue:0.f alpha:1.f];
    [self assertColor:translucentBlue red:0.f green:0.f blue:1.f alpha:0.25f];
}

- (void)testColorFromStringParsesOKLCHWithAlpha
{
    CGColorRef color = [IJSVGColor colorFromString:@"oklch(62.8% 0.25 29.23 / 50%)"];

    XCTAssertNotEqual(color, NULL);
    XCTAssertEqualWithAccuracy(CGColorGetAlpha([self deviceRGBColor:color]), 0.5f, 0.002f);
}

- (void)testColorFromStringRejectsInvalidOKLCHInput
{
    XCTAssertEqual([IJSVGColor colorFromString:@"oklch(62.8% 0.25)"], NULL);
    XCTAssertEqual([IJSVGColor colorFromString:@"oklch(nope 0.25 29.23)"], NULL);
}

- (void)testNoneTransparentEmptyAndUnknownColorsReturnNil
{
    XCTAssertEqual([IJSVGColor colorFromString:nil], NULL);
    XCTAssertEqual([IJSVGColor colorFromString:@""], NULL);
    XCTAssertEqual([IJSVGColor colorFromString:@"none"], NULL);
    XCTAssertEqual([IJSVGColor colorFromString:@"transparent"], NULL);
    XCTAssertEqual([IJSVGColor colorFromString:@"not-a-real-color"], NULL);
    XCTAssertTrue([IJSVGColor isNoneOrTransparent:@"none"]);
    XCTAssertTrue([IJSVGColor isNoneOrTransparent:@"transparent"]);
    XCTAssertFalse([IJSVGColor isNoneOrTransparent:@"red"]);
}

- (void)testColorStringFromColorUsesShorthandWhenAllowed
{
    CGColorRef color = [IJSVGColor colorWithRed:0x33 / 255.f green:0xAA / 255.f blue:0x77 / 255.f alpha:1.f];

    XCTAssertEqualObjects([IJSVGColor colorStringFromColor:color], @"#3A7");
}

- (void)testColorStringFromColorSerializesAlphaAsRGBAByDefault
{
    CGColorRef color = [IJSVGColor colorWithRed:51.f / 255.f green:102.f / 255.f blue:153.f / 255.f alpha:0.5f];

    XCTAssertEqualObjects([IJSVGColor colorStringFromColor:color], @"rgba(51,102,153,.5)");
}

- (void)testColorStringFromColorCanForceRRGGBBAAOutput
{
    CGColorRef color = [IJSVGColor colorWithRed:0x33 / 255.f green:0x66 / 255.f blue:0x99 / 255.f alpha:0x80 / 255.f];
    IJSVGColorStringOptions options = IJSVGColorStringOptionAllowRRGGBBAA;

    XCTAssertEqualObjects([IJSVGColor colorStringFromColor:color options:options], @"#33669980");
}

- (void)testChangeAlphaKeepsRGBComponents
{
    CGColorRef color = [IJSVGColor colorFromString:@"#336699"];
    CGColorRef changed = [IJSVGColor changeAlphaOnColor:color to:0.25f];

    [self assertColor:changed red:0x33 / 255.f green:0x66 / 255.f blue:0x99 / 255.f alpha:0.25f];
}

- (void)testParserCreatesColorNodesForFillStrokeAndNone
{
    NSString* body = @"<rect id=\"a\" width=\"5\" height=\"5\" fill=\"#336699\" "
                      "stroke=\"rgba(255,0,0,.5)\"/><rect id=\"b\" x=\"5\" "
                      "width=\"5\" height=\"5\" "
                      "fill=\"none\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body) fileURL:nil error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(10.f, 5.f)];
    IJSVGPath* first = (IJSVGPath*)rootNode.children[0];
    IJSVGPath* second = (IJSVGPath*)rootNode.children[1];
    IJSVGColorNode* fill = (IJSVGColorNode*)first.fill;
    IJSVGColorNode* stroke = (IJSVGColorNode*)first.stroke;
    IJSVGColorNode* noneFill = (IJSVGColorNode*)second.fill;

    XCTAssertTrue([fill isKindOfClass:IJSVGColorNode.class]);
    XCTAssertTrue([stroke isKindOfClass:IJSVGColorNode.class]);
    XCTAssertTrue([noneFill isKindOfClass:IJSVGColorNode.class]);
    [self assertColor:fill.color red:0x33 / 255.f green:0x66 / 255.f blue:0x99 / 255.f alpha:1.f];
    [self assertColor:stroke.color red:1.f green:0.f blue:0.f alpha:0.5f];
    XCTAssertEqual(noneFill.color, NULL);
    XCTAssertTrue(noneFill.isNoneOrTransparent);
}

- (void)testParserAppliesStopColorAndStopOpacityToGradientStops
{
    NSString* body = @"<defs><linearGradient id=\"g\"><stop offset=\"0\" "
                     @"stop-color=\"#336699\" "
                      "stop-opacity=\"25%\"/><stop offset=\"1\" "
                      "stop-color=\"hsl(120,100%,50%)\"/>"
                      "</linearGradient></defs><rect width=\"10\" height=\"10\" "
                      "fill=\"url(#g)\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body) fileURL:nil error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(10.f, 10.f)];
    IJSVGPath* rect = (IJSVGPath*)rootNode.children.firstObject;
    IJSVGLinearGradient* gradient = (IJSVGLinearGradient*)rect.fill;
    IJSVGStop* firstStop = (IJSVGStop*)gradient.children[0];
    IJSVGStop* secondStop = (IJSVGStop*)gradient.children[1];
    IJSVGColorNode* firstColor = (IJSVGColorNode*)firstStop.fill;
    IJSVGColorNode* secondColor = (IJSVGColorNode*)secondStop.fill;

    [self assertColor:firstColor.color red:0x33 / 255.f green:0x66 / 255.f blue:0x99 / 255.f alpha:0.25f];
    [self assertColor:secondColor.color red:0.f green:1.f blue:0.f alpha:1.f];
}

@end
