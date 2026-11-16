//
//  IJSVGDisplayP3AuditTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 01/11/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTraitedColorStorage.h>
#import <IJSVGFilterGraph.h>
#import <IJSVGTestHelpers.h>

/// Applies the signed transfer function shared by P3 and sRGB.
static double P3AuditLinear(double value)
{
    double magnitude = fabs(value);
    return copysign(magnitude <= .04045 ? magnitude / 12.92 : pow((magnitude + .055) / 1.055, 2.4), value);
}

/// Encodes linear light values without clipping.
static double P3AuditEncoded(double value)
{
    double magnitude = fabs(value);
    return copysign(magnitude <= .0031308 ? magnitude * 12.92 : 1.055 * pow(magnitude, 1 / 2.4) - .055, value);
}

/// Converts through D65 primaries independently of ColorSync.
static void P3AuditToSRGB(const double p3[3], double rgb[3])
{
    double r = P3AuditLinear(p3[0]), g = P3AuditLinear(p3[1]), b = P3AuditLinear(p3[2]);
    rgb[0] = P3AuditEncoded(1.224940176 * r - .224940176 * g);
    rgb[1] = P3AuditEncoded(-.042056955 * r + 1.042056955 * g);
    rgb[2] = P3AuditEncoded(-.019637555 * r - .078636046 * g + 1.098273601 * b);
}

/// Converts sRGB back to P3 using an independent inverse matrix.
static void P3AuditFromSRGB(const double rgb[3], double p3[3])
{
    double r = P3AuditLinear(rgb[0]), g = P3AuditLinear(rgb[1]), b = P3AuditLinear(rgb[2]);
    p3[0] = P3AuditEncoded(.822461969 * r + .177538031 * g);
    p3[1] = P3AuditEncoded(.033194199 * r + .966805801 * g);
    p3[2] = P3AuditEncoded(.017082631 * r + .072397441 * g + .910519929 * b);
}

@interface P3AuditExportDelegate : NSObject <IJSVGExporterDelegate>
@property (nonatomic, assign) CGColorRef expectedColor;
@property (nonatomic, assign) BOOL sawOriginalColor;
@property (nonatomic, assign) BOOL sawConversionOption;
@end

@implementation P3AuditExportDelegate
- (NSString*)svgExporter:(IJSVGExporter*)exporter stringForColor:(CGColorRef)color flags:(IJSVGColorUsageTraits)flag options:(IJSVGColorStringOptions)options
{
    self.sawOriginalColor |= color == self.expectedColor;
    self.sawConversionOption |= (options & IJSVGColorStringOptionConvertToSRGB) != 0;
    return nil;
}
@end

@interface IJSVGDisplayP3AuditTests : XCTestCase
@end

@implementation IJSVGDisplayP3AuditTests

/// Creates fixed size artwork with deterministic sampling.
- (IJSVG*)document:(NSString*)artwork
{
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:[NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'>%@</svg>", artwork] error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(svg);
    svg.renderingBackingScaleHelper = ^CGFloat {
        return 1;
    };
    return svg;
}

/// Reads unbounded premultiplied samples directly from the destination.
- (NSArray<NSNumber*>*)pixel:(IJSVG*)svg space:(CFStringRef)name
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(name);
    CGContextRef context = CGBitmapContextCreate(NULL, 16, 16, 32, 256, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapFloatComponents | kCGBitmapByteOrder32Little);
    XCTAssertTrue(context != NULL);
    if (context == NULL) {
        CGColorSpaceRelease(space);
        return @[];
    }
    [svg drawInRect:CGRectMake(0, 0, 16, 16) context:context];
    CGImageRef image = CGBitmapContextCreateImage(context);
    XCTAssertTrue(CFEqual(CGImageGetColorSpace(image), space));
    XCTAssertEqual(CGImageGetBitsPerComponent(image), 32);
    const float* values = (const float*)CGBitmapContextGetData(context) + 8 * 64 + 8 * 4;
    NSArray* result = @[ @(values[0]), @(values[1]), @(values[2]), @(values[3]) ];
    CGImageRelease(image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return result;
}

/// Checks the public image API and its registered bitmap rendering path.
- (NSArray<NSNumber*>*)imagePixel:(IJSVG*)svg space:(CFStringRef)name
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(name);
    NSError* error = nil;
    CGImageRef image = [svg newCGImageRefWithSize:CGSizeMake(16, 16) flipped:NO colorSpace:space error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(image != NULL);
    if (image == NULL) {
        CGColorSpaceRelease(space);
        return @[];
    }
    XCTAssertTrue(CFEqual(CGImageGetColorSpace(image), space));
    CGContextRef context = CGBitmapContextCreate(NULL, 16, 16, 8, 64, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, 16, 16), image);
    const UInt8* values = (const UInt8*)CGBitmapContextGetData(context) + 8 * 64 + 8 * 4;
    NSArray* result = @[ @(values[0] / 255.), @(values[1] / 255.), @(values[2] / 255.), @(values[3] / 255.) ];
    CGContextRelease(context);
    CGImageRelease(image);
    CGColorSpaceRelease(space);
    return result;
}

/// Checks grammar, calculations, missing channel used values and alpha clamping.
- (void)testParsingGrammarAndCalculations
{
    for (NSString* source in @[ @" COLOR(DISPLAY-P3 1\t50%\n-.1 / 50%) ", @"color(display-p3 calc(2 / 2) min(50%, 75%) calc(-.2 / 2)/.5)", @"color(display-p3 100% calc(25% + 25%) -0.1 / 50%)" ]) {
        CGColorRef color = [IJSVGColor colorFromString:source];
        XCTAssertTrue([IJSVGColor isDisplayP3Color:color]);
        if (color == NULL) {
            continue;
        }
        const CGFloat* values = CGColorGetComponents(color);
        CGFloat expected[] = { 1, .5, -.1, .5 };
        for (NSUInteger index = 0; index < 4; index++) {
            XCTAssertEqualWithAccuracy(values[index], expected[index], .00001, @"%@", source);
        }
    }
    CGColorRef missing = [IJSVGColor colorFromString:@"color(display-p3 none 1 none / none)"];
    XCTAssertTrue(missing != NULL);
    if (missing != NULL) {
        const CGFloat* values = CGColorGetComponents(missing);
        XCTAssertEqual(values[0], 0);
        XCTAssertEqual(values[1], 1);
        XCTAssertEqual(values[2], 0);
        XCTAssertEqual(values[3], 0);
    }
    XCTAssertEqual(CGColorGetAlpha([IJSVGColor colorFromString:@"color(display-p3 1 0 0 / 200%)"]), 1);
    for (NSString* source in @[ @"color(display-p3 1 0)", @"color(display-p3 1 0 0 0.5)", @"color(display-p3 1,0,0)", @"color(display-p3 1 0 0 /)", @"color(display-p3 1 0 0 / .5 / .5)", @"color(display-p3 1 0 0) red", @"color(display-p3 1 0 0", @"color(display-p3 1 0 0))", @"color(display-p3 1 0 .5.5)", @"color(display-p3 calc(50% * 50%) 0 0)", @"color(display-p3 calc(1 / 50%) 0 0)", @"color(unknown 1 0 0)", @"color(display-p3 1deg 0 0)" ]) {
        XCTAssertTrue([IJSVGColor colorFromString:source] == NULL, @"%@", source);
    }
}

/// Verifies ownership, matching and hash identity across profile variants.
- (void)testStorageIdentityAndReplacement
{
    IJSVGTraitedColorStorage* storage = [[IJSVGTraitedColorStorage alloc] init];
    @autoreleasepool {
        CGColorRef parsed = [IJSVGColor colorFromString:@"color(display-p3 1 .3 0 / .5)"];
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
        CGFloat values[] = { 1, .3, 0, .5 };
        CGColorRef supplied = CGColorCreate(space, values);
        IJSVGTraitedColor* first = [IJSVGTraitedColor colorWithColor:parsed traits:IJSVGColorUsageTraitFill];
        IJSVGTraitedColor* second = [IJSVGTraitedColor colorWithColor:supplied traits:IJSVGColorUsageTraitFill];
        XCTAssertEqualObjects(first, second);
        XCTAssertEqual(first.hash, second.hash);
        [storage addColor:first];
        [storage addColor:second];
        XCTAssertEqual(storage.count, 1);
        [storage replaceColor:supplied withColor:parsed traits:IJSVGColorUsageTraitFill];
        CGColorRelease(supplied);
        CGColorSpaceRelease(space);
    }
    CGColorRef parsed = [IJSVGColor colorFromString:@"color(display-p3 1 .3 0 / .5)"];
    CGColorRef replacement = [storage colorForColor:parsed matchingTraits:IJSVGColorUsageTraitFill];
    XCTAssertTrue([IJSVGColor isDisplayP3Color:replacement]);
    XCTAssertTrue(CGColorEqualToColor(replacement, parsed));
    XCTAssertTrue([IJSVGColor preservingColorSpace:NULL] == NULL);
}

/// Preserves extended values across spatial filters and cached output.
- (void)testExtendedNestedFiltersAndCache
{
    IJSVG* svg = [self document:@"<defs><filter id='f'><feOffset/></filter></defs><g filter='url(#f)'><rect width='16' height='16' fill='color(display-p3 1.2 .3 -.1)' filter='url(#f)'/></g>"];
    double expected[] = { 1.2, .3, -.1, 1 };
    for (NSUInteger pass = 0; pass < 2; pass++) {
        NSArray* actual = [self pixel:svg space:kCGColorSpaceExtendedDisplayP3];
        for (NSUInteger index = 0; index < 4; index++) {
            XCTAssertEqualWithAccuracy([actual[index] doubleValue], expected[index], .005);
        }
        [self imagePixel:svg space:kCGColorSpaceSRGB];
    }
}

/// Requires the matrix clamp in its declared interpolation space.
- (void)testOpacityMatrixClampsInPrimitiveSpace
{
    double input[] = { 1, .3, 0 }, rgb[3], expected[3];
    P3AuditToSRGB(input, rgb);
    for (NSUInteger index = 0; index < 3; index++) {
        rgb[index] = fmin(1, fmax(0, rgb[index]));
    }
    P3AuditFromSRGB(rgb, expected);
    for (NSNumber* opacity in @[ @1, @.5 ]) {
        for (NSString* interpolation in @[ @"sRGB", @"linearRGB" ]) {
            IJSVG* svg = [self document:[NSString stringWithFormat:@"<defs><filter id='f' color-interpolation-filters='%@'><feColorMatrix values='1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 %@ 0'/></filter></defs><rect width='16' height='16' fill='color(display-p3 1 .3 0)' filter='url(#f)'/>", interpolation, opacity]];
            NSArray* actual = [self pixel:svg space:kCGColorSpaceExtendedDisplayP3];
            for (NSUInteger index = 0; index < 3; index++) {
                XCTAssertEqualWithAccuracy([actual[index] doubleValue], expected[index] * opacity.doubleValue, .005, @"%@", interpolation);
            }
            XCTAssertEqualWithAccuracy([actual[3] doubleValue], opacity.doubleValue, .005);
        }
    }
}

/// Checks pattern rendering and mask alpha without premature clipping.
- (void)testExtendedPatternAndAlphaMask
{
    for (NSString* filter in @[ @"", @"filter='url(#f)'" ]) {
        IJSVG* svg = [self document:[NSString stringWithFormat:@"<defs><filter id='f'><feOffset/></filter><pattern id='p' width='1' height='1'><rect width='16' height='16' fill='color(display-p3 1.2 .3 -.1)'/></pattern><mask id='m' mask-type='alpha'><rect width='16' height='16' fill='white' fill-opacity='.5'/></mask></defs><rect width='16' height='16' fill='url(#p)' mask='url(#m)' %@/>", filter]];
        NSArray* actual = [self pixel:svg space:kCGColorSpaceExtendedDisplayP3];
        double expected[] = { .6, .15, -.05, .5 };
        for (NSUInteger index = 0; index < 4; index++) {
            XCTAssertEqualWithAccuracy([actual[index] doubleValue], expected[index], .005);
        }
    }
}

/// Measures the Quartz sampling position using a scalar reference ramp.
- (double)gradientSamplePosition
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceExtendedSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, 16, 16, 32, 256, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapFloatComponents | kCGBitmapByteOrder32Little);
    CGFloat components[] = { 0, 0, 0, 1, 1, 1, 1, 1 };
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, NULL, 2);
    CGContextDrawLinearGradient(context, gradient, CGPointZero, CGPointMake(16, 0), 0);
    const float* values = (const float*)CGBitmapContextGetData(context) + 8 * 64 + 8 * 4;
    double position = values[0] * 16;
    XCTAssertGreaterThanOrEqual(position, 8);
    XCTAssertLessThanOrEqual(position, 8.5);
    CGGradientRelease(gradient);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return position;
}

/// Uses distinct stops and independent matrices to check SVG interpolation.
- (void)testGradientsMatchIndependentInterpolation
{
    double first[] = { 1, .3, 0 }, last[] = { 0, .8, 1 }, a[3], b[3];
    double position = [self gradientSamplePosition];
    P3AuditToSRGB(first, a);
    P3AuditToSRGB(last, b);
    for (NSString* interpolation in @[ @"sRGB", @"linearRGB" ]) {
        for (NSString* spread in @[ @"pad", @"repeat", @"reflect" ]) {
            double length = [spread isEqual:@"pad"] ? 16 : 6;
            IJSVG* svg = [self document:[NSString stringWithFormat:@"<defs><linearGradient id='g' gradientUnits='userSpaceOnUse' x1='0' x2='%g' spreadMethod='%@' color-interpolation='%@'><stop stop-color='color(display-p3 1 .3 0)'/><stop offset='1' stop-color='color(display-p3 0 .8 1)'/></linearGradient></defs><rect width='16' height='16' fill='url(#g)'/>", length, spread, interpolation]];
            double fraction = position / length, rgb[3], expected[3];
            if ([spread isEqual:@"pad"]) {
                fraction = fmin(1, fraction);
            } else if ([spread isEqual:@"repeat"]) {
                fraction -= floor(fraction);
            } else {
                fraction = 2 - fraction;
            }
            for (NSUInteger index = 0; index < 3; index++) {
                rgb[index] = [interpolation isEqual:@"sRGB"] ? a[index] * (1 - fraction) + b[index] * fraction : P3AuditEncoded(P3AuditLinear(a[index]) * (1 - fraction) + P3AuditLinear(b[index]) * fraction);
            }
            P3AuditFromSRGB(rgb, expected);
            NSArray* actual = [self pixel:svg space:kCGColorSpaceExtendedDisplayP3];
            for (NSUInteger index = 0; index < 3; index++) {
                XCTAssertEqualWithAccuracy([actual[index] doubleValue], expected[index], .006, @"%@ %@", interpolation, spread);
            }
        }
    }
}

/// Checks resolved styles, filter colors and nested artwork on export.
- (void)testCompatibilityExportAndGradientAlpha
{
    IJSVG* svg = [self document:@"<style>.p {fill:color(display-p3 1 .3 0)}</style><defs><linearGradient id='g'><stop stop-color='color(display-p3 1 .3 0 / .5)' stop-opacity='.5'/><stop offset='1' stop-color='color(display-p3 1 .3 0 / .5)' stop-opacity='.5'/></linearGradient><filter id='f' x='0' y='0' width='100%' height='100%'><feFlood style='flood-color:color(display-p3 1 .3 0)'/></filter><pattern id='p' width='1' height='1'><rect width='16' height='16' class='p'/></pattern></defs><rect width='4' height='16' fill='url(#p)'/><rect x='4' width='4' height='16' filter='url(#f)'/><rect x='8' width='8' height='16' fill='url(#g)'/>"];
    NSString* output = [[[IJSVGExporter alloc] initWithSVG:svg size:CGSizeZero options:IJSVGExporterOptionAll] SVGString];
    XCTAssertTrue([output containsString:@"color(display-p3"]);
    NSError* error = nil;
    IJSVG* restored = [[IJSVG alloc] initWithSVGString:output error:&error];
    XCTAssertNil(error);
    NSArray* actual = [self pixel:restored space:kCGColorSpaceExtendedDisplayP3];
    XCTAssertEqualWithAccuracy([actual[3] doubleValue], .25, .003);
    XCTAssertEqualWithAccuracy([actual[0] doubleValue], .25, .003);
    XCTAssertEqualWithAccuracy([actual[1] doubleValue], .075, .003);
    NSString* compatible = [[[IJSVGExporter alloc] initWithSVG:svg size:CGSizeZero options:IJSVGExporterOptionAll | IJSVGExporterOptionColorConvertToSRGB] SVGString];
    XCTAssertFalse([compatible.lowercaseString containsString:@"display-p3"]);
}

/// Checks source color before a matrix even for an sRGB destination.
- (void)testSRGBDestinationDoesNotClipFilterInput
{
    IJSVG* svg = [self document:@"<defs><filter id='f' color-interpolation-filters='sRGB'><feColorMatrix values='.5 0 0 0 0 0 .5 0 0 0 0 0 .5 0 0 0 0 0 1 0'/></filter></defs><rect width='16' height='16' fill='color(display-p3 1 .3 0)' filter='url(#f)'/>"];
    double input[] = { 1, .3, 0 }, expected[3];
    P3AuditToSRGB(input, expected);
    NSArray* actual = [self imagePixel:svg space:kCGColorSpaceSRGB];
    for (NSUInteger index = 0; index < 3; index++) {
        XCTAssertEqualWithAccuracy([actual[index] doubleValue], fmin(1, fmax(0, expected[index] * .5)), .005);
    }
}

/// Retains original P3 rendering cases and exercises additional image inputs.
- (void)testWideGamutPaintPaths
{
    NSArray<NSString*>* artworks = @[
        @"<rect width='16' height='16' fill='color(display-p3 1 .3 0)'/>",
        @"<defs><linearGradient id='g'><stop stop-color='color(display-p3 1 .3 0)'/><stop offset='1' stop-color='color(display-p3 1 .3 0)'/></linearGradient></defs><rect width='16' height='16' fill='url(#g)'/>",
        @"<defs><linearGradient id='g' x2='25%' spreadMethod='reflect'><stop stop-color='color(display-p3 1 .3 0)'/><stop offset='1' stop-color='color(display-p3 1 .3 0)'/></linearGradient></defs><rect width='16' height='16' fill='url(#g)'/>",
        @"<defs><linearGradient id='g' color-interpolation='linearRGB'><stop stop-color='color(display-p3 1 .3 0)'/><stop offset='1' stop-color='color(display-p3 1 .3 0)'/></linearGradient></defs><rect width='16' height='16' fill='url(#g)'/>",
        @"<path d='M0 8H16' stroke-width='16' stroke='color(display-p3 1 .3 0)'/>",
        @"<defs><filter id='f'><feGaussianBlur stdDeviation='.5'/></filter></defs><rect width='16' height='16' fill='color(display-p3 1 .3 0)' filter='url(#f)'/>",
        @"<defs><filter id='f'><feOffset/></filter></defs><rect width='16' height='16' fill='color(display-p3 1 .3 0)' filter='url(#f)'/>",
        @"<defs><filter id='f'><feFlood flood-color='color(display-p3 1 .3 0)'/></filter></defs><rect width='16' height='16' filter='url(#f)'/>",
        @"<defs><pattern id='p' width='1' height='1'><rect width='16' height='16' fill='color(display-p3 1 .3 0)'/></pattern><filter id='f'><feOffset/></filter></defs><rect width='16' height='16' fill='url(#p)' filter='url(#f)'/>",
        @"<defs><filter id='f'><feOffset in='FillPaint'/></filter></defs><rect width='16' height='16' fill='color(display-p3 1 .3 0)' filter='url(#f)'/>",
        @"<defs><rect id='source' width='16' height='16' fill='color(display-p3 1 .3 0)'/><filter id='f'><feImage href='#source'/></filter></defs><rect width='16' height='16' filter='url(#f)'/>",
        @"<g opacity='.5'><rect width='16' height='16' fill='color(display-p3 1 .3 0)'/></g>"
    ];
    for (NSUInteger artworkIndex = 0; artworkIndex < artworks.count; artworkIndex++) {
        IJSVG* svg = [self document:artworks[artworkIndex]];
        double alpha = artworkIndex == artworks.count - 1 ? .5 : 1;
        for (NSUInteger pass = 0; pass < 2; pass++) {
            NSArray* actual = [self imagePixel:svg space:kCGColorSpaceDisplayP3];
            XCTAssertEqualWithAccuracy([actual[0] doubleValue], alpha, .005, @"%@", artworks[artworkIndex]);
            XCTAssertEqualWithAccuracy([actual[1] doubleValue], .3 * alpha, .005, @"%@", artworks[artworkIndex]);
            XCTAssertEqualWithAccuracy([actual[2] doubleValue], 0, .005, @"%@", artworks[artworkIndex]);
            XCTAssertEqualWithAccuracy([actual[3] doubleValue], alpha, .005, @"%@", artworks[artworkIndex]);
            [self imagePixel:svg space:kCGColorSpaceSRGB];
        }
    }
}

/// Decodes nested image payloads so compatibility cannot hide P3 in base64.
- (void)testCompatibilityConvertsEmbeddedDocuments
{
    NSString* child = @"<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><rect width='16' height='16' fill='color(display-p3 1 .3 0)'/></svg>";
    NSString* payload = [[child dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    NSString* artwork = [NSString stringWithFormat:@"<image width='16' height='16' href='data:image/svg+xml;base64,%@'/><defs><filter id='f'><feImage href='data:image/svg+xml;base64,%@'/><feDiffuseLighting lighting-color='color(display-p3 1 .3 0)'/></filter></defs><rect width='16' height='16' filter='url(#f)'/>", payload, payload];
    IJSVG* svg = [self document:artwork];
    NSString* output = [[[IJSVGExporter alloc] initWithSVG:svg size:CGSizeZero options:IJSVGExporterOptionAll | IJSVGExporterOptionColorConvertToSRGB] SVGString];
    XCTAssertFalse([output containsString:@"display-p3"]);
    NSRegularExpression* expression = [NSRegularExpression regularExpressionWithPattern:@"data:image/svg\\+xml;base64,([A-Za-z0-9+/=]+)" options:0 error:nil];
    NSArray<NSTextCheckingResult*>* matches = [expression matchesInString:output options:0 range:NSMakeRange(0, output.length)];
    XCTAssertEqual(matches.count, 2);
    for (NSTextCheckingResult* match in matches) {
        NSData* data = [[NSData alloc] initWithBase64EncodedString:[output substringWithRange:[match rangeAtIndex:1]] options:0];
        NSString* decoded = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        XCTAssertNotNil(decoded);
        XCTAssertFalse([decoded containsString:@"display-p3"], @"%@", decoded);
        NSError* error = nil;
        IJSVG* restored = [[IJSVG alloc] initWithSVGString:decoded error:&error];
        XCTAssertNil(error);
        NSArray* values = [self pixel:restored space:kCGColorSpaceSRGB];
        XCTAssertGreaterThan([values[0] doubleValue], .9);
        XCTAssertEqualWithAccuracy([values[3] doubleValue], 1, .005);
    }
}

/// Verifies the general evaluator with a software Core Image context.
- (void)testSoftwareFilterEvaluationPreservesP3
{
    IJSVG* svg = [self document:@"<defs><filter id='f' x='0' y='0' width='100%' height='100%'><feFlood flood-color='color(display-p3 1 .3 0)'/><feOffset/></filter></defs><rect width='16' height='16' filter='url(#f)'/>"];
    IJSVGFilterGraph* graph = [[IJSVGFilterGraph alloc] init];
    graph.filter = ((IJSVGGraphicsNode*)svg.rootNode.children.firstObject).filter;
    XCTAssertNotNil(graph.filter);
    graph.boundingBox = graph.viewPort = graph.extent = CGRectMake(0, 0, 16, 16);
    graph.imageTransform = CGAffineTransformIdentity;
    graph.context = [CIContext contextWithOptions:@{ kCIContextUseSoftwareRenderer : @YES }];
    graph.supportsMetalKernels = NO;
    CIImage* result = [graph imageByFilteringSource:CIImage.emptyImage];
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceExtendedDisplayP3);
    float pixel[4] = { 0 };
    [graph.context render:result toBitmap:pixel rowBytes:sizeof(pixel) bounds:CGRectMake(8, 8, 1, 1) format:kCIFormatRGBAf colorSpace:space];
    CGColorSpaceRelease(space);
    XCTAssertEqualWithAccuracy(pixel[0], 1, .005);
    XCTAssertEqualWithAccuracy(pixel[1], .3, .005);
    XCTAssertEqualWithAccuracy(pixel[2], 0, .005);
    XCTAssertEqualWithAccuracy(pixel[3], 1, .005);
}

/// Checks the nonbitmap filter route by rasterizing the resulting PDF in P3.
- (void)testPDFPreservesFilteredP3
{
    IJSVG* svg = [self document:@"<defs><filter id='f'><feOffset/></filter></defs><rect width='16' height='16' fill='color(display-p3 1 .3 0)' filter='url(#f)'/>"];
    NSError* error = nil;
    NSData* data = [svg PDFData:&error];
    XCTAssertNil(error);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
    XCTAssertTrue(document != NULL);
    if (document == NULL) {
        CGDataProviderRelease(provider);
        return;
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
    CGContextRef context = CGBitmapContextCreate(NULL, 16, 16, 8, 64, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextDrawPDFPage(context, CGPDFDocumentGetPage(document, 1));
    const UInt8* pixel = (const UInt8*)CGBitmapContextGetData(context) + 8 * 64 + 8 * 4;
    XCTAssertEqualWithAccuracy(pixel[0], 255, 3);
    XCTAssertEqualWithAccuracy(pixel[1], 77, 3);
    XCTAssertEqualWithAccuracy(pixel[2], 0, 3);
    XCTAssertEqual(pixel[3], 255);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    CGPDFDocumentRelease(document);
    CGDataProviderRelease(provider);
}

/// Checks authored alpha and stop opacity before and after serialization.
- (void)testGradientAlphaMultipliesExactlyOnce
{
    for (NSString* color in @[ @"color(display-p3 1 .3 0 / .5)", @"rgba(255, 77, 0, .5)", @"#ff4d0080" ]) {
        for (NSNumber* opacity in @[ @1, @.5 ]) {
            IJSVG* svg = [self document:[NSString stringWithFormat:@"<defs><linearGradient id='g'><stop stop-color='%@' stop-opacity='%@'/><stop offset='1' stop-color='%@' stop-opacity='%@'/></linearGradient></defs><rect width='16' height='16' fill='url(#g)'/>", color, opacity, color, opacity]];
            NSString* output = [[[IJSVGExporter alloc] initWithSVG:svg size:CGSizeZero options:IJSVGExporterOptionAll] SVGString];
            IJSVG* restored = [[IJSVG alloc] initWithSVGString:output error:nil];
            double expected = CGColorGetAlpha([IJSVGColor colorFromString:color]) * opacity.doubleValue;
            for (IJSVG* image in @[ svg, restored ]) {
                NSArray* values = [self pixel:image space:kCGColorSpaceExtendedDisplayP3];
                XCTAssertEqualWithAccuracy([values[3] doubleValue], expected, .003, @"%@ %@", color, opacity);
            }
        }
    }
}

/// Measures radial geometry with a scalar Quartz ramp independent of color conversion.
- (double)radialSampleDistanceForRadius:(double)radius
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceExtendedSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, 16, 16, 32, 256, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapFloatComponents | kCGBitmapByteOrder32Little);
    XCTAssertTrue(context != NULL);
    CGFloat components[] = { 0, 0, 0, 1, 1, 1, 1, 1 };
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, NULL, 2);
    CGContextDrawRadialGradient(context, gradient, CGPointMake(0, 8), 0, CGPointMake(0, 8), radius, 0);
    const float* values = (const float*)CGBitmapContextGetData(context) + 8 * 64 + 8 * 4;
    double distance = values[0] * radius;
    XCTAssertGreaterThanOrEqual(distance, 8);
    XCTAssertLessThanOrEqual(distance, hypot(9, 1));
    CGGradientRelease(gradient);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return distance;
}

/// Checks radial interpolation and both repeated spread modes against independent matrices.
- (void)testRadialGradientsMatchIndependentInterpolation
{
    double first[] = { 1, .3, 0 }, last[] = { 0, .8, 1 }, a[3], b[3];
    P3AuditToSRGB(first, a);
    P3AuditToSRGB(last, b);
    for (NSString* interpolation in @[ @"sRGB", @"linearRGB" ]) {
        for (NSString* spread in @[ @"pad", @"repeat", @"reflect" ]) {
            double radius = [spread isEqualToString:@"pad"] ? 16 : 6;
            NSString* artwork = [NSString stringWithFormat:@"<defs><radialGradient id='g' gradientUnits='userSpaceOnUse' cx='0' cy='8' fx='0' fy='8' r='%g' spreadMethod='%@' color-interpolation='%@'><stop offset='0' stop-color='color(display-p3 1 .3 0)'/><stop offset='1' stop-color='color(display-p3 0 .8 1)'/></radialGradient></defs><rect width='16' height='16' fill='url(#g)'/>", radius, spread, interpolation];

            // Quartz discretizes radial ramps based on their outer radius.
            // Match the geometric envelope, not the colored stops: the repeat
            // envelope reaches the farthest corner of this 16 by 16 viewport.
            double envelope = [spread isEqualToString:@"pad"] ? radius : hypot(16, 8);
            double distance = [self radialSampleDistanceForRadius:envelope];
            double fraction = distance / radius;
            if ([spread isEqualToString:@"pad"]) {
                fraction = fmin(1, fraction);
            } else if ([spread isEqualToString:@"repeat"]) {
                fraction -= floor(fraction);
            } else {
                fraction = 1 - fabs(1 - fmod(fraction, 2));
            }
            double rgb[3], expected[3];
            for (NSUInteger index = 0; index < 3; index++) {
                rgb[index] = [interpolation isEqualToString:@"sRGB"] ? a[index] * (1 - fraction) + b[index] * fraction : P3AuditEncoded(P3AuditLinear(a[index]) * (1 - fraction) + P3AuditLinear(b[index]) * fraction);
            }
            P3AuditFromSRGB(rgb, expected);
            IJSVG* svg = [self document:artwork];
            for (NSUInteger pass = 0; pass < 2; pass++) {
                NSArray* actual = [self pixel:svg space:kCGColorSpaceExtendedDisplayP3];
                for (NSUInteger index = 0; index < 3; index++) {
                    XCTAssertEqualWithAccuracy([actual[index] doubleValue], expected[index], .006, @"%@ %@ channel %lu", interpolation, spread, index);
                }
                XCTAssertEqualWithAccuracy([actual[3] doubleValue], 1, .003);
            }
        }
    }
}

/// Computes mask opacity from unbounded sRGB channels and SVG luminance coefficients.
- (void)testLuminanceMasksUseDeclaredInterpolationAndAlpha
{
    double p3[] = { 1, .3, 0 }, rgb[3];
    P3AuditToSRGB(p3, rgb);
    for (NSString* interpolation in @[ @"sRGB", @"linearRGB" ]) {
        double luminance = 0;
        double weights[] = { .2125, .7154, .0721 };
        for (NSUInteger index = 0; index < 3; index++) {
            luminance += weights[index] * ([interpolation isEqualToString:@"linearRGB"] ? P3AuditLinear(rgb[index]) : rgb[index]);
        }
        for (NSNumber* alpha in @[ @1, @.5 ]) {
            for (NSString* filter in @[ @"", @"filter='url(#f)'" ]) {
                IJSVG* svg = [self document:[NSString stringWithFormat:@"<defs><filter id='f'><feOffset/></filter><mask id='m' mask-type='luminance' color-interpolation='%@'><rect width='16' height='16' fill='color(display-p3 1 .3 0 / %@)' %@/></mask></defs><rect width='16' height='16' fill='color(display-p3 1 .3 0)' mask='url(#m)'/>", interpolation, alpha, filter]];
                double expectedAlpha = fmin(1, fmax(0, luminance)) * alpha.doubleValue;
                for (NSUInteger pass = 0; pass < 2; pass++) {
                    NSArray* actual = [self pixel:svg space:kCGColorSpaceExtendedDisplayP3];
                    XCTAssertEqualWithAccuracy([actual[3] doubleValue], expectedAlpha, .005, @"%@ alpha %@ %@", interpolation, alpha, filter);
                    for (NSUInteger index = 0; index < 3; index++) {
                        XCTAssertEqualWithAccuracy([actual[index] doubleValue], p3[index] * expectedAlpha, .005);
                    }
                }
            }
        }
    }
}

/// Rasterizes exported PDF pixels into a known P3 destination.
- (NSArray<NSNumber*>*)PDFPixel:(IJSVG*)svg
{
    NSError* error = nil;
    NSData* data = [svg PDFData:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(data);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
    XCTAssertTrue(document != NULL);
    if (document == NULL) {
        CGDataProviderRelease(provider);
        return @[];
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
    CGContextRef context = CGBitmapContextCreate(NULL, 16, 16, 8, 64, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextDrawPDFPage(context, CGPDFDocumentGetPage(document, 1));
    CGImageRef image = CGBitmapContextCreateImage(context);
    XCTAssertTrue(CFEqual(CGImageGetColorSpace(image), space));
    const UInt8* values = (const UInt8*)CGBitmapContextGetData(context) + 8 * 64 + 8 * 4;
    NSArray* result = @[ @(values[0] / 255.), @(values[1] / 255.), @(values[2] / 255.), @(values[3] / 255.) ];
    CGImageRelease(image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    CGPDFDocumentRelease(document);
    CGDataProviderRelease(provider);
    return result;
}

/// Reuses one filtered document through bounded, extended and PDF destinations.
- (void)testDestinationSwitchesPreservePixelsAndProfiles
{
    IJSVG* svg = [self document:@"<defs><filter id='f'><feOffset/></filter></defs><g filter='url(#f)' opacity='.5'><rect width='16' height='16' fill='color(display-p3 1 .3 0)' filter='url(#f)'/></g>"];
    double p3[] = { 1, .3, 0 }, rgb[3];
    P3AuditToSRGB(p3, rgb);
    for (NSUInteger pass = 0; pass < 3; pass++) {
        NSArray* wide = [self imagePixel:svg space:kCGColorSpaceDisplayP3];
        NSArray* narrow = [self imagePixel:svg space:kCGColorSpaceSRGB];
        NSArray* pdf = [self PDFPixel:svg];
        NSArray* extended = [self pixel:svg space:kCGColorSpaceExtendedSRGB];
        NSArray* restored = [self imagePixel:svg space:kCGColorSpaceDisplayP3];
        for (NSArray* values in @[ wide, pdf, restored ]) {
            for (NSUInteger index = 0; index < 3; index++) {
                XCTAssertEqualWithAccuracy([values[index] doubleValue], p3[index] * .5, .006);
            }
            XCTAssertEqualWithAccuracy([values[3] doubleValue], .5, .006);
        }
        for (NSUInteger index = 0; index < 3; index++) {
            XCTAssertEqualWithAccuracy([extended[index] doubleValue], rgb[index] * .5, .005);
            XCTAssertEqualWithAccuracy([narrow[index] doubleValue], fmin(1, fmax(0, rgb[index])) * .5, .006);
        }
        XCTAssertEqualWithAccuracy([narrow[3] doubleValue], .5, .006);
        XCTAssertEqualWithAccuracy([extended[3] doubleValue], .5, .005);
    }
}

/// Verifies default optimized export retains nested styles, gradient alpha and filter colors.
- (void)testExportRoundTripsPreserveP3ProfilesComponentsAndPixels
{
    NSString* child = @"<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><style>.p{fill:color(display-p3 1 .3 0 / .5)}</style><rect class='p' width='16' height='16'/></svg>";
    NSString* payload = [[child dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    NSArray* artworks = @[
        @"<style>.p{fill:color(display-p3 1 .3 0 / .5)}</style><g><rect class='p' width='16' height='16'/></g>",
        @"<defs><radialGradient id='g'><stop stop-color='color(display-p3 1 .3 0 / .5)' stop-opacity='.5'/><stop offset='1' stop-color='color(display-p3 1 .3 0 / .5)' stop-opacity='.5'/></radialGradient></defs><rect width='16' height='16' fill='url(#g)'/>",
        @"<defs><filter id='f'><feFlood flood-color='color(display-p3 1 .3 0 / .5)'/><feOffset/></filter></defs><rect width='16' height='16' filter='url(#f)'/>",
        @"<defs><pattern id='p' width='1' height='1'><g><rect width='16' height='16' fill='color(display-p3 1 .3 0 / .5)'/></g></pattern></defs><rect width='16' height='16' fill='url(#p)'/>",
        [NSString stringWithFormat:@"<image width='16' height='16' href='data:image/svg+xml;base64,%@'/>", payload],
        [NSString stringWithFormat:@"<defs><filter id='f'><feImage href='data:image/svg+xml;base64,%@'/><feOffset/></filter></defs><rect width='16' height='16' filter='url(#f)'/>", payload]
    ];
    for (NSUInteger fixture = 0; fixture < artworks.count; fixture++) {
        double alpha = fixture == 1 ? .25 : .5;
        IJSVG* original = [self document:artworks[fixture]];
        for (NSNumber* options in @[ @0, @(IJSVGExporterOptionAll) ]) {
            NSString* output = [[[IJSVGExporter alloc] initWithSVG:original size:CGSizeZero options:options.unsignedIntegerValue] SVGString];
            NSError* error = nil;
            IJSVG* restored = [[IJSVG alloc] initWithSVGString:output error:&error];
            XCTAssertNil(error);
            XCTAssertNotNil(restored);
            if (restored == nil) {
                continue;
            }
            NSString* colorSource = output;
            if (fixture >= 4) {
                NSRegularExpression* expression = [NSRegularExpression regularExpressionWithPattern:@"data:image/svg\\+xml;base64,([A-Za-z0-9+/=]+)" options:0 error:nil];
                NSTextCheckingResult* match = [expression firstMatchInString:output options:0 range:NSMakeRange(0, output.length)];
                XCTAssertNotNil(match);
                if (match == nil) {
                    continue;
                }
                NSData* data = [[NSData alloc] initWithBase64EncodedString:[output substringWithRange:[match rangeAtIndex:1]] options:0];
                colorSource = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
            NSRegularExpression* expression = [NSRegularExpression regularExpressionWithPattern:@"color\\(display-p3[^)]*\\)" options:0 error:nil];
            NSArray<NSTextCheckingResult*>* matches = [expression matchesInString:colorSource options:0 range:NSMakeRange(0, colorSource.length)];
            XCTAssertGreaterThan(matches.count, 0, @"fixture %lu %@", fixture, output);
            for (NSTextCheckingResult* match in matches) {
                CGColorRef color = [IJSVGColor colorFromString:[colorSource substringWithRange:match.range]];
                XCTAssertTrue(color != NULL);
                if (color == NULL) {
                    continue;
                }
                CFStringRef profile = CGColorSpaceCopyName(CGColorGetColorSpace(color));
                XCTAssertTrue(CFEqual(profile, kCGColorSpaceExtendedDisplayP3));
                CFRelease(profile);
                const CGFloat* values = CGColorGetComponents(color);
                XCTAssertEqualWithAccuracy(values[0], 1, .00001);
                XCTAssertEqualWithAccuracy(values[1], .3, .00001);
                XCTAssertEqualWithAccuracy(values[2], 0, .00001);

                // Stops serialize their effective alpha separately as stop opacity.
                XCTAssertEqualWithAccuracy(values[3], fixture == 1 ? 1 : .5, .00001);
            }
            if (fixture == 1) {
                IJSVGGradient* gradient = (IJSVGGradient*)((IJSVGGraphicsNode*)restored.rootNode.children.firstObject).fill;
                XCTAssertTrue([gradient isKindOfClass:IJSVGGradient.class]);
                XCTAssertEqual(gradient.colors.count, 2);
                for (id stored in gradient.colors) {
                    CGColorRef stop = (__bridge CGColorRef)stored;
                    XCTAssertTrue([IJSVGColor isDisplayP3Color:stop]);
                    XCTAssertEqualWithAccuracy(CGColorGetAlpha(stop), .25, .00001);
                }
            }
            for (IJSVG* svg in @[ original, restored ]) {
                NSArray* actual = [self pixel:svg space:kCGColorSpaceExtendedDisplayP3];
                double expected[] = { alpha, .3 * alpha, 0, alpha };
                for (NSUInteger index = 0; index < 4; index++) {
                    XCTAssertEqualWithAccuracy([actual[index] doubleValue], expected[index], .006, @"fixture %lu options %@ channel %lu", fixture, options, index);
                }
            }
        }
        NSString* compatible = [[[IJSVGExporter alloc] initWithSVG:original size:CGSizeZero options:IJSVGExporterOptionAll | IJSVGExporterOptionColorConvertToSRGB] SVGString];
        XCTAssertFalse([compatible.lowercaseString containsString:@"display-p3"]);
        NSError* error = nil;
        IJSVG* restored = [[IJSVG alloc] initWithSVGString:compatible error:&error];
        XCTAssertNil(error);
        XCTAssertNotNil(restored);
        if (restored == nil) {
            continue;
        }

        // Use ColorSync directly as the independent reference for compatibility gamut mapping.
        CGColorSpaceRef p3Space = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
        CGColorSpaceRef rgbSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGFloat channels[] = { 1, .3, 0, 1 };
        CGColorRef source = CGColorCreate(p3Space, channels);
        CGColorRef mapped = CGColorCreateCopyByMatchingToColorSpace(rgbSpace, kCGRenderingIntentDefault, source, NULL);
        XCTAssertTrue(mapped != NULL);
        if (mapped != NULL) {
            const CGFloat* expected = CGColorGetComponents(mapped);
            NSArray* actual = [self imagePixel:restored space:kCGColorSpaceSRGB];
            for (NSUInteger index = 0; index < 3; index++) {
                XCTAssertEqualWithAccuracy([actual[index] doubleValue], expected[index] * alpha, .006, @"compatibility fixture %lu", fixture);
            }
            XCTAssertEqualWithAccuracy([actual[3] doubleValue], alpha, .006);
            CGColorRelease(mapped);
        }
        CGColorRelease(source);
        CGColorSpaceRelease(rgbSpace);
        CGColorSpaceRelease(p3Space);
    }
}

/// Checks that optimized export retains the mask interpolation rather than inheriting a new default.
- (void)testLuminanceMaskExportRetainsInterpolation
{
    double p3[] = { 1, .3, 0 }, rgb[3];
    P3AuditToSRGB(p3, rgb);
    double expectedAlpha = (.2125 * P3AuditLinear(rgb[0]) + .7154 * P3AuditLinear(rgb[1]) + .0721 * P3AuditLinear(rgb[2])) * .5;
    IJSVG* original = [self document:@"<g color-interpolation='linearRGB'><defs><mask id='m' mask-type='luminance'><rect width='16' height='16' fill='color(display-p3 1 .3 0 / .5)'/></mask></defs><rect width='16' height='16' fill='color(display-p3 1 .3 0)' mask='url(#m)'/></g>"];
    for (NSNumber* options in @[ @0, @(IJSVGExporterOptionAll) ]) {
        NSString* output = [[[IJSVGExporter alloc] initWithSVG:original size:CGSizeZero options:options.unsignedIntegerValue] SVGString];
        NSError* error = nil;
        IJSVG* restored = [[IJSVG alloc] initWithSVGString:output error:&error];
        XCTAssertNil(error);
        XCTAssertNotNil(restored);
        if (restored == nil) {
            continue;
        }
        XCTAssertTrue([output containsString:@"linearRGB"]);
        for (IJSVG* svg in @[ original, restored ]) {
            NSArray* actual = [self pixel:svg space:kCGColorSpaceExtendedDisplayP3];
            XCTAssertEqualWithAccuracy([actual[3] doubleValue], expectedAlpha, .005, @"options %@ %@", options, output);
            for (NSUInteger index = 0; index < 3; index++) {
                XCTAssertEqualWithAccuracy([actual[index] doubleValue], p3[index] * expectedAlpha, .005);
            }
        }
    }
}

/// Retains the sRGB mask contract for primary colors and translucent gray.
- (void)testLuminanceMaskSRGBReferenceColors
{
    NSArray* colors = @[ @"rgb(255 0 0)", @"rgb(0 255 0)", @"rgb(0 0 255)", @"rgb(50% 50% 50% / .5)" ];
    for (NSString* interpolation in @[ @"sRGB", @"linearRGB" ]) {
        double expected[] = { .2125, .7154, .0721, ([interpolation isEqualToString:@"linearRGB"] ? P3AuditLinear(.5) : .5) * .5 };
        for (NSUInteger fixture = 0; fixture < colors.count; fixture++) {
            IJSVG* svg = [self document:[NSString stringWithFormat:@"<defs><mask id='m' color-interpolation='%@'><rect width='16' height='16' fill='%@'/></mask></defs><rect width='16' height='16' fill='white' mask='url(#m)'/>", interpolation, colors[fixture]]];
            NSArray* actual = [self pixel:svg space:kCGColorSpaceExtendedSRGB];
            for (NSUInteger channel = 0; channel < 4; channel++) {
                XCTAssertEqualWithAccuracy([actual[channel] doubleValue], expected[fixture], .003, @"%@ %@", interpolation, colors[fixture]);
            }
        }
    }
}

/// Export delegates see the stored identity before optional compatibility conversion.
- (void)testExportDelegatePreservesP3Identity
{
    IJSVG* svg = [self document:@"<rect width='16' height='16' fill='color(display-p3 1 .3 0)'/>"];
    IJSVGGraphicsNode* node = (IJSVGGraphicsNode*)svg.rootNode.children.firstObject;
    CGColorRef color = ((IJSVGColorNode*)node.fill).color;
    XCTAssertTrue(color != NULL);
    XCTAssertTrue([IJSVGColor preservingColorSpace:color] == color);
    for (NSNumber* compatibility in @[ @NO, @YES ]) {
        P3AuditExportDelegate* delegate = [[P3AuditExportDelegate alloc] init];
        delegate.expectedColor = color;
        IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg size:CGSizeZero options:compatibility.boolValue ? IJSVGExporterOptionColorConvertToSRGB : 0];
        exporter.delegate = delegate;
        NSString* output = exporter.SVGString;
        XCTAssertTrue(delegate.sawOriginalColor);
        XCTAssertEqual(delegate.sawConversionOption, compatibility.boolValue);
        XCTAssertEqual([output containsString:@"display-p3"], !compatibility.boolValue);
    }
}

/// A P3 shadow must match the general graph in both narrow and wide destinations.
- (void)testP3DropShadowMatchesGeneralEvaluator
{
    for (NSString* interpolation in @[ @"sRGB", @"linearRGB" ]) {
        NSString* artwork = [NSString stringWithFormat:@"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='16' height='16' color-interpolation-filters='%@'><feDropShadow dx='5' dy='0' stdDeviation='1' flood-color='color(display-p3 1 .3 0 / .7)' flood-opacity='.6'/>EXTRA</filter></defs><rect x='1' y='1' width='4' height='14' fill='white' filter='url(#f)'/>", interpolation];
        IJSVG* direct = [self document:[artwork stringByReplacingOccurrencesOfString:@"EXTRA" withString:@""]];
        IJSVG* general = [self document:[artwork stringByReplacingOccurrencesOfString:@"EXTRA" withString:@"<feOffset/>"]];
        for (id name in @[ (__bridge id)kCGColorSpaceSRGB, (__bridge id)kCGColorSpaceDisplayP3, (__bridge id)kCGColorSpaceExtendedDisplayP3 ]) {
            BOOL extended = CFEqual((__bridge CFStringRef)name, kCGColorSpaceExtendedDisplayP3);
            NSArray* actual = extended ? [self pixel:direct space:(__bridge CFStringRef)name] : [self imagePixel:direct space:(__bridge CFStringRef)name];
            NSArray* expected = extended ? [self pixel:general space:(__bridge CFStringRef)name] : [self imagePixel:general space:(__bridge CFStringRef)name];
            XCTAssertEqual(actual.count, 4);
            XCTAssertEqual(expected.count, 4);
            if (actual.count != 4 || expected.count != 4) {
                continue;
            }
            XCTAssertGreaterThan([actual[3] doubleValue], .1);
            for (NSUInteger channel = 0; channel < 4; channel++) {
                XCTAssertEqualWithAccuracy([actual[channel] doubleValue], [expected[channel] doubleValue], .012);
            }
        }
        IJSVGFilterGraph* graph = [[IJSVGFilterGraph alloc] init];
        graph.filter = ((IJSVGGraphicsNode*)direct.rootNode.children.firstObject).filter;
        graph.boundingBox = graph.viewPort = graph.extent = CGRectMake(0, 0, 16, 16);
        graph.imageTransform = CGAffineTransformIdentity;
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef bitmap = CGBitmapContextCreate(NULL, 16, 16, 8, 64, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        XCTAssertTrue(bitmap != NULL);
        if (bitmap != NULL) {
            XCTAssertNil([graph metalBlurJobForBitmap:bitmap]);
            CGContextRelease(bitmap);
        }
        CGColorSpaceRelease(space);
    }
}

/// Specular RGB may exceed the gamut while its coverage remains bounded.
- (void)testP3SpecularLightingPreservesExtendedRGBAndBoundsAlpha
{
    double p3[] = { 1, .3, 0 }, rgb[3];
    P3AuditToSRGB(p3, rgb);
    for (NSString* interpolation in @[ @"sRGB", @"linearRGB" ]) {
        for (NSNumber* constant in @[ @.5, @2 ]) {
            IJSVG* svg = [self document:[NSString stringWithFormat:@"<defs><filter id='f' color-interpolation-filters='%@'><feSpecularLighting lighting-color='color(display-p3 1 .3 0)' surfaceScale='0' specularConstant='%@' specularExponent='1'><feDistantLight elevation='90'/></feSpecularLighting></filter></defs><rect width='16' height='16' filter='url(#f)'/>", interpolation, constant]];
            double expected[3], alpha = 0;
            for (NSUInteger channel = 0; channel < 3; channel++) {
                expected[channel] = ([interpolation isEqualToString:@"linearRGB"] ? P3AuditLinear(rgb[channel]) : rgb[channel]) * constant.doubleValue;
                alpha = fmax(alpha, expected[channel]);
            }
            alpha = fmin(1, alpha);

            // Read in the primitive color space to compare premultiplied output directly.
            NSArray* actual = [self pixel:svg space:[interpolation isEqualToString:@"linearRGB"] ? kCGColorSpaceExtendedLinearSRGB : kCGColorSpaceExtendedSRGB];
            for (NSUInteger channel = 0; channel < 3; channel++) {
                XCTAssertEqualWithAccuracy([actual[channel] doubleValue], expected[channel], .008);
            }
            XCTAssertEqualWithAccuracy([actual[3] doubleValue], alpha, .005);
        }
    }
}

/// Uses a flat surface and overhead light for an independent lighting and export reference.
- (void)testLightingColorExportRoundTrip
{
    double p3[] = { 1, .3, 0 }, rgb[3];
    P3AuditToSRGB(p3, rgb);
    for (NSString* interpolation in @[ @"sRGB", @"linearRGB" ]) {
        IJSVG* original = [self document:[NSString stringWithFormat:@"<style>.light {lighting-color:color(display-p3 1 .3 0)}</style><defs><filter id='f' color-interpolation-filters='%@'><feDiffuseLighting class='light' surfaceScale='0' diffuseConstant='.5'><feDistantLight azimuth='0' elevation='90'/></feDiffuseLighting></filter></defs><rect width='16' height='16' fill='white' filter='url(#f)'/>", interpolation]];
        double expectedRGB[3], expectedP3[3];
        for (NSUInteger channel = 0; channel < 3; channel++) {
            double value = [interpolation isEqualToString:@"linearRGB"] ? P3AuditLinear(rgb[channel]) : rgb[channel];

            // P3 lighting retains signed, extended interpolation components.
            value *= .5;
            expectedRGB[channel] = [interpolation isEqualToString:@"linearRGB"] ? P3AuditEncoded(value) : value;
        }
        P3AuditFromSRGB(expectedRGB, expectedP3);
        for (NSNumber* options in @[ @0, @(IJSVGExporterOptionAll) ]) {
            NSString* output = [[[IJSVGExporter alloc] initWithSVG:original size:CGSizeZero options:options.unsignedIntegerValue] SVGString];
            NSError* error = nil;
            IJSVG* restored = [[IJSVG alloc] initWithSVGString:output error:&error];
            XCTAssertNil(error);
            XCTAssertNotNil(restored);
            if (restored == nil) {
                continue;
            }
            for (IJSVG* svg in @[ original, restored ]) {
                IJSVGFilterPrimitive* primitive = (IJSVGFilterPrimitive*)((IJSVGGraphicsNode*)svg.rootNode.children.firstObject).filter.children.firstObject;
                CGColorRef light = [IJSVGColor colorFromString:primitive.parameters[@"lighting-color"]];
                XCTAssertTrue([IJSVGColor isDisplayP3Color:light]);
                if (light != NULL) {
                    const CGFloat* values = CGColorGetComponents(light);
                    for (NSUInteger channel = 0; channel < 3; channel++) {
                        XCTAssertEqualWithAccuracy(values[channel], p3[channel], .00001);
                    }
                }
                NSArray* actual = [self pixel:svg space:kCGColorSpaceExtendedDisplayP3];
                for (NSUInteger channel = 0; channel < 3; channel++) {
                    XCTAssertEqualWithAccuracy([actual[channel] doubleValue], expectedP3[channel], .006, @"%@ %@", interpolation, options);
                }
                XCTAssertEqualWithAccuracy([actual[3] doubleValue], 1, .003);
            }
        }
    }
}

@end
