//
//  IJSVGNodeAndColorStorageTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGTestHelpers.h"
#import <IJSVG/IJSVGTraitedColor.h>
#import <IJSVG/IJSVGTraitedColorStorage.h>

@interface IJSVGNodeAndColorStorageTests : XCTestCase
@end

@implementation IJSVGNodeAndColorStorageTests

- (NSColor*)rgb:(NSColor*)color
{
    return [color colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
}

- (void)testNodeTypeMappingCoversKnownElementsAndTextFallback
{
    XCTAssertEqual([IJSVGNode typeForString:@"g" kind:NSXMLElementKind], IJSVGNodeTypeGroup);
    XCTAssertEqual([IJSVGNode typeForString:@"PATH" kind:NSXMLElementKind], IJSVGNodeTypePath);
    XCTAssertEqual([IJSVGNode typeForString:@"linearGradient" kind:NSXMLElementKind], IJSVGNodeTypeLinearGradient);
    XCTAssertEqual([IJSVGNode typeForString:@"radialGradient" kind:NSXMLElementKind], IJSVGNodeTypeRadialGradient);
    XCTAssertEqual([IJSVGNode typeForString:@"clipPath" kind:NSXMLElementKind], IJSVGNodeTypeClipPath);
    XCTAssertEqual([IJSVGNode typeForString:@"feGaussianBlur" kind:NSXMLElementKind], IJSVGNodeTypeUnknown);
    XCTAssertEqual([IJSVGNode typeForString:@"unknown" kind:NSXMLElementKind], IJSVGNodeTypeUnknown);
    XCTAssertEqual([IJSVGNode typeForString:@"text body" kind:NSXMLTextKind], IJSVGNodeTypeTextSpan);
    XCTAssertEqual([IJSVGNode typeForString:nil kind:NSXMLElementKind], IJSVGNodeTypeNotFound);
}

- (void)testNodeTypeIsPathableOnlyForPathShapes
{
    XCTAssertTrue([IJSVGNode typeIsPathable:IJSVGNodeTypePath]);
    XCTAssertTrue([IJSVGNode typeIsPathable:IJSVGNodeTypeRect]);
    XCTAssertTrue([IJSVGNode typeIsPathable:IJSVGNodeTypeCircle]);
    XCTAssertTrue([IJSVGNode typeIsPathable:IJSVGNodeTypeEllipse]);
    XCTAssertTrue([IJSVGNode typeIsPathable:IJSVGNodeTypePolygon]);
    XCTAssertTrue([IJSVGNode typeIsPathable:IJSVGNodeTypePolyline]);
    XCTAssertTrue([IJSVGNode typeIsPathable:IJSVGNodeTypeLine]);
    XCTAssertFalse([IJSVGNode typeIsPathable:IJSVGNodeTypeGroup]);
    XCTAssertFalse([IJSVGNode typeIsPathable:IJSVGNodeTypeLinearGradient]);
}

- (void)testNodeDefaultsAndTraitMutation
{
    IJSVGNode* node = [[IJSVGNode alloc] init];

    XCTAssertTrue(node.shouldRender);
    XCTAssertEqualWithAccuracy(node.opacity.value, 1.f, 0.0001f);
    XCTAssertEqualWithAccuracy(node.fillOpacity.value, 1.f, 0.0001f);
    XCTAssertEqualWithAccuracy(node.strokeOpacity.value, 1.f, 0.0001f);
    XCTAssertEqual(node.windingRule, IJSVGWindingRuleInherit);
    XCTAssertEqual(node.lineCapStyle, IJSVGLineCapStyleInherit);
    XCTAssertEqual(node.lineJoinStyle, IJSVGLineJoinStyleInherit);
    XCTAssertFalse([node matchesTraits:IJSVGNodeTraitPaintable]);

    [node addTraits:IJSVGNodeTraitPaintable | IJSVGNodeTraitStroked];
    XCTAssertTrue([node matchesTraits:IJSVGNodeTraitPaintable]);
    XCTAssertTrue([node matchesTraits:IJSVGNodeTraitStroked]);

    [node removeTraits:IJSVGNodeTraitStroked];
    XCTAssertTrue([node matchesTraits:IJSVGNodeTraitPaintable]);
    XCTAssertFalse([node matchesTraits:IJSVGNodeTraitStroked]);
}

- (void)testGroupMaintainsParentLinksWhenAddingMovingAndRemovingChildren
{
    IJSVGGroup* firstParent = [[IJSVGGroup alloc] init];
    IJSVGGroup* secondParent = [[IJSVGGroup alloc] init];
    IJSVGNode* child = IJSVGTestNode(@"rect", @"child", nil);

    [firstParent addChild:child];
    XCTAssertEqual(child.parentNode, firstParent);
    XCTAssertTrue([firstParent.children containsObject:child]);

    [secondParent addChild:child];
    XCTAssertEqual(child.parentNode, secondParent);
    XCTAssertFalse([firstParent.children containsObject:child]);
    XCTAssertTrue([secondParent.children containsObject:child]);

    [secondParent removeChild:child];
    XCTAssertNil(child.parentNode);
    XCTAssertFalse([secondParent.children containsObject:child]);
}

- (void)testGroupFiltersChildrenByTypeAndTraits
{
    IJSVGGroup* group = [[IJSVGGroup alloc] init];
    IJSVGNode* rect = IJSVGTestNode(@"rect", nil, nil);
    rect.type = IJSVGNodeTypeRect;
    [rect addTraits:IJSVGNodeTraitPathed | IJSVGNodeTraitPaintable];
    IJSVGNode* circle = IJSVGTestNode(@"circle", nil, nil);
    circle.type = IJSVGNodeTypeCircle;
    [circle addTraits:IJSVGNodeTraitPaintable];
    IJSVGNode* hidden = IJSVGTestNode(@"path", nil, nil);
    hidden.type = IJSVGNodeTypePath;
    hidden.shouldRender = NO;
    [hidden addTraits:IJSVGNodeTraitPathed];
    [group addChildren:@[ rect, circle, hidden ]];

    XCTAssertEqual([group childrenOfType:IJSVGNodeTypeRect].count, 1u);
    XCTAssertTrue([[group childSetOfType:IJSVGNodeTypeCircle] containsObject:circle]);
    XCTAssertTrue([group containsNodesMatchingTraits:IJSVGNodeTraitPaintable]);
    XCTAssertEqual([group nodesMatchingTraits:IJSVGNodeTraitPathed].count, 1u);
    XCTAssertFalse([group childrenMatchTraits:IJSVGNodeTraitPathed]);
}

- (void)testWalkNodeTreeCanSkipChildrenAndStopEarly
{
    IJSVGGroup* root = [[IJSVGGroup alloc] init];
    root.name = @"root";
    IJSVGGroup* branch = [[IJSVGGroup alloc] init];
    branch.name = @"branch";
    IJSVGNode* skipped = IJSVGTestNode(@"rect", nil, nil);
    skipped.name = @"skipped";
    IJSVGNode* after = IJSVGTestNode(@"circle", nil, nil);
    after.name = @"after";
    [branch addChild:skipped];
    [root addChildren:@[ branch, after ]];

    NSMutableArray<NSString*>* visited = [[NSMutableArray alloc] init];
    [IJSVGNode walkNodeTree:root handler:^(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop) {
        [visited addObject:node.name ?: @"unknown"];
        if(node == branch) {
            *allowChildNodes = NO;
        }
    }];
    XCTAssertEqualObjects(visited, (@[ @"root", @"branch", @"after" ]));

    [visited removeAllObjects];
    [IJSVGNode walkNodeTree:root handler:^(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop) {
        [visited addObject:node.name ?: @"unknown"];
        if(node == branch) {
            *stop = YES;
        }
    }];
    XCTAssertEqualObjects(visited, (@[ @"root", @"branch" ]));
}

- (void)testInheritedNodePropertiesResolveFromParent
{
    IJSVGGroup* parent = [[IJSVGGroup alloc] init];
    IJSVGNode* child = [[IJSVGNode alloc] init];
    parent.opacity = [IJSVGUnitLength unitWithFloat:0.5f];
    parent.fillOpacity = [IJSVGUnitLength unitWithFloat:0.25f];
    parent.strokeWidth = [IJSVGUnitLength unitWithFloat:3.f];
    parent.windingRule = IJSVGWindingRuleEvenOdd;
    parent.clipRule = IJSVGWindingRuleNonZero;
    parent.lineCapStyle = IJSVGLineCapStyleRound;
    parent.lineJoinStyle = IJSVGLineJoinStyleBevel;
    [parent addChild:child];

    child.opacity.inherit = YES;
    XCTAssertEqualWithAccuracy(child.opacity.value, 0.5f, 0.0001f);
    XCTAssertEqualWithAccuracy(child.fillOpacity.value, 0.25f, 0.0001f);
    XCTAssertEqualWithAccuracy(child.strokeWidth.value, 3.f, 0.0001f);
    XCTAssertEqual(child.windingRule, IJSVGWindingRuleEvenOdd);
    XCTAssertEqual(child.clipRule, IJSVGWindingRuleNonZero);
    XCTAssertEqual(child.lineCapStyle, IJSVGLineCapStyleRound);
    XCTAssertEqual(child.lineJoinStyle, IJSVGLineJoinStyleBevel);
}

- (void)testColorNodeReturnsColorsForRequestedTraitsAndStyleOverrides
{
    IJSVGColorNode* colorNode = [[IJSVGColorNode alloc] initWithColor:NSColor.redColor];
    IJSVGStyle* style = [[IJSVGStyle alloc] init];
    style.fillColor = NSColor.greenColor;

    IJSVGTraitedColorStorage* fillStorage = [colorNode colorsWithStyle:style
                                                        matchingTraits:IJSVGColorUsageTraitFill];
    IJSVGTraitedColor* fillColor = fillStorage.colors.anyObject;
    XCTAssertEqual(fillStorage.count, 1u);
    XCTAssertTrue([fillColor matchesTraits:IJSVGColorUsageTraitFill]);
    XCTAssertEqualWithAccuracy([self rgb:fillColor.color].greenComponent, 1.f, 0.002f);

    colorNode.isNoneOrTransparent = YES;
    IJSVGTraitedColorStorage* emptyStorage = [colorNode colorsWithStyle:style
                                                         matchingTraits:IJSVGColorUsageTraitFill];
    XCTAssertEqual(emptyStorage.count, 0u);
}

- (void)testTraitedColorMergesAndMatchesTraitsByColor
{
    IJSVGTraitedColor* color = [IJSVGTraitedColor colorWithColor:NSColor.redColor
                                                          traits:IJSVGColorUsageTraitFill];
    IJSVGTraitedColor* sameColor = [IJSVGTraitedColor colorWithColor:NSColor.redColor
                                                              traits:IJSVGColorUsageTraitStroke];
    IJSVGTraitedColor* differentColor = [IJSVGTraitedColor colorWithColor:NSColor.blueColor
                                                                   traits:IJSVGColorUsageTraitFill];

    XCTAssertEqualObjects(color, sameColor);
    XCTAssertNotEqualObjects(color, differentColor);
    XCTAssertTrue([color matchesTraits:IJSVGColorUsageTraitFill]);
    [color addTraits:IJSVGColorUsageTraitStroke];
    XCTAssertTrue([color matchesTraits:IJSVGColorUsageTraitFill | IJSVGColorUsageTraitStroke]);
    [color removeTraits:IJSVGColorUsageTraitFill];
    XCTAssertFalse([color matchesTraits:IJSVGColorUsageTraitFill]);
}

- (void)testTraitedColorStorageMergesColorsAndReplacesByTrait
{
    IJSVGTraitedColorStorage* storage = [[IJSVGTraitedColorStorage alloc] init];
    IJSVGTraitedColor* fillRed = [IJSVGTraitedColor colorWithColor:NSColor.redColor
                                                            traits:IJSVGColorUsageTraitFill];
    IJSVGTraitedColor* strokeRed = [IJSVGTraitedColor colorWithColor:NSColor.redColor
                                                              traits:IJSVGColorUsageTraitStroke];
    [storage addColor:fillRed];
    [storage addColor:strokeRed];

    XCTAssertEqual(storage.count, 1u);
    XCTAssertTrue([storage matchesTraits:IJSVGColorUsageTraitFill]);
    XCTAssertTrue([storage.colors.anyObject matchesTraits:IJSVGColorUsageTraitFill | IJSVGColorUsageTraitStroke]);

    [storage replaceColor:NSColor.redColor
                withColor:NSColor.greenColor
                   traits:IJSVGColorUsageTraitFill];
    XCTAssertEqual(storage.replacedColorCount, 1u);
    XCTAssertTrue([storage matchesReplacementTraits:IJSVGColorUsageTraitFill]);
    XCTAssertNil([storage colorForColor:NSColor.redColor
                         matchingTraits:IJSVGColorUsageTraitStroke]);

    NSColor* replacement = [storage colorForColor:NSColor.redColor
                                   matchingTraits:IJSVGColorUsageTraitFill];
    XCTAssertNotNil(replacement);
    XCTAssertEqualWithAccuracy([self rgb:replacement].greenComponent, 1.f, 0.002f);
}

@end
