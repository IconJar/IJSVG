//
//  IJSVGAlphaOcclusionTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 22/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterTestHelpers.h>

@interface IJSVGAlphaOcclusionTests : XCTestCase
@end

@implementation IJSVGAlphaOcclusionTests

- (void)testPreservesAlphaAtOpaqueAndTransparentEdges
{
    NSArray<NSString*>* variants = @[ @"", @"transform='rotate(17 64 64)'",
        @"transform='translate(128 0) scale(-1 1)'", @"opacity='.6'",
        @"style='isolation:isolate'", @"style='mix-blend-mode:multiply'" ];
    for (NSString* attributes in variants) {
        for (NSNumber* orientation in @[ @NO, @YES ]) {
            BOOL flipped = orientation.boolValue;

            // The asymmetric base catches reversed bitmap rows. One filter is
            // covered, another crosses its edge, and a third lies outside it.
            NSString* body = [NSString stringWithFormat:@"<g %@>"
                                                         "<rect x='8.25' y='7.5' width='110' height='49.25' fill='red'/>"
                                                         "<g clip-path='url(#clip)'>"
                                                         "<rect x='24' y='20' width='16' height='14' fill='blue' filter='url(#blur)'/>"
                                                         "<rect x='48' y='49' width='20' height='14' fill='blue' filter='url(#blur)'/>"
                                                         "<rect x='28' y='85' width='24' height='18' fill='blue' filter='url(#blur)'/>"
                                                         "</g></g>",
                attributes];
            NSData* actual = [self pixelsForDocument:[self documentWithBody:body general:NO] flipped:flipped];
            NSData* expected = [self pixelsForDocument:[self documentWithBody:body general:YES] flipped:flipped];
            XCTAssertNotNil(actual);
            XCTAssertNotNil(expected);
            if (actual == nil || expected == nil) {
                continue;
            }
            XCTAssertTrue([self containsPaintedPixels:actual], @"%@ flipped=%d", attributes, flipped);
            XCTAssertLessThanOrEqual([self maximumDifference:actual other:expected], 1, @"%@ flipped=%d", attributes, flipped);
        }
    }
}

- (void)testGradientCoveragePlanningPreservesPixels
{
    NSArray<NSString*>* gradients = @[
        @"<linearGradient id='g'%@>%@</linearGradient>",
        @"<radialGradient id='g'%@>%@</radialGradient>"
    ];
    NSArray<NSArray<NSString*>*>* attributes = @[
        @[ @"", @" gradientTransform='rotate(23)' spreadMethod='reflect'", @" x1='0' x2='0'" ],
        @[ @"", @" fx='35%' fy='40%'", @" fx='150%'", @" fr='20%'" ]
    ];
    for (NSUInteger kind = 0; kind < gradients.count; kind++) {
        for (NSString* geometry in attributes[kind]) {
            for (NSString* opacity in @[ @"1", @".5" ]) {
                NSString* stops = [NSString stringWithFormat:@"<stop stop-color='red'/><stop offset='1' stop-color='blue' stop-opacity='%@'/>", opacity];
                NSString* definition = [NSString stringWithFormat:gradients[kind], geometry, stops];
                NSString* body = [NSString stringWithFormat:@"<defs>%@</defs><g transform='rotate(17 64 64)'>"
                                                             "<rect x='8.25' y='7.5' width='110' height='49.25' fill='url(#g)'/>"
                                                             "<rect x='24' y='20' width='16' height='14' fill='blue' filter='url(#blur)'/>"
                                                             "<rect x='48' y='49' width='20' height='14' fill='blue' filter='url(#blur)'/>"
                                                             "<rect x='28' y='85' width='24' height='18' fill='blue' filter='url(#blur)'/>"
                                                             "</g>",
                    definition];
                for (NSNumber* orientation in @[ @NO, @YES ]) {
                    NSData* actual = [self pixelsForDocument:[self documentWithBody:body general:NO] flipped:orientation.boolValue];
                    NSData* expected = [self pixelsForDocument:[self documentWithBody:body general:YES] flipped:orientation.boolValue];
                    XCTAssertNotNil(actual);
                    XCTAssertNotNil(expected);
                    if (actual == nil || expected == nil) {
                        continue;
                    }
                    XCTAssertTrue([self containsPaintedPixels:actual]);
                    XCTAssertLessThanOrEqual([self maximumDifference:actual other:expected], 1, @"%@ flipped=%@", definition, orientation);
                }
            }
        }
    }
}

- (void)testPreservesBackgroundDependentDescendants
{
    NSString* body = @"<g enable-background='new'>"
                      "<rect width='128' height='64' fill='red'/>"
                      "<rect x='16' y='16' width='24' height='24' fill='blue' filter='url(#background)'/>"
                      "</g>";
    NSData* actual = [self pixelsForDocument:[self documentWithBody:body general:NO] flipped:NO];
    NSData* expected = [self pixelsForDocument:[self documentWithBody:body general:YES] flipped:NO];
    XCTAssertNotNil(actual);
    XCTAssertNotNil(expected);
    if (actual == nil || expected == nil) {
        return;
    }
    XCTAssertLessThanOrEqual([self maximumDifference:actual other:expected], 1);
}

- (NSString*)documentWithBody:(NSString*)body general:(BOOL)general
{
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='128' height='128'>"
                                       "<defs><filter id='white' filterUnits='userSpaceOnUse' x='0' y='0' width='128' height='128'>"
                                       "<feColorMatrix values='0 0 0 0 1 0 0 0 0 1 0 0 0 0 1 0 0 0 1 0'/>%@</filter>"
                                       "<filter id='blur'><feGaussianBlur stdDeviation='1'/></filter>"
                                       "<filter id='background'>"
                                       "<feColorMatrix in='BackgroundImage' values='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0'/>"
                                       "</filter><clipPath id='clip'><rect x='4.5' y='3.25' width='119' height='120'/></clipPath>"
                                       "</defs><g filter='url(#white)'>%@</g></svg>",
        general ? @"<feOffset dx='0' dy='0'/>" : @"", body];
}

- (NSData*)pixelsForDocument:(NSString*)source flipped:(BOOL)flipped
{
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:source error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(svg);
    if (svg == nil) {
        return nil;
    }
    CGContextRef bitmap = [self newBitmapWithSize:256 flipped:flipped];
    if (bitmap == NULL) {
        return nil;
    }
    [svg drawInRect:CGRectMake(0, 0, 256, 256) context:bitmap];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(bitmap) length:256 * 1024];
    CGContextRelease(bitmap);
    return pixels;
}

@end
