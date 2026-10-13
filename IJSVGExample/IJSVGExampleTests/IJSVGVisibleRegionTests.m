//
//  IJSVGVisibleRegionTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterGraph.h>
#import <IJSVGFilterPaint.h>
#import <IJSVGFilterTestHelpers.h>
#import <objc/runtime.h>

@interface IJSVGFilterPaint (VisibleRegionTesting)
- (CGRect)requestedOutputExtentForGraph:(IJSVGFilterGraph*)graph context:(CGContextRef)ctx;

- (void)renderGraph:(IJSVGFilterGraph*)graph context:(CGContextRef)ctx region:(CGRect)region workRect:(CGRect)workRect pixelSize:(CGSize)pixelSize scale:(CGFloat)scale;
@end

@interface IJSVGShapePaint (VisibleRegionTesting)
- (BOOL)isPathOutsideClipInContext:(CGContextRef)ctx;
@end

static _Thread_local NSUInteger IJSVGTestAllocatedPixels;
static _Thread_local NSUInteger IJSVGTestCulledShapes;

// These test subclasses add no instance storage and preserve the resolved tree.
@interface IJSVGObservedFilterPaint : IJSVGFilterPaint
@end

@implementation IJSVGObservedFilterPaint

- (void)renderGraph:(IJSVGFilterGraph*)graph context:(CGContextRef)ctx region:(CGRect)region workRect:(CGRect)workRect pixelSize:(CGSize)pixelSize scale:(CGFloat)scale
{
    IJSVGTestAllocatedPixels += pixelSize.width * pixelSize.height;
    [super renderGraph:graph context:ctx region:region workRect:workRect pixelSize:pixelSize scale:scale];
}

@end

@interface IJSVGFullExtentFilterPaint : IJSVGObservedFilterPaint
@end

@implementation IJSVGFullExtentFilterPaint

- (CGRect)requestedOutputExtentForGraph:(IJSVGFilterGraph*)graph context:(CGContextRef)ctx
{
    return graph.extent;
}

@end

@interface IJSVGObservedShapePaint : IJSVGShapePaint
@end

@implementation IJSVGObservedShapePaint

- (BOOL)isPathOutsideClipInContext:(CGContextRef)ctx
{
    BOOL outside = [super isPathOutsideClipInContext:ctx];
    IJSVGTestCulledShapes += outside;
    return outside;
}

@end

@interface IJSVGUnculledShapePaint : IJSVGShapePaint
@end

@implementation IJSVGUnculledShapePaint

- (BOOL)isPathOutsideClipInContext:(CGContextRef)ctx
{
    return NO;
}

@end

@interface IJSVGVisibleRegionTests : XCTestCase
@end

@implementation IJSVGVisibleRegionTests

- (IJSVGRootPaint*)paintForDocument:(NSString*)document reference:(BOOL)reference
{
    IJSVG* svg = IJSVGTestSVGObject(document);
    IJSVGQuartzRenderer* renderer = [[IJSVGQuartzRenderer alloc] init];
    renderer.renderingOptions = svg.renderingOptions;
    IJSVGRootPaint* root = [renderer rootPaintForRootNode:svg.rootNode];
    root.frame = CGRectMake(0, 0, 128, 128);
    [IJSVGPaint setBackingScaleFactor:1 renderQuality:kIJSVGRenderQualityFullResolution recursivelyToPaint:root];
    NSMutableArray<IJSVGPaint*>* pending = [NSMutableArray arrayWithObject:root];
    while (pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        Class replacement = Nil;
        if (paint.class == IJSVGFilterPaint.class) {
            replacement = reference ? IJSVGFullExtentFilterPaint.class : IJSVGObservedFilterPaint.class;

        } else if (paint.class == IJSVGShapePaint.class) {
            replacement = reference ? IJSVGUnculledShapePaint.class : IJSVGObservedShapePaint.class;
        }

        if (replacement != Nil) {
            XCTAssertEqual(class_getInstanceSize(paint.class), class_getInstanceSize(replacement));
            object_setClass(paint, replacement);
        }
        [pending addObjectsFromArray:paint.children];
        if (paint.maskPaint != nil) {
            [pending addObject:paint.maskPaint];
        }
    }
    return root;
}

- (NSData*)renderPaint:(IJSVGPaint*)paint clip:(CGRect)clip flipped:(BOOL)flipped
{
    CGContextRef context = [self newBitmapWithSize:128 flipped:flipped];
    CGContextClipToRect(context, clip);
    [IJSVGFilterPaint renderPaint:paint inBitmapContext:context];
    NSData* data = [NSData dataWithBytes:CGBitmapContextGetData(context) length:128 * 128 * 4];
    CGContextRelease(context);
    return data;
}

- (NSString*)documentWithFilter:(NSString*)filter transform:(NSString*)transform
{
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='128' height='128'>"
                                       "<defs><filter id='f' filterUnits='userSpaceOnUse' x='-128' "
                                       "y='-128' width='384' height='384'>"
                                       "%@</filter></defs><g transform='%@' filter='url(#f)'>"
                                       "<circle cx='78' cy='55' r='21' fill='#ef4732'/>"
                                       "<path d='M10 15L85 90L115 20Z' fill='#2468ac' opacity='.6'/>"
                                       "</g></svg>",
        filter, transform];
}

- (void)testReverseBoundsPreserveBlurHaloAndNamedBranches
{
    NSArray<NSString*>* filters = @[
        (@"<feOffset dx='-40' dy='9'/><feGaussianBlur stdDeviation='3'/>"),
        (@"<feGaussianBlur in='SourceAlpha' stdDeviation='2.7' result='blur'/>"
          "<feOffset in='blur' dx='17' dy='-9' result='shifted'/>"
          "<feMerge><feMergeNode in='SourceGraphic'/><feMergeNode "
          "in='shifted'/></feMerge>"),
        (@"<feGaussianBlur stdDeviation='2'/><feComponentTransfer>"
          "<feFuncA type='linear' slope='20' intercept='-1'/></feComponentTransfer>"
          "<feGaussianBlur stdDeviation='1.3'/>"),
        (@"<feFlood flood-color='red'/><feComposite in2='SourceGraphic' "
         @"operator='in'/>"),
        (@"<feTile/><feGaussianBlur stdDeviation='1'/>"),
        (@"<feGaussianBlur in='SourceAlpha' stdDeviation='9.256' result='blur'/>"
          "<feComponentTransfer in='blur' result='contour'><feFuncA type='linear' "
          "slope='100' "
          "intercept='-1'/></feComponentTransfer>"
          "<feMerge result='raw'><feMergeNode in='SourceAlpha'/><feMergeNode "
          "in='contour'/></feMerge>"
          "<feGaussianBlur in='raw' stdDeviation='8.912'/>"
          "<feComponentTransfer result='smooth'><feFuncA type='linear' slope='20' "
          "intercept='-10'/></feComponentTransfer>"
          "<feMerge><feMergeNode in='raw'/><feMergeNode in='smooth'/></feMerge>")
    ];
    for (NSString* filter in filters) {
        for (NSString* transform in @[ @"", @"translate(.3 .7)", @"rotate(17 64 64)" ]) {
            NSString* document = [self documentWithFilter:filter transform:transform];
            for (NSNumber* flipped in @[ @NO, @YES ]) {
                IJSVGRootPaint* actual = [self paintForDocument:document reference:NO];
                IJSVGRootPaint* expected = [self paintForDocument:document reference:YES];

                // Reuse both graphs while the clip shrinks, moves, then expands.
                for (NSValue* value in @[ [NSValue valueWithRect:CGRectMake(24, 32, 40, 36)], [NSValue valueWithRect:CGRectMake(55, 20, 24, 27)], [NSValue valueWithRect:CGRectMake(0, 0, 128, 128)] ]) {
                    NSData* pixels = [self renderPaint:actual clip:value.rectValue flipped:flipped.boolValue];
                    NSData* reference = [self renderPaint:expected clip:value.rectValue flipped:flipped.boolValue];
                    XCTAssertLessThanOrEqual([self maximumDifference:pixels other:reference], 2, @"%@ %@ %@", filter, transform, value);
                }
            }
        }
    }
}

- (void)testSmallVisibleAreaAllocatesFewerFilterPixels
{
    NSString* document = [self documentWithFilter:@"<feOffset dx='-40' dy='9'/><feGaussianBlur stdDeviation='3'/>" transform:@""];
    CGRect clip = CGRectMake(24, 32, 40, 36);
    IJSVGTestAllocatedPixels = 0;
    NSData* actual = [self renderPaint:[self paintForDocument:document reference:NO] clip:clip flipped:NO];
    NSUInteger allocated = IJSVGTestAllocatedPixels;
    IJSVGTestAllocatedPixels = 0;
    NSData* expected = [self renderPaint:[self paintForDocument:document reference:YES] clip:clip flipped:NO];
    XCTAssertGreaterThan(allocated, 0u);
    XCTAssertLessThan(allocated, IJSVGTestAllocatedPixels / 2);
    XCTAssertTrue([self containsPaintedPixels:actual]);
    XCTAssertLessThanOrEqual([self maximumDifference:actual other:expected], 2);
}

- (void)testRotatedVisibleAreaAllocatesFewerFilterPixels
{
    NSString* document = [self documentWithFilter:@"<feOffset dx='-40' dy='9'/><feGaussianBlur stdDeviation='3'/>" transform:@"rotate(17 64 64)"];
    CGRect clip = CGRectMake(24, 32, 40, 36);
    IJSVGTestAllocatedPixels = 0;
    NSData* actual = [self renderPaint:[self paintForDocument:document reference:NO] clip:clip flipped:NO];
    NSUInteger allocated = IJSVGTestAllocatedPixels;
    IJSVGTestAllocatedPixels = 0;
    NSData* expected = [self renderPaint:[self paintForDocument:document reference:YES] clip:clip flipped:NO];
    XCTAssertGreaterThan(allocated, 0u);
    XCTAssertLessThan(allocated, IJSVGTestAllocatedPixels / 2);
    XCTAssertTrue([self containsPaintedPixels:actual]);
    XCTAssertLessThanOrEqual([self maximumDifference:actual other:expected], 2);
}

- (void)testCullingKeepsWideStrokesCapsAndAntialiasedEdges
{
    NSArray<NSString*>* drawings = @[ @"<path d='M90 90H120V120H90Z' fill='red'/>", @"<path d='M67 20V70' stroke='red' stroke-width='28' stroke-linecap='square'/>", @"<path d='M20 90L45 20L70 90' fill='none' stroke='blue' stroke-width='9' stroke-miterlimit='20'/>", @"<path d='M63.8 10V90' stroke='red' stroke-width='.2'/>", @"<path d='M67 20V70' stroke='red' stroke-width='28' vector-effect='non-scaling-stroke'/>" ];
    for (NSString* drawing in drawings) {
        for (NSString* transform in @[ @"", @"rotate(9 64 64)", @"scale(.5 1.5)" ]) {
            NSString* document = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='128' "
                                                            @"height='128'><g transform='%@'>%@</g></svg>",
                transform, drawing];
            CGRect clip = CGRectMake(0, 0, 64, 64);
            NSData* actual = [self renderPaint:[self paintForDocument:document reference:NO] clip:clip flipped:NO];
            NSData* expected = [self renderPaint:[self paintForDocument:document reference:YES] clip:clip flipped:NO];
            XCTAssertEqualObjects(actual, expected, @"%@ %@", drawing, transform);
        }
    }
}

- (void)testOffscreenPathIsSkipped
{
    NSString* document = @"<svg xmlns='http://www.w3.org/2000/svg' width='128' height='128'>"
                          "<path d='M90 90H120V120H90Z' fill='red'/></svg>";
    IJSVGTestCulledShapes = 0;
    NSData* data = [self renderPaint:[self paintForDocument:document reference:NO] clip:CGRectMake(0, 0, 32, 32) flipped:NO];
    XCTAssertGreaterThan(IJSVGTestCulledShapes, 0u);
    XCTAssertFalse([self containsPaintedPixels:data]);
}

@end
