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

@interface IJSVGResourceExportTests : XCTestCase
@end

@implementation IJSVGResourceExportTests

- (NSData*)pixelsForSVG:(IJSVG*)svg size:(NSUInteger)size
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, size, size, 8, size * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if (context == NULL) {
        return nil;
    }
    CGContextTranslateCTM(context, 0, size);
    CGContextScaleCTM(context, 1, -1);
    [svg drawInRect:CGRectMake(0, 0, size, size) context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:size * size * 4];
    CGContextRelease(context);
    return pixels;
}

- (void)assertRoundTrip:(NSString*)xml
{
    for (NSNumber* dimension in @[ @32, @256, @900 ]) {
        @autoreleasepool {
            NSUInteger size = dimension.unsignedIntegerValue;
            IJSVG* source = [[IJSVG alloc] initWithSVGString:xml];
            XCTAssertNotNil(source);
            if (source == nil) {
                continue;
            }
            NSData* before = [self pixelsForSVG:source size:size];
            NSString* exported = [source SVGStringWithSize:CGSizeMake(size, size) options:IJSVGExporterOptionNone];
            XCTAssertNotNil(exported);
            IJSVG* reloaded = [[IJSVG alloc] initWithSVGString:exported];
            XCTAssertNotNil(reloaded);
            if (reloaded == nil) {
                continue;
            }
            XCTAssertEqualObjects([self pixelsForSVG:reloaded size:size], before, @"Export changed pixels at %@px", dimension);
        }
    }
}

- (void)testPositionedImageSurvivesExport
{
    NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:2 pixelsHigh:2 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:8 bitsPerPixel:32];
    XCTAssertNotNil(bitmap);
    if (bitmap == nil) {
        return;
    }
    for (NSUInteger y = 0; y < 2; y++) {
        for (NSUInteger x = 0; x < 2; x++) {
            [bitmap setColor:x == y ? NSColor.redColor : NSColor.blueColor atX:x y:y];
        }
    }
    NSData* png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
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
    CGFloat coordinates[] = { 655.66998, -825.24652, 0.00012345 };
    IJSVGExporterPathInstructionRoundData(coordinates, 3, IJSVGFloatingPointOptionsMake(NO, 2));
    XCTAssertEqual(coordinates[0], 655.66998);
    XCTAssertEqual(coordinates[1], -825.24652);
    XCTAssertEqual(coordinates[2], 0.00012345);
}

- (void)testLinesAfterClosePreserveClipGeometry
{
    [self assertRoundTrip:@"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 60 "
                          @"30'><clipPath id='t'>"
                           "<path d='M30 "
                           "15h30v15zv15h-30zh-30v-15zv-15h30z'/></clipPath><path d='M0 "
                           "0L60 30M60 0L0 30' clip-path='url(#t)' stroke='red' "
                           "stroke-width='4'/></svg>"];
}

- (void)testBytePathSerializationMatchesStringFormatter
{
    const char commands[] = "MmLlHhVvCcSsQqTtAaZz";
    const NSUInteger counts[] = { 2, 2, 2, 2, 1, 1, 1, 1, 6, 6, 4, 4, 4, 4, 2, 2, 7, 7, 0, 0 };
    for (NSNumber* round in @[ @NO, @YES ]) {
        IJSVGFloatingPointOptions options = IJSVGFloatingPointOptionsMake(round.boolValue, 3);
        NSMutableArray* instructions = [[NSMutableArray alloc] init];
        NSMutableArray* referenceCommands = [[NSMutableArray alloc] init];
        for (NSUInteger index = 0; index < 2048; index++) {
            NSUInteger type = (index / 3) % (sizeof(commands) - 1);
            IJSVGExporterPathInstruction* instruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:commands[type] dataCount:counts[type]];
            IJSVGExporterPathInstructionCommand* reference = [[IJSVGExporterPathInstructionCommand alloc] init];
            reference.instruction = commands[type];
            NSMutableArray* parameters = [[NSMutableArray alloc] init];
            for (NSUInteger coordinate = 0; coordinate < counts[type]; coordinate++) {
                CGFloat value = (CGFloat)((NSInteger)((index * 31 + coordinate * 19) % 10000) - 5000) / 1000.;

                // Exercise the integer fast path, its exponent boundaries and
                // values that become integral only after rounding.
                const CGFloat boundaries[] = { -0., 0., 1., -1., 999999., -999999., 1000000., -1000000., 999999.9999, -999999.9999, 12345., -54321. };
                if (index % 2 == 0) {
                    value = boundaries[(index / 2 + coordinate) % (sizeof(boundaries) / sizeof(*boundaries))];
                }
                instruction.data[coordinate] = value;
                [parameters addObject:IJSVGShortFloatStringWithOptions(value, options)];
            }
            reference.params = parameters;
            [instructions addObject:instruction];
            [referenceCommands addObject:reference];
        }
        NSString* expected = [IJSVGExporterPathInstruction pathStringWithInstructionSet:referenceCommands floatingPointOptions:options];
        XCTAssertEqualObjects([IJSVGExporterPathInstruction pathStringFromInstructions:instructions floatingPointOptions:options], expected);
        XCTAssertEqualObjects([IJSVGExporterPathInstruction pathStringFromInstructions:@[] floatingPointOptions:options], @"");
    }
}

- (void)testCachedPathCleanupMatchesSeparatePasses
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, -0., 0.);
    for (NSUInteger index = 0; index < 300; index++) {
        CGFloat x = (index % 31) * .173;
        CGFloat y = (index % 17) * -.219;
        CGPathAddLineToPoint(path, NULL, x, y);
        CGPathAddCurveToPoint(path, NULL, x + .5, y - .25, x + 1., y, x, y);
        if (index % 13 == 0) {
            CGPathCloseSubpath(path);
            CGPathMoveToPoint(path, NULL, x, y);
        }
    }
    for (NSNumber* round in @[ @NO, @YES ]) {
        IJSVGFloatingPointOptions options = IJSVGFloatingPointOptionsMake(round.boolValue, 3);
        NSArray* expected = [IJSVGExporterPathInstruction instructionsFromPath:path floatingPointOptions:options];
        [IJSVGExporterPathInstruction convertInstructionsDataToRoundedAndRecalculateCoordinates:expected floatingPointOptions:options];
        [IJSVGExporterPathInstruction convertInstructionsToMixedAbsoluteRelative:expected floatingPointOptions:options];
        expected = [IJSVGExporterPathInstruction convertInstructionsCurves:expected floatingPointOptions:options];
        NSString* expectedString = [IJSVGExporterPathInstruction pathStringFromInstructions:expected floatingPointOptions:options];
        NSArray* actual = [IJSVGExporterPathInstruction instructionsFromPath:path floatingPointOptions:options];
        XCTAssertEqualObjects([IJSVGExporterPathInstruction pathStringFromInstructions:actual floatingPointOptions:options cleanup:YES], expectedString);
    }
    CGPathRelease(path);
    IJSVGExporterPathInstruction* mutable = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'M' dataCount:2];
    mutable.data[0] = -0.;
    XCTAssertEqualObjects([IJSVGExporterPathInstruction pathStringFromInstructions:@[ mutable ] floatingPointOptions:IJSVGFloatingPointOptionsDefault()], @"M-0 0");
    mutable.data[0] = .5;
    XCTAssertEqualObjects([IJSVGExporterPathInstruction pathStringFromInstructions:@[ mutable ] floatingPointOptions:IJSVGFloatingPointOptionsDefault()], @"M.5 0");
}

@end
