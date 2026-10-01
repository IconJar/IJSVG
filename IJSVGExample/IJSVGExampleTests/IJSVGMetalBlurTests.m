#import <IJSVGFilterTestHelpers.h>

@interface IJSVGMetalBlurTests : XCTestCase
@end

@implementation IJSVGMetalBlurTests

- (NSData*)renderDocument:(NSString*)document size:(NSUInteger)size flipped:(BOOL)flipped
{
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:document error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(svg);
    if(svg == nil) {
        return nil;
    }
    svg.renderingBackingScaleHelper = ^CGFloat { return 1; };
    CGContextRef bitmap = [self newBitmapWithSize:size flipped:flipped];
    if(bitmap == NULL) {
        return nil;
    }
    [svg drawInRect:CGRectMake(0, 0, size, size) context:bitmap];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(bitmap) length:size * size * 4];
    CGContextRelease(bitmap);
    return pixels;
}

- (NSString*)documentWithRadius:(double)radius colorSpace:(NSString*)colorSpace
                 explicitRegion:(BOOL)explicitRegion transparentBlend:(BOOL)transparentBlend
{
    NSString* region = @"x='.175' y='.31' width='319.2' height='318.5'";
    NSString* prefix = transparentBlend
        ? @"<feFlood flood-opacity='0' result='empty'/><feBlend in='SourceGraphic' in2='empty' mode='normal'/>"
        : @"";
    return [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='320' height='320'>"
        "<defs><filter id='f' filterUnits='userSpaceOnUse' %@ color-interpolation-filters='%@'>"
        "%@<feGaussianBlur stdDeviation='%.9g' %@/></filter></defs>"
        "<g filter='url(#f)' opacity='.8'>"
        "<rect width='175' height='315' fill='#e03080' opacity='.37'/>"
        "<circle cx='190' cy='167' r='147' fill='#2090d0' opacity='.63'/>"
        "<rect x='121.3' y='2.4' width='190' height='58.7' fill='#20f040'/>"
        "</g></svg>", region, colorSpace, prefix, radius, explicitRegion ? region : @""];
}

- (void)testMatchesCoreImage
{
    for(NSNumber* radius in @[@0.2, @0.5, @1.3, @2.67857143, @4.0, @4.1, @6.0, @8.0, @12.0]) {
        for(NSString* space in @[@"sRGB", @"linearRGB"]) {
            for(NSNumber* flipped in @[@NO, @YES]) {
                NSString* name = [NSString stringWithFormat:@"radius=%@ space=%@ flipped=%@", radius, space, flipped];
                [XCTContext runActivityNamed:name block:^(id<XCTActivity> activity) {
                    NSData* actual = [self renderDocument:[self documentWithRadius:radius.doubleValue
                                                                        colorSpace:space explicitRegion:NO transparentBlend:NO] size:320 flipped:flipped.boolValue];
                    NSData* expected = [self renderDocument:[self documentWithRadius:radius.doubleValue
                                                                          colorSpace:space explicitRegion:YES transparentBlend:NO] size:320 flipped:flipped.boolValue];
                    XCTAssertLessThanOrEqual([self maximumDifference:actual other:expected], 2);
                    XCTAssertTrue([self containsPaintedPixels:actual]);
                }];
            }
        }
    }
}

- (void)testTransparentBlendAndConcurrentRenders
{
    NSData* reference = [self renderDocument:[self documentWithRadius:2 colorSpace:@"sRGB"
                                                       explicitRegion:YES transparentBlend:YES] size:320 flipped:NO];
    [self runWorkers:12 freshThreads:NO block:^(NSUInteger index) {
        NSData* pixels = [self renderDocument:[self documentWithRadius:2 colorSpace:@"sRGB"
                                                        explicitRegion:NO transparentBlend:YES] size:320 flipped:NO];
        XCTAssertLessThanOrEqual([self maximumDifference:pixels other:reference], 2);
    }];
}

- (NSString*)batchDocumentWithColorSpace:(NSString*)colorSpace explicitRegion:(BOOL)explicitRegion
{
    NSMutableString* definitions = [[NSMutableString alloc] init];
    NSMutableString* artwork = [[NSMutableString alloc] init];
    const double radii[] = {0.2, 0.5, 1.3, 2.0, 2.67857143, 4.0};
    for(NSUInteger index = 0; index < 6; index++) {
        NSUInteger width = 39 + index * 7, height = 61 - index * 5;
        NSString* region = [NSString stringWithFormat:@"x='.175' y='.31' width='%lu.2' height='%lu.5'",
            (unsigned long)width, (unsigned long)height];
        [definitions appendFormat:
            @"<filter id='f%lu' filterUnits='userSpaceOnUse' %@ color-interpolation-filters='%@'>"
            "<feGaussianBlur stdDeviation='%.9g' %@/></filter>",
            (unsigned long)index, region, colorSpace, radii[index], explicitRegion ? region : @""];
        [artwork appendFormat:
            @"<g transform='translate(%lu,%lu)' opacity='.73'><g filter='url(#f%lu)'>"
            "<rect width='%lu' height='%lu' fill='#f02080' opacity='.4'/>"
            "<circle cx='29' cy='21' r='27' fill='#30c0e0' opacity='.7'/></g></g>",
            (unsigned long)(index * 37), (unsigned long)(index * 29), (unsigned long)index,
            (unsigned long)width, (unsigned long)height];
    }
    return [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='320' height='320'><defs>%@</defs>%@</svg>",
        definitions, artwork];
}

- (void)testBatchedSmallBlursMatchCoreImage
{
    for(NSString* space in @[@"sRGB", @"linearRGB"]) {
        for(NSNumber* flipped in @[@NO, @YES]) {
            NSString* name = [NSString stringWithFormat:@"space=%@ flipped=%@", space, flipped];
            [XCTContext runActivityNamed:name block:^(id<XCTActivity> activity) {
                NSData* actual = [self renderDocument:[self batchDocumentWithColorSpace:space explicitRegion:NO]
                                                 size:320 flipped:flipped.boolValue];
                NSData* expected = [self renderDocument:[self batchDocumentWithColorSpace:space explicitRegion:YES]
                                                   size:320 flipped:flipped.boolValue];
                XCTAssertLessThanOrEqual([self maximumDifference:actual other:expected], 2);
                XCTAssertTrue([self containsPaintedPixels:actual]);
            }];
        }
    }
}

- (void)testConcurrentBatchesKeepIndependentPixels
{
    NSData* expected = [self renderDocument:[self batchDocumentWithColorSpace:@"linearRGB" explicitRegion:YES]
                                       size:320 flipped:NO];
    [self runWorkers:12 freshThreads:NO block:^(NSUInteger index) {
        NSData* actual = [self renderDocument:[self batchDocumentWithColorSpace:@"linearRGB" explicitRegion:NO]
                                         size:320 flipped:NO];
        XCTAssertLessThanOrEqual([self maximumDifference:actual other:expected], 2);
    }];
}

- (NSString*)largeBatchDocumentWithCount:(NSUInteger)count width:(NSUInteger)width
                                 serial:(BOOL)serial ciOnly:(BOOL)ciOnly
{
    NSMutableString* definitions = [NSMutableString stringWithString:
        @"<clipPath id='canvas'><rect width='900' height='900'/></clipPath>"];
    NSMutableString* artwork = [[NSMutableString alloc] init];
    for(NSUInteger index = 0; index < count; index++) {
        NSUInteger radius = ciOnly || index % 2 == 0 ? 13 : 2;
        [definitions appendFormat:
            @"<filter id='large%lu' filterUnits='userSpaceOnUse' "
            "x='.175' y='.31' width='%lu.2' height='400.5' color-interpolation-filters='linearRGB'>"
            "<feGaussianBlur stdDeviation='%lu'/></filter>",
            (unsigned long)index, (unsigned long)width, (unsigned long)radius];
        [artwork appendFormat:
            @"<g transform='translate(%lu,%lu)' opacity='.63'><g filter='url(#large%lu)'>"
            "<rect width='%lu' height='400' fill='#e05020' opacity='.27'/>"
            "<circle cx='300' cy='230' r='147' fill='#2090f0' opacity='.51'/></g></g>",
            (unsigned long)(index * 11), (unsigned long)(index * 17), (unsigned long)index,
            (unsigned long)width];
    }
    // A canvas sized clip selects the independent renderer without changing pixels.
    return [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='900' height='900'><defs>%@</defs><g %@>%@</g></svg>",
        definitions, serial ? @"clip-path='url(#canvas)'" : @"", artwork];
}

- (void)testLargeChunksAndBudgetFallbackMatchIndependentRendering
{
    // Six jobs exceed one chunk; twenty exercise the larger replay budget;
    // forty exceed it and must fall back before drawing sources.
    for(NSNumber* count in @[@6, @20, @40]) {
        for(NSNumber* flipped in @[@NO, @YES]) {
            NSString* name = [NSString stringWithFormat:@"count=%@ flipped=%@", count, flipped];
            [XCTContext runActivityNamed:name block:^(id<XCTActivity> activity) {
                NSData* actual = [self renderDocument:[self largeBatchDocumentWithCount:count.unsignedIntegerValue
                                                                                  width:600 serial:NO ciOnly:NO] size:900 flipped:flipped.boolValue];
                NSData* expected = [self renderDocument:[self largeBatchDocumentWithCount:count.unsignedIntegerValue
                                                                                    width:600 serial:YES ciOnly:NO] size:900 flipped:flipped.boolValue];
                XCTAssertLessThanOrEqual([self maximumDifference:actual other:expected], 2);
            }];
        }
    }
}

- (void)testAtlasPaddingSplitsWithoutChangingPixels
{
    // The source pixels fit in one chunk but the packed atlas exceeds one megapixel.
    NSData* actual = [self renderDocument:[self largeBatchDocumentWithCount:3 width:800 serial:NO ciOnly:YES]
                                     size:900 flipped:NO];
    NSData* expected = [self renderDocument:[self largeBatchDocumentWithCount:3 width:800 serial:YES ciOnly:YES]
                                       size:900 flipped:NO];
    XCTAssertLessThanOrEqual([self maximumDifference:actual other:expected], 2);
}

- (void)testUnsupportedRadiiKeepCoreImageOutput
{
    for(NSNumber* radius in @[@0.0, @0.1, @12.1, @24.0]) {
        [XCTContext runActivityNamed:[NSString stringWithFormat:@"radius=%@", radius] block:^(id<XCTActivity> activity) {
            NSData* actual = [self renderDocument:[self documentWithRadius:radius.doubleValue colorSpace:@"linearRGB"
                                                            explicitRegion:NO transparentBlend:NO] size:320 flipped:NO];
            NSData* expected = [self renderDocument:[self documentWithRadius:radius.doubleValue colorSpace:@"linearRGB"
                                                              explicitRegion:YES transparentBlend:NO] size:320 flipped:NO];
            XCTAssertNotNil(actual);
            XCTAssertNotNil(expected);
            XCTAssertEqualObjects(actual, expected);
        }];
    }
}

@end
