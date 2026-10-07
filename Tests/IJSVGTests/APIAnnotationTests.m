#import <XCTest/XCTest.h>
#import <IJSVG/IJSVGUmbrella.h>
#import <IJSVGTestSupport.h>

static NSString* const IJSVGAnnotationTestSVG = @"<svg xmlns='http://www.w3.org/2000/svg' width='16' height='8'><rect width='16' height='8' fill='red'/></svg>";

@interface IJSVGAPIAnnotationTests: XCTestCase
@end

@implementation IJSVGAPIAnnotationTests

- (void)testRenderingEntryPoints
{
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:IJSVGAnnotationTestSVG error:&error];
    XCTAssertNotNil(svg);
    XCTAssertNil(error);
    svg.renderingBackingScaleHelper = ^CGFloat { return 1; };
    CGSize size = CGSizeMake(32, 16);
    XColor* image = [svg imageWithSize:size error:&error];
    XCTAssertNotNil(image);
    XCTAssertNil(error);
    XColor* flipped = [svg imageWithSize:size flipped:YES error:&error];
    XCTAssertNotNil(flipped);
    XCTAssertNil(error);
    XColor* fitted = [svg imageByMaintainingAspectRatioWithSize:size flipped:NO error:&error];
    XCTAssertNotNil(fitted);
    XCTAssertNil(error);
    XCTAssertTrue(CGSizeEqualToSize(image.size, size));
    XCTAssertTrue(CGSizeEqualToSize(flipped.size, size));
    XCTAssertTrue(CGSizeEqualToSize(fitted.size, size));
    CGImageRef cgImage = [svg newCGImageRefWithSize:size flipped:NO error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(cgImage != NULL);
    if(cgImage != NULL) {
        XCTAssertEqual(CGImageGetWidth(cgImage), 32u);
        XCTAssertEqual(CGImageGetHeight(cgImage), 16u);
        NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
        XColor* color = [[bitmap colorAtX:8 y:8] colorUsingColorSpace:XColorSpace.deviceRGBColorSpace];
        XCTAssertNotNil(color);
        XCTAssertGreaterThan(color.redComponent, 0.95);
        XCTAssertGreaterThan(color.alphaComponent, 0.95);
        CGImageRelease(cgImage);
    }
    CGRect rect = (CGRect){CGPointZero, size};
    NSData* pdf = [svg PDFData:&error];
    XCTAssertNil(error);
    NSData* rectPDF = [svg PDFDataWithRect:rect error:&error];
    XCTAssertNil(error);
    for(NSData* data in @[[svg PDFData], [svg PDFDataWithRect:rect], pdf, rectPDF]) {
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
        XCTAssertTrue(provider != NULL);
        if(provider == NULL) continue;
        CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
        XCTAssertTrue(document != NULL);
        if(document != NULL) {
            XCTAssertEqual(CGPDFDocumentGetNumberOfPages(document), 1u);
            CGPDFDocumentRelease(document);
        }
        CGDataProviderRelease(provider);
    }
}

- (void)testCoreGraphicsObjectOwnership
{
    CGPathRef source = CGPathCreateWithRect(CGRectMake(0, 0, 8, 4), NULL);
    CGPathRef flipped = [IJSVGUtils newFlippedCGPath:source];
    XCTAssertTrue(CGSizeEqualToSize(CGPathGetPathBoundingBox(flipped).size, CGPathGetPathBoundingBox(source).size));
    CGPathRelease(flipped);
    CGPathRelease(source);
    CGMutablePathRef path = [IJSVGCommand newPathForCommandsArray:[IJSVGCommand commandsForDataCharacters:"M0 0 L8 4"]];
    XCTAssertTrue(path != NULL);
    if(path == NULL) return;
    XCTAssertTrue(CGPointEqualToPoint(CGPathGetCurrentPoint(path), CGPointMake(8, 4)));
    XCTAssertEqual(CGColorSpaceGetNumberOfComponents(IJSVGDeviceRGBColorSpace()), 3u);
    XCTAssertEqual(CGColorSpaceGetNumberOfComponents(IJSVGDeviceGrayColorSpace()), 1u);

    // Objective-C callers explicitly retain borrowed Core Graphics objects.
    CGPathRef borrowedPath = NULL;
    @autoreleasepool {
        IJSVGPath* node = [[IJSVGPath alloc] init];
        node.path = path;
        borrowedPath = CGPathRetain(node.path);
    }
    CGPathRelease(path);
    XCTAssertTrue(CGPointEqualToPoint(CGPathGetCurrentPoint(borrowedPath), CGPointMake(8, 4)));
    CGPathRelease(borrowedPath);
    CGImageRef borrowedImage = NULL;
    @autoreleasepool {
        IJSVG* svg = [[IJSVG alloc] initWithSVGString:IJSVGAnnotationTestSVG];
        IJSVGImage* node = [[IJSVGImage alloc] init];
        node.image = [svg imageWithSize:CGSizeMake(16, 8)];
        borrowedImage = CGImageRetain([node CGImage]);
    }
    XCTAssertTrue(borrowedImage != NULL);
    if(borrowedImage != NULL) {
        XCTAssertGreaterThan(CGImageGetWidth(borrowedImage), 0u);
        CGImageRelease(borrowedImage);
    }
    CGGradientRef borrowedGradient = NULL;
    @autoreleasepool {
        IJSVGGradient* gradient = [[IJSVGGradient alloc] init];
        gradient.colors = @[XColor.redColor, XColor.blueColor];
        gradient.numberOfStops = 2;
        borrowedGradient = CGGradientRetain(gradient.CGGradient);
    }
    XCTAssertTrue(borrowedGradient != NULL);
    if(borrowedGradient != NULL) {
        XCTAssertEqual(CFGetTypeID(borrowedGradient), CGGradientGetTypeID());
        CGGradientRelease(borrowedGradient);
    }
}

- (void)testParserAcceptsOptionalBaseURL
{
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:IJSVGAnnotationTestSVG fileURL:nil error:&error];
    XCTAssertNotNil(parser);
    XCTAssertNil(error);
    XCTAssertEqual([parser rootNodeWithSize:CGSizeMake(16, 8)].children.count, 1u);
    XCTAssertNil([[IJSVGParser alloc] initWithSVGData:NSData.data fileURL:nil error:&error]);
    XCTAssertNotNil(error);
}

- (void)testNodeAndStyleNullabilityMatchesEmptyState
{
    IJSVGNode* node = [[IJSVGNode alloc] init];
    XCTAssertNil(node.parentNode);
    XCTAssertNil(node.rootNode);
    XCTAssertNil(node.fill);
    XCTAssertNil(node.stroke);
    XCTAssertNil(node.identifier);
    node.fill = nil;
    node.stroke = nil;
    node.mask = nil;
    node.filter = nil;
    IJSVGImage* image = [[IJSVGImage alloc] init];
    XCTAssertNil(image.image);
    XCTAssertNil(image.sourceData);
    IJSVGStyle* style = [[IJSVGStyle alloc] init];
    XCTAssertNil(style.fillColor);
    XCTAssertNil(style.strokeColor);
    style.fillColor = XColor.redColor;
    style.fillColor = nil;
    XCTAssertEqual(style.colors.count, 0u);
    XCTAssertEqual([[IJSVGFilter alloc] init].primitives.count, 0u);
    XCTAssertNil([[IJSVGFilterPrimitive alloc] init].parameters);
}

- (void)testColorLookupsReturnNil
{
    XCTAssertNil([IJSVGColor colorFromString:@"not-a-color"]);
    XCTAssertNil([IJSVGColor colorFromString:@"none"]);
    IJSVGTraitedColorStorage* storage = [[IJSVGTraitedColorStorage alloc] init];
    XCTAssertNil([storage colorForColor:XColor.redColor matchingTraits:IJSVGColorUsageTraitFill]);
    XCTAssertEqual(storage.colors.count, 0u);
}

- (void)testPDFReportsErrorAlongsideData
{
    IJSVG* svg = IJSVGWithPDFError();
    NSError* error = nil;
    XCTAssertNotNil([svg PDFData:&error]);
    XCTAssertNotNil(error);
    error = nil;
    XCTAssertNotNil([svg PDFDataWithRect:CGRectZero error:&error]);
    XCTAssertNotNil(error);
    XCTAssertEqual([svg PDFData].length, 0u);
}

@end
