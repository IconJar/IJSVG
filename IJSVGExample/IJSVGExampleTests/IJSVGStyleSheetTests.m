//
//  IJSVGStyleSheetTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGTestHelpers.h"
#import <IJSVG/IJSVGStyleSheetSelectorRaw.h>

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

@interface IJSVGStyleSheetTests : XCTestCase
@end

@implementation IJSVGStyleSheetTests

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
    IJSVGStyleSheet* styleSheet = IJSVGTestStyleSheet(@"#target { fill: #00ff00; } rect { fill: #ff0000; }");
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
    IJSVGStyleSheet* styleSheet = IJSVGTestStyleSheet(@"/* ignore */ rect { fill: url(#gradient); stroke: #101010; }");
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

- (void)testStyleSheetRejectsMalformedPipeSelectors
{
    IJSVGStyleSheet* triplePipeStyleSheet = IJSVGTestStyleSheet(@"g ||| rect { fill: #ff0000; }");
    XCTAssertEqual(triplePipeStyleSheet.ruleCount, 0);

    IJSVGStyleSheet* leadingPipeStyleSheet = IJSVGTestStyleSheet(@"|rect { fill: #ff0000; }");
    XCTAssertEqual(leadingPipeStyleSheet.ruleCount, 0);
}

- (void)testStyleSheetRejectsUnsupportedSelectorSyntax
{
    IJSVGStyleSheet* attributeStyleSheet = IJSVGTestStyleSheet(@"rect[fill] { fill: #ff0000; }");
    XCTAssertEqual(attributeStyleSheet.ruleCount, 0);

    IJSVGStyleSheet* pseudoStyleSheet = IJSVGTestStyleSheet(@"rect:hover { fill: #ff0000; }");
    XCTAssertEqual(pseudoStyleSheet.ruleCount, 0);
}

- (void)testStyleDeclarationParserKeepsQuotedDelimitersAndComments
{
    IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleString:@"font-family: 'A;B'; fill: #ffffff; marker: url(\"#a;b\"); content: '/* not a comment */';"];

    XCTAssertEqualObjects([style property:@"font-family"], @"'A;B'");
    XCTAssertEqualObjects([style property:@"fill"], @"#ffffff");
    XCTAssertEqualObjects([style property:@"marker"], @"url(\"#a;b\")");
    XCTAssertEqualObjects([style property:@"content"], @"'/* not a comment */'");
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
    NSString* css = @"rect { fill: red; } /* remove */ .a::before { content: '/* keep */'; } \"/* keep too */\" /* unterminated";
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
    IJSVGStyleSheetSelectorRaw* withTag = IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinatorDirectDescendant);
    IJSVGStyleSheetSelectorRaw* withID = IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinatorNextSibling);
    IJSVGStyleSheetSelectorRaw* withClass = IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinatorPrecededSibling);

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

@end
