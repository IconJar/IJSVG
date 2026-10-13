//
//  IJSVGElementNodeTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGUmbrella.h>
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

@interface IJSVGElementNodeTests : XCTestCase
@end

@implementation IJSVGElementNodeTests

- (void)testRepeatedUseResolvesGeometryForEachInstance
{
    IJSVGRootNode* root = [self root:@"<defs><rect id='variable' width='var(--size)' "
                                     @"height='3'/><rect id='inherited' "
                                     @"style='width:inherit' height='3'/></defs>"
                                      "<use href='#variable' style='--size:7'/><use "
                                      "href='#variable' style='--size:7'/>"
                                      "<use href='#variable' style='--size:19'/><use "
                                      "href='#variable' style='--size:7'/>"
                                      "<use href='#inherited' style='width:11'/><use "
                                      "href='#inherited' style='width:11'/>"
                                      "<use href='#inherited' style='width:23'/><use "
                                      "href='#inherited' style='width:11'/>"];
    NSArray<NSNumber*>* widths = @[ @7, @7, @19, @7, @11, @11, @23, @11 ];
    XCTAssertEqual(root.children.count, widths.count);
    if (root.children.count != widths.count)
        return;
    for (NSUInteger index = 0; index < widths.count; index++) {
        IJSVGUse* use = (IJSVGUse*)root.children[index];
        IJSVGRect* rect = (IJSVGRect*)use.children.firstObject;
        XCTAssertEqualWithAccuracy(rect.width.value, widths[index].doubleValue, .0001);
    }
}

- (IJSVGRootNode*)root:(NSString*)body
{
    NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' "
                                               @"width='64' height='64'>%@</svg>",
        body];
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml];
    XCTAssertNotNil(svg);
    IJSVGRootNode* root = svg.rootNode;
    XCTAssertNotNil(root);
    return root;
}

- (void)testNodesOnlyExposeTheirOwnedCapabilities
{
    XCTAssertFalse([[[IJSVGNode alloc] init] respondsToSelector:NSSelectorFromString(@"fill")]);
    XCTAssertFalse([[[IJSVGStop alloc] init] respondsToSelector:NSSelectorFromString(@"stroke")]);
    XCTAssertFalse([[[IJSVGPath alloc] init] respondsToSelector:NSSelectorFromString(@"viewBox")]);
    XCTAssertFalse([[[IJSVGPath alloc] init] respondsToSelector:NSSelectorFromString(@"r")]);
    XCTAssertFalse([[[IJSVGCircle alloc] init] respondsToSelector:NSSelectorFromString(@"x1")]);
    XCTAssertTrue([[[IJSVGCircle alloc] init] respondsToSelector:@selector(r)]);
    XCTAssertTrue([[[IJSVGLine alloc] init] respondsToSelector:@selector(x1)]);
    XCTAssertTrue([[[IJSVGRect alloc] init] respondsToSelector:@selector(rx)]);
    XCTAssertFalse([[[IJSVGRootNode alloc] init] respondsToSelector:NSSelectorFromString(@"refX")]);
    XCTAssertTrue([[[IJSVGSymbol alloc] init] respondsToSelector:@selector(refX)]);
    XCTAssertLessThan(class_getInstanceSize(IJSVGStop.class), class_getInstanceSize(IJSVGPath.class));
}

- (void)testReferencesRemainIndependentWhenNodesAreCopied
{
    IJSVGReference* reference = [[IJSVGReference alloc] initWithHref:@"#source"];
    NSArray<IJSVGNode<IJSVGReferenceNode>*>* nodes = @[ [[IJSVGUse alloc] init], [[IJSVGLinearGradient alloc] init], [[IJSVGRadialGradient alloc] init], [[IJSVGPattern alloc] init], [[IJSVGImage alloc] init], [[IJSVGFilter alloc] init], [[IJSVGFilterImagePrimitive alloc] init], [[IJSVGTextPath alloc] init], [[IJSVGAnchor alloc] init] ];
    for (IJSVGNode<IJSVGReferenceNode>* node in nodes) {
        node.reference = reference;
        IJSVGNode<IJSVGReferenceNode>* copy = node.copy;
        XCTAssertEqualObjects(copy.reference.href, @"#source");
        XCTAssertEqualObjects(copy.reference.fragmentIdentifier, @"source");
        copy.reference = [[IJSVGReference alloc] initWithHref:@"#other"];
        XCTAssertEqualObjects(node.reference.fragmentIdentifier, @"source");
        XCTAssertEqualObjects(copy.reference.fragmentIdentifier, @"other");
    }
    XCTAssertFalse([[[IJSVGNode alloc] init] respondsToSelector:@selector(reference)]);
    XCTAssertFalse([[[IJSVGRect alloc] init] respondsToSelector:@selector(reference)]);
}

- (void)testReferencesConsumeXMLValuesBeforeTheStyleCascade
{
    IJSVGRootNode* root = [self root:@"<defs><rect id='box' width='7' height='8'/>"
                                      "<path id='guide' d='M0 10H50'/></defs>"
                                      "<use xmlns:l='http://www.w3.org/1999/xlink' l:href='#box' href=''/>"
                                      "<use xmlns:l='http://www.w3.org/1999/xlink' l:href='#box' "
                                      "style='href:#guide'/>"
                                      "<text><textPath href='#guide'>Text</textPath></text>"];
    XCTAssertEqual(root.children.count, 3u);
    if (root.children.count != 3)
        return;
    IJSVGUse* empty = (IJSVGUse*)root.children[0];
    XCTAssertEqualObjects(empty.reference.href, @"");
    XCTAssertNil(empty.reference.fragmentIdentifier);
    XCTAssertEqual(empty.children.count, 0u);
    IJSVGUse* use = (IJSVGUse*)root.children[1];
    XCTAssertEqualObjects(use.reference.fragmentIdentifier, @"box");
    XCTAssertEqual(((IJSVGRect*)use.children.firstObject).width.value, 7);
    IJSVGText* text = (IJSVGText*)root.children[2];
    IJSVGTextPath* textPath = (IJSVGTextPath*)text.children.firstObject;
    XCTAssertEqualObjects(textPath.reference.fragmentIdentifier, @"guide");
    XCTAssertNotNil(textPath.textPath);
}

- (void)testShapesKeepTheirConcreteTypeWhenCopied
{
    IJSVGRootNode* node = [self root:@"<path d='M0 0L10 10'/><rect width='10' height='20'/>"
                                      "<circle r='5'/><ellipse rx='5' ry='3'/>"
                                      "<line x1='1' y1='2' x2='3' y2='4'/>"
                                      "<polygon points='0,0 10,0 5,10'/><polyline points='0,0 10,0 "
                                      "5,10'/>"];
    NSArray<NSString*>* names = @[ @"IJSVGPath", @"IJSVGRect", @"IJSVGCircle", @"IJSVGEllipse", @"IJSVGLine", @"IJSVGPolygon", @"IJSVGPolyline" ];
    XCTAssertEqual(node.children.count, names.count);
    if (node.children.count != names.count)
        return;
    for (NSUInteger index = 0; index < names.count; index++) {
        IJSVGNode* child = node.children[index];
        XCTAssertEqualObjects(NSStringFromClass(child.class), names[index]);
        IJSVGNode* copy = child.copy;
        XCTAssertNotNil(copy);
        XCTAssertEqualObjects(NSStringFromClass(copy.class), names[index]);
        XCTAssertNotEqual(copy, child);
    }
    IJSVGLine* line = (IJSVGLine*)node.children[4];
    XCTAssertEqual(line.x2.value, 3);
}

- (void)testStopDoesNotConsumeShapeAttributes
{
    IJSVGRootNode* node = [self root:@"<defs><linearGradient id='paint'>"
                                      "<stop offset='.25' stop-color='red' stroke='blue' width='99' "
                                      "filter='url(#missing)' d='M0 0L1 1'/><stop offset='1' "
                                      "stop-color='blue'/>"
                                      "</linearGradient></defs><rect width='64' height='64' "
                                      "fill='url(#paint)'/>"];
    IJSVGPaintNode* shape = (IJSVGPaintNode*)node.children.firstObject;
    XCTAssertTrue([shape.fill isKindOfClass:IJSVGLinearGradient.class]);
    IJSVGLinearGradient* gradient = (IJSVGLinearGradient*)shape.fill;
    XCTAssertTrue([gradient.children.firstObject isKindOfClass:IJSVGStop.class]);
    IJSVGStop* stop = (IJSVGStop*)gradient.children.firstObject;
    XCTAssertEqual(stop.offset.value, .25);
    XCTAssertFalse([stop respondsToSelector:NSSelectorFromString(@"stroke")]);
    XCTAssertFalse([stop respondsToSelector:NSSelectorFromString(@"filter")]);
    XCTAssertFalse([stop respondsToSelector:NSSelectorFromString(@"width")]);
}

- (void)testFilterParametersBelongToTheirPrimitive
{
    IJSVGRootNode* node = [self root:@"<defs><filter id='filter'><feGaussianBlur stdDeviation='2' "
                                     @"k1='42' slope='9'/>"
                                      "<feComponentTransfer><feFuncR type='linear' slope='.5' "
                                      "stdDeviation='9'/>"
                                      "</feComponentTransfer></filter></defs>"
                                      "<rect width='10' height='10' filter='url(#filter)'/>"];
    IJSVGGraphicsNode* shape = (IJSVGGraphicsNode*)node.children.firstObject;
    IJSVGFilter* filter = shape.filter;
    XCTAssertNotNil(filter);
    XCTAssertTrue([filter.children.firstObject isKindOfClass:IJSVGFilterGaussianBlurPrimitive.class]);
    IJSVGFilterGaussianBlurPrimitive* blur = (IJSVGFilterGaussianBlurPrimitive*)filter.children.firstObject;
    XCTAssertEqualObjects(blur.parameters[@"stdDeviation"], @"2");
    XCTAssertNil(blur.parameters[@"k1"]);
    XCTAssertNil(blur.parameters[@"slope"]);
    XCTAssertTrue([filter.children.lastObject isKindOfClass:IJSVGFilterComponentTransferPrimitive.class]);
    IJSVGFilterComponentTransferPrimitive* transfer = (IJSVGFilterComponentTransferPrimitive*)filter.children.lastObject;
    XCTAssertTrue([transfer.children.firstObject isKindOfClass:IJSVGFilterFuncRPrimitive.class]);
    IJSVGFilterFuncRPrimitive* function = (IJSVGFilterFuncRPrimitive*)transfer.children.firstObject;
    XCTAssertEqualObjects(function.parameters[@"slope"], @".5");
    XCTAssertNil(function.parameters[@"stdDeviation"]);
}

- (void)testTextAnchorsRetainMixedContent
{
    IJSVGRootNode* node = [self root:@"<text x='1' y='20'>before<a href='#target'>linked<tspan> "
                                     @"span</tspan></a>after</text>"];
    XCTAssertTrue([node.children.firstObject isKindOfClass:IJSVGText.class]);
    IJSVGText* text = (IJSVGText*)node.children.firstObject;
    XCTAssertTrue([text.children.firstObject isKindOfClass:IJSVGAnchor.class]);
    IJSVGAnchor* anchor = (IJSVGAnchor*)text.children.firstObject;
    XCTAssertTrue([anchor.textContent containsObject:@"linked"]);
    XCTAssertTrue([anchor.children.firstObject isKindOfClass:IJSVGTextSpan.class]);
    XCTAssertTrue([text.textContent containsObject:@"after"]);
}

- (void)testDefinitionsAndMetadataDoNotBecomeRenderedChildren
{
    IJSVGRootNode* node = [self root:@"<title>Example</title><desc>Description</desc>"
                                      "<defs><style>rect { fill: red }</style><rect id='shape' "
                                      "width='10' height='10'/></defs>"
                                      "<use href='#shape'/>"];
    XCTAssertEqualObjects(node.title, @"Example");
    XCTAssertEqualObjects(node.desc, @"Description");
    XCTAssertEqual(node.children.count, 1u);
    XCTAssertTrue([node.children.firstObject isKindOfClass:IJSVGUse.class]);
}

- (void)testTextPositioningDoesNotRequireTextStyleAttributes
{
    IJSVGRootNode* node = [self root:@"<text x='7' y='20'><tspan dx='3'>text</tspan></text>"];
    XCTAssertTrue([node.children.firstObject isKindOfClass:IJSVGText.class]);
    IJSVGText* text = (IJSVGText*)node.children.firstObject;
    XCTAssertTrue([text.children.firstObject isKindOfClass:IJSVGTextSpan.class]);
    IJSVGTextSpan* span = (IJSVGTextSpan*)text.children.firstObject;
    XCTAssertNotNil(text.positioning[@"x"]);
    XCTAssertNotNil(text.positioning[@"y"]);
    XCTAssertNotNil(span.positioning[@"dx"]);
}

- (void)testShapesIgnoreGeometryOwnedByOtherElements
{
    IJSVGRootNode* node = [self root:@"<circle cx='10' cy='11' r='4' x='40' width='99' rx='20'/>"
                                      "<rect width='12' height='14' cx='50' cy='51' r='30'/>"];
    XCTAssertTrue([node.children.firstObject isKindOfClass:IJSVGCircle.class]);
    IJSVGCircle* circle = (IJSVGCircle*)node.children.firstObject;
    XCTAssertTrue([node.children.lastObject isKindOfClass:IJSVGRect.class]);
    IJSVGRect* rectangle = (IJSVGRect*)node.children.lastObject;
    XCTAssertEqual(circle.cx.value, 10);
    XCTAssertEqual(circle.r.value, 4);
    XCTAssertEqual(circle.geometryLengths.count, 3u);
    XCTAssertEqual(rectangle.width.value, 12);
    XCTAssertEqual(rectangle.geometryLengths.count, 2u);
}

@end
