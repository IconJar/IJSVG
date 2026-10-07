#import <IJSVGTestHelpers.h>

@interface IJSVGParserOptimizationTests : XCTestCase
@end

@implementation IJSVGParserOptimizationTests

- (void)testCascadeKeepsImportanceSpecificityAndSourceOrder
{
    IJSVGStyleSheet* sheet = IJSVGTestStyleSheet(
        @"#target { fill: red; stroke: red !important; opacity: .2 }"
         ".item { fill: blue !important; stroke: blue !important; opacity: .5 }"
         "rect, #target { opacity: .8; font: italic 20px Helvetica }"
         "rect { fill: green; font-size: 10px }"
         ".item { fill: purple !important }");
    IJSVGNode* node = IJSVGTestNode(@"rect", @"target", @[@"item"]);
    IJSVGStyleSheetStyle* style = [sheet styleForNode:node];
    XCTAssertNotNil(style);
    XCTAssertEqualObjects([style property:@"fill"], @"purple");
    XCTAssertEqualObjects([style property:@"stroke"], @"red");
    XCTAssertEqualObjects([style property:@"opacity"], @".8");
    XCTAssertEqualObjects([style property:@"font-size"], @"20px");

    // An inline style must not override an important declaration.
    IJSVGStyleSheetStyle* inlineStyle = [IJSVGStyleSheetStyle parseStyleString:@"fill: orange"];
    XCTAssertEqualObjects([[style mergedStyle:inlineStyle] property:@"fill"], @"purple");
}

- (void)testCascadeMatchesSortedReferenceWithManyRules
{
    IJSVGNode* node = IJSVGTestNode(@"rect", @"target", @[@"item"]);
    NSArray<NSString*>* selectors = @[@"rect", @".item", @"#target", @"rect, #missing"];
    NSArray<NSNumber*>* specificities = @[@1, @10, @100, @1];
    for(NSUInteger seed = 0; seed < 8; seed++) {
        IJSVGStyleSheet* sheet = [[IJSVGStyleSheet alloc] init];
        NSMutableArray<NSDictionary*>* rules = [[NSMutableArray alloc] init];
        for(NSUInteger index = 0; index < 96; index++) {
            NSUInteger selectorIndex = (index * 7 + seed) % selectors.count;
            NSString* important = (index + seed) % 5 == 0 ? @" !important" : @"";
            NSString* declaration = [NSString stringWithFormat:
                @"fill: rgb(%lu, 20, 30)%@; custom-value: %lu; stroke-width: %lu%@",
                index, important, index, index % 7 + 1, important];
            [sheet parseStyleBlock:[NSString stringWithFormat:@"%@ { %@ }",
                selectors[selectorIndex], declaration]];
            [rules addObject:@{@"specificity": specificities[selectorIndex],
                @"index": @(index), @"declaration": declaration}];
        }
        [rules sortUsingComparator:^NSComparisonResult(NSDictionary* first, NSDictionary* second) {
            NSComparisonResult order = [first[@"specificity"] compare:second[@"specificity"]];
            return order != NSOrderedSame ? order : [first[@"index"] compare:second[@"index"]];
        }];
        IJSVGStyleSheetStyle* expected = [[IJSVGStyleSheetStyle alloc] init];
        for(NSDictionary* rule in rules) {
            [expected addPropertiesFromStyle:
                [IJSVGStyleSheetStyle parseStyleString:rule[@"declaration"]]];
        }
        IJSVGStyleSheetStyle* actual = [sheet styleForNode:node];
        XCTAssertNotNil(actual);
        XCTAssertEqualObjects(actual.properties, expected.properties, @"Seed %lu", seed);
    }
}

- (void)testSelectorRecordsPreserveXMLSiblingsAndReferenceScope
{
    NSString* svg = IJSVGTestSVG(
        @"<style>defs > g > rect { opacity: .1 }"
         "g > rect + rect { opacity: .6 } circle ~ rect { stroke-width: 7 }</style>"
         "<defs><g id='shape'><circle r='1'/><rect width='2' height='2'/>"
         "<!-- not an element sibling -->"
         "<rect width='3' height='3'/><title>Break adjacency</title>"
         "<rect width='4' height='4'/></g></defs>"
         "<use href='#shape'/><use href='#shape'/>");
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:svg fileURL:nil error:&error];
    XCTAssertNotNil(parser);
    XCTAssertNil(error);
    IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
    XCTAssertEqual(root.children.count, 2);
    for(IJSVGGroup* use in root.children) {
        XCTAssertTrue([use isKindOfClass:IJSVGGroup.class]);
        IJSVGGroup* group = (IJSVGGroup*)use.children.firstObject;
        XCTAssertTrue([group isKindOfClass:IJSVGGroup.class]);
        XCTAssertEqual(group.children.count, 4);
        if(group.children.count != 4) {
            continue;
        }
        IJSVGNode* adjacent = group.children[2];
        XCTAssertEqualWithAccuracy(adjacent.opacity.value, .6, .001);
        XCTAssertEqual(adjacent.strokeWidth.value, 7);
        XCTAssertEqual(group.children[1].opacity.value, 1);
        XCTAssertEqual(group.children[3].opacity.value, 1);
    }
}

- (void)testRepeatedRawAttributesKeepInstanceInheritance
{
    NSString* svg = IJSVGTestSVG(
        @"<defs><g id='shape'><rect class='item detail' width='3' height='4' fill='inherit'/></g></defs>"
         "<use href='#shape' fill='red' stroke-width='2'/>"
         "<use href='#shape' fill='blue' stroke-width='9'/>"
         "<use href='#shape' fill='green' stroke-width='4'/>");
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:svg fileURL:nil error:&error];
    XCTAssertNotNil(parser);
    XCTAssertNil(error);
    // Parse twice to check that each parse starts with an empty cache.
    for(NSUInteger iteration = 0; iteration < 2; iteration++) {
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
        NSMutableArray<IJSVGNode*>* paths = [[NSMutableArray alloc] init];
        for(IJSVGGroup* use in root.children) {
            IJSVGGroup* group = (IJSVGGroup*)use.children.firstObject;
            IJSVGNode* path = group.children.firstObject;
            XCTAssertNotNil(path);
            if(path != nil) {
                [paths addObject:path];
            }
        }
        XCTAssertEqual(paths.count, 3);
        if(paths.count != 3) {
            continue;
        }
        XCTAssertNotEqual(paths[0], paths[1]);
        XCTAssertEqual(paths[0].strokeWidth.value, 2);
        XCTAssertEqual(paths[1].strokeWidth.value, 9);
        XCTAssertEqual(paths[2].strokeWidth.value, 4);
        for(IJSVGNode* path in paths) {
            XCTAssertEqualObjects(path.classNameList, ([NSSet setWithArray:@[@"item", @"detail"]]));
        }
        XCTAssertNotEqual(paths[0].fill, paths[1].fill);
    }
}

- (void)testClassWhitespaceMatchesAcrossNormalCachedAndSelectorRecords
{
    for(NSString* selector in @[@".item.detail.extra", @"g > .item.detail.extra"]) {
        NSString* rect = @"<rect class=' item&#x9;detail&#xA;extra&#xD; ' width='3' height='4'/>";
        NSString* svg = IJSVGTestSVG([NSString stringWithFormat:
            @"<style>%@ { opacity: .6 }</style><g>%@</g>"
             "<defs><g id='shape'>%@</g></defs>"
             "<use href='#shape'/><use href='#shape'/><use href='#shape'/>",
            selector, rect, rect]);
        NSError* error = nil;
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:svg fileURL:nil error:&error];
        XCTAssertNotNil(parser);
        XCTAssertNil(error);
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
        XCTAssertEqual(root.children.count, 4);
        for(IJSVGGroup* group in root.children) {
            IJSVGNode* node = group.children.firstObject;
            if([node isKindOfClass:IJSVGGroup.class]) {
                node = ((IJSVGGroup*)node).children.firstObject;
            }
            XCTAssertNotNil(node);
            XCTAssertEqualObjects(node.classNameList, ([NSSet setWithArray:@[@"item", @"detail", @"extra"]]));
            XCTAssertEqualWithAccuracy(node.opacity.value, .6, .001, @"Selector %@", selector);
        }
    }
}

@end
