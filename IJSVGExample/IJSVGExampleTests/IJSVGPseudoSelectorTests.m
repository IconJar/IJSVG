//
//  IJSVGPseudoSelectorTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 15/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "../Scripts/selector-stress-document.h"
#import <IJSVGTestHelpers.h>
#import <WebKit/WebKit.h>

@interface IJSVGPseudoSelectorTests : XCTestCase
@property (nonatomic, strong) IJSVGRootNode* parsedRoot;
@end

@implementation IJSVGPseudoSelectorTests

- (NSDictionary<NSString*, IJSVGNode*>*)nodesFromBody:(NSString*)body css:(NSString*)css
{
    NSString* source = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><style>%@</style>%@</svg>", css, body];
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:&error];
    XCTAssertNotNil(parser);
    XCTAssertNil(error);

    // Inherited node properties need their ancestor tree to remain alive.
    self.parsedRoot = [parser rootNodeWithSize:CGSizeMake(100, 100)];
    NSMutableDictionary* result = [[NSMutableDictionary alloc] init];
    NSMutableArray<IJSVGNode*>* pending = [[NSMutableArray alloc] init];
    if (self.parsedRoot != nil) {
        [pending addObject:self.parsedRoot];
    }
    while (pending.count != 0) {
        IJSVGNode* node = pending.lastObject;
        [pending removeLastObject];
        if (node.identifier != nil) {
            result[node.identifier] = node;
        }
        if ([node isKindOfClass:IJSVGGroup.class]) {
            [pending addObjectsFromArray:((IJSVGGroup*)node).children];
        }
    }
    return result;
}

- (NSSet<NSString*>*)matches:(NSString*)selector body:(NSString*)body
{
    // Reset inherited values so this observes exact matches, not descendants
    // that inherit stroke width from a matching ancestor.
    NSString* css = [NSString stringWithFormat:@"* { stroke-width: 0 } %@ { stroke-width: 17 }", selector];
    NSDictionary* nodes = [self nodesFromBody:body css:css];
    NSMutableSet* result = [[NSMutableSet alloc] init];
    for (NSString* identifier in nodes) {
        IJSVGGraphicsNode* node = nodes[identifier];
        if ([node isKindOfClass:IJSVGGraphicsNode.class] && node.strokeWidth.value == 17) {
            [result addObject:identifier];
        }
    }
    return result;
}

- (void)testStructuralAndLogicalSelectors
{
    NSString* body = @"<g><rect id='a'/><!--ignored--><?test ignored?><title>counts</title><rect id='b' class='chosen'/><circle id='c'/><rect id='d'/></g>";
    NSDictionary<NSString*, NSArray*>* cases = @{
        @"rect:first-child" : @[ @"a" ],
        @"rect:last-child" : @[ @"d" ],
        @"rect:only-child" : @[],
        @"circle:only-of-type" : @[ @"c" ],
        @"rect:first-of-type" : @[ @"a" ],
        @"rect:last-of-type" : @[ @"d" ],
        @"rect:nth-child(odd)" : @[ @"a", @"b", @"d" ],
        @"rect:nth-child(even)" : @[],
        @"rect:nth-child(-n + 3)" : @[ @"a", @"b" ],
        @"rect:nth-child(0n+3)" : @[ @"b" ],
        @"rect:nth-child(2n - 1)" : @[ @"a", @"b", @"d" ],
        @"rect:nth-child(n-2)" : @[ @"a", @"b", @"d" ],
        @"rect:nth-child(0)" : @[],
        @"rect:nth-child(-2)" : @[],
        @"rect:nth-last-child(3)" : @[ @"b" ],
        @"rect:nth-of-type(2)" : @[ @"b" ],
        @"rect:nth-last-of-type(2)" : @[ @"b" ],
        @"rect:nth-child(2 of rect)" : @[ @"b" ],
        @"rect:nth-last-child(1 of rect, circle)" : @[ @"d" ],
        @"rect:nth-child(1 of :is(.chosen, #b))" : @[ @"b" ],
        @"rect:nth-child(2):last-of-type" : @[],
        @":is(rect, circle):not(#a, #d)" : @[ @"b", @"c" ],
        @"rect:where(#a, #b):not(:first-child)" : @[ @"b" ],
        @"rect:is(:unknown, #d)" : @[ @"d" ],
        @"rect:where(:unknown, #d)" : @[ @"d" ],
        @"rect:is(:unknown)" : @[],
        @"rect:not(:unknown, #a)" : @[],
        @"rect:has(+ title)" : @[ @"a" ],
        @"rect:has(~ circle)" : @[ @"a", @"b" ],
        @"rect:has(+ title + rect)" : @[ @"a" ],
        @"rect:has(:has(circle))" : @[],
        @"rect:NTH-CHILD(ODD)" : @[ @"a", @"b", @"d" ],
        @"rect:nth-child(-9223372036854775808n+1)" : @[ @"a" ],
        @"rect:nth-child(9223372036854775807n+1)" : @[ @"a" ],
        @"rect:nth-child(n-9223372036854775808)" : @[ @"a", @"b", @"d" ],
        @"rect:nth-child(0n-9223372036854775808)" : @[]
    };
    for (NSString* selector in cases) {
        XCTAssertEqualObjects([self matches:selector body:body], [NSSet setWithArray:cases[selector]], @"%@", selector);
    }
}

- (void)testEmptyPreservesSourceWhitespace
{
    NSDictionary<NSString*, NSNumber*>* cases = @{
        @"" : @YES,
        @" " : @NO,
        @"\n\t\r " : @NO,
        @"<!-- comment -->" : @YES,
        @"<?test ignored?>" : @YES,
        @" <!-- comment --> " : @NO,
        @"<![CDATA[ ]]>" : @NO,
        @"<![CDATA[]]>" : @YES,
        @"<![CDATA[text]]>" : @NO,
        @"&#32;" : @NO,
        @"&#160;" : @NO,
        @"<title/>" : @NO,
        @"text" : @NO
    };
    for (NSString* content in cases) {
        for (NSString* space in @[ @"", @" xml:space='preserve'", @" xml:space='default'" ]) {
            NSString* body = [NSString stringWithFormat:@"<g id='target'%@>%@</g>", space, content];
            XCTAssertEqual([[self matches:@"g:empty" body:body] containsObject:@"target"], cases[content].boolValue, @"%@ %@", space, content);
        }
    }
}

- (void)testMalformedNthDoesNotApply
{
    for (NSString* argument in @[ @"", @"2 n", @"+ 2n", @"n+-1", @"n 1", @"2.5", @"odd extra", @"2n+", @"999999999999999999999999999999", @"2 of", @"2 of :unknown" ]) {
        NSString* selector = [NSString stringWithFormat:@"rect:nth-child(%@)", argument];
        XCTAssertEqual([self matches:selector body:@"<rect id='a'/>"].count, 0u, @"%@", selector);
    }
}

- (void)testSpecificityAndStrictLists
{
    NSString* body = @"<rect id='a' class='x'/>";
    for (NSString* css in @[
             @":where(#a) { stroke-width: 3 } rect { stroke-width: 17 }",
             @":is(#missing, .x) { stroke-width: 17 } .x { stroke-width: 3 }",
             @":not(#missing) { stroke-width: 17 } .x { stroke-width: 3 }",
             @"#a { stroke-width: 17 } .x.x.x.x.x.x.x.x.x.x.x { stroke-width: 3 }",
             @":nth-child(1 of #a) { stroke-width: 17 } #a { stroke-width: 3 }",
             @"rect { stroke-width: 17 } rect, :unknown { stroke-width: 3 }",
             @"rect:has(+ circle, #missing) { stroke-width: 17 } .x { stroke-width: 3 }",
             @"#a#missing { stroke-width: 3 } rect { stroke-width: 17 }"
         ]) {
        NSDictionary* nodes = [self nodesFromBody:[body stringByAppendingString:@"<circle/>"] css:css];
        IJSVGGraphicsNode* node = nodes[@"a"];
        XCTAssertEqual(node.strokeWidth.value, 17, @"%@", css);
    }
}

- (void)testRootScopeAndNestedCombinators
{
    NSString* body = @"<g><g class='outer'><g><g><rect id='a'/></g></g></g></g><g><circle id='b'/></g>";
    XCTAssertTrue([[self matches:@":root > g .outer > g rect" body:body] containsObject:@"a"]);
    XCTAssertEqualObjects([self matches:@":scope > g:last-child > circle" body:body], [NSSet setWithObject:@"b"]);
    XCTAssertEqualObjects([self matches:@"g:has(> circle) > circle" body:body], [NSSet setWithObject:@"b"]);
    XCTAssertEqualObjects([self matches:@"rect:is(.outer > g rect):not(:where(#missing))" body:body], [NSSet setWithObject:@"a"]);
}

- (void)compareWithWebKit:(NSArray<NSString*>*)selectors body:(NSString*)body
{
    NSString* source = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg'><style>/* stylesheet */</style>%@</svg>", body];
    WKWebView* webView = [[WKWebView alloc] init];
    XCTestExpectation* ready = [self expectationWithDescription:@"WebKit selector oracle"];
    __block NSArray<NSArray<NSString*>*>* expected;
    [webView callAsyncJavaScript:@"const doc = new DOMParser().parseFromString(source, 'image/svg+xml');"
                                  "return selectors.map(selector => {"
                                  "try { return Array.from(doc.querySelectorAll(selector), node => node.id).filter(Boolean); }"
                                  "catch { return null; } });"
                       arguments:@{ @"source" : source, @"selectors" : selectors }
                         inFrame:nil
                  inContentWorld:WKContentWorld.pageWorld
               completionHandler:^(id result, NSError* error) {
                   XCTAssertNil(error);
                   expected = result;
                   [ready fulfill];
               }];
    [self waitForExpectations:@[ ready ] timeout:30];
    XCTAssertEqual(expected.count, selectors.count);
    for (NSUInteger index = 0; index < MIN(expected.count, selectors.count); index++) {
        @autoreleasepool {
            NSString* selector = selectors[index];
            XCTAssertTrue([expected[index] isKindOfClass:NSArray.class], @"WebKit rejected %@", selector);
            if (![expected[index] isKindOfClass:NSArray.class]) {
                continue;
            }
            NSSet* actual = [self matches:selector body:body];
            XCTAssertEqualObjects(actual, [NSSet setWithArray:expected[index]], @"%@", selector);
        }
    }
    NSLog(@"Verified %lu selector combinations against WebKit", selectors.count);
}

- (void)testGeneratedNthFormulaMatrix
{
    NSMutableArray<NSString*>* selectors = [[NSMutableArray alloc] init];
    for (NSString* family in @[ @"nth-child", @"nth-last-child", @"nth-of-type", @"nth-last-of-type" ]) {
        for (NSInteger a = -4; a <= 4; a++) {
            for (NSInteger b = -8; b <= 12; b++) {
                NSString* formula = [NSString stringWithFormat:@"%ldn%@%ld", a, b < 0 ? @"" : @"+", b];
                for (NSString* prefix in @[ @"rect", @"circle", @"*" ]) {
                    [selectors addObject:[NSString stringWithFormat:@"%@:%@(%@)", prefix, family, formula]];
                }
            }
        }
    }
    for (NSString* family in @[ @"nth-child", @"nth-last-child" ]) {
        for (NSString* filter in @[ @"rect", @".chosen", @"rect, circle", @":is(rect, circle):not(.skip)", @"g > rect.chosen" ]) {
            for (NSString* formula in @[ @"odd", @"even", @"1", @"2", @"-n+4", @"2n-1", @"n+2", @"0n+3" ]) {
                [selectors addObject:[NSString stringWithFormat:@"*:%@(%@ of %@)", family, formula, filter]];
            }
        }
    }
    NSMutableString* body = [[NSMutableString alloc] initWithString:@"<g>"];
    for (NSUInteger index = 1; index <= 32; index++) {
        NSString* element = index % 4 == 0 ? @"circle" : @"rect";
        NSString* classes = index % 3 == 0 ? @"chosen skip" : @"chosen";
        [body appendFormat:@"<%@ id='n%lu' class='%@'/><!--ignored--><?test ignored?>", element, index, classes];
    }
    [body appendString:@"</g>"];
    [self compareWithWebKit:selectors body:body];
}

- (void)testGeneratedCompoundAndCombinatorMatrix
{
    NSArray* pseudos = @[
        @":root", @":scope", @":empty", @":first-child", @":last-child", @":only-child",
        @":first-of-type", @":last-of-type", @":only-of-type", @":nth-child(2n+1)",
        @":nth-last-child(-n+2)", @":nth-of-type(2n)", @":nth-last-of-type(n+2)",
        @":is(rect, .chosen)", @":where(rect, circle)", @":not(.skip, #missing)",
        @":has(> rect)", @":has(+ circle)", @":has(~ rect)"
    ];
    NSMutableArray* selectors = [[NSMutableArray alloc] init];
    for (NSString* left in pseudos) {
        for (NSString* right in pseudos) {
            for (NSString* prefix in @[ @"*", @"rect", @"g" ]) {
                [selectors addObject:[NSString stringWithFormat:@"%@%@%@", prefix, left, right]];
            }
            for (NSString* combinator in @[ @" ", @" > ", @" + ", @" ~ " ]) {
                [selectors addObject:[NSString stringWithFormat:@"*%@%@*%@", left, combinator, right]];
            }
        }
    }
    NSArray* fixtures = @[
        @"<g id='group' class='chosen'><rect id='a'/><title/><circle id='b'/><rect id='c' class='chosen skip'/><rect id='d'/></g>",
        @"<g id='outer' class='chosen'><g id='inner'><rect id='a'/><circle id='b' class='chosen'/></g><rect id='c'/></g><g id='last'><rect id='d'/></g>",
        @"<g id='empty'/><g id='blank'> </g><g id='comment'><!--comment--></g><g id='cdata'><![CDATA[ ]]></g><rect id='a'/><circle id='b'/>"
    ];
    for (NSString* fixture in fixtures) {
        [self compareWithWebKit:selectors body:fixture];
    }
}

- (void)testGeneratedNestedLogicalAndRelativeMatrix
{
    NSArray* leaves = @[ @"rect", @".chosen", @"#a", @":first-child", @":last-of-type", @":nth-child(2n)", @":empty", @"g > rect" ];
    NSMutableArray* selectors = [[NSMutableArray alloc] init];
    for (NSString* outer in @[ @"is", @"where", @"not" ]) {
        for (NSString* inner in @[ @"is", @"where", @"not" ]) {
            for (NSString* lhs in leaves) {
                for (NSString* rhs in leaves) {
                    [selectors addObject:[NSString stringWithFormat:@"*:%@(:%@(%@, %@), #missing)", outer, inner, lhs, rhs]];
                }
            }
        }
    }
    for (NSString* relation in @[ @"", @"> ", @"+ ", @"~ " ]) {
        for (NSString* lhs in leaves) {
            for (NSString* rhs in @[ @"rect", @"circle", @":is(rect,circle)", @":not(.skip)" ]) {
                [selectors addObject:[NSString stringWithFormat:@"*:has(%@%@)", relation, lhs]];
                [selectors addObject:[NSString stringWithFormat:@"*:has(%@%@ + %@)", relation, lhs, rhs]];
                [selectors addObject:[NSString stringWithFormat:@"*:has(%@%@ ~ %@)", relation, lhs, rhs]];
                [selectors addObject:[NSString stringWithFormat:@"*:not(:has(%@%@, > %@))", relation, lhs, rhs]];
            }
        }
    }
    [self compareWithWebKit:selectors body:@"<g id='outer'><g id='inner' class='chosen'><rect id='a'/><circle id='b'/><rect id='c' class='chosen skip'/></g><rect id='d'/><circle id='e'/></g><g id='last'/>"];
}

- (void)testRelativeSelectorTraversalBoundaries
{
    NSString* body = @"<g id='a'><g id='nested'><rect id='deep'/></g></g>"
                      "<g id='b'><circle id='inside'/></g><rect id='c'/><circle id='d'/>";
    [self compareWithWebKit:@[
        @"g:has(> rect)", @"g:has(rect)", @"g:has(+ rect)",
        @"g:has(~ rect)", @"g:has(+ circle)", @"g:has(+ g > circle)",
        @"g:has(+ g + rect)", @"g:has(> g > rect)", @"g:has(~ g circle)",
        @"g:has(> :is(rect, circle))", @"g:has(+ :not(rect))"
    ]
                       body:body];
}

- (void)testAttributeOperatorMatrix
{
    NSString* body = @"<g><rect id='a' data-v='Alpha beta' fill='red'/>"
                      "<rect id='b' data-v='alpha-beta'/>"
                      "<rect id='c' data-v=''/>"
                      "<rect id='d' data-v='ALPHA&#9;beta&#10;gamma'/>"
                      "<rect id='e' data-v='Älpha'/>"
                      "<rect id='f'/><rect id='g' data-v='a,b){}'/></g>";
    NSMutableArray* selectors = [[NSMutableArray alloc] init];
    for (NSString* operation in @[ @"=", @"~=", @"|=", @"^=", @"$=", @"*=" ]) {
        for (NSString* value in @[ @"", @"Alpha", @"alpha", @"beta", @"alpha-beta", @"Alpha beta", @"a,b){}", @"älpha" ]) {
            for (NSString* flag in @[ @"", @" i", @" I" ]) {
                NSString* attribute = [NSString stringWithFormat:@"[data-v%@'%@'%@]", operation, value, flag];
                [selectors addObject:attribute];
                [selectors addObject:[NSString stringWithFormat:@"rect:is(%@, #missing)", attribute]];
                [selectors addObject:[NSString stringWithFormat:@"rect:not(%@)", attribute]];
                [selectors addObject:[NSString stringWithFormat:@"rect:nth-child(2n of %@)", attribute]];
                [selectors addObject:[NSString stringWithFormat:@"g:has(> %@)", attribute]];
            }
        }
    }
    [selectors addObjectsFromArray:@[ @"[fill]", @"[missing]", @"[data-v]", @"[data-v='Al\\70 ha beta']", @"[d\\61 ta-v]", @"[id=a]", @"[id='a'i]", @"[id='A' i]", @"[ID]", @"[|id]", @"[*|id]" ]];
    [self compareWithWebKit:selectors body:body];
    XCTAssertEqualObjects([self matches:@"[data-v^='Alpha' s]" body:body], [NSSet setWithObject:@"a"]);
    XCTAssertEqualObjects([self matches:@"[data-v^='alpha' S]" body:body], [NSSet setWithObject:@"b"]);
}

- (void)testAttributeNamespacesAndMalformedSyntax
{
    NSString* body = @"<g xmlns:x='urn:test'><rect id='a' x:data='yes'/><rect id='b' data='yes'/><rect id='c' data='no' x:data='yes'/></g>";
    [self compareWithWebKit:@[ @"[*|data]", @"[data]", @"[|data]", @"[*|data=yes]", @"[data=yes]", @"[data=no]", @":is([*|data=yes], #missing)" ] body:body];
    for (NSString* selector in @[ @"[]", @"[*]", @"[data=]", @"[data!=yes]", @"[data~=]", @"[data=1]", @"[data='yes' q]", @"[data i]", @"[data|]", @"[missing|data]", @"[data='yes' ii]", @"[data='yes' i s]", @"[data='yes'" ]) {
        XCTAssertNil([[IJSVGStyleSheetSelector alloc] initWithSelectorString:selector], @"%@", selector);
    }
    XCTAssertEqualObjects([self matches:@":is([data!=yes], #b)" body:body], [NSSet setWithObject:@"b"]);
    NSDictionary* nodes = [self nodesFromBody:body css:@"[data] { stroke-width: 17 } rect { stroke-width: 3 }"];
    XCTAssertEqual(((IJSVGGraphicsNode*)nodes[@"b"]).strokeWidth.value, 17);
}

- (void)testLanguageInheritanceAndRanges
{
    NSString* body = @"<g xml:lang='en-GB'><rect id='a'/><rect id='b' xml:lang='fr-CA'/>"
                      "<g lang='de-Latn-DE'><rect id='c'/></g>"
                      "<rect id='d' lang='fr' xml:lang='en-US'/>"
                      "<g xml:lang=''><rect id='e'/></g>"
                      "<rect id='f' xml:lang='de-x-DE'/></g><rect id='g'/>";
    [self compareWithWebKit:@[
        @"rect:lang(en)", @"rect:lang(EN)", @"rect:lang(en-GB)", @"rect:lang(fr)",
        @"rect:lang(de)", @"rect:lang('de-DE')",
        @"rect:lang('*')", @"rect:lang(en, fr)", @"rect:lang('*-GB')",
        @"rect:not(:lang(en))", @"g:has(> :lang(fr))", @"rect:nth-child(1 of :lang(en))"
    ]
                       body:body];

    // WebKit differs here from Selectors 4 and RFC 4647 section 3.3.2:
    // Empty ranges match untagged language. Wildcards cannot skip a singleton.
    XCTAssertEqualObjects([self matches:@"rect:lang('')" body:body], ([NSSet setWithArray:@[ @"e", @"g" ]]));
    XCTAssertEqualObjects([self matches:@"rect:lang('de-*-DE')" body:body], [NSSet setWithObject:@"c"]);
    for (NSString* selector in @[ @":lang()", @":lang(*)", @":lang(en,)", @":lang(en fr)", @":lang(123)" ]) {
        XCTAssertNil([[IJSVGStyleSheetSelector alloc] initWithSelectorString:selector], @"%@", selector);
    }
}

- (void)testCSSNamespaceDeclarations
{
    NSString* body = @"<g xmlns:x='urn:test'><rect id='a' data='yes' x:data='no'/><rect id='b' x:data='yes'/><rect xmlns='' id='c' data='yes'/></g>";
    NSDictionary<NSString*, NSArray*>* cases = @{
        @"@namespace s 'http://www.w3.org/2000/svg'; s|rect" : @[ @"a", @"b" ],
        @"@namespace s url(http://www.w3.org/2000/svg); s|rect" : @[ @"a", @"b" ],
        @"@namespace s url('http://www.w3.org/2000/svg'); s|rect" : @[ @"a", @"b" ],
        @"@namespace s 'urn:wrong'; @namespace s 'http://www.w3.org/2000/svg'; s|rect" : @[ @"a", @"b" ],
        @"@namespace 'http://www.w3.org/2000/svg'; rect" : @[ @"a", @"b" ],
        @"@namespace 'http://www.w3.org/2000/svg'; [data]" : @[ @"a" ],
        @"@namespace 'http://www.w3.org/2000/svg'; *|rect[data]" : @[ @"a", @"c" ],
        @"@namespace 'http://www.w3.org/2000/svg'; *|rect:is([data])" : @[ @"a", @"c" ],
        @"@namespace 'http://www.w3.org/2000/svg'; *|rect:is(*[data])" : @[ @"a" ],
        @"@namespace 'http://www.w3.org/2000/svg'; *|rect:not([data])" : @[ @"b" ],
        @"@namespace s 'urn:test'; [s|data=yes]" : @[ @"b" ],
        @"@namespace s 'urn:test'; :is([s|data=yes], #a)" : @[ @"a", @"b" ],
        @"@namespace s 'urn:test'; g:has(> [s|data=yes]) > rect" : @[ @"a", @"b", @"c" ],
        @"|rect" : @[ @"c" ],
        @"*|rect" : @[ @"a", @"b", @"c" ],
        @"missing|rect" : @[],
        @"x|rect" : @[]
    };
    for (NSString* prefix in cases) {
        NSString* css = [prefix stringByAppendingString:@" { stroke-width: 17 }"];
        NSDictionary* nodes = [self nodesFromBody:body css:css];
        NSMutableSet* actual = [[NSMutableSet alloc] init];
        for (NSString* identifier in nodes) {
            if (((IJSVGGraphicsNode*)nodes[identifier]).strokeWidth.value == 17) {
                [actual addObject:identifier];
            }
        }
        XCTAssertEqualObjects(actual, [NSSet setWithArray:cases[prefix]], @"%@", prefix);
    }

    // Bindings and selector caches must not leak between separate style elements.
    NSDictionary* nodes = [self nodesFromBody:@"<style>s|rect { stroke-width: 99 }</style><rect id='a'/>"
                                          css:@"@namespace s 'http://www.w3.org/2000/svg'; s|rect { stroke-width: 17 }"];
    XCTAssertEqual(((IJSVGGraphicsNode*)nodes[@"a"]).strokeWidth.value, 17);
    nodes = [self nodesFromBody:@"<rect id='a'/>" css:@"rect { stroke-width: 17 } @namespace s 'http://www.w3.org/2000/svg'; s|rect { stroke-width: 99 }"];
    XCTAssertEqual(((IJSVGGraphicsNode*)nodes[@"a"]).strokeWidth.value, 17);
}

- (void)testAttributeValuesAcrossXMLChunkBoundaries
{
    for (NSString* value in @[ @"é", @"&#233;" ]) {
        for (NSUInteger offset = 65533; offset <= 65537; offset++) {
            NSString* prefix = @"<svg xmlns='http://www.w3.org/2000/svg'><style>rect[data-label='é'] { stroke-width: 17 }</style><!--";
            NSString* opening = @"--><rect data-label='";
            NSUInteger padding = offset - [prefix lengthOfBytesUsingEncoding:NSUTF8StringEncoding] - opening.length;
            NSMutableString* source = [prefix mutableCopy];
            [source appendString:[@"" stringByPaddingToLength:padding withString:@" " startingAtIndex:0]];
            [source appendFormat:@"%@%@'/></svg>", opening, value];
            NSError* error = nil;
            IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:&error];
            XCTAssertNotNil(parser, @"%@ at %lu", value, offset);
            XCTAssertNil(error);
            IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
            XCTAssertEqual(((IJSVGGraphicsNode*)root.children.firstObject).strokeWidth.value, 17);
        }
    }
}

- (void)testLargeAttributeDocumentAgainstWebKit
{
    const NSUInteger count = 100000;
    NSString* source = IJSVGSelectorStressDocument(100, 1000);
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:&error];
    XCTAssertNotNil(parser);
    XCTAssertNil(error);
    IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(1000, 1000)];
    NSMutableArray* pending = [[NSMutableArray alloc] initWithArray:root.children];
    NSMutableDictionary* widths = [[NSMutableDictionary alloc] initWithCapacity:count];
    while (pending.count != 0) {
        IJSVGGraphicsNode* node = pending.lastObject;
        [pending removeLastObject];
        if ([node isKindOfClass:IJSVGGroup.class]) {
            [pending addObjectsFromArray:((IJSVGGroup*)node).children];
        } else if (node.identifier != nil) {
            widths[node.identifier] = @(node.strokeWidth.value);
        }
    }
    XCTAssertEqual(widths.count, count);
    WKWebView* webView = [[WKWebView alloc] init];
    XCTestExpectation* ready = [self expectationWithDescription:@"Large SVG computed styles"];
    __block NSArray<NSNumber*>* expected = nil;
    [webView callAsyncJavaScript:@"const svg = new DOMParser().parseFromString(source, 'image/svg+xml').documentElement;"
                                  "document.open(); document.write('<!doctype html><html><body></body></html>'); document.close();"
                                  "document.body.appendChild(document.importNode(svg, true));"
                                  "return Array.from(document.querySelectorAll('[id^=\"n\"]'), node => parseFloat(getComputedStyle(node).strokeWidth));"
                       arguments:@{ @"source" : source }
                         inFrame:nil
                  inContentWorld:WKContentWorld.pageWorld
               completionHandler:^(id result, NSError* failure) {
                   XCTAssertNil(failure);
                   expected = result;
                   [ready fulfill];
               }];
    [self waitForExpectations:@[ ready ] timeout:120];
    XCTAssertEqual(expected.count, count);
    NSUInteger mismatches = 0;
    double checksum = 0;
    NSMutableArray* examples = [[NSMutableArray alloc] init];
    for (NSUInteger index = 0; index < MIN(count, expected.count); index++) {
        NSString* identifier = [NSString stringWithFormat:@"n%lu", index];
        NSNumber* actual = widths[identifier];
        checksum += actual.doubleValue;
        if (![actual isEqualToNumber:expected[index]]) {
            mismatches++;
            if (examples.count < 10) {
                [examples addObject:[NSString stringWithFormat:@"%@: engine=%@ browser=%@", identifier, actual, expected[index]]];
            }
        }
    }
    XCTAssertEqual(mismatches, 0, @"%@", examples);
    NSLog(@"Verified %lu shapes in %lu-byte SVG against WebKit; checksum=%.0f", count, [source lengthOfBytesUsingEncoding:NSUTF8StringEncoding], checksum);
}

- (void)testMalformedSelectorMatrix
{
    NSArray* invalid = @[
        @":root()", @":empty(x)", @":first-child(1)", @":only-of-type(2)",
        @":nth-child", @":nth-child()", @":nth-of-type(2 of rect)", @":nth-last-of-type(1 of *)",
        @":not()", @":has()", @":not(rect,)", @":has(> rect,)", @":has(:has(rect))",
        @":has(> g:has(rect))", @":has(::before)", @":not(::before)",
        @":is(rect", @":where(rect))", @"rect:nth-child(2n+)", @"rect:nth-child(n--2)",
        @"rect:nth-child(2 of > rect)", @"rect:nth-child(2 of rect, :unknown)",
        @"> rect", @"rect >", @"rect + + circle", @"rect,,circle"
    ];
    for (NSString* selector in invalid) {
        XCTAssertNil([IJSVGStyleSheetSelector selectorsWithString:selector forgiving:NO], @"%@", selector);
    }
}

- (void)testTypeIndexUsesNamespaceURI
{
    NSString* body = @"<g xmlns:o='urn:other'><o:rect/><rect id='a'/><rect id='b'/></g>";
    XCTAssertTrue([[self matches:@"rect:nth-of-type(1)" body:body] containsObject:@"a"]);
    XCTAssertTrue([[self matches:@"rect:nth-of-type(2)" body:body] containsObject:@"b"]);
}

- (void)testReferencedContentRetainsStructuralScope
{
    NSString* body = @"<defs><g id='shape'><title>counts</title><rect id='a'/><rect id='b'/></g></defs><use href='#shape'/><use href='#shape'/>";
    XCTAssertTrue([[self matches:@"rect:nth-child(2)" body:body] containsObject:@"a"]);
    XCTAssertTrue([[self matches:@"rect:last-child" body:body] containsObject:@"b"]);
}

@end
