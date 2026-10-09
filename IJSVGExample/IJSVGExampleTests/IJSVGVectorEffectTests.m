#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <XCTest/XCTest.h>

@interface IJSVGVectorEffectTests : XCTestCase
@end

@implementation IJSVGVectorEffectTests

- (IJSVG*)documentWithBody:(NSString*)body
{
    NSString* xml = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100' "
         "viewBox='0 0 100 100'>%@</svg>", body];
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml error:&error];
    XCTAssertNotNil(svg, @"%@", error);
    return svg;
}

- (NSData*)pixelsForSVG:(IJSVG*)svg size:(NSUInteger)size backingScale:(NSUInteger)backingScale
{
    return [self pixelsForSVG:svg size:size backingScale:backingScale
                 drawingRect:CGRectMake(0, 0, size, size)];
}

- (NSData*)pixelsForSVG:(IJSVG*)svg size:(NSUInteger)size backingScale:(NSUInteger)backingScale
           drawingRect:(CGRect)drawingRect
{
    if(svg == nil) {
        return nil;
    }
    NSUInteger dimension = size * backingScale;
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    XCTAssertTrue(space != NULL);
    if(space == NULL) {
        return nil;
    }
    CGContextRef context = CGBitmapContextCreate(NULL, dimension, dimension, 8,
        dimension * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) {
        return nil;
    }
    CGContextScaleCTM(context, backingScale, backingScale);
    [svg drawInRect:drawingRect context:context];
    const void* bytes = CGBitmapContextGetData(context);
    XCTAssertTrue(bytes != NULL);
    NSData* pixels = bytes == NULL ? nil :
        [NSData dataWithBytes:bytes length:dimension * dimension * 4];
    CGContextRelease(context);
    return pixels;
}

- (NSUInteger)coverage:(NSData*)pixels dimension:(NSUInteger)dimension x:(NSUInteger)x
{
    XCTAssertEqual(pixels.length, dimension * dimension * 4);
    if(pixels.length != dimension * dimension * 4) {
        return NSNotFound;
    }
    const uint8_t* bytes = pixels.bytes;
    NSUInteger count = 0;
    for(NSUInteger y = 0; y < dimension; y++) {
        if(bytes[(y * dimension + x) * 4 + 3] > 127) {
            count++;
        }
    }
    return count;
}

- (NSUInteger)coverageForBody:(NSString*)body
{
    NSData* pixels = [self pixelsForSVG:[self documentWithBody:body] size:100 backingScale:1];
    return [self coverage:pixels dimension:100 x:40];
}

- (void)testTransformedStrokeKeepsWidth
{
    for(NSString* transform in @[@"scale(2 4)", @"matrix(2 0 1 4 0 0)", @"matrix(-2 0 1 4 80 0)"]) {
        NSString* body = [NSString stringWithFormat:
            @"<path d='M 5 10 H 30' transform='%@' fill='none' stroke='black' "
             "stroke-width='4' vector-effect='non-scaling-stroke'/>", transform];
        XCTAssertEqual([self coverageForBody:body], 4u, @"%@", transform);
    }
}

- (void)testViewportResizeAndBackingScale
{
    IJSVG* svg = [self documentWithBody:
        @"<path d='M 10 50 H 90' stroke='black' stroke-width='4' "
         "vector-effect='non-scaling-stroke'/>"];
    // Reuse one renderer to exercise cache invalidation on viewport changes.
    for(NSNumber* sizeValue in @[@100, @200, @50, @100]) {
        NSUInteger size = sizeValue.unsignedIntegerValue;
        for(NSUInteger scale = 1; scale <= 2; scale++) {
            NSData* pixels = [self pixelsForSVG:svg size:size backingScale:scale];
            NSUInteger dimension = size * scale;
            XCTAssertEqual([self coverage:pixels dimension:dimension x:dimension / 2],
                           4 * scale, @"size=%lu scale=%lu", size, scale);
        }
    }
}

- (void)testNormalAndNonScalingStrokes
{
    NSArray<NSString*>* declarations = @[@"", @"vector-effect='none'",
        @"vector-effect='non-scaling-stroke'", @"style='vector-effect:non-scaling-stroke'"];
    NSArray<NSNumber*>* expected = @[@16, @16, @4, @4];
    for(NSUInteger index = 0; index < declarations.count; index++) {
        NSString* body = [NSString stringWithFormat:
            @"<path d='M 5 10 H 30' transform='scale(2 4)' stroke='black' "
             "stroke-width='4' %@/>", declarations[index]];
        XCTAssertEqual([self coverageForBody:body], expected[index].unsignedIntegerValue,
                       @"%@", declarations[index]);
    }
}

- (void)testVectorEffectDoesNotInheritImplicitly
{
    NSArray<NSString*>* declarations = @[@"", @"vector-effect='inherit'",
        @"vector-effect='initial'", @"vector-effect='unset'"];
    NSArray<NSNumber*>* expected = @[@16, @4, @16, @16];
    for(NSUInteger index = 0; index < declarations.count; index++) {
        NSString* body = [NSString stringWithFormat:
            @"<g vector-effect='non-scaling-stroke' transform='scale(2 4)'>"
             "<path d='M 5 10 H 30' stroke='black' stroke-width='4' %@/></g>",
            declarations[index]];
        XCTAssertEqual([self coverageForBody:body], expected[index].unsignedIntegerValue,
                       @"%@", declarations[index]);
    }
}

- (void)testStylesheetOverridesPresentationAttribute
{
    XCTAssertEqual([self coverageForBody:
        @"<style>.fixed { vector-effect: non-scaling-stroke; }</style>"
         "<path class='fixed' vector-effect='none' d='M 5 10 H 30' "
         "transform='scale(2 4)' stroke='black' stroke-width='4'/>"], 4u);
}

- (void)testPaintServersAndDashes
{
    for(NSString* stroke in @[@"black", @"url(#gradient)", @"url(#pattern)"]) {
        NSString* body = [NSString stringWithFormat:
            @"<defs><linearGradient id='gradient' gradientUnits='userSpaceOnUse' x2='50'>"
             "<stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient>"
             "<pattern id='pattern' patternUnits='userSpaceOnUse' width='10' height='10'>"
             "<rect width='10' height='10' fill='green'/></pattern></defs>"
             "<path d='M 5 10 H 40' transform='scale(2 4)' fill='none' stroke='%@' "
             "stroke-width='4' stroke-dasharray='6 6' vector-effect='non-scaling-stroke'/>", stroke];
        NSData* pixels = [self pixelsForSVG:[self documentWithBody:body] size:100 backingScale:1];
        XCTAssertEqual([self coverage:pixels dimension:100 x:12], 4u, @"%@", stroke);
        XCTAssertEqual([self coverage:pixels dimension:100 x:18], 0u, @"%@", stroke);
        XCTAssertEqual([self coverage:pixels dimension:100 x:24], 4u, @"%@", stroke);
    }
}

- (void)testNestedViewport
{
    XCTAssertEqual([self coverageForBody:
        @"<svg width='100' height='100' viewBox='0 0 25 25'><g transform='scale(2)'>"
         "<path d='M 1 5 H 10' stroke='black' stroke-width='4' "
         "vector-effect='non-scaling-stroke'/></g></svg>"], 4u);
}

- (void)testLocalNonScalingStrokeExampleSurvivesExport
{
    NSString* path = [@(__FILE__).stringByDeletingLastPathComponent.stringByDeletingLastPathComponent
        stringByAppendingPathComponent:@"IJSVGExample/non-scaling-stroke.svg"];
    NSString* xml = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    XCTAssertNotNil(xml);
    if(xml == nil) return;
    IJSVG* source = [[IJSVG alloc] initWithSVGString:xml];
    for(NSNumber* optionValue in @[@(IJSVGExporterOptionNone),
                                  @(IJSVGExporterOptionCreateUseForPaths),
                                  @(IJSVGExporterOptionAll),
                                  @(IJSVGExporterOptionAll & ~IJSVGExporterOptionConvertStrokesToPaths)]) {
        NSString* exported = [source SVGStringWithSize:CGSizeMake(500, 240)
                                             options:optionValue.integerValue];
        NSXMLDocument* document = [[NSXMLDocument alloc] initWithXMLString:exported options:0 error:NULL];
        NSArray* fixedPaths = [document nodesForXPath:@"//path[@vector-effect='non-scaling-stroke']"
                                               error:NULL];
        XCTAssertEqual(fixedPaths.count, 1u, @"%@", exported);
        IJSVG* restored = [[IJSVG alloc] initWithSVGString:exported];
        XCTAssertNotNil(restored);
        for(NSNumber* sizeValue in @[@500, @1000]) {
            NSUInteger size = sizeValue.unsignedIntegerValue;
            CGRect rect = CGRectMake(0, 0, size, size * 240.0 / 500);
            NSData* before = [self pixelsForSVG:source size:size backingScale:1 drawingRect:rect];
            NSData* after = [self pixelsForSVG:restored size:size backingScale:1 drawingRect:rect];
            XCTAssertEqual(before.length, after.length);
            const uint8_t* expected = before.bytes;
            const uint8_t* actual = after.bytes;
            NSUInteger difference = 0;
            for(NSUInteger index = 0; index < MIN(before.length, after.length); index++) {
                difference += ABS((int)expected[index] - (int)actual[index]);
            }
            // Permit only minor outline serialization / antialiasing differences.
            XCTAssertLessThan((double)difference / before.length, 0.01,
                              @"options=%@ size=%@", optionValue, sizeValue);
        }
    }
}

- (void)testExportPreservesNonScalingStroke
{
    for(NSString* stroke in @[@"black", @"url(#gradient)", @"url(#pattern)"]) {
        IJSVG* svg = [self documentWithBody:[NSString stringWithFormat:
            @"<defs><linearGradient id='gradient' gradientUnits='userSpaceOnUse' x2='40'>"
             "<stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient>"
             "<pattern id='pattern' patternUnits='userSpaceOnUse' width='10' height='10'>"
             "<rect width='10' height='10' fill='green'/></pattern></defs>"
             "<path d='M 5 10 H 40' transform='scale(2 4)' fill='none' stroke='%@' "
             "stroke-width='4' stroke-dasharray='6 6' vector-effect='non-scaling-stroke'/>", stroke]];
        for(NSNumber* optionValue in @[@(IJSVGExporterOptionNone),
                                      @(IJSVGExporterOptionConvertStrokesToPaths),
                                      @(IJSVGExporterOptionAll),
                                      @(IJSVGExporterOptionAll & ~IJSVGExporterOptionConvertStrokesToPaths)]) {
            IJSVGExporterOptions options = optionValue.integerValue;
            NSNumber* convert = @((options & IJSVGExporterOptionConvertStrokesToPaths) != 0);
            NSString* exported = [svg SVGStringWithSize:CGSizeMake(100, 100) options:options];
            XCTAssertTrue([exported containsString:@"non-scaling-stroke"]);
            IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:exported];
            XCTAssertNotNil(roundTrip);
            // Non-scaling strokes must survive every export option and viewport size.
            NSArray<NSNumber*>* sizes = @[@100, @200];
            for(NSNumber* sizeValue in sizes) {
                NSUInteger size = sizeValue.unsignedIntegerValue;
                NSData* expected = [self pixelsForSVG:svg size:size backingScale:1];
                NSData* actual = [self pixelsForSVG:roundTrip size:size backingScale:1];
                XCTAssertEqual(actual.length, expected.length);
                if(actual.length != expected.length) continue;
                const uint8_t* a = actual.bytes;
                const uint8_t* e = expected.bytes;
                NSUInteger difference = 0;
                for(NSUInteger index = 0; index < actual.length; index++) {
                    difference += ABS((int)a[index] - (int)e[index]);
                }
                // Allow small path serialization / antialiasing rounding differences.
                XCTAssertLessThan((double)difference / actual.length, 0.25,
                                  @"stroke=%@ convert=%@ size=%@", stroke, convert, sizeValue);
            }
        }
    }
}

- (void)testResizingMatchesFreshRender
{
    NSArray<NSString*>* bodies = @[
        (@"<g opacity='.6' transform='matrix(2 .3 .7 1.5 5 5)'><path d='M 5 10 C 20 0 30 30 35 20' "
         "fill='none' stroke='black' stroke-width='4' stroke-dasharray='5 3' "
         "stroke-linejoin='round' vector-effect='non-scaling-stroke'/></g>"),
        (@"<defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/>"
         "</linearGradient></defs><path d='M 10 20 L 70 40 L 20 70' fill='none' stroke='url(#g)' "
         "stroke-width='4' vector-effect='non-scaling-stroke'/>"),
        (@"<svg x='10' y='10' width='80' height='60' viewBox='0 0 40 40' preserveAspectRatio='none'>"
         "<path d='M 5 10 H 30 V 30' fill='none' stroke='black' stroke-width='4' "
         "vector-effect='non-scaling-stroke'/></svg>"),
        (@"<defs><filter id='f'><feGaussianBlur stdDeviation='1'/></filter></defs>"
         "<path d='M 10 20 H 80 V 70' fill='none' stroke='black' stroke-width='4' "
         "vector-effect='non-scaling-stroke' filter='url(#f)'/>"),
        (@"<defs><pattern id='p' width='10' height='10' patternUnits='userSpaceOnUse'>"
         "<rect width='10' height='10' fill='green'/></pattern></defs>"
         "<path d='M 10 20 H 80 V 70' fill='none' stroke='url(#p)' stroke-width='4' "
         "vector-effect='non-scaling-stroke'/>")
    ];
    for(NSString* body in bodies) {
        IJSVG* cached = [self documentWithBody:body];
        IJSVG* fresh = [self documentWithBody:body];
        for(NSNumber* sizeValue in @[@100, @137, @63, @200, @100]) {
            NSUInteger size = sizeValue.unsignedIntegerValue;
            [fresh setNeedsDisplay];
            NSData* expected = [self pixelsForSVG:fresh size:size backingScale:1];
            NSData* actual = [self pixelsForSVG:cached size:size backingScale:1];
            XCTAssertEqualObjects(actual, expected, @"size=%@ body=%@", sizeValue, body);
        }
    }
}

- (void)testNonUniformViewportResizingMatchesFreshRender
{
    for(NSString* aspectRatio in @[@"none", @"xMidYMid meet", @"xMaxYMin slice"]) {
        NSString* xml = [NSString stringWithFormat:
            @"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100' viewBox='0 0 100 100' "
             "preserveAspectRatio='%@'><path d='M 10 20 C 40 0 70 80 90 60' fill='none' "
             "transform='matrix(1 .1 .3 1 0 0)' stroke='black' stroke-width='3.5' "
             "stroke-dasharray='3.25 1.75' vector-effect='non-scaling-stroke'/></svg>", aspectRatio];
        IJSVG* cached = [[IJSVG alloc] initWithSVGString:xml];
        IJSVG* fresh = [[IJSVG alloc] initWithSVGString:xml];
        for(NSUInteger index = 0; index < 20; index++) {
            CGRect rect = CGRectMake(7, 9, 63 + index * 7 % 130, 73 + index * 11 % 110);
            [fresh setNeedsDisplay];
            NSData* actual = [self pixelsForSVG:cached size:240 backingScale:2 drawingRect:rect];
            NSData* expected = [self pixelsForSVG:fresh size:240 backingScale:2 drawingRect:rect];
            XCTAssertEqualObjects(actual, expected, @"aspect=%@ index=%lu", aspectRatio, index);
        }
    }
}

- (void)testStrokeConversionPreservesNonScalingStroke
{
    IJSVG* svg = [self documentWithBody:
        @"<path d='M 10 50 H 90' stroke='black' stroke-width='4' vector-effect='non-scaling-stroke'/>"];
    NSString* exported = [svg SVGStringWithSize:CGSizeMake(200, 200)
        options:IJSVGExporterOptionConvertStrokesToPaths];
    IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:exported];
    XCTAssertNotNil(roundTrip);
    XCTAssertTrue([exported containsString:@"non-scaling-stroke"]);
    for(NSNumber* sizeValue in @[@100, @200, @400]) {
        NSUInteger size = sizeValue.unsignedIntegerValue;
        NSData* pixels = [self pixelsForSVG:roundTrip size:size backingScale:1];
        XCTAssertEqual([self coverage:pixels dimension:size x:size / 2], 4u);
    }
}

- (void)testSingularTransformProducesNoStroke
{
    IJSVG* svg = [self documentWithBody:
        @"<path d='M 10 50 H 90' transform='scale(0 2)' stroke='black' stroke-width='4' "
         "vector-effect='non-scaling-stroke'/>"];
    NSData* pixels = [self pixelsForSVG:svg size:100 backingScale:1];
    XCTAssertNotNil(pixels);
    XCTAssertEqualObjects(pixels, [NSMutableData dataWithLength:100 * 100 * 4]);
}

@end
