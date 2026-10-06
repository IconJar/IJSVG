#import <IJSVGFilterTestHelpers.h>
#import <QuartzCore/QuartzCore.h>

@interface IJSVGFilterBatchTests: XCTestCase
@end

@implementation IJSVGFilterBatchTests

- (void)assertBackdropRendersIntoPDF:(BOOL)alphaOnly
{
    NSString* matrix = alphaOnly
        ? @"0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0"
        : @"0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 1 0";
    NSString* document = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' "
                                                     "height='32' enable-background='new'><defs><filter "
                                                     "id='f' filterUnits='userSpaceOnUse' x='0' y='0' "
                                                     "width='32' height='32'><feColorMatrix in='%@' "
                                                     "values='%@'/></filter></defs><rect x='4' y='4' "
                                                     "width='8' height='8' fill='blue'/><rect x='20' "
                                                     "y='20' width='4' height='4' fill='red' "
                                                     "filter='url(#f)'/></svg>",
                                                    alphaOnly ? @"BackgroundAlpha" : @"BackgroundImage",
                                                    matrix];
    IJSVG* svg = IJSVGTestSVGObject(document);
    XCTAssertNotNil(svg);
    if(svg == nil) {
        return;
    }
    for(NSNumber* flipped in @[@NO, @YES]) {
        NSMutableData* data = [NSMutableData data];
        CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef)data);
        XCTAssertTrue(consumer != NULL);
        if(consumer == NULL) {
            return;
        }
        CGRect mediaBox = CGRectMake(0, 0, 96, 96);
        CGContextRef pdfContext = CGPDFContextCreate(consumer, &mediaBox, NULL);
        CGDataConsumerRelease(consumer);
        XCTAssertTrue(pdfContext != NULL);
        if(pdfContext == NULL) {
            return;
        }
        CGPDFContextBeginPage(pdfContext, NULL);
        if(flipped.boolValue) {
            CGContextTranslateCTM(pdfContext, 0, 96);
            CGContextScaleCTM(pdfContext, 1, -1);
        }
        [svg drawInRect:CGRectMake(12, 12, 64, 64)
                context:pdfContext];
        CGPDFContextEndPage(pdfContext);
        CGPDFContextClose(pdfContext);
        CGContextRelease(pdfContext);
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
        CGPDFDocumentRef pdf = provider == NULL ? NULL : CGPDFDocumentCreateWithProvider(provider);
        if(provider != NULL) {
            CGDataProviderRelease(provider);
        }
        XCTAssertTrue(pdf != NULL);
        if(pdf == NULL) {
            return;
        }
        CGContextRef bitmap = [self newBitmapWithSize:96
                                              flipped:NO];
        CGPDFPageRef page = CGPDFDocumentGetPage(pdf, 1);
        XCTAssertTrue(page != NULL);
        XCTAssertTrue(bitmap != NULL);
        if(bitmap != NULL && page != NULL) {
            CGContextDrawPDFPage(bitmap, page);
            const uint8_t* pixels = CGBitmapContextGetData(bitmap);
            // The earlier blue square must become red (alpha) or green (image).
            NSUInteger row = flipped.boolValue ? 28 : 95 - 28;
            const uint8_t* pixel = pixels + (row * 96 + 28) * 4;
            XCTAssertGreaterThan(pixel[alphaOnly ? 0 : 1], 250);
            XCTAssertLessThan(pixel[2], 5);
            XCTAssertGreaterThan(pixel[3], 250);
        }
        if(bitmap != NULL) {
            CGContextRelease(bitmap);
        }
        CGPDFDocumentRelease(pdf);
    }
}

- (void)testBackgroundImageRendersIntoPDFContext
{
    [self assertBackdropRendersIntoPDF:NO];
}

- (void)testBackgroundAlphaRendersIntoPDFContext
{
    [self assertBackdropRendersIntoPDF:YES];
}

- (void)testFiltersRenderIntoPDFContext
{
    for(NSNumber* origin in @[@0.0, @12.0]) {
        [XCTContext runActivityNamed:[NSString stringWithFormat:@"origin=%@",
                                                                origin]
                               block:^(id<XCTActivity> activity) {
            NSMutableString* shapes = [[NSMutableString alloc] init];
            for(NSUInteger index = 0; index < 4; index++) {
                [shapes appendFormat:@"<rect x='%lu' y='8' width='10' height='40' fill='red' "
                                      "filter='url(#f)'/>",
                                     (unsigned long)(4 + index * 12)];
            }
            NSString* document = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' "
                                                             "width='64' height='64'><defs><filter "
                                                             "id='f' color-interpolation-filters='sRGB'>"
                                                             "<feGaussianBlur stdDeviation='1'/></filter>"
                                                             "</defs>%@</svg>",
                                                            shapes];
            IJSVG* svg = IJSVGTestSVGObject(document);
            XCTAssertNotNil(svg);
            NSMutableData* data = [[NSMutableData alloc] init];
            CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef)data);
            XCTAssertTrue(consumer != NULL);
            if(consumer == NULL) return;
            CGRect mediaBox = CGRectMake(0, 0, 96, 96);
            CGContextRef pdfContext = CGPDFContextCreate(consumer, &mediaBox,
                                                         NULL);
            CGDataConsumerRelease(consumer);
            XCTAssertTrue(pdfContext != NULL);
            if(pdfContext == NULL) return;
            CGPDFContextBeginPage(pdfContext, NULL);
            CGContextTranslateCTM(pdfContext, origin.doubleValue,
                                  origin.doubleValue);
            CGContextClipToRect(pdfContext, CGRectMake(0, 0, 64, 64));
            [svg drawInRect:CGRectMake(0, 0, 64, 64)
                    context:pdfContext];
            CGPDFContextEndPage(pdfContext);
            CGPDFContextClose(pdfContext);
            CGContextRelease(pdfContext);

            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
            XCTAssertTrue(provider != NULL);
            if(provider == NULL) return;
            CGPDFDocumentRef pdf = CGPDFDocumentCreateWithProvider(provider);
            CGDataProviderRelease(provider);
            XCTAssertTrue(pdf != NULL);
            if(pdf == NULL) return;
            CGPDFPageRef page = CGPDFDocumentGetPage(pdf, 1);
            XCTAssertTrue(page != NULL);
            CGContextRef bitmap = [self newBitmapWithSize:96
                                                  flipped:NO];
            if(page != NULL && bitmap != NULL) {
                CGContextDrawPDFPage(bitmap, page);
                const uint8_t* pixels = CGBitmapContextGetData(bitmap);
                NSInteger row = 95 - (origin.integerValue + 28);
                NSInteger center = (row * 96 + origin.integerValue + 9) * 4;
                XCTAssertGreaterThan(pixels[center], 240, @"origin=%@", origin);
                XCTAssertGreaterThan(pixels[center + 3], 240, @"origin=%@",
                                     origin);
            }
            if(bitmap != NULL) CGContextRelease(bitmap);
            CGPDFDocumentRelease(pdf);
        }];
    }
}

- (NSString*)mixedArtworkDocument:(BOOL)forceGeneral
{
    NSMutableString* shapes = [[NSMutableString alloc] init];
    for(NSUInteger index = 0; index < 4; index++) {
        [shapes appendFormat:@"<g transform='translate(%lu, %lu)' opacity='.7'><rect x='2' y='2' "
                              "width='10' height='18' fill='#e09030'/><g filter='url(#f)'><rect x='4' "
                              "y='3' width='12' height='15' fill='url(#paint)'/><circle cx='12' cy='12' "
                              "r='7' fill='#2080d0' opacity='.6'/></g><path d='M 0 20 L 18 2 L 22 24 Z' "
                              "fill='#50b040' opacity='.3'/></g>",
                             (unsigned long)(index * 5),
                             (unsigned long)(index * 3)];
    }
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'>"
                                       "<defs><filter id='f' color-interpolation-filters='sRGB'>"
                                       "<feGaussianBlur stdDeviation='.6'/></filter><linearGradient "
                                       "id='paint'><stop stop-color='red'/><stop offset='1' "
                                       "stop-color='yellow'/></linearGradient><clipPath id='canvas'>"
                                       "<rect width='32' height='32'/></clipPath></defs><g %@><rect "
                                       "width='32' height='32' fill='#304050'/>%@<circle cx='25' cy='25' "
                                       "r='5' fill='white' opacity='.4'/></g></svg>",
                                      forceGeneral ? @"clip-path='url(#canvas)'" : @"",
                                      shapes];
}

- (void)testCollectionPreservesMixedArtwork
{
    for(NSNumber* flipped in @[@NO, @YES]) {
        [XCTContext runActivityNamed:[NSString stringWithFormat:@"flipped=%@",
                                                                flipped]
                               block:^(id<XCTActivity> activity) {
            NSData* actual = [self renderDocument:[self mixedArtworkDocument:NO]
                                          flipped:flipped.boolValue
                                          clipped:YES
                              generalTransparency:NO];
            NSData* expected = [self renderDocument:[self mixedArtworkDocument:YES]
                                            flipped:flipped.boolValue
                                            clipped:YES
                                generalTransparency:NO];
            XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                       other:expected],
                                     2);
        }];
    }
}

- (void)testGradientOpacityClipPreservesEdges
{
    for(NSNumber* angle in @[@0, @17]) {
        for(NSNumber* flipped in @[@NO, @YES]) {
            [XCTContext runActivityNamed:[NSString stringWithFormat:@"angle=%@ flipped=%@",
                                                                    angle,
                                                                    flipped]
                                   block:^(id<XCTActivity> activity) {
                NSString* document = [NSString stringWithFormat:@"<svg "
                                                                 "xmlns='http://www.w3.org/2000/svg' "
                                                                 "width='32' height='32'><defs>"
                                                                 "<linearGradient id='paint'><stop "
                                                                 "stop-color='#d02060' "
                                                                 "stop-opacity='.4'/><stop offset='1' "
                                                                 "stop-color='#30b080'/></linearGradient>"
                                                                 "</defs><rect width='32' height='32' "
                                                                 "fill='#304060'/><g "
                                                                 "transform='rotate(%@ 16 16)'><path "
                                                                 "d='M 2.35 5.7 L 26.4 3.2 L 29.1 24.8 L "
                                                                 "5.2 28.3 Z' fill='url(#paint)' "
                                                                 "opacity='.57'/></g></svg>",
                                                                angle];
                NSData* actual = [self renderDocument:document
                                              flipped:flipped.boolValue];
                NSData* expected = [self renderDocument:document
                                                flipped:flipped.boolValue
                                                clipped:NO
                                    generalTransparency:YES];
                XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                           other:expected],
                                         2);
            }];
        }
    }
}

- (void)testShapeOpacityClipPreservesPaint
{
    NSArray* styles = @[
        @"solid",
        @"round",
        @"square-dash",
        @"miter",
        @"gradient-stroke",
        @"both-gradients",
        @"curve-dash"
    ];
    NSDictionary* strokes = @{
        @"solid": @"",
        @"round": @"stroke='#d08020' stroke-width='3.7' stroke-linecap='round' stroke-linejoin='round'",
        @"square-dash": @"stroke='#d08020' stroke-width='3.7' stroke-linecap='square' "
                         "stroke-dasharray='1.3 2.7' stroke-dashoffset='.6'",
        @"miter": @"stroke='#d08020' stroke-width='2.1' stroke-linejoin='miter' stroke-miterlimit='12'",
        @"curve-dash": @"stroke='#d08020' stroke-width='4.3' stroke-linecap='square' "
                        "stroke-linejoin='bevel' stroke-dasharray='2 3 1'"
    };
    for(NSString* style in styles) {
        for(NSNumber* flipped in @[@NO, @YES]) {
            [XCTContext runActivityNamed:[NSString stringWithFormat:@"%@ flipped=%@",
                                                                    style,
                                                                    flipped]
                                   block:^(id<XCTActivity> activity) {
                NSString* stroke = strokes[style] ?: @"stroke='url(#paint)' stroke-width='3.7' "
                                                      "stroke-linecap='round' stroke-linejoin='miter'";
                NSString* fill = [style isEqualToString:@"both-gradients"] ? @"url(#paint)" : @"#30b080";
                NSString* path = [style isEqualToString:@"curve-dash"]
                    ? @"M 3.2 20.7 C 2.1 1.5 25.7 29.1 27.2 5.3"
                    : @"M 3.35 23.7 L 15.4 5.2 L 16.9 24.8 L 27.2 9.3";
                NSString* document = [NSString stringWithFormat:@"<svg "
                                                                 "xmlns='http://www.w3.org/2000/svg' "
                                                                 "width='32' height='32'><defs>"
                                                                 "<linearGradient id='paint'><stop "
                                                                 "stop-color='#d02060' "
                                                                 "stop-opacity='.4'/><stop offset='1' "
                                                                 "stop-color='#3080d0'/></linearGradient>"
                                                                 "</defs><rect width='32' height='32' "
                                                                 "fill='#304060'/><g opacity='.73' "
                                                                 "transform='rotate(17 16 16)'><g "
                                                                 "transform='translate(.3 .7) scale(.87 "
                                                                 "1.03)'><path d='%@' fill='%@' "
                                                                 "fill-opacity='.8' opacity='.57' %@/>"
                                                                 "</g></g></svg>",
                                                                path,
                                                                fill,
                                                                stroke];
                NSData* actual = [self renderDocument:document
                                              flipped:flipped.boolValue
                                              clipped:YES
                                  generalTransparency:NO];
                NSData* expected = [self renderDocument:document
                                                flipped:flipped.boolValue
                                                clipped:YES
                                    generalTransparency:YES];
                XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                           other:expected],
                                         2);
            }];
        }
    }
}

- (NSData*)translatedPixelsWithOffset:(double)offset
                              flipped:(BOOL)flipped
                            reference:(BOOL)reference
{
    CGContextRef context = [self newBitmapWithSize:64
                                           flipped:flipped];
    if(context == NULL) return nil;
    IJSVGShapePaint* container = [IJSVGShapePaint paint];
    container.frame = CGRectMake(0, 0, 64, 64);
    container.fillColor = NULL;
    container.strokeColor = NULL;
    container.opacity = 0.57;
    if(reference) {
        CGContextSetAlpha(context, container.opacity);
        CGContextBeginTransparencyLayer(context, NULL);
        container.opacity = 1;
    }
    for(NSUInteger index = 0; index < 2; index++) {
        IJSVGShapePaint* child = [IJSVGShapePaint paint];
        child.frame = CGRectMake(5.3, 3.7, 48, 48);
        CGPathRef path = CGPathCreateWithEllipseInRect(CGRectMake(10.2, 12.8,
                                                                  21.6, 15.4),
                                                       NULL);
        child.path = path;
        CGPathRelease(path);
        CGColorRef fill = CGColorCreateGenericRGB(0.8, 0.2, 0.3, 0.7);
        CGColorRef stroke = CGColorCreateGenericRGB(0.2, 0.7, 0.8, 0.6);
        child.fillColor = index == 0 ? fill : NULL;
        child.strokeColor = index == 1 ? stroke : NULL;
        CGColorRelease(fill);
        CGColorRelease(stroke);
        child.lineWidth = 3.3;
        child.lineCap = kCGLineCapSquare;
        child.lineJoin = kCGLineJoinRound;
        child.lineDashPattern = @[@2, @3];
        child.affineTransform = CGAffineTransformMakeTranslation(offset,
                                                                 -offset / 2);
        [container addChild:child];
    }
    [container renderInContext:context];
    if(reference) CGContextEndTransparencyLayer(context);
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context)
                                    length:64 * 64 * 4];
    CGContextRelease(context);
    return pixels;
}

- (void)testTranslatedPaintChildrenPreserveEdges
{
    for(NSNumber* offset in @[@-8.7, @0.0, @7.35]) {
        for(NSNumber* flipped in @[@NO, @YES]) {
            [XCTContext runActivityNamed:[NSString stringWithFormat:@"offset=%@ flipped=%@",
                                                                    offset,
                                                                    flipped]
                                   block:^(id<XCTActivity> activity) {
                NSData* actual = [self translatedPixelsWithOffset:offset.doubleValue
                                                          flipped:flipped.boolValue
                                                        reference:NO];
                NSData* expected = [self translatedPixelsWithOffset:offset.doubleValue
                                                            flipped:flipped.boolValue
                                                          reference:YES];
                XCTAssertTrue([self containsPaintedPixels:actual]);
                XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                           other:expected],
                                         1);
            }];
        }
    }
}

- (NSString*)saturatedEdgesDocumentWithAlpha:(NSNumber*)alpha
                              explicitRegion:(BOOL)explicitRegion
{
    NSString* region = explicitRegion ? @"x='.35' y='.7' width='30.2' height='29.6'" : @"";
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'>"
                                       "<defs><filter id='f' filterUnits='userSpaceOnUse' x='.35' y='.7' "
                                       "width='30.2' height='29.6' color-interpolation-filters='sRGB'>"
                                       "<feGaussianBlur stdDeviation='.6' "
                                       "color-interpolation-filters='linearRGB' %@/></filter></defs><g "
                                       "filter='url(#f)'><rect x='0' y='1' width='14' height='28' "
                                       "fill='red' opacity='%@'/><rect x='10' y='4' width='17' "
                                       "height='25' fill='lime' opacity='%@'/><circle cx='22' cy='16' "
                                       "r='9' fill='blue' opacity='%@'/><rect x='5' y='12' width='22' "
                                       "height='3' fill='white' opacity='%@'/><rect x='9' y='18' "
                                       "width='18' height='3' fill='#080808' opacity='%@'/></g></svg>",
                                      region,
                                      alpha,
                                      alpha,
                                      alpha,
                                      alpha,
                                      alpha];
}

- (void)testLinearBlurPreservesSaturatedEdges
{
    for(NSNumber* alpha in @[@0.02, @0.3, @1.0]) {
        for(NSNumber* flipped in @[@NO, @YES]) {
            [XCTContext runActivityNamed:[NSString stringWithFormat:@"alpha=%@ flipped=%@",
                                                                    alpha,
                                                                    flipped]
                                   block:^(id<XCTActivity> activity) {
                NSData* actual = [self renderDocument:[self saturatedEdgesDocumentWithAlpha:alpha
                                                                             explicitRegion:NO]
                                              flipped:flipped.boolValue];
                NSData* expected = [self renderDocument:[self saturatedEdgesDocumentWithAlpha:alpha
                                                                               explicitRegion:YES]
                                                flipped:flipped.boolValue];
                XCTAssertTrue([self containsPaintedPixels:actual]);
                XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                           other:expected],
                                         2);
            }];
        }
    }
}

- (NSString*)blurDocumentWithRadius:(NSNumber*)radius
                         colorSpace:(NSString*)colorSpace
                     explicitRegion:(BOOL)explicitRegion
{
    NSString* region = explicitRegion ? @"x='.35' y='.7' width='30.2' height='29.6'" : @"";
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'>"
                                       "<defs><filter id='f' filterUnits='userSpaceOnUse' x='.35' y='.7' "
                                       "width='30.2' height='29.6' color-interpolation-filters='%@'>"
                                       "<feGaussianBlur stdDeviation='%@' %@/></filter></defs><g "
                                       "filter='url(#f)'><rect x='0' y='1' width='20' height='28' "
                                       "fill='#804020' opacity='.6'/><circle cx='21' cy='18' r='10' "
                                       "fill='#2080c0' opacity='.4'/></g></svg>",
                                      colorSpace,
                                      radius,
                                      region];
}

- (void)testSmallBlurMatchesGeneralEvaluator
{
    for(NSNumber* radius in @[@0.0, @0.05, @0.1, @0.25, @0.5, @0.9, @1.3, @2.0]) {
        for(NSString* colorSpace in @[@"sRGB", @"linearRGB"]) {
            [XCTContext runActivityNamed:[NSString stringWithFormat:@"radius=%@ %@",
                                                                    radius,
                                                                    colorSpace]
                                   block:^(id<XCTActivity> activity) {
                // Explicit primitive bounds select the general evaluator with the same crop.
                NSData* actual = [self renderDocument:[self blurDocumentWithRadius:radius
                                                                        colorSpace:colorSpace
                                                                    explicitRegion:NO]
                                              flipped:NO];
                NSData* expected = [self renderDocument:[self blurDocumentWithRadius:radius
                                                                          colorSpace:colorSpace
                                                                      explicitRegion:YES]
                                                flipped:NO];
                XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                           other:expected],
                                         2);
            }];
        }
    }
}

- (NSString*)batchedDocumentWithIndices:(NSArray<NSNumber*>*)indices
{
    NSArray* effects = @[@"<feOffset dx='.4' dy='-.6'/>", @"<feGaussianBlur stdDeviation='.6 1.2'/>",
        @"<feColorMatrix type='saturate' values='.4'/>", @"<feGaussianBlur stdDeviation='.4'/>"];
    NSArray* colors = @[@"#a03080", @"#40b020", @"#3080c0", @"#d08020"];
    NSMutableString* definitions = [[NSMutableString alloc] init];
    NSMutableString* content = [[NSMutableString alloc] init];
    for(NSNumber* value in indices) {
        NSUInteger index = value.unsignedIntegerValue;
        [definitions appendFormat:@"<filter id='f%@' filterUnits='userSpaceOnUse' x='0' y='0' width='32' "
                                   "height='32' color-interpolation-filters='sRGB'>%@</filter>",
                                  value,
                                  effects[index]];
        [content appendFormat:@"<circle cx='%lu' cy='%lu' r='8' fill='%@' opacity='.6' "
                               "filter='url(#f%@)'/>",
                              (unsigned long)(10 + index * 4),
                              (unsigned long)(11 + index * 3),
                              colors[index],
                              value];
    }
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'>"
                                       "<defs>%@</defs>%@</svg>",
                                      definitions,
                                      content];
}

- (void)testBatchedFiltersMatchIndependentRenders
{
    for(NSNumber* flipped in @[@NO, @YES]) {
        for(NSNumber* count in @[@3, @4]) {
            [XCTContext runActivityNamed:[NSString stringWithFormat:@"count=%@ flipped=%@",
                                                                    count,
                                                                    flipped]
                                   block:^(id<XCTActivity> activity) {
                NSMutableArray* indices = [[NSMutableArray alloc] init];
                NSMutableArray* references = [[NSMutableArray alloc] init];
                for(NSUInteger index = 0; index < count.unsignedIntegerValue; index++) {
                    [indices addObject:@(index)];
                    [references addObject:[self batchedDocumentWithIndices:@[@(index)]]];
                }
                NSData* actual = [self renderDocument:[self batchedDocumentWithIndices:indices]
                                              flipped:flipped.boolValue
                                              clipped:YES
                                  generalTransparency:NO];
                NSData* expected = [self compositeDocuments:references
                                                    flipped:flipped.boolValue
                                                    clipped:YES];
                XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                           other:expected],
                                         2);
            }];
        }
    }
}

@end
