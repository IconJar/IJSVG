//
//  IJSVGMetalShadowTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 30/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterTestHelpers.h>

@interface IJSVGMetalShadowTests: XCTestCase
@end

@implementation IJSVGMetalShadowTests

- (NSString*)documentWithRadius:(double)radius
                        shadows:(NSUInteger)shadows
                     colorSpace:(NSString*)colorSpace
                   forceGeneral:(BOOL)forceGeneral
                         offset:(NSNumber*)offset
{
    NSMutableString* definitions = [[NSMutableString alloc] init];
    NSMutableString* shapes = [[NSMutableString alloc] init];
    for(NSUInteger index = 0; index < 4; index++) {
        NSMutableString* stages = [NSMutableString stringWithString:@"<feFlood flood-opacity='0' "
                                                                     "result='empty'/><feBlend "
                                                                     "in='SourceGraphic' in2='empty' "
                                                                     "mode='normal' result='shape'/>"];
        for(NSUInteger stage = 0; stage < shadows; stage++) {
            NSString* previous = stage == 0 ? @"shape" : [NSString stringWithFormat:@"shadow%lu",
                                                                                    (unsigned long)stage - 1];
            [stages appendFormat:@"<feColorMatrix in='SourceAlpha' result='hardAlpha' type='matrix' "
                                  "values='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0'/><feOffset "
                                  "dx='%.9g' dy='%.9g'/><feGaussianBlur stdDeviation='%.9g'/>"
                                  "<feComposite in2='hardAlpha' operator='arithmetic' k2='-1' k3='1'/>"
                                  "<feColorMatrix type='matrix' values='0 0 0 0 .8 0 0 0 0 .23 0 0 0 0 "
                                  ".47 0 0 0 1 0'/><feBlend in2='%@' mode='normal' result='shadow%lu'/>",
                                 offset != nil ? offset.doubleValue : (stage % 2 == 0 ? 0.35 : -0.6),
                                 index % 2 == 0 ? -0.6 : 0.4,
                                 radius,
                                 previous,
                                 (unsigned long)stage];
        }
        [definitions appendFormat:@"<filter id='f%lu' filterUnits='userSpaceOnUse' x='.175' y='.31' "
                                   "width='31.2' height='30.5' color-interpolation-filters='%@'>"
                                   "%@</filter>",
                                  (unsigned long)index,
                                  colorSpace,
                                  stages];
        [shapes appendFormat:@"<g filter='url(#f%lu)' opacity='.8'><circle cx='%lu' cy='%lu' r='9' "
                              "fill='#4080c0' opacity='.63'/><rect x='%lu' y='%lu' width='14' "
                              "height='23' rx='2.1' fill='#b06030' opacity='.41'/></g>",
                             (unsigned long)index,
                             (unsigned long)(9 + index * 5),
                             (unsigned long)(10 + index * 3),
                             (unsigned long)(index * 2),
                             (unsigned long)(index * 3)];
    }
    // A clip matching the canvas size selects the general evaluator without changing pixels.
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'>"
                                       "<defs>%@<clipPath id='canvas'><rect width='32' height='32'/>"
                                       "</clipPath></defs><g %@>%@</g></svg>",
                                      definitions,
                                      forceGeneral ? @"clip-path='url(#canvas)'" : @"",
                                      shapes];
}

- (void)compareRadius:(double)radius
              shadows:(NSUInteger)shadows
           colorSpace:(NSString*)colorSpace
              flipped:(BOOL)flipped
               offset:(NSNumber*)offset
{
    NSString* actual = [self documentWithRadius:radius
                                        shadows:shadows
                                     colorSpace:colorSpace
                                   forceGeneral:NO
                                         offset:offset];
    NSString* expected = [self documentWithRadius:radius
                                          shadows:shadows
                                       colorSpace:colorSpace
                                     forceGeneral:YES
                                           offset:offset];
    XCTAssertLessThanOrEqual([self maximumDifference:[self renderDocument:actual
                                                                  flipped:flipped]
                                               other:[self renderDocument:expected
                                                                  flipped:flipped]],
                             2,
                             @"radius=%g shadows=%lu space=%@ flipped=%d offset=%@",
                             radius, (unsigned long)shadows, colorSpace,
                             flipped, offset);
}

- (void)testShadowsMatchGeneralEvaluator
{
    for(NSNumber* radius in @[@0.1, @0.2, @0.5, @1.0, @2.0]) {
        for(NSNumber* shadows in @[@1, @2, @4]) {
            [XCTContext runActivityNamed:[NSString stringWithFormat:@"radius=%@ shadows=%@",
                                                                    radius,
                                                                    shadows]
                                   block:^(id<XCTActivity> activity) {
                [self compareRadius:radius.doubleValue
                            shadows:shadows.unsignedIntegerValue
                         colorSpace:@"sRGB"
                            flipped:NO
                             offset:nil];
            }];
        }
    }
}

- (void)testOrientationAndColorSpace
{
    for(NSNumber* flipped in @[@NO, @YES]) {
        for(NSString* colorSpace in @[@"sRGB", @"linearRGB"]) {
            [XCTContext runActivityNamed:[NSString stringWithFormat:@"%@ flipped=%@",
                                                                    colorSpace,
                                                                    flipped]
                                   block:^(id<XCTActivity> activity) {
                [self compareRadius:0.5
                            shadows:2
                         colorSpace:colorSpace
                            flipped:flipped.boolValue
                             offset:nil];
            }];
        }
    }
}

- (void)testFractionalOffsetsNearPixelBoundaries
{
    for(NSNumber* offset in @[@0.000001, @-0.000001, @0.999999, @-0.999999]) {
        [XCTContext runActivityNamed:[NSString stringWithFormat:@"offset=%@",
                                                                offset]
                               block:^(id<XCTActivity> activity) {
            [self compareRadius:1
                        shadows:2
                     colorSpace:@"sRGB"
                        flipped:NO
                         offset:offset];
        }];
    }
}

- (void)testRenderingOptionsToggleMetalShadows
{
    for(NSNumber* shadows in @[@1, @2, @4]) {
        for(NSNumber* flipped in @[@NO, @YES]) {
            for(NSNumber* exportImage in @[@NO, @YES]) {
                NSString* name = [NSString stringWithFormat:@"shadows=%@ flipped=%@ exportImage=%@",
                                                            shadows,
                                                            flipped,
                                                            exportImage];
                [XCTContext runActivityNamed:name
                                       block:^(id<XCTActivity> activity) {
                    NSString* document = [self documentWithRadius:1
                                                          shadows:shadows.unsignedIntegerValue
                                                       colorSpace:@"sRGB"
                                                     forceGeneral:NO
                                                           offset:nil];
                    [self assertFilterOptionsForDocument:document
                                                 flipped:flipped.boolValue
                                             exportImage:exportImage.boolValue];
                }];
            }
        }
    }
}

- (void)testConcurrentBatchesMatchGeneralEvaluator
{
    NSString* xml = [self documentWithRadius:0.5
                                     shadows:2
                                  colorSpace:@"sRGB"
                                forceGeneral:NO
                                      offset:nil];
    NSString* reference = [self documentWithRadius:0.5
                                           shadows:2
                                        colorSpace:@"sRGB"
                                      forceGeneral:YES
                                            offset:nil];
    NSData* expected = [self renderDocument:reference
                                    flipped:NO];
    for(NSUInteger batch = 0; batch < 3; batch++) {
        [self runWorkers:12
            freshThreads:NO
                   block:^(NSUInteger index) {
            NSData* actual = [self renderDocument:xml
                                          flipped:NO];
            XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                       other:expected],
                                     2, @"batch=%lu worker=%lu",
                                     (unsigned long)batch,
                                     (unsigned long)index);
        }];
    }
}

@end
