//
//  IJSVGDirectGradientTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGTestHelpers.h"
#import <IJSVGQuartzRenderer.h>
#import <IJSVGRootPaint.h>
#import <IJSVGShapePaint.h>

@interface IJSVGDirectGradientTests : XCTestCase
@end

@implementation IJSVGDirectGradientTests

- (NSString*)svgWithGradientAttributes:(NSString*)gradientAttributes
                      shapeAttributes:(NSString*)shapeAttributes
{
    return [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'>"
         "<defs><linearGradient id='g' %@><stop stop-color='red' stop-opacity='.4'/>"
         "<stop offset='1' stop-color='blue'/></linearGradient><marker id='unused'/>"
         "<clipPath id='clip'><rect x='5' y='3' width='20' height='25'/></clipPath>"
         "<mask id='mask'><rect width='32' height='32' fill='white' opacity='.6'/></mask>"
         "<filter id='blur'><feGaussianBlur stdDeviation='.5'/></filter></defs>"
         "<path d='M4 4h24v24H4z M10 10h12v12H10z' fill='url(#g)' fill-rule='evenodd' %@/>"
         "</svg>", gradientAttributes, shapeAttributes];
}

- (NSArray<IJSVGShapePaint*>*)directShapesForSVG:(NSString*)xml
{
    IJSVG* svg = IJSVGTestSVGObject(xml);
    IJSVGQuartzRenderer* renderer = [[IJSVGQuartzRenderer alloc] init];
    IJSVGRootPaint* root = [renderer rootPaintForRootNode:svg.rootNode
                                          viewportSize:CGSizeMake(32, 32)];
    NSMutableArray<IJSVGPaint*>* pending = [NSMutableArray arrayWithObject:root];
    NSMutableArray<IJSVGShapePaint*>* shapes = [NSMutableArray array];
    while(pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        if([paint isKindOfClass:IJSVGShapePaint.class] &&
           ((IJSVGShapePaint*)paint).fillGradient != nil) {
            [shapes addObject:(IJSVGShapePaint*)paint];
        }
        [pending addObjectsFromArray:paint.children];
    }
    return shapes;
}

- (void)testDirectFillsMatchSeparatePaints
{
    for(NSString* gradient in @[@"", @"gradientTransform='rotate(23 .5 .5)'",
                                @"x2='.3' spreadMethod='reflect'", @"x2='.3' spreadMethod='repeat'"]) {
        for(NSString* attributes in @[@"", @"transform='translate(.3 .7) rotate(17 16 16)'",
                                      @"transform='translate(32 0) scale(-1 1)'",
                                      @"clip-path='url(#clip)'", @"mask='url(#mask)'",
                                      @"filter='url(#blur)'"]) {
            NSString* direct = [self svgWithGradientAttributes:gradient shapeAttributes:attributes];
            NSString* separate = [self svgWithGradientAttributes:gradient
                shapeAttributes:[attributes stringByAppendingString:@" marker-end='url(#unused)'"]];
            XCTAssertEqual([self directShapesForSVG:direct].count, 1);
            XCTAssertEqual([self directShapesForSVG:separate].count, 0);
            XCTAssertEqualObjects(IJSVGTestRGBADataForSVG(direct, CGSizeMake(128, 128)),
                                  IJSVGTestRGBADataForSVG(separate, CGSizeMake(128, 128)),
                                  @"%@ %@", gradient, attributes);
        }
    }
}

- (void)testComplexFillsKeepSeparatePaints
{
    for(NSString* attributes in @[@"fill-opacity='.5'", @"opacity='.5'",
                                  @"stroke='black' stroke-width='2'",
                                  @"style='isolation:isolate'", @"style='mix-blend-mode:multiply'"]) {
        NSString* xml = [self svgWithGradientAttributes:@"" shapeAttributes:attributes];
        XCTAssertEqual([self directShapesForSVG:xml].count, 0, @"%@", attributes);
    }
    NSString* userSpace = [self svgWithGradientAttributes:@"gradientUnits='userSpaceOnUse'"
                                         shapeAttributes:@""];
    XCTAssertEqual([self directShapesForSVG:userSpace].count, 0);
}

- (void)testDirectFillExportAndOutline
{
    NSString* xml = [self svgWithGradientAttributes:@"" shapeAttributes:@""];
    IJSVG* svg = IJSVGTestSVGObject(xml);
    NSString* exported = [svg SVGStringWithSize:CGSizeMake(32, 32) options:IJSVGExporterOptionNone];
    XCTAssertEqualObjects(IJSVGTestRGBADataForSVG(xml, CGSizeMake(128, 128)),
                          IJSVGTestRGBADataForSVG(exported, CGSizeMake(128, 128)));
    CGPathRef outline = [svg outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    XCTAssertTrue(outline != NULL);
    if(outline != NULL) {
        XCTAssertTrue(CGPathContainsPoint(outline, NULL, CGPointMake(6, 6), false));
        XCTAssertFalse(CGPathContainsPoint(outline, NULL, CGPointMake(16, 16), false));
        XCTAssertTrue(CGRectEqualToRect(CGPathGetPathBoundingBox(outline), CGRectMake(4, 4, 24, 24)));
    }
    NSString* transparent = [xml stringByReplacingOccurrencesOfString:@"stop-opacity='.4'"
                                                          withString:@"stop-opacity='0'"];
    transparent = [transparent stringByReplacingOccurrencesOfString:@"stop-color='blue'"
                                                         withString:@"stop-color='blue' stop-opacity='0'"];
    CGPathRef empty = [IJSVGTestSVGObject(transparent) outlinePathIncludingFilterExtents:NO preservingHoles:YES];
    XCTAssertTrue(empty != NULL && CGPathIsEmpty(empty));
}

- (void)testMarkerCopyRetainsDirectGradient
{
    IJSVGShapePaint* paint = [self directShapesForSVG:
        [self svgWithGradientAttributes:@"" shapeAttributes:@""]].firstObject;
    IJSVGShapePaint* copy = (IJSVGShapePaint*)[paint copyForMarker];
    XCTAssertNotNil(copy);
    XCTAssertEqual(copy.fillGradient, paint.fillGradient);
    XCTAssertTrue(CGPathEqualToPath(copy.path, paint.path));
}

@end
