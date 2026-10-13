//
//  IJSVGParserOptimizationTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 07/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGFilterPrimitive.h>
#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGRadialGradient.h>
#import <IJSVG/IJSVGRect.h>
#import <IJSVG/IJSVGUse.h>
#import <IJSVGParsedPathCache.h>
#import <IJSVGParserUtils.h>
#import <IJSVGTestHelpers.h>

@interface IJSVGParserOptimizationTests : XCTestCase
@end

@implementation IJSVGParserOptimizationTests

- (void)testLocalPathCacheKeepsVariantsAndImmutableSnapshots
{
    IJSVGParsedPathCache* cache = IJSVGParsedPathCacheCreate();
    IJSVGParsedPathCache* otherCache = IJSVGParsedPathCacheCreate();
    XCTAssertNotEqual(cache, NULL);
    XCTAssertNotEqual(otherCache, NULL);
    NSString* key = @"same source";
    for (NSUInteger index = 0; index < IJSVGParsedPathKindCount; index++) {
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathAddRect(path, NULL, CGRectMake(0, 0, index + 1, 10));
        IJSVGParsedPathCacheStore(cache, key, (IJSVGParsedPathKind)index, path);
        CGPathAddRect(path, NULL, CGRectMake(0, 0, 999, 999));
        CGPathRelease(path);
    }
    for (NSUInteger index = 0; index < IJSVGParsedPathKindCount; index++) {
        CGPathRef snapshot = IJSVGParsedPathCacheCopy(cache, key, (IJSVGParsedPathKind)index);
        XCTAssertNotEqual(snapshot, NULL);
        if (snapshot != NULL) {
            XCTAssertEqual(CGPathGetPathBoundingBox(snapshot).size.width, index + 1);
            CGPathRelease(snapshot);
        }
    }
    CGPathRef absent = IJSVGParsedPathCacheCopy(otherCache, key, IJSVGParsedPathData);
    XCTAssertEqual(absent, NULL);
    CGPathRelease(absent);
    CGPathRef otherPath = CGPathCreateWithRect(CGRectMake(0, 0, 42, 10), NULL);
    IJSVGParsedPathCacheStore(otherCache, key, IJSVGParsedPathData, otherPath);
    CGPathRelease(otherPath);
    CGPathRef snapshot = IJSVGParsedPathCacheCopy(cache, key, IJSVGParsedPathData);
    CGPathRef otherSnapshot = IJSVGParsedPathCacheCopy(otherCache, key, IJSVGParsedPathData);
    XCTAssertEqual(IJSVGParsedPathCacheCopy(cache, nil, IJSVGParsedPathData), NULL);
    XCTAssertEqual(IJSVGParsedPathCacheCopy(cache, key, IJSVGParsedPathKindCount), NULL);
    XCTAssertEqual(IJSVGParsedPathCacheCopy(NULL, key, IJSVGParsedPathData), NULL);
    IJSVGParsedPathCacheDestroy(cache);
    IJSVGParsedPathCacheDestroy(otherCache);
    IJSVGParsedPathCacheDestroy(NULL);
    XCTAssertNotEqual(snapshot, NULL);
    XCTAssertNotEqual(otherSnapshot, NULL);
    if (snapshot != NULL && otherSnapshot != NULL) {
        XCTAssertEqual(CGPathGetPathBoundingBox(snapshot).size.width, 1);
        XCTAssertEqual(CGPathGetPathBoundingBox(otherSnapshot).size.width, 42);
    }
    CGPathRelease(snapshot);
    CGPathRelease(otherSnapshot);
}

- (void)testCachedPolygonPathsPreserveClosureAndIndependentTransforms
{
    NSString* source = IJSVGTestSVG(@"<polygon points='1,2 11,2 6,12' transform='translate(10)'/>"
                                     "<polyline points='1,2 11,2 6,12'/>"
                                     "<polygon points='1,2 11,2 6,12' transform='translate(20)'/>");
    CGMutablePathRef open = CGPathCreateMutable();
    CGPathMoveToPoint(open, NULL, 1, 2);
    CGPathAddLineToPoint(open, NULL, 11, 2);
    CGPathAddLineToPoint(open, NULL, 6, 12);
    CGMutablePathRef closed = CGPathCreateMutableCopy(open);
    CGPathCloseSubpath(closed);
    for (NSUInteger iteration = 0; iteration < 2; iteration++) {
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:nil];
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
        XCTAssertEqual(root.children.count, 3);
        if (root.children.count != 3) {
            continue;
        }
        IJSVGPath* first = (IJSVGPath*)root.children[0];
        IJSVGPath* line = (IJSVGPath*)root.children[1];
        IJSVGPath* second = (IJSVGPath*)root.children[2];
        XCTAssertTrue(CGPathEqualToPath(first.path, closed));
        XCTAssertTrue(CGPathEqualToPath(line.path, open));
        XCTAssertTrue(CGPathEqualToPath(second.path, closed));
        XCTAssertEqual(first.transforms.firstObject.CGAffineTransform.tx, 10);
        XCTAssertEqual(second.transforms.firstObject.CGAffineTransform.tx, 20);
        CGPathAddRect(first.path, NULL, CGRectMake(0, 0, 999, 999));
        XCTAssertTrue(CGPathEqualToPath(second.path, closed));
        XCTAssertTrue(CGPathEqualToPath(line.path, open));
    }
    CGPathRelease(closed);
    CGPathRelease(open);
}

- (void)testCachedClipGeometryKeepsIndependentTransformsAndRules
{
    NSString* source = IJSVGTestSVG(@"<defs>"
                                     "<clipPath id='first'><path d='M0 0H10V10H0Z' "
                                     "transform='translate(10)' clip-rule='evenodd'/></clipPath>"
                                     "<clipPath id='second'><path d='M0 0H10V10H0Z' "
                                     "transform='translate(20)' clip-rule='nonzero'/></clipPath>"
                                     "</defs>"
                                     "<rect width='100' height='100' clip-path='url(#first)'/>"
                                     "<rect width='100' height='100' clip-path='url(#second)'/>"
                                     "<rect width='100' height='100' clip-path='url(#first)'/>");
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:nil];
    IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
    XCTAssertEqual(root.children.count, 3);
    if (root.children.count != 3) {
        return;
    }
    IJSVGPath* first = (IJSVGPath*)((IJSVGGraphicsNode*)root.children[0]).clipPath.children.firstObject;
    IJSVGPath* second = (IJSVGPath*)((IJSVGGraphicsNode*)root.children[1]).clipPath.children.firstObject;
    IJSVGPath* third = (IJSVGPath*)((IJSVGGraphicsNode*)root.children[2]).clipPath.children.firstObject;
    XCTAssertNotNil(first);
    XCTAssertNotNil(second);
    XCTAssertNotNil(third);
    if (first == nil || second == nil || third == nil) {
        return;
    }
    XCTAssertTrue(CGPathEqualToPath(first.path, second.path));
    XCTAssertTrue(CGPathEqualToPath(first.path, third.path));
    XCTAssertEqual(CGPathGetPathBoundingBox(first.path).origin.x, 0);
    XCTAssertEqual(first.transforms.firstObject.CGAffineTransform.tx, 10);
    XCTAssertEqual(second.transforms.firstObject.CGAffineTransform.tx, 20);
    XCTAssertEqual(third.transforms.firstObject.CGAffineTransform.tx, 10);
    XCTAssertEqual(first.clipRule, IJSVGWindingRuleEvenOdd);
    XCTAssertEqual(second.clipRule, IJSVGWindingRuleNonZero);
    CGPathAddRect(first.path, NULL, CGRectMake(0, 0, 999, 999));
    XCTAssertEqual(CGPathGetPathBoundingBox(second.path).size.width, 10);
    XCTAssertEqual(CGPathGetPathBoundingBox(third.path).size.width, 10);
}

- (void)testRepeatedClipsRemainIndependentAndTrackNewRules
{
    NSString* source = IJSVGTestSVG(@"<style>*{stroke-linecap:square;stroke-linejoin:round}</style>"
                                     "<defs><clipPath id='clip'><rect width='10' height='20' "
                                     "stroke-width='2'/></clipPath></defs>"
                                     "<rect width='100' height='100' clip-path='url(#clip)'/>"
                                     "<rect width='100' height='100' clip-path='url(#clip)'/>"
                                     "<g><style>*{stroke-linecap:round}</style>"
                                     "<rect width='100' height='100' clip-path='url(#clip)'/></g>");
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:nil];
    IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
    XCTAssertEqual(root.children.count, 3);
    if (root.children.count != 3) {
        return;
    }
    IJSVGClipPath* first = ((IJSVGGraphicsNode*)root.children[0]).clipPath;
    IJSVGClipPath* second = ((IJSVGGraphicsNode*)root.children[1]).clipPath;
    IJSVGGroup* group = (IJSVGGroup*)root.children[2];
    IJSVGClipPath* third = ((IJSVGGraphicsNode*)group.children.firstObject).clipPath;
    XCTAssertNotNil(first);
    XCTAssertNotNil(second);
    XCTAssertNotNil(third);
    XCTAssertNotEqual(first, second);
    XCTAssertEqual(((IJSVGGraphicsNode*)first.children.firstObject).lineCapStyle, IJSVGLineCapStyleSquare);
    XCTAssertEqual(((IJSVGGraphicsNode*)second.children.firstObject).lineCapStyle, IJSVGLineCapStyleSquare);
    XCTAssertEqual(((IJSVGGraphicsNode*)third.children.firstObject).lineCapStyle, IJSVGLineCapStyleRound);
    ((IJSVGGraphicsNode*)first.children.firstObject).width = [((IJSVGGraphicsNode*)first.children.firstObject).width lengthWithValue:99];
    XCTAssertEqual(((IJSVGGraphicsNode*)second.children.firstObject).width.value, 10);
    XCTAssertEqual(((IJSVGGraphicsNode*)third.children.firstObject).width.value, 10);
    ((IJSVGGraphicsNode*)first.children.firstObject).strokeWidth = [((IJSVGGraphicsNode*)first.children.firstObject).strokeWidth lengthWithValue:7];
    XCTAssertEqual(((IJSVGGraphicsNode*)second.children.firstObject).strokeWidth.value, 2);
    XCTAssertEqual(((IJSVGGraphicsNode*)third.children.firstObject).strokeWidth.value, 2);
}

- (void)testReferenceLookupPreservesNamespacesAndHrefPrecedence
{
    NSString* source = IJSVGTestSVG(@"<defs><rect id='first' width='3' height='4'/>"
                                     "<rect id='second' width='7' height='8'/></defs>"
                                     "<g xmlns:link='http://www.w3.org/1999/xlink' xmlns:other='urn:other'>"
                                     "<use link:href='#first'/>"
                                     "<use link:href='#first' href='#second'/>"
                                     "<use xmlns:xlink='urn:legacy' xlink:href='#first'/>"
                                     "<use other:href='#first'/>"
                                     "<use/></g>");
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:nil];
    IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
    IJSVGGroup* group = (IJSVGGroup*)root.children.firstObject;
    XCTAssertEqual(group.children.count, 5);
    if (group.children.count != 5) {
        return;
    }
    const CGFloat widths[] = { 3, 7, 3 };
    for (NSUInteger index = 0; index < group.children.count; index++) {
        IJSVGGroup* use = (IJSVGGroup*)group.children[index];
        XCTAssertEqual(use.children.count, index < 3 ? 1 : 0);
        if (index < 3) {
            XCTAssertEqual(((IJSVGGraphicsNode*)use.children.firstObject).width.value, widths[index]);
        }
    }
}

- (void)testCachedInlineStylesResolveAgainstEachDocument
{
    for (NSUInteger index = 0; index < 3; index++) {
        NSString* rules = index == 2 ? @"<style>rect { fill:green!important; "
                                       @"width:17px!important }</style>"
                                     : @"";
        NSString* content = [[NSString alloc] initWithFormat:@"%@<g color='%@'><rect height='20' "
                                                             @"style='fill:currentColor;width:13px;opacity:0.5'/></g>",
            rules, index == 0 ? @"red" : @"blue"];
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(content) fileURL:nil error:nil];
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
        XCTAssertEqual(root.children.count, 1);
        if (root.children.count != 1) {
            continue;
        }
        IJSVGGroup* group = (IJSVGGroup*)root.children.firstObject;
        XCTAssertEqual(group.children.count, 1);
        IJSVGGraphicsNode* rectangle = (IJSVGGraphicsNode*)group.children.firstObject;
        XCTAssertEqual(rectangle.width.value, index == 2 ? 17 : 13);
        XCTAssertEqual(rectangle.opacity.value, 0.5);
        IJSVGColorNode* fill = (IJSVGColorNode*)rectangle.fill;
        XCTAssertEqual(fill.usesCurrentColor, index != 2);
        NSColor* color = fill.usesCurrentColor ? rectangle.currentColor : fill.color;
        NSString* expectedName = index == 2 ? @"green" : (index == 0 ? @"red" : @"blue");
        XCTAssertEqualObjects(color, [IJSVGColor colorFromString:expectedName]);
        rectangle.width = [rectangle.width lengthWithValue:999];
        rectangle.opacity = [rectangle.opacity lengthWithValue:0];
    }
}

- (void)testCachedPathCacheKeepsDocumentsAndMutablePathsIndependent
{
    for (NSUInteger index = 0; index < 3; index++) {
        NSString* data = index == 2 ? @"M0 0H40V20H0Z" : @"M0 0H10V20H0Z";
        NSString* content = [[NSString alloc] initWithFormat:@"<path d='%@' fill='%@'/><path d='%@'/>", data, index == 0 ? @"red" : @"blue", data];
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(content) fileURL:nil error:nil];
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
        XCTAssertEqual(root.children.count, 2);
        if (root.children.count != 2) {
            continue;
        }
        IJSVGPath* first = (IJSVGPath*)root.children[0];
        IJSVGPath* second = (IJSVGPath*)root.children[1];
        CGFloat width = index == 2 ? 40 : 10;
        XCTAssertEqual(CGPathGetPathBoundingBox(first.path).size.width, width);
        XCTAssertEqual(CGPathGetPathBoundingBox(second.path).size.width, width);
        XCTAssertNotEqual(first.path, second.path);
        NSColor* color = ((IJSVGColorNode*)first.fill).color;
        NSColor* expected = [IJSVGColor colorFromString:index == 0 ? @"red" : @"blue"];
        XCTAssertEqualObjects(color, expected);
        CGPathAddRect(first.path, NULL, CGRectMake(0, 0, 999, 999));
        XCTAssertEqual(CGPathGetPathBoundingBox(second.path).size.width, width);
    }
}

- (void)testConcurrentParsersKeepAttributeStateIndependent
{
    const NSUInteger count = 100;
    BOOL* results = calloc(count, sizeof(BOOL));
    XCTAssertNotEqual(results, NULL);
    if (results == NULL) {
        return;
    }
    dispatch_apply(count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        @autoreleasepool {
            NSString* content = [[NSString alloc] initWithFormat:@"<g opacity='0.25'><rect width='%lu' "
                                                                 @"height='20'/><circle r='4'/></g>",
                (unsigned long)(index + 1)];
            IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(content) fileURL:nil error:nil];
            BOOL valid = parser != nil;
            for (NSUInteger iteration = 0; iteration < 2 && valid; iteration++) {
                IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
                valid = root.children.count == 1 && [root.children.firstObject isKindOfClass:IJSVGGroup.class];
                if (!valid) {
                    break;
                }
                IJSVGGroup* group = (IJSVGGroup*)root.children.firstObject;
                valid = group.children.count == 2 && group.opacity.value == 0.25;
                if (valid) {
                    IJSVGGraphicsNode* rectangle = (IJSVGGraphicsNode*)group.children[0];
                    valid = rectangle.width.value == index + 1 && rectangle.height.value == 20 && group.children[1].type == IJSVGNodeTypeCircle;
                    rectangle.width = [rectangle.width lengthWithValue:999];
                }
            }
            results[index] = valid;
        }
    });
    for (NSUInteger index = 0; index < count; index++) {
        XCTAssertTrue(results[index], @"Parser %lu", (unsigned long)index);
    }
    free(results);
}

- (void)testElementNameClassificationPreservesSupportedNames
{
    NSArray<NSString*>* names = [[NSArray alloc] initWithObjects:@"a", @"g", @"path", @"polygon", @"polyline", @"pattern", @"symbol", @"style", @"switch", @"stop", @"svg", @"defs", @"desc", @"rect", @"radialgradient", @"line", @"lineargradient", @"circle", @"clippath", @"ellipse", @"use", @"marker", @"mask", @"image", @"text", @"textpath", @"tspan", @"title", @"feBlend", @"feColorMatrix", @"feComponentTransfer", @"feComposite", @"feConvolveMatrix", @"feDiffuseLighting", @"feDisplacementMap", @"feFlood", @"feGaussianBlur", @"feImage", @"feMerge", @"feMorphology", @"feOffset", @"feSpecularLighting", @"feTile", @"feTurbulence", @"feMergeNode", @"feFuncR", @"feFuncG", @"feFuncB", @"feFuncA", @"feDistantLight", @"fePointLight", @"feSpotLight", @"feDropShadow", @"filter", @"foreignobject", nil];
    const IJSVGNodeType types[] = { IJSVGNodeTypeAnchor, IJSVGNodeTypeGroup, IJSVGNodeTypePath, IJSVGNodeTypePolygon, IJSVGNodeTypePolyline, IJSVGNodeTypePattern, IJSVGNodeTypeSymbol, IJSVGNodeTypeStyle, IJSVGNodeTypeSwitch, IJSVGNodeTypeStop, IJSVGNodeTypeSVG, IJSVGNodeTypeDef, IJSVGNodeTypeDesc, IJSVGNodeTypeRect, IJSVGNodeTypeRadialGradient, IJSVGNodeTypeLine, IJSVGNodeTypeLinearGradient, IJSVGNodeTypeCircle, IJSVGNodeTypeClipPath, IJSVGNodeTypeEllipse, IJSVGNodeTypeUse, IJSVGNodeTypeMarker, IJSVGNodeTypeMask, IJSVGNodeTypeImage, IJSVGNodeTypeText, IJSVGNodeTypeTextPath, IJSVGNodeTypeTextSpan, IJSVGNodeTypeTitle, IJSVGNodeTypeFilterBlend, IJSVGNodeTypeFilterColorMatrix, IJSVGNodeTypeFilterComponentTransfer, IJSVGNodeTypeFilterComposite, IJSVGNodeTypeFilterConvolveMatrix, IJSVGNodeTypeFilterDiffuseLighting, IJSVGNodeTypeFilterDisplacementMap, IJSVGNodeTypeFilterFlood, IJSVGNodeTypeFilterGaussianBlur, IJSVGNodeTypeFilterImage, IJSVGNodeTypeFilterMerge, IJSVGNodeTypeFilterMorphology, IJSVGNodeTypeFilterOffset, IJSVGNodeTypeFilterSpecularLighting, IJSVGNodeTypeFilterTile, IJSVGNodeTypeFilterTurbulence, IJSVGNodeTypeFilterMergeNode, IJSVGNodeTypeFilterFuncR, IJSVGNodeTypeFilterFuncG, IJSVGNodeTypeFilterFuncB, IJSVGNodeTypeFilterFuncA, IJSVGNodeTypeFilterDistantLight, IJSVGNodeTypeFilterPointLight, IJSVGNodeTypeFilterSpotLight, IJSVGNodeTypeFilterDropShadow, IJSVGNodeTypeFilter, IJSVGNodeTypeForeignObject };
    for (NSUInteger index = 0; index < names.count; index++) {
        NSString* name = names[index];
        XCTAssertEqual(IJSVGNodeTypeForString(name, NSXMLElementKind), types[index]);
        XCTAssertEqual(IJSVGNodeTypeForString(name.uppercaseString, NSXMLElementKind), types[index]);
        XCTAssertEqual(IJSVGNodeTypeForString([name stringByAppendingString:@"x"], NSXMLElementKind), IJSVGNodeTypeUnknown);
        XCTAssertEqual(IJSVGNodeTypeForString(name, NSXMLCommentKind), IJSVGNodeTypeNotFound);
        XCTAssertEqual([IJSVGNode typeForString:name kind:NSXMLElementKind], types[index]);
        XCTAssertEqual([IJSVGNode typeForString:name.uppercaseString kind:NSXMLElementKind], types[index]);
        XCTAssertEqual([IJSVGNode typeForString:[name stringByAppendingString:@"x"] kind:NSXMLElementKind], IJSVGNodeTypeUnknown);
        XCTAssertEqual([IJSVGNode typeForString:name kind:NSXMLCommentKind], IJSVGNodeTypeNotFound);
    }
    XCTAssertEqual(IJSVGNodeTypeForString(nil, NSXMLElementKind), IJSVGNodeTypeNotFound);
    XCTAssertEqual(IJSVGNodeTypeForString(@"", NSXMLElementKind), IJSVGNodeTypeUnknown);
    XCTAssertEqual(IJSVGNodeTypeForString(@"réct", NSXMLElementKind), IJSVGNodeTypeUnknown);
    XCTAssertEqual(IJSVGNodeTypeForString(@"feComponentTransferExtra", NSXMLElementKind), IJSVGNodeTypeUnknown);
    XCTAssertEqual([IJSVGNode typeForString:nil kind:NSXMLElementKind], IJSVGNodeTypeNotFound);
    XCTAssertEqual([IJSVGNode typeForString:@"" kind:NSXMLElementKind], IJSVGNodeTypeUnknown);
    XCTAssertEqual([IJSVGNode typeForString:@"réct" kind:NSXMLElementKind], IJSVGNodeTypeUnknown);
    XCTAssertEqual([IJSVGNode typeForString:@"feComponentTransferExtra" kind:NSXMLElementKind], IJSVGNodeTypeUnknown);
}

- (void)testCachedTransformsKeepSyntaxModesAndMutableParametersIndependent
{
    NSString* source = IJSVGTestSVG(@"<rect width='10' height='10' transform='translate(10,20)'/>"
                                     "<rect width='10' height='10' transform='translate(10,20)'/>"
                                     "<rect width='10' height='10' style='transform:translate(10px,20px)'/>"
                                     "<rect width='10' height='10' transform='translate(10px,20px)'/>"
                                     "<rect width='10' height='10' style='transform:translate(10px,20px)'/>"
                                     "<rect width='10' height='10' transform='translate(10px,20px)'/>");
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:nil];
    for (NSUInteger iteration = 0; iteration < 2; iteration++) {
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
        XCTAssertEqual(root.children.count, 6);
        if (root.children.count != 6) {
            continue;
        }
        IJSVGTransform* first = ((IJSVGGraphicsNode*)root.children[0]).transforms.firstObject;
        IJSVGTransform* second = ((IJSVGGraphicsNode*)root.children[1]).transforms.firstObject;
        XCTAssertNotNil(first);
        XCTAssertNotNil(second);
        XCTAssertNotEqual(first, second);
        XCTAssertEqual(first.CGAffineTransform.tx, 10);
        XCTAssertEqual(first.CGAffineTransform.ty, 20);
        CGFloat replacement[] = { 99, 88 };
        [first setParameters:replacement count:2];
        XCTAssertEqual(second.CGAffineTransform.tx, 10);
        XCTAssertEqual(second.CGAffineTransform.ty, 20);
        for (NSUInteger index = 2; index < 6; index++) {
            NSArray<IJSVGTransform*>* transforms = ((IJSVGGraphicsNode*)root.children[index]).transforms;
            XCTAssertEqual(transforms.count, index % 2 == 0 ? 1 : 0);
            if (index % 2 == 0) {
                XCTAssertEqual(transforms.firstObject.CGAffineTransform.tx, 10);
                XCTAssertEqual(transforms.firstObject.CGAffineTransform.ty, 20);
            }
        }
    }
}

- (void)testRepeatedHexColorsKeepStopOpacityAndPaintNodesIndependent
{
    NSString* source = IJSVGTestSVG(@"<defs><linearGradient id='g'>"
                                     "<stop stop-color='#123456' stop-opacity='.25'/>"
                                     "<stop offset='.5' stop-color='#123456' stop-opacity='.75'/>"
                                     "<stop offset='1' stop-color='#123456'/></linearGradient></defs>"
                                     "<rect width='10' height='10' fill='url(#g)'/>"
                                     "<rect width='10' height='10' fill='url(#g)'/>");
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:nil];
    for (NSUInteger iteration = 0; iteration < 2; iteration++) {
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
        IJSVGGradient* first = (IJSVGGradient*)((IJSVGGraphicsNode*)root.children.firstObject).fill;
        IJSVGGradient* second = (IJSVGGradient*)((IJSVGGraphicsNode*)root.children.lastObject).fill;
        XCTAssertEqual(first.children.count, 3);
        XCTAssertEqual(second.children.count, 3);
        if (first.children.count != 3 || second.children.count != 3) {
            continue;
        }
        CGFloat expected[] = { .25, .75, 1 };
        for (NSUInteger index = 0; index < 3; index++) {
            IJSVGColorNode* paint = (IJSVGColorNode*)((IJSVGGraphicsNode*)first.children[index]).fill;
            IJSVGColorNode* other = (IJSVGColorNode*)((IJSVGGraphicsNode*)second.children[index]).fill;
            XCTAssertNotEqual(paint, other);
            XCTAssertEqualWithAccuracy(paint.color.alphaComponent, expected[index], .0001);
            XCTAssertEqualWithAccuracy(other.color.alphaComponent, expected[index], .0001);
            paint.color = NSColor.clearColor;
            XCTAssertEqualWithAccuracy(other.color.alphaComponent, expected[index], .0001);
        }
    }
}

- (void)testRepeatedFilterAttributesRefreshWhenStylesChange
{
    NSString* shape = @"<rect width='10' height='10' filter='url(#f)'/>";
    NSString* body = [NSString stringWithFormat:@"<defs><filter id='f' x='-10%%'><feOffset "
                                                @"dx='1' dy='2'/></filter></defs>"
                                                 "%@%@%@<g><style>defs > filter > feOffset { "
                                                 "dx:9; dy:7 }</style>%@%@%@</g>",
        shape, shape, shape, shape, shape, shape];
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body) fileURL:nil error:nil];
    XCTAssertNotNil(parser);
    for (NSUInteger iteration = 0; iteration < 2; iteration++) {
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
        XCTAssertEqual(root.children.count, 4);
        if (root.children.count != 4) {
            continue;
        }
        for (NSUInteger index = 0; index < 3; index++) {
            IJSVGFilter* filter = ((IJSVGGraphicsNode*)root.children[index]).filters.firstObject;
            XCTAssertNotNil(filter);
            XCTAssertEqualObjects(filter.primitives.firstObject.parameters[@"dx"], @"1");
        }
        IJSVGGroup* group = (IJSVGGroup*)root.children.lastObject;
        XCTAssertEqual(group.children.count, 3);
        for (IJSVGGraphicsNode* shape in group.children) {
            IJSVGFilter* filter = shape.filters.firstObject;
            XCTAssertNotNil(filter);
            XCTAssertEqualObjects(filter.primitives.firstObject.parameters[@"dx"], @"9");
            XCTAssertEqualObjects(filter.primitives.firstObject.parameters[@"dy"], @"7");
        }
        IJSVGFilter* first = ((IJSVGGraphicsNode*)root.children[0]).filters.firstObject;
        IJSVGFilter* second = ((IJSVGGraphicsNode*)root.children[1]).filters.firstObject;
        XCTAssertNotEqual(first, second);
        XCTAssertNotEqual(first.primitives.firstObject, second.primitives.firstObject);
        first.x = [first.x lengthWithValue:5];
        first.primitives.firstObject.parameters = @{ @"dx" : @"99" };
        XCTAssertEqualWithAccuracy(second.x.value, -.1, .0001);
        XCTAssertEqualObjects(second.primitives.firstObject.parameters[@"dx"], @"1");
    }
}

- (void)testLinearGradientCoordinateDefaultsRemainIndependent
{
    for (NSString* attributes in @[ @"", @"x1='inherit' x2='invalid' y1='' y2='inherit'" ]) {
        for (NSString* units in @[ @"userSpaceOnUse", @"objectBoundingBox" ]) {
            NSString* source = IJSVGTestSVG([NSString stringWithFormat:@"<defs><linearGradient id='g' gradientUnits='%@' %@>"
                                                                        "<stop/><stop offset='1'/></linearGradient></defs>"
                                                                        "<rect width='10' height='10' fill='url(#g)'/>"
                                                                        "<rect width='10' height='10' fill='url(#g)'/>",
                units, attributes]);
            IJSVG* svg = [[IJSVG alloc] initWithSVGString:source];
            XCTAssertNotNil(svg);
            IJSVGGradient* first = (IJSVGGradient*)((IJSVGGraphicsNode*)svg.rootNode.children.firstObject).fill;
            IJSVGGradient* second = (IJSVGGradient*)((IJSVGGraphicsNode*)svg.rootNode.children.lastObject).fill;
            XCTAssertNotNil(first);
            XCTAssertNotNil(second);
            XCTAssertEqual(first.x1.value, 0);
            XCTAssertEqual(first.x2.value, 1);
            XCTAssertEqual(first.y1.value, 0);
            XCTAssertEqual(first.y2.value, 0);
            XCTAssertEqual(first.x1.originalType, IJSVGUnitLengthTypeNumber);
            XCTAssertEqual(first.x2.originalType, IJSVGUnitLengthTypePercentage);
            XCTAssertEqual(first.x1.type, [units isEqualToString:@"objectBoundingBox"] ? IJSVGUnitLengthTypePercentage : IJSVGUnitLengthTypeNumber);
            first.x1 = [first.x1 lengthWithValue:7];
            first.y1 = [first.y1 lengthWithValue:8];
            XCTAssertEqual(first.y2.value, 0);
            XCTAssertEqual(second.x1.value, 0);
        }
    }
}

- (void)testLinearGradientCoordinateScanKeepsUnitsAndAttributeNames
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:IJSVGTestSVG(@"<defs><linearGradient id='g' "
                                                               @"xmlns:other='urn:other' other:x1='99'"
                                                                " gradientUnits='userSpaceOnUse' y2='2in' "
                                                                "x2='75%' x1='-1e1' y1='2em'>"
                                                                "<stop/><stop offset='1'/></linearGradient></defs>"
                                                                "<rect width='10' height='10' fill='url(#g)'/>")];
    XCTAssertNotNil(svg);
    IJSVGGradient* gradient = (IJSVGGradient*)((IJSVGGraphicsNode*)svg.rootNode.children.firstObject).fill;
    XCTAssertNotNil(gradient);
    XCTAssertEqual(gradient.x1.value, -10);
    XCTAssertEqualWithAccuracy(gradient.x2.value, .75, .0001);
    XCTAssertEqual(gradient.x2.type, IJSVGUnitLengthTypePercentage);
    XCTAssertEqual(gradient.y1.value, 2);
    XCTAssertEqual(gradient.y1.type, IJSVGUnitLengthTypeEM);
    XCTAssertEqual(gradient.y2.value, 192);
    XCTAssertEqual(gradient.y2.originalType, IJSVGUnitLengthTypeIN);
}

- (void)testGradientAttributeIdentifiersPreserveQualifiedNames
{
    NSString* linearSource = @"<linearGradient xmlns:other='urn:other' other:x1='99' other:y1='99' x1='25%' x2='75%' y1='10%' y2='90%' other:spreadMethod='reflect' spreadMethod='repeat'/>";
    NSString* radialSource = @"<radialGradient xmlns:other='urn:other' other:cx='99' other:cy='99' other:r='99' other:fx='99' other:fy='99' other:fr='99' cx='25%' cy='35%' r='45%' fx='15%' fy='20%' fr='5%' other:spreadMethod='repeat' spreadMethod='reflect'/>";
    for (NSNumber* publicAPI in @[ @NO, @YES ]) {
        IJSVGLinearGradient* linear = nil;
        IJSVGRadialGradient* radial = nil;
        if (publicAPI.boolValue) {
            linear = [[IJSVGLinearGradient alloc] init];
            radial = [[IJSVGRadialGradient alloc] init];
            linear.units = radial.units = IJSVGUnitObjectBoundingBox;
            NSXMLElement* linearElement = [[NSXMLElement alloc] initWithXMLString:linearSource error:nil];
            NSXMLElement* radialElement = [[NSXMLElement alloc] initWithXMLString:radialSource error:nil];
            [IJSVGLinearGradient parseGradient:linearElement gradient:linear];
            [IJSVGRadialGradient parseGradient:radialElement gradient:radial];
        } else {
            NSString* body = [NSString stringWithFormat:@"<defs>%@%@</defs><rect width='10' height='10' fill='url(#linear)'/><rect width='10' height='10' fill='url(#radial)'/>", [linearSource stringByReplacingOccurrencesOfString:@"<linearGradient " withString:@"<linearGradient id='linear' "], [radialSource stringByReplacingOccurrencesOfString:@"<radialGradient " withString:@"<radialGradient id='radial' "]];
            IJSVG* svg = [[IJSVG alloc] initWithSVGString:IJSVGTestSVG(body)];
            XCTAssertNotNil(svg);
            linear = (IJSVGLinearGradient*)((IJSVGGraphicsNode*)svg.rootNode.children.firstObject).fill;
            radial = (IJSVGRadialGradient*)((IJSVGGraphicsNode*)svg.rootNode.children.lastObject).fill;
        }
        XCTAssertNotNil(linear);
        XCTAssertNotNil(radial);
        XCTAssertEqualWithAccuracy(linear.x1.value, .25, .0001);
        XCTAssertEqualWithAccuracy(linear.x2.value, .75, .0001);
        XCTAssertEqualWithAccuracy(linear.y1.value, .10, .0001);
        XCTAssertEqualWithAccuracy(linear.y2.value, .90, .0001);
        XCTAssertEqual(linear.spreadMethod, IJSVGGradientSpreadMethodRepeat);
        XCTAssertEqualWithAccuracy(radial.cx.value, .25, .0001);
        XCTAssertEqualWithAccuracy(radial.cy.value, .35, .0001);
        XCTAssertEqualWithAccuracy(radial.r.value, .45, .0001);
        XCTAssertEqualWithAccuracy(radial.fx.value, .15, .0001);
        XCTAssertEqualWithAccuracy(radial.fy.value, .20, .0001);
        XCTAssertEqualWithAccuracy(radial.fr.value, .05, .0001);
        XCTAssertEqual(radial.spreadMethod, IJSVGGradientSpreadMethodReflect);
    }
}

- (void)testGradientSpreadMethodKeepsExactKeywords
{
    NSArray<NSString*>* values = @[ @"reflect", @"repeat", @"pad", @"Repeat", @"repeatExtra", @" repeat", @"reflect " ];
    for (NSUInteger index = 0; index < values.count; index++) {
        NSString* source = [NSString stringWithFormat:@"<linearGradient xmlns:other='urn:other' other:spreadMethod='repeat' spreadMethod='%@'/>", values[index]];
        NSXMLElement* element = [[NSXMLElement alloc] initWithXMLString:source error:nil];
        IJSVGLinearGradient* gradient = [[IJSVGLinearGradient alloc] init];
        [IJSVGLinearGradient parseGradient:element gradient:gradient];
        IJSVGGradientSpreadMethod expected = index == 0 ? IJSVGGradientSpreadMethodReflect : index == 1 ? IJSVGGradientSpreadMethodRepeat
                                                                                                        : IJSVGGradientSpreadMethodPad;
        XCTAssertEqual(gradient.spreadMethod, expected, @"%@", values[index]);
    }
    NSXMLElement* element = [[NSXMLElement alloc] initWithXMLString:@"<linearGradient xmlns:other='urn:other' other:spreadMethod='repeat'/>" error:nil];
    IJSVGLinearGradient* gradient = [[IJSVGLinearGradient alloc] init];
    [IJSVGLinearGradient parseGradient:element gradient:gradient];
    XCTAssertEqual(gradient.spreadMethod, IJSVGGradientSpreadMethodPad);
}

- (void)testSingleRuleMatchingKeepsSelectorContextAndAdditionalRules
{
    IJSVGGroup* group = IJSVGTestGroup(@"container", @[]);
    IJSVGNode* circle = IJSVGTestNode(@"circle", nil, @[]);
    IJSVGNode* rect = IJSVGTestNode(@"rect", @"target", @[ @"item" ]);
    [group addChild:circle];
    [group addChild:rect];

    IJSVGStyleSheet* sheet = IJSVGTestStyleSheet(@"#missing, g > circle + rect.item { opacity: .4 }");
    XCTAssertNil([sheet styleForNode:circle]);
    XCTAssertEqualObjects([[sheet styleForNode:rect] property:@"opacity"], @".4");
    [rect detach];
    XCTAssertNil([sheet styleForNode:rect]);
    [group addChild:rect];
    XCTAssertEqualObjects([[sheet styleForNode:rect] property:@"opacity"], @".4");

    [sheet parseStyleBlock:@"#target { opacity: .8 }"];
    XCTAssertEqualObjects([[sheet styleForNode:rect] property:@"opacity"], @".8");
}

- (void)testRepeatedStyleDiscoveryDoesNotDuplicateRulesAcrossParses
{
    NSString* source = IJSVGTestSVG(@"<defs><style>* { stroke-width: 7 }</style></defs>"
                                     "<rect width='3' height='4'/>");
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:nil];
    XCTAssertNotNil(parser);
    for (NSUInteger iteration = 0; iteration < 2; iteration++) {
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
        XCTAssertEqual(root.children.count, 1);
        XCTAssertEqual(((IJSVGGraphicsNode*)root.children.firstObject).strokeWidth.value, 7);
        IJSVGStyleSheet* sheet = [parser valueForKey:@"styleSheet"];
        XCTAssertEqual(sheet.ruleCount, 1);
    }
}

- (void)testStyleDiscoveryPreservesInterleavedBlockPrecedence
{
    NSArray<NSString*>* bodies = @[
        (@"<defs><style>rect { stroke-width: 2 }</style></defs>"
          "<style>rect { stroke-width: 5 }</style><rect width='3' height='4'/>"),
        (@"<defs><style>rect { stroke-width: 5 }</style>"
          "<style>rect { stroke-width: 2 }</style>"
          "<style>rect { stroke-width: 5 }</style></defs>"
          "<rect width='3' height='4'/>")
    ];
    for (NSString* body in bodies) {
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGTestSVG(body) fileURL:nil error:nil];
        XCTAssertNotNil(parser);
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
        XCTAssertEqual(root.children.count, 1);
        XCTAssertEqual(((IJSVGGraphicsNode*)root.children.firstObject).strokeWidth.value, 5);
    }
}

- (void)testNodeDefaultsKeepIndependentReplacements
{
    IJSVGPath* first = [[IJSVGPath alloc] init];
    IJSVGPath* second = [[IJSVGPath alloc] init];
    first.fillOpacity = [first.fillOpacity lengthWithValue:.25];
    first.strokeOpacity = [first.strokeOpacity lengthWithInheritance:NO];
    first.strokeWidth = [first.strokeWidth lengthWithValue:7];
    first.strokeDashOffset = [first.strokeDashOffset lengthWithValue:3];
    XCTAssertEqual(second.fillOpacity.value, 1);
    XCTAssertTrue(second.fillOpacity.inherit);
    XCTAssertTrue(second.strokeOpacity.inherit);
    XCTAssertEqual(second.strokeWidth.value, 1);
    XCTAssertEqual(second.strokeDashOffset.value, 0);
    XCTAssertEqual(first.opacity.value, 1);
    XCTAssertFalse(first.opacity.inherit);
    XCTAssertNotEqual(first.path, NULL);

    IJSVGMask* mask = [[IJSVGMask alloc] init];
    XCTAssertEqual(mask.units, IJSVGUnitObjectBoundingBox);
    XCTAssertEqual(mask.contentUnits, IJSVGUnitUserSpaceOnUse);
    XCTAssertEqual(mask.overflowVisibility, IJSVGOverflowVisibilityHidden);
    XCTAssertEqual(mask.width.type, IJSVGUnitLengthTypePercentage);
    XCTAssertEqualWithAccuracy(mask.width.value, 1.2, .0001);
}

- (void)testDeferredNodeDefaultsPreserveExplicitNilAndInheritance
{
    IJSVGGraphicsNode* parent = [[IJSVGGraphicsNode alloc] init];
    IJSVGGraphicsNode* child = [[IJSVGGraphicsNode alloc] init];
    child.parentNode = parent;
    parent.strokeWidth = [parent.strokeWidth lengthWithValue:8];
    XCTAssertEqual(child.strokeWidth, parent.strokeWidth);
    child.parentNode = nil;
    XCTAssertEqual(child.strokeWidth.value, 1);
    XCTAssertTrue(child.strokeWidth.inherit);

    IJSVGGraphicsNode* cleared = [[IJSVGGraphicsNode alloc] init];
    cleared.opacity = nil;
    cleared.fillOpacity = nil;
    cleared.strokeOpacity = nil;
    cleared.strokeWidth = nil;
    cleared.strokeDashOffset = nil;
    XCTAssertNil(cleared.opacity);
    XCTAssertNil(cleared.fillOpacity);
    XCTAssertNil(cleared.strokeOpacity);
    XCTAssertNil(cleared.strokeWidth);
    XCTAssertNil(cleared.strokeDashOffset);
    cleared.parentNode = parent;
    XCTAssertNil(cleared.strokeWidth);
    XCTAssertEqual(cleared.strokeDashOffset, parent.strokeDashOffset);

    IJSVGGraphicsNode* assigned = [[IJSVGGraphicsNode alloc] init];
    IJSVGUnitLength* width = [IJSVGUnitLength unitWithFloat:5];
    assigned.strokeWidth = width;
    XCTAssertEqual(assigned.strokeWidth, width);
    assigned.parentNode = parent;
    XCTAssertEqual(assigned.strokeWidth, width);
}

- (void)testDefinitionIdentifiersKeepNamespaceAndStyleScope
{
    NSString* source = IJSVGTestSVG(@"<defs xmlns:other='urn:other'><g>"
                                     "<style>#shape { opacity: .4 }</style>"
                                     "<rect other:id='decoy' width='3' id='shape' height='4'/>"
                                     "<rect id='形状' width='5' height='6'/>"
                                     "</g></defs><use href='#shape'/><use href='#形状'/>");
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:nil];
    XCTAssertNotNil(parser);
    IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
    XCTAssertEqual(root.children.count, 2);
    if (root.children.count != 2) {
        return;
    }
    IJSVGGroup* first = (IJSVGGroup*)root.children[0];
    IJSVGGroup* second = (IJSVGGroup*)root.children[1];
    IJSVGGraphicsNode* shape = (IJSVGGraphicsNode*)first.children.firstObject;
    IJSVGGraphicsNode* unicodeShape = (IJSVGGraphicsNode*)second.children.firstObject;
    XCTAssertNotNil(shape);
    XCTAssertNotNil(unicodeShape);
    XCTAssertEqualWithAccuracy(shape.opacity.value, .4, .0001);
    XCTAssertNotNil(shape.width);
    XCTAssertNotNil(shape.height);
    XCTAssertNotNil(unicodeShape.width);
    XCTAssertNotNil(unicodeShape.height);
    XCTAssertEqualWithAccuracy(shape.width.value, 3, .0001);
    XCTAssertEqualWithAccuracy(shape.height.value, 4, .0001);
    XCTAssertEqualWithAccuracy(unicodeShape.width.value, 5, .0001);
    XCTAssertEqualWithAccuracy(unicodeShape.height.value, 6, .0001);
}

- (void)testCachedStyleAttributesPreserveCascadeAfterEdits
{
    IJSVGStyleSheetStyle* sheet = [IJSVGStyleSheetStyle parseStyleString:@"fill:red!important;stroke:blue"];
    IJSVGStyleSheetStyle* inlineStyle = [IJSVGStyleSheetStyle parseStyleString:@"fill:green;stroke:orange"];
    IJSVGBitFlags* allowed = [IJSVGPath computedAllowedAttributes];
    for (NSString* color in @[ @"red", @"purple" ]) {
        [sheet setResolvedValue:color forProperty:@"fill" important:YES];
        NSString* __unsafe_unretained values[kIJSVGNodeAttributeStorageLength] = { nil };
        IJSVGStoreCascadedStyleAttributes(sheet, inlineStyle, allowed, values);
        XCTAssertEqualObjects(values[IJSVGNodeAttributeFill], color);
        XCTAssertEqualObjects(values[IJSVGNodeAttributeStroke], @"orange");
    }
    [inlineStyle setPropertyValue:@"yellow!important" forProperty:@"fill"];
    [inlineStyle setResolvedValue:nil forProperty:@"stroke" important:NO];
    NSString* __unsafe_unretained values[kIJSVGNodeAttributeStorageLength] = { nil };
    IJSVGStoreCascadedStyleAttributes(sheet, inlineStyle, allowed, values);
    XCTAssertEqualObjects(values[IJSVGNodeAttributeFill], @"yellow");
    XCTAssertEqualObjects(values[IJSVGNodeAttributeStroke], @"blue");
}

- (void)testCachedStyleAttributesKeepMutableValueSemantics
{
    IJSVGStyleSheetStyle* style = [[IJSVGStyleSheetStyle alloc] init];
    NSMutableString* color = [[NSMutableString alloc] init];
    [style setResolvedValue:color forProperty:@"fill" important:NO];
    for (NSString* value in @[ @"", @"blue", @"" ]) {
        [color setString:value];
        NSString* __unsafe_unretained values[kIJSVGNodeAttributeStorageLength] = { nil };
        IJSVGStoreStyleAttributes(style, [IJSVGPath computedAllowedAttributes], values);
        XCTAssertEqualObjects(values[IJSVGNodeAttributeFill], value.length == 0 ? nil : value);
    }
}

- (void)testGeometryPropertySummaryTracksStyleMutation
{
    IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleString:@"fill:red"];
    XCTAssertFalse(style.hasGeometryProperties);
    [style setPropertyValue:@"25%" forProperty:@"width"];
    XCTAssertTrue(style.hasGeometryProperties);
    [style setResolvedValue:nil forProperty:@"width" important:NO];
    XCTAssertFalse(style.hasGeometryProperties);
    [style setPropertyValue:@"10 !important" forProperty:@"x"];
    XCTAssertTrue(style.hasGeometryProperties);
    [style setResolvedValue:nil forProperty:@"x" important:NO];
    XCTAssertTrue(style.hasGeometryProperties);
    [style setResolvedValue:nil forProperty:@"x" important:YES];
    XCTAssertFalse(style.hasGeometryProperties);
    IJSVGStyleSheetStyle* other = [IJSVGStyleSheetStyle parseStyleString:@"r:12"];
    [style addPropertiesFromStyle:other];
    XCTAssertTrue(style.hasGeometryProperties);
}

- (void)testGeometryStylesStillInheritThroughGroups
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100' "
                                                  @"viewBox='0 0 100 100'>"
                                                   "<style>*{stroke-linejoin:round} "
                                                   "rect{width:inherit;height:inherit}</style>"
                                                   "<g style='width:30px;height:20px'><rect x='10' y='15'/></g></svg>"];
    CGPathRef path = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    XCTAssertTrue(path != NULL);
    if (path != NULL) {
        CGRect bounds = CGPathGetPathBoundingBox(path);
        XCTAssertEqualWithAccuracy(bounds.origin.x, 10, .001);
        XCTAssertEqualWithAccuracy(bounds.origin.y, 15, .001);
        XCTAssertEqualWithAccuracy(bounds.size.width, 30, .001);
        XCTAssertEqualWithAccuracy(bounds.size.height, 20, .001);
    }
}

- (void)testCascadeKeepsImportanceSpecificityAndSourceOrder
{
    IJSVGStyleSheet* sheet = IJSVGTestStyleSheet(@"#target { fill: red; stroke: red !important; opacity: .2 }"
                                                  ".item { fill: blue !important; stroke: blue !important; opacity: .5 }"
                                                  "rect, #target { opacity: .8; font: italic 20px Helvetica }"
                                                  "rect { fill: green; font-size: 10px }"
                                                  ".item { fill: purple !important }");
    IJSVGNode* node = IJSVGTestNode(@"rect", @"target", @[ @"item" ]);
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
    IJSVGNode* node = IJSVGTestNode(@"rect", @"target", @[ @"item" ]);
    NSArray<NSString*>* selectors = @[ @"rect", @".item", @"#target", @"rect, #missing" ];
    NSArray<NSNumber*>* specificities = @[ @1, @10, @100, @1 ];
    for (NSUInteger seed = 0; seed < 8; seed++) {
        IJSVGStyleSheet* sheet = [[IJSVGStyleSheet alloc] init];
        NSMutableArray<NSDictionary<NSString*, id>*>* rules = [[NSMutableArray alloc] init];
        for (NSUInteger index = 0; index < 96; index++) {
            NSUInteger selectorIndex = (index * 7 + seed) % selectors.count;
            NSString* important = (index + seed) % 5 == 0 ? @" !important" : @"";
            NSString* declaration = [NSString stringWithFormat:@"fill: rgb(%lu, 20, 30)%@; custom-value: %lu; "
                                                               @"stroke-width: %lu%@",
                index, important, index, index % 7 + 1, important];
            [sheet parseStyleBlock:[NSString stringWithFormat:@"%@ { %@ }", selectors[selectorIndex], declaration]];
            [rules addObject:@{ @"specificity" : specificities[selectorIndex], @"index" : @(index), @"declaration" : declaration }];
        }
        [rules sortUsingComparator:^NSComparisonResult(NSDictionary<NSString*, id>* first, NSDictionary<NSString*, id>* second) {
            NSComparisonResult order = [first[@"specificity"] compare:second[@"specificity"]];
            return order != NSOrderedSame ? order : [first[@"index"] compare:second[@"index"]];
        }];
        IJSVGStyleSheetStyle* expected = [[IJSVGStyleSheetStyle alloc] init];
        for (NSDictionary<NSString*, id>* rule in rules) {
            [expected addPropertiesFromStyle:[IJSVGStyleSheetStyle parseStyleString:rule[@"declaration"]]];
        }
        IJSVGStyleSheetStyle* actual = [sheet styleForNode:node];
        XCTAssertNotNil(actual);
        XCTAssertEqualObjects(actual.properties, expected.properties, @"Seed %lu", seed);
    }
}

- (void)testSelectorRecordsPreserveXMLSiblingsAndReferenceScope
{
    NSString* svg = IJSVGTestSVG(@"<style>defs > g > rect { opacity: .1 }"
                                  "g > rect + rect { opacity: .6 } circle ~ rect { stroke-width: 7 "
                                  "}</style>"
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
    for (IJSVGGroup* use in root.children) {
        XCTAssertTrue([use isKindOfClass:IJSVGGroup.class]);
        IJSVGGroup* group = (IJSVGGroup*)use.children.firstObject;
        XCTAssertTrue([group isKindOfClass:IJSVGGroup.class]);
        XCTAssertEqual(group.children.count, 4);
        if (group.children.count != 4) {
            continue;
        }
        IJSVGGraphicsNode* adjacent = (IJSVGGraphicsNode*)group.children[2];
        XCTAssertEqualWithAccuracy(adjacent.opacity.value, .6, .001);
        XCTAssertEqual(adjacent.strokeWidth.value, 7);
        XCTAssertEqual(((IJSVGGraphicsNode*)group.children[1]).opacity.value, 1);
        XCTAssertEqual(((IJSVGGraphicsNode*)group.children[3]).opacity.value, 1);
    }
}

- (void)testRepeatedRawAttributesKeepInstanceInheritance
{
    NSString* svg = IJSVGTestSVG(@"<defs><g id='shape'><rect class='item detail' width='3' "
                                 @"height='4' fill='inherit'/></g></defs>"
                                  "<use href='#shape' fill='red' stroke-width='2'/>"
                                  "<use href='#shape' fill='blue' stroke-width='9'/>"
                                  "<use href='#shape' fill='green' stroke-width='4'/>");
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:svg fileURL:nil error:&error];
    XCTAssertNotNil(parser);
    XCTAssertNil(error);

    // Parse twice to check that each parse starts with an empty cache.
    for (NSUInteger iteration = 0; iteration < 2; iteration++) {
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
        NSMutableArray<IJSVGGraphicsNode*>* paths = [[NSMutableArray alloc] init];
        for (IJSVGGroup* use in root.children) {
            IJSVGGroup* group = (IJSVGGroup*)use.children.firstObject;
            IJSVGGraphicsNode* path = (IJSVGGraphicsNode*)group.children.firstObject;
            XCTAssertNotNil(path);
            if (path != nil) {
                [paths addObject:path];
            }
        }
        XCTAssertEqual(paths.count, 3);
        if (paths.count != 3) {
            continue;
        }
        XCTAssertNotEqual(paths[0], paths[1]);
        XCTAssertEqual(paths[0].strokeWidth.value, 2);
        XCTAssertEqual(paths[1].strokeWidth.value, 9);
        XCTAssertEqual(paths[2].strokeWidth.value, 4);
        for (IJSVGGraphicsNode* path in paths) {
            XCTAssertEqualObjects(path.classNameList, ([NSSet setWithArray:@[ @"item", @"detail" ]]));
        }
        XCTAssertNotEqual(paths[0].fill, paths[1].fill);
    }
}

- (void)testClassWhitespaceMatchesAcrossNormalCachedAndSelectorRecords
{
    for (NSString* selector in @[ @".item.detail.extra", @"g > .item.detail.extra" ]) {
        NSString* rect = @"<rect class=' item&#x9;detail&#xA;extra&#xD; ' "
                         @"width='3' height='4'/>";
        NSString* svg = IJSVGTestSVG([NSString stringWithFormat:@"<style>%@ { opacity: .6 }</style><g>%@</g>"
                                                                 "<defs><g id='shape'>%@</g></defs>"
                                                                 "<use href='#shape'/><use href='#shape'/><use href='#shape'/>",
            selector, rect, rect]);
        NSError* error = nil;
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:svg fileURL:nil error:&error];
        XCTAssertNotNil(parser);
        XCTAssertNil(error);
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
        XCTAssertEqual(root.children.count, 4);
        for (IJSVGGroup* group in root.children) {
            IJSVGGraphicsNode* node = (IJSVGGraphicsNode*)group.children.firstObject;
            if ([node isKindOfClass:IJSVGGroup.class]) {
                node = (IJSVGGraphicsNode*)((IJSVGGroup*)node).children.firstObject;
            }
            XCTAssertNotNil(node);
            XCTAssertEqualObjects(node.classNameList, ([NSSet setWithArray:@[ @"item", @"detail", @"extra" ]]));
            XCTAssertEqualWithAccuracy(node.opacity.value, .6, .001, @"Selector %@", selector);
        }
    }
}

- (void)testRepeatedReferenceLookupPreservesCompetingNamespaces
{
    NSString* source = IJSVGTestSVG(@"<defs><rect id='first' width='3' height='4'/>"
                                     "<rect id='second' width='7' height='8'/>"
                                     "<g id='batch' xmlns:link='http://www.w3.org/1999/xlink' "
                                     "xmlns:other='urn:other' xmlns:xlink='urn:legacy'>"
                                     "<use xlink:href='#first' link:href='#second'/>"
                                     "<use link:href='#second' xlink:href='#first'/>"
                                     "<use href='' xlink:href='#first' link:href='#second'/>"
                                     "<use other:href='#second' xlink:href='#first'/>"
                                     "<use href='#first' xlink:href='#second' link:href='#second'/>"
                                     "<use link:href='#' xlink:href='#first'/>"
                                     "<use xmlns:link='urn:shadowed' link:href='#second'/>"
                                     "<use xmlns:link='urn:shadowed' "
                                     "xmlns:local='http://www.w3.org/1999/xlink' "
                                     "link:href='#first' local:href='#second'/></g></defs>"
                                     "<use href='#batch'/><use href='#batch'/>");
    IJSVG* svg = IJSVGTestSVGObject(source);
    XCTAssertEqual(svg.rootNode.children.count, 2u);
    const CGFloat widths[] = { 7, 7, 0, 3, 3, 0, 0, 7 };
    const NSUInteger count = sizeof(widths) / sizeof(widths[0]);
    for (IJSVGUse* instance in svg.rootNode.children) {
        IJSVGGroup* group = (IJSVGGroup*)instance.children.firstObject;
        XCTAssertEqual(group.children.count, count);
        if (group.children.count != count) {
            continue;
        }
        for (NSUInteger index = 0; index < count; index++) {
            IJSVGUse* use = (IJSVGUse*)group.children[index];
            XCTAssertEqual(use.children.count, widths[index] == 0 ? 0u : 1u);
            if (widths[index] != 0) {
                IJSVGRect* rectangle = (IJSVGRect*)use.children.firstObject;
                XCTAssertEqual(rectangle.width.value, widths[index]);
            }
        }
    }
}

@end
