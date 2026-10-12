//
//  IJSVGCSSShapeTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 12/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTestHelpers.h>
#import <IJSVGCSSParser.h>

@interface IJSVGCSSShapeTests: XCTestCase
@end

@implementation IJSVGCSSShapeTests

- (NSData*)pixels:(NSString*)body
{
    NSString* svg = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'>%@</svg>", body];
    NSData* result = IJSVGTestRGBADataForSVG(svg, CGSizeMake(100, 100));
    XCTAssertNotNil(result);
    return result;
}

- (void)testCSSPathDataCascade
{
    NSData* expected = [self pixels:@"<path d='M10 10H60V60H10Z'/>"];
    for(NSString* source in @[
        @"<style>path { d:path('M10 10H60V60H10Z') }</style><path/>",
        @"<path d='M0 0H100V100Z' style='d:path(&quot;M10 10H60V60H10Z&quot;)'/>",
        @"<style>path { d:path('M10 10H60V60H10Z') !important }</style><path style='d:none'/>",
        @"<style>path { d:path('M10 10H60V60H10Z'); d:circle(20%) }</style><path/>",
        @"<g style='d:path(&quot;M10 10H60V60H10Z&quot;)'><path style='d:inherit'/></g>",
        @"<path d='M10 10H60V60H10Z' style='d:revert'/>"
    ]) {
        XCTAssertEqualObjects([self pixels:source], expected, @"%@", source);
    }
    NSData* empty = [self pixels:@""];
    for(NSString* keyword in @[@"none", @"initial", @"unset"]) {
        NSString* source = [NSString stringWithFormat:
            @"<path d='M0 0H100V100Z' style='d:%@'/>", keyword];
        XCTAssertEqualObjects([self pixels:source], empty);
    }
}

- (void)testCSSWideKeywords
{
    XCTAssertEqual(IJSVGCSSWideKeywordFromString(@"InHeRiT"), IJSVGCSSWideKeywordInherit);
    XCTAssertEqual(IJSVGCSSWideKeywordFromString(@"INITIAL"), IJSVGCSSWideKeywordInitial);
    XCTAssertEqual(IJSVGCSSWideKeywordFromString(@"Unset"), IJSVGCSSWideKeywordUnset);
    XCTAssertEqual(IJSVGCSSWideKeywordFromString(@"REVERT"), IJSVGCSSWideKeywordRevert);
    XCTAssertEqual(IJSVGCSSWideKeywordFromString(@"Revert-Layer"), IJSVGCSSWideKeywordRevertLayer);
    for(NSString* value in @[@"", @"none", @"initially", @"inherit extra", @"unset\0xx",
                             @"initial\0junk", @"révert", @"path('M0 0')"]) {
        XCTAssertEqual(IJSVGCSSWideKeywordFromString(value), IJSVGCSSWideKeywordUnknown, @"%@", value);
    }
    NSData* expected = [self pixels:@"<path d='M10 10H60V60H10Z'/>"];
    for(NSString* keyword in @[@"REVERT", @"Revert-Layer"]) {
        NSString* source = [NSString stringWithFormat:
            @"<path d='M10 10H60V60H10Z' style='d:%@'/>", keyword];
        XCTAssertEqualObjects([self pixels:source], expected);
    }
    NSData* empty = [self pixels:@""];
    for(NSString* keyword in @[@"INITIAL", @"Unset"]) {
        NSString* source = [NSString stringWithFormat:
            @"<path d='M10 10H60V60H10Z' style='d:%@'/>", keyword];
        XCTAssertEqualObjects([self pixels:source], empty);
    }
}

- (void)testCSSPathStringsAndEscapes
{
    XCTAssertEqualObjects(IJSVGCSSPathDataFromString(@"path('M10 10L20 20')"), @"M10 10L20 20");
    XCTAssertEqualObjects(IJSVGCSSPathDataFromString(@"p\\61th('\\4d 10 10L20 20')"), @"M10 10L20 20");
    XCTAssertEqualObjects(IJSVGCSSPathDataFromString(@"path('')"), @"");
    XCTAssertEqualObjects(IJSVGCSSPathDataFromString(@"none"), @"");
    for(NSString* source in @[@"path(M0 0)", @"path('M0 0') junk", @"path('M0 0', 'L1 1')",
                              @"path(evenodd, 'M0 0')", @"circle(20%)", @"path('M0 0')\0junk"]) {
        XCTAssertNil(IJSVGCSSPathDataFromString(source), @"%@", source);
    }
}

@end
