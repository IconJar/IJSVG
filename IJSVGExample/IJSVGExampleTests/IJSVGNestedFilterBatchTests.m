//
//  IJSVGNestedFilterBatchTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterTestHelpers.h>

@interface IJSVGNestedFilterBatchTests : XCTestCase
@end

@implementation IJSVGNestedFilterBatchTests

- (void)testNestedFiltersPreserveClipsAndCompositing
{
    [self assertNestedFilterCoverageWithMask:NO];
}

- (void)testNestedMaskReusesCompleteBatchCoverage
{
    [self assertNestedFilterCoverageWithMask:YES];
}

- (void)assertNestedFilterCoverageWithMask:(BOOL)masked
{
    NSString* actualDocument = masked ? [self maskDocumentWithGeneralRendering:NO] : [self documentWithGeneralRendering:NO];
    NSString* expectedDocument = masked ? [self maskDocumentWithGeneralRendering:YES] : [self documentWithGeneralRendering:YES];
    for (NSNumber* size in @[ @32, @220, @440 ]) {
        for (NSNumber* flipped in @[ @NO, @YES ]) {
            [XCTContext runActivityNamed:[NSString stringWithFormat:@"size=%@ flipped=%@", size, flipped]
                                   block:^(id<XCTActivity> activity) {
                                       NSData* actual = [self renderDocument:actualDocument size:size.unsignedIntegerValue flipped:flipped.boolValue];
                                       NSData* expected = [self renderDocument:expectedDocument size:size.unsignedIntegerValue flipped:flipped.boolValue];
                                       XCTAssertNotNil(actual);
                                       XCTAssertNotNil(expected);
                                       if (actual == nil || expected == nil) {
                                           return;
                                       }
                                       XCTAssertEqual(actual.length, expected.length);
                                       XCTAssertTrue([self containsPaintedPixels:actual]);
                                       XCTAssertLessThanOrEqual([self maximumDifference:actual other:expected], 2);
                                   }];
        }
    }
}

- (NSData*)renderDocument:(NSString*)document size:(NSUInteger)size flipped:(BOOL)flipped
{
    IJSVG* svg = IJSVGTestSVGObject(document);
    if (svg == nil) {
        return nil;
    }
    svg.renderingBackingScaleHelper = ^CGFloat {
        return 1;
    };
    CGContextRef context = [self newBitmapWithSize:size flipped:flipped];
    if (context == NULL) {
        return nil;
    }
    CGContextClipToRect(context, CGRectMake(3, 2, size - 6, size - 4));
    [svg drawInRect:CGRectMake(0, 0, size, size) context:context];
    const void* pixels = CGBitmapContextGetData(context);
    XCTAssertTrue(pixels != NULL);
    NSData* data = pixels != NULL ? [NSData dataWithBytes:pixels length:size * size * 4] : nil;
    CGContextRelease(context);
    return data;
}

- (NSString*)maskDocumentWithGeneralRendering:(BOOL)forceGeneral
{
    // The small, reflected mask clips a larger filtered source. Collection
    // retains full filter images. Replay must use them under the mask clip.
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' "
                                       "viewBox='0 0 32 32'><defs><mask id='reflection' "
                                       "maskUnits='userSpaceOnUse' x='12.3' y='6.7' width='17.2' "
                                       "height='20.1' mask-type='luminance'><g "
                                       "transform='translate(32.2 -.4) scale(-1 1)'>%@</g></mask>"
                                       "</defs><rect width='32' height='32' fill='#c05080' "
                                       "mask='url(#reflection)'/></svg>",
        [self documentWithGeneralRendering:forceGeneral]];
}

- (NSString*)documentWithGeneralRendering:(BOOL)forceGeneral
{
    // A fully opaque mask forces the original unbatched source path.
    // Both documents retain the same enclosing filter and ancestor clip.
    NSString* mask = forceGeneral ? @"mask='url(#identity)'" : @"";
    NSMutableString* shapes = [[NSMutableString alloc] init];
    for (NSUInteger index = 0; index < 4; index++) {
        [shapes appendFormat:@"<g transform='translate(%lu %lu)' opacity='.7'>"
                              "<rect x='1' y='2' width='14' height='18' fill='#d08030'/>"
                              "<g filter='url(#child)'><circle cx='10' cy='11' r='8' "
                              "fill='url(#paint)'/><rect x='5' y='4' width='12' height='13' "
                              "fill='#2080d0' opacity='.6'/></g>"
                              "<path d='M 0 20 L 18 2 L 22 24 Z' fill='#50b040' "
                              "opacity='.3'/></g>",
            (unsigned long)(index * 4), (unsigned long)(index * 3)];
    }
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' "
                                       "viewBox='0 0 32 32'><defs>"
                                       "<filter id='outer' x='-30%%' y='-30%%' width='160%%' "
                                       "height='160%%' color-interpolation-filters='sRGB'>"
                                       "<feGaussianBlur stdDeviation='.35'/></filter>"
                                       "<filter id='child' x='-30%%' y='-30%%' width='160%%' "
                                       "height='160%%' color-interpolation-filters='sRGB'>"
                                       "<feGaussianBlur stdDeviation='.6'/><feOffset dx='.3' "
                                       "dy='-.2'/></filter><linearGradient id='paint'>"
                                       "<stop stop-color='#d02060' stop-opacity='.4'/>"
                                       "<stop offset='1' stop-color='#30b080'/></linearGradient>"
                                       "<clipPath id='clip'><circle cx='16' cy='16' r='13.7'/>"
                                       "</clipPath><mask id='identity' maskUnits='userSpaceOnUse' "
                                       "x='-32' y='-32' width='96' height='96'>"
                                       "<rect x='-32' y='-32' width='96' height='96' fill='white'/>"
                                       "</mask></defs><g filter='url(#outer)'>"
                                       "<g clip-path='url(#clip)' transform='rotate(17 16 16)' %@>"
                                       "<rect width='32' height='32' fill='#304050'/>%@"
                                       "<circle cx='25' cy='25' r='5' fill='white' opacity='.4'/>"
                                       "</g></g></svg>",
        mask, shapes];
}

@end
