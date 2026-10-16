//
//  IJSVGParserTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGlyph.h>
#import <IJSVGStyleSheetUtils.h>
#import <IJSVGTestHelpers.h>

@interface IJSVGParserTests : XCTestCase
@end

@implementation IJSVGParserTests

- (void)testParserRecognizesValidXMLDataAndRejectsMalformedData
{
    NSData* validData = [IJSVGTestSVG(@"<rect width=\"8\" height=\"8\"/>") dataUsingEncoding:NSUTF8StringEncoding];
    NSData* malformedData = [@"<svg><rect></svg>" dataUsingEncoding:NSUTF8StringEncoding];

    XCTAssertTrue([IJSVGParser isDataSVG:validData]);
    XCTAssertFalse([IJSVGParser isDataSVG:malformedData]);
}

- (void)testParserBuildsRootFromSVGData
{
    NSData* data = [IJSVGTestSVG(@"<rect id=\"box\" width=\"8\" height=\"8\"/>") dataUsingEncoding:NSUTF8StringEncoding];
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGData:data fileURL:nil error:&error];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGPath* rect = (IJSVGPath*)rootNode.children.firstObject;

    XCTAssertNotNil(parser);
    XCTAssertNil(error);
    XCTAssertEqualObjects(rect.identifier, @"box");
    XCTAssertEqual(rect.primitiveType, kIJSVGPrimitivePathTypeRect);
}

- (void)testParserBuildsRootAndPathNodeAttributes
{
    NSString* string = IJSVGTestSVG(@"<rect id=\"box\" class=\"primary selected\" x=\"1\" y=\"2\" "
                                     "width=\"3\" height=\"4\" fill=\"#336699\"/>");
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:string fileURL:nil error:&error];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGPath* rect = (IJSVGPath*)rootNode.children.firstObject;

    XCTAssertNil(error);
    XCTAssertEqual(rootNode.children.count, 1);
    XCTAssertTrue([rect isKindOfClass:IJSVGPath.class]);
    XCTAssertEqual(rect.primitiveType, kIJSVGPrimitivePathTypeRect);
    XCTAssertEqualObjects(rect.identifier, @"box");
    XCTAssertTrue([rect.classNameList containsObject:@"primary"]);
    XCTAssertTrue([rect.classNameList containsObject:@"selected"]);
    XCTAssertEqualWithAccuracy(rect.x.value, 1.f, 0.001);
    XCTAssertEqualWithAccuracy(rect.y.value, 2.f, 0.001);
    XCTAssertEqualWithAccuracy(rect.width.value, 3.f, 0.001);
    XCTAssertEqualWithAccuracy(rect.height.value, 4.f, 0.001);
    XCTAssertTrue([rect.fill isKindOfClass:IJSVGColorNode.class]);
}

- (void)testParserInfersViewBoxFromWidthAndHeight
{
    NSString* string = @"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" "
                       @"height=\"6\"><rect "
                        "width=\"12\" height=\"6\"/></svg>";
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:string fileURL:nil error:&error];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(12.f, 6.f)];

    XCTAssertNotNil(parser);
    XCTAssertNil(error);
    XCTAssertEqualWithAccuracy(rootNode.viewBox.size.width.value, 12.f, 0.001);
    XCTAssertEqualWithAccuracy(rootNode.viewBox.size.height.value, 6.f, 0.001);
    XCTAssertEqualWithAccuracy(rootNode.intrinsicSize.width.value, 12.f, 0.001);
    XCTAssertEqualWithAccuracy(rootNode.intrinsicSize.height.value, 6.f, 0.001);
}

- (void)testParsedMediaQueryCanMatchDifferentEnvironments
{
    IJSVGMediaEnvironment byteEnvironment = { CGSizeMake(800, 200), IJSVGMediaTypeScreen };
    const char unterminated[] = { 'S', 'C', 'R', 'E', 'E', 'N' };
    IJSVGMediaQuery* byteQuery = IJSVGMediaQueryCreateFromCleanBytes(unterminated, sizeof(unterminated));
    XCTAssertTrue(IJSVGMediaQueryMatches(byteQuery, byteEnvironment));
    IJSVGMediaQueryRelease(byteQuery);

    const char trailing[] = "screen and";
    byteQuery = IJSVGMediaQueryCreateFromCleanBytes(trailing, 6);
    XCTAssertTrue(IJSVGMediaQueryMatches(byteQuery, byteEnvironment));
    IJSVGMediaQueryRelease(byteQuery);
    byteQuery = IJSVGMediaQueryCreateFromCleanBytes(trailing, sizeof(trailing) - 1);
    XCTAssertFalse(IJSVGMediaQueryMatches(byteQuery, byteEnvironment));
    IJSVGMediaQueryRelease(byteQuery);
    const char embeddedNUL[] = { 's', 'c', 'r', 'e', 'e', 'n', 0, 'x' };
    XCTAssertEqual(IJSVGMediaQueryCreateFromCleanBytes(embeddedNUL, sizeof(embeddedNUL)), NULL);

    for (NSUInteger length = 511; length <= 513; length++) {
        NSString* padded = [@"SCREEN AND (MIN-WIDTH:40EM)" stringByPaddingToLength:length withString:@" " startingAtIndex:0];
        byteQuery = IJSVGMediaQueryCreateFromCleanBytes(padded.UTF8String, length);
        XCTAssertTrue(IJSVGMediaQueryMatches(byteQuery, byteEnvironment));
        IJSVGMediaQueryRelease(byteQuery);
    }

    IJSVGMediaQuery* query = IJSVGMediaQueryCreate(@"screen and (min-width:40em) and (orientation:landscape), print");
    XCTAssertNotEqual(query, NULL);
    IJSVGMediaEnvironment environment = { CGSizeMake(800, 200), IJSVGMediaTypeScreen };
    XCTAssertTrue(IJSVGMediaQueryMatches(query, environment));
    environment.viewport.width = 600;
    XCTAssertFalse(IJSVGMediaQueryMatches(query, environment));
    environment.viewport = CGSizeMake(800, 900);
    XCTAssertFalse(IJSVGMediaQueryMatches(query, environment));
    environment.type = IJSVGMediaTypePrint;
    XCTAssertTrue(IJSVGMediaQueryMatches(query, environment));
    environment.type = IJSVGMediaTypeScreen;
    environment.viewport = CGSizeMake(800, 200);
    XCTAssertTrue(IJSVGMediaQueryMatches(query, environment));
    IJSVGMediaQueryRelease(query);

    for (NSString* media in @[ @"only (width:800px)", @"screen and", @"not (width:banana)", @"not", @",", @"(width:800px) garbage" ]) {
        query = IJSVGMediaQueryCreate(media);
        XCTAssertFalse(IJSVGMediaQueryMatches(query, environment), @"%@", media);
        IJSVGMediaQueryRelease(query);
    }
    query = IJSVGMediaQueryCreate(@"/* empty */");
    XCTAssertTrue(IJSVGMediaQueryMatches(query, environment));
    IJSVGMediaQueryRelease(query);
    query = IJSVGMediaQueryCreate(@"(bad:value), screen");
    XCTAssertTrue(IJSVGMediaQueryMatches(query, environment));
    IJSVGMediaQueryRelease(query);
}

- (void)testMediaLengthsUseSharedUnitParsing
{
    IJSVGMediaEnvironment environment = { CGSizeMake(100, 50), IJSVGMediaTypeScreen };
    for (NSString* length in @[ @"96px", @"1in", @"72pt", @"6pc", @"2.54cm", @"25.4mm", @"6em", @"6rem", @".6e1EM", @"+9.6e1PX" ]) {
        NSString* media = [NSString stringWithFormat:@"(min-width:%@)", length];
        IJSVGMediaQuery* query = IJSVGMediaQueryCreate(media);
        environment.viewport.width = 100;
        XCTAssertTrue(IJSVGMediaQueryMatches(query, environment), @"%@", length);
        environment.viewport.width = 90;
        XCTAssertFalse(IJSVGMediaQueryMatches(query, environment), @"%@", length);
        IJSVGMediaQueryRelease(query);
    }
    for (NSString* length in @[ @"50%", @"auto", @"inherit", @"2unknown", @"1e999px", @"-1e-999px", @"0x10px", @"1e+px", @"96", @"2 px" ]) {
        NSString* media = [NSString stringWithFormat:@"not (width:%@)", length];
        IJSVGMediaQuery* query = IJSVGMediaQueryCreate(media);
        XCTAssertFalse(IJSVGMediaQueryMatches(query, environment), @"%@", length);
        IJSVGMediaQueryRelease(query);
    }
}

- (void)testMediaParsingBenchmark
{
    NSString* media = @"screen and (min-width:40em) and (orientation:landscape), print";
    IJSVGMediaEnvironment environment = { CGSizeMake(800, 200), IJSVGMediaTypeScreen };
    NSUInteger matches = 0;
    NSMutableArray<NSNumber*>* creationSamples = [NSMutableArray array];
    NSMutableArray<NSNumber*>* matchingSamples = [NSMutableArray array];
    for (NSUInteger round = 0; round < 10; round++) {
        NSTimeInterval start = NSProcessInfo.processInfo.systemUptime;
        for (NSUInteger iteration = 0; iteration < 10000; iteration++) {
            @autoreleasepool {
                IJSVGMediaQuery* query = IJSVGMediaQueryCreate(media);
                matches += IJSVGMediaQueryMatches(query, environment);
                IJSVGMediaQueryRelease(query);
            }
        }
        NSTimeInterval creation = NSProcessInfo.processInfo.systemUptime - start;
        IJSVGMediaQuery* query = IJSVGMediaQueryCreate(media);
        start = NSProcessInfo.processInfo.systemUptime;
        for (NSUInteger iteration = 0; iteration < 1000000; iteration++) {
            matches += IJSVGMediaQueryMatches(query, environment);
        }
        NSTimeInterval matching = NSProcessInfo.processInfo.systemUptime - start;
        IJSVGMediaQueryRelease(query);
        if (round != 0) {
            [creationSamples addObject:@(creation * 100)];
            [matchingSamples addObject:@(matching * 1000)];
        }
    }
    XCTAssertEqual(matches, 10100000U);
    NSLog(@"Media benchmark median create match release %.3f us and retained "
          @"match %.3f ns",
        [creationSamples sortedArrayUsingSelector:@selector(compare:)][4].doubleValue, [matchingSamples sortedArrayUsingSelector:@selector(compare:)][4].doubleValue);

    for (NSNumber* count in @[ @1, @50 ]) {
        NSMutableString* body = [NSMutableString string];
        for (NSUInteger index = 0; index < count.unsignedIntegerValue; index++) {
            [body appendString:@"<rect width='8' height='8'/>"];
        }
        NSMutableArray<NSString*>* documents = [NSMutableArray array];
        for (NSString *attribute in @[ @"", [NSString stringWithFormat:@" media='%@'", media] ]) {
            [documents addObject:[NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' "
                                                            @"width='800' height='200'>"
                                                             "<style%@>rect{fill:blue}</style>%@</svg>",
                                     attribute, body]];
        }
        NSMutableArray<NSNumber*>* plainSamples = [NSMutableArray array];
        NSMutableArray<NSNumber*>* mediaSamples = [NSMutableArray array];
        NSUInteger children = 0;
        for (NSUInteger round = 0; round < 10; round++) {
            for (NSUInteger pass = 0; pass < 2; pass++) {
                NSUInteger variant = (round + pass) % 2;
                NSString* document = documents[variant];
                NSTimeInterval start = NSProcessInfo.processInfo.systemUptime;
                for (NSUInteger iteration = 0; iteration < 200; iteration++) {
                    @autoreleasepool {
                        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:document fileURL:nil error:nil];
                        children += [parser rootNodeWithSize:environment.viewport].children.count;
                    }
                }
                NSTimeInterval elapsed = NSProcessInfo.processInfo.systemUptime - start;
                if (round != 0) {
                    [(variant == 0 ? plainSamples : mediaSamples) addObject:@(elapsed * 5000)];
                }
            }
        }
        XCTAssertEqual(children, count.unsignedIntegerValue * 4000);
        double plain = [plainSamples sortedArrayUsingSelector:@selector(compare:)][4].doubleValue;
        double conditional = [mediaSamples sortedArrayUsingSelector:@selector(compare:)][4].doubleValue;
        NSLog(@"Media benchmark %@ shapes plain %.3f us conditional %.3f us delta "
              @"%.3f us %.2f percent",
            count, plain, conditional, conditional - plain, (conditional / plain - 1) * 100);
    }
}

- (void)testStyleMediaUsesDocumentViewport
{
    IJSVGStyleSheet* sheet = [[IJSVGStyleSheet alloc] init];
    NSString* repeated = @"@media (min-width:600px){rect{stroke-width:2}}"
                          "@media (min-width:600px){rect{stroke-width:3}}";
    [sheet parseStyleBlock:repeated viewport:CGSizeMake(400, 200)];
    XCTAssertEqual(sheet.ruleCount, 0u);
    [sheet parseStyleBlock:repeated viewport:CGSizeMake(800, 200)];
    XCTAssertEqual(sheet.ruleCount, 2u);
    [sheet parseStyleBlock:repeated viewport:CGSizeMake(400, 200)];
    XCTAssertEqual(sheet.ruleCount, 2u);

    NSMutableString* uniqueConditions = [NSMutableString string];
    for (NSUInteger index = 0; index < 300; index++) {
        [uniqueConditions appendFormat:@"@media (min-width:%lupx){rect{stroke-width:2}}", index];
    }
    [sheet parseStyleBlock:uniqueConditions viewport:CGSizeMake(1000, 500)];
    XCTAssertEqual(sheet.ruleCount, 302u);

    // A valid condition larger than the cache budget still evaluates normally.
    NSString* padding = [@"" stringByPaddingToLength:70 * 1024 withString:@" " startingAtIndex:0];
    NSString* oversized = [NSString stringWithFormat:@"@media %@screen{rect{stroke-width:4}}", padding];
    [sheet parseStyleBlock:[oversized stringByAppendingString:oversized] viewport:CGSizeMake(1000, 500)];
    XCTAssertEqual(sheet.ruleCount, 304u);

    // Exercise block rules through the SVG parser, including viewport resolution,
    // cascade order, inherited namespaces and conjunction with the media attribute.
    NSArray<NSArray*>* cases = @[
        @[ @"rect{stroke-width:1}@media screen{rect{stroke-width:2}}", @2 ],
        @[ @"@media screen{rect{stroke-width:2}}rect{stroke-width:3}", @3 ],
        @[ @"@media screen{rect{stroke-width:2!important}}rect{stroke-width:3}", @2 ],
        @[ @"#target{stroke-width:4}@media screen{rect{stroke-width:2}}", @4 ],
        @[ @"@media screen{@media (width:800px){rect{stroke-width:5}}}", @5 ],
        @[ @"@media print{@media screen{rect{stroke-width:9}}}rect{stroke-width:2}", @2 ],
        @[ @"@media screen{@media print{rect{stroke-width:9}}rect{stroke-width:3}}", @3 ],
        @[ @"@media (unknown:1){rect{stroke-width:9}}@media screen{rect{stroke-width:2}}", @2 ],
        @[ @"@unknown screen{rect{stroke-width:9}}@media screen{rect{stroke-width:2}}", @2 ],
        @[ @"@MEDIA /* comment */ (min-width:600px){rect{stroke-width:2}}", @2 ],
        @[ @"@media{rect{stroke-width:2}}", @2 ],
        @[ @" \t@MEDIA SCREEN AND (MIN-WIDTH:40EM) \n {rect{stroke-width:2}}", @2 ],
        @[ @"@media (min-width:600px){.café{stroke-width:9}rect{stroke-width:2}}", @2 ],
        @[ @"@media screen{rect{--value:6;stroke-width:var(--value)}}", @6 ],
        @[ @"@namespace s url(http://www.w3.org/2000/svg);@media screen{s|rect{stroke-width:7}}", @7 ],
        @[ @"@namespace s url(http://www.w3.org/2000/svg);@media screen{@namespace s url(urn:wrong);s|rect{stroke-width:7}}s|rect{stroke-width:8}", @8 ],
        @[ @"@media screen{rect{--text:'}';stroke-width:2}}rect{stroke-width:3}", @3 ],
        @[ @"@media screen{ }rect{stroke-width:3}", @3 ]
    ];
    for (NSArray* entry in cases) {
        for (NSString* media in @[ @"screen", @"print" ]) {
            NSString* xml = [NSString stringWithFormat:
                @"<svg xmlns='http://www.w3.org/2000/svg' width='800' height='200'>"
                 "<style media='%@'>%@</style><rect id='target' width='10' height='10' stroke-width='1'/></svg>",
                media, entry[0]];
            IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:xml fileURL:nil error:nil];
            IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(300, 150)];
            IJSVGGraphicsNode* rect = (IJSVGGraphicsNode*)root.children.lastObject;
            CGFloat expected = [media isEqualToString:@"screen"] ? [entry[1] doubleValue] : 1;
            XCTAssertEqualWithAccuracy(rect.strokeWidth.value, expected, .001, @"%@", entry[0]);
        }
    }
    for (NSNumber* size in @[ @400, @800 ]) {
        NSString* xml = @"<svg xmlns='http://www.w3.org/2000/svg' width='100%' height='200'>"
                        "<style>rect{stroke-width:1}@media (min-width:600px){rect{stroke-width:2}}</style>"
                        "<rect width='10' height='10'/></svg>";
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:xml fileURL:nil error:nil];
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(size.doubleValue, 200)];
        XCTAssertEqualWithAccuracy(((IJSVGGraphicsNode*)root.children.lastObject).strokeWidth.value,
            size.doubleValue >= 600 ? 2 : 1, .001);
    }
    NSArray<NSString*>* queries = @[ @"screen and (min-width:600px)", @"(width >= 600px)", @"print, (width > 599px) and (height:200px)", @"not screen and (max-width:599px)" ];
    for (NSString* query in queries) {
        for (NSNumber* width in @[ @400, @800 ]) {
            NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' "
                                                       @"width='%@' height='200'>"
                                                        "<style>rect{fill:red}</style><style "
                                                        "media='%@'>rect{fill:blue}</style>"
                                                        "<rect width='100' height='100'/></svg>",
                width, query];
            IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:xml fileURL:nil error:nil];
            IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(300, 150)];
            IJSVGColorNode* fill = (IJSVGColorNode*)((IJSVGGraphicsNode*)root.children.lastObject).fill;
            CGColorRef color = [IJSVGColor computeColorSpace:fill.color];
            XCTAssertEqualWithAccuracy(CGColorGetComponents(color)[2], width.doubleValue >= 600 ? 1 : 0, .001);
        }
    }
    for (NSString* query in @[ @"print", @"(unknown:600px)", @"not (width:banana)", @"(width:600garbage)" ]) {
        NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='800' height='200'>"
                                                    "<style>rect{fill:red}</style><style "
                                                    "media='%@'>rect{fill:blue}</style><rect "
                                                    "width='10' height='10'/></svg>",
            query];
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:xml fileURL:nil error:nil];
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(800, 200)];
        IJSVGColorNode* fill = (IJSVGColorNode*)((IJSVGGraphicsNode*)root.children.lastObject).fill;
        XCTAssertEqualWithAccuracy(CGColorGetComponents([IJSVGColor computeColorSpace:fill.color])[0], 1, .001);
    }
}

- (void)testParserAppliesStyleElementRulesToNodeAttributes
{
    NSString* body = @"<style>rect.target { fill: #00ff00; stroke: #0000ff; "
                     @"stroke-width: 2; }</style>"
                      "<rect class=\"target\" width=\"8\" height=\"8\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body) fileURL:nil error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGPath* rect = (IJSVGPath*)rootNode.children.firstObject;

    XCTAssertTrue([rect.fill isKindOfClass:IJSVGColorNode.class]);
    XCTAssertTrue([rect.stroke isKindOfClass:IJSVGColorNode.class]);
    XCTAssertEqualWithAccuracy(rect.strokeWidth.value, 2.f, 0.001);
}

- (void)testParserAllowsInlineStyleToOverrideStyleElement
{
    NSString* body = @"<style>rect { fill: #00ff00; stroke-width: 1; "
                     @"}</style><rect width=\"8\" "
                      "height=\"8\" style=\"fill: #ff0000; stroke-width: 3;\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body) fileURL:nil error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGPath* rect = (IJSVGPath*)rootNode.children.firstObject;
    IJSVGColorNode* fill = (IJSVGColorNode*)rect.fill;
    CGColorRef rgbColor = [IJSVGColor computeColorSpace:fill.color];

    XCTAssertEqualWithAccuracy(CGColorGetComponents(rgbColor)[0], 1.f, 0.03);
    XCTAssertEqualWithAccuracy(CGColorGetComponents(rgbColor)[1], 0.f, 0.03);
    XCTAssertEqualWithAccuracy(CGColorGetComponents(rgbColor)[2], 0.f, 0.03);
    XCTAssertEqualWithAccuracy(rect.strokeWidth.value, 3.f, 0.001);
}

- (void)testParserBuildsNestedNodeTreeWithParentLinksAndOrder
{
    NSString* body = @"<title>Root title</title><desc>Root description</desc><g id=\"outer\" "
                      "class=\"container\" transform=\"translate(2,3)\"><rect id=\"first\" "
                      "width=\"2\" "
                      "height=\"2\"/><g id=\"inner\"><circle id=\"dot\" cx=\"4\" cy=\"4\" "
                      "r=\"1\"/></g>"
                      "<line id=\"last\" x1=\"0\" y1=\"0\" x2=\"8\" y2=\"8\"/></g>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body) fileURL:nil error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGGroup* outer = (IJSVGGroup*)rootNode.children.firstObject;
    IJSVGPath* first = (IJSVGPath*)outer.children[0];
    IJSVGGroup* inner = (IJSVGGroup*)outer.children[1];
    IJSVGPath* dot = (IJSVGPath*)inner.children.firstObject;
    IJSVGPath* last = (IJSVGPath*)outer.children[2];

    XCTAssertEqualObjects(rootNode.title, @"Root title");
    XCTAssertEqualObjects(rootNode.desc, @"Root description");
    XCTAssertEqual(rootNode.children.count, 1);
    XCTAssertTrue([outer isKindOfClass:IJSVGGroup.class]);
    XCTAssertEqualObjects(outer.identifier, @"outer");
    XCTAssertTrue([outer.classNameList containsObject:@"container"]);
    XCTAssertEqual(outer.transforms.count, 1);
    XCTAssertEqual(outer.transforms.firstObject.command, IJSVGTransformCommandTranslate);
    XCTAssertEqual(outer.children.count, 3);
    XCTAssertEqual(first.parentNode, outer);
    XCTAssertEqual(inner.parentNode, outer);
    XCTAssertEqual(last.parentNode, outer);
    XCTAssertEqual(dot.parentNode, inner);
    XCTAssertEqualObjects(first.identifier, @"first");
    XCTAssertEqualObjects(inner.identifier, @"inner");
    XCTAssertEqualObjects(dot.identifier, @"dot");
    XCTAssertEqualObjects(last.identifier, @"last");
    XCTAssertEqual(dot.primitiveType, kIJSVGPrimitivePathTypeCircle);
    XCTAssertEqual(last.primitiveType, kIJSVGPrimitivePathTypeLine);
}

- (void)testParserPreservesUnicodeAttributeOnGlyphNodes
{
    NSString* body = @"<glyph unicode=\"A\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body) fileURL:nil error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGGlyph* glyph = (IJSVGGlyph*)rootNode.children.firstObject;

    XCTAssertEqual(rootNode.children.count, 1);
    XCTAssertEqualObjects(glyph.name, @"glyph");
    XCTAssertEqualObjects(glyph.unicode, @"A");
}

- (void)testParserCopiesRepeatedUseReferencesIntoDistinctChildren
{
    NSString* body = @"<defs><path id=\"shape\" d=\"M0 0 H8\"/></defs><use id=\"first-use\" "
                      "href=\"#shape\"/><use id=\"second-use\" href=\"#shape\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body) fileURL:nil error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGGroup* firstUse = (IJSVGGroup*)rootNode.children[0];
    IJSVGGroup* secondUse = (IJSVGGroup*)rootNode.children[1];
    IJSVGPath* firstShadowPath = (IJSVGPath*)firstUse.children.firstObject;
    IJSVGPath* secondShadowPath = (IJSVGPath*)secondUse.children.firstObject;

    XCTAssertEqual(rootNode.children.count, 2);
    XCTAssertEqual(firstUse.type, IJSVGNodeTypeUse);
    XCTAssertEqual(secondUse.type, IJSVGNodeTypeUse);
    XCTAssertEqual(firstUse.children.count, 1);
    XCTAssertEqual(secondUse.children.count, 1);
    XCTAssertNotEqual(firstShadowPath, secondShadowPath);
    XCTAssertEqual(firstShadowPath.parentNode, firstUse);
    XCTAssertEqual(secondShadowPath.parentNode, secondUse);
    XCTAssertEqualObjects(firstShadowPath.identifier, @"shape");
    XCTAssertEqualObjects(secondShadowPath.identifier, @"shape");
}

- (void)testParserMapsPrimitiveShapeTypesInRootOrder
{
    NSString* body = @"<rect id=\"rect\" width=\"1\" height=\"1\"/><circle "
                     @"id=\"circle\" cx=\"2\" "
                      "cy=\"2\" r=\"1\"/><ellipse id=\"ellipse\" cx=\"3\" "
                      "cy=\"3\" rx=\"1\" ry=\"2\"/>"
                      "<polygon id=\"polygon\" points=\"0,0 2,0 2,2\"/><polyline "
                      "id=\"polyline\" "
                      "points=\"0,0 1,1 2,0\"/><line id=\"line\" x1=\"0\" "
                      "y1=\"0\" x2=\"8\" y2=\"8\"/>"
                      "<path id=\"path\" d=\"M0 0 H8\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body) fileURL:nil error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    NSArray<NSNumber*>* expectedTypes = @[ @(kIJSVGPrimitivePathTypeRect), @(kIJSVGPrimitivePathTypeCircle), @(kIJSVGPrimitivePathTypeEllipse), @(kIJSVGPrimitivePathTypePolygon), @(kIJSVGPrimitivePathTypePolyLine), @(kIJSVGPrimitivePathTypeLine), @(kIJSVGPrimitivePathTypePath) ];
    NSArray<NSString*>* expectedIdentifiers = @[ @"rect", @"circle", @"ellipse", @"polygon", @"polyline", @"line", @"path" ];

    XCTAssertEqual(rootNode.children.count, expectedTypes.count);
    for (NSUInteger index = 0; index < expectedTypes.count; index++) {
        IJSVGPath* path = (IJSVGPath*)rootNode.children[index];
        XCTAssertTrue([path isKindOfClass:IJSVGPath.class]);
        XCTAssertEqual(path.primitiveType, expectedTypes[index].integerValue);
        XCTAssertEqualObjects(path.identifier, expectedIdentifiers[index]);
        XCTAssertEqual(path.parentNode, rootNode);
    }
}

- (void)testParserResolvesClipPathAndMaskReferencesIntoDetachedNodeTrees
{
    NSString* body = @"<defs><clipPath id=\"clip\"><rect id=\"clip-rect\" "
                     @"width=\"4\" height=\"4\"/>"
                      "</clipPath><mask id=\"mask\"><rect id=\"mask-rect\" "
                      "width=\"8\" height=\"8\" "
                      "fill=\"#ffffff\"/></mask></defs><rect id=\"target\" "
                      "width=\"8\" height=\"8\" "
                      "clip-path=\"url(#clip)\" mask=\"url(#mask)\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body) fileURL:nil error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGPath* target = (IJSVGPath*)rootNode.children.firstObject;

    XCTAssertEqual(rootNode.children.count, 1);
    XCTAssertEqualObjects(target.identifier, @"target");
    XCTAssertTrue([target.clipPath isKindOfClass:IJSVGClipPath.class]);
    XCTAssertTrue([target.mask isKindOfClass:IJSVGMask.class]);
    XCTAssertEqual(target.clipPath.children.count, 1);
    XCTAssertEqual(target.mask.children.count, 1);
    XCTAssertEqualObjects(target.clipPath.children.firstObject.identifier, @"clip-rect");
    XCTAssertEqualObjects(target.mask.children.firstObject.identifier, @"mask-rect");
}

- (void)testParserBuildsGradientNodeTreeAndStopColors
{
    NSString* body = @"<defs><linearGradient id=\"fade\" x1=\"0\" y1=\"0\" x2=\"8\" y2=\"0\" "
                      "gradientUnits=\"userSpaceOnUse\"><stop offset=\"0\" "
                      "stop-color=\"#ff0000\"/><stop "
                      "offset=\"1\" stop-color=\"#0000ff\" "
                      "stop-opacity=\"0.5\"/></linearGradient></defs>"
                      "<rect id=\"target\" width=\"8\" height=\"8\" fill=\"url(#fade)\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body) fileURL:nil error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGPath* target = (IJSVGPath*)rootNode.children.firstObject;
    IJSVGLinearGradient* gradient = (IJSVGLinearGradient*)target.fill;
    CGColorRef firstColor = [IJSVGColor computeColorSpace:(__bridge CGColorRef)gradient.colors.firstObject];
    CGColorRef lastColor = [IJSVGColor computeColorSpace:(__bridge CGColorRef)gradient.colors.lastObject];

    XCTAssertTrue([gradient isKindOfClass:IJSVGLinearGradient.class]);
    XCTAssertEqualObjects(gradient.identifier, @"fade");
    XCTAssertEqual(gradient.numberOfStops, 2);
    XCTAssertEqual(gradient.colors.count, 2);
    XCTAssertEqualWithAccuracy(gradient.locations[0], 0.f, 0.001);
    XCTAssertEqualWithAccuracy(gradient.locations[1], 1.f, 0.001);
    XCTAssertEqualWithAccuracy(gradient.x1.value, 0.f, 0.001);
    XCTAssertEqualWithAccuracy(gradient.y1.value, 0.f, 0.001);
    XCTAssertEqualWithAccuracy(gradient.x2.value, 8.f, 0.001);
    XCTAssertEqualWithAccuracy(gradient.y2.value, 0.f, 0.001);
    XCTAssertEqualWithAccuracy(CGColorGetComponents(firstColor)[0], 1.f, 0.03);
    XCTAssertEqualWithAccuracy(CGColorGetComponents(firstColor)[2], 0.f, 0.03);
    XCTAssertEqualWithAccuracy(CGColorGetComponents(lastColor)[0], 0.f, 0.03);
    XCTAssertEqualWithAccuracy(CGColorGetComponents(lastColor)[2], 1.f, 0.03);
    XCTAssertEqualWithAccuracy(CGColorGetAlpha(lastColor), 0.5f, 0.03);
}

- (void)testParserReturnsErrorForMalformedXML
{
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:@"<svg><rect></svg>" fileURL:nil error:&error];

    XCTAssertNil(parser);
    XCTAssertNotNil(error);
}

@end
