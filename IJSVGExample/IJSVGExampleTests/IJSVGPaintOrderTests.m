#import <IJSVGTestHelpers.h>
#import <IJSVGParserUtils.h>

@interface IJSVGPaintOrderTests: XCTestCase
@end

@implementation IJSVGPaintOrderTests

- (void)testLengthListParsing
{
    NSArray<NSString*>* tokens = @[@"0", @"+2.5", @".5em", @"2EX", @"3px", @"25%",
        @"1cm", @"2mm", @"1in", @"3pt", @"2pc", @"1e2em", @"2E-2ex", @"1.e+1"];
    NSArray<IJSVGUnitLength*>* lengths = IJSVGUnitLengthsFromString(
        [NSString stringWithFormat:@" \t%@\r\n", [tokens componentsJoinedByString:@", \n"]]);
    XCTAssertEqual(lengths.count, tokens.count);
    for(NSUInteger index = 0; index < MIN(lengths.count, tokens.count); index++) {
        IJSVGUnitLength* expected = [IJSVGUnitLength unitWithString:tokens[index]];
        XCTAssertEqualWithAccuracy(lengths[index].value, expected.value, 0.000001);
        XCTAssertEqual(lengths[index].type, expected.type);
        XCTAssertEqual(lengths[index].originalType, expected.originalType);
    }
    XCTAssertEqual(IJSVGUnitLengthsFromString(@"1 2\t3\r4\n5").count, 5u);
    XCTAssertEqualWithAccuracy(IJSVGUnitLengthsFromString(@"1e-320").firstObject.value, 1e-320, 1e-323);
}

- (void)testLengthListRejectsInvalidValues
{
    for(NSString* value in @[@"", @" \n", @",1", @"1,", @"1,,2", @"-1em", @"1 -2",
                             @"nan", @"inf", @"1e999", @"1e309cm", @"1e", @"1e+", @".",
                             @"+", @"1fooem", @"1%%", @"1pxpx", @"1 em", @"1-2", @"1.2.3",
                             @"1\u00a02", @"1😀", @"1e2e3"]) {
        XCTAssertNil(IJSVGUnitLengthsFromString(value), @"%@", value);
    }
}

- (void)testLengthListParsingPerformance
{
    NSString* value = @"1em, 2ex, 3px, 4%, 5cm, 6mm, 7in, 8pt, 9pc, 1e-2, .5em, +2EX";
    [self measureBlock:^{
        for(NSUInteger index = 0; index < 10000; index++) {
            @autoreleasepool {
                IJSVGUnitLengthsFromString(value);
            }
        }
    }];
}

- (void)testLengthListBoundaryValues
{
    NSArray<IJSVGUnitLength*>* zeroes = IJSVGUnitLengthsFromString(@"-0 -0.0em -0e-999ex +0% 0e999");
    XCTAssertEqual(zeroes.count, 5u);
    for(IJSVGUnitLength* length in zeroes) {
        XCTAssertEqual(length.value, 0.f);
    }
    XCTAssertNil(IJSVGUnitLengthsFromString(@"-1e-999"));
    XCTAssertNil(IJSVGUnitLengthsFromString(@"-1e-323%"));
    XCTAssertNil(IJSVGUnitLengthsFromString(@"1em\0,2ex"));
    XCTAssertNil(IJSVGUnitLengthsFromString(@"1\0"));
    for(NSString* separator in @[@",", @" ,", @", ", @" \t,\r\n", @" \t\r\n"]) {
        NSArray<IJSVGUnitLength*>* lengths = IJSVGUnitLengthsFromString(
            [NSString stringWithFormat:@"1em%@2ex", separator]);
        XCTAssertEqual(lengths.count, 2u, @"%@", separator);
        XCTAssertEqual(lengths.firstObject.value, 1.f);
        XCTAssertEqual(lengths.lastObject.value, 2.f);
    }
}

- (void)testParsingAndInheritance
{
    XCTAssertEqual(IJSVGPaintOrderFromString(@" normal "), IJSVGPaintOrderNormal);
    XCTAssertEqual(IJSVGPaintOrderFromString(@"stroke"), IJSVGPaintOrderStrokeFillMarkers);
    XCTAssertEqual(IJSVGPaintOrderFromString(@"markers"), IJSVGPaintOrderMarkersFillStroke);
    XCTAssertEqual(IJSVGPaintOrderFromString(@"stroke markers"), IJSVGPaintOrderStrokeMarkersFill);
    XCTAssertEqual(IJSVGPaintOrderFromString(@"fill fill"), IJSVGPaintOrderInherit);
    XCTAssertEqual(IJSVGPaintOrderFromString(@"invalid"), IJSVGPaintOrderInherit);
    IJSVGNode* parent = [[IJSVGNode alloc] init];
    parent.paintOrder = IJSVGPaintOrderMarkersStrokeFill;
    IJSVGNode* child = [[IJSVGNode alloc] init];
    child.parentNode = parent;
    XCTAssertEqual(child.paintOrder, parent.paintOrder);
    child.paintOrder = IJSVGPaintOrderNormal;
    XCTAssertEqual(child.paintOrder, IJSVGPaintOrderNormal);
}

- (void)testAllOrdersExportWithPaintServersAndMarkers
{
    NSString* definitions = @"<defs><linearGradient id='g'><stop stop-color='red'/>"
        "<stop offset='1' stop-color='blue'/></linearGradient>"
        "<pattern id='p' width='2' height='2' patternUnits='userSpaceOnUse'>"
        "<rect width='1' height='2' fill='orange'/></pattern>"
        "<marker id='m' markerWidth='2' markerHeight='2' refX='1' refY='1'"
        " markerUnits='userSpaceOnUse'><rect width='2' height='2' fill='lime'/></marker></defs>";
    for(NSString* order in @[@"normal", @"fill markers stroke", @"stroke fill markers",
                             @"stroke markers fill", @"markers fill stroke", @"markers stroke fill"]) {
        for(NSString* fill in @[@"red", @"url(#g)", @"url(#p)"]) {
            for(NSString* stroke in @[@"blue", @"url(#g)", @"url(#p)"]) {
                for(NSString* markers in @[@"", @"marker-start='url(#m)' marker-mid='url(#m)'"]) {
                    NSString* source = IJSVGTestSVG([NSString stringWithFormat:
                        @"%@<path d='M2 2H6V6H2Z' fill='%@' stroke='%@' stroke-width='2'"
                         " paint-order='%@' %@/>", definitions, fill, stroke, order, markers]);
                    IJSVG* svg = IJSVGTestSVGObject(source);
                    NSData* expected = IJSVGTestRGBADataForSVG(source, CGSizeMake(8, 8));
                    XCTAssertNotNil(expected);
                    for(NSNumber* options in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionAll)]) {
                        NSString* exported = [svg SVGStringWithSize:CGSizeMake(8, 8) options:options.unsignedIntegerValue];
                        XCTAssertEqualObjects(expected, IJSVGTestRGBADataForSVG(exported, CGSizeMake(8, 8)),
                                              @"%@ %@", source, exported);
                    }
                }
            }
        }
    }
}

- (void)testSymbolUseLengthsResolveAgainstUseFont
{
    NSString* source = IJSVGTestSVG(
        @"<symbol id='s' viewBox='0 0 2 2' font-size='4'><rect width='2' height='2' fill='red'/></symbol>"
         "<use href='#s' x='1em' y='1em' width='2em' height='2em' font-size='2'/>");
    NSString* expected = IJSVGTestSVG(@"<rect x='2' y='2' width='4' height='4' fill='red'/>");
    XCTAssertEqualObjects(IJSVGTestRGBADataForSVG(source, CGSizeMake(8, 8)),
                          IJSVGTestRGBADataForSVG(expected, CGSizeMake(8, 8)));
}

@end
