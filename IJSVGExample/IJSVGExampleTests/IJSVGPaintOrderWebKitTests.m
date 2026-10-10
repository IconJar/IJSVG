//
//  IJSVGPaintOrderWebKitTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <WebKit/WebKit.h>
#import <IJSVG/IJSVG.h>

@interface IJSVGPaintOrderWebKitTests: XCTestCase <WKNavigationDelegate>

@property (nonatomic, strong) XCTestExpectation* navigation;
@property (nonatomic, strong) WKWebView* webView;
@property (nonatomic, strong) NSWindow* window;
@property (nonatomic, assign) CGFloat defaultFontSize;

@end

@implementation IJSVGPaintOrderWebKitTests

- (void)testPointSubpathCapsMatchExplicitShapes
{
    for(NSString* cap in @[@"round", @"square"]) {
        for(NSString* transform in @[@"", @"transform='rotate(25 200 100)'",
                                     @"transform='scale(1.5 .75)' vector-effect='non-scaling-stroke'"]) {
            BOOL nonScaling = [transform containsString:@"non-scaling-stroke"];
            NSString* body = [NSString stringWithFormat:
                @"<path d='M100 100h0 M200 100q0 0 0 0' fill='none' stroke='red' stroke-width='40' stroke-linecap='%@' %@/>",
                cap, transform];
            NSMutableString* reference = [NSMutableString string];
            for(NSUInteger index = 1; index <= 2; index++) {
                CGFloat x = index * (nonScaling ? 150.f : 100.f);
                CGFloat y = nonScaling ? 75.f : 100.f;
                NSString* attributes = nonScaling ? @"" : transform;
                if([cap isEqualToString:@"round"]) {
                    [reference appendFormat:@"<circle cx='%g' cy='%g' r='20' fill='red' %@/>", x, y, attributes];
                } else {
                    [reference appendFormat:@"<rect x='%g' y='%g' width='40' height='40' fill='red' %@/>", x - 20.f, y - 20.f, attributes];
                }
            }
            [self compareBody:body referenceBody:reference
                         name:[NSString stringWithFormat:@"point-caps-%@-%lu", cap, (unsigned long)transform.length]
                    tolerance:.025];
        }
    }
}

- (void)testGradientSpreadingMatchesExplicitStops
{
    for(NSString* method in @[@"repeat", @"reflect"]) {
        NSMutableString* stops = [NSMutableString string];
        for(NSUInteger index = 0; index < 8; index++) {
            BOOL reversed = [method isEqualToString:@"reflect"] && index % 2 != 0;
            [stops appendFormat:@"<stop offset='%g' stop-color='%@'/><stop offset='%g' stop-color='%@'/>",
                index / 8.0, reversed ? @"blue" : @"red",
                (index + 1) / 8.0, reversed ? @"red" : @"blue"];
        }
        for(NSString* geometry in @[@"linearGradient x1='0' y1='0' x2='80' y2='0'",
                                    @"radialGradient cx='100' cy='100' r='40'"]) {
            NSString* tag = [geometry componentsSeparatedByString:@" "].firstObject;
            NSString* expanded = [geometry stringByReplacingOccurrencesOfString:@"x2='80'" withString:@"x2='640'"];
            expanded = [expanded stringByReplacingOccurrencesOfString:@"r='40'" withString:@"r='320'"];
            NSString* body = [NSString stringWithFormat:
                @"<defs><%@ id='g' gradientUnits='userSpaceOnUse' spreadMethod='%@'>"
                 "<stop stop-color='red'/><stop offset='1' stop-color='blue'/></%@></defs>"
                 "<rect width='300' height='180' fill='url(#g)'/>", geometry, method, tag];
            NSString* reference = [NSString stringWithFormat:
                @"<defs><%@ id='g' gradientUnits='userSpaceOnUse'>%@</%@></defs>"
                 "<rect width='300' height='180' fill='url(#g)'/>", expanded, stops, tag];
            [self compareBody:body referenceBody:reference
                         name:[NSString stringWithFormat:@"spread-%@-%@", tag, method] tolerance:.025];
        }
    }
}

- (void)testRadialSpreadWithFocalRadiusMatchesExplicitStops
{
    // The MDN radial fixture uses a nonzero focal radius. WebKit pads that
    // fixture, so use a zero-radius cone with explicitly expanded stops.
    CGFloat minimum = -17.f / 16.f;
    CGFloat maximum = 40.f;
    for(NSString* method in @[@"repeat", @"reflect"]) {
        BOOL reflect = [method isEqualToString:@"reflect"];
        NSMutableString* stops = [NSMutableString stringWithFormat:
            @"<stop offset='0' stop-color='rgb(255 %g %g)'/>",
            165.f * .9375f, 255.f * (1.f - .9375f)];
        for(NSInteger cycle = -1; cycle < (NSInteger)maximum; cycle++) {
            BOOL reversed = reflect && labs(cycle) % 2 != 0;
            CGFloat first = (cycle - minimum) / (maximum - minimum);
            CGFloat last = (cycle + 1 - minimum) / (maximum - minimum);
            [stops appendFormat:@"<stop offset='%.15g' stop-color='%@'/><stop offset='%.15g' stop-color='%@'/>",
                first, reversed ? @"orange" : @"fuchsia", last, reversed ? @"fuchsia" : @"orange"];
        }
        NSString* body = [NSString stringWithFormat:
            @"<defs><radialGradient id='g' gradientUnits='userSpaceOnUse' cx='75' cy='25' r='33'"
             " fx='64' fy='18' fr='17' spreadMethod='%@'>"
             "<stop stop-color='fuchsia'/><stop offset='1' stop-color='orange'/></radialGradient></defs>"
             "<rect width='100' height='100' fill='url(#g)'/>", method];
        NSString* reference = [NSString stringWithFormat:
            @"<defs><radialGradient id='g' gradientUnits='userSpaceOnUse' fx='52.3125' fy='10.5625'"
             " cx='504' cy='298' r='657'>%@</radialGradient></defs>"
             "<rect width='100' height='100' fill='url(#g)'/>", stops];
        [self compareBody:[NSString stringWithFormat:@"<g transform='scale(2)'>%@</g>", body]
            referenceBody:[NSString stringWithFormat:@"<g transform='scale(2)'>%@</g>", reference]
                     name:[@"spread-focal-radius-" stringByAppendingString:method] tolerance:.025];
    }
}

- (void)testLightingSurfaceScaleMatchesEquivalentLightHeight
{
    for(NSString* type in @[@"feDiffuseLighting", @"feSpecularLighting"]) {
        for(NSNumber* height in @[@1, @15]) {
            NSString* format = [NSString stringWithFormat:
                @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='400' height='200'>"
                 "<%@ surfaceScale='%%g' lighting-color='cyan'><fePointLight x='100' y='80' z='%%g'/>"
                 "</%@></filter></defs><rect width='400' height='200' filter='url(#f)'/>", type, type];
            NSString* body = [NSString stringWithFormat:format, height.doubleValue, 20.0];
            NSString* reference = [NSString stringWithFormat:format, 0.0, 20.0 - height.doubleValue];
            [self compareBody:body referenceBody:reference
                         name:[NSString stringWithFormat:@"lighting-surface-%@-%@", type, height] tolerance:.025];
        }
    }
}

- (void)testSpotlightConeEdgesMatchWebKit
{
    for(NSString* type in @[@"feDiffuseLighting", @"feSpecularLighting"]) {
        for(NSNumber* angle in @[@5.5, @10, @40]) {
            NSString* body = [NSString stringWithFormat:
                @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='400' height='200'>"
                 "<%@ surfaceScale='0' lighting-color='cyan'><feSpotLight x='20' y='20' z='80' "
                 "pointsAtX='200' pointsAtY='100' limitingConeAngle='%@'/></%@></filter></defs>"
                 "<rect width='400' height='200' filter='url(#f)'/>", type, angle, type];
            [self compareBody:body name:[NSString stringWithFormat:@"spot-cone-%@-%@", type, angle] tolerance:.025];
        }
    }
}

- (void)testDisplacementChannelsMatchWebKit
{
    NSArray* channels = @[@"R", @"G", @"B", @"A"];
    for(NSString* space in @[@"sRGB", @"linearRGB"]) {
        for(NSString* xChannel in channels) {
            for(NSString* yChannel in channels) {
                NSString* body = [NSString stringWithFormat:
                    @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='400' height='200' "
                     "color-interpolation-filters='%@'><feFlood flood-color='#ff8040' flood-opacity='.75' result='map'/>"
                     "<feDisplacementMap in='SourceGraphic' in2='map' scale='32' xChannelSelector='%@' yChannelSelector='%@'/>"
                     "</filter></defs><g filter='url(#f)'><rect x='60' y='50' width='140' height='90' fill='navy'/>"
                     "<circle cx='210' cy='90' r='35' fill='orange'/></g>", space, xChannel, yChannel];
                [self compareBody:body name:[NSString stringWithFormat:@"displacement-%@-%@-%@", space, xChannel, yChannel] tolerance:.025];
            }
        }
    }
}

- (void)testDisplacementImageMapMatchesWebKit
{
    for(NSString* viewBox in @[@"", @"viewBox='0 0 100 80'"]) {
        NSString* source = [NSString stringWithFormat:
            @"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='80' %@>"
             "<defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs>"
             "<rect width='100' height='30' fill='url(#g)'/><path d='M0 30H40V80H0Z' fill='#4080ff' fill-opacity='.5'/></svg>", viewBox];
        NSString* encoded = [[source dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
        for(NSString* channel in @[@"", @"R", @"G", @"B", @"A"]) {
            NSString* displacement = channel.length == 0 ? @"" : [NSString stringWithFormat:
                @"<feDisplacementMap in='SourceGraphic' in2='map' scale='30' xChannelSelector='%@' yChannelSelector='%@'/>", channel, channel];
            NSString* body = [NSString stringWithFormat:
                @"<defs><filter id='f' color-interpolation-filters='sRGB' filterUnits='userSpaceOnUse' x='0' y='0' width='400' height='200'>"
                 "<feImage href='data:image/svg+xml;base64,%@' x='0' y='0' width='100%%' height='100%%' result='map'/>%@"
                 "</filter></defs><g filter='url(#f)'><rect x='60' y='50' width='140' height='90' fill='navy'/>"
                 "<circle cx='210' cy='90' r='35' fill='orange'/></g>", encoded, displacement];
            [self compareBody:body name:[NSString stringWithFormat:@"displacement-image-%@-%@", viewBox, channel] tolerance:.025];
        }
    }
}

- (void)testLinearDisplacementImageMapMatchesFloodMap
{
    NSString* source = @"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='80'>"
                       "<rect width='100' height='30' fill='#ff8040'/>"
                       "<rect y='30' width='40' height='50' fill='#4080ff' fill-opacity='.5'/></svg>";
    NSString* encoded = [[source dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    NSString* imageMap = [NSString stringWithFormat:
        @"<feImage href='data:image/svg+xml;base64,%@' x='0' y='0' width='100%%' height='100%%' result='map'/>", encoded];
    // WebKit does not linearize the embedded image map in this case.
    // Equivalent flood regions verify the required linear channel values.
    NSString* floodMap = @"<feFlood x='75' y='0' width='250' height='75' flood-color='#ff8040' result='top'/>"
                         "<feFlood x='75' y='75' width='100' height='125' flood-color='#4080ff' flood-opacity='.5' result='bottom'/>"
                         "<feMerge result='map'><feMergeNode in='top'/><feMergeNode in='bottom'/></feMerge>";
    for(NSString* channel in @[@"R", @"G", @"B", @"A"]) {
        NSString* format = [NSString stringWithFormat:
            @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='0' y='0' width='400' height='200' "
             "color-interpolation-filters='linearRGB'>%%@"
             "<feDisplacementMap in='SourceGraphic' in2='map' scale='30' xChannelSelector='%@' yChannelSelector='%@'/>"
             "</filter></defs><g filter='url(#f)'><rect x='60' y='50' width='140' height='90' fill='navy'/>"
             "<circle cx='210' cy='90' r='35' fill='orange'/></g>", channel, channel];
        [self compareBody:[NSString stringWithFormat:format, imageMap]
            referenceBody:[NSString stringWithFormat:format, floodMap]
                     name:[@"displacement-linear-image-" stringByAppendingString:channel] tolerance:.025];
    }
}

- (void)testMarkerContextPaintMatchesExplicitColors
{
    NSString* marker = @"<marker id='%@' markerWidth='6' markerHeight='6' refX='3' refY='3' markerUnits='strokeWidth'>"
                       "<circle cx='3' cy='3' r='2' stroke='%@' fill='%@'/></marker>";
    NSMutableString* actual = [NSMutableString stringWithString:@"<g transform='scale(4)'>"];
    NSMutableString* reference = [NSMutableString stringWithString:@"<g transform='scale(4)'>"];
    [actual appendFormat:marker, @"m", @"context-stroke", @"context-fill"];
    NSArray* strokes = @[@"black", @"blue", @"red", @"gray"];
    NSArray* fills = @[@"black", @"red", @"none", @"blue"];
    for(NSUInteger index = 0; index < strokes.count; index++) {
        NSString* identifier = [NSString stringWithFormat:@"m%lu", (unsigned long)index];
        [reference appendFormat:marker, identifier, strokes[index], fills[index]];
        NSString* path = [NSString stringWithFormat:
            @"<path d='M10,%lu 30,%lu h10' stroke='%@' fill='%@' stroke-width='%g' style='marker:url(#%%@)'/>",
            (unsigned long)(index + 1) * 10, (unsigned long)(index + 1) * 10,
            strokes[index], fills[index], index == 3 ? 1.5 : 1.0];
        [actual appendFormat:path, @"m"];
        [reference appendFormat:path, identifier];
    }
    [actual appendString:@"</g>"];
    [reference appendString:@"</g>"];
    [self compareBody:actual referenceBody:reference name:@"marker-context-colors" tolerance:.025];
}

- (void)testMarkerViewportClippingMatchesWebKit
{
    for(NSString* overflow in @[@"", @"overflow='hidden'", @"overflow='visible'", @"overflow='scroll'"]) {
        for(NSString* viewBox in @[@"", @"viewBox='5 5 10 20' preserveAspectRatio='xMaxYMin slice'"]) {
            NSString* body = [NSString stringWithFormat:
                @"<defs><marker id='m' markerWidth='20' markerHeight='14' refX='8' refY='7' "
                 "markerUnits='userSpaceOnUse' orient='auto' %@ %@>"
                 "<rect x='-10' y='-10' width='40' height='40' fill='orange'/>"
                 "<circle cx='8' cy='7' r='5' fill='navy'/></marker></defs>"
                 "<path d='M60 50L130 100L220 50' fill='none' stroke='red' stroke-width='3' style='marker:url(#m)'/>",
                overflow, viewBox];
            [self compareBody:body name:[NSString stringWithFormat:@"marker-clip-%@-%@", overflow, viewBox] tolerance:.025];
        }
    }
}

- (void)testNestedViewportClippingMatchesWebKit
{
    for(NSString* overflow in @[@"", @"overflow='hidden'", @"overflow='visible'", @"overflow='auto'", @"overflow='scroll'",
                                @"overflow='inherit'", @"overflow='invalid'", @"style='overflow:clip'", @"style='overflow:visible'"]) {
        for(NSString* viewBox in @[@"", @"viewBox='5 10 40 20' preserveAspectRatio='xMaxYMin slice'"]) {
            NSString* body = [NSString stringWithFormat:
                @"<g transform='translate(40 30) rotate(12)'><svg x='20' y='10' width='120' height='80' %@ %@>"
                 "<rect x='-30' y='-30' width='220' height='160' fill='orange'/>"
                 "<circle cx='25' cy='20' r='15' fill='navy'/></svg></g>", overflow, viewBox];
            [self compareBody:body name:[NSString stringWithFormat:@"nested-clip-%@-%@", overflow, viewBox] tolerance:.025];
        }
    }
}

- (void)testImageSliceOverflowMatchesWebKit
{
    NSString* image = @"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII=";
    for(NSString* overflow in @[@"hidden", @"visible", @"scroll"]) {
        NSString* body = [NSString stringWithFormat:
            @"<image x='80' y='40' width='80' height='100' preserveAspectRatio='xMidYMid slice' overflow='%@' href='%@'/>",
            overflow, image];
        NSString* reference = body;
        if([overflow isEqualToString:@"visible"]) {
            // WebKit clips raster images even when overflow is visible.
            // Draw the fitted image at its full size to verify the overflow.
            reference = [NSString stringWithFormat:
                @"<image x='20' y='40' width='200' height='100' preserveAspectRatio='none' href='%@'/>", image];
        }
        [self compareBody:body referenceBody:reference
                     name:[@"image-slice-overflow-" stringByAppendingString:overflow] tolerance:.025];
    }
}

- (void)testEmbeddedSVGFilterSourcesMatchWebKit
{
    NSString* source = @"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='80' viewBox='0 0 100 80'>"
                       "<rect width='100' height='30' fill='#2075bc'/>"
                       "<path d='M0 30H40V80H0Z' fill='#f08030'/></svg>";
    NSString* encoded = [[source dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    NSArray* effects = @[@"<feOffset/>",
                         @"<feComposite in2='SourceGraphic' operator='arithmetic' k1='2'/>",
                         @"<feConvolveMatrix kernelMatrix='1 2 0 0 0 0 0 0 -1' divisor='8'/>"];
    for(NSUInteger index = 0; index < effects.count; index++) {
        NSString* body = [NSString stringWithFormat:
            @"<defs><filter id='f' x='0' y='0' width='100%%' height='100%%'>%@</filter></defs>"
             "<image x='20' y='20' width='160' height='150' href='data:image/svg+xml;base64,%@'/>"
             "<image x='210' y='20' width='160' height='150' href='data:image/svg+xml;base64,%@' filter='url(#f)'/>",
             effects[index], encoded, encoded];
        [self compareBody:body name:[NSString stringWithFormat:@"embedded-filter-source-%lu", (unsigned long)index] tolerance:.025];
    }
    NSString* imageFilter = [NSString stringWithFormat:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='20' y='20' width='160' height='150'>"
         "<feImage href='data:image/svg+xml;base64,%@'/></filter></defs>"
         "<rect x='20' y='20' width='160' height='150' filter='url(#f)'/>", encoded];
    [self compareBody:imageFilter name:@"embedded-feimage-source" tolerance:.025];
    [self compareBody:@"<defs><filter id='f' filterUnits='userSpaceOnUse'>"
                       "<feFlood x='50' y='50' width='100' height='100' flood-color='green' flood-opacity='.5'/></filter></defs>"
                       "<use filter='url(#f)'/>"
                 name:@"empty-use-flood" tolerance:.025];
}

- (void)testEmbeddedSVGWithoutViewBoxMatchesWebKit
{
    NSArray* dimensions = @[@"width='100' height='80'", @"width='100' height='80' viewBox='0 0 100 80'"];
    NSArray* alignments = @[@"xMidYMid meet", @"none", @"xMaxYMin slice"];
    for(NSUInteger index = 0; index < dimensions.count; index++) {
        NSString* source = [NSString stringWithFormat:
            @"<svg xmlns='http://www.w3.org/2000/svg' %@><rect width='100' height='30' fill='navy'/>"
             "<path d='M0 30H40V80H0Z' fill='orange'/></svg>", dimensions[index]];
        NSString* encoded = [[source dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
        for(NSString* alignment in alignments) {
            NSString* body = [NSString stringWithFormat:
                @"<defs><filter id='f'><feOffset/></filter></defs>"
                 "<image x='20' y='20' width='160' height='150' preserveAspectRatio='%@' href='data:image/svg+xml;base64,%@'/>"
                 "<image x='210' y='20' width='160' height='150' preserveAspectRatio='%@' href='data:image/svg+xml;base64,%@' filter='url(#f)'/>",
                 alignment, encoded, alignment, encoded];
            NSString* reference = body;
            if(index == 1 && [alignment containsString:@"slice"]) {
                // WebKit fits this external SVG with meet despite the slice value.
                // Use an inline viewport to verify the requested crop.
                reference = @"<defs><filter id='f'><feOffset/></filter></defs>"
                            "<svg x='20' y='20' width='160' height='150' viewBox='0 0 100 80' preserveAspectRatio='xMaxYMin slice'>"
                            "<rect width='100' height='30' fill='navy'/><path d='M0 30H40V80H0Z' fill='orange'/></svg>"
                            "<svg x='210' y='20' width='160' height='150' viewBox='0 0 100 80' preserveAspectRatio='xMaxYMin slice' filter='url(#f)'>"
                            "<rect width='100' height='30' fill='navy'/><path d='M0 30H40V80H0Z' fill='orange'/></svg>";
            }
            [self compareBody:body
                referenceBody:reference
                         name:[NSString stringWithFormat:@"embedded-size-%lu-%@", (unsigned long)index, alignment]
                    tolerance:.025];
        }
    }
}

- (void)testPatternCoordinateSystemsMatchWebKit
{
    NSArray* patterns = @[
        @"patternUnits='userSpaceOnUse' width='20' height='20'",
        @"patternUnits='userSpaceOnUse' x='5' y='7' width='20' height='20'",
        @"width='.25' height='.25'",
        @"width='.25' height='.25' patternTransform='rotate(20) skewX(30) scale(1 .5)'",
        @"patternUnits='userSpaceOnUse' width='10%' height='20%'",
        @"width='.25' height='.25' viewBox='0 0 20 20' patternContentUnits='objectBoundingBox'"
    ];
    for(NSUInteger index = 0; index < patterns.count; index++) {
        NSString* body = [NSString stringWithFormat:
            @"<defs><pattern id='p' %@><circle cx='10' cy='10' r='10' fill='navy'/></pattern></defs>"
             "<rect x='30' y='20' width='160' height='120' fill='url(#p)'/>", patterns[index]];
        [self compareBody:body name:[NSString stringWithFormat:@"pattern-coordinates-%lu", (unsigned long)index] tolerance:.025];
        NSString* stroked = [body stringByReplacingOccurrencesOfString:@"fill='url(#p)'"
                                                            withString:@"fill='url(#p)' stroke='green' stroke-width='12'"];
        [self compareBody:stroked name:[NSString stringWithFormat:@"pattern-stroked-coordinates-%lu", (unsigned long)index] tolerance:.025];
    }
}

- (void)testBasicShapeClippingMatchesWebKit
{
    NSArray* clips = @[
        @"circle()", @"circle() fill-box", @"circle() stroke-box",
        @"circle(35% at 30% 60%) fill-box", @"fill-box circle(farthest-side at left top)",
        @"ellipse(40% 30%) fill-box", @"ellipse(closest-side farthest-side at 25% 70%)",
        @"fill-box", @"circle(2em at center) fill-box", @"circle(0) fill-box"
    ];
    for(NSUInteger index = 0; index < clips.count; index++) {
        NSString* body = [NSString stringWithFormat:
            @"<rect x='40' y='30' width='180' height='120' fill='navy' stroke='green' stroke-width='12'"
             " font-size='18' clip-path='%@'/><rect x='300' y='20' width='20' height='20' fill='red'/>", clips[index]];
        [self compareBody:body name:[NSString stringWithFormat:@"clip-shape-%lu", (unsigned long)index] tolerance:.025];
    }
    [self compareBody:@"<defs><clipPath id='c' clipPathUnits='objectBoundingBox'><circle cx='.5' cy='.5' r='.5'/></clipPath></defs>"
                       "<rect x='40' y='30' width='180' height='120' fill='navy' stroke='green' stroke-width='12' clip-path='url(#c)'/>"
                 name:@"clip-object-bounds-stroke" tolerance:.025];
}

- (void)testViewBoxClippingMatchesExplicitGeometry
{
    NSString* content = @"<rect x='110' y='110' width='80' height='80' stroke='green' stroke-width='10' %@/>";
    NSString* body = [NSString stringWithFormat:content, @"clip-path='circle() view-box'"];
    NSString* reference = [@"<defs><clipPath id='c'><circle cx='200' cy='100' r='100'/></clipPath></defs>"
        stringByAppendingString:[NSString stringWithFormat:content, @"clip-path='url(#c)'"]];
    [self compareBody:body referenceBody:reference name:@"clip-viewbox-explicit" tolerance:.025];
    body = @"<svg x='30' width='200' height='200' viewBox='0 0 20 20'>"
            "<rect x='11' y='11' width='8' height='8' stroke='green' clip-path='circle() view-box'/></svg>";
    reference = @"<svg x='30' width='200' height='200' viewBox='0 0 20 20'>"
                 "<defs><clipPath id='c'><circle cx='10' cy='10' r='10'/></clipPath></defs>"
                 "<rect x='11' y='11' width='8' height='8' stroke='green' clip-path='url(#c)'/></svg>";
    [self compareBody:body referenceBody:reference name:@"clip-nested-viewbox-explicit" tolerance:.025];
}

- (void)testStrokedPatternMatchesExplicitGeometry
{
    NSString* body = @"<defs><pattern id='p' viewBox='0 0 10 10' width='.25' height='.25'>"
                     "<polygon points='0,0 2,5 0,10 5,8 10,10 8,5 10,0 5,2'/></pattern></defs>"
                     "<circle cx='180' cy='90' r='40' fill='none' stroke-width='20' stroke='url(#p)'/>";
    NSString* reference = [body stringByReplacingOccurrencesOfString:@"width='.25' height='.25'"
                                                          withString:@"patternUnits='userSpaceOnUse' x='140' y='50' width='20' height='20'"];
    [self compareBody:[NSString stringWithFormat:@"<g transform='translate(-200 -80) scale(2)'>%@</g>", body]
        referenceBody:[NSString stringWithFormat:@"<g transform='translate(-200 -80) scale(2)'>%@</g>", reference]
                 name:@"pattern-stroke-explicit" tolerance:.025];
}

- (void)testTransformOriginsMatchWebKit
{
    [self compareBody:@"<style>.box {transform-origin:center;transform-box:fill-box}</style>"
                       "<rect class='box' x='20' y='30' width='80' height='50' transform='rotate(35)' fill='navy'/>"
                       "<rect x='140' y='30' width='80' height='50' transform-origin='50% 50%' transform='rotate(15)' fill='red'/>"
                       "<g style='transform-origin:bottom right;transform-box:fill-box' transform='rotate(-15)'>"
                       "<rect x='250' y='100' width='80' height='50' fill='green'/></g>"
                 name:@"transform-origins" tolerance:.025];
}

- (void)testLinearGradientSpreadTransformAndAlpha
{
    [self compareBody:@"<defs><linearGradient id='base' x1='25%' x2='45%' spreadMethod='repeat'>"
                       "<stop offset='.2' stop-color='red' stop-opacity='.3'/>"
                       "<stop offset='.8' stop-color='blue'/></linearGradient>"
                       "<linearGradient id='g' href='#base' gradientTransform='rotate(25 .5 .5)'/></defs>"
                       "<rect x='20' y='10' width='350' height='170' fill='url(#g)'/>"
                 name:@"spread-transform-alpha-reference" tolerance:.025];
}

- (void)testCSSGeometryMatchesWebKit
{
    [self compareBody:@"<style>.box {x:20px;y:20px;width:90px;height:60px;rx:12px;ry:8px}"
                       "circle {cx:180px;cy:55px;r:30px} ellipse {cx:290px;cy:55px;rx:40px;ry:25px}</style>"
                       "<rect class='box' width='2' height='2' fill='navy'/>"
                       "<circle cx='1' cy='1' r='1' fill='red'/><ellipse rx='1' ry='1' fill='green'/>"
                       "<rect x='10' y='110' width='120' height='60' style='x:20px;width:90px;rx:auto;ry:15px' fill='purple'/>"
                 name:@"css-geometry" tolerance:.025];
}

- (void)testCSSGeometryInheritanceAndCascadeMatchesWebKit
{
    [self compareBody:@"<style>#a {r:30px!important} circle {r:10px} .position {cx:50%;cy:50%}</style>"
                       "<circle id='a' class='position' cx='20' cy='20' r='5' style='r:20px' fill='navy'/>"
                       "<g font-family='Helvetica' font-size='20' style='r:1em;cx:50px;cy:50px'>"
                       "<circle font-size='50' style='r:inherit;cx:inherit;cy:inherit' fill='red'/></g>"
                       "<rect x='280' y='30' width='80' height='70' style='width:100px;width:invalid' fill='green'/>"
                 name:@"css-geometry-cascade" tolerance:.025];
}

- (void)testCSSGeometryPercentagesMatchesWebKit
{
    [self compareBody:@"<circle style='cx:25%;cy:50%;r:12%' fill='navy'/>"
                       "<ellipse style='cx:60%;cy:50%;rx:12%;ry:auto' fill='green'/>"
                 name:@"css-geometry-percentages" tolerance:.025];
}

- (void)testCSSGeometryImagesAndUseMatchWebKit
{
    // WebKit does not apply these image and use positioning declarations.
    // Compare against explicit geometry for those elements.
    [self compareBody:@"<style>.sized {x:20px;y:20px;width:120px;height:auto} use {x:200px;y:30px;width:100px;height:100px}</style>"
                       "<image class='sized' width='10' height='10' href='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII='/>"
                       "<symbol id='s' viewBox='0 0 10 10'><rect width='10' height='10' fill='navy'/></symbol>"
                       "<use href='#s' x='5' y='5' width='10' height='10'/>"
        referenceBody:@"<image x='20' y='20' width='120' height='60' href='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII='/>"
                       "<rect x='200' y='30' width='100' height='100' fill='navy'/>"
                 name:@"css-geometry-image-use" tolerance:.025];
}

- (void)testAutomaticRadiiMatchesWebKit
{
    [self compareBody:@"<ellipse cx='50' cy='60' rx='30'/><ellipse cx='130' cy='60' ry='30'/>"
                       "<ellipse cx='210' cy='60' rx='auto' ry='15%'/><rect x='260' y='20' width='100' height='80' ry='20'/>"
                       "<rect x='20' y='120' width='150' height='60' rx='10%'/><ellipse cx='240' cy='150' rx='2em'/>"
                 name:@"automatic-radii" tolerance:.025];
}

- (void)testAutomaticImagesMatchWebKit
{
    NSString* href = @"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII=";
    [self compareBody:[NSString stringWithFormat:
        @"<image x='10' y='10' width='120' href='%@'/><image x='150' y='10' height='60' href='%@'/>"
         "<image x='10' y='90' width='auto' height='30%%' href='%@'/>"
         "<image x='170' y='90' width='8em' height='auto' href='%@'/>"
         "<image width='0' height='100' href='%@'/>", href, href, href, href, href]
                 name:@"automatic-images" tolerance:.025];
}

- (void)testPathLengthMatchesWebKit
{
    NSArray* shapes = @[@"<circle cx='55' cy='55' r='40' pathLength='100'/>",
                        @"<ellipse cx='170' cy='55' rx='60' ry='35' pathLength='100'/>",
                        @"<rect x='255' y='15' width='120' height='80' rx='15' pathLength='100'/>",
                        @"<path d='M10 150 Q100 70 190 150 T380 150' pathLength='100'/>"];
    for(NSUInteger index = 0; index < shapes.count; index++) {
        // Thin curved dashes have the same rasterization difference without
        // calibration. Retain the baseline alongside the pathLength case.
        NSString* baseline = [shapes[index] stringByReplacingOccurrencesOfString:@" pathLength='100'" withString:@""];
        [self compareBody:[NSString stringWithFormat:@"<g fill='none' stroke='navy' stroke-width='4' stroke-dasharray='20 12' stroke-dashoffset='8'>%@</g>", baseline]
                     name:[NSString stringWithFormat:@"path-length-baseline-%lu", index] tolerance:.07];
        [self compareBody:[NSString stringWithFormat:@"<g fill='none' stroke='navy' stroke-width='4' stroke-dasharray='5 3' stroke-dashoffset='2'>%@</g>", shapes[index]]
                     name:[NSString stringWithFormat:@"path-length-curve-%lu", index] tolerance:.07];
    }
}

- (void)testZeroPathLengthUsesLimitingPattern
{
    // WebKit currently makes pathLength=0 strokes solid, including percentages.
    // Compare the specified limit against equivalent explicit geometry instead.
    [self compareBody:@"<g fill='none' stroke='navy' stroke-width='16'>"
                       "<path d='M10 30H390' pathLength='0' stroke-dasharray='1 1'/>"
                       "<path d='M10 70H390' pathLength='0' stroke-dasharray='0 1'/>"
                       "<path d='M10 110H390' pathLength='0' stroke-dasharray='1 1' stroke-dashoffset='1'/>"
                       "<path d='M10 150H390' pathLength='0' stroke-dasharray='10% 5%'/></g>"
        referenceBody:@"<g fill='none' stroke='navy' stroke-width='16'>"
                       "<path d='M10 30H390'/>"
                       "<path d='M10 150H390' stroke-dasharray='10% 5%'/></g>"
                 name:@"path-length-zero" tolerance:.025];
}

- (void)testPathLengthTransformsMatchWebKit
{
    NSString* body = @"<g stroke='navy' stroke-width='8' stroke-dasharray='4 2' fill='none'>"
                       "<path d='M10 20H180' transform='scale(2)' pathLength='85'/>"
                       "<path d='M10 50H180' transform='scale(2)' pathLength='85' vector-effect='non-scaling-stroke'/>"
                       "<path d='M10 80H180' transform='scale(2 1.5)' pathLength='85' vector-effect='non-scaling-stroke'/></g>";
    NSString* baseline = [[body stringByReplacingOccurrencesOfString:@" pathLength='85'" withString:@""]
                          stringByReplacingOccurrencesOfString:@"stroke-dasharray='4 2'" withString:@"stroke-dasharray='8 4'"];
    [self compareBody:baseline name:@"path-length-transform-baseline" tolerance:.05];
    [self compareBody:body name:@"path-length-transforms" tolerance:.05];
}

- (void)webView:(WKWebView*)webView
didFinishNavigation:(WKNavigation*)navigation
{
    [self.navigation fulfill];
}

- (void)webView:(WKWebView*)webView
didFailNavigation:(WKNavigation*)navigation
        withError:(NSError*)error
{
    XCTFail(@"WebKit navigation failed: %@", error);
    [self.navigation fulfill];
}

- (CGContextRef)newBitmap
{
    return [self newBitmapWithScale:1];
}

- (CGContextRef)newBitmapWithScale:(CGFloat)scale
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    bitmapInfo |= kCGBitmapByteOrder32Big;
    CGContextRef context = CGBitmapContextCreate(NULL, 400 * scale, 200 * scale,
                                                 8, 1600 * scale, space,
                                                 bitmapInfo);
    CGColorSpaceRelease(space);
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 400 * scale, 200 * scale));
    return context;
}

- (NSData*)pixelsForImage:(CGImageRef)image
{
    CGContextRef context = [self newBitmap];
    CGContextDrawImage(context, CGRectMake(0, 0, 400, 200), image);
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context)
                                    length:400 * 200 * 4];
    CGContextRelease(context);
    return pixels;
}

- (void)saveImage:(CGImageRef)image
             name:(NSString*)name
{
    NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    NSData* png = [rep representationUsingType:NSBitmapImageFileTypePNG
                                    properties:@{}];
    NSString* directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"IJSVGPaintOrderComparisons"];
    [NSFileManager.defaultManager createDirectoryAtPath:directory
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
    [png writeToFile:[directory stringByAppendingPathComponent:[name stringByAppendingString:@".png"]]
          atomically:YES];
    XCTAttachment* attachment = [XCTAttachment attachmentWithData:png
                                            uniformTypeIdentifier:@"public.png"];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
    NSLog(@"Symbol comparison image: %@",
          [directory stringByAppendingPathComponent:name]);
}

- (void)compareBody:(NSString*)body
               name:(NSString*)name
          tolerance:(double)tolerance
{
    [self compareBody:body referenceBody:body name:name tolerance:tolerance];
}

- (void)compareBody:(NSString*)body
      referenceBody:(NSString*)referenceBody
               name:(NSString*)name
          tolerance:(double)tolerance
{
    NSString* svgString = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' "
                                                      "width='400' height='200' viewBox='0 0 400 200'>"
                                                      "%@</svg>",
                                                     body];
    self.navigation = [self expectationWithDescription:@"WebKit loaded"];
    WKWebViewConfiguration* configuration = [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 400, 200)
                                      configuration:configuration];
    self.webView.navigationDelegate = self;
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400,
                                                                   200)
                                              styleMask:NSWindowStyleMaskBorderless
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.releasedWhenClosed = NO;
    self.window.contentView = self.webView;
    NSString* html = [NSString stringWithFormat:@"<!doctype html><html><head><style>html,body{margin:0;"
                                                 "padding:0;background:white;}svg{display:block;}</style>"
                                                 "</head><body>%@</body></html>",
                                                [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' "
                                                                            "width='400' height='200' viewBox='0 0 400 200'>%@</svg>",
                                                                           referenceBody]];
    [self.webView loadHTMLString:html
                         baseURL:nil];
    [self waitForExpectations:@[self.navigation]
                      timeout:20];
    XCTestExpectation* snapshot = [self expectationWithDescription:@"WebKit snapshot"];
    __block NSImage* referenceImage = nil;
    WKSnapshotConfiguration* snapshotConfiguration = [[WKSnapshotConfiguration alloc] init];
    snapshotConfiguration.rect = CGRectMake(0, 0, 400, 200);
    snapshotConfiguration.snapshotWidth = @400;
    [self.webView takeSnapshotWithConfiguration:snapshotConfiguration
                              completionHandler:^(NSImage* image, NSError* error) {
                                  XCTAssertNil(error);
                                  referenceImage = image;
                                  [snapshot fulfill];
                              }];
    [self waitForExpectations:@[snapshot]
                      timeout:20];
    XCTAssertNotNil(referenceImage);
    if(!referenceImage) {
        return;
    }
    CGRect rect = CGRectMake(0, 0, 400, 200);
    CGImageRef reference = [referenceImage CGImageForProposedRect:&rect
                                                          context:nil
                                                            hints:nil];
    NSData* expected = [self pixelsForImage:reference];
    CGContextRef referenceContext = [self newBitmap];
    CGContextDrawImage(referenceContext, CGRectMake(0, 0, 400, 200), reference);
    CGImageRef normalizedReference = CGBitmapContextCreateImage(referenceContext);
    [self saveImage:normalizedReference
               name:[name stringByAppendingString:@"-webkit"]];
    CGImageRelease(normalizedReference);
    CGContextRelease(referenceContext);

    IJSVG* svg = [[IJSVG alloc] initWithSVGString:svgString];
    if(self.defaultFontSize > 0) {
        IJSVGRenderingOptions* options = svg.renderingOptions;
        options.defaultFontSize = self.defaultFontSize;
        svg.renderingOptions = options;
    }
    CGFloat renderScale = (CGFloat)CGImageGetWidth(reference) / 400;
    CGContextRef context = [self newBitmapWithScale:renderScale];
    CGContextTranslateCTM(context, 0, 200 * renderScale);
    CGContextScaleCTM(context, renderScale, -renderScale);
    [svg drawInRect:CGRectMake(0, 0, 400, 200)
            context:context];
    CGImageRef rendered = CGBitmapContextCreateImage(context);
    NSData* actual = [self pixelsForImage:rendered];
    [self saveImage:rendered
               name:[name stringByAppendingString:@"-ijsvg"]];
    CGImageRelease(rendered);
    CGContextRelease(context);

    const uint8_t* a = actual.bytes;
    const uint8_t* b = expected.bytes;
    double difference = 0;
    NSUInteger ink = 0;
    for(NSUInteger i = 0; i < actual.length; i += 4) {
        if(MIN(MIN(a[i], a[i + 1]), a[i + 2]) < 245 || MIN(MIN(b[i], b[i + 1]),
                                                           b[i + 2]) < 245) {
            ink++;
            difference += (abs(a[i] - b[i]) + abs(a[i + 1] - b[i + 1]) + abs(a[i + 2] - b[i + 2])) /
                (3. * 255.);
        }
    }
    double error = ink ? difference / ink : 0;
    NSLog(@"WebKit paint-order/font comparison %@: mean ink error %.4f (%lu pixels)", name,
          error, (unsigned long)ink);
    XCTAssertGreaterThan(ink, 10);
    XCTAssertLessThan(error, tolerance,
                      @"%@ differs from WebKit; inspect attached PNGs", name);
    self.webView.navigationDelegate = nil;
    self.webView = nil;
    [self.window close];
    self.window = nil;
}


- (void)testPaintOrdersMatchWebKit
{
    for(NSString* order in @[@"normal", @"fill stroke markers", @"fill markers stroke",
                             @"stroke fill markers", @"stroke markers fill", @"markers fill stroke",
                             @"markers stroke fill", @"stroke", @"markers", @"stroke markers"]) {
        NSString* body = [NSString stringWithFormat:
            @"<defs><marker id='m' markerUnits='userSpaceOnUse' markerWidth='50' markerHeight='50'"
             " refX='25' refY='25'><circle cx='25' cy='25' r='22' fill='lime'/></marker></defs>"
             "<g paint-order='%@'><path d='M60 50H300V150H60Z' fill='orange' stroke='navy'"
             " stroke-width='25' marker-start='url(#m)' marker-mid='url(#m)'/></g>", order];
        [self compareBody:body name:[@"order-" stringByAppendingString:order] tolerance:.025];
    }
}

- (void)testPaintOrderWithEffectsMatchesWebKit
{
    [self compareBody:@"<defs><clipPath id='c'><rect x='30' y='20' width='280' height='150'/></clipPath>"
                       "<marker id='m' markerUnits='userSpaceOnUse' markerWidth='40' markerHeight='40'"
                       " refX='20' refY='20'><circle cx='20' cy='20' r='18' fill='lime'/></marker></defs>"
                       "<g transform='translate(20 10) scale(.9)' opacity='.6' clip-path='url(#c)'>"
                       "<path d='M40 40H300V140H40Z' fill='orange' stroke='navy' stroke-width='24'"
                       " vector-effect='non-scaling-stroke' style='paint-order:stroke markers fill'"
                       " marker-start='url(#m)' marker-mid='url(#m)'/></g>"
                 name:@"effects-and-non-scaling-stroke" tolerance:.025];
}

- (void)testTextPaintOrderMatchesWebKit
{
    [self compareBody:@"<g paint-order='stroke'><text x='30' y='130' font-family='Helvetica'"
                       " font-size='90' fill='orange' stroke='navy' stroke-width='10'>SVG</text></g>"
                 name:@"text-stroke-first" tolerance:.10];
    [self compareBody:@"<style>.under { paint-order:stroke; }</style>"
                       "<text x='30' y='130' font-family='Helvetica' font-size='90' fill='orange'"
                       " stroke='navy' stroke-width='10'><tspan class='under' paint-order='normal'>S</tspan>"
                       "<tspan style='paint-order:stroke'>VG</tspan></text>"
                 name:@"text-css-and-tspan" tolerance:.10];
}

- (void)testRelativeSymbolDimensionsMatchWebKit
{
    for(NSString* attributes in @[
        @"width='10em' height='5em' font-size='20'",
        @"width='20ex' height='10ex' font-size='20' font-family='Helvetica'",
        @"width='10em' height='5em' font-size='150%'",
        @"width='20ex' height='10ex' font-size='2ex' font-family='Times'",
        @"width='10em' height='5em' font-size='20' x='1em' y='1em'"]) {
        NSString* body = [NSString stringWithFormat:
            @"<symbol id='s' viewBox='0 0 20 10'>"
             "<rect width='20' height='10' fill='navy'/></symbol>"
             "<g font-size='16'><use href='#s' %@/></g>", attributes];
        [self compareBody:body name:[@"relative-" stringByAppendingString:attributes] tolerance:.025];
    }
}

- (void)testFontRelativeStrokeWidthsMatchWebKit
{
    [self compareBody:@"<defs><marker id='m' markerWidth='2' markerHeight='2' refY='1'>"
                       "<rect width='2' height='2' fill='lime'/></marker></defs>"
                       "<g font-size='20' font-family='Helvetica' stroke='navy' stroke-width='1em'>"
                       "<path d='M30 40H300' font-size='40' marker-end='url(#m)'/>"
                       "<path d='M30 100H300' stroke-width='1em' font-size='30'/>"
                       "<path d='M30 160H300' stroke-width='2ex'/></g>"
                 name:@"font-relative-strokes" tolerance:.025];
}

- (void)compareFontRelativeBody:(NSString*)template name:(NSString*)name
{
    self.defaultFontSize = 24;
    for(NSString* unit in @[@"em", @"ex"]) {
        NSString* body = [NSString stringWithFormat:@"<g font-family='Helvetica'>%@</g>",
            [template stringByReplacingOccurrencesOfString:@"em" withString:unit]];
        NSString* reference = [NSString stringWithFormat:@"<g font-size='24'>%@</g>", body];
        [self compareBody:body referenceBody:reference name:[name stringByAppendingString:unit] tolerance:.025];
    }
}

- (void)testFontRelativeShapesAndDashesMatchWebKit
{
    [self compareFontRelativeBody:
        @"<rect x='1em' y='1em' width='3em' height='2em' rx='.5em' ry='.25em' fill='navy'/>"
         "<circle cx='6em' cy='2em' r='1em' fill='orange'/><ellipse cx='10em' cy='2em' rx='2em' ry='1em' fill='green'/>"
         "<line x1='1em' y1='5em' x2='13em' y2='5em' stroke='navy' stroke-width='.25em' stroke-dasharray='1em .5em' stroke-dashoffset='.25em'/>"
                 name:@"shapes-dashes-"];
}

- (void)testFontRelativePaintServersMatchWebKit
{
    [self compareFontRelativeBody:
        @"<defs><linearGradient id='g' gradientUnits='userSpaceOnUse' x1='1em' y1='1em' x2='6em' y2='4em'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient>"
         "<radialGradient id='r' gradientUnits='userSpaceOnUse' cx='3em' cy='3em' fx='2em' fy='2em' r='2em'><stop stop-color='orange'/><stop offset='1' stop-color='navy'/></radialGradient>"
         "<pattern id='p' patternUnits='userSpaceOnUse' width='1em' height='1em'><rect width='.5em' height='1em' fill='green'/></pattern></defs>"
         "<rect width='6em' height='6em' fill='url(#g)'/><g transform='translate(150)'><rect width='6em' height='6em' fill='url(#r)'/></g>"
         "<g transform='translate(300)'><rect width='3em' height='6em' fill='url(#p)'/></g>"
                 name:@"paint-servers-"];
}

- (void)testFontRelativeClipsMasksAndFiltersMatchWebKit
{
    [self compareFontRelativeBody:
        @"<defs><clipPath id='c'><rect x='1em' y='1em' width='3em' height='4em'/></clipPath>"
         "<mask id='m' maskUnits='userSpaceOnUse' x='1em' y='1em' width='3em' height='4em'><rect width='100%' height='100%' fill='white'/></mask>"
         "<filter id='f' filterUnits='userSpaceOnUse' x='1em' y='1em' width='3em' height='4em'><feFlood flood-color='orange' x='1.5em' y='1.5em' width='2em' height='3em'/></filter></defs>"
         "<rect width='120' height='150' fill='navy' clip-path='url(#c)'/>"
         "<g transform='translate(130)'><rect width='120' height='150' fill='green' mask='url(#m)'/></g>"
         "<g transform='translate(260)'><rect width='120' height='150' filter='url(#f)'/></g>"
                 name:@"clips-masks-filters-"];
}

- (void)testFontRelativeNestedViewportsAndMarkersMatchWebKit
{
    [self compareFontRelativeBody:
        @"<defs><marker id='m' markerUnits='userSpaceOnUse' markerWidth='2em' markerHeight='2em' refX='1em' refY='1em'><circle cx='1em' cy='1em' r='.75em' fill='orange'/></marker></defs>"
         "<svg x='1em' y='1em' width='5em' height='4em' viewBox='0 0 20 20'><rect width='20' height='20' fill='navy'/></svg>"
         "<path d='M200 80H320' stroke='green' stroke-width='.25em' marker-end='url(#m)'/>"
                 name:@"viewports-markers-"];
}

- (void)testFontRelativeImagesMatchWebKit
{
    NSString* data = @"iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII=";
    [self compareFontRelativeBody:[NSString stringWithFormat:
        @"<image x='1em' y='1em' width='5em' height='3em' href='data:image/png;base64,%@'/>", data]
                            name:@"images-"];
}

- (void)testSymbolOwnRelativeDimensionsMatchWebKit
{
    [self compareBody:@"<symbol id='s' width='10em' height='5em' font-size='20' viewBox='0 0 20 10'>"
                       "<rect width='20' height='10' fill='navy'/></symbol><use href='#s' x='20' y='20'/>"
                 name:@"symbol-own-em" tolerance:.025];
}

@end
