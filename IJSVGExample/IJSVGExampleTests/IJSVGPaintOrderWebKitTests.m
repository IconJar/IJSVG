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
