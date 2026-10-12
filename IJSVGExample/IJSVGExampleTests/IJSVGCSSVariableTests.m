//
//  IJSVGCSSVariableTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 12/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTestHelpers.h>
#import <IJSVGCSSVariables.h>
#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVGCSSParser.h>

@interface IJSVGCSSVariableTests: XCTestCase
@end

@implementation IJSVGCSSVariableTests

- (NSData*)pixels:(NSString*)body
{
    NSString* svg = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'>%@</svg>", body];
    NSData* result = IJSVGTestRGBADataForSVG(svg, CGSizeMake(100, 100));
    XCTAssertNotNil(result);
    return result;
}

- (void)testVariablesResolveInsideCalculationsAndColors
{
    NSData* expected = [self pixels:@"<rect x='10' width='40' height='30' fill='rgb(128,0,0)'/>"];
    XCTAssertEqualObjects([self pixels:
        @"<style>:root { --size:30px; --red:128; } rect { x:10px; width:calc(var(--size) + 10px);"
         "height:var(--size); fill:rgb(var(--red), 0, 0); }</style><rect/>"], expected);
}

- (void)testCustomPropertyCascadeAndCaseSensitivity
{
    NSData* expected = [self pixels:@"<rect width='40' height='30' fill='red'/>"];
    for(NSString* source in @[
        @"<style>rect { --w:10px; --w:40px; --W:30px; width:var(--w); height:var(--W); fill:var(--c,red) }</style><rect/>",
        @"<style>rect { --w:40px !important; width:var(--w); height:30px; fill:red }</style><rect style='--w:10px'/>",
        @"<style>#r { --w:40px } rect { --w:10px; width:var(--w); height:30px; fill:red }</style><rect id='r'/>",
        @"<style>rect { --w:10px; width:var(--w); height:30px; fill:red }</style><rect style='--w:40px'/>"
    ]) {
        XCTAssertEqualObjects([self pixels:source], expected, @"%@", source);
    }
}

- (void)testCustomPropertiesInheritComputedValues
{
    NSData* expected = [self pixels:@"<rect width='40' height='30' fill='red'/>"];
    XCTAssertEqualObjects([self pixels:
        @"<g style='--w:40px; --alias:var(--w); --c:red'><g><rect height='30' "
         "style='--w:10px; width:var(--alias); fill:var(--c)'/></g></g>"], expected);
    XCTAssertEqualObjects([self pixels:
        @"<g style='--w:40px; --c:red'><rect height='30' style='--w:inherit; width:var(--w); fill:var(--c)'/></g>"],
        expected);
}

- (void)testNestedFallbacksAndEmptyValues
{
    NSDictionary<NSString*, id>* properties = IJSVGCSSResolveCustomProperties(@{@"--empty": @"", @"--red": @"red"}, nil);
    XCTAssertEqualObjects(IJSVGCSSResolveVariables(@"var(--missing,var(--red,blue))", properties), @"red");
    XCTAssertEqualObjects(IJSVGCSSResolveVariables(@"var(--missing,)", properties), @"");
    XCTAssertEqualObjects(IJSVGCSSResolveVariables(@"var(--empty,red)", properties), @"");
    XCTAssertEqualObjects(IJSVGCSSResolveVariables(@"rgb(var(--missing,1,2,3))", properties), @"rgb(1,2,3)");
    IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleString:@"--empty:; --other: !important"];
    XCTAssertEqualObjects([style property:@"--empty"], @"");
    XCTAssertEqualObjects([style property:@"--other"], @"");
    XCTAssertTrue([style isPropertyImportant:@"--other"]);
}

- (void)testCyclesIncludeUnusedFallbacks
{
    NSDictionary<NSString*, id>* properties = IJSVGCSSResolveCustomProperties(@{
        @"--a": @"var(--b,red)", @"--b": @"var(--a,blue)", @"--ok": @"green",
        @"--self": @"var(--ok,var(--self))", @"--result": @"var(--a,red)"
    }, nil);
    XCTAssertEqualObjects(properties[@"--a"], NSNull.null);
    XCTAssertEqualObjects(properties[@"--b"], NSNull.null);
    XCTAssertEqualObjects(properties[@"--self"], NSNull.null);
    XCTAssertEqualObjects(properties[@"--result"], @"red");
    XCTAssertEqualObjects(IJSVGCSSResolveVariables(@"var(--self,blue)", properties), @"blue");
}

- (void)testMissingAndInvalidValuesDoNotRestoreEarlierDeclarations
{
    NSData* empty = [self pixels:@""];
    for(NSString* declarations in @[
        @"width:40px;width:var(--missing)",
        @"--w:red;width:40px;width:var(--w,40px)",
        @"--a:var(--a);width:var(--a)",
        @"--w:initial;width:var(--w)"
    ]) {
        NSString* body = [NSString stringWithFormat:
            @"<rect width='40' height='30' style='%@'/>", declarations];
        XCTAssertEqualObjects([self pixels:body], empty, @"%@", declarations);
    }
    XCTAssertEqualObjects([self pixels:
        @"<g fill='red'><rect width='40' height='30' fill='blue' style='fill:var(--missing)'/></g>"],
        [self pixels:@"<rect width='40' height='30' fill='red'/>"]);
}

- (void)testInvalidVariableSyntaxDoesNotEnterCascade
{
    for(NSString* value in @[@"var()", @"var(color)", @"var(--)", @"var(--x red)", @"var(--x,var())",
                             @"var(--x", @"var(--x)\0junk"]) {
        XCTAssertEqual(IJSVGCSSValidateVariables(value), IJSVGCSSVariableSyntaxInvalid, @"%@", value);
    }
    XCTAssertEqualObjects([self pixels:
        @"<rect height='30' style='width:40px;width:var(no);fill:red'/>"],
        [self pixels:@"<rect width='40' height='30' fill='red'/>"]);
}

- (void)testSubstitutionPreservesTokensAndStrings
{
    NSDictionary<NSString*, id>* properties = @{@"--n": @"20", @"--color": @"red"};
    XCTAssertEqualObjects(IJSVGCSSResolveVariables(@"'var(--color)'", properties), @"'var(--color)'");
    XCTAssertEqualObjects(IJSVGCSSResolveVariables(@"url('var(--color)')", properties), @"url('var(--color)')");
    XCTAssertEqualObjects(IJSVGCSSResolveVariables(@"var(--n)px", properties), @"20/**/px");
    XCTAssertEqualObjects([self pixels:
        @"<rect height='30' style='--n:20;width:var(--n)px'/>"], [self pixels:@""]);
    XCTAssertEqualObjects([self pixels:
        @"<rect height='30' style='--n:20px;width:calc(var(--n)+ 20px)'/>"], [self pixels:@""]);
}

- (void)testVariablesInPathsAndPaintReferences
{
    XCTAssertEqualObjects([self pixels:
        @"<path style='--d:path(&quot;M10 10H50V40H10Z&quot;);d:var(--d);--c:red;fill:var(--c)'/>"],
        [self pixels:@"<path d='M10 10H50V40H10Z' fill='red'/>"]);
    NSString* defs = @"<defs><linearGradient id='g'><stop stop-color='red'/></linearGradient></defs>";
    XCTAssertEqualObjects([self pixels:[defs stringByAppendingString:
        @"<rect width='40' height='30' style='--paint:url(#g);fill:var(--paint)'/>"]],
        [self pixels:[defs stringByAppendingString:@"<rect width='40' height='30' fill='url(#g)'/>"]]);
}

- (void)testVariablesInFontShorthandRespectLonghands
{
    IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleString:
        @"font:var(--font);font-size:18px"];
    IJSVGStyleSheetStyle* resolved = [style styleByResolvingVariables:@{@"--font": @"italic 12px serif"}];
    XCTAssertEqualObjects([resolved property:@"font-size"], @"18px");
    XCTAssertEqualObjects([resolved property:@"font-style"], @"italic");
    XCTAssertEqualObjects([resolved property:@"font-family"], @"serif");
    style = [IJSVGStyleSheetStyle parseStyleString:@"font-size:18px;font:var(--font)"];
    resolved = [style styleByResolvingVariables:@{@"--font": @"italic 12px serif"}];
    XCTAssertEqualObjects([resolved property:@"font-size"], @"12px");
}

- (void)testEscapedNamesAndCommentBoundaries
{
    XCTAssertEqualObjects([self pixels:
        @"<rect height='30' style='--s\\69ze:40px;--颜色:red;width:v\\61r(--size);fill:var(--颜色)'/>"],
        [self pixels:@"<rect width='40' height='30' fill='red'/>"]);
    XCTAssertEqualObjects([self pixels:
        @"<rect height='30' style='--n:20/**/px;width:var(--n)'/>"], [self pixels:@""]);
    XCTAssertEqualObjects([self pixels:
        @"<rect height='30' style='--n:20px;width:var(--missing,calc(var(--n) + 20px));fill:red'/>"],
        [self pixels:@"<rect width='40' height='30' fill='red'/>"]);
}

- (void)testRootSelectorMatchesOnlyDocumentRoot
{
    XCTAssertEqualObjects([self pixels:
        @"<style>:root { --w:40px; --c:red } svg:root { --h:30px }"
         "svg { --w:10px } rect { width:var(--w);height:var(--h);fill:var(--c) }</style><g><rect/></g>"],
        [self pixels:@"<rect width='40' height='30' fill='red'/>"]);
    XCTAssertEqualObjects([self pixels:
        @"<style>:root { --w:40px } svg { --w:10px } rect { width:var(--w);height:30px;fill:red }</style>"
         "<svg width='100' height='100'><rect/></svg>"],
        [self pixels:@"<rect width='10' height='30' fill='red'/>"]);
}

- (void)testReferencesResolveVariablesForEachInstance
{
    XCTAssertEqualObjects([self pixels:
        @"<defs><rect id='r' height='30' style='width:var(--w);fill:var(--c)'/></defs>"
         "<use href='#r' style='--w:20px;--c:red'/><use href='#r' x='30' style='--w:40px;--c:blue'/>"],
        [self pixels:@"<rect width='20' height='30' fill='red'/><rect x='30' width='40' height='30' fill='blue'/>"]);
}

- (void)testInvalidResolvedPaintInherits
{
    XCTAssertEqualObjects([self pixels:
        @"<g fill='red'><rect width='40' height='30' style='--c:20px;fill:blue;fill:var(--c,green)'/></g>"],
        [self pixels:@"<rect width='40' height='30' fill='red'/>"]);
}

- (void)testVariablesInPresentationAttributes
{
    XCTAssertEqualObjects([self pixels:
        @"<g style='--c:red;--w:40px'><rect width='var(--w)' height='30' fill='var(--c)'/></g>"],
        [self pixels:@"<rect width='40' height='30' fill='red'/>"]);
    XCTAssertEqualObjects([self pixels:
        @"<rect width='var(--missing,40px)' height='30' fill='var(--missing,red)'/>"],
        [self pixels:@"<rect width='40' height='30' fill='red'/>"]);
    XCTAssertEqualObjects([self pixels:
        @"<rect width='var(--missing)' height='30' fill='var(--missing,blue)' style='width:40px;fill:red'/>"],
        [self pixels:@"<rect width='40' height='30' fill='red'/>"]);
}

- (void)testExpansionBufferBoundaries
{
    for(NSNumber* size in @[@511, @512, @513, @2048, @65536, @65537]) {
        NSString* value = [@"" stringByPaddingToLength:size.unsignedIntegerValue
                                          withString:@"x"
                                     startingAtIndex:0];
        NSString* resolved = IJSVGCSSResolveVariables(@"var(--value)", @{@"--value": value});
        if(size.unsignedIntegerValue > 65536) {
            XCTAssertNil(resolved);
        } else {
            XCTAssertEqualObjects(resolved, value);
        }
    }
    NSString* unicode = [@"" stringByPaddingToLength:600 withString:@"é" startingAtIndex:0];
    XCTAssertEqualObjects(IJSVGCSSResolveVariables(@"var(--missing,var(--value))",
        @{@"--value": unicode}), unicode);
    XCTAssertEqualObjects(IJSVGCSSResolveVariables(@"var(--value),var(--value)",
        @{@"--value": unicode}), ([NSString stringWithFormat:@"%@,%@", unicode, unicode]));
}

- (void)testShorthandResolutionPreservesDifferentCascadeSources
{
    IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleString:
        @"font:var(--first);font-size:var(--size)!important;font:var(--second)"];
    NSDictionary<NSString*, id>* first = @{@"--first": @"italic 12px Arial",
        @"--second": @"bold 20px Helvetica", @"--size": @"30px"};
    IJSVGStyleSheetStyle* resolved = [style styleByResolvingVariables:first];
    XCTAssertEqualObjects([resolved property:@"font-size"], @"30px");
    XCTAssertEqualObjects([resolved property:@"font-family"], @"Helvetica");
    XCTAssertTrue([resolved isPropertyImportant:@"font-size"]);
    IJSVGStyleSheetStyle* next = [style styleByResolvingVariables:
        @{@"--second": @"italic 10px Courier", @"--size": @"15px"}];
    XCTAssertEqualObjects([next property:@"font-family"], @"Courier");
    XCTAssertEqualObjects([resolved property:@"font-family"], @"Helvetica");
}

- (void)testExpansionLimits
{
    NSMutableDictionary<NSString*, NSString*>* declarations = [NSMutableDictionary dictionaryWithObject:@"x" forKey:@"--v0"];
    for(NSUInteger index = 1; index < 24; index++) {
        declarations[[NSString stringWithFormat:@"--v%lu", (unsigned long)index]] =
            [NSString stringWithFormat:@"var(--v%lu) var(--v%lu)",
                (unsigned long)(index - 1), (unsigned long)(index - 1)];
    }
    NSDictionary<NSString*, id>* properties = IJSVGCSSResolveCustomProperties(declarations, nil);
    XCTAssertEqualObjects(properties[@"--v23"], NSNull.null);
    XCTAssertEqualObjects(IJSVGCSSResolveVariables(@"var(--v23,red)", properties), @"red");
}

@end
