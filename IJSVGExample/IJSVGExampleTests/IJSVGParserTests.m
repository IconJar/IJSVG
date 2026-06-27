//
//  IJSVGParserTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGTestHelpers.h"

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
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGData:data
                                                       fileURL:nil
                                                         error:&error];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGPath* rect = (IJSVGPath*)rootNode.children.firstObject;

    XCTAssertNotNil(parser);
    XCTAssertNil(error);
    XCTAssertEqualObjects(rect.identifier, @"box");
    XCTAssertEqual(rect.primitiveType, kIJSVGPrimitivePathTypeRect);
}

- (void)testParserBuildsRootAndPathNodeAttributes
{
    NSString* string = IJSVGTestSVG(@"<rect id=\"box\" class=\"primary selected\" x=\"1\" y=\"2\" width=\"3\" height=\"4\" fill=\"#336699\"/>");
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:string
                                                         fileURL:nil
                                                           error:&error];
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
    NSString* string = @"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"6\"><rect width=\"12\" height=\"6\"/></svg>";
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:string
                                                         fileURL:nil
                                                           error:&error];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(12.f, 6.f)];

    XCTAssertNotNil(parser);
    XCTAssertNil(error);
    XCTAssertEqualWithAccuracy(rootNode.viewBox.size.width.value, 12.f, 0.001);
    XCTAssertEqualWithAccuracy(rootNode.viewBox.size.height.value, 6.f, 0.001);
    XCTAssertEqualWithAccuracy(rootNode.intrinsicSize.width.value, 12.f, 0.001);
    XCTAssertEqualWithAccuracy(rootNode.intrinsicSize.height.value, 6.f, 0.001);
}

- (void)testParserAppliesStyleElementRulesToNodeAttributes
{
    NSString* body = @"<style>rect.target { fill: #00ff00; stroke: #0000ff; stroke-width: 2; }</style><rect class=\"target\" width=\"8\" height=\"8\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body)
                                                         fileURL:nil
                                                           error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGPath* rect = (IJSVGPath*)rootNode.children.firstObject;

    XCTAssertTrue([rect.fill isKindOfClass:IJSVGColorNode.class]);
    XCTAssertTrue([rect.stroke isKindOfClass:IJSVGColorNode.class]);
    XCTAssertEqualWithAccuracy(rect.strokeWidth.value, 2.f, 0.001);
}

- (void)testParserAllowsInlineStyleToOverrideStyleElement
{
    NSString* body = @"<style>rect { fill: #00ff00; stroke-width: 1; }</style><rect width=\"8\" height=\"8\" style=\"fill: #ff0000; stroke-width: 3;\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body)
                                                         fileURL:nil
                                                           error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGPath* rect = (IJSVGPath*)rootNode.children.firstObject;
    IJSVGColorNode* fill = (IJSVGColorNode*)rect.fill;
    NSColor* rgbColor = [fill.color colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];

    XCTAssertEqualWithAccuracy(rgbColor.redComponent, 1.f, 0.03);
    XCTAssertEqualWithAccuracy(rgbColor.greenComponent, 0.f, 0.03);
    XCTAssertEqualWithAccuracy(rgbColor.blueComponent, 0.f, 0.03);
    XCTAssertEqualWithAccuracy(rect.strokeWidth.value, 3.f, 0.001);
}

- (void)testParserBuildsNestedNodeTreeWithParentLinksAndOrder
{
    NSString* body = @"<title>Root title</title><desc>Root description</desc>"
        @"<g id=\"outer\" class=\"container\" transform=\"translate(2,3)\">"
        @"<rect id=\"first\" width=\"2\" height=\"2\"/>"
        @"<g id=\"inner\"><circle id=\"dot\" cx=\"4\" cy=\"4\" r=\"1\"/></g>"
        @"<line id=\"last\" x1=\"0\" y1=\"0\" x2=\"8\" y2=\"8\"/>"
        @"</g>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body)
                                                         fileURL:nil
                                                           error:nil];
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

- (void)testParserCopiesRepeatedUseReferencesIntoDistinctChildren
{
    NSString* body = @"<defs><path id=\"shape\" d=\"M0 0 H8\"/></defs>"
        @"<use id=\"first-use\" href=\"#shape\"/>"
        @"<use id=\"second-use\" href=\"#shape\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body)
                                                         fileURL:nil
                                                           error:nil];
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
    NSString* body = @"<rect id=\"rect\" width=\"1\" height=\"1\"/>"
        @"<circle id=\"circle\" cx=\"2\" cy=\"2\" r=\"1\"/>"
        @"<ellipse id=\"ellipse\" cx=\"3\" cy=\"3\" rx=\"1\" ry=\"2\"/>"
        @"<polygon id=\"polygon\" points=\"0,0 2,0 2,2\"/>"
        @"<polyline id=\"polyline\" points=\"0,0 1,1 2,0\"/>"
        @"<line id=\"line\" x1=\"0\" y1=\"0\" x2=\"8\" y2=\"8\"/>"
        @"<path id=\"path\" d=\"M0 0 H8\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body)
                                                         fileURL:nil
                                                           error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    NSArray<NSNumber*>* expectedTypes = @[ @(kIJSVGPrimitivePathTypeRect),
                                           @(kIJSVGPrimitivePathTypeCircle),
                                           @(kIJSVGPrimitivePathTypeEllipse),
                                           @(kIJSVGPrimitivePathTypePolygon),
                                           @(kIJSVGPrimitivePathTypePolyLine),
                                           @(kIJSVGPrimitivePathTypeLine),
                                           @(kIJSVGPrimitivePathTypePath) ];
    NSArray<NSString*>* expectedIdentifiers = @[ @"rect", @"circle", @"ellipse", @"polygon", @"polyline", @"line", @"path" ];

    XCTAssertEqual(rootNode.children.count, expectedTypes.count);
    for(NSUInteger index = 0; index < expectedTypes.count; index++) {
        IJSVGPath* path = (IJSVGPath*)rootNode.children[index];
        XCTAssertTrue([path isKindOfClass:IJSVGPath.class]);
        XCTAssertEqual(path.primitiveType, expectedTypes[index].integerValue);
        XCTAssertEqualObjects(path.identifier, expectedIdentifiers[index]);
        XCTAssertEqual(path.parentNode, rootNode);
    }
}

- (void)testParserResolvesClipPathAndMaskReferencesIntoDetachedNodeTrees
{
    NSString* body = @"<defs>"
        @"<clipPath id=\"clip\"><rect id=\"clip-rect\" width=\"4\" height=\"4\"/></clipPath>"
        @"<mask id=\"mask\"><rect id=\"mask-rect\" width=\"8\" height=\"8\" fill=\"#ffffff\"/></mask>"
        @"</defs>"
        @"<rect id=\"target\" width=\"8\" height=\"8\" clip-path=\"url(#clip)\" mask=\"url(#mask)\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body)
                                                         fileURL:nil
                                                           error:nil];
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
    NSString* body = @"<defs><linearGradient id=\"fade\" x1=\"0\" y1=\"0\" x2=\"8\" y2=\"0\" gradientUnits=\"userSpaceOnUse\">"
        @"<stop offset=\"0\" stop-color=\"#ff0000\"/>"
        @"<stop offset=\"1\" stop-color=\"#0000ff\" stop-opacity=\"0.5\"/>"
        @"</linearGradient></defs>"
        @"<rect id=\"target\" width=\"8\" height=\"8\" fill=\"url(#fade)\"/>";
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body)
                                                         fileURL:nil
                                                           error:nil];
    IJSVGRootNode* rootNode = [parser rootNodeWithSize:CGSizeMake(8.f, 8.f)];
    IJSVGPath* target = (IJSVGPath*)rootNode.children.firstObject;
    IJSVGLinearGradient* gradient = (IJSVGLinearGradient*)target.fill;
    NSColor* firstColor = [gradient.colors.firstObject colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
    NSColor* lastColor = [gradient.colors.lastObject colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];

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
    XCTAssertEqualWithAccuracy(firstColor.redComponent, 1.f, 0.03);
    XCTAssertEqualWithAccuracy(firstColor.blueComponent, 0.f, 0.03);
    XCTAssertEqualWithAccuracy(lastColor.redComponent, 0.f, 0.03);
    XCTAssertEqualWithAccuracy(lastColor.blueComponent, 1.f, 0.03);
    XCTAssertEqualWithAccuracy(lastColor.alphaComponent, 0.5f, 0.03);
}

- (void)testParserReturnsErrorForMalformedXML
{
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:@"<svg><rect></svg>"
                                                         fileURL:nil
                                                           error:&error];

    XCTAssertNil(parser);
    XCTAssertNotNil(error);
}

@end
