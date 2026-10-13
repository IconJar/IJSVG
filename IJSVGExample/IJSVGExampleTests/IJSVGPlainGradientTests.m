//
//  IJSVGPlainGradientTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <IJSVG/IJSVGUmbrella.h>
#import <XCTest/XCTest.h>

@interface IJSVGPlainGradientTests : XCTestCase
@end

@implementation IJSVGPlainGradientTests

- (NSString*)stops
{
    return @"<stop offset='0' stop-color='#ff0000'/>"
            "<stop offset='1' stop-color='#0000ff' stop-opacity='.5'/>";
}

- (IJSVG*)document:(NSString*)body
{
    NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' "
                                               @"xmlns:xlink='http://www.w3.org/1999/xlink' "
                                                "width='64' height='64'>%@</svg>",
        body];
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml];
    XCTAssertNotNil(svg);
    return svg;
}

- (NSData*)pixels:(IJSVG*)svg
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    XCTAssertTrue(colorSpace != NULL);
    if (colorSpace == NULL) {
        return nil;
    }
    CGContextRef context = CGBitmapContextCreate(NULL, 64, 64, 8, 256, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    XCTAssertTrue(context != NULL);
    if (context == NULL) {
        return nil;
    }
    svg.renderingBackingScaleHelper = ^CGFloat {
        return 1.f;
    };
    [svg drawInRect:CGRectMake(0, 0, 64, 64) context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:64 * 256];
    CGContextRelease(context);
    return pixels;
}

- (void)testReferencedStopsMatchExpandedGradients
{
    // Include stylesheet, local stops, units, transforms, spread, and inherited
    // coordinates.
    NSArray<NSArray<NSString*>*>* variants = @[ @[ @"", @"", @"", @"" ], @[ @"<style>stop { stop-opacity: .7 }</style>", @"", @"", @"" ], @[ @"", @"gradientUnits='userSpaceOnUse'", @"", @"" ], @[ @"", @"", @"gradientTransform='rotate(20)'", @"" ], @[ @"", @"spreadMethod='reflect'", @"", @"" ], @[ @"", @"x1='.25'", @"", @"" ], @[ @"", @"", @"", @"<stop offset='0' stop-color='green'/><stop offset='1' stop-color='black'/>" ] ];
    for (NSArray<NSString*>* variant in variants) {
        NSString* style = variant[0];
        NSString* inherited = variant[1];
        NSString* local = variant[2];
        NSString* localStops = variant[3];
        NSString* expectedStops = localStops.length == 0 ? self.stops : localStops;
        NSString* common = @"<rect width='64' height='64' fill='url(#paint)'/>";
        IJSVG* referenced = [self document:[NSString stringWithFormat:@"%@<defs><linearGradient id='base' %@>%@</linearGradient>"
                                                                       "<linearGradient id='paint' x2='.8' %@ "
                                                                       "xlink:href='#base'>%@</linearGradient></defs>%@",
                                               style, inherited, self.stops, local, localStops, common]];
        IJSVG* expanded = [self document:[NSString stringWithFormat:@"%@<defs><linearGradient id='paint' x2='.8' %@ "
                                                                    @"%@>%@</linearGradient></defs>%@",
                                             style, inherited, local, expectedStops, common]];
        XCTAssertEqualObjects([self pixels:referenced], [self pixels:expanded], @"%@", variant);
    }
}

- (IJSVG*)documentWithStops:(NSString*)stops extra:(NSString*)extra
{
    return [self document:[NSString stringWithFormat:@"<defs color='green'><linearGradient "
                                                     @"id='base'>%@</linearGradient>"
                                                      "<linearGradient id='paint' x1='.1' x2='.9' href='#base' "
                                                      "%@/></defs>"
                                                      "<rect width='32' height='64' fill='url(#paint)'/>"
                                                      "<rect x='32' width='32' height='64' fill='url(#paint)'/>",
                              stops, extra]];
}

- (void)testPlainStopsMatchGeneralParserForContextualValues
{
    NSArray<NSString*>* variants = @[ self.stops, @"<stop stop-color='currentColor'/><stop offset='1' stop-color='blue'/>", @"<stop stop-color='inherit' stop-opacity='inherit'/><stop offset='1'/>", @"<stop stop-color='var(--missing, red)'/><stop offset='1' stop-color='blue'/>", @"<stop offset='.8' stop-color='red'/><stop offset='.2' stop-color='blue'/>", @"<stop offset='0' style='stop-color: green'/><stop offset='1' stop-color='blue'/>", @"" ];
    for (NSString* stops in variants) {
        // An ignored attribute deliberately selects the general merge path.
        IJSVG* plain = [self documentWithStops:stops extra:@""];
        IJSVG* general = [self documentWithStops:stops extra:@"data-general='true'"];
        XCTAssertEqualObjects([self pixels:plain], [self pixels:general], @"%@", stops);
    }
}

- (void)testRepeatedReferencesKeepIndependentNodes
{
    IJSVG* svg = [self document:[NSString stringWithFormat:@"<defs><linearGradient id='base'>%@</linearGradient>"
                                                            "<linearGradient id='paint' x2='1' href='#base'/></defs>"
                                                            "<rect width='32' height='64' fill='url(#paint)'/>"
                                                            "<rect x='32' width='32' height='64' fill='url(#paint)'/>",
                                    self.stops]];
    IJSVGRootNode* root = svg.rootNode;
    XCTAssertEqual(root.children.count, 2u);
    if (root.children.count != 2) {
        return;
    }
    IJSVGPaintNode* firstShape = (IJSVGPaintNode*)root.children[0];
    IJSVGPaintNode* secondShape = (IJSVGPaintNode*)root.children[1];
    XCTAssertTrue([firstShape.fill isKindOfClass:IJSVGLinearGradient.class]);
    XCTAssertTrue([secondShape.fill isKindOfClass:IJSVGLinearGradient.class]);
    IJSVGLinearGradient* first = (IJSVGLinearGradient*)firstShape.fill;
    IJSVGLinearGradient* second = (IJSVGLinearGradient*)secondShape.fill;
    XCTAssertNotEqual(first, second);
    XCTAssertNotNil(first.children.firstObject);
    XCTAssertNotNil(second.children.firstObject);
    XCTAssertNotEqual(first.children.firstObject, second.children.firstObject);
    IJSVGUnitLength* before = second.x2;
    first.x2 = [IJSVGUnitLength unitWithFloat:.25];
    XCTAssertEqual(second.x2, before);
    XCTAssertEqual(second.numberOfStops, 2u);
}

- (void)testPreviouslyUsedGradientCanBeInheritedAgain
{
    NSString* common = @"<rect width='32' height='64' fill='url(#paint)'/>";
    IJSVG* referenced = [self document:[NSString stringWithFormat:@"<defs><linearGradient id='base'>%@</linearGradient>"
                                                                   "<linearGradient id='paint' x2='1' href='#base'/>"
                                                                   "<linearGradient id='chain' x1='.2' href='#paint'/></defs>"
                                                                   "%@<rect x='32' width='32' height='64' fill='url(#chain)'/>",
                                           self.stops, common]];
    IJSVG* expanded = [self document:[NSString stringWithFormat:@"<defs><linearGradient id='paint' x2='1'>%@</linearGradient>"
                                                                 "<linearGradient id='chain' x1='.2' "
                                                                 "x2='1'>%@</linearGradient></defs>"
                                                                 "%@<rect x='32' width='32' height='64' fill='url(#chain)'/>",
                                         self.stops, self.stops, common]];
    XCTAssertEqualObjects([self pixels:referenced], [self pixels:expanded]);
}

- (void)testUnusedGradientChainsMatchExpandedSources
{
    for (NSString* kind in @[ @"linearGradient", @"radialGradient" ]) {
        NSString* coordinates = [kind isEqualToString:@"linearGradient"] ? @"x1='.2' x2='.8'" : @"cx='.2' r='.8'";
        NSString* artwork = @"<rect width='64' height='64' fill='url(#paint)'/>";
        IJSVG* referenced = [self document:[NSString stringWithFormat:@"<defs><%@ id='base' %@ "
                                                                      @"spreadMethod='reflect'>%@</%@>"
                                                                       "<%@ id='middle' href='#base'/><%@ "
                                                                       "id='paint' href='#middle'/></defs>%@",
                                               kind, coordinates, self.stops, kind, kind, kind, artwork]];
        IJSVG* expanded = [self document:[NSString stringWithFormat:@"<defs><%@ id='paint' %@ "
                                                                    @"spreadMethod='reflect'>%@</%@></defs>%@",
                                             kind, coordinates, self.stops, kind, artwork]];
        XCTAssertEqualObjects([self pixels:referenced], [self pixels:expanded], @"%@", kind);
    }
}

- (void)testPatternChainUsesLocalAttributesAndInheritedChildren
{
    NSString* artwork = @"<rect width='64' height='64' fill='url(#paint)'/>";
    NSString* child = @"<rect width='5' height='7' fill='red'/>";
    IJSVG* referenced = [self document:[NSString stringWithFormat:@"<defs><pattern id='base' patternUnits='userSpaceOnUse' "
                                                                  @"width='20' height='12'>%@</pattern>"
                                                                   "<pattern id='middle' href='#base' width='10'/><pattern "
                                                                   "id='paint' href='#middle'/></defs>%@",
                                           child, artwork]];
    IJSVG* expanded = [self document:[NSString stringWithFormat:@"<defs><pattern id='paint' "
                                                                @"patternUnits='userSpaceOnUse' width='10' "
                                                                @"height='12'>%@</pattern></defs>%@",
                                         child, artwork]];
    XCTAssertEqualObjects([self pixels:referenced], [self pixels:expanded]);
}

- (void)testCachedStopsKeepMutableInstancesIndependent
{
    NSMutableString* body = [NSMutableString stringWithFormat:@"<defs><linearGradient id='paint'>%@</linearGradient></defs>", self.stops];
    for (NSUInteger index = 0; index < 4; index++) {
        [body appendFormat:@"<rect x='%lu' width='16' height='64' fill='url(#paint)'/>", index * 16];
    }
    IJSVG* svg = [self document:body];
    IJSVGGradient* first = (IJSVGGradient*)((IJSVGPaintNode*)svg.rootNode.children[2]).fill;
    IJSVGGradient* second = (IJSVGGradient*)((IJSVGPaintNode*)svg.rootNode.children[3]).fill;
    XCTAssertNotEqual(first, second);
    XCTAssertNotEqual(first.locations, second.locations);
    IJSVGStop* firstStop = (IJSVGStop*)first.children.firstObject;
    IJSVGStop* secondStop = (IJSVGStop*)second.children.firstObject;
    XCTAssertNotEqual(firstStop, secondStop);
    XCTAssertNotEqual(firstStop.fill, secondStop.fill);
    NSColor* original = ((IJSVGColorNode*)secondStop.fill).color;
    ((IJSVGColorNode*)firstStop.fill).color = NSColor.greenColor;
    first.locations[0] = .3;
    XCTAssertEqualObjects(((IJSVGColorNode*)secondStop.fill).color, original);
    XCTAssertEqual(second.locations[0], 0);
    first.fillOpacity = [IJSVGUnitLength unitWithFloat:.4];
    XCTAssertEqualWithAccuracy(firstStop.fillOpacity.value, .4, .0001);
    XCTAssertEqualWithAccuracy(secondStop.fillOpacity.value, 1, .0001);
}

- (void)testCachedStopsRespectInheritedOpacityAndCurrentColor
{
    for (NSString* color in @[ @"red", @"currentColor" ]) {
        NSMutableString* references = [NSMutableString stringWithFormat:@"<defs><linearGradient id='base'><stop stop-color='%@'/><stop "
                                                                        @"offset='1' stop-color='blue'/></linearGradient>",
            color];
        NSMutableString* expanded = [NSMutableString stringWithString:@"<defs>"];
        NSMutableString* artwork = [NSMutableString string];
        for (NSUInteger index = 0; index < 4; index++) {
            NSString* opacity = index == 3 ? @".3" : @"1";
            NSString* current = index == 3 ? @"green" : @"red";
            [references appendFormat:@"<linearGradient id='g%lu' href='#base' "
                                     @"color='%@' fill-opacity='%@'/>",
                index, current, opacity];
            [expanded appendFormat:@"<linearGradient id='g%lu' color='%@' fill-opacity='%@'><stop "
                                   @"stop-color='%@'/><stop offset='1' "
                                   @"stop-color='blue'/></linearGradient>",
                index, current, opacity, color];
            [artwork appendFormat:@"<rect x='%lu' width='16' height='64' fill='url(#g%lu)'/>", index * 16, index];
        }
        [references appendFormat:@"</defs>%@", artwork];
        [expanded appendFormat:@"</defs>%@", artwork];
        XCTAssertEqualObjects([self pixels:[self document:references]], [self pixels:[self document:expanded]], @"%@", color);
    }
}

- (void)testInheritedChildrenKeepSelectorRelationships
{
    NSString* style = @"<style>#paint > stop { stop-color: green } #paint > stop "
                      @"+ stop { stop-color: blue }</style>";
    NSString* artwork = @"<rect width='64' height='64' fill='url(#paint)'/>";
    IJSVG* referenced = [self document:[NSString stringWithFormat:@"%@<defs><linearGradient "
                                                                  @"id='base'>%@</linearGradient><linearGradient "
                                                                  @"id='paint' href='#base'/></defs>%@",
                                           style, self.stops, artwork]];
    IJSVG* expanded = [self document:[NSString stringWithFormat:@"%@<defs><linearGradient "
                                                                @"id='paint'>%@</linearGradient></defs>%@",
                                         style, self.stops, artwork]];
    XCTAssertEqualObjects([self pixels:referenced], [self pixels:expanded]);
}

- (void)testMissingAndCyclicReferencesKeepLocalGradientValues
{
    for (NSString* reference in @[ @"missing", @"paint" ]) {
        IJSVG* svg = [self document:[NSString stringWithFormat:@"<defs><linearGradient id='paint' href='#%@' "
                                                               @"x2='.7'>%@</linearGradient></defs>"
                                                                "<rect width='64' height='64' fill='url(#paint)'/>",
                                        reference, self.stops]];
        IJSVGLinearGradient* gradient = (IJSVGLinearGradient*)((IJSVGPaintNode*)svg.rootNode.children.firstObject).fill;
        XCTAssertEqualWithAccuracy(gradient.x2.value, .7, .0001);
        XCTAssertEqual(gradient.numberOfStops, 2u);
    }
}

@end
