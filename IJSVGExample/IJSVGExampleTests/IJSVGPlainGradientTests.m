//
//  IJSVGPlainGradientTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <IJSVG/IJSVGUmbrella.h>
#import <IJSVGGradientStops.h>
#import <IJSVGNodeParsing.h>
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

@interface IJSVGPlainGradientTests : XCTestCase
@end

@implementation IJSVGPlainGradientTests

- (void)testSharedCGGradientsAreLazyAndDetachWhenEdited
{
    NSString* stops = @"<stop stop-color='red'/><stop offset='1' stop-color='blue'/>";
    IJSVG* svg = [self document:[NSString stringWithFormat:@"<defs><linearGradient id='a'>%@</linearGradient><linearGradient id='b'>%@</linearGradient></defs><rect width='32' height='64' fill='url(#a)'/><rect x='32' width='32' height='64' fill='url(#b)'/>", stops, stops]];
    IJSVGGradient* first = (IJSVGGradient*)((IJSVGPaintNode*)svg.rootNode.children[0]).fill;
    IJSVGGradient* second = (IJSVGGradient*)((IJSVGPaintNode*)svg.rootNode.children[1]).fill;
    Ivar rendered = class_getInstanceVariable(IJSVGGradient.class, "_CGGradient");
    XCTAssertEqual(*(CGGradientRef*)((char*)(__bridge void*)first + ivar_getOffset(rendered)), NULL);
    XCTAssertEqual(*(CGGradientRef*)((char*)(__bridge void*)second + ivar_getOffset(rendered)), NULL);
    CGGradientRef shared = first.CGGradient;
    XCTAssertNotEqual(shared, NULL);
    XCTAssertEqual(shared, second.CGGradient);
    IJSVGGradient* copy = first.copy;
    XCTAssertEqual(copy.CGGradient, shared);
    IJSVGStop* stop = (IJSVGStop*)second.children[0];
    stop.fill = [IJSVGColorNode colorNodeWithColor:NSColor.greenColor.CGColor];
    [second parseColorStops];
    XCTAssertNotEqual(second.CGGradient, shared);
    XCTAssertEqual(first.CGGradient, shared);
    XCTAssertEqual(copy.CGGradient, shared);
    copy.colors = @[ (__bridge id)NSColor.yellowColor.CGColor, (__bridge id)NSColor.blackColor.CGColor ];
    XCTAssertNotEqual(copy.CGGradient, shared);
    XCTAssertEqual(first.CGGradient, shared);
    [svg setNeedsDisplay];
    NSString* xml = [svg SVGStringWithSize:CGSizeMake(64, 64) options:IJSVGExporterOptionRemoveComments];
    XCTAssertEqualObjects([self pixels:svg], [self pixels:[[IJSVG alloc] initWithSVGString:xml]]);
}

- (void)testSharedCGGradientCopiesCanConstructConcurrently
{
    IJSVG* svg = [self document:@"<defs><linearGradient id='a'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect width='64' height='64' fill='url(#a)'/>"];
    IJSVGGradient* gradient = (IJSVGGradient*)((IJSVGPaintNode*)svg.rootNode.children[0]).fill;
    NSMutableArray<IJSVGGradient*>* copies = [[NSMutableArray alloc] init];
    for (NSUInteger index = 0; index < 32; index++) {
        [copies addObject:gradient.copy];
    }
    dispatch_apply(copies.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        (void)copies[index].CGGradient;
    });
    CGGradientRef shared = gradient.CGGradient;
    for (IJSVGGradient* copy in copies) {
        XCTAssertEqual(copy.CGGradient, shared);
    }
}

- (void)testSharedInlineStopSequencesKeepIndependentEditableChildren
{
    NSString* stops = @"<stop offset='0' style='stop-color:#c1ff36;stop-opacity:1'/><stop offset='1' style='stop-color:#c1ff36;stop-opacity:0'/>";
    NSString* body = [NSString stringWithFormat:@"<style>* {stroke-linecap:square}</style><defs><linearGradient id='a'>%@</linearGradient><linearGradient id='b'>%@</linearGradient></defs><rect width='32' height='64' fill='url(#a)'/><rect x='32' width='32' height='64' fill='url(#b)'/>", stops, stops];
    IJSVG* svg = [self document:body];
    IJSVG* reference = [self document:[body stringByReplacingOccurrencesOfString:@"<stop " withString:@"<stop class='general' "]];
    XCTAssertEqualObjects([self pixels:svg], [self pixels:reference]);
    IJSVGGradient* first = (IJSVGGradient*)((IJSVGPaintNode*)svg.rootNode.children[0]).fill;
    IJSVGGradient* second = (IJSVGGradient*)((IJSVGPaintNode*)svg.rootNode.children[1]).fill;
    Ivar storage = class_getInstanceVariable(IJSVGGroup.class, "_children");
    XCTAssertEqual([object_getIvar(second, storage) count], 0u);
    XCTAssertNotEqual(first.children[0], second.children[0]);
    XCTAssertEqual(((IJSVGStop*)second.children[0]).fillOpacity.value, 1);
    XCTAssertEqual(((IJSVGStop*)second.children[1]).fillOpacity.value, 0);
    IJSVGStop* edited = (IJSVGStop*)second.children[0];
    edited.fill = [IJSVGColorNode colorNodeWithColor:NSColor.redColor.CGColor];
    [second parseColorStops];
    [svg setNeedsDisplay];
    XCTAssertFalse(CGColorEqualToColor(((IJSVGColorNode*)((IJSVGStop*)first.children[0]).fill).color, ((IJSVGColorNode*)edited.fill).color));
    NSData* pixels = [self pixels:svg];
    NSString* xml = [svg SVGStringWithSize:CGSizeMake(64, 64) options:IJSVGExporterOptionRemoveComments];
    XCTAssertEqualObjects([self pixels:[[IJSVG alloc] initWithSVGString:xml]], pixels);
}

- (void)testSharedStopSequencesKeepInheritedOpacityAndContextSeparate
{
    for (NSString* stops in @[ @"<stop style='stop-color:red'/><stop offset='1' style='stop-color:blue'/>", @"<stop style='stop-color:currentColor'/><stop offset='1' stop-color='blue'/>", @"<stop style='stop-color:var(--paint)'/><stop offset='1' stop-color='blue'/>" ]) {
        NSString* body = [NSString stringWithFormat:@"<defs><linearGradient id='a' stop-opacity='.25' fill-opacity='.25' color='red' style='--paint:red'>%@</linearGradient><linearGradient id='b' stop-opacity='.75' fill-opacity='.75' color='lime' style='--paint:lime'>%@</linearGradient></defs><rect width='32' height='64' fill='url(#a)'/><rect x='32' width='32' height='64' fill='url(#b)'/>", stops, stops];
        IJSVG* actual = [self document:body];
        IJSVG* reference = [self document:[body stringByReplacingOccurrencesOfString:@"<stop " withString:@"<stop class='general' "]];
        XCTAssertEqualObjects([self pixels:actual], [self pixels:reference], @"%@", stops);
    }
}

- (void)testPlainInlineStopDeclarationsMatchGeneralCascade
{
    for (NSString* style in @[ @"", @"<style>* {stroke-linecap:square;stroke-linejoin:round}</style>" ]) {
        for (NSString* stops in @[
                 @"<stop offset='0' style='stop-color:#800000;stop-opacity:1'/><stop offset='1' style='stop-color:#800000;stop-opacity:0'/>",
                 @"<stop stop-color='red' style='stop-opacity:.25;offset:.1'/><stop offset='1' stop-opacity='.5' style='stop-color:blue!important;stop-color:lime'/>",
                 @"<stop stop-color='red' style='stop-color:var(--paint)'/><stop offset='1' stop-color='blue'/>",
                 @"<stop stop-color='currentColor'/><stop offset='1' style='stop-color:currentColor;stop-opacity:.5'/>",
                 @"<stop stop-color='red' style='stop-opacity:inherit'/><stop offset='1' stop-color='blue'/>",
                 @"<stop stop-color='red' style='stop-color:initial;stop-opacity:unset'/><stop offset='1' stop-color='blue'/>",
                 @"<stop stop-color='red' style='stop-color:revert'/><stop offset='1' stop-color='blue'/>",
                 @"<stop stop-color='red' style='stop-color:in/**/herit'/><stop offset='1' stop-color='blue'/>"
             ]) {
            NSString* body = [NSString stringWithFormat:
                    @"%@<defs><linearGradient id='paint' color='lime' style='--paint:orange'>%@</linearGradient></defs>"
                     "<rect width='64' height='64' fill='url(#paint)'/>",
                style, stops];
            IJSVG* fast = [self document:body];
            IJSVG* general = [self document:[body stringByReplacingOccurrencesOfString:@"<stop " withString:@"<stop class='force-general' "]];
            XCTAssertEqualObjects([self pixels:fast], [self pixels:general], @"%@", stops);
        }
    }
}

- (void)testUnrelatedStyleRulesPreservePlainAndDeferredStops
{
    NSMutableString* body = [NSMutableString stringWithFormat:
            @"<style>* { stroke-linejoin:round; stroke-linecap:butt }</style>"
             "<defs><linearGradient id='paint'>%@</linearGradient></defs>",
        self.stops];
    for (NSUInteger index = 0; index < 5; index++) {
        [body appendFormat:@"<rect x='%lu' width='12' height='64' fill='url(#paint)'/>", index * 12];
    }
    IJSVG* actual = [self document:body];
    IJSVG* general = [self document:[body stringByReplacingOccurrencesOfString:@"<stop " withString:@"<stop class='force-general' "]];
    XCTAssertEqualObjects([self pixels:actual], [self pixels:general]);
    IJSVGGradient* gradient = (IJSVGGradient*)((IJSVGPaintNode*)actual.rootNode.children.lastObject).fill;
    Ivar storage = class_getInstanceVariable(IJSVGGroup.class, "_children");
    XCTAssertEqual([object_getIvar(gradient, storage) count], 0u);
    XCTAssertEqual(gradient.children.count, 2u);
    XCTAssertEqual(((IJSVGStop*)gradient.children.lastObject).fillOpacity.value, .5);
}

- (void)testStopStylesAndVariablesKeepTheGeneralCascade
{
    for (NSString* style in @[
             @"stop { stop-color:lime!important }",
             @"linearGradient stop { stop-opacity:.25 }",
             @"stop { offset:.5 }",
             @"* { --paint:lime } stop { stop-color:var(--paint) }",
             @"stop { color:lime; stop-color:currentColor }"
         ]) {
        NSMutableString* body = [NSMutableString stringWithFormat:
                @"<style>%@</style><defs><linearGradient id='paint'>%@</linearGradient></defs>", style, self.stops];
        for (NSUInteger index = 0; index < 5; index++) {
            [body appendFormat:@"<rect x='%lu' width='12' height='64' fill='url(#paint)'/>", index * 12];
        }
        IJSVG* actual = [self document:body];
        IJSVG* general = [self document:[body stringByReplacingOccurrencesOfString:@"<stop " withString:@"<stop class='force-general' "]];
        XCTAssertEqualObjects([self pixels:actual], [self pixels:general], @"%@", style);
    }
}

- (void)testUnrelatedRulesKeepContextualStopValuesUncached
{
    for (NSString* color in @[ @"currentColor", @"var(--paint)" ]) {
        NSString* body = [NSString stringWithFormat:
                @"<style>* { stroke-linejoin:round }</style>"
                 "<defs><linearGradient id='paint' color='lime' style='--paint:blue'>"
                 "<stop stop-color='%@'/><stop offset='1' stop-color='red'/></linearGradient></defs>"
                 "<rect width='64' height='64' fill='url(#paint)'/>",
            color];
        IJSVG* actual = [self document:body];
        IJSVG* general = [self document:[body stringByReplacingOccurrencesOfString:@"<stop " withString:@"<stop class='force-general' "]];
        XCTAssertEqualObjects([self pixels:actual], [self pixels:general]);
    }
}

- (void)testGradientCacheEligibilityReadsBytesWithoutMaterializingStrings
{
    for (NSString* color in @[ @"#ff0000", @"red", @"CURRENTCOLOR", @"xINHERITy", @"vAr(--paint)", @"réD", @"" ]) {
        NSString* source = [NSString stringWithFormat:@"<linearGradient><stop offset='.25' stop-color='%@' stop-opacity='.5'/></linearGradient>", color];
        NSData* data = [source dataUsingEncoding:NSUTF8StringEncoding];
        IJSVGXMLDocument* document = IJSVGXMLDocumentCreate(data.bytes, data.length);
        XCTAssertNotEqual(document, NULL);
        if (document == NULL) {
            continue;
        }
        BOOL expected = [color isEqualToString:@"#ff0000"] || [color isEqualToString:@"red"];
        XCTAssertEqual([IJSVGGradientStops canCacheElement:IJSVGXMLRoot(document)], expected, @"%@", color);
        IJSVGXMLAttributeList attributes = IJSVGXMLAttributes(IJSVGXMLFirstChild(IJSVGXMLRoot(document)));
        for (NSUInteger index = 0; index < attributes.count; index++) {
            XCTAssertEqual(attributes.first[index].cachedValue, NULL);
        }
        IJSVGXMLDocumentDestroy(document);
    }
}

- (void)testGradientCacheKeepsNoncanonicalStopNamesUncached
{
    for (NSString* name in @[ @"STOP", @"sTop" ]) {
        NSString* source = [NSString stringWithFormat:@"<linearGradient><%@ offset='0' stop-color='red'/></linearGradient>", name];
        NSData* data = [source dataUsingEncoding:NSUTF8StringEncoding];
        IJSVGXMLDocument* document = IJSVGXMLDocumentCreate(data.bytes, data.length);
        XCTAssertNotEqual(document, NULL);
        if (document != NULL) {
            XCTAssertFalse([IJSVGGradientStops canCacheElement:IJSVGXMLRoot(document)]);
            IJSVGXMLDocumentDestroy(document);
        }
    }
}

- (IJSVG*)repeatedGradientDocument
{
    NSMutableString* body = [NSMutableString stringWithFormat:@"<defs><linearGradient id='paint'>%@</linearGradient></defs>", self.stops];
    for (NSUInteger index = 0; index < 4; index++) {
        [body appendFormat:@"<rect x='%lu' width='16' height='64' fill='url(#paint)'/>", index * 16];
    }
    return [self document:body];
}

- (void)testCachedStopsStayDeferredDuringDrawingAndCopying
{
    IJSVG* svg = [self repeatedGradientDocument];
    IJSVGGradient* gradient = (IJSVGGradient*)((IJSVGPaintNode*)svg.rootNode.children[2]).fill;
    Ivar childrenStorage = class_getInstanceVariable(IJSVGGroup.class, "_children");
    XCTAssertEqual([object_getIvar(gradient, childrenStorage) count], 0u);
    NSData* expected = [self pixels:svg];
    XCTAssertNotNil(expected);
    XCTAssertEqual([object_getIvar(gradient, childrenStorage) count], 0u);
    IJSVGGradient* copy = gradient.copy;
    XCTAssertEqual([object_getIvar(copy, childrenStorage) count], 0u);
    XCTAssertEqual(copy.children.count, 2u);
    XCTAssertEqual([object_getIvar(gradient, childrenStorage) count], 0u);
    IJSVGStop* copyFirst = (IJSVGStop*)copy.children.firstObject;
    IJSVGStop* copyLast = (IJSVGStop*)copy.children.lastObject;
    copyFirst.offset = [IJSVGUnitLength unitWithFloat:.4];
    copyLast.fillOpacity = [IJSVGUnitLength unitWithFloat:.2];
    XCTAssertEqual(((IJSVGStop*)gradient.children.firstObject).offset.value, 0);
    XCTAssertEqual(((IJSVGStop*)gradient.children.lastObject).fillOpacity.value, .5);
    XCTAssertEqual(copyFirst.parentNode, copy);
    XCTAssertEqual(gradient.children.firstObject.parentNode, gradient);
    XCTAssertEqualObjects([self pixels:svg], expected);
}

- (void)testDeferredStopsSupportTraversalMutationAndExport
{
    IJSVG* svg = [self repeatedGradientDocument];
    NSData* expected = [self pixels:svg];
    NSString* xml = [svg SVGStringWithSize:CGSizeMake(64, 64) options:IJSVGExporterOptionRemoveComments];
    IJSVG* restored = [[IJSVG alloc] initWithSVGString:xml];
    XCTAssertEqualObjects([self pixels:restored], expected);

    IJSVG* editable = [self repeatedGradientDocument];
    IJSVGGradient* gradient = (IJSVGGradient*)((IJSVGPaintNode*)editable.rootNode.children[2]).fill;
    XCTAssertFalse([gradient childrenMatchTraits:IJSVGNodeTraitPathed]);
    XCTAssertEqual([gradient childrenOfType:IJSVGNodeTypeStop].count, 2u);
    IJSVGGradient* untouched = (IJSVGGradient*)((IJSVGPaintNode*)editable.rootNode.children[3]).fill;
    IJSVGStop* added = [[IJSVGStop alloc] init];
    added.offset = [IJSVGUnitLength unitWithFloat:.7];
    [untouched addChild:added];
    XCTAssertEqual(untouched.children.count, 3u);
    XCTAssertEqual(untouched.children.lastObject, added);
    [untouched removeChild:untouched.children.firstObject];
    XCTAssertEqual(untouched.children.count, 2u);
    XCTAssertEqual(gradient.children.count, 2u);
    [untouched parseColorStops];
    [editable setNeedsDisplay];
    NSData* editedPixels = [self pixels:editable];
    NSString* editedXML = [editable SVGStringWithSize:CGSizeMake(64, 64) options:IJSVGExporterOptionRemoveComments];
    IJSVG* editedReload = [[IJSVG alloc] initWithSVGString:editedXML];
    XCTAssertEqualObjects([self pixels:editedReload], editedPixels);
}

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

- (void)testLateStyledStopDoesNotLeavePartialChildren
{
    for (NSString* type in @[ @"linearGradient", @"radialGradient" ]) {
        NSString* source = [NSString stringWithFormat:@"<defs><%@ id='paint'>"
                                                       "<stop offset='0' stop-color='red'/>"
                                                       "<stop offset='.5' stop-color='blue'/>"
                                                       "<stop offset='1' style='stop-color:green'/></%@></defs>"
                                                       "<rect width='64' height='64' fill='url(#paint)'/>",
            type, type];
        IJSVG* svg = [self document:source];
        IJSVGGradient* gradient = (IJSVGGradient*)((IJSVGPaintNode*)svg.rootNode.children.firstObject).fill;
        XCTAssertEqual(gradient.children.count, 3u);
        XCTAssertEqual(gradient.numberOfStops, 3u);
        XCTAssertTrue(CGColorEqualToColor((__bridge CGColorRef)gradient.colors.lastObject, [IJSVGColor colorFromString:@"green"]));
        for (IJSVGNode* stop in gradient.children) {
            XCTAssertEqual(stop.parentNode, gradient);
            XCTAssertEqual(stop.type, IJSVGNodeTypeStop);
        }
    }
}

- (void)testCachedStopValuesSurviveParserRelease
{
    IJSVGRootNode* root = nil;
    @autoreleasepool {
        NSString* source = @"<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64'>"
                            "<defs><linearGradient id='paint'>"
                            "<stop offset='25%' stop-color='#ff0000' stop-opacity='.5'/>"
                            "<stop offset='1' stop-color='#0000ff'/></linearGradient></defs>"
                            "<rect width='16' height='64' fill='url(#paint)'/>"
                            "<rect x='16' width='16' height='64' fill='url(#paint)'/>"
                            "<rect x='32' width='16' height='64' fill='url(#paint)'/>"
                            "<rect x='48' width='16' height='64' fill='url(#paint)'/></svg>";
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:source fileURL:nil error:nil];
        root = [parser rootNodeWithSize:CGSizeMake(64, 64)];
    }
    XCTAssertEqual(root.children.count, 4u);
    IJSVGGradient* first = (IJSVGGradient*)((IJSVGPaintNode*)root.children[2]).fill;
    IJSVGGradient* second = (IJSVGGradient*)((IJSVGPaintNode*)root.children[3]).fill;
    IJSVGStop* firstStop = (IJSVGStop*)first.children.firstObject;
    IJSVGStop* secondStop = (IJSVGStop*)second.children.firstObject;
    XCTAssertEqualWithAccuracy(secondStop.offset.value, .25, .0001);
    XCTAssertEqual(secondStop.offset.originalType, IJSVGUnitLengthTypePercentage);
    XCTAssertEqualWithAccuracy(secondStop.fillOpacity.value, .5, .0001);
    XCTAssertEqualWithAccuracy(CGColorGetAlpha(((IJSVGColorNode*)secondStop.fill).color), .5, .0001);
    firstStop.offset = [firstStop.offset lengthWithValue:.75];
    firstStop.fillOpacity = [firstStop.fillOpacity lengthWithValue:.8];
    ((IJSVGColorNode*)firstStop.fill).color = NSColor.greenColor.CGColor;
    XCTAssertEqualWithAccuracy(secondStop.offset.value, .25, .0001);
    XCTAssertEqualWithAccuracy(secondStop.fillOpacity.value, .5, .0001);
    XCTAssertEqualWithAccuracy(CGColorGetAlpha(((IJSVGColorNode*)secondStop.fill).color), .5, .0001);
    XCTAssertNotEqual(firstStop, secondStop);
    XCTAssertNotEqual(firstStop.fill, secondStop.fill);
    XCTAssertEqual(secondStop.parentNode, second);
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
    CGColorRef original = ((IJSVGColorNode*)secondStop.fill).color;
    ((IJSVGColorNode*)firstStop.fill).color = NSColor.greenColor.CGColor;
    first.locations[0] = .3;
    XCTAssertTrue(CGColorEqualToColor(((IJSVGColorNode*)secondStop.fill).color, original));
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
