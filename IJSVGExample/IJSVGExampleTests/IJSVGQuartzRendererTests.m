//
//  IJSVGQuartzRendererTests.m
//  IJSVGExampleTests
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <IJSVG/IJSVG.h>
#import <XCTest/XCTest.h>

@interface IJSVGQuartzRendererTests : XCTestCase
@end

@implementation IJSVGQuartzRendererTests

- (IJSVG*)svgWithBody:(NSString*)body
{
    NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'>%@</svg>", body];
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml];
    XCTAssertNotNil(svg);
    return svg;
}

- (NSData*)renderSVG:(IJSVG*)svg size:(NSUInteger)size drawingRect:(CGRect)drawingRect
{
    XCTAssertNotNil(svg);
    if(svg == nil) return nil;

    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    XCTAssertTrue(space != NULL);
    if(space == NULL) return nil;

    CGContextRef context = CGBitmapContextCreate(NULL, size, size, 8, size * 4,
                                                space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) return nil;

    CGContextTranslateCTM(context, 0.f, size);
    CGContextScaleCTM(context, 1.f, -1.f);
    [svg drawInRect:drawingRect context:context];

    const void* bytes = CGBitmapContextGetData(context);
    XCTAssertTrue(bytes != NULL);
    NSData* pixels = bytes == NULL ? nil : [NSData dataWithBytes:bytes length:size * size * 4];
    CGContextRelease(context);
    return pixels;
}

- (NSData*)renderSVG:(IJSVG*)svg size:(NSUInteger)size
{
    return [self renderSVG:svg size:size drawingRect:CGRectMake(0.f, 0.f, size, size)];
}

- (NSData*)renderBody:(NSString*)body size:(NSUInteger)size
{
    return [self renderSVG:[self svgWithBody:body] size:size];
}

// Checks backdrop rendering at several backing scales.
- (void)testBackdropSurfacePreservesDevicePixelEdges
{
    NSMutableString* body = [NSMutableString stringWithString:
        @"<defs><filter id='f'><feComposite in='SourceGraphic' in2='BackgroundImage' "
        "operator='arithmetic' k2='1'/></filter></defs><rect width='32' height='32' fill='white'/>" ];
    for(NSUInteger x = 0; x < 32; x++) {
        [body appendFormat:@"<rect x='%lu' width='.5' height='24' fill='black'/>", (unsigned long)x];
    }
    // This isolated shape enables backdrop rendering without changing the stripes.
    [body appendString:@"<rect x='2' y='28' width='4' height='2' fill='red' filter='url(#f)'/>"];
    for(NSNumber* scaleValue in @[@1, @2, @3]) {
        CGFloat scale = scaleValue.doubleValue;
        NSUInteger size = 32 * scale;
        NSMutableArray<NSData*>* images = [NSMutableArray array];
        for(NSNumber* enabled in @[@YES, @NO]) {
            IJSVG* svg = [self svgWithBody:body];
            IJSVGRenderingOptions* options = svg.renderingOptions;
            options.filtersEnabled = enabled.boolValue;
            svg.renderingOptions = options;
            svg.renderingBackingScaleHelper = ^CGFloat { return scale; };
            CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            CGContextRef bitmap = CGBitmapContextCreate(NULL, size, size, 8, size * 4,
                space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
            CGColorSpaceRelease(space);
            XCTAssertTrue(bitmap != NULL);
            if(bitmap == NULL) {
                return;
            }
            CGContextScaleCTM(bitmap, scale, scale);
            [svg drawInRect:CGRectMake(0, 0, 32, 32) context:bitmap];
            [images addObject:[NSData dataWithBytes:CGBitmapContextGetData(bitmap) length:size * size * 4]];
            CGContextRelease(bitmap);
        }
        const uint8_t* actual = images[0].bytes;
        const uint8_t* expected = images[1].bytes;
        for(NSUInteger x = 0; x < size; x++) {
            NSUInteger offset = (size / 2 * size + x) * 4;
            for(NSUInteger channel = 0; channel < 4; channel++) {
                XCTAssertEqual(actual[offset + channel], expected[offset + channel],
                    @"scale=%@ x=%lu channel=%lu", scaleValue, (unsigned long)x, (unsigned long)channel);
            }
        }
    }
}

- (void)testOverlappingChildrenReceiveGroupOpacityOnce
{
    NSData* data = [self renderBody:@"<g opacity='0.5'>"
        @"<rect x='2' y='2' width='20' height='20' fill='red'/>"
        @"<rect x='10' y='10' width='20' height='20' fill='blue'/>"
        @"</g>" size:32];
    if(data == nil) return;
    const uint8_t* pixels = data.bytes;
    XCTAssertEqualWithAccuracy(pixels[(5 * 32 + 5) * 4 + 3], 128, 1);
    XCTAssertEqualWithAccuracy(pixels[(15 * 32 + 15) * 4 + 3], 128, 1);
    XCTAssertEqual(pixels[(15 * 32 + 15) * 4], 0);
    XCTAssertEqualWithAccuracy(pixels[(15 * 32 + 15) * 4 + 2], 128, 1);
}

- (void)testTransformedClipRestrictsPaint
{
    NSData* data = [self renderBody:@"<defs><clipPath id='c'><rect width='8' height='8'/></clipPath></defs>"
        @"<g transform='translate(8 8)'>"
        @"<rect width='20' height='20' fill='red' clip-path='url(#c)'/>"
        @"</g>" size:32];
    if(data == nil) return;
    const uint8_t* pixels = data.bytes;
    XCTAssertEqual(pixels[(10 * 32 + 10) * 4], 255);
    XCTAssertEqual(pixels[(20 * 32 + 20) * 4 + 3], 0);
    XCTAssertEqual(pixels[(4 * 32 + 4) * 4 + 3], 0);
}

- (void)testDrawingRespectsDestinationOrigin
{
    IJSVG* svg = [self svgWithBody:@"<rect width='32' height='32' fill='red'/>"];
    NSData* data = [self renderSVG:svg size:32 drawingRect:CGRectMake(8.f, 8.f, 16.f, 16.f)];
    if(data == nil) return;
    const uint8_t* pixels = data.bytes;
    XCTAssertEqual(pixels[(4 * 32 + 4) * 4 + 3], 0);
    XCTAssertEqual(pixels[(10 * 32 + 10) * 4], 255);
    XCTAssertEqual(pixels[(26 * 32 + 26) * 4 + 3], 0);
}

- (void)testPatternRepeatsInSVGCoordinates
{
    NSData* data = [self renderBody:@"<defs><pattern id='p' width='8' height='8' patternUnits='userSpaceOnUse'>"
        @"<rect width='4' height='8' fill='red'/>"
        @"<rect x='4' width='4' height='8' fill='blue'/>"
        @"</pattern></defs><rect width='32' height='32' fill='url(#p)'/>" size:32];
    if(data == nil) return;
    const uint8_t* pixels = data.bytes;
    for(NSUInteger x = 2; x <= 26; x += 8) {
        XCTAssertEqual(pixels[(12 * 32 + x) * 4], 255);
        XCTAssertEqual(pixels[(12 * 32 + x + 4) * 4 + 2], 255);
    }
}

- (void)testCachedPaintsFollowViewportScaleChanges
{
    NSString* body = @"<defs>"
        @"<pattern id='p' width='8' height='8' patternUnits='userSpaceOnUse'>"
        @"<rect width='4' height='8' fill='red'/>"
        @"<rect x='4' width='4' height='8' fill='blue'/></pattern>"
        @"<mask id='m'><rect width='32' height='32' fill='white'/></mask>"
        @"</defs><g mask='url(#m)'>"
        @"<rect width='32' height='32' fill='url(#p)'/>"
        @"<path d='M2 16h28' stroke='white' stroke-width='2' stroke-dasharray='2 3'/>"
        @"</g>";
    IJSVG* svg = [self svgWithBody:body];
    for(NSNumber* value in @[ @32, @128, @64, @32 ]) {
        NSUInteger size = value.unsignedIntegerValue;
        NSData* reused = [self renderSVG:svg size:size];
        NSData* fresh = [self renderBody:body size:size];
        XCTAssertEqualObjects(reused, fresh, @"Viewport size: %@", value);
    }
}

- (void)assertVectorExportPreservesQuartzPixels:(NSString*)body optimized:(BOOL)optimized
{
    IJSVG* svg = [self svgWithBody:body];
    if(svg == nil) return;
    IJSVGExporterOptions options = optimized ? IJSVGExporterOptionAll : IJSVGExporterOptionNone;
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg size:CGSizeMake(32.f, 32.f) options:options];
    NSString* exported = [exporter SVGString];
    IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:exported];
    NSData* before = [self renderSVG:svg size:64];
    NSData* after = [self renderSVG:roundTrip size:64];
    if(before == nil || after == nil) return;
    XCTAssertEqual(before.length, after.length);
    if(before.length != after.length) return;

    const uint8_t* beforePixels = before.bytes;
    const uint8_t* afterPixels = after.bytes;
    NSInteger difference = 0;
    for(NSUInteger index = 0; index < before.length; index++) {
        NSInteger delta = (NSInteger)beforePixels[index] - (NSInteger)afterPixels[index];
        difference = MAX(difference, delta < 0 ? -delta : delta);
    }
    // Outlined patterned strokes can differ by four levels at resampled tile edges.
    NSInteger tolerance = optimized && [body containsString:@"stroke='url(#p)'"] ? 4 : 3;
    XCTAssertLessThanOrEqual(difference, tolerance, @"Pixel difference %ld; SVG: %@", (long)difference, exported);
}

- (void)testUnoptimizedVectorExportPreservesNestedTransforms
{
    [self assertVectorExportPreservesQuartzPixels:@"<g transform='translate(2 3)'><g transform='translate(5 7)'><rect width='8' height='8' fill='red'/></g></g>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesNestedTransforms
{
    [self assertVectorExportPreservesQuartzPixels:@"<g transform='translate(2 3)'><g transform='translate(5 7)'><rect width='8' height='8' fill='red'/></g></g>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesGroupOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<g opacity='.5'><rect x='2' y='2' width='20' height='20' fill='red'/><rect x='10' y='10' width='20' height='20' fill='blue'/></g>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesGroupOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<g opacity='.5'><rect x='2' y='2' width='20' height='20' fill='red'/><rect x='10' y='10' width='20' height='20' fill='blue'/></g>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesDashedStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<path d='M3 5L25 5L25 25' fill='none' stroke='red' stroke-width='3' stroke-linecap='round' stroke-linejoin='bevel' stroke-dasharray='3 2' stroke-dashoffset='1'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesDashedStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<path d='M3 5L25 5L25 25' fill='none' stroke='red' stroke-width='3' stroke-linecap='round' stroke-linejoin='bevel' stroke-dasharray='3 2' stroke-dashoffset='1'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesLinearGradientOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect x='4' y='4' width='24' height='24' fill='url(#g)' fill-opacity='.6'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesLinearGradientOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect x='4' y='4' width='24' height='24' fill='url(#g)' fill-opacity='.6'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesRadialGradient
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><radialGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></radialGradient></defs><circle cx='16' cy='16' r='10' fill='url(#g)'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesRadialGradient
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><radialGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></radialGradient></defs><circle cx='16' cy='16' r='10' fill='url(#g)'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesGradientStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><path d='M4 8L28 8L28 24' fill='none' stroke='url(#g)' stroke-opacity='.6' stroke-width='3'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesGradientStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><path d='M4 8L28 8L28 24' fill='none' stroke='url(#g)' stroke-opacity='.6' stroke-width='3'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesPatternOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><pattern id='p' width='8' height='8' patternUnits='userSpaceOnUse'><rect width='4' height='8' fill='red'/><rect x='4' width='4' height='8' fill='blue'/></pattern></defs><rect width='32' height='32' fill='url(#p)' fill-opacity='.5'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesPatternOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><pattern id='p' width='8' height='8' patternUnits='userSpaceOnUse'><rect width='4' height='8' fill='red'/><rect x='4' width='4' height='8' fill='blue'/></pattern></defs><rect width='32' height='32' fill='url(#p)' fill-opacity='.5'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesTransformedClip
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><clipPath id='c'><rect width='8' height='8'/></clipPath></defs><g transform='translate(8 8)'><rect width='20' height='20' fill='red' clip-path='url(#c)'/></g>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesTransformedClip
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><clipPath id='c'><rect width='8' height='8'/></clipPath></defs><g transform='translate(8 8)'><rect width='20' height='20' fill='red' clip-path='url(#c)'/></g>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesMask
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><mask id='m'><rect width='16' height='32' fill='white'/></mask></defs><rect width='32' height='32' fill='red' mask='url(#m)'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesMask
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><mask id='m'><rect width='16' height='32' fill='white'/></mask></defs><rect width='32' height='32' fill='red' mask='url(#m)'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesNestedSVG
{
    [self assertVectorExportPreservesQuartzPixels:@"<svg x='8' y='8' width='16' height='16' viewBox='0 0 8 8'><rect width='8' height='8' fill='blue'/></svg>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesNestedSVG
{
    [self assertVectorExportPreservesQuartzPixels:@"<svg x='8' y='8' width='16' height='16' viewBox='0 0 8 8'><rect width='8' height='8' fill='blue'/></svg>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesPatternedStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><pattern id='p' width='8' height='8' patternUnits='userSpaceOnUse' patternTransform='translate(2 3)'><rect width='4' height='8' fill='red'/></pattern></defs><path d='M4 8L28 8L28 24' fill='none' stroke='url(#p)' stroke-opacity='.6' stroke-width='3'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesPatternedStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><pattern id='p' width='8' height='8' patternUnits='userSpaceOnUse' patternTransform='translate(2 3)'><rect width='4' height='8' fill='red'/></pattern></defs><path d='M4 8L28 8L28 24' fill='none' stroke='url(#p)' stroke-opacity='.6' stroke-width='3'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesPositionedMask
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><mask id='m' maskUnits='userSpaceOnUse' x='8' y='8' width='8' height='8'><rect x='8' y='8' width='8' height='8' fill='white'/></mask></defs><rect x='4' y='4' width='24' height='24' fill='red' mask='url(#m)'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesPositionedMask
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><mask id='m' maskUnits='userSpaceOnUse' x='8' y='8' width='8' height='8'><rect x='8' y='8' width='8' height='8' fill='white'/></mask></defs><rect x='4' y='4' width='24' height='24' fill='red' mask='url(#m)'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesFillAndStrokeOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<rect x='5' y='5' width='22' height='22' fill='red' stroke='blue' stroke-width='4' opacity='.5'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesFillAndStrokeOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<rect x='5' y='5' width='22' height='22' fill='red' stroke='blue' stroke-width='4' opacity='.5'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesTransformedLinearGradient
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><linearGradient id='g' gradientUnits='userSpaceOnUse' x1='4' x2='28' gradientTransform='rotate(15 16 16)'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect x='4' y='4' width='24' height='24' fill='url(#g)' stroke='black' stroke-width='2'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesTransformedLinearGradient
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><linearGradient id='g' gradientUnits='userSpaceOnUse' x1='4' x2='28' gradientTransform='rotate(15 16 16)'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect x='4' y='4' width='24' height='24' fill='url(#g)' stroke='black' stroke-width='2'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesRadialGradientStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><radialGradient id='g' gradientTransform='scale(.8 1)'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></radialGradient></defs><path d='M4 8L28 8L28 24' fill='none' stroke='url(#g)' stroke-width='3'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesRadialGradientStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><radialGradient id='g' gradientTransform='scale(.8 1)'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></radialGradient></defs><path d='M4 8L28 8L28 24' fill='none' stroke='url(#g)' stroke-width='3'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesEvenOddFill
{
    [self assertVectorExportPreservesQuartzPixels:@"<path d='M2 2H30V30H2ZM8 8H24V24H8Z' fill='red' fill-rule='evenodd'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesEvenOddFill
{
    [self assertVectorExportPreservesQuartzPixels:@"<path d='M2 2H30V30H2ZM8 8H24V24H8Z' fill='red' fill-rule='evenodd'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesRelativePattern
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><pattern id='p' width='.25' height='.25'><rect width='4' height='8' fill='red'/></pattern></defs><rect x='4' y='4' width='24' height='24' fill='url(#p)'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesRelativePattern
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><pattern id='p' width='.25' height='.25'><rect width='4' height='8' fill='red'/></pattern></defs><rect x='4' y='4' width='24' height='24' fill='url(#p)'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesMultiplyBlend
{
    [self assertVectorExportPreservesQuartzPixels:@"<rect width='32' height='32' fill='red'/><rect x='8' y='8' width='16' height='16' fill='blue' style='mix-blend-mode:multiply'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesMultiplyBlend
{
    [self assertVectorExportPreservesQuartzPixels:@"<rect width='32' height='32' fill='red'/><rect x='8' y='8' width='16' height='16' fill='blue' style='mix-blend-mode:multiply'/>"
                                        optimized:YES];
}

- (void)testExportPreservesStyleOverrides
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'><rect x='5' y='5' width='22' height='22' fill='red' stroke='blue' stroke-width='2'/></svg>"];
    XCTAssertNotNil(svg);
    if(svg == nil) return;
    svg.style.fillColor = XColor.greenColor;
    svg.style.strokeColor = XColor.magentaColor;
    svg.style.lineWidth = 4.f;
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg size:CGSizeMake(32.f, 32.f) options:IJSVGExporterOptionNone];
    IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:[exporter SVGString]];
    XCTAssertEqualObjects([self renderSVG:svg size:64], [self renderSVG:roundTrip size:64]);
}

- (void)assertNodeGraphExportPreservesRelativeUnitsAndDoesNotMutateClientSize:(BOOL)optimized
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='100%' height='100%'><rect x='25%' y='25%' width='50%' height='50%' fill='red'/></svg>"];
    XCTAssertNotNil(svg);
    if(svg == nil) return;
    IJSVGRootNode* node = [svg rootNode];
    XCTAssertNotNil(node);
    if(node == nil) return;
    CGSize clientSize = node.clientSize;
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithRootNode:node
                                                                 size:CGSizeMake(64.f, 64.f)
                                                                style:svg.style
                                                     renderingOptions:svg.renderingOptions
                                                              options:optimized ? IJSVGExporterOptionAll : IJSVGExporterOptionNone
                                                 floatingPointOptions:IJSVGFloatingPointOptionsDefault()];
    NSString* text = [exporter SVGString];
    XCTAssertTrue(CGSizeEqualToSize(node.clientSize, clientSize));
    IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:text];
    XCTAssertEqualObjects([self renderSVG:svg size:64], [self renderSVG:roundTrip size:64], @"%@", text);
}

- (void)testUnoptimizedNodeGraphExportPreservesRelativeUnitsAndDoesNotMutateClientSize
{
    [self assertNodeGraphExportPreservesRelativeUnitsAndDoesNotMutateClientSize:NO];
}

- (void)testOptimizedNodeGraphExportPreservesRelativeUnitsAndDoesNotMutateClientSize
{
    [self assertNodeGraphExportPreservesRelativeUnitsAndDoesNotMutateClientSize:YES];
}

- (void)testGradientColorReplacementSurvivesExport
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'><defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect width='32' height='32' fill='url(#g)'/></svg>"];
    XCTAssertNotNil(svg);
    if(svg == nil) return;
    [svg.style.colors replaceColor:XColor.redColor withColor:XColor.greenColor traits:IJSVGColorUsageTraitGradientStop];
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg size:CGSizeMake(32.f, 32.f) options:IJSVGExporterOptionAll];
    IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:[exporter SVGString]];
    XCTAssertEqualObjects([self renderSVG:svg size:64], [self renderSVG:roundTrip size:64]);
}

- (void)testNodeTraversalStopsAtRequestedDescendant
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'><g id='first'><rect id='nested' width='4' height='4'/></g><rect id='later' width='8' height='8'/></svg>"];
    XCTAssertNotNil(svg);
    if(svg == nil) return;
    NSMutableArray<NSString*>* identifiers = [NSMutableArray array];
    [IJSVGNode walkNodeTree:[svg rootNode] handler:^(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop) {
        if(node.identifier.length != 0) {
            [identifiers addObject:node.identifier];
            if([node.identifier isEqualToString:@"nested"] && stop != NULL) {
                *stop = YES;
            }
        }
    }];
    NSArray<NSString*>* expected = @[ @"first", @"nested" ];
    XCTAssertEqualObjects(identifiers, expected);
}

@end
