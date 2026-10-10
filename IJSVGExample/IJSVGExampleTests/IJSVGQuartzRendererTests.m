//
//  IJSVGQuartzRendererTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>
#import <IJSVG/IJSVG.h>
#import <XCTest/XCTest.h>
#import "../../Framework/IJSVG/IJSVG/Source/Nodes/IJSVGSwitch.h"

@interface IJSVGQuartzRendererTests: XCTestCase
@end

@implementation IJSVGQuartzRendererTests

- (void)testParsedPointSubpathsIncludeDegenerateCommands
{
    NSDictionary<NSString*, NSNumber*>* cases = @{
        @"M8 8h16": @NO,
        @"M8 8h16z": @NO,
        @"M8 8q8 8 0 0": @NO,
        @"M8 8c8 8 8 8 0 0": @NO,
        @"M8 8a4 4 0 0 0 8 0": @NO,
        @"M8 8h0 M16 16h8": @YES,
        @"M8 8h16 M16 16z": @YES,
        @"M8 8q0 0 0 0": @YES,
        @"M8 8c0 0 0 0 0 0": @YES,
        @"M8 8h16 M16 16h0 M24 24h4": @YES
    };
    for(NSString* data in cases) {
        NSString* body = [NSString stringWithFormat:
            @"<svg xmlns='http://www.w3.org/2000/svg'><path d='%@'/><path d='%@'/></svg>", data, data];
        IJSVG* svg = [[IJSVG alloc] initWithSVGString:body];
        for(IJSVGPath* node in svg.rootNode.children) {
            XCTAssertEqual(node.hasPointSubpaths, cases[data].boolValue, @"%@", data);
        }
    }
}

- (void)testPointSubpathCacheFollowsMutableGeometry
{
    NSString* format = @"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><path d='%@' fill='none' stroke='red' stroke-width='4' stroke-linecap='square'/></svg>";
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:[NSString stringWithFormat:format, @"M8 8h0"]];
    IJSVGPath* node = (IJSVGPath*)svg.rootNode.children.firstObject;
    [self renderSVG:svg size:64];
    XCTAssertTrue(node.hasPointSubpaths);
    CGPathAddLineToPoint(node.path, NULL, 24.f, 8.f);
    [svg setNeedsDisplay];
    IJSVG* reference = [[IJSVG alloc] initWithSVGString:[NSString stringWithFormat:format, @"M8 8H24"]];
    XCTAssertEqualObjects([self renderSVG:svg size:64], [self renderSVG:reference size:64]);
    XCTAssertFalse(node.hasPointSubpaths);
    CGPathMoveToPoint(node.path, NULL, 16.f, 24.f);
    CGPathAddLineToPoint(node.path, NULL, 16.f, 24.f);
    [svg setNeedsDisplay];
    reference = [[IJSVG alloc] initWithSVGString:[NSString stringWithFormat:format, @"M8 8H24 M16 24h0"]];
    XCTAssertEqualObjects([self renderSVG:svg size:64], [self renderSVG:reference size:64]);
    XCTAssertTrue(node.hasPointSubpaths);
    IJSVGPath* copy = node.copy;
    XCTAssertTrue(copy.hasPointSubpaths);
    CGPathAddLineToPoint(copy.path, NULL, 24.f, 24.f);
    XCTAssertFalse(copy.hasPointSubpaths);
    XCTAssertTrue(node.hasPointSubpaths);
    node.path = copy.path;
    XCTAssertFalse(node.hasPointSubpaths);
}

- (void)testPointSubpathCapsMatchExplicitShapes
{
    for(NSString* data in @[@"M16 16h0", @"M16 16v0", @"M16 16z",
                            @"M16 16q0 0 0 0", @"M16 16c0 0 0 0 0 0"]) {
        for(NSString* cap in @[@"butt", @"round", @"square"]) {
            NSString* body = [NSString stringWithFormat:
                @"<path d='%@' fill='none' stroke='red' stroke-width='8' stroke-linecap='%@'/>",
                data, cap];
            NSString* reference = [cap isEqualToString:@"butt"] ? @"" :
                [cap isEqualToString:@"round"] ? @"<circle cx='16' cy='16' r='4' fill='red'/>" :
                @"<rect x='12' y='12' width='8' height='8' fill='red'/>";
            [self assertBody:body rendersLike:reference];
            [self assertVectorExportPreservesQuartzPixels:body optimized:YES];
        }
    }
    [self assertBody:@"<path d='M4 8h24 M16 24h0' stroke='red' stroke-width='8' stroke-linecap='square'/>"
        rendersLike:@"<path d='M4 8h24' stroke='red' stroke-width='8' stroke-linecap='square'/><rect x='12' y='20' width='8' height='8' fill='red'/>"];
}

- (void)testPointSubpathDashesAndPaintServers
{
    for(NSString* pattern in @[@"4 4", @"4"]) {
        for(NSNumber* offset in @[@0, @2, @6, @(-2)]) {
            NSString* body = [NSString stringWithFormat:
                @"<path d='M16 16h0' stroke='red' stroke-width='8' stroke-linecap='square' stroke-dasharray='%@' stroke-dashoffset='%@'/>",
                pattern, offset];
            BOOL visible = offset.integerValue == 0 || offset.integerValue == 2;
            [self assertBody:body rendersLike:visible ? @"<rect x='12' y='12' width='8' height='8' fill='red'/>" : @""];
        }
    }
    NSString* definitions = @"<defs><linearGradient id='g' gradientUnits='userSpaceOnUse' x1='12' x2='20'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs>";
    NSString* body = [definitions stringByAppendingString:
        @"<path d='M16 16h0' stroke='url(#g)' stroke-width='8' stroke-linecap='square'/>"];
    [self assertBody:body rendersLike:[definitions stringByAppendingString:
        @"<rect x='12' y='12' width='8' height='8' fill='url(#g)'/>"]];
    [self assertVectorExportPreservesQuartzPixels:body optimized:YES];
}

- (void)testAlphaMasksPreserveBlackContentAndOpacity
{
    for(NSString* attribute in @[@"mask-type='alpha'", @"style='mask-type:alpha'",
                                 @"mask-type='luminance' style='mask-type:alpha'"]) {
        NSString* body = [NSString stringWithFormat:
            @"<defs><mask id='m' %@><rect width='16' height='32' fill='black' fill-opacity='.5'/></mask></defs>"
             "<rect width='32' height='32' fill='red' mask='url(#m)'/>", attribute];
        [self assertBody:body rendersLike:@"<rect width='16' height='32' fill='red' fill-opacity='.5'/>"];
        [self assertVectorExportPreservesQuartzPixels:body optimized:YES];
        [self assertVectorExportPreservesQuartzPixels:body optimized:NO];
    }
    [self assertBody:@"<style>mask {mask-type:alpha}</style><defs><mask id='m'><rect width='16' height='32' fill='black'/></mask></defs><rect width='32' height='32' mask='url(#m)'/>"
        rendersLike:@"<rect width='16' height='32'/>"];
    [self assertBody:@"<defs><mask id='m' mask-type='luminance'><rect width='32' height='32' fill='black'/></mask></defs><rect width='32' height='32' mask='url(#m)'/>"
        rendersLike:@""];
}

- (void)testClipRuleOnUseMatchesEvenOddFill
{
    NSString* body = @"<defs><path id='p' d='M2 2H30V30H2Z M8 8H24V24H8Z'/><clipPath id='c'><use href='#p' clip-rule='evenodd'/></clipPath></defs><rect width='32' height='32' clip-path='url(#c)'/>";
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:[NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'>%@</svg>", body]];
    IJSVGNode* rect = svg.rootNode.children.lastObject;
    IJSVGGroup* clip = rect.clipPath;
    IJSVGGroup* use = (IJSVGGroup*)clip.children.firstObject;
    XCTAssertEqual(use.clipRule, IJSVGWindingRuleEvenOdd);
    XCTAssertEqual(use.children.firstObject.clipRule, IJSVGWindingRuleEvenOdd);
    [self assertBody:body rendersLike:@"<path d='M2 2H30V30H2Z M8 8H24V24H8Z' fill-rule='evenodd'/>"];
}

- (void)testVisibilityInheritanceAndOverrides
{
    [self assertBody:@"<g visibility='hidden'><rect width='32' height='32'/><rect width='16' height='16' visibility='visible'/></g>"
        rendersLike:@"<rect width='16' height='16'/>"];
    [self assertBody:@"<style>.hidden {visibility:hidden}</style><g class='hidden'><rect width='32' height='32'/><rect width='16' height='16' style='visibility:visible'/></g>"
        rendersLike:@"<rect width='16' height='16'/>"];
    [self assertBody:@"<g display='none'><rect width='32' height='32' visibility='visible'/></g>"
        rendersLike:@""];
    [self assertBody:@"<rect width='32' height='32' visibility='collapse'/>" rendersLike:@""];
    [self assertBody:@"<defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient><mask id='m' maskContentUnits='objectBoundingBox'><rect width='1' height='1' fill='url(#g)'/></mask></defs><g mask='url(#m)'><rect width='16' height='32' visibility='hidden'/><rect x='16' width='16' height='32'/></g>"
        rendersLike:@"<defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient><mask id='m' maskContentUnits='objectBoundingBox'><rect width='1' height='1' fill='url(#g)'/></mask></defs><g mask='url(#m)'><rect width='16' height='32' fill-opacity='0'/><rect x='16' width='16' height='32'/></g>"];
    [self assertBody:@"<text y='24' visibility='hidden' font-size='12'>A<tspan visibility='visible'>B</tspan></text>"
        rendersLike:@"<text y='24' font-size='12'><tspan fill-opacity='0'>A</tspan>B</text>"];
}

- (void)testVerticalTextLengthPercentageUsesViewportDiagonal
{
    [self assertBody:@"<svg width='32' height='16' viewBox='0 0 32 16'>"
                      "<text x='16' y='1' font-size='8' writing-mode='vertical-rl' textLength='50%' lengthAdjust='spacingAndGlyphs'>ABC</text></svg>"
        rendersLike:@"<svg width='32' height='16' viewBox='0 0 32 16'>"
                      "<text x='16' y='1' font-size='8' writing-mode='vertical-rl' textLength='12.649110640673518' lengthAdjust='spacingAndGlyphs'>ABC</text></svg>"];
}

- (void)testCurrentColorResolvesOnPaintedElement
{
    [self assertBody:@"<g color='red' fill='currentColor'><rect width='16' height='32'/><rect x='16' width='16' height='32' color='blue'/></g>"
        rendersLike:@"<rect width='16' height='32' fill='red'/><rect x='16' width='16' height='32' fill='blue'/>"];
    [self assertBody:@"<style>g {color:green;stroke:currentColor} .blue {color:blue}</style><g><path d='M2 8H30' stroke-width='4'/><path class='blue' d='M2 24H30' stroke-width='4'/></g>"
        rendersLike:@"<path d='M2 8H30' stroke='green' stroke-width='4'/><path d='M2 24H30' stroke='blue' stroke-width='4'/>"];
    [self assertBody:@"<text y='24' color='red' fill='currentColor' font-size='12'>A<tspan color='blue'>B</tspan></text>"
        rendersLike:@"<text y='24' fill='red' font-size='12'>A<tspan fill='blue'>B</tspan></text>"];
    [self assertBody:@"<defs><linearGradient id='g' color='red'><stop stop-color='currentColor'/><stop offset='1' color='blue' stop-color='currentColor'/></linearGradient></defs><rect width='32' height='32' fill='url(#g)'/>"
        rendersLike:@"<defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect width='32' height='32' fill='url(#g)'/>"];
    [self assertBody:@"<g color='red'><rect width='32' height='32' fill='currentColor' color='transparent'/></g>"
        rendersLike:@""];
    [self assertBody:@"<g color='red'><rect width='32' height='32' fill='currentColor' color='initial'/></g>"
        rendersLike:@"<rect width='32' height='32'/>"];
    [self assertBody:@"<defs><path id='p' d='M2 2H30V30H2Z' fill='currentColor'/></defs><use href='#p' color='blue'/>"
        rendersLike:@"<path d='M2 2H30V30H2Z' fill='blue'/>"];
}

- (void)testCurrentColorInMarkerContextPaint
{
    NSString* definitions = @"<defs><marker id='m' markerWidth='6' markerHeight='6' refX='3' refY='3' markerUnits='userSpaceOnUse'><circle cx='3' cy='3' r='3' fill='context-stroke'/></marker></defs>";
    [self assertBody:[definitions stringByAppendingString:@"<path d='M4 16H28' color='red' stroke='currentColor' marker-end='url(#m)'/>"]
        rendersLike:[definitions stringByAppendingString:@"<path d='M4 16H28' stroke='red' marker-end='url(#m)'/>"]];
}

- (void)testTransformOriginAndReferenceBoxes
{
    NSArray* cases = @[
        @[@"transform-origin='center'", @"16 16"],
        @[@"transform-origin='25% 75%'", @"8 24"],
        @[@"transform-origin='right top'", @"32 0"],
        @[@"transform-origin='top right'", @"32 0"],
        @[@"transform-origin='-2 3'", @"-2 3"],
        @[@"transform-origin='1em .5em' font-size='8'", @"8 4"],
        @[@"style='transform-origin:center;transform-box:fill-box'", @"12 10"],
        @[@"style='transform-origin:100% 0;transform-box:fill-box'", @"20 4"],
        @[@"transform-origin='0 0' style='transform-origin:center!important;transform-origin:bogus'", @"16 16"],
        @[@"style='transform-origin:center;transform-box:fill-box;transform-box:bogus'", @"12 10"]
    ];
    for(NSArray* item in cases) {
        [self assertBody:[NSString stringWithFormat:
            @"<rect x='4' y='4' width='16' height='12' transform='rotate(90)' %@/>", item[0]]
            rendersLike:[NSString stringWithFormat:
            @"<rect x='4' y='4' width='16' height='12' transform='rotate(90 %@)'/>", item[1]]];
    }
    [self assertBody:@"<svg width='16' height='24' viewBox='0 0 8 12'>"
                      "<rect width='6' height='4' transform='rotate(90)' transform-origin='center'/></svg>"
        rendersLike:@"<svg width='16' height='24' viewBox='0 0 8 12'>"
                      "<rect width='6' height='4' transform='rotate(90 4 6)'/></svg>"];
    [self assertBody:@"<g transform='rotate(90)' style='transform-origin:center;transform-box:fill-box'>"
                      "<rect x='4' y='4' width='16' height='12'/></g>"
        rendersLike:@"<g transform='rotate(90 12 10)'><rect x='4' y='4' width='16' height='12'/></g>"];
    [self assertBody:@"<rect x='4' y='4' width='16' height='12' stroke='red' stroke-width='2'"
                      " transform='rotate(90)' style='transform-origin:0 0;transform-box:stroke-box'/>"
        rendersLike:@"<rect x='4' y='4' width='16' height='12' stroke='red' stroke-width='2' transform='rotate(90 3 3)'/>"];
    [self assertBody:@"<text x='4' y='12' font-size='8' transform='rotate(90)' transform-origin='center'>Hi</text>"
        rendersLike:@"<text x='4' y='12' font-size='8' transform='rotate(90 16 16)'>Hi</text>"];
    [self assertBody:@"<defs><rect id='r' width='8' height='4'/></defs>"
                      "<use href='#r' x='4' y='6' transform='rotate(90)' transform-origin='center'/>"
        rendersLike:@"<defs><rect id='r' width='8' height='4'/></defs>"
                      "<use href='#r' x='4' y='6' transform='rotate(90 16 16)'/>"];
}

- (void)testGradientSpreadExportAndReferences
{
    for(NSString* tag in @[@"linearGradient", @"radialGradient"]) {
        for(NSString* method in @[@"pad", @"repeat", @"reflect"]) {
            NSString* body = [NSString stringWithFormat:
                @"<defs><%@ id='base' x1='.25' x2='.5' r='.2' spreadMethod='%@'>"
                 "<stop stop-color='red'/><stop offset='1' stop-color='blue'/></%@>"
                 "<%@ id='g' href='#base'/></defs><rect width='32' height='32' fill='url(#g)'/>",
                tag, method, tag, tag];
            NSString* reference = [NSString stringWithFormat:
                @"<defs><%@ id='g' x1='.25' x2='.5' r='.2' spreadMethod='%@'>"
                 "<stop stop-color='red'/><stop offset='1' stop-color='blue'/></%@></defs>"
                 "<rect width='32' height='32' fill='url(#g)'/>", tag, method, tag];
            [self assertBody:body rendersLike:reference];
            IJSVG* svg = [self svgWithBody:body];
            NSData* expected = [self renderSVG:svg size:128];
            for(NSNumber* options in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionAll)]) {
                NSString* xml = [svg SVGStringWithSize:CGSizeMake(32, 32) options:options.unsignedIntegerValue];
                XCTAssertEqualObjects(expected, [self renderSVG:[[IJSVG alloc] initWithSVGString:xml] size:128]);
            }
        }
    }
}

- (void)testNestedViewportOverflowSurvivesExport
{
    for(NSString* overflow in @[@"hidden", @"visible", @"scroll", @"auto"]) {
        for(NSString* mapping in @[@"", @"viewBox='4 4 8 16' preserveAspectRatio='xMaxYMin slice'"]) {
            NSString* body = [NSString stringWithFormat:
                @"<svg x='8' y='8' width='16' height='16' overflow='%@' %@>"
                 "<rect x='-4' y='-4' width='32' height='32' fill='red'/></svg>", overflow, mapping];
            [self assertVectorExportPreservesQuartzPixels:body optimized:NO];
            [self assertVectorExportPreservesQuartzPixels:body optimized:YES];
        }
    }
}

- (void)testNestedSVGDefaultsToContainingViewport
{
    [self assertBody:@"<svg x='16' width='16' viewBox='0 0 8 8'><circle cx='4' cy='4' r='4'/></svg>"
        rendersLike:@"<svg x='16' width='16' height='32' viewBox='0 0 8 8'><circle cx='4' cy='4' r='4'/></svg>"];
    [self assertBody:@"<svg height='16' viewBox='0 0 8 8'><circle cx='4' cy='4' r='4'/></svg>"
        rendersLike:@"<svg width='32' height='16' viewBox='0 0 8 8'><circle cx='4' cy='4' r='4'/></svg>"];
    [self assertBody:@"<svg width='16'><rect width='8' height='8'/></svg>"
        rendersLike:@"<rect width='8' height='8'/>"];
    [self assertBody:@"<svg style='width:auto;height:auto' viewBox='0 0 8 8'><circle cx='4' cy='4' r='4'/></svg>"
        rendersLike:@"<circle cx='16' cy='16' r='16'/>"];
    [self assertBody:@"<svg width='0' viewBox='0 0 8 8'><rect width='8' height='8'/></svg>"
        rendersLike:@""];
}

- (void)testSwitchNodeSelectsLanguagesAndCopies
{
    NSString* xml = @"<switch><!-- comment --><style>rect {fill:red}</style>"
                    "<rect id='extension' requiredExtensions='urn:unsupported'/>"
                    "<rect id='regional' systemLanguage='de, EN-gb'/>"
                    "<rect id='english' systemLanguage='en' display='none'/>"
                    "<rect id='fallback'/></switch>";
    NSXMLElement* element = [[NSXMLElement alloc] initWithXMLString:xml error:nil];
    NSArray* cases = @[
        @[@[@"en-GB"], @"regional"],
        @[@[@"en-GB-x-private"], @"regional"],
        @[@[@"en-US"], @"english"],
        @[@[@"en"], @"english"],
        @[@[@"eng"], @"fallback"],
        @[@[@"fr", @"DE"], @"regional"],
        @[@[], @"fallback"]
    ];
    for(NSArray* item in cases) {
        NSXMLElement* selected = [IJSVGSwitch selectedChildInElement:element preferredLanguages:item[0]];
        XCTAssertEqualObjects([selected attributeForName:IJSVGAttributeID].stringValue, item[1]);
    }
    NSXMLElement* noMatch = [[NSXMLElement alloc] initWithXMLString:
        @"<switch><rect systemLanguage=' , '/><rect requiredExtensions=''/></switch>" error:nil];
    XCTAssertNil([IJSVGSwitch selectedChildInElement:noMatch preferredLanguages:@[@"en-GB"]]);
    IJSVG* svg = [self svgWithBody:@"<switch><rect width='8' height='8'/><circle r='4'/></switch>"];
    IJSVGSwitch* node = (IJSVGSwitch*)svg.rootNode.children.firstObject;
    XCTAssertTrue([node isKindOfClass:IJSVGSwitch.class]);
    IJSVGSwitch* copy = node.copy;
    XCTAssertTrue([copy isKindOfClass:IJSVGSwitch.class]);
    XCTAssertEqual(copy.type, IJSVGNodeTypeSwitch);
    XCTAssertEqual(copy.children.count, 1);
    XCTAssertEqual(copy.children.firstObject.parentNode, copy);
    XCTAssertEqual(node.children.firstObject.parentNode, node);
}

- (void)testSwitchSelectsFirstMatchingChild
{
    [self assertBody:@"<switch><rect width='16' height='16' fill='red'/><rect width='32' height='32' fill='blue'/></switch>"
        rendersLike:@"<rect width='16' height='16' fill='red'/>"];
    [self assertBody:@"<switch><rect requiredExtensions='https://example.org/extension' width='32' height='32'/><rect systemLanguage='zz-ZZ' width='32' height='32'/><rect width='16' height='16'/></switch>"
        rendersLike:@"<rect width='16' height='16'/>"];
    [self assertBody:@"<switch><rect display='none' width='16' height='16'/><rect width='32' height='32'/></switch>"
        rendersLike:@""];
    [self assertBody:@"<switch><rect systemLanguage='' width='32' height='32'/><rect requiredExtensions='' width='32' height='32'/></switch>"
        rendersLike:@""];
    NSString* preferred = NSLocale.preferredLanguages.firstObject;
    if(preferred.length != 0) {
        NSString* body = [NSString stringWithFormat:
            @"<switch><rect systemLanguage='zz-ZZ, %@' width='16' height='16'/><rect width='32' height='32'/></switch>",
            preferred.uppercaseString];
        [self assertBody:body rendersLike:@"<rect width='16' height='16'/>"];
    }
}

- (void)testCSSGeometryParsingPerformance
{
    NSMutableString* source = [NSMutableString stringWithString:@"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><style>.a {cx:16px;cy:16px;r:8px} .b {x:2px;y:4px;width:20px;height:18px;rx:2px;ry:3px}</style>"];
    for(NSUInteger index = 0; index < 100; index++) {
        [source appendString:@"<circle class='a'/><rect class='b' style='width:1em;height:50%'/>"];
    }
    [source appendString:@"</svg>"];
    [self measureBlock:^{
        for(NSUInteger index = 0; index < 100; index++) {
            @autoreleasepool {
                IJSVG* svg = [[IJSVG alloc] initWithSVGString:source];
                XCTAssertNotNil(svg);
            }
        }
    }];
}

- (void)testCSSGeometryOverridesPresentationAttributes
{
    [self assertBody:@"<style>.box { x:4px; y:6px; width:20px; height:18px; rx:3px; ry:4px; }</style>"
                      "<rect class='box' x='1' y='1' width='2' height='2' rx='1' ry='1'/>"
        rendersLike:@"<rect x='4' y='6' width='20' height='18' rx='3' ry='4'/>"];
    [self assertBody:@"<style>circle {cx:16px;cy:17px;r:8px} ellipse {cx:16px;cy:16px;rx:9px;ry:6px}</style>"
                      "<circle cx='1' cy='1' r='1'/><ellipse cx='1' cy='1' rx='1' ry='1' fill='red'/>"
        rendersLike:@"<circle cx='16' cy='17' r='8'/><ellipse cx='16' cy='16' rx='9' ry='6' fill='red'/>"];
    [self assertBody:@"<style>#a {width:20px!important} .a {width:5px;height:12px} rect {width:2px}</style>"
                      "<rect id='a' class='a' width='1' height='1' style='width:10px;x:3px;y:4px'/>"
        rendersLike:@"<rect x='3' y='4' width='20' height='12'/>"];
}

- (void)testCSSGeometryKeywordsAndInheritance
{
    [self assertBody:@"<style>.a {r:1em;cx:16px;cy:16px}</style>"
                      "<g class='a' font-size='4'><circle class='a' font-size='8'/></g>"
        rendersLike:@"<circle r='8' cx='16' cy='16'/>"];
    [self assertBody:@"<g style='r:1em;cx:50%;cy:50%' font-size='4'>"
                      "<circle style='r:inherit;cx:inherit;cy:inherit' font-size='12'/></g>"
        rendersLike:@"<circle r='4' cx='16' cy='16'/>"];
    [self assertBody:@"<g style='r:8px;cx:16px;cy:16px'><circle/></g>" rendersLike:@""];
    for(NSString* keyword in @[@"initial", @"unset", @"revert", @"revert-layer"]) {
        [self assertBody:[NSString stringWithFormat:@"<circle r='8' cx='16' cy='16' style='r:%@'/>", keyword]
            rendersLike:@""];
    }
    [self assertBody:@"<rect x='3' y='4' width='20' height='20' rx='8' ry='4' style='rx:auto'/>"
        rendersLike:@"<rect x='3' y='4' width='20' height='20' rx='4' ry='4'/>"];
}

- (void)testInlineStylesPreserveImportantValuesAndCachedRules
{
    [self assertBody:@"<style>.a {width:10px!important;height:8px;fill:red!important;stroke:blue;stroke-width:1px}</style>"
                      "<rect class='a' style='width:2px;height:6px;fill:green;stroke:none'/>"
                      "<rect class='a' y='10' style='width:20px!important;height:6px;fill:green!important;stroke:none'/>"
                      "<rect class='a' y='20' style='width:bad!important;height:6px;stroke:none'/>"
        rendersLike:@"<rect width='10' height='6' fill='red'/>"
                      "<rect y='10' width='20' height='6' fill='green'/>"
                      "<rect y='20' width='10' height='6' fill='red'/>"];
}

- (void)testCSSGeometryUnitsAndInvalidDeclarations
{
    [self assertBody:@"<rect style='x:-.5em;y:25%;width:1in;height:.5em' font-size='16'/>"
        rendersLike:@"<rect x='-8' y='8' width='96' height='8'/>"];
    [self assertBody:@"<circle style='cx:16px;cy:16px;r:4px;r:banana;r:-1px;r:2px 3px'/>"
        rendersLike:@"<circle cx='16' cy='16' r='4'/>"];
    [self assertBody:@"<style>rect { width:20px;height:10px } #a {width:invalid!important}</style>"
                      "<rect id='a' style='width:8px;width:invalid'/>"
        rendersLike:@"<rect width='8' height='10'/>"];
    CGFloat radius = hypot(32.f, 16.f) / M_SQRT2 * .25;
    [self assertBody:@"<svg width='32' height='16'><circle style='cx:50%;cy:50%;r:25%'/></svg>"
        rendersLike:[NSString stringWithFormat:@"<svg width='32' height='16'><circle cx='16' cy='8' r='%.12g'/></svg>", radius]];
}

- (void)testCSSGeometryWithTransformsClipsAndMasks
{
    [self assertBody:@"<defs><clipPath id='c'><circle style='cx:16px;cy:16px;r:10px'/></clipPath>"
                      "<mask id='m'><rect style='x:0;y:0;width:100%;height:50%' fill='white'/></mask></defs>"
                      "<g transform='translate(2 1)' clip-path='url(#c)' mask='url(#m)'>"
                      "<rect style='x:3px;y:4px;width:25px;height:24px;rx:3px' transform='rotate(10 16 16)'/></g>"
        rendersLike:@"<defs><clipPath id='c'><circle cx='16' cy='16' r='10'/></clipPath>"
                      "<mask id='m'><rect x='0' y='0' width='100%' height='50%' fill='white'/></mask></defs>"
                      "<g transform='translate(2 1)' clip-path='url(#c)' mask='url(#m)'>"
                      "<rect x='3' y='4' width='25' height='24' rx='3' transform='rotate(10 16 16)'/></g>"];
    [self assertBody:@"<defs><clipPath id='c' clipPathUnits='objectBoundingBox'>"
                      "<circle style='cx:50%;cy:50%;r:50%'/></clipPath></defs>"
                      "<rect width='32' height='16' clip-path='url(#c)'/>"
        rendersLike:@"<defs><clipPath id='c' clipPathUnits='objectBoundingBox'>"
                      "<circle cx='50%' cy='50%' r='50%'/></clipPath></defs>"
                      "<rect width='32' height='16' clip-path='url(#c)'/>"];
}

- (void)testCSSGeometryOnNestedViewportsAndUses
{
    [self assertBody:@"<svg x='0' y='0' width='32' height='32' style='x:4px;y:6px;width:20px;height:16px' viewBox='0 0 10 8'>"
                      "<rect style='width:100%;height:100%'/></svg>"
        rendersLike:@"<rect x='4' y='6' width='20' height='16'/>"];
    [self assertBody:@"<defs><symbol id='s' viewBox='0 0 10 10'><circle style='cx:5px;cy:5px;r:5px'/></symbol></defs>"
                      "<use href='#s' style='x:4px;y:6px;width:20px;height:20px'/>"
        rendersLike:@"<circle cx='14' cy='16' r='10'/>"];
}

- (void)assertBody:(NSString*)body rendersLike:(NSString*)reference
{
    IJSVG* svg = [self svgWithBody:body];
    IJSVG* expected = [self svgWithBody:reference];
    XCTAssertEqualObjects([self renderSVG:svg size:128], [self renderSVG:expected size:128], @"%@", body);
    for(NSNumber* options in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionAll)]) {
        NSString* actualXML = [svg SVGStringWithSize:CGSizeMake(32, 32) options:options.unsignedIntegerValue];
        NSString* expectedXML = [expected SVGStringWithSize:CGSizeMake(32, 32) options:options.unsignedIntegerValue];
        XCTAssertEqualObjects([self renderSVG:[[IJSVG alloc] initWithSVGString:actualXML] size:128],
                              [self renderSVG:[[IJSVG alloc] initWithSVGString:expectedXML] size:128], @"%@", body);
    }
}

- (void)testAutomaticRadii
{
    for(NSString* element in @[@"ellipse cx='16' cy='16'", @"rect x='2' y='2' width='28' height='28'"]) {
        for(NSString* radii in @[@"rx='8'", @"ry='8'", @"rx='auto' ry='8'", @"rx='8' ry='auto'",
                                @"rx='25%'", @"ry='25%'", @"rx='.5em'", @"ry='.5em'"]) {
            [self assertBody:[NSString stringWithFormat:@"<%@ %@/>", element, radii]
                rendersLike:[NSString stringWithFormat:@"<%@ rx='8' ry='8'/>", element]];
        }
    }
    [self assertBody:@"<svg width='32' height='16'><ellipse cx='16' cy='8' ry='25%'/></svg>"
        rendersLike:@"<svg width='32' height='16'><ellipse cx='16' cy='8' rx='4' ry='4'/></svg>"];
    [self assertBody:@"<ellipse cx='16' cy='16' rx='0' ry='8'/>" rendersLike:@""];
    [self assertBody:@"<ellipse cx='16' cy='16'/>" rendersLike:@""];
}

- (void)testAutomaticImageDimensions
{
    NSString* image = @"<image x='2' y='3' href='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII=' %@/>";
    NSArray* cases = @[@[@"", @"width='2' height='1'"],
                       @[@"width='auto' height='auto'", @"width='2' height='1'"],
                       @[@"width='16'", @"width='16' height='8'"],
                       @[@"height='8'", @"width='16' height='8'"],
                       @[@"width='auto' height='25%'", @"width='16' height='8'"],
                       @[@"width='1em' height='auto'", @"width='16' height='8'"],
                       @[@"width='0' height='8'", @"width='0' height='8'"],
                       @[@"width='16' height='0'", @"width='16' height='0'"]];
    for(NSArray* pair in cases) {
        [self assertBody:[NSString stringWithFormat:image, pair[0]]
            rendersLike:[NSString stringWithFormat:image, pair[1]]];
    }
    [self assertBody:[NSString stringWithFormat:image, @"width='0'"] rendersLike:@""];
    [self assertBody:[NSString stringWithFormat:image, @"height='0'"] rendersLike:@""];
}

- (void)testPathLengthDashCalibration
{
    for(NSString* shape in @[@"path d='M2 16H30'", @"line x1='2' y1='16' x2='30' y2='16'",
                             @"polyline points='2,16 30,16'", @"polygon points='2,2 9,2 9,9 2,9'",
                             @"rect x='2' y='2' width='7' height='7'"]) {
        for(NSString* transform in @[@"", @"transform='translate(1 2) scale(.8)'",
                                     @"transform='scale(.8)' vector-effect='non-scaling-stroke'"]) {
            NSString* format = @"<%@ %@ fill='none' stroke='red' stroke-width='2' %@/>";
            [self assertBody:[NSString stringWithFormat:format, shape, transform,
                              @"pathLength='14' stroke-dasharray='2 1' stroke-dashoffset='-1'"]
                rendersLike:[NSString stringWithFormat:format, shape, transform,
                              @"stroke-dasharray='4 2' stroke-dashoffset='-2'"]];
            [self assertBody:[NSString stringWithFormat:format, shape, transform,
                              @"pathLength='14' stroke-dasharray='2 10%' stroke-dashoffset='5%'"]
                rendersLike:[NSString stringWithFormat:format, shape, transform,
                              @"stroke-dasharray='4 10%' stroke-dashoffset='5%'"]];
        }
    }
    for(NSString* invalid in @[@"-1", @"-1e-999", @"1px", @"1 2", @"nan", @"1e999"]) {
        [self assertBody:[NSString stringWithFormat:@"<path d='M2 16H30' pathLength='%@' stroke='red' stroke-dasharray='4 2'/>", invalid]
            rendersLike:@"<path d='M2 16H30' stroke='red' stroke-dasharray='4 2'/>"];
    }
}

- (void)testZeroPathLengthRenderingAndExport
{
    [self assertBody:@"<path d='M2 16H30' stroke='red' pathLength='0' stroke-dasharray='1 1'/>"
        rendersLike:@"<path d='M2 16H30' stroke='red'/>"];
    [self assertBody:@"<path d='M2 16H30' stroke='red' pathLength='0' stroke-dasharray='0 1'/>"
        rendersLike:@""];
    [self assertBody:@"<path d='M2 16H30' stroke='red' pathLength='0' stroke-dasharray='1 1' stroke-dashoffset='1'/>"
        rendersLike:@""];
    [self assertBody:@"<path d='M2 16H30' stroke='red' pathLength='0' stroke-dasharray='10% 5%'/>"
        rendersLike:@"<path d='M2 16H30' stroke='red' stroke-dasharray='10% 5%'/>"];
}

- (void)testPathLengthWithInheritedUnitsAndUse
{
    [self assertBody:@"<defs><path id='p' d='M2 16H30' pathLength='14'/></defs>"
                      "<g font-size='2' stroke='red' stroke-dasharray='1em .5em' stroke-dashoffset='.5em'>"
                      "<use href='#p'/></g>"
        rendersLike:@"<path d='M2 16H30' stroke='red' stroke-dasharray='4 2' stroke-dashoffset='2'/>"];
    [self assertBody:@"<g pathLength='14'><path d='M2 16H30' stroke='red' stroke-dasharray='2 1'/></g>"
        rendersLike:@"<path d='M2 16H30' stroke='red' stroke-dasharray='2 1'/>"];
    NSString* defs = @"<defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient>"
                      "<clipPath id='c'><rect x='4' y='4' width='24' height='24'/></clipPath></defs>";
    [self assertBody:[defs stringByAppendingString:@"<path d='M2 16H30' stroke='url(#g)' stroke-width='4' clip-path='url(#c)' pathLength='14' stroke-dasharray='2 1'/>"]
        rendersLike:[defs stringByAppendingString:@"<path d='M2 16H30' stroke='url(#g)' stroke-width='4' clip-path='url(#c)' stroke-dasharray='4 2'/>"]];
    [self assertBody:@"<path d='M2 16H30' stroke='red' pathLength='1e-320' stroke-dasharray='1 1'/>"
        rendersLike:@"<path d='M2 16H30' stroke='red'/>"];
}

- (IJSVG*)svgWithBody:(NSString*)body
{
    NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' "
                                                "height='32' viewBox='0 0 32 32'>%@</svg>",
                                               body];
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml];
    XCTAssertNotNil(svg);
    return svg;
}

- (NSData*)renderSVG:(IJSVG*)svg
                size:(NSUInteger)size
         drawingRect:(CGRect)drawingRect
{
    XCTAssertNotNil(svg);
    if(svg == nil) return nil;

    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    XCTAssertTrue(space != NULL);
    if(space == NULL) return nil;

    CGContextRef context = CGBitmapContextCreate(NULL, size, size, 8, size * 4,
                                                 space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) return nil;

    CGContextTranslateCTM(context, 0.f, size);
    CGContextScaleCTM(context, 1.f, -1.f);
    [svg drawInRect:drawingRect
            context:context];

    const void* bytes = CGBitmapContextGetData(context);
    XCTAssertTrue(bytes != NULL);
    NSData* pixels = bytes == NULL ? nil : [NSData dataWithBytes:bytes
                                                          length:size * size * 4];
    CGContextRelease(context);
    return pixels;
}

- (NSData*)renderSVG:(IJSVG*)svg
                size:(NSUInteger)size
{
    return [self renderSVG:svg
                      size:size
               drawingRect:CGRectMake(0.f, 0.f, size,
                                                                size)];
}

- (NSData*)renderBody:(NSString*)body
                 size:(NSUInteger)size
{
    return [self renderSVG:[self svgWithBody:body]
                      size:size];
}

// Checks backdrop rendering at several backing scales.
- (void)testBackdropSurfacePreservesDevicePixelEdges
{
    NSMutableString* body = [NSMutableString stringWithString:@"<defs><filter id='f'><feComposite "
                                                               "in='SourceGraphic' in2='BackgroundImage' "
                                                               "operator='arithmetic' k2='1'/></filter>"
                                                               "</defs><rect width='32' height='32' "
                                                               "fill='white'/>" ];
    for(NSUInteger x = 0; x < 32; x++) {
        [body appendFormat:@"<rect x='%lu' width='.5' height='24' fill='black'/>",
                           (unsigned long)x];
    }
    // This isolated shape enables backdrop rendering without changing the stripes.
    [body appendString:@"<rect x='2' y='28' width='4' height='2' fill='red' filter='url(#f)'/>"];
    for(NSNumber* scaleValue in @[@1, @2, @3]) {
        CGFloat scale = scaleValue.doubleValue;
        NSUInteger size = 32 * scale;
        NSMutableArray<NSData*>* images = [NSMutableArray array];
        for(NSNumber* enabled in @[@YES, @NO]) {
            IJSVG* svg = [self svgWithBody:body];
            IJSVGRenderingOptions* options = svg.renderingOptions;
            options.filtersEnabled = enabled.boolValue;
            svg.renderingOptions = options;
            svg.renderingBackingScaleHelper = ^CGFloat { return scale; };
            CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            CGContextRef bitmap = CGBitmapContextCreate(NULL, size, size, 8,
                                                        size * 4, space,
                                                        (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
            CGColorSpaceRelease(space);
            XCTAssertTrue(bitmap != NULL);
            if(bitmap == NULL) {
                return;
            }
            CGContextScaleCTM(bitmap, scale, scale);
            [svg drawInRect:CGRectMake(0, 0, 32, 32)
                    context:bitmap];
            [images addObject:[NSData dataWithBytes:CGBitmapContextGetData(bitmap)
                                             length:size * size * 4]];
            CGContextRelease(bitmap);
        }
        const uint8_t* actual = images[0].bytes;
        const uint8_t* expected = images[1].bytes;
        for(NSUInteger x = 0; x < size; x++) {
            NSUInteger offset = (size / 2 * size + x) * 4;
            for(NSUInteger channel = 0; channel < 4; channel++) {
                XCTAssertEqual(actual[offset + channel],
                               expected[offset + channel],
                               @"scale=%@ x=%lu channel=%lu", scaleValue,
                               (unsigned long)x, (unsigned long)channel);
            }
        }
    }
}

- (void)testOverlappingChildrenReceiveGroupOpacityOnce
{
    NSData* data = [self renderBody:@"<g opacity='0.5'><rect x='2' y='2' width='20' height='20' "
                                     "fill='red'/><rect x='10' y='10' width='20' height='20' "
                                     "fill='blue'/></g>"
                               size:32];
    if(data == nil) return;
    const uint8_t* pixels = data.bytes;
    XCTAssertEqualWithAccuracy(pixels[(5 * 32 + 5) * 4 + 3], 128, 1);
    XCTAssertEqualWithAccuracy(pixels[(15 * 32 + 15) * 4 + 3], 128, 1);
    XCTAssertEqual(pixels[(15 * 32 + 15) * 4], 0);
    XCTAssertEqualWithAccuracy(pixels[(15 * 32 + 15) * 4 + 2], 128, 1);
}

- (void)testTransformedClipRestrictsPaint
{
    NSData* data = [self renderBody:@"<defs><clipPath id='c'><rect width='8' height='8'/></clipPath>"
                                     "</defs><g transform='translate(8 8)'><rect width='20' height='20' "
                                     "fill='red' clip-path='url(#c)'/></g>"
                               size:32];
    if(data == nil) return;
    const uint8_t* pixels = data.bytes;
    XCTAssertEqual(pixels[(10 * 32 + 10) * 4], 255);
    XCTAssertEqual(pixels[(20 * 32 + 20) * 4 + 3], 0);
    XCTAssertEqual(pixels[(4 * 32 + 4) * 4 + 3], 0);
}

- (void)testDrawingRespectsDestinationOrigin
{
    IJSVG* svg = [self svgWithBody:@"<rect width='32' height='32' fill='red'/>"];
    NSData* data = [self renderSVG:svg
                              size:32
                       drawingRect:CGRectMake(8.f, 8.f,
                                                                      16.f,
                                                                      16.f)];
    if(data == nil) return;
    const uint8_t* pixels = data.bytes;
    XCTAssertEqual(pixels[(4 * 32 + 4) * 4 + 3], 0);
    XCTAssertEqual(pixels[(10 * 32 + 10) * 4], 255);
    XCTAssertEqual(pixels[(26 * 32 + 26) * 4 + 3], 0);
}

- (void)testPatternRepeatsInSVGCoordinates
{
    NSData* data = [self renderBody:@"<defs><pattern id='p' width='8' height='8' "
                                     "patternUnits='userSpaceOnUse'><rect width='4' height='8' "
                                     "fill='red'/><rect x='4' width='4' height='8' fill='blue'/>"
                                     "</pattern></defs><rect width='32' height='32' fill='url(#p)'/>"
                               size:32];
    if(data == nil) return;
    const uint8_t* pixels = data.bytes;
    for(NSUInteger x = 2; x <= 26; x += 8) {
        XCTAssertEqual(pixels[(12 * 32 + x) * 4], 255);
        XCTAssertEqual(pixels[(12 * 32 + x + 4) * 4 + 2], 255);
    }
}

- (void)testDefaultFontSizeResolvesTextAndRelativeGeometry
{
    NSArray<NSString*>* bodies = @[
        @"<text x='1' y='26'>A</text>",
        @"<text x='1' y='26' font-size='50%'>A</text>",
        @"<text x='1' y='26' font-size='.5em'>A</text>",
        @"<text x='1' y='26' font-size='1ex'>A</text>",
        (@"<symbol id='s' viewBox='0 0 2 2'><rect width='2' height='2'/></symbol>"
          "<use href='#s' x='.25em' y='.25ex' width='.5em' height='1ex'/>"),
        (@"<symbol id='s' width='.5em' height='1ex' viewBox='0 0 2 2'>"
          "<rect width='2' height='2'/></symbol><use href='#s'/>")
    ];
    for(NSString* body in bodies) {
        IJSVG* svg = [self svgWithBody:body];
        IJSVGRenderingOptions* options = svg.renderingOptions;
        options.defaultFontSize = 24;
        svg.renderingOptions = options;
        NSString* reference = [NSString stringWithFormat:@"<g font-size='24'>%@</g>", body];
        XCTAssertEqualObjects([self renderSVG:svg size:64], [self renderBody:reference size:64], @"%@", body);
    }
    NSDictionary<NSString*, NSNumber*>* sizes = @{
        @"initial": @24, @"medium": @24, @"small": @19.5, @"large": @27,
        @"12": @12, @"50%": @5, @"inherit": @10
    };
    for(NSString* size in sizes) {
        NSString* body = [NSString stringWithFormat:
            @"<g font-size='10'><text x='1' y='28' font-size='%@'>A</text></g>", size];
        IJSVG* svg = [self svgWithBody:body];
        IJSVGRenderingOptions* options = svg.renderingOptions;
        options.defaultFontSize = 24;
        svg.renderingOptions = options;
        NSString* reference = [NSString stringWithFormat:
            @"<text x='1' y='28' font-size='%@'>A</text>", sizes[size]];
        XCTAssertEqualObjects([self renderSVG:svg size:64], [self renderBody:reference size:64], @"%@", size);
    }
}

- (void)testDefaultFontSizeChangesInvalidateRenderingAndMeasurement
{
    NSString* body = @"<symbol id='s' viewBox='0 0 1 1'><rect width='1' height='1'/></symbol>"
                      "<use href='#s' width='1em' height='1em'/>";
    IJSVG* svg = [self svgWithBody:body];
    for(NSNumber* size in @[@16, @24, @8, @16]) {
        IJSVGRenderingOptions* options = svg.renderingOptions;
        options.defaultFontSize = size.doubleValue;
        svg.renderingOptions = options;
        NSString* reference = [NSString stringWithFormat:@"<rect width='%@' height='%@'/>", size, size];
        XCTAssertEqualObjects([self renderSVG:svg size:64], [self renderBody:reference size:64]);
        XCTAssertEqualWithAccuracy(svg.artworkBounds.size.width, size.doubleValue, .001);
        XCTAssertEqualWithAccuracy(svg.artworkExtent.size.height, size.doubleValue, .001);
    }
    svg.renderingOptions = nil;
    XCTAssertEqualObjects([self renderSVG:svg size:64], [self renderBody:body size:64]);
}

- (void)testFontRelativeStrokeWidthsAndMarkers
{
    NSString* definitions = @"<defs><marker id='m' markerWidth='1' markerHeight='1' refY='.5'>"
        "<rect width='1' height='1' fill='red'/></marker></defs>";
    NSArray<NSArray<NSString*>*>* cases = @[
        @[@"<path d='M4 16H20' stroke='blue' stroke-width='1em'/>",
          @"<path d='M4 16H20' stroke='blue' stroke-width='24'/>"],
        @[@"<path d='M4 16H20' stroke='blue' stroke-width='1em' font-size='8'/>",
          @"<path d='M4 16H20' stroke='blue' stroke-width='8'/>"],
        @[@"<g font-size='8' stroke-width='1em'><path d='M4 16H20' stroke='blue' font-size='20'/></g>",
          @"<path d='M4 16H20' stroke='blue' stroke-width='8'/>"],
        @[@"<path d='M4 16H20' stroke='blue' stroke-width='.25em' marker-end='url(#m)'/>",
          @"<path d='M4 16H20' stroke='blue' stroke-width='6' marker-end='url(#m)'/>"],
        @[@"<path d='M4 16H20' stroke='blue' stroke-width='1ex'/>",
          @"<g font-size='24'><path d='M4 16H20' stroke='blue' stroke-width='1ex'/></g>"]
    ];
    for(NSArray<NSString*>* pair in cases) {
        IJSVG* svg = [self svgWithBody:[definitions stringByAppendingString:pair[0]]];
        IJSVGRenderingOptions* options = svg.renderingOptions;
        options.defaultFontSize = 24;
        svg.renderingOptions = options;
        NSData* expected = [self renderBody:[definitions stringByAppendingString:pair[1]] size:64];
        XCTAssertEqualObjects([self renderSVG:svg size:64], expected, @"%@", pair[0]);
        for(NSNumber* flags in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionAll)]) {
            NSString* exported = [svg SVGStringWithSize:CGSizeMake(32, 32) options:flags.unsignedIntegerValue];
            XCTAssertEqualObjects([self renderSVG:[[IJSVG alloc] initWithSVGString:exported] size:64], expected);
        }
    }
}

- (void)testDefaultFontSizeSurvivesExport
{
    NSString* body = @"<symbol id='s' viewBox='0 0 1 1'><rect width='1' height='1' fill='red'/></symbol>"
                      "<use href='#s' width='.5em' height='1ex'/><text x='1' y='28'>A</text>";
    IJSVG* svg = [self svgWithBody:body];
    IJSVGRenderingOptions* options = svg.renderingOptions;
    options.defaultFontSize = 24;
    svg.renderingOptions = options;
    NSData* expected = [self renderSVG:svg size:64];
    for(NSNumber* flags in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionAll)]) {
        NSString* exported = [svg SVGStringWithSize:CGSizeMake(32, 32) options:flags.unsignedIntegerValue];
        IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:exported];
        XCTAssertEqualObjects(expected, [self renderSVG:roundTrip size:64]);
    }
}

- (void)testDefaultFontSizeOptionsAreIndependent
{
    IJSVGRenderingOptions* options = [[IJSVGRenderingOptions alloc] init];
    XCTAssertEqual(options.defaultFontSize, 16);
    options.defaultFontSize = 24;
    IJSVG* svg = [self svgWithBody:@"<text y='28'>A</text>"];
    svg.renderingOptions = options;
    options.defaultFontSize = 8;
    XCTAssertEqual(svg.renderingOptions.defaultFontSize, 24);
    IJSVGRenderingOptions* snapshot = svg.renderingOptions;
    snapshot.defaultFontSize = 12;
    XCTAssertEqual(svg.renderingOptions.defaultFontSize, 24);
    svg.renderingOptions = snapshot;
    XCTAssertEqual(svg.renderingOptions.defaultFontSize, 12);
    for(NSNumber* value in @[@(-1), @(NAN), @(INFINITY)]) {
        options.defaultFontSize = value.doubleValue;
        XCTAssertEqual(options.defaultFontSize, 16);
    }
    options.defaultFontSize = 0;
    XCTAssertEqual(options.defaultFontSize, 0);
}

- (NSString*)bodyByResolvingFontUnits:(NSString*)body fontSize:(CGFloat)fontSize
{
    CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), fontSize, NULL);
    CGFloat xHeight = CTFontGetXHeight(font);
    CFRelease(font);
    NSRegularExpression* expression = [NSRegularExpression regularExpressionWithPattern:
        @"([0-9]*\\.?[0-9]+)(em|ex)" options:0 error:NULL];
    BOOL documentBody = [body hasPrefix:@"<svg xmlns"];
    NSString* xml = documentBody ? body : [NSString stringWithFormat:@"<g>%@</g>", body];
    NSXMLDocument* document = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:NULL];
    NSMutableArray<NSXMLElement*>* pending = [NSMutableArray arrayWithObject:document.rootElement];
    while(pending.count != 0) {
        NSXMLElement* element = pending.lastObject;
        [pending removeLastObject];
        BOOL cssGeometry = [@[@"rect", @"circle", @"ellipse", @"image"] containsObject:element.localName];
        for(NSXMLNode* attribute in element.attributes) {
            BOOL css = cssGeometry || [@[@"stroke-width", @"stroke-dasharray", @"stroke-dashoffset"] containsObject:attribute.name];
            NSString* value = attribute.stringValue;
            NSMutableString* result = value.mutableCopy;
            NSArray<NSTextCheckingResult*>* matches = [expression matchesInString:value options:0 range:NSMakeRange(0, value.length)];
            for(NSTextCheckingResult* match in matches.reverseObjectEnumerator) {
                CGFloat number = [[value substringWithRange:[match rangeAtIndex:1]] doubleValue];
                NSString* unit = [value substringWithRange:[match rangeAtIndex:2]];
                CGFloat basis = [unit isEqualToString:@"em"] ? fontSize : (css ? xHeight : ceil(xHeight));
                [result replaceCharactersInRange:match.range withString:[NSString stringWithFormat:@"%.12g", number * basis]];
            }
            attribute.stringValue = result;
        }
        for(NSXMLNode* child in element.children) {
            if(child.kind == NSXMLElementKind) {
                [pending addObject:(NSXMLElement*)child];
            }
        }
    }
    return document.rootElement.XMLString;
}

- (void)assertFontRelativeLengthsInBody:(NSString*)template
{
    for(NSString* unit in @[@"em", @"ex"]) {
        NSString* body = [template stringByReplacingOccurrencesOfString:@"em" withString:unit];
        for(NSNumber* base in @[@16, @24]) {
            for(NSNumber* override in @[@0, @12]) {
                CGFloat fontSize = override.doubleValue ?: base.doubleValue;
                NSString* style = override.doubleValue == 0 ? @"" : @" font-size='12'";
                NSString* source = [NSString stringWithFormat:@"<g font-family='Helvetica'%@>%@</g>", style, body];
                IJSVG* svg = [self svgWithBody:source];
                IJSVGRenderingOptions* options = svg.renderingOptions;
                options.defaultFontSize = base.doubleValue;
                svg.renderingOptions = options;
                NSString* reference = [self bodyByResolvingFontUnits:body fontSize:fontSize];
                NSData* expected = [self renderBody:reference size:64];
                const uint8_t* bytes = expected.bytes;
                NSUInteger ink = 0;
                for(NSUInteger index = 3; index < expected.length; index += 4) {
                    ink += bytes[index] != 0;
                }
                XCTAssertGreaterThan(ink, 0, @"%@", reference);
                XCTAssertEqualObjects([self renderSVG:svg size:64], expected, @"%@ base=%@ override=%@", source, base, override);
                IJSVG* referenceSVG = [self svgWithBody:reference];
                XCTAssertEqualWithAccuracy(svg.artworkBounds.size.width, referenceSVG.artworkBounds.size.width, .001);
                XCTAssertEqualWithAccuracy(svg.artworkExtent.size.height, referenceSVG.artworkExtent.size.height, .001);
                for(NSNumber* flags in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionAll)]) {
                    NSString* exported = [svg SVGStringWithSize:CGSizeMake(32, 32) options:flags.unsignedIntegerValue];
                    IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:exported];
                    NSString* referenceExport = [referenceSVG SVGStringWithSize:CGSizeMake(32, 32) options:flags.unsignedIntegerValue];
                    IJSVG* referenceRoundTrip = [[IJSVG alloc] initWithSVGString:referenceExport];
                    XCTAssertEqualObjects([self renderSVG:roundTrip size:64], [self renderSVG:referenceRoundTrip size:64], @"%@ exported %@", source, exported);
                }
            }
        }
    }
}

- (void)testFontRelativeShapeGeometry
{
    for(NSString* body in @[
        @"<rect x='.25em' y='.25em' width='1em' height='.75em' rx='.125em' ry='.25em'/>",
        @"<circle cx='.75em' cy='.75em' r='.5em'/>",
        @"<ellipse cx='.75em' cy='.75em' rx='.5em' ry='.25em'/>",
        @"<line x1='.25em' y1='.25em' x2='1em' y2='1em' stroke='navy' stroke-width='.125em'/>",
        @"<path d='M2 12H30' stroke='navy' stroke-width='.125em' stroke-dasharray='.25em .125em' stroke-dashoffset='.125em'/>",
        @"<g stroke-dasharray='.25em .125em' stroke-dashoffset='.125em'><path d='M2 12H30' stroke='navy' stroke-width='2'/></g>"
    ]) {
        [self assertFontRelativeLengthsInBody:body];
    }
}

- (void)testFontRelativeViewportsAndMarkers
{
    for(NSString* body in @[
        @"<svg x='.25em' y='.25em' width='1em' height='.75em' viewBox='0 0 4 4'><rect width='4' height='4'/></svg>",
        @"<svg x='.25em' y='.25em' width='1em' height='.75em'><rect width='8' height='8'/></svg>",
        @"<symbol id='s' viewBox='0 0 4 4'><rect width='4' height='4'/></symbol><use href='#s' x='.25em' y='.25em' width='1em' height='.75em'/>",
        @"<defs><marker id='m' markerUnits='userSpaceOnUse' markerWidth='.5em' markerHeight='.5em' refX='.25em' refY='.25em'><rect width='.5em' height='.5em' fill='red'/></marker></defs><path d='M8 8H24' stroke='navy' marker-end='url(#m)'/>"
    ]) {
        [self assertFontRelativeLengthsInBody:body];
    }
}

- (void)testFontRelativePaintServers
{
    for(NSString* body in @[
        @"<defs><linearGradient id='g' gradientUnits='userSpaceOnUse' x1='.25em' y1='.25em' x2='1em' y2='1em'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect width='32' height='32' fill='url(#g)'/>",
        @"<defs><radialGradient id='g' gradientUnits='userSpaceOnUse' cx='.75em' cy='.75em' fx='.5em' fy='.5em' r='.5em'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></radialGradient></defs><rect width='32' height='32' fill='url(#g)'/>",
        @"<defs><pattern id='p' patternUnits='userSpaceOnUse' x='.25em' y='.25em' width='.5em' height='.5em'><rect width='.25em' height='.5em' fill='orange'/></pattern></defs><rect width='32' height='32' fill='url(#p)'/>"
    ]) {
        [self assertFontRelativeLengthsInBody:body];
    }
}

- (void)testFontRelativeClipMaskAndFilterRegions
{
    for(NSString* body in @[
        @"<defs><clipPath id='c'><rect x='.25em' y='.25em' width='1em' height='.75em'/></clipPath></defs><rect width='32' height='32' fill='red' clip-path='url(#c)'/>",
        @"<defs><mask id='m' maskUnits='userSpaceOnUse' x='.25em' y='.25em' width='1em' height='.75em'><rect width='32' height='32' fill='white'/></mask></defs><rect width='32' height='32' fill='red' mask='url(#m)'/>",
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='.25em' y='.25em' width='1em' height='.75em'><feFlood flood-color='red'/></filter></defs><rect width='32' height='32' filter='url(#f)'/>",
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='32' height='32'><feFlood flood-color='red' x='.25em' y='.25em' width='1em' height='.75em'/></filter></defs><rect width='32' height='32' filter='url(#f)'/>"
    ]) {
        [self assertFontRelativeLengthsInBody:body];
    }
}

- (void)testFontRelativeObjectBoundingBoxLengths
{
    for(NSString* body in @[
        @"<defs><clipPath id='c' clipPathUnits='objectBoundingBox'><rect width='.025em' height='.025em'/></clipPath></defs><rect width='32' height='32' clip-path='url(#c)'/>",
        @"<defs><mask id='m' x='0' y='0' width='.025em' height='.025em'><rect width='32' height='32' fill='white'/></mask></defs><rect width='32' height='32' mask='url(#m)'/>",
        @"<defs><linearGradient id='g' x2='.025em'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect width='32' height='32' fill='url(#g)'/>"
    ]) {
        [self assertFontRelativeLengthsInBody:body];
    }
}

- (void)testFontRelativeFilterInputs
{
    [self assertFontRelativeLengthsInBody:
        @"<defs><rect id='tile' width='1em' height='.5em' fill='red'/><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='32' height='32'><feImage href='#tile'/></filter></defs><rect width='32' height='32' filter='url(#f)'/>"];
    [self assertFontRelativeLengthsInBody:
        @"<defs><linearGradient id='g' gradientUnits='userSpaceOnUse' x2='1em'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='32' height='32'><feComposite in='FillPaint' in2='SourceAlpha' operator='in'/></filter></defs><rect width='32' height='32' fill='url(#g)' filter='url(#f)'/>"];
}

- (void)testFontRelativePaintServersFollowOptionChanges
{
    NSString* body = @"<defs><linearGradient id='g' gradientUnits='userSpaceOnUse' x2='1em'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='1em' height='1em'><feOffset dx='0'/></filter></defs><rect width='1em' height='1em' fill='url(#g)' filter='url(#f)'/>";
    IJSVG* svg = [self svgWithBody:body];
    for(NSNumber* base in @[@16, @24, @12, @16]) {
        IJSVGRenderingOptions* options = svg.renderingOptions;
        options.defaultFontSize = base.doubleValue;
        svg.renderingOptions = options;
        NSString* reference = [self bodyByResolvingFontUnits:body fontSize:base.doubleValue];
        XCTAssertEqualObjects([self renderSVG:svg size:64], [self renderBody:reference size:64]);
    }
}

- (void)testFontRelativeImageBounds
{
    NSString* data = @"iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII=";
    [self assertFontRelativeLengthsInBody:[NSString stringWithFormat:
        @"<image x='.25em' y='.25em' width='1em' height='.75em' preserveAspectRatio='none' href='data:image/png;base64,%@'/>", data]];
    [self assertFontRelativeLengthsInBody:[NSString stringWithFormat:
        @"<image x='.25em' y='.25em' width='1em' height='.75em' href='data:image/png;base64,%@'/>", data]];
}

- (void)testFontRelativeRootSize
{
    for(NSString* unit in @[@"em", @"ex"]) {
        NSString* source = [NSString stringWithFormat:
            @"<svg xmlns='http://www.w3.org/2000/svg' font-family='Helvetica' width='2%@' height='1%@'><rect width='8' height='8'/></svg>", unit, unit];
        IJSVG* svg = [[IJSVG alloc] initWithSVGString:source];
        for(NSNumber* base in @[@16, @24, @12]) {
            IJSVGRenderingOptions* options = svg.renderingOptions;
            options.defaultFontSize = base.doubleValue;
            svg.renderingOptions = options;
            NSString* reference = [self bodyByResolvingFontUnits:source fontSize:base.doubleValue];
            IJSVG* expected = [[IJSVG alloc] initWithSVGString:reference];
            XCTAssertTrue(CGSizeEqualToSize(svg.size, expected.size));
            XCTAssertTrue(CGRectEqualToRect(svg.viewBox, expected.viewBox));
            XCTAssertTrue(CGSizeEqualToSize([svg sizeByMaintainingAspectRatioWithSize:CGSizeMake(64, 64)], [expected sizeByMaintainingAspectRatioWithSize:CGSizeMake(64, 64)]));
            XCTAssertEqualObjects([self renderSVG:svg size:64], [self renderSVG:expected size:64]);
            NSString* exported = [svg SVGStringWithSize:CGSizeZero options:IJSVGExporterOptionNone];
            IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:exported];
            XCTAssertTrue(CGSizeEqualToSize(roundTrip.size, expected.size));
            XCTAssertEqualObjects([self renderSVG:roundTrip size:64], [self renderSVG:expected size:64]);
        }
    }
}

- (void)testCachedPaintsFollowViewportScaleChanges
{
    NSString* body = @"<defs><pattern id='p' width='8' height='8' patternUnits='userSpaceOnUse'><rect "
                      "width='4' height='8' fill='red'/><rect x='4' width='4' height='8' fill='blue'/>"
                      "</pattern><mask id='m'><rect width='32' height='32' fill='white'/></mask></defs>"
                      "<g mask='url(#m)'><rect width='32' height='32' fill='url(#p)'/><path d='M2 16h28' "
                      "stroke='white' stroke-width='2' stroke-dasharray='2 3'/></g>";
    IJSVG* svg = [self svgWithBody:body];
    for(NSNumber* value in @[@32, @128, @64, @32]) {
        NSUInteger size = value.unsignedIntegerValue;
        NSData* reused = [self renderSVG:svg
                                    size:size];
        NSData* fresh = [self renderBody:body
                                    size:size];
        XCTAssertEqualObjects(reused, fresh, @"Viewport size: %@", value);
    }
}

- (void)assertVectorExportPreservesQuartzPixels:(NSString*)body
                                      optimized:(BOOL)optimized
{
    IJSVG* svg = [self svgWithBody:body];
    if(svg == nil) return;
    IJSVGExporterOptions options = optimized ? IJSVGExporterOptionAll: IJSVGExporterOptionNone;
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg
                                                            size:CGSizeMake(32.f,
                                                                                     32.f)
                                                         options:options];
    NSString* exported = [exporter SVGString];
    IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:exported];
    NSData* before = [self renderSVG:svg
                                size:64];
    NSData* after = [self renderSVG:roundTrip
                               size:64];
    if(before == nil || after == nil) return;
    XCTAssertEqual(before.length, after.length);
    if(before.length != after.length) return;

    const uint8_t* beforePixels = before.bytes;
    const uint8_t* afterPixels = after.bytes;
    NSInteger difference = 0;
    for(NSUInteger index = 0; index < before.length; index++) {
        NSInteger delta = (NSInteger)beforePixels[index] - (NSInteger)afterPixels[index];
        difference = MAX(difference, delta < 0 ? -delta : delta);
    }
    // Outlined patterned strokes can differ by four levels at resampled tile edges.
    NSInteger tolerance = optimized && [body containsString:@"stroke='url(#p)'"] ? 4 : 3;
    XCTAssertLessThanOrEqual(difference, tolerance,
                             @"Pixel difference %ld; SVG: %@", (long)difference,
                             exported);
}

- (void)assertTextExportPreservesQuartzPixels:(BOOL)optimized
{
    NSArray<NSString*>* bodies = @[
        (@"<text x='2' y='16' font-family='Helvetica' font-size='10'>A<tspan fill='red'>B</tspan>C</text>"
          ""),
        (@"<defs><path id='baseline' d='M2 20Q16 4 30 20'/></defs><text font-family='Helvetica' "
          "font-size='8'><textPath href='#baseline'>ABC</textPath></text>"),
        (@"<defs><filter id='blur' x='-50%' y='-50%' width='200%' height='200%'><feGaussianBlur "
          "stdDeviation='.3'/></filter></defs><g transform='translate(2 3) rotate(5 12 12)'><text x='2' "
          "y='16' font-family='Helvetica' font-size='10' fill='red' filter='url(#blur)'>AB</text></g>")
    ];
    for(NSString* body in bodies) {
        [self assertVectorExportPreservesQuartzPixels:body
                                            optimized:optimized];
    }
}

- (void)testUnoptimizedTextExportPreservesQuartzPixels
{
    [self assertTextExportPreservesQuartzPixels:NO];
}

- (void)testOptimizedTextExportPreservesQuartzPixels
{
    [self assertTextExportPreservesQuartzPixels:YES];
}

- (void)testUnoptimizedVectorExportPreservesNestedTransforms
{
    [self assertVectorExportPreservesQuartzPixels:@"<g transform='translate(2 3)'><g "
                                                   "transform='translate(5 7)'><rect width='8' "
                                                   "height='8' fill='red'/></g></g>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesNestedTransforms
{
    [self assertVectorExportPreservesQuartzPixels:@"<g transform='translate(2 3)'><g "
                                                   "transform='translate(5 7)'><rect width='8' "
                                                   "height='8' fill='red'/></g></g>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesGroupOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<g opacity='.5'><rect x='2' y='2' width='20' "
                                                   "height='20' fill='red'/><rect x='10' y='10' "
                                                   "width='20' height='20' fill='blue'/></g>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesGroupOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<g opacity='.5'><rect x='2' y='2' width='20' "
                                                   "height='20' fill='red'/><rect x='10' y='10' "
                                                   "width='20' height='20' fill='blue'/></g>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesDashedStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<path d='M3 5L25 5L25 25' fill='none' stroke='red' "
                                                   "stroke-width='3' stroke-linecap='round' "
                                                   "stroke-linejoin='bevel' stroke-dasharray='3 2' "
                                                   "stroke-dashoffset='1'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesDashedStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<path d='M3 5L25 5L25 25' fill='none' stroke='red' "
                                                   "stroke-width='3' stroke-linecap='round' "
                                                   "stroke-linejoin='bevel' stroke-dasharray='3 2' "
                                                   "stroke-dashoffset='1'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesLinearGradientOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><linearGradient id='g'><stop stop-color='red'/>"
                                                   "<stop offset='1' stop-color='blue'/></linearGradient>"
                                                   "</defs><rect x='4' y='4' width='24' height='24' "
                                                   "fill='url(#g)' fill-opacity='.6'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesLinearGradientOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><linearGradient id='g'><stop stop-color='red'/>"
                                                   "<stop offset='1' stop-color='blue'/></linearGradient>"
                                                   "</defs><rect x='4' y='4' width='24' height='24' "
                                                   "fill='url(#g)' fill-opacity='.6'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesRadialGradient
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><radialGradient id='g'><stop stop-color='red'/>"
                                                   "<stop offset='1' stop-color='blue'/></radialGradient>"
                                                   "</defs><circle cx='16' cy='16' r='10' "
                                                   "fill='url(#g)'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesRadialGradient
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><radialGradient id='g'><stop stop-color='red'/>"
                                                   "<stop offset='1' stop-color='blue'/></radialGradient>"
                                                   "</defs><circle cx='16' cy='16' r='10' "
                                                   "fill='url(#g)'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesGradientStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><linearGradient id='g'><stop stop-color='red'/>"
                                                   "<stop offset='1' stop-color='blue'/></linearGradient>"
                                                   "</defs><path d='M4 8L28 8L28 24' fill='none' "
                                                   "stroke='url(#g)' stroke-opacity='.6' "
                                                   "stroke-width='3'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesGradientStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><linearGradient id='g'><stop stop-color='red'/>"
                                                   "<stop offset='1' stop-color='blue'/></linearGradient>"
                                                   "</defs><path d='M4 8L28 8L28 24' fill='none' "
                                                   "stroke='url(#g)' stroke-opacity='.6' "
                                                   "stroke-width='3'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesPatternOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><pattern id='p' width='8' height='8' "
                                                   "patternUnits='userSpaceOnUse'><rect width='4' "
                                                   "height='8' fill='red'/><rect x='4' width='4' "
                                                   "height='8' fill='blue'/></pattern></defs><rect "
                                                   "width='32' height='32' fill='url(#p)' "
                                                   "fill-opacity='.5'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesPatternOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><pattern id='p' width='8' height='8' "
                                                   "patternUnits='userSpaceOnUse'><rect width='4' "
                                                   "height='8' fill='red'/><rect x='4' width='4' "
                                                   "height='8' fill='blue'/></pattern></defs><rect "
                                                   "width='32' height='32' fill='url(#p)' "
                                                   "fill-opacity='.5'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesTransformedClip
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><clipPath id='c'><rect width='8' height='8'/>"
                                                   "</clipPath></defs><g transform='translate(8 8)'>"
                                                   "<rect width='20' height='20' fill='red' "
                                                   "clip-path='url(#c)'/></g>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesTransformedClip
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><clipPath id='c'><rect width='8' height='8'/>"
                                                   "</clipPath></defs><g transform='translate(8 8)'>"
                                                   "<rect width='20' height='20' fill='red' "
                                                   "clip-path='url(#c)'/></g>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesMask
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><mask id='m'><rect width='16' height='32' "
                                                   "fill='white'/></mask></defs><rect width='32' "
                                                   "height='32' fill='red' mask='url(#m)'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesMask
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><mask id='m'><rect width='16' height='32' "
                                                   "fill='white'/></mask></defs><rect width='32' "
                                                   "height='32' fill='red' mask='url(#m)'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesNestedSVG
{
    [self assertVectorExportPreservesQuartzPixels:@"<svg x='8' y='8' width='16' height='16' viewBox='0 0 "
                                                   "8 8'><rect width='8' height='8' fill='blue'/></svg>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesNestedSVG
{
    [self assertVectorExportPreservesQuartzPixels:@"<svg x='8' y='8' width='16' height='16' viewBox='0 0 "
                                                   "8 8'><rect width='8' height='8' fill='blue'/></svg>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesPatternedStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><pattern id='p' width='8' height='8' "
                                                   "patternUnits='userSpaceOnUse' "
                                                   "patternTransform='translate(2 3)'><rect width='4' "
                                                   "height='8' fill='red'/></pattern></defs><path d='M4 "
                                                   "8L28 8L28 24' fill='none' stroke='url(#p)' "
                                                   "stroke-opacity='.6' stroke-width='3'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesPatternedStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><pattern id='p' width='8' height='8' "
                                                   "patternUnits='userSpaceOnUse' "
                                                   "patternTransform='translate(2 3)'><rect width='4' "
                                                   "height='8' fill='red'/></pattern></defs><path d='M4 "
                                                   "8L28 8L28 24' fill='none' stroke='url(#p)' "
                                                   "stroke-opacity='.6' stroke-width='3'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesPositionedMask
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><mask id='m' maskUnits='userSpaceOnUse' x='8' "
                                                   "y='8' width='8' height='8'><rect x='8' y='8' "
                                                   "width='8' height='8' fill='white'/></mask></defs>"
                                                   "<rect x='4' y='4' width='24' height='24' fill='red' "
                                                   "mask='url(#m)'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesPositionedMask
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><mask id='m' maskUnits='userSpaceOnUse' x='8' "
                                                   "y='8' width='8' height='8'><rect x='8' y='8' "
                                                   "width='8' height='8' fill='white'/></mask></defs>"
                                                   "<rect x='4' y='4' width='24' height='24' fill='red' "
                                                   "mask='url(#m)'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesFillAndStrokeOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<rect x='5' y='5' width='22' height='22' fill='red' "
                                                   "stroke='blue' stroke-width='4' opacity='.5'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesFillAndStrokeOpacity
{
    [self assertVectorExportPreservesQuartzPixels:@"<rect x='5' y='5' width='22' height='22' fill='red' "
                                                   "stroke='blue' stroke-width='4' opacity='.5'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesTransformedLinearGradient
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><linearGradient id='g' "
                                                   "gradientUnits='userSpaceOnUse' x1='4' x2='28' "
                                                   "gradientTransform='rotate(15 16 16)'><stop "
                                                   "stop-color='red'/><stop offset='1' "
                                                   "stop-color='blue'/></linearGradient></defs><rect "
                                                   "x='4' y='4' width='24' height='24' fill='url(#g)' "
                                                   "stroke='black' stroke-width='2'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesTransformedLinearGradient
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><linearGradient id='g' "
                                                   "gradientUnits='userSpaceOnUse' x1='4' x2='28' "
                                                   "gradientTransform='rotate(15 16 16)'><stop "
                                                   "stop-color='red'/><stop offset='1' "
                                                   "stop-color='blue'/></linearGradient></defs><rect "
                                                   "x='4' y='4' width='24' height='24' fill='url(#g)' "
                                                   "stroke='black' stroke-width='2'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesRadialGradientStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><radialGradient id='g' "
                                                   "gradientTransform='scale(.8 1)'><stop "
                                                   "stop-color='red'/><stop offset='1' "
                                                   "stop-color='blue'/></radialGradient></defs><path "
                                                   "d='M4 8L28 8L28 24' fill='none' stroke='url(#g)' "
                                                   "stroke-width='3'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesRadialGradientStroke
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><radialGradient id='g' "
                                                   "gradientTransform='scale(.8 1)'><stop "
                                                   "stop-color='red'/><stop offset='1' "
                                                   "stop-color='blue'/></radialGradient></defs><path "
                                                   "d='M4 8L28 8L28 24' fill='none' stroke='url(#g)' "
                                                   "stroke-width='3'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesEvenOddFill
{
    [self assertVectorExportPreservesQuartzPixels:@"<path d='M2 2H30V30H2ZM8 8H24V24H8Z' fill='red' "
                                                   "fill-rule='evenodd'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesEvenOddFill
{
    [self assertVectorExportPreservesQuartzPixels:@"<path d='M2 2H30V30H2ZM8 8H24V24H8Z' fill='red' "
                                                   "fill-rule='evenodd'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesRelativePattern
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><pattern id='p' width='.25' height='.25'><rect "
                                                   "width='4' height='8' fill='red'/></pattern></defs>"
                                                   "<rect x='4' y='4' width='24' height='24' "
                                                   "fill='url(#p)'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesRelativePattern
{
    [self assertVectorExportPreservesQuartzPixels:@"<defs><pattern id='p' width='.25' height='.25'><rect "
                                                   "width='4' height='8' fill='red'/></pattern></defs>"
                                                   "<rect x='4' y='4' width='24' height='24' "
                                                   "fill='url(#p)'/>"
                                        optimized:YES];
}

- (void)testUnoptimizedVectorExportPreservesMultiplyBlend
{
    [self assertVectorExportPreservesQuartzPixels:@"<rect width='32' height='32' fill='red'/><rect x='8' "
                                                   "y='8' width='16' height='16' fill='blue' "
                                                   "style='mix-blend-mode:multiply'/>"
                                        optimized:NO];
}

- (void)testOptimizedVectorExportPreservesMultiplyBlend
{
    [self assertVectorExportPreservesQuartzPixels:@"<rect width='32' height='32' fill='red'/><rect x='8' "
                                                   "y='8' width='16' height='16' fill='blue' "
                                                   "style='mix-blend-mode:multiply'/>"
                                        optimized:YES];
}

- (void)testExportPreservesStyleOverrides
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' "
                                                   "height='32'><rect x='5' y='5' width='22' height='22' "
                                                   "fill='red' stroke='blue' stroke-width='2'/></svg>"];
    XCTAssertNotNil(svg);
    if(svg == nil) return;
    svg.style.fillColor = NSColor.greenColor;
    svg.style.strokeColor = NSColor.magentaColor;
    svg.style.lineWidth = 4.f;
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg
                                                            size:CGSizeMake(32.f,
                                                                                     32.f)
                                                         options:IJSVGExporterOptionNone];
    IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:[exporter SVGString]];
    XCTAssertEqualObjects([self renderSVG:svg
                                     size:64],
                          [self renderSVG:roundTrip
                                     size:64]);
}

- (void)assertNodeGraphExportPreservesRelativeUnitsAndDoesNotMutateClientSize:(BOOL)optimized
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='100%' "
                                                   "height='100%'><rect x='25%' y='25%' width='50%' "
                                                   "height='50%' fill='red'/></svg>"];
    XCTAssertNotNil(svg);
    if(svg == nil) return;
    IJSVGRootNode* node = [svg rootNode];
    XCTAssertNotNil(node);
    if(node == nil) return;
    CGSize clientSize = node.clientSize;
    IJSVGExporterOptions options = optimized ? IJSVGExporterOptionAll: IJSVGExporterOptionNone;
    CGSize size = CGSizeMake(64.f, 64.f);
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithRootNode:node
                                                                 size:size
                                                                style:svg.style
                                                     renderingOptions:svg.renderingOptions
                                                              options:options
                                                 floatingPointOptions:IJSVGFloatingPointOptionsDefault()];
    NSString* text = [exporter SVGString];
    XCTAssertTrue(CGSizeEqualToSize(node.clientSize, clientSize));
    IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:text];
    XCTAssertEqualObjects([self renderSVG:svg
                                     size:64],
                          [self renderSVG:roundTrip
                                     size:64], @"%@", text);
}

- (void)testUnoptimizedNodeGraphExportPreservesRelativeUnitsAndDoesNotMutateClientSize
{
    [self assertNodeGraphExportPreservesRelativeUnitsAndDoesNotMutateClientSize:NO];
}

- (void)testOptimizedNodeGraphExportPreservesRelativeUnitsAndDoesNotMutateClientSize
{
    [self assertNodeGraphExportPreservesRelativeUnitsAndDoesNotMutateClientSize:YES];
}

- (void)testGradientColorReplacementSurvivesExport
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' "
                                                   "height='32'><defs><linearGradient id='g'><stop "
                                                   "stop-color='red'/><stop offset='1' "
                                                   "stop-color='blue'/></linearGradient></defs><rect "
                                                   "width='32' height='32' fill='url(#g)'/></svg>"];
    XCTAssertNotNil(svg);
    if(svg == nil) return;
    [svg.style.colors replaceColor:NSColor.redColor
                         withColor:NSColor.greenColor
                            traits:IJSVGColorUsageTraitGradientStop];
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg
                                                            size:CGSizeMake(32.f,
                                                                                     32.f)
                                                         options:IJSVGExporterOptionAll];
    IJSVG* roundTrip = [[IJSVG alloc] initWithSVGString:[exporter SVGString]];
    XCTAssertEqualObjects([self renderSVG:svg
                                     size:64],
                          [self renderSVG:roundTrip
                                     size:64]);
}

- (void)testNodeTraversalStopsAtRequestedDescendant
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' "
                                                   "height='32'><g id='first'><rect id='nested' "
                                                   "width='4' height='4'/></g><rect id='later' width='8' "
                                                   "height='8'/></svg>"];
    XCTAssertNotNil(svg);
    if(svg == nil) return;
    NSMutableArray<NSString*>* identifiers = [NSMutableArray array];
    [IJSVGNode walkNodeTree:[svg rootNode]
                    handler:^(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop) {
        if(node.identifier.length != 0) {
            [identifiers addObject:node.identifier];
            if([node.identifier isEqualToString:@"nested"] && stop != NULL) {
                *stop = YES;
            }
        }
    }];
    NSArray<NSString*>* expected = @[@"first", @"nested"];
    XCTAssertEqualObjects(identifiers, expected);
}

@end
