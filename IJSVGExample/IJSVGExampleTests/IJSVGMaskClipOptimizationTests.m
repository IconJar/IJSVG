//
//  IJSVGMaskClipOptimizationTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterTestHelpers.h>
#import <IJSVGFilterGraph.h>

@interface IJSVGMaskClipOptimizationTests : XCTestCase
@end

@implementation IJSVGMaskClipOptimizationTests

- (IJSVGFilterGraph*)graphWithMatrix:(NSString*)matrix
                              input:(NSString*)input
                             region:(NSString*)region
                          primitive:(NSString*)primitive
                         colorSpace:(NSString*)colorSpace
{
    NSString* xml = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='96' height='96'>"
         "<defs><filter id='f' filterUnits='userSpaceOnUse' %@ "
         "color-interpolation-filters='%@'><feColorMatrix type='matrix' "
         "values='%@' in='%@' %@/></filter></defs>"
         "<rect width='96' height='96' filter='url(#f)'/></svg>",
        region, colorSpace, matrix, input, primitive];
    IJSVG* svg = IJSVGTestSVGObject(xml);
    IJSVGFilterGraph* graph = [[IJSVGFilterGraph alloc] init];
    graph.filter = svg.rootNode.children.firstObject.filters.firstObject;
    graph.viewPort = graph.boundingBox = graph.extent = CGRectMake(0, 0, 96, 96);
    graph.imageTransform = CGAffineTransformIdentity;
    graph.hasNestedFilters = YES;
    XCTAssertNotNil(graph.filter);
    return graph;
}

- (NSData*)pixelsForImage:(CGImageRef)image
{
    CGContextRef bitmap = [self newBitmapWithSize:96 flipped:NO];
    CGContextDrawImage(bitmap, CGRectMake(0, 0, 96, 96), image);
    NSData* data = [NSData dataWithBytes:CGBitmapContextGetData(bitmap) length:96 * 96 * 4];
    CGContextRelease(bitmap);
    return data;
}

- (void)testWhiteAlphaMatchesCoreImageWithFractionalCrops
{
    CGContextRef bitmap = [self newBitmapWithSize:96 flipped:NO];
    uint8_t* bytes = CGBitmapContextGetData(bitmap);
    for(NSUInteger index = 0; index < 96 * 96; index++) {
        uint8_t alpha = index % 256;
        bytes[index * 4] = alpha / 2;
        bytes[index * 4 + 1] = alpha / 3;
        bytes[index * 4 + 2] = alpha / 4;
        bytes[index * 4 + 3] = alpha;
    }
    NSData* unchanged = [NSData dataWithBytes:bytes length:96 * 96 * 4];
    for(NSString* colorSpace in @[@"sRGB", @"linearRGB"]) {
        for(NSString* input in @[@"SourceGraphic", @"SourceAlpha", @""]) {
            for(NSString* primitive in @[@"", @"x='7.25' y='9.75' width='54.5' height='63.125'"]) {
                IJSVGFilterGraph* graph = [self graphWithMatrix:@"0 0 0 0 1 0 0 0 0 1 0 0 0 0 1 0 0 0 1 0"
                    input:input region:@"x='2.25' y='3.5' width='85.25' height='87.75'"
                    primitive:primitive colorSpace:colorSpace];
                CGImageRef actual = [graph newCGImageForWhiteAlpha:bitmap];
                XCTAssertNotEqual(actual, NULL);
                if(actual == NULL) {
                    continue;
                }
                CGImageRef source = CGBitmapContextCreateImage(bitmap);
                [IJSVGThreadManager performBlockWithCIContext:^(CIContext* context, BOOL supportsMetalKernels) {
                    graph.context = context;
                    graph.supportsMetalKernels = supportsMetalKernels;
                    CIImage* result = [graph imageByFilteringSource:[CIImage imageWithCGImage:source]];
                    CGImageRef expected = [context createCGImage:result fromRect:graph.extent
                        format:kCIFormatRGBA8 colorSpace:CGBitmapContextGetColorSpace(bitmap)];
                    XCTAssertNotEqual(expected, NULL);
                    if(expected != NULL) {
                        XCTAssertLessThanOrEqual([self maximumDifference:[self pixelsForImage:actual]
                            other:[self pixelsForImage:expected]], 1, @"%@ %@ %@", colorSpace, input, primitive);
                        CGImageRelease(expected);
                    }
                }];
                CGImageRelease(source);
                CGImageRelease(actual);
            }
        }
    }
    XCTAssertEqualObjects(unchanged, [NSData dataWithBytes:bytes length:96 * 96 * 4]);
    CGContextRelease(bitmap);
}

- (void)testOtherMatricesAndInputsKeepGeneralEvaluation
{
    CGContextRef bitmap = [self newBitmapWithSize:96 flipped:NO];
    NSArray<NSString*>* matrices = @[
        @"1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 1 0",
        @"0 0 0 0 .9 0 0 0 0 1 0 0 0 0 1 0 0 0 1 0",
        @"0 0 0 0 1 0 0 0 0 1 0 0 0 0 1 0 0 0 .5 0",
        @"0 0 0 0 1 0 0 0 0 1 0 0 0 0 1 0 0 0 1 .1"
    ];
    for(NSString* matrix in matrices) {
        IJSVGFilterGraph* graph = [self graphWithMatrix:matrix input:@"SourceGraphic"
            region:@"x='0' y='0' width='96' height='96'" primitive:@"" colorSpace:@"sRGB"];
        CGImageRef image = [graph newCGImageForWhiteAlpha:bitmap];
        XCTAssertEqual(image, NULL);
        CGImageRelease(image);
    }
    for(NSString* input in @[@"BackgroundImage", @"BackgroundAlpha", @"FillPaint", @"StrokePaint", @"missing"]) {
        IJSVGFilterGraph* graph = [self graphWithMatrix:@"0 0 0 0 1 0 0 0 0 1 0 0 0 0 1 0 0 0 1 0"
            input:input region:@"x='0' y='0' width='96' height='96'" primitive:@"" colorSpace:@"sRGB"];
        CGImageRef image = [graph newCGImageForWhiteAlpha:bitmap];
        XCTAssertEqual(image, NULL);
        CGImageRelease(image);
    }
    CGContextRelease(bitmap);
}

- (NSArray<IJSVGPaint*>*)clipsInPaint:(IJSVGPaint*)root
{
    NSMutableArray<IJSVGPaint*>* clips = [[NSMutableArray alloc] init];
    NSMutableArray<IJSVGPaint*>* pending = [NSMutableArray arrayWithObject:root];
    while(pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        if(paint.clipPath != NULL && paint.sourceNode.clipPath != nil) {
            [clips addObject:paint];
        }
        [pending addObjectsFromArray:paint.children];
    }
    return clips;
}

- (void)testRepeatedClipsSharePathsAndRebuildAfterMutation
{
    IJSVG* svg = IJSVGTestSVGObject(
        @"<svg xmlns='http://www.w3.org/2000/svg' width='96' height='96'>"
         "<defs><clipPath id='a'><path d='M4 4H70V70H4Z'/></clipPath>"
         "<clipPath id='b'><path d='M4 4H70V70H4Z'/></clipPath></defs>"
         "<rect width='80' height='80' clip-path='url(#a)'/>"
         "<rect width='80' height='80' clip-path='url(#b)'/></svg>");
    IJSVGQuartzRenderer* renderer = [[IJSVGQuartzRenderer alloc] init];
    renderer.renderingOptions = svg.renderingOptions;
    NSArray<IJSVGPaint*>* clips = [self clipsInPaint:[renderer rootPaintForRootNode:svg.rootNode]];
    XCTAssertEqual(clips.count, 2u);
    if(clips.count != 2) {
        return;
    }
    XCTAssertEqual(clips[0].clipPath, clips[1].clipPath);
    IJSVGClipPath* clip = svg.rootNode.children.firstObject.clipPath;
    IJSVGPath* path = (IJSVGPath*)clip.children.firstObject;
    CGPathAddRect(path.path, NULL, CGRectMake(80, 80, 8, 8));
    NSArray<IJSVGPaint*>* rebuilt = [self clipsInPaint:[renderer rootPaintForRootNode:svg.rootNode]];
    XCTAssertEqual(rebuilt.count, 2u);
    if(rebuilt.count == 2) {
        XCTAssertFalse(CGPathEqualToPath(rebuilt[0].clipPath, rebuilt[1].clipPath));
    }
    XCTAssertTrue(CGPathEqualToPath(clips[0].clipPath, clips[1].clipPath));
}

- (void)testUseClipsShareGeometryWithoutSharingDifferentPlacements
{
    IJSVG* svg = IJSVGTestSVGObject(
        @"<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' width='96' height='96'>"
         "<defs><path id='p' d='M4 4H70V70H4Z'/>"
         "<clipPath id='a'><use xlink:href='#p'/></clipPath>"
         "<clipPath id='b'><use xlink:href='#p'/></clipPath>"
         "<clipPath id='c'><use xlink:href='#p'/></clipPath></defs>"
         "<rect width='80' height='80' clip-path='url(#a)'/>"
         "<rect width='80' height='80' clip-path='url(#b)'/>"
         "<rect x='5' width='80' height='80' clip-path='url(#c)'/></svg>");
    IJSVGQuartzRenderer* renderer = [[IJSVGQuartzRenderer alloc] init];
    renderer.renderingOptions = svg.renderingOptions;
    NSArray<IJSVGPaint*>* clips = [self clipsInPaint:[renderer rootPaintForRootNode:svg.rootNode]];
    NSMutableDictionary<NSString*, IJSVGPaint*>* indexed = [[NSMutableDictionary alloc] init];
    for(IJSVGPaint* paint in clips) {
        indexed[paint.sourceNode.clipPath.identifier] = paint;
    }
    XCTAssertEqual(indexed.count, 3u);
    if(indexed.count == 3) {
        XCTAssertEqual(indexed[@"a"].clipPath, indexed[@"b"].clipPath);
        XCTAssertFalse(CGPathEqualToPath(indexed[@"a"].clipPath, indexed[@"c"].clipPath));
    }
}

- (void)testWhiteMaskMatchesGeneralFilterWithNestedArtwork
{
    NSString* format =
        @"<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64'>"
         "<defs><filter id='blur'><feGaussianBlur stdDeviation='1.2'/></filter>"
         "<filter id='white' filterUnits='userSpaceOnUse' x='0' y='0' width='64' height='64' "
         "color-interpolation-filters='linearRGB'>"
         "<feColorMatrix values='0 0 0 0 1 0 0 0 0 1 0 0 0 0 1 0 0 0 1 0'/>%@</filter>"
         "<clipPath id='clip'><path d='M5 5H58V58H5Z'/></clipPath>"
         "<mask id='mask' mask-type='%@' maskUnits='userSpaceOnUse' x='0' y='0' width='64' height='64'>"
         "<g filter='url(#white)' opacity='.7'><g transform='rotate(13 32 32)' clip-path='url(#clip)'>"
         "<circle cx='30' cy='30' r='15' fill='#258' filter='url(#blur)'/>"
         "<rect x='24' y='30' width='20' height='14' fill='red' opacity='.5'/>"
         "</g></g></mask></defs><rect width='64' height='64' fill='#ef4732' mask='url(#mask)'/></svg>";
    for(NSString* maskType in @[@"luminance", @"alpha"]) {
        NSString* optimized = [NSString stringWithFormat:format, @"", maskType];
        NSString* general = [NSString stringWithFormat:format, @"<feOffset dx='0' dy='0'/>", maskType];
        for(NSNumber* flipped in @[@NO, @YES]) {
            NSData* actual = [self renderDocument:optimized flipped:flipped.boolValue];
            NSData* expected = [self renderDocument:general flipped:flipped.boolValue];
            XCTAssertTrue([self containsPaintedPixels:actual]);
            XCTAssertLessThanOrEqual([self maximumDifference:actual other:expected], 1, @"%@", maskType);
        }
    }
}

- (void)testSharedClipsMatchRecursiveClipsAcrossUnitsAndTransforms
{
    for(NSString* units in @[@"userSpaceOnUse", @"objectBoundingBox"]) {
        NSString* geometry = [units isEqualToString:@"objectBoundingBox"] ?
            @"M.1 .1H.9V.9H.1Z M.3 .3V.7H.7V.3Z" : @"M3 3H50V50H3Z M15 15V35H35V15Z";
        for(NSString* transform in @[@"translate(.3 .7)", @"rotate(17 32 32)", @"translate(64 0) scale(-1 1)"]) {
            NSString* format = @"<svg xmlns='http://www.w3.org/2000/svg' width='128' height='128'>"
                "<defs><clipPath id='a' clipPathUnits='%@' clip-rule='evenodd'>%@<path d='%@'/>%@"
                "</clipPath></defs><g transform='%@'><rect width='60' height='60' fill='red' clip-path='url(#a)'/>"
                "<rect x='7' y='5' width='80' height='70' fill='blue' opacity='.6' clip-path='url(#a)'/></g></svg>";
            NSString* shared = [NSString stringWithFormat:format, units, @"", geometry, @"", transform];
            NSString* recursive = [NSString stringWithFormat:format, units, @"", geometry, @"<path d=''/>", transform];
            for(NSNumber* flipped in @[@NO, @YES]) {
                XCTAssertEqualObjects([self renderDocument:shared flipped:flipped.boolValue],
                    [self renderDocument:recursive flipped:flipped.boolValue], @"%@ %@", units, transform);
            }
        }
    }
}

@end
