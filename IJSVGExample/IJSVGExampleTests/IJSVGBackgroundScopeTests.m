//
//  IJSVGBackgroundScopeTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 10/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGTestHelpers.h"

@interface IJSVGBackgroundScopeTests : XCTestCase
@end

@implementation IJSVGBackgroundScopeTests

- (NSData*)pixelsForContents:(NSString*)contents size:(NSUInteger)size
{
    NSString* xml = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'>%@</svg>", contents];
    return IJSVGTestRGBADataForSVG(xml, CGSizeMake(size, size));
}

- (void)testUnusedBackgroundPreservesIsolationAndGroupOpacity
{
    for(NSNumber* size in @[@16, @64, @128]) {
        NSString* format =
            @"<rect width='16' height='16' fill='red'/><g %@ opacity='.5' "
             "transform='translate(1 1) rotate(7 7 7)'>"
             "<rect x='2' y='2' width='9' height='9' fill='lime'/>"
             "<rect x='6' y='4' width='7' height='7' fill='blue' "
             "style='mix-blend-mode:screen'/></g>";
        NSString* actual = [NSString stringWithFormat:format, @"enable-background='new'"];
        NSString* expected = [NSString stringWithFormat:format, @"style='isolation:isolate'"];
        XCTAssertEqualObjects([self pixelsForContents:actual size:size.unsignedIntegerValue],
                              [self pixelsForContents:expected size:size.unsignedIntegerValue]);
    }
}

- (void)testBoundedLayersPreservePaintedCoverage
{
    NSArray<NSString*>* fixtures = @[
        (@"<g transform='translate(1.3 2.1) rotate(23 4 4)'>"
          "<path d='M1 1 L5 1 L5 5' fill='none' stroke='blue' stroke-width='1.7' "
          "stroke-linecap='round' stroke-linejoin='miter'/>"
          "<circle cx='10' cy='9' r='1.2' fill='lime'/></g>"),
        (@"<defs><clipPath id='clip'><circle cx='8' cy='8' r='5'/></clipPath></defs>"
          "<g clip-path='url(#clip)' transform='translate(.3 .7) skewX(20)'>"
          "<rect x='2' y='2' width='8' height='8' fill='blue'/>"
          "<circle cx='11' cy='11' r='3' fill='lime'/></g>"),
        (@"<defs><filter id='blur' x='-100%' y='-100%' width='300%' height='300%'>"
          "<feGaussianBlur stdDeviation='1'/></filter></defs>"
          "<rect x='5' y='5' width='4' height='4' fill='blue' filter='url(#blur)'/>")
    ];
    for(NSNumber* size in @[@16, @64, @128]) {
        for(NSString* contents in fixtures) {
            NSString* actual = [NSString stringWithFormat:
                @"<g enable-background='new' opacity='.6'>%@</g>", contents];
            // The invisible rectangle broadens the reference layer without
            // painting, providing an independent uncropped reference.
            NSString* expected = [NSString stringWithFormat:
                @"<g enable-background='new' opacity='.6'>"
                 "<rect x='-100' y='-100' width='216' height='216' opacity='0'/>%@</g>", contents];
            NSData* pixels = [self pixelsForContents:actual size:size.unsignedIntegerValue];
            XCTAssertEqualObjects(pixels,
                [self pixelsForContents:expected size:size.unsignedIntegerValue]);
            const uint8_t* bytes = pixels.bytes;
            BOOL visible = NO;
            for(NSUInteger i = 0; i < pixels.length; i++) {
                visible |= bytes[i] != 0;
            }
            XCTAssertTrue(visible);
        }
    }
}

- (void)testBackgroundReaderRetainsItsOwnScope
{
    NSString* contents =
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='16' "
         "height='16' color-interpolation-filters='sRGB'><feColorMatrix in='BackgroundImage' "
         "values='0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 1 0'/></filter></defs>"
         "<rect width='16' height='16' fill='red'/><g enable-background='new'>"
         "<rect x='2' y='2' width='4' height='4' fill='blue'/>"
         "<g><rect width='16' height='16' filter='url(#f)'/></g></g>";
    NSData* data = [self pixelsForContents:contents size:16];
    IJSVGAssertColorComponents(IJSVGTestColorFromRGBAData(data, CGSizeMake(16, 16),
        CGPointMake(4, 4)), 0, 1, 0, 1);
    IJSVGAssertColorComponents(IJSVGTestColorFromRGBAData(data, CGSizeMake(16, 16),
        CGPointMake(10, 10)), 1, 0, 0, 1);
}

@end
