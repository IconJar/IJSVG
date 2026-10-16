//
//  PackageTests.m
//  IJSVG
//
//  Created by Curtis Hard on 07/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <CoreImage/CoreImage.h>
#import <IJSVG/IJSVGUmbrella.h>
#import <IJSVGTestSupport.h>
#import <Metal/Metal.h>
#import <XCTest/XCTest.h>

@interface IJSVGPackageTests : XCTestCase
@end

@implementation IJSVGPackageTests

- (void)testRendersSVG
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='16' "
                                                  @"height='16'><rect width='16' height='16' fill='red'/></svg>"];
    XCTAssertNotNil(svg);
    XCTAssertTrue(CGSizeEqualToSize(svg.size, CGSizeMake(16, 16)));
    CGImageRef cgImage = [svg newCGImageRefWithSize:CGSizeMake(32, 32) flipped:NO error:nil];
    XCTAssertTrue(cgImage != NULL);
    if (cgImage == NULL) {
        return;
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    XCTAssertTrue(CFEqual(CGImageGetColorSpace(cgImage), space));
    CGContextRef context = CGBitmapContextCreate(NULL, 32, 32, 8, 32 * 4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if (context == NULL) {
        CGImageRelease(cgImage);
        return;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, 32, 32), cgImage);
    const UInt8* pixel = (const UInt8*)CGBitmapContextGetData(context) + 16 * CGBitmapContextGetBytesPerRow(context) + 16 * 4;
    XCTAssertGreaterThan(pixel[0], 242);
    XCTAssertLessThan(pixel[1], 13);
    XCTAssertLessThan(pixel[2], 13);
    XCTAssertGreaterThan(pixel[3], 242);
    CGContextRelease(context);
    CGImageRelease(cgImage);
}

- (void)checkPackagedShader:(NSString*)name
{
    NSString* source = IJSVGPackageShaderSource(name);
    XCTAssertGreaterThan(source.length, 0u, @"%@", name);
    if (source.length == 0) {
        return;
    }
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device != nil) {
        NSError* error = nil;
        id<MTLLibrary> library = [device newLibraryWithSource:source options:nil error:&error];
        XCTAssertNil(error);
        XCTAssertGreaterThan(library.functionNames.count, 0u, @"%@", name);
    }
}

- (void)testLoadsPackagedBlurShader
{
    [self checkPackagedShader:@"IJSVGBlur"];
}

- (void)testLoadsPackagedInnerShadowShader
{
    [self checkPackagedShader:@"IJSVGInnerShadow"];
}

- (void)testLoadsPackagedSubtractShader
{
    [self checkPackagedCoreImageShader:@"IJSVGSubtract"];
}

- (void)testLoadsPackagedSeparableBlurShader
{
    [self checkPackagedCoreImageShader:@"IJSVGSeparableBlur"];
}

- (void)checkPackagedCoreImageShader:(NSString*)name
{
    NSString* source = IJSVGPackageShaderSource(name);
    XCTAssertGreaterThan(source.length, 0u);
    if (source.length == 0) {
        return;
    }
    if (MTLCreateSystemDefaultDevice() != nil) {
        NSError* error = nil;
        NSArray<CIKernel*>* kernels = [CIKernel kernelsWithMetalString:source error:&error];
        XCTAssertNil(error);
        XCTAssertGreaterThan(kernels.count, 0u);
    }
}

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

@end
