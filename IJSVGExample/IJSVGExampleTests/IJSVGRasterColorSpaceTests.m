//
//  IJSVGRasterColorSpaceTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 14/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGError.h>
#import <ImageIO/ImageIO.h>
#import <XCTest/XCTest.h>

@interface IJSVGRasterColorSpaceTests : XCTestCase
@end

@implementation IJSVGRasterColorSpaceTests

- (IJSVG*)fixtureWithScale:(CGFloat)scale
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='8' height='8'>"
                                                   "<rect width='8' height='4' fill='#804020'/>"
                                                   "<rect y='4' width='8' height='4' fill='#2060c0'/></svg>"];
    XCTAssertNotNil(svg);
    svg.renderingBackingScaleHelper = ^CGFloat {
        return scale;
    };
    return svg;
}

- (NSData*)pixels:(CGImageRef)image
{
    return CFBridgingRelease(CGDataProviderCopyData(CGImageGetDataProvider(image)));
}

- (void)testExplicitRGBSpacesAndPixels
{
    for (NSString* name in @[ (__bridge NSString*)kCGColorSpaceSRGB, (__bridge NSString*)kCGColorSpaceDisplayP3 ]) {
        CGColorSpaceRef space = CGColorSpaceCreateWithName((__bridge CFStringRef)name);
        IJSVG* svg = [self fixtureWithScale:1];
        NSError* error = nil;
        CGImageRef image = [svg newCGImageRefWithSize:CGSizeMake(8, 8) flipped:YES colorSpace:space error:&error];
        XCTAssertNil(error);
        XCTAssertTrue(image != NULL);
        if (image == NULL) {
            CGColorSpaceRelease(space);
            continue;
        }
        XCTAssertTrue(CFEqual(CGImageGetColorSpace(image), space));

        // Compare direct drawing in the requested space, rather than relabeling pixels.
        CGContextRef context = CGBitmapContextCreate(NULL, 8, 8, 8, CGImageGetBytesPerRow(image), space, CGImageGetBitmapInfo(image));
        XCTAssertTrue(context != NULL);
        if (context != NULL) {
            CGContextTranslateCTM(context, 0, 8);
            CGContextScaleCTM(context, 1, -1);
            [svg drawInRect:CGRectMake(0, 0, 8, 8) context:context];
            CGImageRef expected = CGBitmapContextCreateImage(context);
            XCTAssertTrue(expected != NULL);
            if (expected != NULL) {
                XCTAssertEqualObjects([self pixels:image], [self pixels:expected]);
                CGImageRelease(expected);
            }
            CGContextRelease(context);
        }

        // The retained image must remain usable after the caller releases its space.
        CGColorSpaceRelease(space);
        CGColorRef source = CGColorCreateSRGB(128.0 / 255, 64.0 / 255, 32.0 / 255, 1);
        CGColorRef converted = CGColorCreateCopyByMatchingToColorSpace(CGImageGetColorSpace(image), kCGRenderingIntentDefault, source, NULL);
        XCTAssertTrue(converted != NULL);
        if (converted != NULL) {
            const CGFloat* components = CGColorGetComponents(converted);
            NSData* pixels = [self pixels:image];

            // The existing native pixel format stores 0xAARRGGBB words.
            uint32_t pixel = 0;
            memcpy(&pixel, (const UInt8*)pixels.bytes + 2 * CGImageGetBytesPerRow(image) + 2 * 4, sizeof(pixel));
            XCTAssertEqualWithAccuracy((pixel >> 16) & 255, components[0] * 255, 2);
            XCTAssertEqualWithAccuracy((pixel >> 8) & 255, components[1] * 255, 2);
            XCTAssertEqualWithAccuracy(pixel & 255, components[2] * 255, 2);
            XCTAssertEqual(pixel >> 24, 255u);
            CGColorRelease(converted);
        }
        CGColorRelease(source);
        CGImageRelease(image);
    }
}

- (void)testFlippingAndBackingScale
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    for (NSNumber* scale in @[ @1, @1.5, @2 ]) {
        IJSVG* svg = [self fixtureWithScale:scale.doubleValue];
        NSError* error = nil;
        CGImageRef normal = [svg newCGImageRefWithSize:CGSizeMake(8, 8) flipped:NO colorSpace:space error:&error];
        XCTAssertNil(error);
        CGImageRef flipped = [svg newCGImageRefWithSize:CGSizeMake(8, 8) flipped:YES colorSpace:space error:&error];
        XCTAssertNil(error);
        XCTAssertTrue(normal != NULL && flipped != NULL);
        if (normal != NULL && flipped != NULL) {
            XCTAssertEqual(CGImageGetWidth(normal), (size_t)(8 * scale.doubleValue));
            XCTAssertEqual(CGImageGetHeight(normal), (size_t)(8 * scale.doubleValue));
            XCTAssertEqual(CGImageGetWidth(flipped), CGImageGetWidth(normal));
            XCTAssertEqual(CGImageGetHeight(flipped), CGImageGetHeight(normal));
            NSData* a = [self pixels:normal];
            NSData* b = [self pixels:flipped];
            XCTAssertNotEqualObjects(a, b);
            for (size_t y = 0; y < CGImageGetHeight(normal); y++) {
                const UInt8* rowA = (const UInt8*)a.bytes + y * CGImageGetBytesPerRow(normal);
                const UInt8* rowB = (const UInt8*)b.bytes + (CGImageGetHeight(normal) - y - 1) * CGImageGetBytesPerRow(flipped);
                XCTAssertEqual(memcmp(rowA, rowB, CGImageGetWidth(normal) * 4), 0);
            }
            uint32_t top = 0;
            memcpy(&top, (const UInt8*)b.bytes + 2 * CGImageGetBytesPerRow(flipped) + 2 * 4, sizeof(top));
            XCTAssertEqualWithAccuracy((top >> 16) & 255, 128, 1);
        }
        if (normal != NULL) {
            CGImageRelease(normal);
        }
        if (flipped != NULL) {
            CGImageRelease(flipped);
        }
    }
    CGColorSpaceRelease(space);
}

- (void)testSRGBPNGEncodingPreservesProfileAndPixels
{
    IJSVG* svg = [self fixtureWithScale:1];
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef image = [svg newCGImageRefWithSize:CGSizeMake(8, 8) flipped:YES colorSpace:space error:nil];
    CGColorSpaceRelease(space);
    XCTAssertTrue(image != NULL);
    if (image == NULL) {
        return;
    }
    NSMutableData* data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.png"), 1, NULL);
    XCTAssertTrue(destination != NULL);
    if (destination != NULL) {
        CGImageDestinationAddImage(destination, image, NULL);
        XCTAssertTrue(CGImageDestinationFinalize(destination));
        CFRelease(destination);
        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        XCTAssertTrue(source != NULL);
        if (source != NULL) {
            CGImageRef decoded = CGImageSourceCreateImageAtIndex(source, 0, NULL);
            XCTAssertTrue(decoded != NULL);
            if (decoded != NULL) {
                XCTAssertTrue(CFEqual(CGImageGetColorSpace(decoded), CGImageGetColorSpace(image)));
                CGContextRef context = CGBitmapContextCreate(NULL, 8, 8, 8, CGImageGetBytesPerRow(image), CGImageGetColorSpace(image), CGImageGetBitmapInfo(image));
                XCTAssertTrue(context != NULL);
                if (context != NULL) {
                    CGContextDrawImage(context, CGRectMake(0, 0, 8, 8), decoded);
                    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:8 * CGBitmapContextGetBytesPerRow(context)];
                    XCTAssertEqualObjects(pixels, [self pixels:image]);
                    CGContextRelease(context);
                }
                CGImageRelease(decoded);
            }
            CFRelease(source);
        }
    }
    CGImageRelease(image);
}

- (void)testDefaultUsesSRGB
{
    IJSVG* svg = [self fixtureWithScale:2];
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    NSError* error = nil;
    CGImageRef legacy = [svg newCGImageRefWithSize:CGSizeMake(8, 8) flipped:YES error:&error];
    XCTAssertNil(error);
    CGImageRef explicit = [svg newCGImageRefWithSize:CGSizeMake(8, 8) flipped:YES colorSpace:space error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(legacy != NULL && explicit != NULL);
    if (legacy != NULL && explicit != NULL) {
        XCTAssertTrue(CFEqual(CGImageGetColorSpace(legacy), space));
        XCTAssertEqualObjects([self pixels:legacy], [self pixels:explicit]);
    }
    if (legacy != NULL) {
        CGImageRelease(legacy);
    }
    if (explicit != NULL) {
        CGImageRelease(explicit);
    }
    CGColorSpaceRelease(space);
}

- (void)testUnsupportedSpacesAndInvalidDimensionsReportDrawingErrors
{
    IJSVG* svg = [self fixtureWithScale:1];
    CGColorSpaceRef spaces[] = { CGColorSpaceCreateDeviceGray(), CGColorSpaceCreateDeviceCMYK(), CGColorSpaceCreatePattern(NULL) };
    for (NSUInteger index = 0; index < 3; index++) {
        NSError* error = nil;
        CGImageRef image = [svg newCGImageRefWithSize:CGSizeMake(8, 8) flipped:NO colorSpace:spaces[index] error:&error];
        XCTAssertTrue(image == NULL);
        XCTAssertEqualObjects(error.domain, IJSVGErrorDomain);
        XCTAssertEqual(error.code, IJSVGErrorDrawing);
        if (image != NULL) {
            CGImageRelease(image);
        }

        // NSError is optional.
        image = [svg newCGImageRefWithSize:CGSizeMake(8, 8) flipped:NO colorSpace:spaces[index] error:nil];
        XCTAssertTrue(image == NULL);
        if (image != NULL) {
            CGImageRelease(image);
        }
        CGColorSpaceRelease(spaces[index]);
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    for (NSNumber* width in @[ @0, @(-1), @(NAN), @(INFINITY), @(DBL_MAX) ]) {
        NSError* error = nil;
        CGImageRef image = [svg newCGImageRefWithSize:CGSizeMake(width.doubleValue, 8) flipped:NO colorSpace:space error:&error];
        XCTAssertTrue(image == NULL);
        XCTAssertEqualObjects(error.domain, IJSVGErrorDomain);
        XCTAssertEqual(error.code, IJSVGErrorDrawing);
        if (image != NULL) {
            CGImageRelease(image);
        }
    }
    NSError* error = nil;
    XCTAssertNil([svg imageWithSize:CGSizeZero flipped:NO error:&error]);
    XCTAssertEqualObjects(error.domain, IJSVGErrorDomain);
    XCTAssertEqual(error.code, IJSVGErrorDrawing);
    CGColorSpaceRelease(space);
}

@end
