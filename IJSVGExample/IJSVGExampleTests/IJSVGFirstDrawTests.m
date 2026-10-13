//
//  IJSVGFirstDrawTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 10/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGTestHelpers.h"
#import <IJSVGQuartzRenderer.h>

@interface IJSVGFirstDrawTests : XCTestCase
@end

@implementation IJSVGFirstDrawTests

- (IJSVG*)svgWithContents:(NSString*)contents
{
    NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' "
                                               @"viewBox='0 0 128 128'>%@</svg>",
        contents];
    IJSVG* svg = IJSVGTestSVGObject(xml);
    svg.renderingBackingScaleHelper = ^CGFloat {
        return 1;
    };
    return svg;
}

- (NSData*)pixelsForSVG:(IJSVG*)svg clip:(CGRect)clip
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, 128, 128, 8, 512, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    XCTAssertNotEqual(context, NULL);
    if (context == NULL) {
        return nil;
    }
    CGContextTranslateCTM(context, 0, 128);
    CGContextScaleCTM(context, 1, -1);
    if (!CGRectIsNull(clip)) {
        CGContextClipToRect(context, clip);
    }
    [svg drawInRect:CGRectMake(0, 0, 128, 128) context:context];
    NSData* data = [NSData dataWithBytes:CGBitmapContextGetData(context) length:128 * 128 * 4];
    CGContextRelease(context);
    return data;
}

- (NSData*)pixelsForRoot:(IJSVGRootNode*)root renderer:(IJSVGQuartzRenderer*)renderer
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, 128, 128, 8, 512, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    XCTAssertNotEqual(context, NULL);
    if (context == NULL) {
        return nil;
    }
    CGContextTranslateCTM(context, 0, 128);
    CGContextScaleCTM(context, 1, -1);
    root.clientSize = CGSizeMake(128, 128);
    [renderer renderNode:root inContext:context viewPort:CGRectMake(0, 0, 128, 128) backingScale:1];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:128 * 128 * 4];
    CGContextRelease(context);
    return pixels;
}

- (void)testFilterDiscoveryResetsWhenRendererChangesRoots
{
    IJSVG* plain = [self svgWithContents:@"<rect width='128' height='128' fill='blue'/>"];
    IJSVG* filtered = [self svgWithContents:@"<g enable-background='new'><defs><filter id='f' "
                                            @"filterUnits='userSpaceOnUse' x='0' "
                                            @"y='0' width='128' height='128'>"
                                             "<feColorMatrix in='BackgroundImage' values='0 0 0 0 0 0 0 1 0 0 0 "
                                             "0 0 0 0 0 0 0 1 0'/>"
                                             "</filter></defs><rect width='128' height='128' fill='blue'/>"
                                             "<rect width='128' height='128' fill='red' filter='url(#f)'/></g>"];
    IJSVG* green = [self svgWithContents:@"<rect width='128' height='128' fill='#00ff00'/>"];
    NSData* bluePixels = [self pixelsForSVG:plain clip:CGRectNull];
    NSData* greenPixels = [self pixelsForSVG:green clip:CGRectNull];
    IJSVGQuartzRenderer* renderer = [[IJSVGQuartzRenderer alloc] init];
    for (NSUInteger index = 0; index < 3; index++) {
        XCTAssertEqualObjects([self pixelsForRoot:plain.rootNode renderer:renderer], bluePixels);
        XCTAssertEqualObjects([self pixelsForRoot:filtered.rootNode renderer:renderer], greenPixels);
    }
    IJSVGRenderingOptions* options = [[IJSVGRenderingOptions alloc] init];
    options.filtersEnabled = NO;
    renderer.renderingOptions = options;
    IJSVG* red = [self svgWithContents:@"<rect width='128' height='128' fill='red'/>"];
    XCTAssertEqualObjects([self pixelsForRoot:filtered.rootNode renderer:renderer], [self pixelsForSVG:red clip:CGRectNull]);
    options.filtersEnabled = YES;
    renderer.renderingOptions = options;
    XCTAssertEqualObjects([self pixelsForRoot:filtered.rootNode renderer:renderer], greenPixels);
}

- (void)testClippedMasksMatchFullRaster
{
    for (NSString* transform in @[ @"", @"translate(.3 .7)", @"rotate(17 64 64)", @"translate(128 0) scale(-1 1)" ]) {
        for (NSString* maskType in @[ @"alpha", @"luminance" ]) {
            for (NSNumber* filtered in @[ @NO, @YES ]) {
                NSString* effect = filtered.boolValue ? @"filter='url(#blur)'" : @"";
                IJSVG* svg = [self svgWithContents:[NSString stringWithFormat:@"<defs><linearGradient id='gradient'><stop "
                                                                              @"stop-color='white'/>"
                                                                               "<stop offset='1' "
                                                                               "stop-color='#2468ac'/></linearGradient>"
                                                                               "<filter id='blur'><feGaussianBlur "
                                                                               "stdDeviation='1.3'/></filter>"
                                                                               "<mask id='mask' mask-type='%@' "
                                                                               "maskUnits='userSpaceOnUse' "
                                                                               "x='-128' y='-128' width='384' height='384'>"
                                                                               "<rect x='-128' y='-128' width='384' height='384' "
                                                                               "fill='url(#gradient)' opacity='.7'/>"
                                                                               "<circle cx='57.4' cy='53.7' r='29.3' fill='black' "
                                                                               "%@/>"
                                                                               "</mask></defs><g transform='%@'>"
                                                                               "<rect x='-128' y='-128' width='384' height='384' "
                                                                               "fill='#ec5628' "
                                                                               "mask='url(#mask)'/></g>",
                                                       maskType, effect, transform]];
                NSData* full = [self pixelsForSVG:svg clip:CGRectNull];

                // Change the destination clip while reusing the same resolved
                // tree. Cached mask bounds must track the newly requested area.
                for (NSValue* value in @[ [NSValue valueWithRect:CGRectMake(30, 32, 41, 37)], [NSValue valueWithRect:CGRectMake(53, 49, 49, 35)] ]) {
                    CGRect clip = value.rectValue;
                    NSData* cropped = [self pixelsForSVG:svg clip:clip];
                    const uint8_t* actual = cropped.bytes;
                    const uint8_t* reference = full.bytes;
                    NSUInteger maximumDifference = 0;
                    NSUInteger totalDifference = 0;
                    for (NSUInteger y = 0; y < 128; y++) {
                        for (NSUInteger x = 0; x < 128; x++) {
                            BOOL inside = CGRectContainsPoint(clip, CGPointMake(x + .5, y + .5));
                            for (NSUInteger channel = 0; channel < 4; channel++) {
                                NSUInteger index = (y * 128 + x) * 4 + channel;
                                int expected = inside ? reference[index] : 0;
                                NSUInteger difference = abs(actual[index] - expected);
                                maximumDifference = MAX(maximumDifference, difference);
                                totalDifference += difference;
                            }
                        }
                    }

                    // Cropping changes Quartz gradient rounding and mask
                    // interpolation. Bound both the worst channel and total error.
                    XCTAssertLessThanOrEqual(maximumDifference, 2, @"%@ filtered=%@ transform=%@ clip=%@", maskType, filtered, transform, value);
                    XCTAssertLessThan((double)totalDifference / cropped.length, .05);
                }
                XCTAssertEqualObjects([self pixelsForSVG:svg clip:CGRectNull], full);
            }
        }
    }
}

- (void)testEmptyClipDoesNotSuppressFollowingSibling
{
    IJSVG* svg = [self svgWithContents:@"<defs><clipPath id='outside'><rect x='200' "
                                       @"y='200' width='20' height='20'/>"
                                        "</clipPath><filter id='blur'><feGaussianBlur "
                                        "stdDeviation='4'/></filter></defs>"
                                        "<g clip-path='url(#outside)'><rect width='128' "
                                        "height='128' fill='red' "
                                        "filter='url(#blur)'/></g><circle cx='64' cy='64' "
                                        "r='30' fill='#3472bd'/>"];
    IJSVG* reference = [self svgWithContents:@"<circle cx='64' cy='64' r='30' fill='#3472bd'/>"];
    XCTAssertEqualObjects([self pixelsForSVG:svg clip:CGRectNull], [self pixelsForSVG:reference clip:CGRectNull]);
}

- (void)testRepeatedClipTemplatesMatchIndependentParsing
{
    for (NSString* units in @[ @"userSpaceOnUse", @"objectBoundingBox" ]) {
        NSString* geometry = [units isEqualToString:@"objectBoundingBox"] ? @"<rect x='.1' y='.1' width='.8' height='.8'/>"
                                                                             "<circle cx='.5' cy='.5' r='.2'/>"
                                                                          : @"<rect x='10' y='10' width='80' height='80'/>"
                                                                             "<circle cx='50' cy='50' r='20'/>";
        NSMutableString* clients = [NSMutableString string];
        for (NSUInteger i = 0; i < 12; i++) {
            [clients appendFormat:@"<rect x='%lu' y='%lu' width='%lu' height='41' fill='#3481b7' "
                                   "clip-path='url(#clip)' transform='rotate(%lu 64 64)'/>",
                (unsigned long)(i * 7), (unsigned long)(i * 3), (unsigned long)(33 + i), (unsigned long)i];
        }
        NSString* format = @"<defs><clipPath id='clip' clipPathUnits='%@' "
                            "clip-rule='evenodd'>%@</clipPath></defs>%@";
        IJSVG* cached = [self svgWithContents:[NSString stringWithFormat:format, units, geometry, clients]];

        // An ignored data attribute excludes the conservative template path
        // without changing any geometry, style or reference coordinates.
        NSString* independent = [[NSString stringWithFormat:format, units, geometry, clients] stringByReplacingOccurrencesOfString:@"<clipPath "
                                                                                                                        withString:@"<clipPath "
                                                                                                                                   @"data-reference='independent' "];
        IJSVG* reference = [self svgWithContents:independent];
        XCTAssertEqualObjects([self pixelsForSVG:cached clip:CGRectNull], [self pixelsForSVG:reference clip:CGRectNull]);
    }
}

- (void)testClipTemplateCopiesKeepGeometryIndependent
{
    IJSVG* svg = [self svgWithContents:@"<defs><clipPath id='clip'><rect x='10' y='10' "
                                       @"width='70' height='70'/>"
                                        "<path d='M20 20 L60 20 L40 60Z'/></clipPath></defs>"
                                        "<rect id='left' width='128' height='128' fill='red' "
                                        "clip-path='url(#clip)'/>"
                                        "<rect id='right' width='128' height='128' fill='blue' "
                                        "clip-path='url(#clip)'/>"];
    NSMutableDictionary<NSString*, IJSVGGraphicsNode*>* clients = [NSMutableDictionary dictionary];
    [IJSVGNode walkNodeTree:svg.rootNode
                    handler:^(IJSVGNode* node, BOOL* children, BOOL* stop) {
                        if ([node.identifier isEqualToString:@"left"] || [node.identifier isEqualToString:@"right"]) {
                            clients[node.identifier] = (IJSVGGraphicsNode*)node;
                        }
                    }];
    IJSVGClipPath* left = clients[@"left"].clipPath;
    IJSVGClipPath* right = clients[@"right"].clipPath;
    XCTAssertNotNil(left);
    XCTAssertNotNil(right);
    XCTAssertNotEqual(left, right);
    XCTAssertEqual(left.children.count, 2u);
    XCTAssertEqual(right.children.count, 2u);
    if (left.children.count != 2 || right.children.count != 2) {
        return;
    }
    IJSVGPath* leftRect = (IJSVGPath*)left.children[0];
    IJSVGPath* rightRect = (IJSVGPath*)right.children[0];
    CGFloat rightWidth = rightRect.width.value;
    leftRect.width = [leftRect.width lengthWithValue:5];
    XCTAssertEqual(rightRect.width.value, rightWidth);
    IJSVGPath* leftPath = (IJSVGPath*)left.children[1];
    IJSVGPath* rightPath = (IJSVGPath*)right.children[1];
    CGRect rightBounds = CGPathGetBoundingBox(rightPath.path);
    CGPathAddRect(leftPath.path, NULL, CGRectMake(100, 100, 20, 20));
    XCTAssertTrue(CGRectEqualToRect(CGPathGetBoundingBox(rightPath.path), rightBounds));
    NSData* before = [self pixelsForSVG:svg clip:CGRectNull];
    rightRect.width = [rightRect.width lengthWithValue:2];
    [svg setNeedsDisplay];
    XCTAssertNotEqualObjects([self pixelsForSVG:svg clip:CGRectNull], before);
}

- (void)testStructuralGroupsPreserveCompositingState
{
    NSString* contents = @"<rect x='12.3' y='13.7' width='47.1' height='51.2' fill='#e34729'/>"
                          "<g opacity='.6'><circle cx='64' cy='64' r='35' fill='blue'/>"
                          "<rect x='45' y='45' width='60' height='60' fill='lime' "
                          "style='mix-blend-mode:multiply'/></g>";
    for (NSString* outer in @[ @"", @"opacity='.4'", @"style='isolation:isolate'", @"transform='translate(.3 .7) rotate(13 64 64)'" ]) {
        NSString* reference = [NSString stringWithFormat:@"<g %@>%@</g>", outer, contents];
        NSString* wrapped = [NSString stringWithFormat:@"<g %@><g><g><g>%@</g></g></g></g>", outer, contents];
        XCTAssertEqualObjects([self pixelsForSVG:[self svgWithContents:wrapped] clip:CGRectNull], [self pixelsForSVG:[self svgWithContents:reference] clip:CGRectNull]);
    }
}

@end
