//
//  IJSVGNodeAndColorStorageTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGClipPath.h>
#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGImage.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVG/IJSVGMask.h>
#import <IJSVG/IJSVGRadialGradient.h>
#import <IJSVG/IJSVGRect.h>
#import <IJSVG/IJSVGStop.h>
#import <IJSVG/IJSVGTraitedColor.h>
#import <IJSVG/IJSVGTraitedColorStorage.h>
#import <IJSVGTestHelpers.h>
#import <objc/runtime.h>

@interface IJSVGNodeAndColorStorageTests : XCTestCase
@end

@implementation IJSVGNodeAndColorStorageTests

- (void)testTransformBoxKeywordsResolveToEnums
{
    NSDictionary<NSString*, NSNumber*>* cases = @{ @"view-box" : @(IJSVGTransformBoxViewBox), @"fill-box" : @(IJSVGTransformBoxFillBox), @"stroke-box" : @(IJSVGTransformBoxStrokeBox), @"content-box" : @(IJSVGTransformBoxContentBox), @"border-box" : @(IJSVGTransformBoxBorderBox), @"FILL-BOX" : @(IJSVGTransformBoxFillBox), @"initial" : @(IJSVGTransformBoxViewBox), @"unset" : @(IJSVGTransformBoxViewBox), @"inherit" : @(IJSVGTransformBoxStrokeBox) };
    for (NSString* keyword in cases) {
        NSString* source = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg'><g transform-box='stroke-box'><path style='transform-box:%@' d='M0 0h10v10z'/><path d='M0 0h10v10z'/></g></svg>", keyword];
        IJSVG* svg = [[IJSVG alloc] initWithSVGString:source];
        IJSVGGroup* group = (IJSVGGroup*)svg.rootNode.children.firstObject;
        IJSVGGraphicsNode* node = (IJSVGGraphicsNode*)group.children.firstObject;
        XCTAssertNotNil(node);
        XCTAssertEqual(node.transformBox, cases[keyword].unsignedIntegerValue, @"%@", keyword);
        IJSVGGraphicsNode* copy = node.copy;
        XCTAssertEqual(copy.transformBox, node.transformBox);
        XCTAssertEqual(((IJSVGGraphicsNode*)group.children.lastObject).transformBox, IJSVGTransformBoxUnspecified);
    }
}

- (void)testUnusedGraphicsFeaturesDoNotAllocateStorage
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    XCTAssertNil(node.markerStart);
    XCTAssertNil(node.markerMid);
    XCTAssertNil(node.markerEnd);
    XCTAssertNil(node.mask);
    XCTAssertNil(node.filters);
    XCTAssertNil(node.transformOrigin);
    XCTAssertEqual(node.transformBox, IJSVGTransformBoxUnspecified);
    XCTAssertEqual(node.filterColorInterpolation, IJSVGColorInterpolationUnspecified);
    XCTAssertEqual(node.backgroundEnabled, IJSVGBackgroundEnabledUnspecified);
    XCTAssertTrue(CGRectEqualToRect(node.backgroundBounds, CGRectZero));
    node.markerStart = nil;
    node.mask = nil;
    node.filters = nil;
    node.transformOrigin = nil;
    node.transformBox = IJSVGTransformBoxUnspecified;
    node.filterColorInterpolation = IJSVGColorInterpolationUnspecified;
    node.backgroundEnabled = IJSVGBackgroundEnabledUnspecified;
    node.backgroundBounds = CGRectZero;
    IJSVGPath* copy = node.copy;
    for (NSString* name in @[ @"_markerProperties", @"_effectProperties", @"_transformOriginProperties" ]) {
        Ivar storage = class_getInstanceVariable(IJSVGGraphicsNode.class, name.UTF8String);
        XCTAssertNotEqual(storage, NULL);
        XCTAssertNil(object_getIvar(node, storage));
        XCTAssertNil(object_getIvar(copy, storage));
    }
}

- (void)testOptionalEffectsAndTransformStorageCopyAndRelease
{
    IJSVGGroup* node = [[IJSVGGroup alloc] init];
    IJSVGFilter* filter = [[IJSVGFilter alloc] init];
    NSMutableArray* filters = [NSMutableArray arrayWithObject:filter];
    node.filters = filters;
    [filters removeAllObjects];
    XCTAssertEqual(node.filter, filter);
    node.mask = [[IJSVGMask alloc] init];
    node.filterColorInterpolation = IJSVGColorInterpolationSRGB;
    node.backgroundEnabled = IJSVGBackgroundEnabledNew;
    node.backgroundBounds = CGRectNull;
    node.transformBox = IJSVGTransformBoxFillBox;
    NSMutableArray* origin = [NSMutableArray arrayWithObject:[IJSVGUnitLength unitWithFloat:5]];
    node.transformOrigin = origin;
    [origin removeAllObjects];
    IJSVGGroup* copy = node.copy;
    XCTAssertEqual(copy.filter, filter);
    XCTAssertEqual(copy.mask, node.mask);
    XCTAssertEqual(copy.resolvedFilterColorInterpolation, IJSVGColorInterpolationSRGB);
    XCTAssertTrue(CGRectIsNull(copy.backgroundRect));
    XCTAssertEqual(copy.transformBox, IJSVGTransformBoxFillBox);
    XCTAssertEqual(copy.transformOrigin.count, 1u);
    node.filters = nil;
    node.mask = nil;
    node.filterColorInterpolation = IJSVGColorInterpolationUnspecified;
    node.backgroundEnabled = IJSVGBackgroundEnabledUnspecified;
    node.backgroundBounds = CGRectZero;
    node.transformOrigin = nil;
    node.transformBox = IJSVGTransformBoxUnspecified;
    XCTAssertNil(object_getIvar(node, class_getInstanceVariable(IJSVGGraphicsNode.class, "_effectProperties")));
    XCTAssertNil(object_getIvar(node, class_getInstanceVariable(IJSVGGraphicsNode.class, "_transformOriginProperties")));
    XCTAssertEqual(copy.filter, filter);
    XCTAssertEqual(copy.transformBox, IJSVGTransformBoxFillBox);
    copy.filter = nil;
    XCTAssertEqualObjects(copy.filters, @[]);
    XCTAssertNil(copy.filter);
}

- (void)testOptionalMarkersPreserveInheritanceAndIndependentCopies
{
    IJSVGGroup* parent = [[IJSVGGroup alloc] init];
    IJSVGPath* child = [[IJSVGPath alloc] init];
    [parent addChild:child];
    parent.markerStart = [[IJSVGMarker alloc] init];
    parent.markerMid = [[IJSVGMarker alloc] init];
    parent.markerEnd = [[IJSVGMarker alloc] init];
    Ivar storage = class_getInstanceVariable(IJSVGGraphicsNode.class, "_markerProperties");
    XCTAssertEqual(child.markerStart, parent.markerStart);
    XCTAssertEqual(child.markerMid, parent.markerMid);
    XCTAssertEqual(child.markerEnd, parent.markerEnd);
    XCTAssertNil(object_getIvar(child, storage));
    IJSVGPath* inheritedCopy = child.copy;
    XCTAssertNil(object_getIvar(inheritedCopy, storage));
    child.markerStart = [[IJSVGMarker alloc] init];
    IJSVGPath* explicitCopy = child.copy;
    XCTAssertNotEqual(explicitCopy.markerStart, child.markerStart);
    child.markerStart = nil;
    XCTAssertNil(object_getIvar(child, storage));
    XCTAssertEqual(child.markerStart, parent.markerStart);
    XCTAssertNotEqual(explicitCopy.markerStart, parent.markerStart);
    inheritedCopy.parentNode = nil;
    explicitCopy.parentNode = nil;
}

- (void)testEmptyPathsRemainMutableAndIndependentWhenCopied
{
    IJSVGPath* path = [[IJSVGPath alloc] init];
    IJSVGPath* copy = path.copy;
    XCTAssertTrue(CGRectIsNull(path.pathBoundingBox));
    XCTAssertTrue(CGPointEqualToPoint(path.currentPoint, CGPointZero));
    XCTAssertFalse(path.hasPointSubpaths);
    [path close];
    XCTAssertTrue(CGPathIsEmpty(path.path));
    CGMutablePathRef editable = copy.path;
    XCTAssertNotEqual(editable, NULL);
    XCTAssertEqual(copy.path, editable);
    CGPathAddRect(editable, NULL, CGRectMake(1, 2, 3, 4));
    XCTAssertTrue(CGPathIsEmpty(path.path));
    XCTAssertTrue(CGRectEqualToRect(copy.pathBoundingBox, CGRectMake(1, 2, 3, 4)));
    IJSVGPath* drawnCopy = copy.copy;
    CGPathAddRect(drawnCopy.path, NULL, CGRectMake(10, 10, 5, 5));
    XCTAssertTrue(CGRectEqualToRect(copy.pathBoundingBox, CGRectMake(1, 2, 3, 4)));
}

- (void)testExplicitNullPathAndMarkerSnapshotsKeepTheirSemantics
{
    IJSVGPath* path = [[IJSVGPath alloc] init];
    path.path = NULL;
    XCTAssertEqual(path.path, NULL);
    IJSVGPath* copy = path.copy;
    XCTAssertEqual(copy.path, NULL);
    CGMutablePathRef geometry = CGPathCreateMutable();
    CGPathMoveToPoint(geometry, NULL, 0, 0);
    CGPathAddLineToPoint(geometry, NULL, 2, 3);
    path.path = geometry;
    CGPathRelease(geometry);
    path.markerPathData = @"M0 0L2 3";
    XCTAssertEqualObjects(path.markerPathData, @"M0 0L2 3");
    CGPathAddLineToPoint(path.path, NULL, 4, 5);
    XCTAssertNil(path.markerPathData);
    XCTAssertEqual(copy.path, NULL);
}

- (void)testBasicClipShapeValidationAndCopy
{
    NSArray<NSString*>* invalid = @[ @"circle(-1)", @"circle(10 20)", @"ellipse(10)", @"circle(at)", @"circle(at 10 20 30)", @"circle(10) unknown", @"circle(10) fill-box stroke-box", @"fill-box circle(10) stroke-box", @"circle(10", @"circle(10))", @"circle(calc(10px))" ];
    for (NSString* value in invalid) {
        XCTAssertNil([IJSVGClipPath clipPathWithBasicShape:value], @"%@", value);
    }
    IJSVGClipPath* original = [IJSVGClipPath clipPathWithBasicShape:@"ellipse(25% 40% at 30% 60%) fill-box"];
    IJSVGClipPath* copy = original.copy;
    XCTAssertNotNil(copy);
    XCTAssertTrue(copy.hasBasicShape);
    CGFloat (^resolver)(IJSVGUnitLength*, CGFloat) = ^CGFloat(IJSVGUnitLength* length, CGFloat percentage) {
        return [length computeValue:percentage];
    };
    CGPathRef path = [copy newBasicShapePathWithFillBox:CGRectMake(10, 20, 200, 100) strokeBox:CGRectMake(0, 10, 220, 120) viewBox:CGRectMake(0, 0, 400, 200) lengthResolver:resolver];
    XCTAssertTrue(CGRectEqualToRect(CGPathGetBoundingBox(path), CGRectMake(20, 40, 100, 80)));
    CGPathRelease(path);
}

- (void)testCurrentColorStorageAndCopyResolveInheritedPaint
{
    IJSVG* svg = IJSVGTestSVGObject(IJSVGTestSVG(@"<g color='red' fill='currentColor' stroke='currentColor'><rect "
                                                 @"color='blue' width='8' height='8'/></g>"));
    IJSVGGroup* group = (IJSVGGroup*)svg.rootNode.children.firstObject;
    IJSVGRect* rect = (IJSVGRect*)group.children.firstObject;
    IJSVGTraitedColorStorage* storage = [rect colorsWithStyle:[[IJSVGStyle alloc] init]];
    XCTAssertEqual(storage.count, 1u);
    IJSVGTraitedColor* color = storage.colors.anyObject;
    XCTAssertEqualWithAccuracy([self rgb:color.color].blueComponent, 1.f, 0.002f);
    XCTAssertTrue([color matchesTraits:IJSVGColorUsageTraitFill | IJSVGColorUsageTraitStroke]);
    IJSVGGroup* copy = group.copy;
    XCTAssertEqualObjects(copy.children.firstObject.currentColor, rect.currentColor);
    XCTAssertTrue(((IJSVGColorNode*)((IJSVGGraphicsNode*)copy.children.firstObject).fill).usesCurrentColor);
}

- (void)testRootCopyPreservesInferredViewBox
{
    IJSVG* inferred = IJSVGTestSVGObject(@"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='80'/>");
    IJSVG* explicit = IJSVGTestSVGObject(@"<svg xmlns='http://www.w3.org/2000/svg' width='100' "
                                         @"height='80' viewBox='0 0 100 80'/>");
    XCTAssertTrue(inferred.rootNode.viewBoxWasInferred);
    XCTAssertFalse(explicit.rootNode.viewBoxWasInferred);
    IJSVGRootNode* copy = inferred.rootNode.copy;
    XCTAssertTrue(copy.viewBoxWasInferred);
    copy.viewBox = [IJSVGUnitRect rectWithCGRect:CGRectMake(0, 0, 50, 40)];
    XCTAssertFalse(copy.viewBoxWasInferred);
    XCTAssertTrue(inferred.rootNode.viewBoxWasInferred);
}

- (void)testRootCopyPreservesSizingAndChildren
{
    IJSVGRootNode* original = [[IJSVGRootNode alloc] init];
    original.clientSize = CGSizeMake(80, 60);
    original.intrinsicSize = [IJSVGUnitSize sizeWithCGSize:CGSizeMake(80, 60)];
    original.intrinsicDimensions = IJSVGIntrinsicDimensionBoth;
    original.viewBox = [IJSVGUnitRect rectWithCGRect:CGRectMake(0, 0, 40, 30)];
    IJSVGGraphicsNode* ancestor = [[IJSVGGraphicsNode alloc] init];
    original.styleAncestors = @[ ancestor ];
    [original addChild:[self imageCopyTestNode]];
    IJSVGRootNode* copy = original.copy;

    XCTAssertTrue(CGSizeEqualToSize(copy.clientSize, original.clientSize));
    XCTAssertEqual(copy.intrinsicDimensions, IJSVGIntrinsicDimensionBoth);
    XCTAssertNotNil(copy.intrinsicSize);
    XCTAssertNotEqual(copy.intrinsicSize, original.intrinsicSize);
    XCTAssertTrue(CGSizeEqualToSize([copy.intrinsicSize computeValue:CGSizeZero], CGSizeMake(80, 60)));
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
    IJSVGColorNode* original = [[IJSVGColorNode alloc] initWithColor:[NSColor colorWithDeviceRed:1 green:0 blue:0 alpha:1]];
    original.identifier = @"paint";
    original.currentColor = NSColor.greenColor;
    IJSVGColorNode* copy = original.copy;
    XCTAssertEqual(copy.color, original.color);
    XCTAssertEqualObjects(copy.identifier, @"paint");
    XCTAssertEqualObjects(copy.currentColor, NSColor.greenColor);
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

    // A copied color must still be accepted as a fill by the node trait check.
    IJSVGPath* path = [[IJSVGPath alloc] init];
    XCTAssertNoThrow(path.fill = copy);
}

- (void)testPathCopyPreservesTraitsBeforeAndAfterComputation
{
    for (NSNumber* computeFirst in @[ @NO, @YES ]) {
        IJSVGPath* original = [[IJSVGPath alloc] init];
        original.stroke = [[IJSVGColorNode alloc] initWithColor:[NSColor colorWithDeviceRed:1 green:0 blue:0 alpha:1]];
        [original addTraits:IJSVGNodeTraitPaintable];
        if (computeFirst.boolValue) {
            XCTAssertTrue([original matchesTraits:IJSVGNodeTraitStroked]);
        }
        IJSVGPath* copy = original.copy;
        XCTAssertTrue([copy matchesTraits:IJSVGNodeTraitPathed | IJSVGNodeTraitPaintable | IJSVGNodeTraitStroked]);
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
    XCTAssertEqual(copy.offset, original.offset);
    original.offset = [original.offset lengthWithValue:0.25];
    XCTAssertEqual(copy.offset.value, 0.75);
}

- (void)testGradientCopyPreservesStopTreeAndCachedData
{
    for (Class gradientClass in @[ IJSVGLinearGradient.class, IJSVGRadialGradient.class ]) {
        IJSVGGradient* copy = nil;
        __weak IJSVGGradient* weakOriginal = nil;
        @autoreleasepool {
            IJSVGGradient* original = [[gradientClass alloc] init];
            weakOriginal = original;
            NSArray<NSColor*>* colors = @[ [NSColor colorWithDeviceRed:1 green:0 blue:0 alpha:1], [NSColor colorWithDeviceRed:0 green:0 blue:1 alpha:1] ];
            for (NSUInteger index = 0; index < colors.count; index++) {
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
            if (copy.children.count != 2 || copy.locations == NULL) {
                continue;
            }
            for (NSUInteger index = 0; index < 2; index++) {
                IJSVGStop* child = (IJSVGStop*)copy.children[index];
                XCTAssertNotEqual(child, original.children[index]);
                XCTAssertEqual(child.parentNode, copy);
                XCTAssertEqual(original.children[index].parentNode, original);
                XCTAssertEqual(child.offset.value, ((IJSVGStop*)original.children[index]).offset.value);
                XCTAssertEqual(copy.locations[index], original.locations[index]);
            }
        }
        XCTAssertNil(weakOriginal);
        XCTAssertTrue(copy.CGGradient != NULL);
        NSArray<NSColor*>* rebuiltColors = nil;
        CGFloat* rebuiltLocations = [IJSVGGradient computeColorStops:copy colors:&rebuiltColors];
        XCTAssertEqualObjects(rebuiltColors, copy.colors);
        XCTAssertTrue(rebuiltLocations != NULL);
        if (rebuiltLocations != NULL) {
            if (rebuiltColors.count == 2) {
                XCTAssertEqual(rebuiltLocations[0], 0.25);
                XCTAssertEqual(rebuiltLocations[1], 0.75);
            }
            free(rebuiltLocations);
        }
    }
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
    NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:4 pixelsHigh:2 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:16 bitsPerPixel:32];
    XCTAssertNotNil(bitmap);
    if (bitmap == nil) {
        return nil;
    }

    // Explicit RGBA bytes avoid NSColor conversion changing the fixture pixels.
    for (NSUInteger y = 0; y < 2; y++) {
        for (NSUInteger x = 0; x < 4; x++) {
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
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='4' "
                                                  @"height='2' viewBox='0 0 4 2'/>"];
    [svg.rootNode addChild:node];
    unsigned char pixels[4 * 2 * 4] = { 0 };
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(pixels, 4, 2, 8, 16, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if (context == NULL) {
        return;
    }
    [svg drawInRect:CGRectMake(0, 0, 4, 2) context:context];
    CGContextRelease(context);
    for (NSUInteger index = 0; index < sizeof(pixels); index += 4) {
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

    // The node cached intrinsic dimensions must survive even if NSImage changes.
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
    NSData* png = [[self imageCopyTestBitmap] representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    XCTAssertNotNil(png);
    NSString* dataURL = [@"data:image/png;base64," stringByAppendingString:[png base64EncodedStringWithOptions:0]];
    IJSVGImage* original = [self imageCopyTestNode];
    [original loadFromString:dataURL];
    IJSVGImage* copy = original.copy;

    XCTAssertNotNil(original.image);
    XCTAssertEqual(copy.image, original.image);
    XCTAssertEqual(copy.CGImage, original.CGImage);
    XCTAssertTrue(CGSizeEqualToSize(copy.intrinsicSize, original.intrinsicSize));
    XCTAssertEqualObjects(copy.sourceData, png);
    XCTAssertEqualObjects(copy.sourceMIMEType, @"image/png");

    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 2'/>"];
    [svg.rootNode addChild:copy];
    NSString* exported = [svg SVGStringWithSize:CGSizeMake(4, 2) options:IJSVGExporterOptionNone];
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

        // Also release the original cached image before destroying the node.
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
    XCTAssertEqual([IJSVGNode typeForString:@"g" kind:NSXMLElementKind], IJSVGNodeTypeGroup);
    XCTAssertEqual([IJSVGNode typeForString:@"PATH" kind:NSXMLElementKind], IJSVGNodeTypePath);
    XCTAssertEqual([IJSVGNode typeForString:@"linearGradient" kind:NSXMLElementKind], IJSVGNodeTypeLinearGradient);
    XCTAssertEqual([IJSVGNode typeForString:@"radialGradient" kind:NSXMLElementKind], IJSVGNodeTypeRadialGradient);
    XCTAssertEqual([IJSVGNode typeForString:@"clipPath" kind:NSXMLElementKind], IJSVGNodeTypeClipPath);
    XCTAssertEqual([IJSVGNode typeForString:@"feGaussianBlur" kind:NSXMLElementKind], IJSVGNodeTypeFilterGaussianBlur);
    XCTAssertEqual([IJSVGNode typeForString:@"unknown" kind:NSXMLElementKind], IJSVGNodeTypeUnknown);
    XCTAssertEqual([IJSVGNode typeForString:@"text body" kind:NSXMLTextKind], IJSVGNodeTypeNotFound);
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
    IJSVGGraphicsNode* node = [[IJSVGGraphicsNode alloc] init];

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
    [IJSVGNode walkNodeTree:root
                    handler:^(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop) {
                        [visited addObject:node.name ?: @"unknown"];
                        if (node == branch) {
                            *allowChildNodes = NO;
                        }
                    }];
    XCTAssertEqualObjects(visited, (@[ @"root", @"branch", @"after" ]));

    [visited removeAllObjects];
    [IJSVGNode walkNodeTree:root
                    handler:^(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop) {
                        [visited addObject:node.name ?: @"unknown"];
                        if (node == branch) {
                            *stop = YES;
                        }
                    }];
    XCTAssertEqualObjects(visited, (@[ @"root", @"branch" ]));
}

- (void)testInheritedNodePropertiesResolveFromParent
{
    IJSVGGroup* parent = [[IJSVGGroup alloc] init];
    IJSVGGraphicsNode* child = [[IJSVGGraphicsNode alloc] init];
    parent.opacity = [IJSVGUnitLength unitWithFloat:0.5f];
    parent.fillOpacity = [IJSVGUnitLength unitWithFloat:0.25f];
    parent.strokeWidth = [IJSVGUnitLength unitWithFloat:3.f];
    parent.windingRule = IJSVGWindingRuleEvenOdd;
    parent.clipRule = IJSVGWindingRuleNonZero;
    parent.lineCapStyle = IJSVGLineCapStyleRound;
    parent.lineJoinStyle = IJSVGLineJoinStyleBevel;
    [parent addChild:child];

    child.opacity = [child.opacity lengthWithInheritance:YES];
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

    IJSVGTraitedColorStorage* fillStorage = [colorNode colorsWithStyle:style matchingTraits:IJSVGColorUsageTraitFill];
    IJSVGTraitedColor* fillColor = fillStorage.colors.anyObject;
    XCTAssertEqual(fillStorage.count, 1u);
    XCTAssertTrue([fillColor matchesTraits:IJSVGColorUsageTraitFill]);
    XCTAssertEqualWithAccuracy([self rgb:fillColor.color].greenComponent, 1.f, 0.002f);

    colorNode.isNoneOrTransparent = YES;
    IJSVGTraitedColorStorage* emptyStorage = [colorNode colorsWithStyle:style matchingTraits:IJSVGColorUsageTraitFill];
    XCTAssertEqual(emptyStorage.count, 0u);
}

- (void)testTraitedColorMergesAndMatchesTraitsByColor
{
    IJSVGTraitedColor* color = [IJSVGTraitedColor colorWithColor:NSColor.redColor traits:IJSVGColorUsageTraitFill];
    IJSVGTraitedColor* sameColor = [IJSVGTraitedColor colorWithColor:NSColor.redColor traits:IJSVGColorUsageTraitStroke];
    IJSVGTraitedColor* differentColor = [IJSVGTraitedColor colorWithColor:NSColor.blueColor traits:IJSVGColorUsageTraitFill];

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
    IJSVGTraitedColor* fillRed = [IJSVGTraitedColor colorWithColor:NSColor.redColor traits:IJSVGColorUsageTraitFill];
    IJSVGTraitedColor* strokeRed = [IJSVGTraitedColor colorWithColor:NSColor.redColor traits:IJSVGColorUsageTraitStroke];
    [storage addColor:fillRed];
    [storage addColor:strokeRed];

    XCTAssertEqual(storage.count, 1u);
    XCTAssertTrue([storage matchesTraits:IJSVGColorUsageTraitFill]);
    XCTAssertTrue([storage.colors.anyObject matchesTraits:IJSVGColorUsageTraitFill | IJSVGColorUsageTraitStroke]);

    [storage replaceColor:NSColor.redColor withColor:NSColor.greenColor traits:IJSVGColorUsageTraitFill];
    XCTAssertEqual(storage.replacedColorCount, 1u);
    XCTAssertTrue([storage matchesReplacementTraits:IJSVGColorUsageTraitFill]);
    XCTAssertNil([storage colorForColor:NSColor.redColor matchingTraits:IJSVGColorUsageTraitStroke]);

    NSColor* replacement = [storage colorForColor:NSColor.redColor matchingTraits:IJSVGColorUsageTraitFill];
    XCTAssertNotNil(replacement);
    XCTAssertEqualWithAccuracy([self rgb:replacement].greenComponent, 1.f, 0.002f);
}

// Bulk moves and removals must tolerate the live children array of a group.
- (void)testBulkChildOperationsPreserveOrderAndParentLinks
{
    IJSVGGroup* source = [[IJSVGGroup alloc] init];
    IJSVGGroup* destination = [[IJSVGGroup alloc] init];
    NSArray<IJSVGNode*>* children = @[ IJSVGTestNode(@"rect", @"first", nil), IJSVGTestNode(@"circle", @"second", nil), IJSVGTestNode(@"path", @"third", nil) ];
    [source addChildren:children];
    XCTAssertNoThrow([destination addChildren:source.children]);
    XCTAssertEqual(source.children.count, 0u);
    XCTAssertEqualObjects(destination.children, children);
    for (IJSVGNode* child in children) {
        XCTAssertEqual(child.parentNode, destination);
    }
    XCTAssertNoThrow([destination addChildren:destination.children]);
    XCTAssertEqualObjects(destination.children, children);
    XCTAssertNoThrow([destination removeChildren:destination.children]);
    XCTAssertEqual(destination.children.count, 0u);
    for (IJSVGNode* child in children) {
        XCTAssertNil(child.parentNode);
    }
}

@end
