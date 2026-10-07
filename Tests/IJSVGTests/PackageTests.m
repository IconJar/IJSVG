#import <XCTest/XCTest.h>
#import <IJSVG/IJSVGUmbrella.h>
#import <IJSVGTestSupport.h>
#import <Metal/Metal.h>

@interface IJSVGPackageTests: XCTestCase
@end

@implementation IJSVGPackageTests

- (void)testRendersSVG
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><rect width='16' height='16' fill='red'/></svg>"];
    XCTAssertNotNil(svg);
    XCTAssertTrue(CGSizeEqualToSize(svg.size, CGSizeMake(16, 16)));
    NSImage* image = [svg imageWithSize:CGSizeMake(32, 32)];
    XCTAssertNotNil(image);
    XCTAssertTrue(CGSizeEqualToSize(image.size, CGSizeMake(32, 32)));
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    XCTAssertTrue(cgImage != NULL);
    if(cgImage == NULL) return;
    NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    NSColor* color = [[bitmap colorAtX:16 y:16] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
    XCTAssertNotNil(color);
    XCTAssertGreaterThan(color.redComponent, 0.95);
    XCTAssertLessThan(color.greenComponent, 0.05);
    XCTAssertLessThan(color.blueComponent, 0.05);
    XCTAssertGreaterThan(color.alphaComponent, 0.95);
}

- (void)checkPackagedShader:(NSString*)name
{
    NSString* source = IJSVGPackageShaderSource(name);
    XCTAssertGreaterThan(source.length, 0u, @"%@", name);
    if(source.length == 0) return;
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if(device != nil) {
        NSError* error = nil;
        id<MTLLibrary> library = [device newLibraryWithSource:source options:nil error:&error];
        XCTAssertNil(error);
        XCTAssertGreaterThan(library.functionNames.count, 0u, @"%@", name);
    }
}

- (void)testLoadsPackagedBlurShader { [self checkPackagedShader:@"IJSVGBlur"]; }
- (void)testLoadsPackagedInnerShadowShader { [self checkPackagedShader:@"IJSVGInnerShadow"]; }
- (void)testLoadsPackagedSubtractShader { [self checkPackagedShader:@"IJSVGSubtract"]; }
- (void)testLoadsPackagedSeparableBlurShader { [self checkPackagedShader:@"IJSVGSeparableBlur"]; }

- (void)testInitializersWithErrors
{
    NSString* source = @"<svg xmlns='http://www.w3.org/2000/svg' width='12' height='8'/>";
    NSError* error = nil;
    IJSVG* parsed = [[IJSVG alloc] initWithSVGString:source error:&error];
    XCTAssertNotNil(parsed);
    XCTAssertNil(error);
    NSData* data = [source dataUsingEncoding:NSUTF8StringEncoding];
    IJSVG* fromData = [[IJSVG alloc] initWithSVGData:data error:&error];
    XCTAssertNotNil(fromData);
    XCTAssertNil(error);
    XCTAssertTrue(CGSizeEqualToSize(parsed.size, fromData.size));
    NSURL* url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".svg"]]];
    XCTAssertTrue([data writeToURL:url options:0 error:&error]);
    XCTAssertNil(error);
    @try {
        IJSVG* fromURL = [[IJSVG alloc] initWithFilePathURL:url error:&error];
        XCTAssertNotNil(fromURL);
        XCTAssertNil(error);
        IJSVG* fromPath = [[IJSVG alloc] initWithFile:url.path error:&error];
        XCTAssertNotNil(fromPath);
        XCTAssertNil(error);
        XCTAssertTrue(CGSizeEqualToSize(fromURL.size, parsed.size));
        XCTAssertTrue(CGSizeEqualToSize(fromPath.size, parsed.size));
    } @finally {
        [NSFileManager.defaultManager removeItemAtURL:url error:NULL];
    }
}

- (void)testReportsParsingAndFileErrors
{
    NSError* error = nil;
    XCTAssertNil([[IJSVG alloc] initWithSVGString:@"not SVG" error:&error]);
    XCTAssertNotNil(error);
    error = nil;
    XCTAssertNil([[IJSVG alloc] initWithSVGData:NSData.data error:&error]);
    XCTAssertNotNil(error);
    error = nil;
    NSURL* missing = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".svg"]]];
    XCTAssertNil([[IJSVG alloc] initWithFilePathURL:missing error:&error]);
    XCTAssertNotNil(error);
    XCTAssertNil([[IJSVG alloc] initWithSVGString:@"not SVG"]);
}

- (void)testOptionalMetadataCanBeCleared
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg'/>"];
    XCTAssertNotNil(svg);
    XCTAssertNil(svg.title);
    XCTAssertNil(svg.desc);
    svg.title = @"Example";
    svg.title = nil;
    svg.desc = nil;
    svg.renderingBackingScaleHelper = nil;
    XCTAssertNil(svg.title);
    IJSVGExporter* exporter = [svg exporterWithSize:CGSizeMake(16, 16) options:0 floatingPointOptions:IJSVGFloatingPointOptionsDefault()];
    exporter.delegate = nil;
    XCTAssertNil(exporter.delegate);
}

- (void)testViewAcceptsAnEmptySVG
{
    void (^check)(void) = ^{
        IJSVGView* view = [[IJSVGView alloc] initWithSVG:nil];
        view.SVG = nil;
        XCTAssertNil(view.SVG);
    };
    if(NSThread.isMainThread) check();
    else dispatch_sync(dispatch_get_main_queue(), check);
}

@end
