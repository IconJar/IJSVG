//
//  IJSVGGradientComponentTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradient.h>
#import <IJSVGTestHelpers.h>

@interface IJSVGGradientComponentTests : XCTestCase
@end

@implementation IJSVGGradientComponentTests

- (NSData*)pixelsForGradient:(CGGradientRef)gradient
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, 256, 8, 8, 1024, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if (context == NULL) {
        return nil;
    }
    CGContextDrawLinearGradient(context, gradient, CGPointZero, CGPointMake(256, 0), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:8192];
    CGContextRelease(context);
    return pixels;
}

- (void)testComponentsMatchColorArrayConstruction
{
    NSColor* gray = [NSColor colorWithGenericGamma22White:0.4 alpha:0.3];
    NSColor* p3 = [NSColor colorWithDisplayP3Red:0.9 green:0.2 blue:0.4 alpha:0.7];
    NSColor* rgb = [NSColor colorWithSRGBRed:0.1 green:0.8 blue:0.3 alpha:0.5];
    NSMutableArray<NSColor*>* many = [NSMutableArray array];
    for (NSUInteger index = 0; index < 12; index++) {
        [many addObject:index % 2 == 0 ? rgb : gray];
    }
    NSArray<NSArray<NSColor*>*>* cases = @[ @[ NSColor.redColor, NSColor.blueColor ], @[ gray, NSColor.whiteColor ], @[ p3, rgb ], @[ NSColor.clearColor, rgb, gray ], @[ rgb ], many ];
    for (NSArray<NSColor*>* colors in cases) {
        for (NSNumber* explicitLocations in @[ @NO, @YES ]) {
            IJSVGGradient* gradient = [[IJSVGGradient alloc] init];
            NSMutableArray* nativeColors = [NSMutableArray arrayWithCapacity:colors.count];
            for (NSColor* color in colors) {
                [nativeColors addObject:(__bridge id)color.CGColor];
            }
            gradient.colors = nativeColors;
            gradient.numberOfStops = colors.count;
            if (explicitLocations.boolValue) {
                CGFloat* locations = calloc(colors.count, sizeof(CGFloat));
                for (NSUInteger index = 0; index < colors.count; index++) {
                    locations[index] = colors.count > 1 ? (CGFloat)index / (colors.count - 1) : 0;
                }
                gradient.locations = locations;
            }
            NSMutableArray<id>* cgColors = [NSMutableArray array];
            for (NSColor* color in colors) {
                [cgColors addObject:(__bridge id)color.CGColor];
            }
            CGGradientRef reference = CGGradientCreateWithColors(IJSVGColor.defaultColorSpace, (__bridge CFArrayRef)cgColors, gradient.locations);
            CGGradientRef actual = gradient.CGGradient;
            if (colors.count == 1 && gradient.locations == NULL) {
                XCTAssertTrue(reference == NULL);
                XCTAssertTrue(actual == NULL);
            } else {
                XCTAssertTrue(reference != NULL);
                XCTAssertTrue(actual != NULL);
            }
            if (reference != NULL && actual != NULL) {
                XCTAssertEqualObjects([self pixelsForGradient:actual], [self pixelsForGradient:reference]);
            }
            if (reference != NULL) {
                CGGradientRelease(reference);
            }
        }
    }
}

@end
