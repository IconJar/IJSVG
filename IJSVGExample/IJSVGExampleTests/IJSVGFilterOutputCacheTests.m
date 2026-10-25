//
//  IJSVGFilterOutputCacheTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 02/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVGFilterGraph.h>
#import <IJSVGFilterPaint.h>
#import <IJSVGFilterSIMD.h>
#import <XCTest/XCTest.h>

static NSData* BitmapPixels(CGContextRef context, NSUInteger size)
{
    void* bytes = CGBitmapContextGetData(context);
    return bytes == NULL ? nil : [NSData dataWithBytes:bytes length:size * size * 4];
}

static CGContextRef NewBitmap(NSUInteger size, CFStringRef colorSpaceName)
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(colorSpaceName);
    if (space == NULL) {
        return NULL;
    }
    CGContextRef context = CGBitmapContextCreate(NULL, size, size, 8, size * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    return context;
}

@interface IJSVGCountingFilterSource : IJSVGPaint
@property (nonatomic, assign) NSUInteger drawCount;
@property (nonatomic, assign) CGFloat sampledScale;
@end

@implementation IJSVGCountingFilterSource
- (void)drawInContext:(CGContextRef)context
{
    self.drawCount++;
    CGAffineTransform transform = CGContextGetCTM(context);
    self.sampledScale = MAX(hypot(transform.a, transform.b), hypot(transform.c, transform.d));
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(8, 8, 16, 16));
}
@end

@interface IJSVGFilterOutputCacheTests : XCTestCase
@end

@implementation IJSVGFilterOutputCacheTests

- (void)testBackdropScopeCacheTracksReplacementAndUncachedEdits
{
    IJSVGFilter* filter = [[IJSVGFilter alloc] init];
    IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
    primitive.input = @"BackgroundImage";
    [filter addChild:primitive];
    IJSVGGroup* parent = [[IJSVGGroup alloc] init];
    parent.backgroundEnabled = IJSVGBackgroundEnabledNew;
    parent.backgroundBounds = CGRectInfinite;
    IJSVGGroup* source = [[IJSVGGroup alloc] init];
    [parent addChild:source];
    IJSVGFilterPaint* paint = [[IJSVGFilterPaint alloc] initWithSourcePaint:IJSVGGroupPaint.paint filter:filter viewPort:CGRectMake(0, 0, 8, 8)];
    paint.sourceNode = source;
    paint.cachesRenderedOutput = YES;
    XCTAssertTrue(paint.usesBackground);
    paint.sourceNode = [[IJSVGGroup alloc] init];
    XCTAssertFalse(paint.usesBackground);
    paint.sourceNode = source;
    XCTAssertTrue(paint.usesBackground);
    paint.filter = [[IJSVGFilter alloc] init];
    XCTAssertFalse(paint.usesBackground);
    paint.filter = filter;
    paint.cachesRenderedOutput = NO;
    XCTAssertTrue(paint.usesBackground);
    parent.backgroundEnabled = IJSVGBackgroundEnabledUnspecified;
    XCTAssertFalse(paint.usesBackground);
}

- (void)testLiteralFilterNumbersKeepGeneralParsingAndReplacement
{
    IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
    for (NSString* value in @[ @"0", @"1", @"9", @"-2", @" .5 ", @"1e2", @"2 3", @"bad" ]) {
        primitive.parameters = @{ @"k2" : value };
        NSArray<NSNumber*>* parsed = [primitive numbersForParameter:@"k2"];
        CGFloat expected = parsed.count == 1 ? parsed[0].doubleValue : 17;
        XCTAssertEqual([primitive numberForParameter:@"k2" defaultValue:17], expected);
    }
    primitive.parameters = @{};
    XCTAssertEqual([primitive numberForParameter:@"k2" defaultValue:17], 17);
}

- (void)testBatchEligibilityKeepsItsCountBoundaries
{
    for (NSNumber* count in @[ @2, @3, @128, @129 ]) {
        IJSVGGroupPaint* root = IJSVGGroupPaint.paint;
        for (NSUInteger index = 0; index < count.unsignedIntegerValue; index++) {
            IJSVGFilterPaint* paint = [[IJSVGFilterPaint alloc] initWithSourcePaint:IJSVGGroupPaint.paint filter:[[IJSVGFilter alloc] init] viewPort:CGRectMake(0, 0, 8, 8)];
            [root addChild:paint];
        }
        NSSet* eligible = [IJSVGFilterPaint batchableFiltersForPaint:root];
        if (count.unsignedIntegerValue >= 3 && count.unsignedIntegerValue <= 128) {
            XCTAssertEqual(eligible.count, count.unsignedIntegerValue);
        } else {
            XCTAssertNil(eligible);
        }
    }
}

- (void)testUncachedFilterMetadataTracksParameterChanges
{
    IJSVGFilter* filter = [[IJSVGFilter alloc] init];
    IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
    primitive.type = IJSVGNodeTypeFilterComposite;
    primitive.input = @"SourceGraphic";
    primitive.input2 = @"BackgroundImage";
    primitive.parameters = @{ @"operator" : @"arithmetic", @"k2" : @"1", @"k3" : @"1" };
    [filter addChild:primitive];
    IJSVGFilterPaint* paint = [[IJSVGFilterPaint alloc] initWithSourcePaint:IJSVGGroupPaint.paint filter:filter viewPort:CGRectMake(0, 0, 8, 8)];
    XCTAssertTrue(paint.filterMetadata.usesBackdropAddition);
    primitive.parameters = @{ @"operator" : @"arithmetic", @"k2" : @"0", @"k3" : @"1" };
    XCTAssertFalse(paint.filterMetadata.usesBackdropAddition);
}

- (void)testFilterMetadataReadsNestedInputsAndRejectsNamedResults
{
    IJSVGFilter* filter = [[IJSVGFilter alloc] init];
    IJSVGFilterPrimitive* merge = [[IJSVGFilterPrimitive alloc] init];
    merge.input = @"SourceAlpha";
    merge.input2 = @"FillPaint";
    IJSVGFilterPrimitive* child = [[IJSVGFilterPrimitive alloc] init];
    child.input = @"BackgroundAlpha";
    [merge addChild:child];
    [filter addChild:merge];
    IJSVGFilterMetadata* metadata = [[IJSVGFilterMetadata alloc] initWithFilter:filter];
    XCTAssertEqual(metadata.primitives.count, 1U);
    XCTAssertEqual(metadata.inputs, IJSVGFilterInputSourceAlpha | IJSVGFilterInputFillPaint | IJSVGFilterInputBackgroundAlpha);
    for (NSString* name in @[ @"BackgroundImage", @"StrokePaint", @"BackgroundImageX", @"backgroundimage", @"SourceAlphaé", @"FillPainté" ]) {
        merge.input = name;
        merge.input2 = nil;
        [merge removeChild:child];
        metadata = [[IJSVGFilterMetadata alloc] initWithFilter:filter];
        IJSVGFilterInputs expected = [name isEqualToString:@"BackgroundImage"] ? IJSVGFilterInputBackgroundImage : [name isEqualToString:@"StrokePaint"] ? IJSVGFilterInputStrokePaint
                                                                                                                                                         : 0;
        XCTAssertEqual(metadata.inputs, expected, @"%@", name);
    }
}

- (void)testFilterPaintMetadataFollowsLiveEditsAndCacheTransitions
{
    IJSVGFilter* filter = [[IJSVGFilter alloc] init];
    IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
    primitive.input = @"SourceAlpha";
    [filter addChild:primitive];
    IJSVGGroupPaint* source = [[IJSVGGroupPaint alloc] init];
    IJSVGFilterPaint* paint = [[IJSVGFilterPaint alloc] initWithSourcePaint:source filter:filter viewPort:CGRectMake(0, 0, 100, 100)];
    XCTAssertEqual(paint.filterMetadata.inputs, IJSVGFilterInputSourceAlpha);
    primitive.input = @"BackgroundImage";
    XCTAssertEqual(paint.filterMetadata.inputs, IJSVGFilterInputBackgroundImage);
    paint.cachesRenderedOutput = YES;
    IJSVGFilterMetadata* first = paint.filterMetadata;
    XCTAssertEqual(first, paint.filterMetadata);
    paint.cachesRenderedOutput = NO;
    primitive.input = @"StrokePaint";
    paint.cachesRenderedOutput = YES;
    XCTAssertNotEqual(first, paint.filterMetadata);
    XCTAssertEqual(paint.filterMetadata.inputs, IJSVGFilterInputStrokePaint);
    paint.filter = [[IJSVGFilter alloc] init];
    XCTAssertEqual(paint.filterMetadata.primitives.count, 0U);
    XCTAssertEqual(paint.filterMetadata.inputs, 0U);
}

- (void)testFilterGraphMetadataDoesNotFreezeLiveFilters
{
    IJSVGFilter* filter = [[IJSVGFilter alloc] init];
    IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
    primitive.input = @"SourceAlpha";
    [filter addChild:primitive];
    IJSVGFilterGraph* graph = [[IJSVGFilterGraph alloc] init];
    graph.filter = filter;
    XCTAssertEqual(graph.filterInputs, IJSVGFilterInputSourceAlpha);
    primitive.input = @"BackgroundAlpha";
    XCTAssertEqual(graph.filterInputs, IJSVGFilterInputBackgroundAlpha);
    graph.resolvedMetadata = [[IJSVGFilterMetadata alloc] initWithFilter:filter];
    XCTAssertEqual(graph.filterInputs, IJSVGFilterInputBackgroundAlpha);
    graph.filter = [[IJSVGFilter alloc] init];
    XCTAssertEqual(graph.filterInputs, 0U);
    XCTAssertEqual(graph.filterPrimitives.count, 0U);
}

- (IJSVG*)svgForDocument:(NSUInteger)index
{
    NSArray<NSString*>* documents = @[
        (@"<defs><filter id='f'><feGaussianBlur "
         @"stdDeviation='1'/></filter></defs><rect x='8' y='8' "
          "width='16' height='16' fill='red' filter='url(#f)'/>"),
        (@"<defs><filter id='f'><feDropShadow dx='1' dy='1' "
         @"stdDeviation='1'/></filter></defs><g "
          "filter='url(#f)'><circle cx='16' cy='16' r='10' fill='blue' "
          "filter='url(#f)'/></g>"),
        (@"<defs><filter id='f'><feGaussianBlur "
         @"stdDeviation='.5'/></filter></defs><rect x='2' y='2' "
          "width='8' height='20' fill='red' filter='url(#f)'/><rect x='12' y='2' "
          "width='8' height='20' "
          "fill='green' filter='url(#f)'/><rect x='22' y='2' width='8' height='20' "
          "fill='blue' "
          "filter='url(#f)'/>"),
        (@"<defs><filter id='f'><feBlend in='SourceGraphic' in2='BackgroundImage' "
         @"mode='multiply'/>"
          "</filter></defs><circle cx='16' cy='16' r='10' fill='red' "
          "filter='url(#f)'/>"),
        (@"<defs><mask id='m'><rect width='20' height='32' "
         @"fill='white'/></mask><filter id='f'>"
          "<feGaussianBlur stdDeviation='1'/></filter></defs><g "
          "filter='url(#f)'><rect width='28' "
          "height='28' fill='blue' mask='url(#m)'/></g>"),
        (@"<defs><pattern id='p' width='4' height='4' "
         @"patternUnits='userSpaceOnUse'><rect width='2' "
          "height='4' fill='red'/></pattern><filter id='f'><feGaussianBlur "
          "stdDeviation='.5'/></filter>"
          "</defs><rect width='32' height='32' fill='url(#p)' "
          "filter='url(#f)'/>")
    ];
    NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' "
                                                "height='32' viewBox='0 0 32 32'>%@</svg>",
        documents[index]];
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml];
    XCTAssertNotNil(svg);
    return svg;
}

- (NSData*)render:(IJSVG*)svg size:(NSUInteger)size scale:(CGFloat)scale flipped:(BOOL)flipped blueBackground:(BOOL)blue
{
    if (svg == nil) {
        return nil;
    }
    CGContextRef context = NewBitmap(size, kCGColorSpaceSRGB);
    XCTAssertTrue(context != NULL);
    if (context == NULL) {
        return nil;
    }
    CGContextSetRGBFillColor(context, blue ? 0 : 1, 1, blue ? 1 : 0, 1);
    CGContextFillRect(context, CGRectMake(0, 0, size, size));
    if (flipped) {
        CGContextTranslateCTM(context, 0, size);
        CGContextScaleCTM(context, 1, -1);
    }
    svg.renderingBackingScaleHelper = ^CGFloat {
        return scale;
    };
    [svg drawInRect:CGRectMake(0, 0, size, size) context:context];
    NSData* pixels = BitmapPixels(context, size);
    CGContextRelease(context);
    XCTAssertNotNil(pixels);
    return pixels;
}

- (void)assertCachedOutputMatchesFreshRendererForDocument:(NSUInteger)index
{
    IJSVG* reused = [self svgForDocument:index];

    // Exercise cache hits, backing scales, sizes, flipped CTMs and backdrops.
    const NSUInteger sizes[] = { 64, 64, 128, 128, 64, 96, 64, 64 };
    for (NSUInteger step = 0; step < 8; step++) {
        CGFloat scale = step == 3 || step == 4 ? 2 : 1;
        NSData* actual = [self render:reused size:sizes[step] scale:scale flipped:step % 2 == 1 blueBackground:step >= 4];
        NSData* expected = [self render:[self svgForDocument:index] size:sizes[step] scale:scale flipped:step % 2 == 1 blueBackground:step >= 4];
        if (actual == nil || expected == nil) {
            return;
        }
        XCTAssertEqual(actual.length, expected.length);
        if (actual.length != expected.length) {
            return;
        }
        const uint8_t* a = actual.bytes;
        const uint8_t* b = expected.bytes;
        int maximumError = 0;
        for (NSUInteger byte = 0; byte < actual.length; byte++) {
            maximumError = MAX(maximumError, abs((int)a[byte] - (int)b[byte]));
        }
        XCTAssertLessThanOrEqual(maximumError, 1, @"case %lu, step %lu", (unsigned long)index, (unsigned long)step);
    }
}

- (void)testBatchReplayCachesOutputForLaterDraws
{
    IJSVG* svg = [self svgForDocument:0];
    IJSVGFilter* filter = ((IJSVGGraphicsNode*)svg.rootNode.children.firstObject).filter;
    XCTAssertNotNil(filter);
    NSMutableArray<IJSVGCountingFilterSource*>* sources = [NSMutableArray array];
    NSMutableArray<IJSVGFilterPaint*>* paints = [NSMutableArray array];
    for (NSUInteger index = 0; index < 3; index++) {
        IJSVGCountingFilterSource* source = [[IJSVGCountingFilterSource alloc] init];
        source.frame = CGRectMake(0, 0, 32, 32);
        source.boundingBox = source.outerBoundingBox = source.frame;
        IJSVGFilterPaint* paint = [[IJSVGFilterPaint alloc] initWithSourcePaint:source filter:filter viewPort:source.frame];
        paint.cachesRenderedOutput = YES;
        [sources addObject:source];
        [paints addObject:paint];
    }
    CGContextRef bitmap = NewBitmap(64, kCGColorSpaceSRGB);
    XCTAssertTrue(bitmap != NULL);
    if (bitmap == NULL) {
        return;
    }
    NSData* firstPixels = nil;
    for (NSUInteger draw = 0; draw < 3; draw++) {
        CGContextClearRect(bitmap, CGRectMake(0, 0, 64, 64));
        BOOL batched = [IJSVGFilterPaint renderBatchedPaints:[NSSet setWithArray:paints]
                                                   inContext:bitmap
                                                drawingBlock:^(CGContextRef context) {
                                                    for (IJSVGFilterPaint* paint in paints) {
                                                        [IJSVGFilterPaint renderPaint:paint inBitmapContext:context];
                                                    }
                                                }];
        XCTAssertTrue(batched);
        for (IJSVGCountingFilterSource* source in sources) {
            XCTAssertEqual(source.drawCount, 1U, @"Draw %lu must reuse the completed filter output", (unsigned long)draw);
        }
        NSData* pixels = BitmapPixels(bitmap, 64);
        if (draw == 0) {
            firstPixels = pixels;
        } else {
            XCTAssertEqualObjects(pixels, firstPixels);
        }
    }
    CGContextRelease(bitmap);
}

- (void)testBlurCacheMatchesFreshRenderer
{
    [self assertCachedOutputMatchesFreshRendererForDocument:0];
}

- (void)testNestedDropShadowCacheMatchesFreshRenderer
{
    [self assertCachedOutputMatchesFreshRendererForDocument:1];
}

- (void)testSharedFilterCacheMatchesFreshRenderer
{
    [self assertCachedOutputMatchesFreshRendererForDocument:2];
}

- (void)testBackgroundBlendCacheMatchesFreshRenderer
{
    [self assertCachedOutputMatchesFreshRendererForDocument:3];
}

- (void)testMaskedFilterCacheMatchesFreshRenderer
{
    [self assertCachedOutputMatchesFreshRendererForDocument:4];
}

- (void)testPatternFilterCacheMatchesFreshRenderer
{
    [self assertCachedOutputMatchesFreshRendererForDocument:5];
}

- (void)testChangingFilterOptionsInvalidatesCachedOutput
{
    IJSVG* reused = [self svgForDocument:1];
    for (NSNumber* enabled in @[ @YES, @YES, @NO, @NO, @YES ]) {
        IJSVGRenderingOptions* options = reused.renderingOptions;
        XCTAssertNotNil(options);
        options.filtersEnabled = enabled.boolValue;
        reused.renderingOptions = options;
        NSData* actual = [self render:reused size:96 scale:1 flipped:NO blueBackground:NO];
        IJSVG* fresh = [self svgForDocument:1];
        IJSVGRenderingOptions* freshOptions = fresh.renderingOptions;
        XCTAssertNotNil(freshOptions);
        freshOptions.filtersEnabled = enabled.boolValue;
        fresh.renderingOptions = freshOptions;
        NSData* expected = [self render:fresh size:96 scale:1 flipped:NO blueBackground:NO];
        XCTAssertNotNil(actual);
        XCTAssertNotNil(expected);
        XCTAssertEqualObjects(actual, expected);
    }
}

// Nested filters must reuse extra coverage samples rather than multiply them.
- (void)testNestedFilterQualityBoundsSamplingScale
{
    for (NSNumber* value in @[ @(kIJSVGRenderQualityFullResolution), @(kIJSVGRenderQualityOptimized), @(kIJSVGRenderQualityLow) ]) {
        IJSVGCountingFilterSource* source = [[IJSVGCountingFilterSource alloc] init];
        source.frame = CGRectMake(0, 0, 32, 32);
        source.boundingBox = source.outerBoundingBox = source.frame;
        IJSVGPaint* outer = source;
        for (NSUInteger level = 0; level < 3; level++) {
            IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
            primitive.type = IJSVGNodeTypeFilterColorMatrix;
            primitive.parameters = @{ @"type" : @"matrix", @"values" : @"1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 8 0" };
            IJSVGFilter* filter = [[IJSVGFilter alloc] init];
            [filter addChild:primitive];
            outer = [[IJSVGFilterPaint alloc] initWithSourcePaint:outer filter:filter viewPort:source.frame];
            outer.renderQuality = value.integerValue;
        }
        CGContextRef bitmap = NewBitmap(64, kCGColorSpaceSRGB);
        XCTAssertTrue(bitmap != NULL);
        if (bitmap == NULL) {
            return;
        }
        [IJSVGFilterPaint renderPaint:outer inBitmapContext:bitmap];
        XCTAssertGreaterThan(source.drawCount, 0U);
        XCTAssertEqualWithAccuracy(source.sampledScale, value.integerValue == kIJSVGRenderQualityLow ? 1.f : 2.f, 1e-6);
        CGContextRelease(bitmap);
    }
}

// Switching quality must rebuild filter output while preserving option snapshots.
- (void)testFilterQualitySwitchingRestoresFullResolution
{
    NSString* source = @"<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64'>"
                        "<defs>"
                        "<filter id='outer' x='-50%' y='-50%' width='200%' height='200%'><feGaussianBlur stdDeviation='.3'/></filter>"
                        "<filter id='hard' x='-50%' y='-50%' width='200%' height='200%'>"
                        "<feColorMatrix type='matrix' values='1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 8 0'/></filter>"
                        "</defs><g filter='url(#outer)'><g filter='url(#hard)'>"
                        "<circle cx='18.3' cy='17.7' r='10.2' fill='red' filter='url(#hard)'/>"
                        "<circle cx='44.7' cy='18.1' r='9.3' fill='blue' filter='url(#hard)'/>"
                        "<circle cx='30.2' cy='43.6' r='11.4' fill='green' filter='url(#hard)'/>"
                        "</g></g></svg>";
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:source];
    XCTAssertEqual(svg.renderingOptions.renderQuality, kIJSVGRenderQualityFullResolution);
    NSData* full = [self render:svg size:96 scale:1 flipped:NO blueBackground:NO];
    XCTAssertNotNil(full);
    NSMutableDictionary<NSNumber*, NSData*>* results = [NSMutableDictionary dictionary];
    results[@(kIJSVGRenderQualityFullResolution)] = full;
    for (NSNumber* value in @[ @(kIJSVGRenderQualityOptimized), @(kIJSVGRenderQualityLow), @(kIJSVGRenderQualityFullResolution),
             @(kIJSVGRenderQualityLow), @(kIJSVGRenderQualityOptimized), @(kIJSVGRenderQualityFullResolution) ]) {
        IJSVGRenderQuality quality = value.integerValue;
        IJSVGRenderingOptions* options = svg.renderingOptions;
        options.renderQuality = quality;
        svg.renderingOptions = options;
        NSData* actual = [self render:svg size:96 scale:1 flipped:NO blueBackground:NO];
        XCTAssertNotNil(actual);
        XCTAssertEqualObjects(actual, [self render:svg size:96 scale:1 flipped:NO blueBackground:NO]);
        IJSVG* fresh = [[IJSVG alloc] initWithSVGString:source];
        fresh.renderingOptions = options;
        XCTAssertEqualObjects(actual, [self render:fresh size:96 scale:1 flipped:NO blueBackground:NO]);
        if (results[value] != nil) {
            XCTAssertEqualObjects(actual, results[value]);
        }
        results[value] = actual;
        options.renderQuality = kIJSVGRenderQualityFullResolution;
        XCTAssertEqual(svg.renderingOptions.renderQuality, quality);
    }
    XCTAssertNotEqualObjects(results[@(kIJSVGRenderQualityFullResolution)], results[@(kIJSVGRenderQualityOptimized)]);
    XCTAssertNotEqualObjects(results[@(kIJSVGRenderQualityOptimized)], results[@(kIJSVGRenderQualityLow)]);
}

// Mask and pattern cache replay must follow quality changes and preserve sizing.
- (void)testLowQualityMasksAndPatternsRestoreFullQuality
{
    NSArray<NSString*>* documents = @[
        @"<defs><mask id='m' mask-type='alpha'><circle cx='16.3' cy='15.7' r='12.4' fill='white'/></mask></defs><rect width='32' height='32' fill='red' mask='url(#m)'/>",
        @"<defs><mask id='m' mask-type='luminance'><circle cx='16.3' cy='15.7' r='12.4' fill='#bbb'/></mask></defs><rect width='32' height='32' fill='red' mask='url(#m)'/>",
        @"<defs><pattern id='p' patternUnits='userSpaceOnUse' width='4.3' height='5.7'><circle cx='2.1' cy='2.7' r='1.8' fill='red'/></pattern><filter id='f' x='0' y='0' width='100%' height='100%'><feColorMatrix type='saturate' values='.5'/></filter></defs><rect width='32' height='32' fill='url(#p)' filter='url(#f)'/>"
    ];
    for (NSString* body in documents) {
        NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'><g transform='rotate(7 16 16)'>%@</g></svg>", body];
        for (NSNumber* backingScale in @[ @1, @2 ]) {
            IJSVG* reused = [[IJSVG alloc] initWithSVGString:xml];
            NSData* full = [self render:reused size:95 scale:backingScale.doubleValue flipped:YES blueBackground:NO];
            XCTAssertNotNil(full);
            for (NSNumber* value in @[ @(kIJSVGRenderQualityLow), @(kIJSVGRenderQualityOptimized), @(kIJSVGRenderQualityFullResolution) ]) {
                IJSVGRenderingOptions* options = reused.renderingOptions;
                options.renderQuality = value.integerValue;
                reused.renderingOptions = options;
                NSData* actual = [self render:reused size:95 scale:backingScale.doubleValue flipped:YES blueBackground:NO];
                XCTAssertNotNil(actual);
                XCTAssertEqualObjects(actual, [self render:reused size:95 scale:backingScale.doubleValue flipped:YES blueBackground:NO]);
                IJSVG* fresh = [[IJSVG alloc] initWithSVGString:xml];
                fresh.renderingOptions = options;
                XCTAssertEqualObjects(actual, [self render:fresh size:95 scale:backingScale.doubleValue flipped:YES blueBackground:NO]);
                if (value.integerValue == kIJSVGRenderQualityFullResolution) {
                    XCTAssertEqualObjects(actual, full);
                }
            }
        }
    }
}

- (void)testExplicitInvalidationRefreshesFilteredStyle
{
    IJSVG* reused = [self svgForDocument:0];
    NSData* before = [self render:reused size:64 scale:1 flipped:NO blueBackground:NO];
    reused.style.fillColor = NSColor.blueColor.CGColor;
    [reused setNeedsDisplay];
    NSData* after = [self render:reused size:64 scale:1 flipped:NO blueBackground:NO];
    IJSVG* fresh = [self svgForDocument:0];
    fresh.style.fillColor = NSColor.blueColor.CGColor;
    NSData* expected = [self render:fresh size:64 scale:1 flipped:NO blueBackground:NO];
    XCTAssertNotNil(before);
    XCTAssertNotNil(after);
    XCTAssertNotNil(expected);
    XCTAssertNotEqualObjects(before, after);
    XCTAssertEqualObjects(after, expected);
}

@end

@interface IJSVGSharedCompositeTests : XCTestCase
@end

@implementation IJSVGSharedCompositeTests

- (IJSVG*)svgWithReferenceGraph:(BOOL)reference variant:(NSUInteger)variant
{
    // The unused flood forces the general graph without changing explicit inputs.
    NSString* unused = reference ? @"<feFlood flood-opacity='0' result='unused'/>" : @"";
    NSString* colorSpace = variant % 2 == 0 ? @"linearRGB" : @"sRGB";
    NSString* region = variant < 4 ? @"x='-.1' y='-.1' width='1.2' height='1.2'"
                                   : @"filterUnits='userSpaceOnUse' x='3.25' "
                                     @"y='4.75' width='53.5' height='48.25'";
    NSString* xml = [NSString stringWithFormat:@"<svg enable-background='new' "
                                                "xmlns='http://www.w3.org/2000/svg' width='64' "
                                                "height='64'><defs><linearGradient id='g' x1='0' y1='0' "
                                                "x2='1' y2='1'><stop offset='0' stop-color='#ce3245' "
                                                "stop-opacity='.8'/><stop offset='1' "
                                                "stop-color='#3172df' stop-opacity='.15'/>"
                                                "</linearGradient><filter id='f' %@ "
                                                "color-interpolation-filters='%@'>%@<feComposite "
                                                "in='SourceGraphic' in2='BackgroundImage' "
                                                "operator='arithmetic' k2='1' k3='1'/></filter><clipPath "
                                                "id='c'><ellipse cx='32' cy='32' rx='28.3' ry='25.7'/>"
                                                "</clipPath></defs><g clip-path='url(#c)' "
                                                "transform='translate(.3,.4)'><path d='M5.1 6.3L55.7 "
                                                "13.8L26.2 57.9Z' fill='#305682'/><path d='M5.1 6.3L55.7 "
                                                "13.8L26.2 57.9Z' fill='url(#g)' filter='url(#f)'/>"
                                                "<circle cx='36.4' cy='28.6' r='17.3' fill='#26839e' "
                                                "fill-opacity='.35' filter='url(#f)'/><rect x='12.4' "
                                                "y='15.6' width='31.3' height='22.1' fill='url(#g)' "
                                                "filter='url(#f)'/></g></svg>",
        region, colorSpace, unused];
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml];
    XCTAssertNotNil(svg);
    return svg;
}

- (NSData*)pixelsForSVG:(IJSVG*)svg variant:(NSUInteger)variant step:(NSUInteger)step
{
    if (svg == nil) {
        return nil;
    }
    NSUInteger size = step == 2 ? 93 : 64;
    CGContextRef context = NewBitmap(size, variant == 7 ? kCGColorSpaceDisplayP3 : kCGColorSpaceSRGB);
    XCTAssertTrue(context != NULL);
    if (context == NULL) {
        return nil;
    }
    if (step != 0) {
        CGContextSetRGBFillColor(context, 0.15, step == 1 ? 0.7 : 0.25, 0.45, variant < 4 ? 1 : 0.4);
        CGContextFillRect(context, CGRectMake(0, 0, size, size));
    }
    if (variant == 2 || variant == 6) {
        CGContextTranslateCTM(context, 0, size);
        CGContextScaleCTM(context, 1, -1);
    }
    if (variant == 3) {
        CGContextTranslateCTM(context, 6.25, -2.5);
        CGContextRotateCTM(context, 0.12);
    }
    if (variant == 5) {
        CGContextAddEllipseInRect(context, CGRectMake(2.3, 5.7, 53.4, 48.6));
        CGContextClip(context);
        CGContextSetAlpha(context, 0.65);
    }
    svg.renderingBackingScaleHelper = ^CGFloat {
        return variant == 4 ? 2 : 1;
    };
    [svg drawInRect:CGRectMake(0, 0, size, size) context:context];
    NSData* pixels = BitmapPixels(context, size);
    CGContextRelease(context);
    XCTAssertNotNil(pixels);
    return pixels;
}

- (void)assertSharedMetalOutputMatchesGeneralGraphForVariant:(NSUInteger)variant
{
    IJSVG* actual = [self svgWithReferenceGraph:NO variant:variant];
    IJSVG* reference = [self svgWithReferenceGraph:YES variant:variant];
    for (NSNumber* step in @[ @0, @1, @1, @2, @0 ]) {
        NSData* result = [self pixelsForSVG:actual variant:variant step:step.unsignedIntegerValue];
        NSData* expected = [self pixelsForSVG:reference variant:variant step:step.unsignedIntegerValue];
        XCTAssertNotNil(result);
        XCTAssertNotNil(expected);
        XCTAssertTrue([result isEqualToData:expected], @"variant %lu, step %@", (unsigned long)variant, step);
    }
}

- (void)assertSIMDAdditionMatchesGeneralGraphWithLinearRGB:(BOOL)linear narrowRegion:(BOOL)narrow
{
    [self assertSIMDPrimitive:@"<feComposite in='SourceGraphic' in2='BackgroundImage' "
                               "operator='arithmetic' k2='1' k3='1'/>"
                    linearRGB:linear
                 narrowRegion:narrow];
}

- (void)assertSIMDPrimitive:(NSString*)primitive linearRGB:(BOOL)linear narrowRegion:(BOOL)narrow
{
    NSString* region = narrow ? @"filterUnits='userSpaceOnUse' x='21.2' y='17.3' "
                                @"width='.4' height='.6'"
                              : @"x='-.1' y='-.1' width='1.2' height='1.2'";
    for (NSNumber* scaleValue in @[ @1, @2, @3 ]) {
        NSUInteger scale = scaleValue.unsignedIntegerValue;
        for (NSNumber* flippedValue in @[ @0, @1, @2, @3 ]) {
            NSMutableArray<NSData*>* renders = [NSMutableArray array];
            for (NSNumber* reference in @[ @NO, @YES ]) {
                NSString* unused = reference.boolValue ? @"<feFlood flood-opacity='0' result='unused'/>" : @"";
                NSMutableString* xml = [NSMutableString stringWithFormat:@"<svg enable-background='new' "
                                                                          "xmlns='http://www.w3.org/2000"
                                                                          "/svg' width='64' height='64'>"
                                                                          "<defs><filter id='f' %@ "
                                                                          "color-interpolation-filters='"
                                                                          "%@'>%@%@</filter></defs><rect "
                                                                          "width='64' height='64' "
                                                                          "fill='#21486b' "
                                                                          "fill-opacity='.4'/>",
                    region, linear ? @"linearRGB" : @"sRGB", unused, primitive];
                for (NSUInteger index = 0; index < 24; index++) {
                    [xml appendFormat:@"<rect x='%g' y='%g' width='10.4' height='10.7' "
                                      @"fill='#%06lx' "
                                       "fill-opacity='%g' filter='url(#f)'/>",
                        narrow ? 16. : (index % 6) * 8., narrow ? 12. : (index / 6) * 12., (unsigned long)((index * 97531 + 0x304020) & 0xffffff), .2 + (index % 5) * .15];
                }
                [xml appendString:@"</svg>"];
                IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml];
                XCTAssertNotNil(svg);
                NSUInteger size = 64 * scale;
                CGContextRef bitmap = NewBitmap(size, kCGColorSpaceSRGB);
                XCTAssertTrue(bitmap != NULL);
                if (bitmap == NULL) {
                    return;
                }
                if ((flippedValue.unsignedIntegerValue & 2) != 0) {
                    CGContextTranslateCTM(bitmap, size, 0);
                    CGContextScaleCTM(bitmap, -1, 1);
                }
                if ((flippedValue.unsignedIntegerValue & 1) != 0) {
                    CGContextTranslateCTM(bitmap, 0, size);
                    CGContextScaleCTM(bitmap, 1, -1);
                }
                CGContextScaleCTM(bitmap, scale, scale);
                svg.renderingBackingScaleHelper = ^CGFloat {
                    return scale;
                };
                [svg drawInRect:CGRectMake(0, 0, 64, 64) context:bitmap];
                [renders addObject:BitmapPixels(bitmap, size)];
                CGContextRelease(bitmap);
            }
            XCTAssertEqualObjects(renders[0], renders[1], @"scale %@, flipped %@", scaleValue, flippedValue);
        }
    }
}

- (void)testFractionalBackdropAdditionPreservesCheckerboard
{
    for (NSNumber* scaleValue in @[ @1, @2, @3 ]) {
        NSUInteger scale = scaleValue.unsignedIntegerValue;
        for (NSNumber* offset in @[ @0.25, @0.5, @0.75 ]) {
            for (NSNumber* flip in @[ @0, @1, @2, @3 ]) {
                NSMutableArray<NSData*>* renders = [NSMutableArray array];
                for (NSNumber* filtered in @[ @NO, @YES ]) {
                    NSMutableString* xml = [NSMutableString stringWithString:@"<svg "
                                                                              "enable-background='new' "
                                                                              "xmlns='http://www.w3.org/"
                                                                              "2000/svg' width='32' "
                                                                              "height='32'><defs><filter "
                                                                              "id='f' "
                                                                              "color-interpolation-filte"
                                                                              "rs='sRGB'><feComposite "
                                                                              "in='SourceGraphic' "
                                                                              "in2='BackgroundImage' "
                                                                              "operator='arithmetic' "
                                                                              "k2='1' k3='1'/></filter>"
                                                                              "</defs><rect width='32' "
                                                                              "height='32' "
                                                                              "fill='#123456'/>"];
                    for (NSUInteger y = 0; y < 16; y++) {
                        for (NSUInteger x = 0; x < 16; x++) {
                            if ((x + y) % 2 == 0) {
                                [xml appendFormat:@"<rect x='%lu' y='%lu' width='2' height='2' "
                                                   "fill='#cdefab'/>",
                                    (unsigned long)(x * 2), (unsigned long)(y * 2)];
                            }
                        }
                    }
                    [xml appendFormat:@"<rect x='7' y='7' width='18' height='18' "
                                      @"fill-opacity='0' %@/>"
                                       "</svg>",
                        filtered.boolValue ? @"filter='url(#f)'" : @""];
                    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml];
                    XCTAssertNotNil(svg);
                    NSUInteger size = 40 * scale;
                    CGContextRef bitmap = NewBitmap(size, kCGColorSpaceSRGB);
                    XCTAssertTrue(bitmap != NULL);
                    if (bitmap == NULL) {
                        return;
                    }
                    if ((flip.unsignedIntegerValue & 1) != 0) {
                        CGContextTranslateCTM(bitmap, size, 0);
                        CGContextScaleCTM(bitmap, -1, 1);
                    }
                    if ((flip.unsignedIntegerValue & 2) != 0) {
                        CGContextTranslateCTM(bitmap, 0, size);
                        CGContextScaleCTM(bitmap, 1, -1);
                    }
                    CGContextScaleCTM(bitmap, scale, scale);
                    CGContextTranslateCTM(bitmap, 2 + offset.doubleValue, 2 + offset.doubleValue);
                    svg.renderingBackingScaleHelper = ^CGFloat {
                        return scale;
                    };
                    [svg drawInRect:CGRectMake(0, 0, 32, 32) context:bitmap];
                    [renders addObject:BitmapPixels(bitmap, size)];
                    CGContextRelease(bitmap);
                }

                // Transparent black addition must not resample the backdrop.
                // Ignore the outer artwork edge, the filter is wholly inside it.
                const uint8_t* expected = [renders[0] bytes];
                const uint8_t* actual = [renders[1] bytes];
                NSUInteger maximum = 0;
                for (NSUInteger y = 9 * scale; y < 25 * scale; y++) {
                    for (NSUInteger x = 9 * scale; x < 25 * scale; x++) {
                        for (NSUInteger channel = 0; channel < 4; channel++) {
                            NSUInteger index = (y * 40 * scale + x) * 4 + channel;
                            maximum = MAX(maximum, abs(actual[index] - expected[index]));
                        }
                    }
                }
                XCTAssertLessThanOrEqual(maximum, 1u, @"scale %@ offset %@ flip %@", scaleValue, offset, flip);
            }
        }
    }
}

- (void)testLinearEncodingMatchesOriginalByteRounding
{
    uint32_t state = 0x12345678;
    NSUInteger mismatches = 0;
    for (NSUInteger index = 0; index < 1000000; index++) {
        state = state * 1664525u + 1013904223u;
        float alpha = (state >> 16) / 65535.f;
        state = state * 1664525u + 1013904223u;
        float component = alpha * ((state >> 16) / 65535.f);
        state = state * 1664525u + 1013904223u;
        float coverage = (state >> 16) / 65535.f;
        float straight = alpha > 0 ? component / alpha : 0;
        float encoded = straight <= .0031308f ? straight * 12.92f : 1.055f * powf(straight, 1.f / 2.4f) - .055f;
        uint8_t expected = (uint8_t)lrintf(fminf(255.f, fmaxf(0.f, (encoded * alpha) * (coverage * 255.f))));
        uint8_t actual = IJSVGFilterSIMDEncodeLinearComponent(component, alpha, coverage);
        mismatches += actual != expected;
    }
    for (NSNumber* alphaValue in @[ @0.01, @0.25, @0.5, @1 ]) {
        float alpha = alphaValue.floatValue;
        for (NSNumber* coverageValue in @[ @0.1, @0.5, @1 ]) {
            float coverage = coverageValue.floatValue;
            for (NSUInteger byte = 0; byte < 255; byte++) {
                float srgb = (byte + .5f) / (alpha * coverage * 255.f);
                if (srgb >= 1.f) {
                    continue;
                }
                float linear = srgb <= .04045f ? srgb / 12.92f : powf((srgb + .055f) / 1.055f, 2.4f);
                for (NSNumber* direction in @[ @(-1), @0, @1 ]) {
                    float nearby = direction.intValue == 0 ? linear : nextafterf(linear, direction.intValue < 0 ? 0.f : 1.f);
                    float component = nearby * alpha;
                    float straight = component / alpha;
                    float encoded = straight <= .0031308f ? straight * 12.92f : 1.055f * powf(straight, 1.f / 2.4f) - .055f;
                    uint8_t expected = (uint8_t)lrintf((encoded * alpha) * (coverage * 255.f));
                    mismatches += IJSVGFilterSIMDEncodeLinearComponent(component, alpha, coverage) != expected;
                }
            }
        }
    }
    XCTAssertEqual(mismatches, 0u);
    XCTAssertEqual(IJSVGFilterSIMDEncodeLinearComponent(0, 0, 1), 0);
    XCTAssertEqual(IJSVGFilterSIMDEncodeLinearComponent(1, 1, 1), 255);
}

- (void)testSIMDBlendNormalMatchesGeneralGraph
{
    NSString* primitive = @"<feBlend in='SourceGraphic' in2='BackgroundImage' mode='normal'/>";
    for (NSNumber* linear in @[ @NO, @YES ]) {
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:NO];
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:YES];
    }
}

- (void)testSIMDBlendMultiplyMatchesGeneralGraph
{
    NSString* primitive = @"<feBlend in='SourceGraphic' in2='BackgroundImage' mode='multiply'/>";
    for (NSNumber* linear in @[ @NO, @YES ]) {
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:NO];
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:YES];
    }
}

- (void)testSIMDBlendScreenMatchesGeneralGraph
{
    NSString* primitive = @"<feBlend in='SourceGraphic' in2='BackgroundImage' mode='screen'/>";
    for (NSNumber* linear in @[ @NO, @YES ]) {
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:NO];
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:YES];
    }
}

- (void)testSIMDBlendDarkenMatchesGeneralGraph
{
    NSString* primitive = @"<feBlend in='SourceGraphic' in2='BackgroundImage' mode='darken'/>";
    for (NSNumber* linear in @[ @NO, @YES ]) {
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:NO];
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:YES];
    }
}

- (void)testSIMDBlendLightenMatchesGeneralGraph
{
    NSString* primitive = @"<feBlend in='SourceGraphic' in2='BackgroundImage' mode='lighten'/>";
    for (NSNumber* linear in @[ @NO, @YES ]) {
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:NO];
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:YES];
    }
}

- (void)testSIMDCompositeOverMatchesGeneralGraph
{
    NSString* primitive = @"<feComposite in='SourceGraphic' "
                          @"in2='BackgroundImage' operator='over'/>";
    for (NSNumber* linear in @[ @NO, @YES ]) {
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:NO];
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:YES];
    }
}

- (void)testSIMDCompositeInMatchesGeneralGraph
{
    NSString* primitive = @"<feComposite in='SourceGraphic' in2='BackgroundImage' operator='in'/>";
    for (NSNumber* linear in @[ @NO, @YES ]) {
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:NO];
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:YES];
    }
}

- (void)testSIMDCompositeOutMatchesGeneralGraph
{
    NSString* primitive = @"<feComposite in='SourceGraphic' in2='BackgroundImage' operator='out'/>";
    for (NSNumber* linear in @[ @NO, @YES ]) {
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:NO];
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:YES];
    }
}

- (void)testSIMDCompositeAtopMatchesGeneralGraph
{
    NSString* primitive = @"<feComposite in='SourceGraphic' "
                          @"in2='BackgroundImage' operator='atop'/>";
    for (NSNumber* linear in @[ @NO, @YES ]) {
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:NO];
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:YES];
    }
}

- (void)testSIMDCompositeXorMatchesGeneralGraph
{
    NSString* primitive = @"<feComposite in='SourceGraphic' in2='BackgroundImage' operator='xor'/>";
    for (NSNumber* linear in @[ @NO, @YES ]) {
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:NO];
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:YES];
    }
}

- (void)testSIMDCompositeLighterMatchesGeneralGraph
{
    NSString* primitive = @"<feComposite in='SourceGraphic' "
                          @"in2='BackgroundImage' operator='lighter'/>";
    for (NSNumber* linear in @[ @NO, @YES ]) {
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:NO];
        [self assertSIMDPrimitive:primitive linearRGB:linear.boolValue narrowRegion:YES];
    }
}

- (void)testSIMDLinearAdditionMatchesGeneralGraph
{
    [self assertSIMDAdditionMatchesGeneralGraphWithLinearRGB:YES narrowRegion:NO];
}

- (void)testSIMDSRGBAdditionMatchesGeneralGraph
{
    [self assertSIMDAdditionMatchesGeneralGraphWithLinearRGB:NO narrowRegion:NO];
}

- (void)testSIMDSubpixelCropMatchesGeneralGraph
{
    [self assertSIMDAdditionMatchesGeneralGraphWithLinearRGB:YES narrowRegion:YES];
}

- (void)testSharedMetalLinearRGBMatchesGeneralGraph
{
    [self assertSharedMetalOutputMatchesGeneralGraphForVariant:0];
}

- (void)testSharedMetalSRGBMatchesGeneralGraph
{
    [self assertSharedMetalOutputMatchesGeneralGraphForVariant:1];
}

- (void)testSharedMetalFlippedMatchesGeneralGraph
{
    [self assertSharedMetalOutputMatchesGeneralGraphForVariant:2];
}

- (void)testSharedMetalRotatedMatchesGeneralGraph
{
    [self assertSharedMetalOutputMatchesGeneralGraphForVariant:3];
}

- (void)testSharedMetalBackingScaleMatchesGeneralGraph
{
    [self assertSharedMetalOutputMatchesGeneralGraphForVariant:4];
}

- (void)testSharedMetalClipAndAlphaMatchesGeneralGraph
{
    [self assertSharedMetalOutputMatchesGeneralGraphForVariant:5];
}

- (void)testSharedMetalFlippedUserSpaceMatchesGeneralGraph
{
    [self assertSharedMetalOutputMatchesGeneralGraphForVariant:6];
}

- (void)testSharedMetalDisplayP3MatchesGeneralGraph
{
    [self assertSharedMetalOutputMatchesGeneralGraphForVariant:7];
}

- (void)testConcurrentSharedBuffersMatchGeneralGraph
{
    XCTestExpectation* finished = [self expectationWithDescription:@"Concurrent composite renders"];
    finished.expectedFulfillmentCount = 8;
    for (NSUInteger variant = 0; variant < 8; variant++) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @autoreleasepool {
                IJSVG* actual = [self svgWithReferenceGraph:NO variant:variant];
                IJSVG* reference = [self svgWithReferenceGraph:YES variant:variant];
                for (NSUInteger step = 0; step < 3; step++) {
                    NSData* result = [self pixelsForSVG:actual variant:variant step:step];
                    NSData* expected = [self pixelsForSVG:reference variant:variant step:step];
                    XCTAssertNotNil(result);
                    XCTAssertNotNil(expected);
                    XCTAssertTrue([result isEqualToData:expected], @"variant %lu, step %lu", (unsigned long)variant, (unsigned long)step);
                }
            }
            [finished fulfill];
        });
    }
    [self waitForExpectationsWithTimeout:60 handler:nil];
}

@end

@interface IJSVGLocalFilterTests : XCTestCase
@end

@implementation IJSVGLocalFilterTests

- (void)testLocalOffsetsAndAlphaRespectCropStrideAndVectorTails
{
    for (NSNumber* widthValue in @[ @1, @2, @3, @5, @7, @17 ]) {
        NSInteger width = widthValue.integerValue, height = 9;
        size_t stride = width * 4 + 12;
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, stride, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space);
        XCTAssertNotEqual(bitmap, NULL);
        if (bitmap == NULL) {
            continue;
        }
        uint8_t* source = CGBitmapContextGetData(bitmap);
        for (NSInteger y = 0; y < height; y++) {
            for (NSInteger x = 0; x < width; x++) {
                uint8_t* pixel = source + y * stride + x * 4;
                pixel[3] = (x * 37 + y * 19) % 256;
                pixel[0] = pixel[3] / 2;
                pixel[1] = pixel[3] / 3;
                pixel[2] = pixel[3] / 4;
            }
        }
        for (NSValue* rect in @[ [NSValue valueWithRect:NSMakeRect(0, 0, width, height)],
                 [NSValue valueWithRect:NSMakeRect(-2, 1, width + 1, 6)],
                 [NSValue valueWithRect:NSMakeRect(width + 5, 0, 2, 2)],
                 [NSValue valueWithRect:NSMakeRect(-1e12, -1e12, 2e12, 2e12)] ]) {
            CGRect crop = rect.rectValue;
            for (NSNumber* shift in @[ @0, @1, @-2, @32, @-32 ]) {
                NSInteger dx = shift.integerValue, dy = -dx;
                for (NSString* input in @[ @"SourceGraphic", @"SourceAlpha" ]) {
                    NSString* recipe = [NSString stringWithFormat:
                            @"<feOffset in='%@' dx='%ld' dy='%ld' result='shift'/>"
                             "<feComposite in='shift' in2='SourceAlpha' operator='in'/>",
                        input, (long)dx, (long)dy];
                    IJSVGFilterGraph* graph = [self graphForRecipe:recipe space:@"sRGB"];
                    CGImageRef image = IJSVGFilterSIMDNewLocalFilter(bitmap, graph, crop);
                    XCTAssertNotEqual(image, NULL);
                    if (image == NULL) {
                        continue;
                    }
                    NSData* data = CFBridgingRelease(CGDataProviderCopyData(CGImageGetDataProvider(image)));
                    const uint8_t* actual = data.bytes;
                    size_t actualStride = CGImageGetBytesPerRow(image);
                    for (NSInteger y = 0; y < height; y++) {
                        for (NSInteger x = 0; x < width; x++) {
                            NSInteger sx = x - dx, sy = y + dy;
                            BOOL inside = CGRectContainsPoint(crop, CGPointMake(x + .5, height - y - .5))
                                && sx >= 0 && sx < width && sy >= 0 && sy < height
                                && CGRectContainsPoint(crop, CGPointMake(sx + .5, height - sy - .5));
                            for (NSUInteger c = 0; c < 4; c++) {
                                double expected = 0;
                                if (inside && (c == 3 || [input isEqualToString:@"SourceGraphic"])) {
                                    expected = source[sy * stride + sx * 4 + c] * source[y * stride + x * 4 + 3] / 255.;
                                }
                                XCTAssertEqualWithAccuracy(actual[y * actualStride + x * 4 + c], expected, 1.01);
                            }
                        }
                    }
                    CGImageRelease(image);
                }
            }
        }
        CGContextRelease(bitmap);
    }
}

- (IJSVGFilterGraph*)graphForRecipe:(NSString*)recipe space:(NSString*)space
{
    NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' "
                                                "height='32'><defs><filter id='f' "
                                                "filterUnits='userSpaceOnUse' x='2' y='3' width='28' "
                                                "height='26' color-interpolation-filters='%@'>%@</filter>"
                                                "</defs><rect width='32' height='32' filter='url(#f)'/>"
                                                "</svg>",
        space, recipe];
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:xml fileURL:nil error:NULL];
    IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(32, 32)];
    IJSVGFilterGraph* graph = [[IJSVGFilterGraph alloc] init];
    graph.filter = ((IJSVGGraphicsNode*)root.children.firstObject).filter;
    graph.boundingBox = graph.viewPort = graph.extent = CGRectMake(0, 0, 32, 32);
    graph.imageTransform = CGAffineTransformIdentity;
    XCTAssertNotNil(graph.filter);
    return graph;
}

- (void)assertRecipe:(NSString*)recipe space:(NSString*)space
{
    IJSVGFilterGraph* graph = [self graphForRecipe:recipe space:space];
    CGContextRef bitmap = NewBitmap(32, kCGColorSpaceSRGB);
    uint8_t* bytes = CGBitmapContextGetData(bitmap);
    uint32_t state = 1234567;
    for (NSUInteger i = 0; i < 32 * 32; i++) {
        state = state * 1664525u + 1013904223u;
        uint8_t alpha = state >> 24;
        for (NSUInteger c = 0; c < 3; c++) {
            state = state * 1664525u + 1013904223u;
            bytes[i * 4 + c] = (state >> 24) * alpha / 255;
        }
        bytes[i * 4 + 3] = alpha;
    }
    NSData* original = BitmapPixels(bitmap, 32);
    CGImageRef fast = IJSVGFilterSIMDNewLocalFilter(bitmap, graph, CGRectMake(2, 3, 28, 26));
    XCTAssertTrue(fast != NULL, @"%@ %@", recipe, space);
    if (fast != NULL) {
        CGContextRef actual = NewBitmap(32, kCGColorSpaceSRGB);
        CGContextDrawImage(actual, graph.extent, fast);
        CGImageRef source = CGBitmapContextCreateImage(bitmap);
        CIImage* expected = [graph imageByFilteringSource:[CIImage imageWithCGImage:source]];
        NSMutableData* reference = [NSMutableData dataWithLength:32 * 32 * 4];
        CIContext* context = [CIContext contextWithOptions:@{ kCIContextCacheIntermediates : @NO }];
        [context render:expected toBitmap:reference.mutableBytes rowBytes:32 * 4 bounds:graph.extent format:kCIFormatRGBA8 colorSpace:CGBitmapContextGetColorSpace(bitmap)];
        const uint8_t* a = CGBitmapContextGetData(actual);
        const uint8_t* b = reference.bytes;
        NSUInteger maximum = 0;
        for (NSUInteger i = 0; i < reference.length; i++) {
            maximum = MAX(maximum, (NSUInteger)abs(a[i] - b[i]));
        }
        XCTAssertLessThanOrEqual(maximum, 2u, @"%@ %@", recipe, space);
        CGContextRelease(actual);
        CGImageRelease(source);
        CGImageRelease(fast);
    }
    XCTAssertEqualObjects(original, BitmapPixels(bitmap, 32));
    CGContextRelease(bitmap);
}

- (void)testPreparedParametersInvalidateAndCopiesRemainIndependent
{
    IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
    NSMutableDictionary<NSString*, NSString*>* attributes = [@{ @"values" : @".25 .75", @"dx" : @"invalid" } mutableCopy];
    primitive.parameters = attributes;
    NSArray<NSNumber*>* numbers = [primitive numbersForParameter:@"values"];
    XCTAssertEqual(numbers, [primitive numbersForParameter:@"values"]);
    XCTAssertEqualObjects(numbers, (@[ @.25, @.75 ]));
    XCTAssertEqual([primitive numberForParameter:@"dx" defaultValue:9], 9);
    attributes[@"values"] = @"5";
    XCTAssertEqualObjects([primitive numbersForParameter:@"values"], numbers);
    IJSVGFilterPrimitive* copy = primitive.copy;
    primitive.parameters = @{ @"values" : @"2" };
    XCTAssertEqual([primitive numberForParameter:@"values" defaultValue:0], 2);
    XCTAssertEqualObjects([copy numbersForParameter:@"values"], numbers);
    NSDictionary<NSString*, NSString*>* first = [primitive preparedValueForKey:@"test"
                                                                       builder:^id {
                                                                           return primitive.parameters;
                                                                       }];
    primitive.parameters = @{ @"type" : @"hueRotate", @"values" : @"45" };
    NSDictionary<NSString*, NSString*>* second = [primitive preparedValueForKey:@"test"
                                                                        builder:^id {
                                                                            return primitive.parameters;
                                                                        }];
    XCTAssertNotEqualObjects(first, second);
    dispatch_apply(32, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        XCTAssertEqualObjects([primitive preparedValueForKey:@"test"
                                                     builder:^id {
                                                         return primitive.parameters;
                                                     }],
            second);
    });
    primitive.parameters = nil;
    XCTAssertEqualObjects([primitive numbersForParameter:@"values"], @[]);
}

- (void)testEmptyParametersRestoreFilterDefaults
{
    IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
    IJSVGFilterPrimitive* defaults = [[IJSVGFilterPrimitive alloc] init];
    NSArray<NSString*>* types = @[ @"hueRotate", @"gamma", @"fractalNoise" ];
    for (NSString* type in types) {
        for (NSString* operation in @[ @"arithmetic", @"dilate" ]) {
            for (NSUInteger reset = 0; reset < 2; reset++) {
                primitive.parameters = @{ @"type" : type, @"operator" : operation, @"edgeMode" : @"wrap", @"xChannelSelector" : @"R", @"yChannelSelector" : @"G", @"mode" : @"multiply", @"preserveAlpha" : @"true", @"stitchTiles" : @"stitch", @"values" : @"7" };
                XCTAssertTrue(primitive.preserveAlpha);
                XCTAssertTrue(primitive.stitchTiles);
                XCTAssertEqual([primitive numberForParameter:@"values" defaultValue:0], 7);
                [primitive preparedValueForKey:@"reset"
                                       builder:^id {
                                           return @"before";
                                       }];
                primitive.parameters = reset == 0 ? [[NSDictionary alloc] init] : nil;
                XCTAssertEqual(primitive.compositeOperator, defaults.compositeOperator);
                XCTAssertEqual(primitive.edgeMode, defaults.edgeMode);
                XCTAssertEqual(primitive.colorMatrixType, defaults.colorMatrixType);
                XCTAssertEqual(primitive.transferType, defaults.transferType);
                XCTAssertEqual(primitive.morphologyOperator, defaults.morphologyOperator);
                XCTAssertEqual(primitive.turbulenceType, defaults.turbulenceType);
                XCTAssertEqual(primitive.xChannel, defaults.xChannel);
                XCTAssertEqual(primitive.yChannel, defaults.yChannel);
                XCTAssertEqual(primitive.filterBlendMode, defaults.filterBlendMode);
                XCTAssertFalse(primitive.preserveAlpha);
                XCTAssertFalse(primitive.stitchTiles);
                XCTAssertEqual([primitive numberForParameter:@"values" defaultValue:3], 3);
                XCTAssertEqualObjects([primitive preparedValueForKey:@"reset"
                                                             builder:^id {
                                                                 return @"after";
                                                             }],
                    @"after");
                primitive.type = IJSVGNodeTypeFilterConvolveMatrix;
                defaults.type = primitive.type;
                XCTAssertEqual(primitive.edgeMode, defaults.edgeMode);
            }
        }
    }
}

- (void)testColorMatricesMatchGeneralEvaluator
{
    for (NSString* space in @[ @"sRGB", @"linearRGB" ]) {
        for (NSString* recipe in @[ @"<feColorMatrix/>", @"<feColorMatrix type='saturate' values='.35'/>", @"<feColorMatrix type='hueRotate' values='137'/>", @"<feColorMatrix type='luminanceToAlpha'/>", @"<feColorMatrix values='1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 .37 0'/>", @"<feColorMatrix values='.5 .2 0 .1 .03 0 .7 .1 0 -.1 .2 0 .6 .1 .02 .1 .2 0 .6 .1'/>", @"<feColorMatrix values='2 -.4 .1 0 .1 .1 .2 .3 0 0 0 .2 .6 0 0 0 0 0 2 0'/>" ]) {
            [self assertRecipe:recipe space:space];
        }
    }
}

- (void)testQuartzCompositesMatchGeneralEvaluator
{
    for (NSString* operation in @[ @"over", @"in", @"out", @"atop", @"xor" ]) {
        for (NSString* first in @[ @"SourceGraphic", @"SourceAlpha", @"shift", @"" ]) {
            NSString* recipe = [NSString stringWithFormat:@"<feOffset in='SourceAlpha' dx='3' dy='-2' "
                                                           "result='shift'/><feComposite in='%@' "
                                                           "in2='shift' operator='%@'/>",
                first, operation];
            [self assertRecipe:recipe space:@"sRGB"];
        }
        [self assertRecipe:[NSString stringWithFormat:@"<feComposite in='SourceGraphic' "
                                                       "in2='SourceAlpha' operator='%@'/>",
                               operation]
                     space:@"sRGB"];
    }
}

- (void)testUnsupportedLocalFiltersFallBackWithoutChangingSource
{
    CGContextRef bitmap = NewBitmap(32, kCGColorSpaceSRGB);
    CGContextSetRGBFillColor(bitmap, .3, .5, .8, .5);
    CGContextFillRect(bitmap, CGRectMake(0, 0, 32, 32));
    NSData* original = BitmapPixels(bitmap, 32);
    for (NSString* recipe in @[ @"<feComposite in='SourceGraphic' in2='BackgroundImage'/>", @"<feComposite operator='arithmetic' k2='1'/>", @"<feOffset dx='.5' result='s'/><feComposite in2='s'/>", @"<feColorMatrix x='1'/>", @"<feColorMatrix values='1 2 3'/>", @"<feColorMatrix in='SourceAlpha'/>" ]) {
        IJSVGFilterGraph* graph = [self graphForRecipe:recipe space:@"sRGB"];
        CGImageRef image = IJSVGFilterSIMDNewLocalFilter(bitmap, graph, CGRectMake(2, 3, 28, 26));
        XCTAssertTrue(image == NULL, @"%@", recipe);
        if (image != NULL) {
            CGImageRelease(image);
        }
    }
    IJSVGFilterGraph* graph = [self graphForRecipe:@"<feComposite/>" space:@"linearRGB"];
    XCTAssertTrue(IJSVGFilterSIMDNewLocalFilter(bitmap, graph, CGRectMake(2, 3, 28, 26)) == NULL);
    graph = [self graphForRecipe:@"<feColorMatrix/>" space:@"sRGB"];
    XCTAssertTrue(IJSVGFilterSIMDNewLocalFilter(bitmap, graph, CGRectMake(2.5, 3, 28, 26)) == NULL);
    XCTAssertEqualObjects(original, BitmapPixels(bitmap, 32));
    CGContextRelease(bitmap);
}

@end
