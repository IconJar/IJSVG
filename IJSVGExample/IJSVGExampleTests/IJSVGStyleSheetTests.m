//
//  IJSVGStyleSheetTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetSelectorRaw.h>
#import <IJSVGStyleSheetUtils.h>
#import <IJSVGTestHelpers.h>

BOOL IJSVGStyleSheetCharIsWhitespace(char aChar);
BOOL IJSVGStyleSheetCharIsCombinator(char aChar);
BOOL IJSVGStyleSheetCharEndsIdentifier(char aChar);
BOOL IJSVGStyleSheetCharIsInvalidSelectorChar(char aChar);
BOOL IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(const char* chars, NSUInteger index, NSUInteger length);
NSUInteger IJSVGStyleSheetIndexBySkippingWhitespace(const char* chars, NSUInteger index, NSUInteger length);
IJSVGStyleSheetSelectorCombinator IJSVGStyleSheetCombinatorForChar(char aChar);
NSString* IJSVGStyleSheetCombinatorStringForCombinator(IJSVGStyleSheetSelectorCombinator combinator);
NSString* IJSVGStyleSheetStringFromUTF8Bytes(const char* chars, NSUInteger start, NSUInteger end);
NSString* IJSVGStyleSheetStringByRemovingCSSComments(NSString* string);
BOOL IJSVGStyleSheetSelectorRawHasSimpleSelector(IJSVGStyleSheetSelectorRaw* rawSelector);
BOOL IJSVGStyleSheetSelectorRawHasAnySelector(IJSVGStyleSheetSelectorRaw* rawSelector, BOOL hasUniversalSelector);
BOOL IJSVGStyleSheetSelectorCommitRawSelector(NSMutableArray<IJSVGStyleSheetSelectorRaw*>* parsedSelectors, IJSVGStyleSheetSelectorRaw* rawSelector, BOOL hasUniversalSelector);
IJSVGStyleSheetSelectorRaw* IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinator combinator);

static NSString* IJSVGNestedFill(NSString* css, BOOL useCircle)
{
    IJSVGStyleSheetSelectorRecord* root = [[IJSVGStyleSheetSelectorRecord alloc] init];
    IJSVGStyleSheetSelectorRecord* group = [[IJSVGStyleSheetSelectorRecord alloc] init];
    IJSVGStyleSheetSelectorRecord* rect = [[IJSVGStyleSheetSelectorRecord alloc] init];
    IJSVGStyleSheetSelectorRecord* circle = [[IJSVGStyleSheetSelectorRecord alloc] init];
    root.name = @"svg";
    group.name = @"g";
    group.classNameList = [NSSet setWithObject:@"panel"];
    rect.name = @"rect";
    rect.classNameList = [NSSet setWithObject:@"item"];
    circle.name = @"circle";
    circle.classNameList = [NSSet setWithObject:@"item"];
    group.selectorParent = root;
    root.selectorFirstChild = group;
    rect.selectorParent = group;
    circle.selectorParent = group;
    group.selectorFirstChild = rect;
    rect.selectorNextSibling = circle;
    circle.selectorPreviousSibling = rect;
    IJSVGStyleSheet* sheet = [[IJSVGStyleSheet alloc] init];
    [sheet parseStyleBlock:css viewport:CGSizeMake(512, 512)];
    return [[sheet styleForNode:useCircle ? circle : rect] property:@"fill"];
}

@interface IJSVGStyleSheetTests : XCTestCase
@end

@implementation IJSVGStyleSheetTests

- (void)testDeclarationPropertyNormalization
{
    for (NSString* property in @[ @"fill", @"FILL", @"Stroke-Width", @"--Custom", @"UNKNOWN", @"\u212aey", @"fill\0extra" ]) {
        NSDictionary* expanded = nil;
        NSString* value = [property caseInsensitiveCompare:@"stroke-width"] == NSOrderedSame ? @"2px" : @"red";
        NSString* result = IJSVGStyleSheetResolveDeclaration(property, value, &expanded);
        XCTAssertEqualObjects(result, [property hasPrefix:@"--"] ? property : property.lowercaseString);
    }
    NSDictionary* expanded = nil;
    XCTAssertNil(IJSVGStyleSheetResolveDeclaration(@"TRANSFORM-ORIGIN", @"left right", &expanded));
    XCTAssertEqualObjects(IJSVGStyleSheetResolveDeclaration(@"TRANSFORM-ORIGIN", @"top right", &expanded), @"transform-origin");
}

- (void)testGeometryDeclarationParsingPerformance
{
    NSString* declarations = @"x:1px;y:2px;width:30px;height:40px;cx:5px;cy:6px;"
                             @"r:7px;rx:8px;ry:9px;fill:red;stroke:blue";
    [self measureBlock:^{
        for (NSUInteger index = 0; index < 10000; index++) {
            @autoreleasepool {
                IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleString:declarations];
                XCTAssertEqualObjects([style property:@"width"], @"30px");
            }
        }
    }];
}

- (void)testStyleSheetMatchesTagIdentifierAndClassSelector
{
    IJSVGStyleSheet* styleSheet = IJSVGTestStyleSheet(@"rect#primary.warning.active { fill: #ff0000; }");
    IJSVGNode* node = IJSVGTestNode(@"rect", @"primary", @[ @"warning", @"active" ]);

    IJSVGStyleSheetStyle* style = [styleSheet styleForNode:node];
    XCTAssertEqualObjects([style property:@"fill"], @"#ff0000");
}

- (void)testStyleSheetRequiresEveryClassInSelector
{
    IJSVGStyleSheet* styleSheet = IJSVGTestStyleSheet(@"rect.warning.active { fill: #ff0000; }");
    IJSVGNode* node = IJSVGTestNode(@"rect", nil, @[ @"warning" ]);

    IJSVGStyleSheetStyle* style = [styleSheet styleForNode:node];
    XCTAssertNil([style property:@"fill"]);
}

- (void)testStyleSheetMatchesDescendantButNotDirectChildSelector
{
    IJSVGGroup* outer = IJSVGTestGroup(@"outer", nil);
    IJSVGGroup* inner = IJSVGTestGroup(nil, nil);
    IJSVGNode* rect = IJSVGTestNode(@"rect", nil, nil);
    [outer addChild:inner];
    [inner addChild:rect];

    IJSVGStyleSheet* descendantStyleSheet = IJSVGTestStyleSheet(@"#outer rect { fill: #00ff00; }");
    XCTAssertEqualObjects([[descendantStyleSheet styleForNode:rect] property:@"fill"], @"#00ff00");

    IJSVGStyleSheet* directStyleSheet = IJSVGTestStyleSheet(@"#outer > rect { fill: #ff0000; }");
    XCTAssertNil([[directStyleSheet styleForNode:rect] property:@"fill"]);
}

- (void)testStyleSheetMatchesAdjacentSiblingSelector
{
    IJSVGGroup* parent = IJSVGTestGroup(nil, nil);
    IJSVGNode* first = IJSVGTestNode(@"rect", nil, @[ @"first" ]);
    IJSVGNode* second = IJSVGTestNode(@"circle", nil, @[ @"second" ]);
    [parent addChild:first];
    [parent addChild:second];

    IJSVGStyleSheet* styleSheet = IJSVGTestStyleSheet(@"rect.first + circle.second { fill: #00ff00; }");
    XCTAssertEqualObjects([[styleSheet styleForNode:second] property:@"fill"], @"#00ff00");
    XCTAssertNil([[styleSheet styleForNode:first] property:@"fill"]);
}

- (void)testStyleSheetMatchesPrecededSiblingSelector
{
    IJSVGGroup* parent = IJSVGTestGroup(nil, nil);
    IJSVGNode* first = IJSVGTestNode(@"rect", nil, @[ @"first" ]);
    IJSVGNode* middle = IJSVGTestNode(@"path", nil, nil);
    IJSVGNode* last = IJSVGTestNode(@"circle", nil, @[ @"last" ]);
    [parent addChild:first];
    [parent addChild:middle];
    [parent addChild:last];

    IJSVGStyleSheet* styleSheet = IJSVGTestStyleSheet(@"rect.first ~ circle.last { fill: #00ff00; }");
    XCTAssertEqualObjects([[styleSheet styleForNode:last] property:@"fill"], @"#00ff00");
    XCTAssertNil([[styleSheet styleForNode:middle] property:@"fill"]);
}

- (void)testStyleSheetAppliesCommaSeparatedSelectors
{
    IJSVGStyleSheet* styleSheet = IJSVGTestStyleSheet(@"circle, rect.highlight { stroke: #111111; }");
    IJSVGNode* circle = IJSVGTestNode(@"circle", nil, nil);
    IJSVGNode* rect = IJSVGTestNode(@"rect", nil, @[ @"highlight" ]);

    XCTAssertEqual(styleSheet.ruleCount, 1);
    XCTAssertEqualObjects([[styleSheet styleForNode:circle] property:@"stroke"], @"#111111");
    XCTAssertEqualObjects([[styleSheet styleForNode:rect] property:@"stroke"], @"#111111");
}

- (void)testStyleSheetUsesSpecificityBeforeSourceOrder
{
    IJSVGStyleSheet* styleSheet = IJSVGTestStyleSheet(@"#target { fill: #00ff00; } rect { fill: #ff0000; "
                                                       "}");
    IJSVGNode* node = IJSVGTestNode(@"rect", @"target", nil);

    XCTAssertEqualObjects([[styleSheet styleForNode:node] property:@"fill"], @"#00ff00");
}

- (void)testStyleSheetUsesSourceOrderForEqualSpecificity
{
    IJSVGStyleSheet* styleSheet = IJSVGTestStyleSheet(@"rect { fill: #ff0000; } rect { fill: #00ff00; }");
    IJSVGNode* node = IJSVGTestNode(@"rect", nil, nil);

    XCTAssertEqualObjects([[styleSheet styleForNode:node] property:@"fill"], @"#00ff00");
}

- (void)testStyleSheetIgnoresCommentsAndKeepsUrlBraces
{
    IJSVGStyleSheet* styleSheet = IJSVGTestStyleSheet(@"/* ignore */ rect { fill: url(#gradient); "
                                                       "stroke: #101010; }");
    IJSVGNode* node = IJSVGTestNode(@"rect", nil, nil);
    IJSVGStyleSheetStyle* style = [styleSheet styleForNode:node];

    XCTAssertEqualObjects([style property:@"fill"], @"url(#gradient)");
    XCTAssertEqualObjects([style property:@"stroke"], @"#101010");
}

- (void)testStyleSheetDoublePipeCombinatorDoesNotMatchSVGAncestor
{
    IJSVGStyleSheet* styleSheet = IJSVGTestStyleSheet(@"#canvas || circle.pipe-target { fill: #c084fc; }");

    XCTAssertEqual(styleSheet.ruleCount, 1);

    IJSVGGroup* canvas = IJSVGTestGroup(@"canvas", nil);
    IJSVGNode* circle = IJSVGTestNode(@"circle", nil, @[ @"pipe-target" ]);
    [canvas addChild:circle];

    IJSVGStyleSheetStyle* style = [styleSheet styleForNode:circle];
    XCTAssertNil([style property:@"fill"]);
}

- (void)testStyleSheetAcceptsEmptyNamespacesAndRejectsMalformedPipes
{
    IJSVGStyleSheet* triplePipeStyleSheet = IJSVGTestStyleSheet(@"g ||| rect { fill: #ff0000; }");
    XCTAssertEqual(triplePipeStyleSheet.ruleCount, 0);

    IJSVGStyleSheet* leadingPipeStyleSheet = IJSVGTestStyleSheet(@"|rect { fill: #ff0000; }");
    XCTAssertEqual(leadingPipeStyleSheet.ruleCount, 1);
    IJSVGStyleSheetSelectorRecord* record = [[IJSVGStyleSheetSelectorRecord alloc] init];
    record.name = @"rect";
    XCTAssertNotNil([leadingPipeStyleSheet styleForNode:record]);
    record.namespaceURI = @"http://www.w3.org/2000/svg";
    XCTAssertNil([leadingPipeStyleSheet styleForNode:record]);
}

- (void)testStyleSheetAcceptsAttributesAndRejectsUnsupportedPseudoClasses
{
    IJSVGStyleSheet* attributeStyleSheet = IJSVGTestStyleSheet(@"rect[fill] { fill: #ff0000; }");
    XCTAssertEqual(attributeStyleSheet.ruleCount, 1);
    XCTAssertTrue(attributeStyleSheet.requiresSelectorTree);

    IJSVGStyleSheet* pseudoStyleSheet = IJSVGTestStyleSheet(@"rect:hover { fill: #ff0000; }");
    XCTAssertEqual(pseudoStyleSheet.ruleCount, 0);
}

- (void)testStyleDeclarationParserKeepsQuotedDelimitersAndComments
{
    IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleString:@"font-family: 'A;B'; fill: "
                                                                          "#ffffff; marker: url(\"#a;"
                                                                          "b\"); content: '/* not a "
                                                                          "comment */';"];

    XCTAssertEqualObjects([style property:@"font-family"], @"'A;B'");
    XCTAssertEqualObjects([style property:@"fill"], @"#ffffff");
    XCTAssertEqualObjects([style property:@"marker"], @"url(\"#a;b\")");
    XCTAssertEqualObjects([style property:@"content"], @"'/* not a comment */'");
}

- (void)testStyleDeclarationParserKeepsTrailingURLValueWithoutSemicolon
{
    IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleString:@"fill:url(#squares)"];

    XCTAssertEqualObjects([style property:@"fill"], @"url(#squares)");
}

- (void)testStyleSheetUtilsClassifySelectorCharacters
{
    XCTAssertTrue(IJSVGStyleSheetCharIsWhitespace(' '));
    XCTAssertTrue(IJSVGStyleSheetCharIsWhitespace('\t'));
    XCTAssertTrue(IJSVGStyleSheetCharIsWhitespace('\n'));
    XCTAssertFalse(IJSVGStyleSheetCharIsWhitespace('a'));

    XCTAssertTrue(IJSVGStyleSheetCharIsCombinator('>'));
    XCTAssertTrue(IJSVGStyleSheetCharIsCombinator('+'));
    XCTAssertTrue(IJSVGStyleSheetCharIsCombinator('~'));
    XCTAssertFalse(IJSVGStyleSheetCharIsCombinator('|'));

    XCTAssertTrue(IJSVGStyleSheetCharEndsIdentifier('#'));
    XCTAssertTrue(IJSVGStyleSheetCharEndsIdentifier('.'));
    XCTAssertTrue(IJSVGStyleSheetCharEndsIdentifier('*'));
    XCTAssertTrue(IJSVGStyleSheetCharEndsIdentifier('|'));
    XCTAssertTrue(IJSVGStyleSheetCharEndsIdentifier('>'));
    XCTAssertTrue(IJSVGStyleSheetCharEndsIdentifier(' '));
    XCTAssertFalse(IJSVGStyleSheetCharEndsIdentifier('r'));

    XCTAssertTrue(IJSVGStyleSheetCharIsInvalidSelectorChar('@'));
    XCTAssertTrue(IJSVGStyleSheetCharIsInvalidSelectorChar(':'));
    XCTAssertTrue(IJSVGStyleSheetCharIsInvalidSelectorChar('['));
    XCTAssertTrue(IJSVGStyleSheetCharIsInvalidSelectorChar(']'));
    XCTAssertFalse(IJSVGStyleSheetCharIsInvalidSelectorChar('-'));
}

- (void)testStyleSheetUtilsDetectColumnCombinatorAtIndex
{
    const char* selector = "g || rect";
    NSUInteger length = strlen(selector);

    XCTAssertTrue(IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(selector, 2, length));
    XCTAssertFalse(IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(selector, 3, length));
    XCTAssertFalse(IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(selector, length - 1, length));
    XCTAssertFalse(IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(NULL, 0, 0));
}

- (void)testStyleSheetUtilsSkipWhitespaceFromIndex
{
    const char* selector = "rect   \n\t.circle";
    NSUInteger length = strlen(selector);

    XCTAssertEqual(IJSVGStyleSheetIndexBySkippingWhitespace(selector, 4, length), 9u);
    XCTAssertEqual(IJSVGStyleSheetIndexBySkippingWhitespace(selector, 0, length), 0u);
    XCTAssertEqual(IJSVGStyleSheetIndexBySkippingWhitespace(selector, length, length), length);
}

- (void)testStyleSheetUtilsMapCombinatorsToEnumsAndStrings
{
    XCTAssertEqual(IJSVGStyleSheetCombinatorForChar('>'), IJSVGStyleSheetSelectorCombinatorDirectDescendant);
    XCTAssertEqual(IJSVGStyleSheetCombinatorForChar('+'), IJSVGStyleSheetSelectorCombinatorNextSibling);
    XCTAssertEqual(IJSVGStyleSheetCombinatorForChar('~'), IJSVGStyleSheetSelectorCombinatorPrecededSibling);
    XCTAssertEqual(IJSVGStyleSheetCombinatorForChar('|'), IJSVGStyleSheetSelectorCombinatorColumn);
    XCTAssertEqual(IJSVGStyleSheetCombinatorForChar('?'), IJSVGStyleSheetSelectorCombinatorDirectDescendant);

    XCTAssertEqualObjects(IJSVGStyleSheetCombinatorStringForCombinator(IJSVGStyleSheetSelectorCombinatorDirectDescendant), @">");
    XCTAssertEqualObjects(IJSVGStyleSheetCombinatorStringForCombinator(IJSVGStyleSheetSelectorCombinatorNextSibling), @"+");
    XCTAssertEqualObjects(IJSVGStyleSheetCombinatorStringForCombinator(IJSVGStyleSheetSelectorCombinatorPrecededSibling), @"~");
    XCTAssertEqualObjects(IJSVGStyleSheetCombinatorStringForCombinator(IJSVGStyleSheetSelectorCombinatorColumn), @"||");
    XCTAssertEqualObjects(IJSVGStyleSheetCombinatorStringForCombinator(IJSVGStyleSheetSelectorCombinatorDescendant), @" ");
    XCTAssertEqualObjects(IJSVGStyleSheetCombinatorStringForCombinator(IJSVGStyleSheetSelectorCombinatorWildcard), @" ");
}

- (void)testStyleSheetUtilsCreateStringFromUTF8ByteRange
{
    const char* bytes = "rect.highlight > circle";

    XCTAssertEqualObjects(IJSVGStyleSheetStringFromUTF8Bytes(bytes, 5, 14), @"highlight");
    XCTAssertNil(IJSVGStyleSheetStringFromUTF8Bytes(bytes, 5, 5));
    XCTAssertNil(IJSVGStyleSheetStringFromUTF8Bytes(NULL, 0, 4));
}

- (void)testStyleSheetUtilsRemoveCSSCommentsOutsideQuotedStrings
{
    NSString* css = @"rect { fill: red; } /* remove */ .a::before { content: '/* "
                    @"keep */'; } \"/* keep "
                     "too */\" /* unterminated";
    NSString* clean = IJSVGStyleSheetStringByRemovingCSSComments(css);

    XCTAssertTrue([clean containsString:@"rect { fill: red; }"]);
    XCTAssertFalse([clean containsString:@"remove"]);
    XCTAssertTrue([clean containsString:@"'/* keep */'"]);
    XCTAssertTrue([clean containsString:@"\"/* keep too */\""]);
    XCTAssertFalse([clean containsString:@"unterminated"]);
}

- (void)testStyleSheetUtilsRawSelectorPresenceChecks
{
    IJSVGStyleSheetSelectorRaw* empty = IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinatorDescendant);
    IJSVGStyleSheetSelectorCombinator descendant = IJSVGStyleSheetSelectorCombinatorDirectDescendant;
    IJSVGStyleSheetSelectorRaw* withTag = IJSVGStyleSheetCreateRawSelector(descendant);
    IJSVGStyleSheetSelectorRaw* withID = IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinatorNextSibling);
    IJSVGStyleSheetSelectorCombinator sibling = IJSVGStyleSheetSelectorCombinatorPrecededSibling;
    IJSVGStyleSheetSelectorRaw* withClass = IJSVGStyleSheetCreateRawSelector(sibling);

    withTag.tag = @"rect";
    withID.identifier = @"target";
    [withClass addClassName:@"selected"];

    XCTAssertFalse(IJSVGStyleSheetSelectorRawHasSimpleSelector(empty));
    XCTAssertTrue(IJSVGStyleSheetSelectorRawHasSimpleSelector(withTag));
    XCTAssertTrue(IJSVGStyleSheetSelectorRawHasSimpleSelector(withID));
    XCTAssertTrue(IJSVGStyleSheetSelectorRawHasSimpleSelector(withClass));
    XCTAssertFalse(IJSVGStyleSheetSelectorRawHasAnySelector(empty, NO));
    XCTAssertTrue(IJSVGStyleSheetSelectorRawHasAnySelector(empty, YES));
}

- (void)testStyleSheetUtilsCommitRawSelectorOnlyWhenSelectorExists
{
    NSMutableArray<IJSVGStyleSheetSelectorRaw*>* selectors = [[NSMutableArray alloc] init];
    IJSVGStyleSheetSelectorRaw* empty = IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinatorDescendant);
    IJSVGStyleSheetSelectorRaw* universal = IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinatorWildcard);
    IJSVGStyleSheetSelectorRaw* tagged = IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinatorDirectDescendant);
    tagged.tag = @"rect";

    XCTAssertFalse(IJSVGStyleSheetSelectorCommitRawSelector(selectors, empty, NO));
    XCTAssertEqual(selectors.count, 0u);

    XCTAssertTrue(IJSVGStyleSheetSelectorCommitRawSelector(selectors, universal, YES));
    XCTAssertEqual(selectors.count, 1u);
    XCTAssertEqual(selectors[0].combinator, IJSVGStyleSheetSelectorCombinatorWildcard);
    XCTAssertEqualObjects(selectors[0].combinatorString, @" ");

    XCTAssertTrue(IJSVGStyleSheetSelectorCommitRawSelector(selectors, tagged, NO));
    XCTAssertEqual(selectors.count, 2u);
    XCTAssertEqualObjects(selectors[1].tag, @"rect");
    XCTAssertEqualObjects(selectors[1].combinatorString, @">");
}

- (void)testNestedSelectorsMatch
{
    for (NSString* css in @[
             @".panel { rect { fill: red } }",
             @".panel { > rect { fill: red } }",
             @".panel { & > rect { fill: red } }",
             @"rect { &.item { fill: red } }",
             @"rect { svg & { fill: red } }",
             @".panel { :is(&) > rect { fill: red } }",
             @".panel { & { > rect { fill: red } } }",
             @".panel, #missing { rect, ellipse { fill: red } }",
             @"svg { .panel { rect { fill: red } } }",
             @".panel:has(rect) { & > rect { fill: red } }",
             @"rect { :is(&, .absent) { fill: red } }",
             @"rect { &:nth-child(1 of &) { fill: red } }"
         ]) {
        XCTAssertEqualObjects(IJSVGNestedFill(css, NO), @"red", @"%@", css);
    }
}

- (void)testNestedSiblingAndRelativeHas
{
    XCTAssertEqualObjects(IJSVGNestedFill(@".item { + & { fill: red } }", YES), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@".panel, .item { > & { fill: red } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { + circle { fill: red } }", YES), @"red");
    XCTAssertNil(IJSVGNestedFill(@"rect { circle:has(~ &) { fill: red } }", YES));
    XCTAssertEqualObjects(IJSVGNestedFill(@"circle { rect:has(+ &) { fill: red } }", NO), @"red");
}

- (void)testNestedSpecificityAndOrder
{
    XCTAssertEqualObjects(IJSVGNestedFill(@".panel, #missing { rect { fill: red } } .panel rect { fill: blue }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { :where(&) { fill: red } } .item { fill: blue }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@".item { && { fill: red } } .item { fill: blue }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { fill: red; & { fill: blue } fill: green }", NO), @"green");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { fill: red !important; & { fill: blue } fill: green }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect, #missing { & { fill: red } fill: green }", NO), @"red");
}

- (void)testNestedMediaDeclarationsKeepParentSpecificity
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect, #missing { @media screen { fill: red } } .item { fill: blue }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { fill: red; @media screen { fill: blue } fill: green }", NO), @"green");
    XCTAssertEqualObjects(IJSVGNestedFill(@".panel { @media (min-width: 500px) { > rect { fill: red } } }", NO), @"red");
    XCTAssertNil(IJSVGNestedFill(@".panel { @media (max-width: 500px) { > rect { fill: red } } }", NO));
    XCTAssertEqualObjects(IJSVGNestedFill(@"@media screen { .panel { @media (min-width: 500px) { rect { fill: red } } } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { @media screen { fill: red; & { fill: blue } fill: green } }", NO), @"green");
}

- (void)testNestingRecoveryAndTokenBoundaries
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { &rect { fill: red } fill: green }", NO), @"green");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { & { fill: red } @unknown thing; fill: green }", NO), @"green");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { @unknown { & { fill: red } } fill: green }", NO), @"green");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { &, :unknown { fill: red } fill: green }", NO), @"green");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { --tokens: { a: b; }; & { fill: green } }", NO), @"green");
    XCTAssertEqualObjects(IJSVGNestedFill(@".panel { [data-value='&'], rect { fill: red } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@".panel { .escaped\\&, rect { fill: red } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@".panel { /* & */ rect { fill: red } }", NO), @"red");
}

- (void)testNestingRejectsEmptyListEntriesAndPreservesURLBlocks
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { , & { fill: red } fill: green }", NO), @"green");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { &, { fill: red } fill: green }", NO), @"green");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { & { fill: url(data:image/svg+xml,}) } fill: green }", NO), @"green");
}

- (void)testUnparentedAmpersandMatchesDocumentRoot
{
    IJSVGGroup* root = IJSVGTestGroup(nil, nil);
    IJSVGNode* rect = IJSVGTestNode(@"rect", nil, nil);
    [root addChild:rect];
    IJSVGStyleSheet* sheet = IJSVGTestStyleSheet(@"& { fill: red }");
    XCTAssertEqualObjects([[sheet styleForNode:root] property:@"fill"], @"red");
    XCTAssertNil([sheet styleForNode:rect]);
}

- (void)testNestingParentListsAreSharedAndDepthIsBounded
{
    NSMutableString* css = [NSMutableString stringWithString:@"rect { "];
    for (NSUInteger index = 0; index < 40; index++) {
        [css appendString:@"&, &.item { "];
    }
    [css appendString:@"fill: red"];
    for (NSUInteger index = 0; index < 41; index++) {
        [css appendString:@" }"];
    }
    XCTAssertEqual(IJSVGTestStyleSheet(css).ruleCount, 1UL);
    XCTAssertEqualObjects(IJSVGNestedFill(css, NO), @"red");
    css = [NSMutableString stringWithString:@"rect { "];
    for (NSUInteger index = 0; index < 70; index++) {
        [css appendString:@"& { "];
    }
    [css appendString:@"fill: red"];
    for (NSUInteger index = 0; index < 71; index++) {
        [css appendString:@" }"];
    }
    [css appendString:@" rect { fill: green }"];
    XCTAssertEqualObjects(IJSVGNestedFill(css, NO), @"green");
}

- (void)testNestedParentFastPathPreservesConstraints
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { g > & { fill: red } }", NO), @"red");
    XCTAssertNil(IJSVGNestedFill(@"rect { svg > & { fill: red } }", NO));
    XCTAssertNil(IJSVGNestedFill(@".panel { &.missing > rect { fill: red } }", NO));
    XCTAssertEqualObjects(IJSVGNestedFill(@".panel { && > rect { fill: red } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"svg > .panel { & > rect { fill: red } }", NO), @"red");

    IJSVGStyleSheetSelectorRecord* node = [[IJSVGStyleSheetSelectorRecord alloc] init];
    node.name = @"rect";
    node.classNameList = [NSSet setWithObject:@"item"];
    IJSVGStyleSheet* sheet = IJSVGTestStyleSheet(@"@namespace 'urn:svg'; .item { :is(&) { fill: red } }");
    node.namespaceURI = @"urn:svg";
    XCTAssertEqualObjects([[sheet styleForNode:node] property:@"fill"], @"red");
    node.namespaceURI = @"urn:other";
    XCTAssertNil([sheet styleForNode:node]);
}

- (void)testNestedStylesRenderLikeFlatStyles
{
    NSString* (^document)(NSString*) = ^NSString*(NSString* css) {
        return IJSVGTestSVG([NSString stringWithFormat:@"<style>%@</style><g class='panel'><rect width='8' height='8'/></g>", css]);
    };
    NSData* nested = IJSVGTestRGBADataForSVG(document(@".panel { > rect { fill: red } }"), CGSizeMake(8, 8));
    NSData* flat = IJSVGTestRGBADataForSVG(document(@".panel > rect { fill: red }"), CGSizeMake(8, 8));
    NSData* blue = IJSVGTestRGBADataForSVG(document(@"rect { fill: blue }"), CGSizeMake(8, 8));
    XCTAssertNotNil(nested);
    XCTAssertEqualObjects(nested, flat);
    XCTAssertNotEqualObjects(nested, blue);
}

- (void)testLayerOrderPrecedesSpecificity
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base, theme; @layer theme { rect { fill: blue } } @layer base { .item.item { fill: red } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base { .item { fill: red } } @layer theme { rect { fill: blue } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base, theme; @layer theme, base; @layer theme { rect { fill: blue } } @layer base { .item { fill: red } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { fill: green } @layer theme { .item.item { fill: red } }", NO), @"green");
}

- (void)testLayerImportantPriorityReversesOrder
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base, theme; @layer base { rect { fill: red !important } } @layer theme { .item { fill: blue !important } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base { rect { fill: red !important } } .item.item { fill: blue !important }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base { rect { fill: red } } @layer theme { rect { fill: blue !important } }", NO), @"blue");
    IJSVGStyleSheet* sheet = IJSVGTestStyleSheet(@"@layer base { rect { fill: red !important; stroke: red } } @layer theme { rect { fill: blue; stroke: blue } }");
    IJSVGStyleSheetStyle* style = [sheet styleForNode:IJSVGTestNode(@"rect", nil, nil)];
    XCTAssertTrue([style isPropertyImportant:@"fill"]);
    XCTAssertEqualObjects([style property:@"fill"], @"red");
    XCTAssertEqualObjects([style property:@"stroke"], @"blue");
}

- (void)testLayerSpecificityAndSourceOrderWithinReopenedLayer
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base { .item { fill: red } } @layer base { rect { fill: blue } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base { rect { fill: red } } @layer base { rect { fill: blue } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base { .item { fill: red !important } } @layer base { rect { fill: blue !important } }", NO), @"red");
}

- (void)testNestedLayerHierarchy
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a, b; @layer b { rect { fill: blue } } @layer a.late { .item { fill: red } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a { rect { fill: green } @layer child { .item { fill: red } } }", NO), @"green");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a { rect { fill: green !important } @layer child { .item { fill: red !important } } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a.first, a.second; @layer a { @layer second { rect { fill: blue } } @layer first { rect { fill: red } } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a.first { rect { fill: red } } @layer a { @layer first { rect { fill: blue } } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a { @layer child { rect { fill: red } } } @layer child { rect { fill: blue } }", NO), @"blue");
}

- (void)testAnonymousLayersAreDistinct
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer { .item { fill: red } } @layer { rect { fill: blue } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer { rect { fill: red !important } } @layer { .item { fill: blue !important } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer { @layer child { .item { fill: red } } } @layer { @layer child { rect { fill: blue } } }", NO), @"blue");
}

- (void)testLayersInsideMediaAndNestedStyleRules
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"@media print { @layer later; } @layer first { rect { fill: red } } @layer later { rect { fill: blue } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@media screen { @layer later; } @layer first { rect { fill: red } } @layer later { rect { fill: blue } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base { @media screen { .panel { rect { fill: red } } } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a, b; .panel { @layer b { > rect { fill: blue } } @layer a { > rect { fill: red } } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { @layer b, a; @layer a { fill: red } @layer b { fill: blue } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"rect { @layer a { fill: red } fill: green }", NO), @"green");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a { rect { @layer b { fill: red } fill: green } }", NO), @"green");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a { rect, #missing { @layer b { fill: red } .item { fill: blue } } } @layer a.b { .item { fill: green } }", NO), @"green");
}

- (void)testLayerNamesAndInvalidRuleRecovery
{
    for (NSString* invalid in @[ @"@layer a, b {}", @"@layer a.;", @"@layer a,;", @"@layer initial;", @"@layer a. inherit {}", @"@layer a .b {}", @"@layer a. b {}", @"@layer 'a' {}", @"@layer 2 {}", @"@layer a, initial;" ]) {
        NSString* css = [NSString stringWithFormat:@"%@ @layer b { rect { fill: blue } } @layer a { rect { fill: red } }", invalid];
        XCTAssertEqualObjects(IJSVGNestedFill(css, NO), @"red", @"%@", invalid);
    }
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer default { rect { fill: red } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer A, a; @layer a { rect { fill: blue } } @layer A { rect { fill: red } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer th\\65 me, later; @layer later { rect { fill: blue } } @layer theme { rect { fill: red } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a\\.b, a.b; @layer a.b { rect { fill: blue } } @layer a\\.b { rect { fill: red } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@LAYER theme { rect { fill: red } }", NO), @"red");
}

- (void)testLayerOrderingPersistsAcrossStyleBlocks
{
    IJSVGStyleSheet* sheet = IJSVGTestStyleSheet(@"@layer a, b; @layer a { rect { fill: red } }");
    IJSVGNode* node = IJSVGTestNode(@"rect", nil, nil);
    XCTAssertEqualObjects([[sheet styleForNode:node] property:@"fill"], @"red");
    [sheet parseStyleBlock:@"@layer b { rect { fill: blue } } @layer a.child { rect { fill: green } }"];
    XCTAssertEqualObjects([[sheet styleForNode:node] property:@"fill"], @"blue");
    [sheet parseStyleBlock:@"@layer a { rect { fill: red !important } }"];
    XCTAssertEqualObjects([[sheet styleForNode:node] property:@"fill"], @"red");

    IJSVGStyleSheet* parent = IJSVGTestStyleSheet(@"@layer a { rect { fill: red } }");
    XCTAssertEqualObjects([[parent styleForNode:node] property:@"fill"], @"red");
    [parent parseStyleBlock:@"@layer a.child { rect { fill: blue } }"];
    XCTAssertEqualObjects([[parent styleForNode:node] property:@"fill"], @"red");
}

- (void)testLayerStatementsAllowFollowingNamespaces
{
    IJSVGStyleSheet* sheet = IJSVGTestStyleSheet(@"@layer theme; @namespace s 'urn:svg'; @layer theme { s|rect { fill: red } }");
    IJSVGStyleSheetSelectorRecord* node = [[IJSVGStyleSheetSelectorRecord alloc] init];
    node.name = @"rect";
    node.namespaceURI = @"urn:svg";
    XCTAssertEqualObjects([[sheet styleForNode:node] property:@"fill"], @"red");
    node.namespaceURI = @"urn:other";
    XCTAssertNil([sheet styleForNode:node]);
}

- (void)testLayerDepthIsBoundedWithoutSwallowingFollowingRules
{
    NSMutableString* css = [NSMutableString string];
    for (NSUInteger index = 0; index < 70; index++) {
        [css appendString:@"@layer a {"];
    }
    [css appendString:@"rect { fill: red }"];
    for (NSUInteger index = 0; index < 70; index++) {
        [css appendString:@"}"];
    }
    [css appendString:@"@layer b { rect { fill: blue } }"];
    XCTAssertEqualObjects(IJSVGNestedFill(css, NO), @"blue");
}

- (void)testLayerRenderingCustomPropertiesAndInlinePriority
{
    NSArray<NSArray<NSString*>*>* cases = @[
        @[ @"@layer base, theme; @layer theme { rect { fill: red } } @layer base { #icon { fill: blue } }", @"" ],
        @[ @"@layer base { rect { fill: red !important } } rect { fill: blue !important }", @"style='fill: blue'" ],
        @[ @"@layer base { rect { fill: blue !important } }", @"style='fill: red !important'" ],
        @[ @"@layer base { rect { --paint: blue } } @layer theme { rect { --paint: red } } rect { fill: var(--paint) }", @"" ],
        @[ @"@layer base { rect { --paint: red !important } } @layer theme { rect { --paint: blue !important } } rect { fill: var(--paint) }", @"" ]
    ];
    NSData* reference = IJSVGTestRGBADataForSVG(IJSVGTestSVG(@"<rect width='8' height='8' fill='red'/>"), CGSizeMake(8, 8));
    for (NSArray<NSString*>* item in cases) {
        NSString* body = [NSString stringWithFormat:@"<style><![CDATA[%@]]></style><rect id='icon' width='8' height='8' fill='green' %@/>", item[0], item[1]];
        XCTAssertEqualObjects(IJSVGTestRGBADataForSVG(IJSVGTestSVG(body), CGSizeMake(8, 8)), reference, @"%@", item[0]);
    }
}

- (void)testRevertLayerSkipsWholeLayerAndRespectsSpecificity
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base { rect { fill: red } } @layer theme { rect { fill: blue } .item { fill: revert-layer } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base { rect { fill: red } } @layer theme { .item { fill: blue } rect { fill: revert-layer } }", NO), @"blue");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer base { rect { fill: red } } rect { fill: blue } .item { fill: revert-layer }", NO), @"red");
    XCTAssertNil(IJSVGNestedFill(@"rect { fill: red } .item { fill: revert-layer }", NO));
    XCTAssertNil(IJSVGNestedFill(@"rect { fill: revert-layer }", NO));
}

- (void)testRevertLayerImportantRemovesInterveningLayers
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a { rect { fill: red } } @layer b { rect { fill: blue; fill: revert-layer !important } } @layer c { rect { fill: green !important } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a { rect { fill: red !important } } @layer b { rect { fill: revert-layer !important } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a { rect { fill: red } } rect { fill: blue; fill: revert-layer !important }", NO), @"red");
    XCTAssertNil(IJSVGNestedFill(@"@layer a { rect { fill: revert-layer !important } } rect { fill: blue !important }", NO));
}

- (void)testRevertLayerChainsNestedAndAnonymousLayers
{
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer { rect { fill: red } } @layer { rect { fill: revert-layer } } @layer { rect { fill: revert-layer } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a { @layer b { rect { fill: red } } rect { fill: revert-layer } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a { rect { fill: red } } .panel { @layer b { & > rect { fill: revert-layer } } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a { rect { fill: red } } @layer b { rect { fill: REVERT-LAYER } }", NO), @"red");
    XCTAssertEqualObjects(IJSVGNestedFill(@"@layer a { rect { fill: red } } @layer b { rect { fill: re\\76 ert-layer } }", NO), @"red");
}

- (void)testRevertLayerShorthands
{
    IJSVGStyleSheet* sheet = IJSVGTestStyleSheet(@"@layer a { rect { font: italic 12px serif; marker: url(#a) } } @layer b { rect { font: revert-layer; marker: revert-layer } }");
    IJSVGStyleSheetStyle* style = [sheet styleForNode:IJSVGTestNode(@"rect", nil, nil)];
    XCTAssertEqualObjects([style property:@"font-size"], @"12px");
    XCTAssertEqualObjects([style property:@"font-style"], @"italic");
    XCTAssertEqualObjects([style property:@"font-family"], @"serif");
    XCTAssertEqualObjects([style property:@"marker-start"], @"url(#a)");
    XCTAssertEqualObjects([style property:@"marker-end"], @"url(#a)");
}

- (void)testRevertLayerRenderingAndInlineFallback
{
    NSArray<NSArray<NSString*>*>* cases = @[
        @[ @"rect { fill: revert-layer }", @"" ],
        @[ @"@layer a { rect { fill: revert-layer !important } }", @"style='fill: blue'" ],
        @[ @"@layer a { rect { fill: red } } @layer b { rect { fill: revert-layer !important } }", @"style='fill: blue'" ],
        @[ @"rect { fill: red }", @"style='fill: blue; fill: revert-layer'" ],
        @[ @"rect { fill: red !important }", @"style='fill: blue !important; fill: revert-layer !important'" ],
        @[ @"@layer a { rect { fill: revert-layer !important } }", @"style='fill: red !important'" ],
        @[ @"@layer a { rect { --paint: red } } @layer b { rect { --paint: revert-layer } } rect { fill: var(--paint) }", @"" ],
        @[ @"rect { --paint: red; fill: var(--paint) }", @"style='--paint: revert-layer'" ],
        @[ @"@layer a { rect { fill: red } } @layer b { rect { fill: var(--missing, revert-layer) } }", @"" ],
        @[ @"rect { fill: var(--missing, revert-layer) }", @"" ],
        @[ @"rect { fill: red }", @"style='fill: var(--missing, revert-layer)'" ],
        @[ @"@layer a { rect { fill: red } } @layer b { rect { fill: var(--missing, revert-layer) !important } }", @"style='fill: blue'" ]
    ];
    NSData* reference = IJSVGTestRGBADataForSVG(IJSVGTestSVG(@"<rect width='8' height='8' fill='red'/>"), CGSizeMake(8, 8));
    for (NSArray<NSString*>* item in cases) {
        NSString* body = [NSString stringWithFormat:@"<style><![CDATA[%@]]></style><rect width='8' height='8' fill='red' %@/>", item[0], item[1]];
        XCTAssertEqualObjects(IJSVGTestRGBADataForSVG(IJSVGTestSVG(body), CGSizeMake(8, 8)), reference, @"%@ / %@", item[0], item[1]);
    }
}

- (void)testRevertLayerWithoutFallbackInherits
{
    NSString* body = @"<style>@layer a { rect { fill: revert-layer } }</style><g fill='red'><rect width='8' height='8'/></g>";
    NSData* reference = IJSVGTestRGBADataForSVG(IJSVGTestSVG(@"<rect width='8' height='8' fill='red'/>"), CGSizeMake(8, 8));
    XCTAssertEqualObjects(IJSVGTestRGBADataForSVG(IJSVGTestSVG(body), CGSizeMake(8, 8)), reference);
}

- (void)testRevertLayerGeometryPreservesPresentationFallback
{
    NSData* reference = IJSVGTestRGBADataForSVG(IJSVGTestSVG(@"<rect width='8' height='8' fill='red'/>"), CGSizeMake(8, 8));
    for (NSString* css in @[ @"@layer a { rect { width: revert-layer !important } }", @"@layer a { rect { width: 8px } } @layer b { rect { width: revert-layer !important } }", @"@layer a { rect { width: var(--missing, revert-layer) !important } }" ]) {
        NSString* body = [NSString stringWithFormat:@"<style>%@</style><rect width='8' height='8' fill='red' style='width: 2px'/>", css];
        XCTAssertEqualObjects(IJSVGTestRGBADataForSVG(IJSVGTestSVG(body), CGSizeMake(8, 8)), reference, @"%@", css);
    }
}

- (void)testRevertLayerVariableResolutionIsReusable
{
    IJSVGStyleSheet* sheet = IJSVGTestStyleSheet(@"@layer a { rect { fill: red } } @layer b { rect { fill: var(--paint, revert-layer) } }");
    IJSVGStyleSheetStyle* style = [sheet styleForNode:IJSVGTestNode(@"rect", nil, nil)];
    XCTAssertEqualObjects([[style styleByResolvingVariables:@{ @"--paint" : @"blue" }] property:@"fill"], @"blue");
    XCTAssertEqualObjects([[style styleByResolvingVariables:@{}] property:@"fill"], @"red");
    XCTAssertEqualObjects([[style styleByResolvingVariables:@{ @"--paint" : @"green" }] property:@"fill"], @"green");
}

- (void)testLargeCascadeAndDeferredStyleOutliveStylesheet
{
    IJSVGStyleSheetStyle* retained;
    @autoreleasepool {
        NSMutableString* css = [NSMutableString stringWithString:@"@layer base { rect { fill: red; --paint: blue } }"];
        for (NSUInteger index = 0; index < 160; index++) {
            [css appendFormat:@"@layer theme { rect { --custom%lu: %lu; stroke-width: %lu } }", (unsigned long)index, (unsigned long)index, (unsigned long)index];
        }
        [css appendString:@"@layer theme { rect { fill: var(--missing, revert-layer); --paint: revert-layer } }"];
        IJSVGStyleSheet* sheet = IJSVGTestStyleSheet(css);
        retained = [sheet styleForNode:IJSVGTestNode(@"rect", nil, nil)];
    }
    IJSVGStyleSheetStyle* resolved = [retained styleByResolvingVariables:@{}];
    XCTAssertEqualObjects([resolved property:@"fill"], @"red");
    XCTAssertEqualObjects([resolved property:@"stroke-width"], @"159");
    XCTAssertEqualObjects([resolved property:@"--paint"], @"blue");
    for (NSUInteger index = 0; index < 160; index++) {
        NSString* property = [NSString stringWithFormat:@"--custom%lu", (unsigned long)index];
        NSString* expected = [NSString stringWithFormat:@"%lu", (unsigned long)index];
        XCTAssertEqualObjects([resolved property:property], expected);
    }
    XCTAssertEqualObjects([[retained styleByResolvingVariables:@{ @"--missing" : @"green" }] property:@"fill"], @"green");
}

@end
