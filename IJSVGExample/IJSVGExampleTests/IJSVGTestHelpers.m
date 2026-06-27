//
//  IJSVGTestHelpers.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGTestHelpers.h"

IJSVGNode* IJSVGTestNode(NSString* name, NSString* identifier,
                         NSArray<NSString*>* classes)
{
    IJSVGNode* node = [[IJSVGNode alloc] init];
    node.name = name;
    node.identifier = identifier;
    node.classNameList = classes == nil ? nil : [NSSet setWithArray:classes];
    return node;
}

IJSVGGroup* IJSVGTestGroup(NSString* identifier, NSArray<NSString*>* classes)
{
    IJSVGGroup* group = [[IJSVGGroup alloc] init];
    group.name = @"g";
    group.identifier = identifier;
    group.classNameList = classes == nil ? nil : [NSSet setWithArray:classes];
    return group;
}

IJSVGStyleSheet* IJSVGTestStyleSheet(NSString* styleBlock)
{
    IJSVGStyleSheet* styleSheet = [[IJSVGStyleSheet alloc] init];
    [styleSheet parseStyleBlock:styleBlock];
    return styleSheet;
}

NSString* IJSVGTestSVG(NSString* body)
{
    return [NSString stringWithFormat:@"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\" viewBox=\"0 0 8 8\">%@</svg>", body];
}

IJSVG* IJSVGTestSVGObject(NSString* svgString)
{
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:svgString
                                           error:&error];
    XCTAssertNotNil(svg);
    XCTAssertNil(error);
    return svg;
}

NSXMLDocument* IJSVGTestXMLDocument(NSString* xmlString)
{
    NSError* error = nil;
    NSXMLDocument* document = [[NSXMLDocument alloc] initWithXMLString:xmlString
                                                               options:0
                                                                 error:&error];
    XCTAssertNotNil(document);
    XCTAssertNil(error);
    return document;
}

NSData* IJSVGTestRGBADataForSVG(NSString* svgString, CGSize size)
{
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:svgString
                                           error:&error];
    XCTAssertNotNil(svg);
    XCTAssertNil(error);

    svg.renderingBackingScaleHelper = ^CGFloat {
        return 1.f;
    };

    CGImageRef image = [svg newCGImageRefWithSize:size
                                          flipped:NO
                                            error:&error];
    XCTAssertNotNil((__bridge id)image);
    XCTAssertNil(error);

    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    size_t bytesPerRow = width * 4;
    NSMutableData* data = [NSMutableData dataWithLength:height * bytesPerRow];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Big | (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    CGContextRef context = CGBitmapContextCreate(data.mutableBytes, width,
                                                 height, 8, bytesPerRow,
                                                 colorSpace, bitmapInfo);
    CGContextDrawImage(context, CGRectMake(0.f, 0.f, width, height), image);

    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(image);
    return data;
}

NSColor* IJSVGTestColorFromRGBAData(NSData* data, CGSize size, CGPoint point)
{
    NSUInteger width = (NSUInteger)size.width;
    NSUInteger height = (NSUInteger)size.height;
    NSUInteger clampedX = MIN((NSUInteger)MAX(point.x, 0.f), width - 1);
    NSUInteger clampedY = MIN((NSUInteger)MAX(point.y, 0.f), height - 1);
    NSUInteger bitmapY = height - 1 - clampedY;
    const unsigned char* pixels = data.bytes;
    const unsigned char* pixel = pixels + ((bitmapY * width) + clampedX) * 4;
    return [NSColor colorWithCalibratedRed:pixel[0] / 255.f
                                     green:pixel[1] / 255.f
                                      blue:pixel[2] / 255.f
                                     alpha:pixel[3] / 255.f];
}

NSColor* IJSVGTestColorFromSVGAtPoint(NSString* svgString, CGPoint point)
{
    CGSize size = CGSizeMake(8.f, 8.f);
    NSData* data = IJSVGTestRGBADataForSVG(svgString, size);
    return IJSVGTestColorFromRGBAData(data, size, point);
}

void IJSVGAssertColorComponents(NSColor* color, CGFloat red, CGFloat green,
                                CGFloat blue, CGFloat alpha)
{
    NSColor* rgbColor = [color colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
    XCTAssertEqualWithAccuracy(rgbColor.redComponent, red, 0.02);
    XCTAssertEqualWithAccuracy(rgbColor.greenComponent, green, 0.02);
    XCTAssertEqualWithAccuracy(rgbColor.blueComponent, blue, 0.02);
    XCTAssertEqualWithAccuracy(rgbColor.alphaComponent, alpha, 0.02);
}

void IJSVGAssertRenderedSVGMatchesMap(NSString* svgString,
                                      NSArray<NSString*>* rows,
                                      NSDictionary<NSString*, NSColor*>* palette)
{
    CGSize size = CGSizeMake(rows.firstObject.length, rows.count);
    NSData* data = IJSVGTestRGBADataForSVG(svgString, size);

    for(NSUInteger y = 0; y < rows.count; y++) {
        NSString* row = rows[y];
        XCTAssertEqual(row.length, (NSUInteger)size.width);

        for(NSUInteger x = 0; x < row.length; x++) {
            NSString* key = [row substringWithRange:NSMakeRange(x, 1)];
            NSColor* expectedColor = palette[key];
            XCTAssertNotNil(expectedColor);

            NSColor* actualColor = IJSVGTestColorFromRGBAData(data, size, CGPointMake(x, y));
            NSColor* expectedRGBColor = [expectedColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
            IJSVGAssertColorComponents(actualColor,
                                       expectedRGBColor.redComponent,
                                       expectedRGBColor.greenComponent,
                                       expectedRGBColor.blueComponent,
                                       expectedRGBColor.alphaComponent);
        }
    }
}
