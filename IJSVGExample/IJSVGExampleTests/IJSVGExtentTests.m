#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <XCTest/XCTest.h>

@interface IJSVGExtentTests : XCTestCase
@end

@implementation IJSVGExtentTests

- (IJSVG*)svgWithBody:(NSString*)body
{
    NSString* xml = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100' viewBox='0 0 100 100'>%@</svg>", body];
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(svg);
    svg.renderingBackingScaleHelper = ^CGFloat { return 1.f; };
    return svg;
}

- (IJSVGNode*)firstNode:(IJSVG*)svg
{
    IJSVGNode* node = svg.rootNode.children.firstObject;
    XCTAssertNotNil(node);
    return node;
}

- (void)assertRect:(CGRect)actual equals:(CGRect)expected
{
    XCTAssertFalse(CGRectIsNull(actual));
    XCTAssertFalse(CGRectIsInfinite(actual));
    XCTAssertEqualWithAccuracy(actual.origin.x, expected.origin.x, 0.001);
    XCTAssertEqualWithAccuracy(actual.origin.y, expected.origin.y, 0.001);
    XCTAssertEqualWithAccuracy(actual.size.width, expected.size.width, 0.001);
    XCTAssertEqualWithAccuracy(actual.size.height, expected.size.height, 0.001);
}

- (NSString*)filterDefinition
{
    return @"<defs><filter id='f' x='-50%' y='-50%' width='200%' height='200%'>"
            "<feFlood flood-color='red'/></filter></defs>";
}

- (IJSVG*)filteredSVGWithBody:(NSString*)body
{
    return [self svgWithBody:[self.filterDefinition stringByAppendingString:body]];
}

// A node includes its own transform, but not the transforms of its ancestors.
- (void)testNodeExtentUsesParentCoordinates
{
    IJSVG* svg = [self svgWithBody:
        @"<g transform='translate(30 40)'><g transform='scale(2 3)'>"
         "<rect x='4' y='5' width='10' height='6'/></g></g>"];
    IJSVGGroup* outer = (IJSVGGroup*)[self firstNode:svg];
    IJSVGGroup* inner = (IJSVGGroup*)outer.children.firstObject;
    IJSVGNode* rect = inner.children.firstObject;
    [self assertRect:[rect extentWithViewPort:svg.viewBox style:nil] equals:CGRectMake(4, 5, 10, 6)];
    [self assertRect:[inner extentWithViewPort:svg.viewBox style:nil] equals:CGRectMake(8, 15, 20, 18)];
    [self assertRect:[outer extentWithViewPort:svg.viewBox style:nil] equals:CGRectMake(38, 55, 20, 18)];
    [self assertRect:svg.artworkExtent equals:CGRectMake(38, 55, 20, 18)];
}

- (void)testObjectBoundingBoxFilterIncludesTransformedRegion
{
    IJSVG* svg = [self filteredSVGWithBody:
        @"<rect x='20' y='30' width='40' height='20' transform='translate(5 7)' filter='url(#f)'/>"];
    [self assertRect:[[self firstNode:svg] extentWithViewPort:svg.viewBox style:nil]
              equals:CGRectMake(5, 27, 80, 40)];
    [self assertRect:svg.artworkExtent equals:CGRectMake(5, 27, 80, 40)];
    [self assertRect:svg.artworkBounds equals:CGRectMake(25, 37, 40, 20)];
}

- (void)testUserSpaceFilterPercentagesFollowViewport
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='10%' y='20%' width='50%' height='60%'>"
         "<feFlood flood-color='red'/></filter></defs>"
         "<rect x='20' y='30' width='10' height='10' filter='url(#f)'/>"];
    IJSVGNode* node = [self firstNode:svg];
    [self assertRect:[node extentWithViewPort:CGRectMake(0, 0, 100, 200) style:nil]
              equals:CGRectMake(10, 40, 50, 120)];
    [self assertRect:[node extentWithViewPort:CGRectMake(0, 0, 200, 100) style:nil]
              equals:CGRectMake(20, 20, 100, 60)];
}

- (void)testFilterOptionsAffectArtworkButNodeQueryIncludesFilters
{
    IJSVG* svg = [self filteredSVGWithBody:
        @"<rect x='20' y='30' width='40' height='20' filter='url(#f)'/>"];
    IJSVGRenderingOptions* options = [[IJSVGRenderingOptions alloc] init];
    options.filtersEnabled = NO;
    svg.renderingOptions = options;
    [self assertRect:svg.artworkExtent equals:CGRectMake(20, 30, 40, 20)];
    [self assertRect:[[self firstNode:svg] extentWithViewPort:svg.viewBox style:nil]
              equals:CGRectMake(0, 20, 80, 40)];
    options.filtersEnabled = YES;
    svg.renderingOptions = options;
    [self assertRect:svg.artworkExtent equals:CGRectMake(0, 20, 80, 40)];
}

- (void)testInvisibleFilteredNodesHaveNoExtent
{
    for(NSString* attributes in @[@"display='none'", @"opacity='0'"]) {
        IJSVG* svg = [self filteredSVGWithBody:[NSString stringWithFormat:
            @"<g %@><rect width='20' height='20' filter='url(#f)'/></g>", attributes]];
        XCTAssertTrue(CGRectIsNull(svg.artworkExtent), @"%@", attributes);
        XCTAssertTrue(CGRectIsNull([[self firstNode:svg] extentWithViewPort:svg.viewBox style:nil]),
                      @"%@", attributes);
    }
}

- (void)testEmptyAndUnpaintedNodesHaveNoExtent
{
    for(NSString* body in @[@"<g/>", @"<rect width='20' height='20' fill='none'/>"]) {
        IJSVG* svg = [self svgWithBody:body];
        XCTAssertTrue(CGRectIsNull(svg.artworkExtent), @"%@", body);
        XCTAssertTrue(CGRectIsNull([[self firstNode:svg] extentWithViewPort:svg.viewBox style:nil]));
        [svg fitArtworkToViewBox:YES includingFilters:YES];
        XCTAssertTrue(CGRectIsNull(svg.artworkExtent));
    }
}

- (void)testStrokeStyleIsResolvedAgainOnEveryQuery
{
    IJSVG* svg = [self svgWithBody:
        @"<path d='M20 40H60' fill='none' stroke='black' stroke-width='4' stroke-linecap='square'/>"];
    IJSVGNode* node = [self firstNode:svg];
    [self assertRect:[node extentWithViewPort:svg.viewBox style:nil] equals:CGRectMake(18, 38, 44, 4)];
    IJSVGStyle* style = [[IJSVGStyle alloc] init];
    style.lineWidth = 10;
    [self assertRect:[node extentWithViewPort:svg.viewBox style:style] equals:CGRectMake(15, 35, 50, 10)];
    style.lineWidth = 20;
    svg.style = style;
    [self assertRect:[node extentWithViewPort:svg.viewBox style:style] equals:CGRectMake(10, 30, 60, 20)];
    [self assertRect:svg.artworkExtent equals:CGRectMake(10, 30, 60, 20)];
}

- (void)testFilteredExtentRespectsClip
{
    IJSVG* svg = [self filteredSVGWithBody:
        @"<defs><clipPath id='c'><rect x='25' y='35' width='10' height='5'/></clipPath></defs>"
         "<rect x='20' y='30' width='40' height='20' filter='url(#f)' clip-path='url(#c)'/>"];
    [self assertRect:svg.artworkExtent equals:CGRectMake(25, 35, 10, 5)];
    [self assertRect:[[self firstNode:svg] extentWithViewPort:svg.viewBox style:nil]
              equals:CGRectMake(25, 35, 10, 5)];
}

// A filter's output is clipped to its region, even when its source is larger.
- (void)testFilterRegionCanBeSmallerThanGeometry
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='25' y='35' width='10' height='5'>"
         "<feFlood flood-color='red'/></filter></defs>"
         "<rect x='20' y='30' width='40' height='20' filter='url(#f)'/>"];
    [self assertRect:svg.artworkExtent equals:CGRectMake(25, 35, 10, 5)];
    [self assertRect:svg.artworkBounds equals:CGRectMake(20, 30, 40, 20)];
}

- (void)testFilterFittingIsRepeatableAndCanSwitchModesAndReset
{
    IJSVG* svg = [self filteredSVGWithBody:
        @"<rect x='10' y='10' width='80' height='80' filter='url(#f)'/>"];
    CGRect original = CGRectMake(-30, -30, 160, 160);
    [self assertRect:svg.artworkExtent equals:original];
    [svg fitArtworkToViewBox:YES];
    [self assertRect:svg.artworkExtent equals:original];
    for(NSUInteger index = 0; index < 3; index++) {
        [svg fitArtworkToViewBox:YES includingFilters:YES];
        [self assertRect:svg.artworkExtent equals:CGRectMake(0, 0, 100, 100)];
        [self assertRect:svg.artworkBounds equals:CGRectMake(25, 25, 50, 50)];
        XCTAssertTrue(CGSizeEqualToSize(svg.size, CGSizeMake(100, 100)));
    }
    [svg fitArtworkToViewBox:YES includingFilters:NO];
    [self assertRect:svg.artworkExtent equals:original];
    [svg fitArtworkToViewBox:YES includingFilters:YES];
    [svg fitArtworkToViewBox:NO includingFilters:YES];
    [self assertRect:svg.artworkExtent equals:original];
}

// Compare actual alpha bounds with an independent, unfiltered rectangle.
- (CGRect)paintedPixelsForSVG:(IJSVG*)svg
{
    NSError* error = nil;
    CGImageRef image = [svg newCGImageRefWithSize:CGSizeMake(100, 100) flipped:NO error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(image != NULL);
    if(image == NULL) {
        return CGRectNull;
    }
    NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithCGImage:image];
    CGImageRelease(image);
    CGRect bounds = CGRectNull;
    for(NSInteger y = 0; y < bitmap.pixelsHigh; y++) {
        for(NSInteger x = 0; x < bitmap.pixelsWide; x++) {
            if([bitmap colorAtX:x y:y].alphaComponent > 0.1) {
                bounds = CGRectUnion(bounds, CGRectMake(x, y, 1, 1));
            }
        }
    }
    return bounds;
}

- (void)testFittingScalesCompletedFilterPixels
{
    IJSVG* svg = [self filteredSVGWithBody:
        @"<rect x='10' y='30' width='80' height='40' filter='url(#f)'/>"];
    IJSVG* expected = [self svgWithBody:@"<rect y='25' width='100' height='50' fill='red'/>"];
    CGRect expectedPixels = [self paintedPixelsForSVG:expected];
    for(NSUInteger index = 0; index < 2; index++) {
        [svg fitArtworkToViewBox:YES includingFilters:YES];
        [self assertRect:svg.artworkExtent equals:CGRectMake(0, 25, 100, 50)];
        [self assertRect:[self paintedPixelsForSVG:svg] equals:expectedPixels];
    }
    [svg fitArtworkToViewBox:NO includingFilters:YES];
    [self assertRect:svg.artworkExtent equals:CGRectMake(-30, 10, 160, 80)];
    XCTAssertEqual([self paintedPixelsForSVG:svg].size.height, 80);
}

- (void)testNodeChangesAreNotCached
{
    IJSVG* svg = [self filteredSVGWithBody:
        @"<rect x='20' y='30' width='40' height='20' filter='url(#f)'/>"];
    IJSVGNode* node = [self firstNode:svg];
    [self assertRect:[node extentWithViewPort:svg.viewBox style:nil] equals:CGRectMake(0, 20, 80, 40)];
    node.shouldRender = NO;
    XCTAssertTrue(CGRectIsNull([node extentWithViewPort:svg.viewBox style:nil]));
    node.shouldRender = YES;
    node.filter.width.value = 3;
    [self assertRect:[node extentWithViewPort:svg.viewBox style:nil] equals:CGRectMake(0, 20, 120, 40)];
    node.filters = @[];
    [self assertRect:[node extentWithViewPort:svg.viewBox style:nil] equals:CGRectMake(20, 30, 40, 20)];
}

- (void)testNestedFilterUsesOuterRegion
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='inner' x='-100%' y='-100%' width='300%' height='300%'>"
         "<feFlood flood-color='red'/></filter>"
         "<filter id='outer' filterUnits='userSpaceOnUse' x='5' y='10' width='70' height='60'>"
         "<feGaussianBlur stdDeviation='1'/></filter></defs>"
         "<g transform='translate(3 4)' filter='url(#outer)'>"
         "<rect x='20' y='30' width='40' height='20' filter='url(#inner)'/></g>"];
    [self assertRect:svg.artworkExtent equals:CGRectMake(8, 14, 70, 60)];
    [self assertRect:[[self firstNode:svg] extentWithViewPort:svg.viewBox style:nil]
              equals:CGRectMake(8, 14, 70, 60)];
}

- (void)testGradientAndPatternNodesUsePaintedGeometry
{
    NSArray<NSString*>* definitions = @[
        @"<linearGradient id='p'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient>",
        @"<pattern id='p' width='0.5' height='0.5'><rect width='10' height='10'/></pattern>"
    ];
    for(NSString* definition in definitions) {
        IJSVG* svg = [self svgWithBody:[NSString stringWithFormat:
            @"<defs>%@</defs><rect x='20' y='30' width='40' height='20' fill='url(#p)'/>", definition]];
        [self assertRect:[[self firstNode:svg] extentWithViewPort:svg.viewBox style:nil]
                  equals:CGRectMake(20, 30, 40, 20)];
    }
}

// Use every nonzero alpha byte: the earlier 10% threshold misses blur tails.
// The context's row coordinates follow SVG coordinates, so no image flip is inferred.
- (CGRect)allPaintedPixelsForSVG:(IJSVG*)svg scale:(NSUInteger)scale
{
    CGSize size = svg.size;
    NSUInteger width = (NSUInteger)ceil(size.width * scale);
    NSUInteger height = (NSUInteger)ceil(size.height * scale);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
        space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) return CGRectNull;
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, scale, -(CGFloat)scale);
    [svg drawInRect:(CGRect){ CGPointZero, size } context:context];
    const uint8_t* pixels = CGBitmapContextGetData(context);
    CGRect bounds = CGRectNull;
    for(NSUInteger y = 0; y < height; y++) {
        for(NSUInteger x = 0; x < width; x++) {
            if(pixels[(y * width + x) * 4 + 3] != 0) {
                bounds = CGRectUnion(bounds, CGRectMake(x, y, 1, 1));
            }
        }
    }
    CGContextRelease(context);
    return bounds;
}

- (void)assertExtent:(CGRect)extent coversPixels:(CGRect)pixels scale:(NSUInteger)scale
{
    XCTAssertFalse(CGRectIsNull(pixels), @"The fixture must actually render");
    CGRect pixelExtent = CGRectApplyAffineTransform(extent, CGAffineTransformMakeScale(scale, scale));
    // Fractional edges may cover the adjacent pixel; round outward, without
    // adding an arbitrary blur-radius tolerance that could conceal missing tails.
    pixelExtent = CGRectIntegral(pixelExtent);
    XCTAssertTrue(CGRectContainsRect(pixelExtent, pixels),
                  @"Extent %@ does not contain pixels %@", NSStringFromRect(pixelExtent), NSStringFromRect(pixels));
}

- (void)assertEffectPixelsCovered:(NSString*)primitives
{
    IJSVG* svg = [self svgWithBody:[NSString stringWithFormat:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='10' y='15' width='75' height='70'>"
         "%@</filter></defs><rect x='40' y='40' width='20' height='20' filter='url(#f)'/>", primitives]];
    CGRect expected = CGRectMake(10, 15, 75, 70);
    [self assertRect:svg.artworkExtent equals:expected];
    CGRect nodeExtent = [[self firstNode:svg] extentWithViewPort:svg.viewBox style:nil];
    [self assertRect:nodeExtent equals:expected];
    for(NSNumber* value in @[@1, @2, @3]) {
        NSUInteger scale = value.unsignedIntegerValue;
        CGRect pixels = [self allPaintedPixelsForSVG:svg scale:scale];
        [self assertExtent:nodeExtent coversPixels:pixels scale:scale];
        CGRect geometry = CGRectMake(40 * scale, 40 * scale, 20 * scale, 20 * scale);
        XCTAssertFalse(CGRectContainsRect(geometry, pixels),
                       @"The effect must generate pixels beyond the source geometry");
    }
}

- (void)testGaussianBlurTailsAreInsideExtent
{
    [self assertEffectPixelsCovered:@"<feGaussianBlur stdDeviation='7'/>"];
    [self assertEffectPixelsCovered:@"<feGaussianBlur stdDeviation='12 2'/>"];
    // A very wide blur is clipped at the filter region, not allowed to expand indefinitely.
    [self assertEffectPixelsCovered:@"<feGaussianBlur stdDeviation='30'/>"];
}

- (void)testOffsetAndDropShadowPixelsAreInsideExtent
{
    [self assertEffectPixelsCovered:@"<feOffset dx='-24' dy='18'/>"];
    [self assertEffectPixelsCovered:
        @"<feDropShadow dx='18' dy='-15' stdDeviation='5 9' flood-color='black'/>"];
}

- (void)testChainedBlurOffsetAndMergePixelsAreInsideExtent
{
    [self assertEffectPixelsCovered:
        @"<feGaussianBlur in='SourceAlpha' stdDeviation='4 7' result='blur'/>"
         "<feOffset in='blur' dx='-18' dy='12' result='shadow'/>"
         "<feMerge><feMergeNode in='shadow'/><feMergeNode in='SourceGraphic'/></feMerge>"];
    [self assertEffectPixelsCovered:
        @"<feGaussianBlur stdDeviation='3'/><feGaussianBlur stdDeviation='6'/>"];
}

- (void)testMorphologyAndGeneratedPixelsAreInsideExtent
{
    [self assertEffectPixelsCovered:@"<feMorphology operator='dilate' radius='8 4'/>"];
    [self assertEffectPixelsCovered:@"<feFlood flood-color='red' flood-opacity='.01'/>"];
    [self assertEffectPixelsCovered:
        @"<feColorMatrix type='matrix' values='1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 0 1'/>"];
}

- (void)testTransformedBlurAndSequentialFiltersCoverPixels
{
    NSArray<NSString*>* transforms = @[
        @"translate(5 3)", @"rotate(25 50 50)", @"translate(10 20) scale(.8 .6)"
    ];
    for(NSString* transform in transforms) {
        IJSVG* svg = [self svgWithBody:[NSString stringWithFormat:
            @"<defs><filter id='blur' filterUnits='userSpaceOnUse' x='15' y='15' width='70' height='70'>"
             "<feGaussianBlur stdDeviation='6'/></filter>"
             "<filter id='offset' filterUnits='userSpaceOnUse' x='5' y='10' width='85' height='80'>"
             "<feOffset dx='-7' dy='5'/></filter></defs>"
             "<g transform='%@'><rect x='40' y='40' width='20' height='20' "
             "filter='url(#blur) url(#offset)'/></g>", transform]];
        IJSVGGroup* group = (IJSVGGroup*)[self firstNode:svg];
        IJSVGNode* rect = group.children.firstObject;
        XCTAssertEqual(rect.filters.count, 2u);
        [self assertRect:[rect extentWithViewPort:svg.viewBox style:nil] equals:CGRectMake(5, 10, 85, 80)];
        CGRect extent = [group extentWithViewPort:svg.viewBox style:nil];
        [self assertRect:svg.artworkExtent equals:extent];
        for(NSNumber* scale in @[@1, @2]) {
            [self assertExtent:extent
                  coversPixels:[self allPaintedPixelsForSVG:svg scale:scale.unsignedIntegerValue]
                         scale:scale.unsignedIntegerValue];
        }
    }
}

- (void)testFittedBlurAndShadowCoverPixels
{
    for(NSString* effect in @[@"<feGaussianBlur stdDeviation='8'/>",
                              @"<feDropShadow dx='15' dy='-10' stdDeviation='6'/>"]) {
        IJSVG* svg = [self svgWithBody:[NSString stringWithFormat:
            @"<defs><filter id='f' x='-50%%' y='-50%%' width='200%%' height='200%%'>%@</filter></defs>"
             "<rect x='10' y='30' width='80' height='40' filter='url(#f)'/>", effect]];
        [self assertRect:svg.artworkExtent equals:CGRectMake(-30, 10, 160, 80)];
        for(NSUInteger index = 0; index < 2; index++) {
            [svg fitArtworkToViewBox:YES includingFilters:YES];
            [self assertRect:svg.artworkExtent equals:CGRectMake(0, 25, 100, 50)];
            CGRect pixels = [self allPaintedPixelsForSVG:svg scale:2];
            [self assertExtent:svg.artworkExtent coversPixels:pixels scale:2];
            CGRect geometry = CGRectApplyAffineTransform(svg.artworkBounds, CGAffineTransformMakeScale(2, 2));
            XCTAssertFalse(CGRectContainsRect(CGRectIntegral(geometry), pixels));
        }
    }
}

// This corpus includes every registered primitive, nested effects, masks, clips,
// fractional regions, transforms, and both sRGB and linearRGB interpolation.
- (void)testFilterCorpusExtentsCoverEveryRenderedPixel
{
    NSString* path = [@(__FILE__).stringByDeletingLastPathComponent
        stringByAppendingPathComponent:@"Fixtures/FilterMatrix/manifest.json"];
    NSError* error = nil;
    NSData* data = [NSData dataWithContentsOfFile:path options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(data);
    if(data == nil) return;
    NSArray<NSDictionary*>* fixtures = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(fixtures.count, 80u);
    for(NSDictionary* fixture in fixtures) {
        [XCTContext runActivityNamed:fixture[@"name"] block:^(id<XCTActivity> activity) {
            NSMutableArray<NSString*>* documents = [fixture[@"references"] mutableCopy];
            [documents addObject:fixture[@"document"]];
            for(NSString* document in documents) {
                @autoreleasepool {
                    IJSVG* svg = [[IJSVG alloc] initWithSVGString:document];
                    XCTAssertNotNil(svg);
                    if(svg == nil) continue;
                    svg.renderingBackingScaleHelper = ^CGFloat { return 1.f; };
                    // Render at two resolutions to expose filter rasterization differences.
                    for(NSNumber* scale in @[@1, @2]) {
                        [self assertExtent:svg.artworkExtent
                              coversPixels:[self allPaintedPixelsForSVG:svg scale:scale.unsignedIntegerValue]
                                     scale:scale.unsignedIntegerValue];
                    }
                }
            }
        }];
    }
}

- (void)testDefaultFilterRegionAndGroupUnion
{
    IJSVG* svg = [self svgWithBody:
        @"<defs><filter id='f'><feGaussianBlur stdDeviation='2'/></filter></defs>"
         "<g><rect x='20' y='30' width='40' height='20' filter='url(#f)'/>"
         "<rect x='80' y='70' width='10' height='10'/></g>"];
    [self assertRect:svg.artworkExtent equals:CGRectMake(16, 28, 74, 52)];
    [self assertRect:[[self firstNode:svg] extentWithViewPort:svg.viewBox style:nil]
              equals:CGRectMake(16, 28, 74, 52)];
}

@end
