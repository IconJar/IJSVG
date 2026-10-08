//
//  IJSVGNodeAndColorStorageTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTestHelpers.h>
#import <IJSVG/IJSVGImage.h>
#import <IJSVG/IJSVGForeignObject.h>
#import <IJSVG/IJSVGRadialGradient.h>
#import <IJSVG/IJSVGTraitedColor.h>
#import <IJSVG/IJSVGTraitedColorStorage.h>

@interface IJSVGNodeAndColorStorageTests: XCTestCase
@end

@implementation IJSVGNodeAndColorStorageTests

- (void)testRootCopyPreservesSizingAndChildren
{
    IJSVGRootNode* original = [[IJSVGRootNode alloc] init];
    original.clientSize = CGSizeMake(80, 60);
    original.intrinsicSize = [IJSVGUnitSize sizeWithCGSize:CGSizeMake(80, 60)];
    original.intrinsicDimensions = IJSVGIntrinsicDimensionBoth;
    original.viewBox = [IJSVGUnitRect rectWithCGRect:CGRectMake(0, 0, 40, 30)];
    IJSVGNode* ancestor = [[IJSVGNode alloc] init];
    original.styleAncestors = @[ancestor];
    [original addChild:[self imageCopyTestNode]];
    IJSVGRootNode* copy = original.copy;

    XCTAssertTrue(CGSizeEqualToSize(copy.clientSize, original.clientSize));
    XCTAssertEqual(copy.intrinsicDimensions, IJSVGIntrinsicDimensionBoth);
    XCTAssertNotNil(copy.intrinsicSize);
    XCTAssertNotEqual(copy.intrinsicSize, original.intrinsicSize);
    XCTAssertTrue(CGSizeEqualToSize([copy.intrinsicSize computeValue:CGSizeZero],
                                   CGSizeMake(80, 60)));
    XCTAssertTrue(CGRectEqualToRect(copy.bounds, original.bounds));
    XCTAssertEqualObjects(copy.styleAncestors, original.styleAncestors);
    XCTAssertEqual(copy.children.count, 1u);
    XCTAssertNotEqual(copy.children.firstObject, original.children.firstObject);
    XCTAssertEqual(copy.children.firstObject.parentNode, copy);
    IJSVG* svg = [[IJSVG alloc] initWithRootNode:copy];
    XCTAssertTrue(CGSizeEqualToSize(svg.size, CGSizeMake(80, 60)));
}

- (void)testColorCopyPreservesSuperclassStateAndNoneFlag
{
    IJSVGColorNode* original = [[IJSVGColorNode alloc] initWithColor:
        [NSColor colorWithDeviceRed:1 green:0 blue:0 alpha:1]];
    original.identifier = @"paint";
    original.opacity = [IJSVGUnitLength unitWithFloat:0.4];
    IJSVGColorNode* copy = original.copy;
    XCTAssertEqual(copy.color, original.color);
    XCTAssertEqualObjects(copy.identifier, @"paint");
    XCTAssertEqual(copy.opacity.value, 0.4);
    XCTAssertTrue(copy.shouldRender);
    XCTAssertTrue([copy matchesTraits:IJSVGNodeTraitPaintable]);
    XCTAssertFalse(copy.isNoneOrTransparent);

    original.color = nil;
    original.isNoneOrTransparent = YES;
    original.shouldRender = NO;
    copy = original.copy;
    XCTAssertNil(copy.color);
    XCTAssertTrue(copy.isNoneOrTransparent);
    XCTAssertFalse(copy.shouldRender);
    XCTAssertEqual([copy colorsWithStyle:nil matchingTraits:IJSVGColorUsageTraitFill].count, 0u);
    // A copied color must still be accepted as a fill by the node's trait check.
    IJSVGPath* path = [[IJSVGPath alloc] init];
    XCTAssertNoThrow(path.fill = copy);
}

- (void)testPathCopyPreservesTraitsBeforeAndAfterComputation
{
    for(NSNumber* computeFirst in @[@NO, @YES]) {
        IJSVGPath* original = [[IJSVGPath alloc] init];
        original.stroke = [[IJSVGColorNode alloc] initWithColor:
            [NSColor colorWithDeviceRed:1 green:0 blue:0 alpha:1]];
        [original addTraits:IJSVGNodeTraitPaintable];
        if(computeFirst.boolValue) {
            XCTAssertTrue([original matchesTraits:IJSVGNodeTraitStroked]);
        }
        IJSVGPath* copy = original.copy;
        XCTAssertTrue([copy matchesTraits:IJSVGNodeTraitPathed |
                                         IJSVGNodeTraitPaintable |
                                         IJSVGNodeTraitStroked]);
        IJSVGGroup* group = [[IJSVGGroup alloc] init];
        [group addChild:copy];
        XCTAssertEqual([group nodesMatchingTraits:IJSVGNodeTraitPathed].count, 1u);
    }
    IJSVGNode* original = [[IJSVGNode alloc] init];
    [original addTraits:IJSVGNodeTraitPaintable | IJSVGNodeTraitPathed];
    [original removeTraits:IJSVGNodeTraitPathed];
    IJSVGNode* copy = original.copy;
    XCTAssertTrue([copy matchesTraits:IJSVGNodeTraitPaintable]);
    XCTAssertFalse([copy matchesTraits:IJSVGNodeTraitPathed]);
}

- (void)testStopCopyPreservesOffset
{
    IJSVGStop* original = [[IJSVGStop alloc] init];
    original.type = IJSVGNodeTypeStop;
    original.offset = [IJSVGUnitLength unitWithFloat:0.75];
    original.fillOpacity = [IJSVGUnitLength unitWithFloat:0.5];
    IJSVGStop* copy = original.copy;
    XCTAssertNotNil(copy.offset);
    XCTAssertEqual(copy.offset.value, 0.75);
    XCTAssertEqual(copy.fillOpacity.value, 0.5);
    XCTAssertEqual(copy.type, IJSVGNodeTypeStop);
    XCTAssertNotEqual(copy.offset, original.offset);
    original.offset.value = 0.25;
    XCTAssertEqual(copy.offset.value, 0.75);
}

- (void)testGradientCopyPreservesStopTreeAndCachedData
{
    for(Class gradientClass in @[IJSVGLinearGradient.class, IJSVGRadialGradient.class]) {
        IJSVGGradient* copy = nil;
        __weak IJSVGGradient* weakOriginal = nil;
        @autoreleasepool {
            IJSVGGradient* original = [[gradientClass alloc] init];
            weakOriginal = original;
            NSArray<NSColor*>* colors = @[
                [NSColor colorWithDeviceRed:1 green:0 blue:0 alpha:1],
                [NSColor colorWithDeviceRed:0 green:0 blue:1 alpha:1]
            ];
            for(NSUInteger index = 0; index < colors.count; index++) {
                IJSVGStop* stop = [[IJSVGStop alloc] init];
                stop.type = IJSVGNodeTypeStop;
                stop.offset = [IJSVGUnitLength unitWithFloat:index == 0 ? 0.25 : 0.75];
                stop.fill = [[IJSVGColorNode alloc] initWithColor:colors[index]];
                [original addChild:stop];
            }
            original.colors = colors;
            original.numberOfStops = 2;
            CGFloat* locations = malloc(2 * sizeof(CGFloat));
            locations[0] = 0.25;
            locations[1] = 0.75;
            original.locations = locations;
            XCTAssertTrue(original.CGGradient != NULL);
            copy = original.copy;
            XCTAssertEqual(copy.class, gradientClass);
            XCTAssertEqual(original.children.count, 2u);
            XCTAssertEqual(copy.children.count, 2u);
            XCTAssertEqualObjects(copy.colors, original.colors);
            XCTAssertEqual(copy.numberOfStops, 2u);
            XCTAssertTrue(copy.locations != NULL);
            XCTAssertNotEqual(copy.locations, original.locations);
            if(copy.children.count != 2 || copy.locations == NULL) continue;
            for(NSUInteger index = 0; index < 2; index++) {
                IJSVGNode* child = copy.children[index];
                XCTAssertNotEqual(child, original.children[index]);
                XCTAssertEqual(child.parentNode, copy);
                XCTAssertEqual(original.children[index].parentNode, original);
                XCTAssertEqual(child.offset.value, original.children[index].offset.value);
                XCTAssertEqual(copy.locations[index], original.locations[index]);
            }
        }
        XCTAssertNil(weakOriginal);
        XCTAssertTrue(copy.CGGradient != NULL);
        NSArray* rebuiltColors = nil;
        CGFloat* rebuiltLocations = [IJSVGGradient computeColorStops:copy colors:&rebuiltColors];
        XCTAssertEqualObjects(rebuiltColors, copy.colors);
        XCTAssertTrue(rebuiltLocations != NULL);
        if(rebuiltLocations != NULL) {
            if(rebuiltColors.count == 2) {
                XCTAssertEqual(rebuiltLocations[0], 0.25);
                XCTAssertEqual(rebuiltLocations[1], 0.75);
            }
            free(rebuiltLocations);
        }
    }
}

- (void)testForeignObjectCopyPreservesRequiredExtension
{
    IJSVGForeignObject* original = [[IJSVGForeignObject alloc] init];
    original.requiredExtension = @"http://www.w3.org/1999/xhtml";
    original.identifier = @"foreign";
    IJSVGForeignObject* copy = original.copy;
    XCTAssertEqualObjects(copy.requiredExtension, original.requiredExtension);
    XCTAssertEqualObjects(copy.identifier, original.identifier);
    XCTAssertTrue(copy.shouldRender);
}

- (void)testPathCopyPreservesLastControlPoint
{
    IJSVGPath* original = [[IJSVGPath alloc] init];
    original.lastControlPoint = CGPointMake(12, 34);
    IJSVGPath* copy = original.copy;
    XCTAssertTrue(CGPointEqualToPoint(copy.lastControlPoint, original.lastControlPoint));
}

- (NSBitmapImageRep*)imageCopyTestBitmap
{
    NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:4
                      pixelsHigh:2
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSDeviceRGBColorSpace
                     bytesPerRow:16
                    bitsPerPixel:32];
    XCTAssertNotNil(bitmap);
    if(bitmap == nil) return nil;
    // Explicit RGBA bytes avoid NSColor conversion changing the fixture pixels.
    for(NSUInteger y = 0; y < 2; y++) {
        for(NSUInteger x = 0; x < 4; x++) {
            unsigned char* pixel = bitmap.bitmapData + y * bitmap.bytesPerRow + x * 4;
            pixel[0] = 255;
            pixel[1] = 0;
            pixel[2] = 0;
            pixel[3] = 255;
        }
    }
    return bitmap;
}

- (IJSVGImage*)imageCopyTestNode
{
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(4, 2)];
    [image addRepresentation:[self imageCopyTestBitmap]];
    IJSVGImage* node = [[IJSVGImage alloc] init];
    node.type = IJSVGNodeTypeImage;
    node.image = image;
    node.width = [IJSVGUnitLength unitWithFloat:4.f];
    node.height = [IJSVGUnitLength unitWithFloat:2.f];
    return node;
}

- (void)assertImageCopyNodeRenders:(IJSVGNode*)node
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='4' height='2' viewBox='0 0 4 2'/>"];
    [svg.rootNode addChild:node];
    unsigned char pixels[4 * 2 * 4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(pixels, 4, 2, 8, 16, space,
        (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) return;
    [svg drawInRect:CGRectMake(0, 0, 4, 2) context:context];
    CGContextRelease(context);
    for(NSUInteger index = 0; index < sizeof(pixels); index += 4) {
        XCTAssertEqual(pixels[index], 255);
        XCTAssertEqual(pixels[index + 1], 0);
        XCTAssertEqual(pixels[index + 2], 0);
        XCTAssertEqual(pixels[index + 3], 255);
    }
}

- (void)testImagePropertyCopyPreservesImageAndNodeState
{
    IJSVGImage* original = [self imageCopyTestNode];
    original.identifier = @"bitmap";
    original.x = [IJSVGUnitLength unitWithFloat:3.f];
    original.y = [IJSVGUnitLength unitWithFloat:5.f];
    original.opacity = [IJSVGUnitLength unitWithFloat:0.5f];
    // The node's cached intrinsic dimensions must survive even if NSImage changes.
    original.image.size = NSMakeSize(8, 6);
    IJSVGImage* copy = original.copy;

    XCTAssertNotEqual(copy, original);
    XCTAssertEqual(copy.image, original.image);
    XCTAssertTrue(copy.CGImage != NULL);
    XCTAssertEqual(copy.CGImage, original.CGImage);
    XCTAssertTrue(CGSizeEqualToSize(copy.intrinsicSize, CGSizeMake(4, 2)));
    XCTAssertTrue(CGRectEqualToRect(copy.intrinsicBounds, original.intrinsicBounds));
    XCTAssertEqualObjects(copy.identifier, original.identifier);
    XCTAssertEqual(copy.type, original.type);
    XCTAssertEqual(copy.x.value, 3.f);
    XCTAssertEqual(copy.y.value, 5.f);
    XCTAssertEqual(copy.width.value, 4.f);
    XCTAssertEqual(copy.height.value, 2.f);
    XCTAssertEqual(copy.opacity.value, 0.5f);
    XCTAssertNil(copy.sourceData);
    XCTAssertNil(copy.sourceMIMEType);
}

- (void)testEncodedImageCopyPreservesExportMetadata
{
    NSData* png = [[self imageCopyTestBitmap]
        representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    XCTAssertNotNil(png);
    NSString* dataURL = [@"data:image/png;base64," stringByAppendingString:
        [png base64EncodedStringWithOptions:0]];
    IJSVGImage* original = [self imageCopyTestNode];
    [original loadFromString:dataURL];
    IJSVGImage* copy = original.copy;

    XCTAssertNotNil(original.image);
    XCTAssertEqual(copy.image, original.image);
    XCTAssertEqual(copy.CGImage, original.CGImage);
    XCTAssertTrue(CGSizeEqualToSize(copy.intrinsicSize, original.intrinsicSize));
    XCTAssertEqualObjects(copy.sourceData, png);
    XCTAssertEqualObjects(copy.sourceMIMEType, @"image/png");

    IJSVG* svg = [[IJSVG alloc] initWithSVGString:
        @"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 2'/>"];
    [svg.rootNode addChild:copy];
    NSString* exported = [svg SVGStringWithSize:CGSizeMake(4, 2)
                                       options:IJSVGExporterOptionNone];
    XCTAssertTrue([exported containsString:dataURL]);
    original.image = nil;
    XCTAssertEqualObjects(copy.sourceData, png);
    XCTAssertEqualObjects(copy.sourceMIMEType, @"image/png");
}

- (void)testGroupCopyPreservesImageChild
{
    IJSVGGroup* original = [[IJSVGGroup alloc] init];
    IJSVGImage* imageNode = [self imageCopyTestNode];
    [original addChild:imageNode];
    IJSVGGroup* copy = original.copy;
    XCTAssertEqual(original.children.count, 1u);
    XCTAssertEqual(copy.children.count, 1u);
    IJSVGImage* copiedImage = (IJSVGImage*)copy.children.firstObject;
    XCTAssertNotEqual(copiedImage, imageNode);
    XCTAssertEqual(imageNode.parentNode, original);
    XCTAssertEqual(copiedImage.parentNode, copy);
    XCTAssertEqual(copiedImage.image, imageNode.image);
    XCTAssertEqual(copiedImage.CGImage, imageNode.CGImage);
    [self assertImageCopyNodeRenders:copy];
}

- (void)testImageCopyRendersAfterOriginalIsReleased
{
    IJSVGImage* copy = nil;
    __weak IJSVGImage* weakOriginal = nil;
    @autoreleasepool {
        IJSVGImage* original = [self imageCopyTestNode];
        weakOriginal = original;
        copy = original.copy;
        XCTAssertEqual(copy.CGImage, original.CGImage);
        // Also release the original's cached image before destroying the node.
        original.image = nil;
    }
    XCTAssertNil(weakOriginal);
    XCTAssertNotNil(copy.image);
    XCTAssertTrue(copy.CGImage != NULL);
    [self assertImageCopyNodeRenders:copy];
}

- (void)testEmptyImageCopy
{
    IJSVGImage* original = [[IJSVGImage alloc] init];
    IJSVGImage* copy = original.copy;
    XCTAssertNil(copy.image);
    XCTAssertTrue(copy.CGImage == NULL);
    XCTAssertTrue(CGSizeEqualToSize(copy.intrinsicSize, CGSizeZero));
    XCTAssertNil(copy.sourceData);
    XCTAssertNil(copy.sourceMIMEType);
}

- (NSColor*)rgb:(NSColor*)color
{
    return [color colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
}

- (void)testNodeTypeMappingCoversKnownElementsAndUnsupportedText
{
    XCTAssertEqual([IJSVGNode typeForString:@"g"
                                       kind:NSXMLElementKind],
                   IJSVGNodeTypeGroup);
    XCTAssertEqual([IJSVGNode typeForString:@"PATH"
                                       kind:NSXMLElementKind],
                   IJSVGNodeTypePath);
    XCTAssertEqual([IJSVGNode typeForString:@"linearGradient"
                                       kind:NSXMLElementKind],
                   IJSVGNodeTypeLinearGradient);
    XCTAssertEqual([IJSVGNode typeForString:@"radialGradient"
                                       kind:NSXMLElementKind],
                   IJSVGNodeTypeRadialGradient);
    XCTAssertEqual([IJSVGNode typeForString:@"clipPath"
                                       kind:NSXMLElementKind],
                   IJSVGNodeTypeClipPath);
    XCTAssertEqual([IJSVGNode typeForString:@"feGaussianBlur"
                                       kind:NSXMLElementKind],
                   IJSVGNodeTypeFilterGaussianBlur);
    XCTAssertEqual([IJSVGNode typeForString:@"unknown"
                                       kind:NSXMLElementKind],
                   IJSVGNodeTypeUnknown);
    XCTAssertEqual([IJSVGNode typeForString:@"text body"
                                       kind:NSXMLTextKind],
                   IJSVGNodeTypeNotFound);
    XCTAssertEqual([IJSVGNode typeForString:nil
                                       kind:NSXMLElementKind],
                   IJSVGNodeTypeNotFound);
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
    [group addChildren:@[rect, circle, hidden]];

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
    [root addChildren:@[branch, after]];

    NSMutableArray<NSString*>* visited = [[NSMutableArray alloc] init];
    [IJSVGNode walkNodeTree:root
                    handler:^(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop) {
        [visited addObject:node.name ?: @"unknown"];
        if(node == branch) {
            *allowChildNodes = NO;
        }
    }];
    XCTAssertEqualObjects(visited, (@[@"root", @"branch", @"after"]));

    [visited removeAllObjects];
    [IJSVGNode walkNodeTree:root
                    handler:^(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop) {
        [visited addObject:node.name ?: @"unknown"];
        if(node == branch) {
            *stop = YES;
        }
    }];
    XCTAssertEqualObjects(visited, (@[@"root", @"branch"]));
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
    XCTAssertEqualWithAccuracy([self rgb:fillColor.color].greenComponent, 1.f,
                               0.002f);

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
    XCTAssertEqualWithAccuracy([self rgb:replacement].greenComponent, 1.f,
                               0.002f);
}

// Bulk moves and removals must tolerate the live children array of a group.
- (void)testBulkChildOperationsPreserveOrderAndParentLinks
{
    IJSVGGroup* source = [[IJSVGGroup alloc] init];
    IJSVGGroup* destination = [[IJSVGGroup alloc] init];
    NSArray<IJSVGNode*>* children = @[
        IJSVGTestNode(@"rect", @"first", nil),
        IJSVGTestNode(@"circle", @"second", nil),
        IJSVGTestNode(@"path", @"third", nil)
    ];
    [source addChildren:children];
    XCTAssertNoThrow([destination addChildren:source.children]);
    XCTAssertEqual(source.children.count, 0u);
    XCTAssertEqualObjects(destination.children, children);
    for(IJSVGNode* child in children) {
        XCTAssertEqual(child.parentNode, destination);
    }
    XCTAssertNoThrow([destination addChildren:destination.children]);
    XCTAssertEqualObjects(destination.children, children);
    XCTAssertNoThrow([destination removeChildren:destination.children]);
    XCTAssertEqual(destination.children.count, 0u);
    for(IJSVGNode* child in children) {
        XCTAssertNil(child.parentNode);
    }
}

@end
