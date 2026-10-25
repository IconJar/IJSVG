//
//  IJSVGGradientComponentTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradient.h>
#import <IJSVG/IJSVGGroup.h>
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

/// Inherited interpolation is cached between draws. Edits to an ancestor,
/// a new style parent and a freed style parent must all be observed.
- (void)testInheritedInterpolationFollowsLiveEdits
{
    IJSVGGradient* gradient = [[IJSVGGradient alloc] init];
    gradient.colors = @[ (__bridge id)NSColor.redColor.CGColor, (__bridge id)NSColor.blueColor.CGColor ];
    gradient.numberOfStops = 2;
    IJSVGGroup* outer = [[IJSVGGroup alloc] init];
    IJSVGGroup* inner = [[IJSVGGroup alloc] init];
    inner.styleParent = outer;
    gradient.styleParent = inner;
    NSData* srgb = [self pixelsForGradient:gradient.CGGradient];

    // Repeated draws reuse the cached result.
    XCTAssertEqualObjects([self pixelsForGradient:gradient.CGGradient], srgb);

    // An edit two levels up changes the resolved interpolation.
    outer.colorInterpolation = IJSVGColorInterpolationLinearRGB;
    NSData* linear = [self pixelsForGradient:gradient.CGGradient];
    XCTAssertNotEqualObjects(linear, srgb);
    outer.colorInterpolation = IJSVGColorInterpolationUnspecified;
    XCTAssertEqualObjects([self pixelsForGradient:gradient.CGGradient], srgb);

    // Replacing the style parent is observed.
    IJSVGGroup* linearParent = [[IJSVGGroup alloc] init];
    linearParent.colorInterpolation = IJSVGColorInterpolationLinearRGB;
    gradient.styleParent = linearParent;
    XCTAssertEqualObjects([self pixelsForGradient:gradient.CGGradient], linear);
    gradient.styleParent = inner;
    XCTAssertEqualObjects([self pixelsForGradient:gradient.CGGradient], srgb);

    // A freed style parent clears the weak link, which falls back to sRGB.
    @autoreleasepool {
        IJSVGGroup* transient = [[IJSVGGroup alloc] init];
        transient.colorInterpolation = IJSVGColorInterpolationLinearRGB;
        gradient.styleParent = transient;
        XCTAssertEqualObjects([self pixelsForGradient:gradient.CGGradient], linear);
    }
    XCTAssertNil(gradient.styleParent);
    XCTAssertEqualObjects([self pixelsForGradient:gradient.CGGradient], srgb);
}

@end
