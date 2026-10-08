//
//  IJSVGResourceExportTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGExporterPathInstruction.h>
#import <XCTest/XCTest.h>

@interface IJSVGResourceExportTests: XCTestCase
@end

@implementation IJSVGResourceExportTests

- (NSData*)pixelsForSVG:(IJSVG*)svg
                   size:(NSUInteger)size
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, size, size, 8, size * 4,
                                                 space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) return nil;
    CGContextTranslateCTM(context, 0, size);
    CGContextScaleCTM(context, 1, -1);
    [svg drawInRect:CGRectMake(0, 0, size, size)
            context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context)
                                    length:size * size * 4];
    CGContextRelease(context);
    return pixels;
}

- (void)assertRoundTrip:(NSString*)xml
{
    for(NSNumber* dimension in @[@32, @256, @900]) {
        @autoreleasepool {
            NSUInteger size = dimension.unsignedIntegerValue;
            IJSVG* source = [[IJSVG alloc] initWithSVGString:xml];
            XCTAssertNotNil(source);
            if(source == nil) continue;
            NSData* before = [self pixelsForSVG:source
                                           size:size];
            NSString* exported = [source SVGStringWithSize:CGSizeMake(size,
                                                                      size)
                                                   options:IJSVGExporterOptionNone];
            XCTAssertNotNil(exported);
            IJSVG* reloaded = [[IJSVG alloc] initWithSVGString:exported];
            XCTAssertNotNil(reloaded);
            if(reloaded == nil) continue;
            XCTAssertEqualObjects([self pixelsForSVG:reloaded
                                                size:size],
                                  before, @"Export changed pixels at %@px",
                                  dimension);
        }
    }
}

- (void)testPositionedImageSurvivesExport
{
    NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:2
                      pixelsHigh:2
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSDeviceRGBColorSpace
                     bytesPerRow:8
                    bitsPerPixel:32];
    XCTAssertNotNil(bitmap);
    if(bitmap == nil) return;
    for(NSUInteger y = 0; y < 2; y++) {
        for(NSUInteger x = 0; x < 2; x++) {
            [bitmap setColor:x == y ? NSColor.redColor : NSColor.blueColor
                         atX:x
                           y:y];
        }
    }
    NSData* png = [bitmap representationUsingType:NSBitmapImageFileTypePNG
                                       properties:@{}];
    XCTAssertNotNil(png);
    NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' "
                                                "xmlns:xlink='http://www.w3.org/1999/xlink' viewBox='0 0 "
                                                "32 32'><image x='4' y='-12' width='8' height='8' "
                                                "transform='scale(2 -2)' xlink:href='data:image/png;"
                                                "base64,%@'/></svg>",
                                               [png base64EncodedStringWithOptions:0]];
    [self assertRoundTrip:xml];
}

- (void)testPathCleanupRespectsDisabledRounding
{
    CGFloat coordinates[] = {655.66998, -825.24652, 0.00012345};
    IJSVGExporterPathInstructionRoundData(coordinates, 3,
                                          IJSVGFloatingPointOptionsMake(NO, 2));
    XCTAssertEqual(coordinates[0], 655.66998);
    XCTAssertEqual(coordinates[1], -825.24652);
    XCTAssertEqual(coordinates[2], 0.00012345);
}

- (void)testLinesAfterClosePreserveClipGeometry
{
    [self assertRoundTrip:@"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 60 30'><clipPath id='t'>"
                           "<path d='M30 15h30v15zv15h-30zh-30v-15zv-15h30z'/></clipPath><path d='M0 "
                           "0L60 30M60 0L0 30' clip-path='url(#t)' stroke='red' stroke-width='4'/></svg>"];
}

@end
