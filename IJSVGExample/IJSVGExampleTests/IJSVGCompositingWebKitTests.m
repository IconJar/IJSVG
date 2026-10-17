//
//  IJSVGCompositingWebKitTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <WebKit/WebKit.h>
#import <XCTest/XCTest.h>

@interface IJSVGCompositingWebKitTests : XCTestCase <WKNavigationDelegate>

@property (nonatomic, strong) XCTestExpectation* navigation;
@property (nonatomic, strong) WKWebView* webView;
@property (nonatomic, strong) NSWindow* window;
@property (nonatomic, copy) NSString* expectedDifference;
@property (nonatomic, copy) NSString* referenceHTML;

@end

@implementation IJSVGCompositingWebKitTests

- (void)compareCSSFilterValues:(NSArray<NSString*>*)values name:(NSString*)name
{
    NSMutableString* body = [NSMutableString stringWithString:@"<rect width='400' height='200' fill='#d0c0b0'/>"];
    NSMutableString* html = [NSMutableString stringWithString:@"<div style='position:absolute;width:400px;height:200px;background:#d0c0b0'></div>"];
    for (NSUInteger index = 0; index < values.count; index++) {
        // WebKit applies CSS functions to HTML wrappers but ignores them on SVG groups.
        [html appendFormat:@"<div style='position:absolute;left:%lupx;top:%lupx;width:200px;height:100px;filter:%@'><svg xmlns='http://www.w3.org/2000/svg' width='200' height='100'><rect x='12' y='12' width='120' height='65' fill='#b04020'/><rect x='65' y='25' width='115' height='60' fill='#2060d0' fill-opacity='.6'/><path d='M 15 85 L 155 15' fill='none' stroke='#309050' stroke-width='9'/></svg></div>", (unsigned long)(index % 2 * 200), (unsigned long)(index / 2 * 100), values[index]];
        [body appendFormat:@"<g transform='translate(%lu %lu)' color-interpolation-filters='linearRGB'><g style='filter:%@'><rect x='12' y='12' width='120' height='65' fill='#b04020'/><rect x='65' y='25' width='115' height='60' fill='#2060d0' fill-opacity='.6'/><path d='M 15 85 L 155 15' fill='none' stroke='#309050' stroke-width='9'/></g></g>", (unsigned long)(index % 2 * 200), (unsigned long)(index / 2 * 100), values[index]];
    }
    self.referenceHTML = html;
    [self compareBody:body name:name tolerance:.008];
}

- (void)testCSSBlurMatchesWebKit
{
    [self compareCSSFilterValues:@[ @"blur()", @"blur(.5px)", @"blur(2px)", @"blur(5px)" ] name:@"css-blur"];
}

- (void)testCSSDropShadowMatchesWebKit
{
    [self compareCSSFilterValues:@[ @"drop-shadow(5px 3px)", @"drop-shadow(-4px 2px 2px #4070a080)", @"drop-shadow(red 2px -3px 1px)", @"drop-shadow(0 0 4px rgba(0,0,255,.5))" ] name:@"css-shadow"];
}

- (void)testCSSSpatialChainsMatchWebKit
{
    [self compareCSSFilterValues:@[ @"blur(1px) drop-shadow(4px 2px 1px red)", @"drop-shadow(4px 2px 1px red) blur(1px)", @"drop-shadow(2px 2px blue) drop-shadow(-3px -2px red)", @"blur(2px) invert(.6)" ] name:@"css-spatial-chains"];
}

- (void)testCSSSpatialInheritedValuesAndClippingMatchWebKit
{
    NSString* shape = @"<rect x='40' y='35' width='180' height='90' fill='#2070a0' fill-opacity='.7'/><path d='M45 130L210 40' stroke='#b04020' stroke-width='8'/>";
    self.referenceHTML = [NSString stringWithFormat:@"<div style='position:absolute;left:15px;top:10px;width:270px;height:150px;overflow:hidden;opacity:.75'><div style='color:purple;font-size:24px;filter:drop-shadow(.5em -.25em .125em) blur(.0625em)'><svg xmlns='http://www.w3.org/2000/svg' width='400' height='200'>%@</svg></div></div>", shape];
    NSString* body = [NSString stringWithFormat:@"<defs><clipPath id='clip'><rect width='270' height='150'/></clipPath></defs><g transform='translate(15 10)' opacity='.75' clip-path='url(#clip)'><g color='purple' font-size='24' filter='drop-shadow(.5em -.25em .125em) blur(.0625em)'>%@</g></g>", shape];
    [self compareBody:body name:@"css-spatial-inherited-clip" tolerance:.008];
}

- (void)testCSSCalculatedHueMatchesWebKit
{
    [self compareCSSFilterValues:@[ @"hue-rotate(calc(.5turn - 90deg))", @"hue-rotate(min(180deg, .25turn))", @"hue-rotate(clamp(0deg, 2rad, 90deg))", @"hue-rotate(calc(100grad * 2))" ] name:@"css-calculated-hue"];
}

- (void)testCSSBrightnessMatchesWebKit
{
    [self compareCSSFilterValues:@[ @"brightness()", @"brightness(0)", @"brightness(45%)", @"brightness(1.8)" ] name:@"css-brightness"];
}

- (void)testCSSContrastMatchesWebKit
{
    [self compareCSSFilterValues:@[ @"contrast()", @"contrast(0)", @"contrast(.45)", @"contrast(1.8)" ] name:@"css-contrast"];
}

- (void)testCSSGrayscaleMatchesWebKit
{
    [self compareCSSFilterValues:@[ @"grayscale()", @"grayscale(0)", @"grayscale(45%)", @"grayscale(2)" ] name:@"css-grayscale"];
}

- (void)testCSSHueRotateMatchesWebKit
{
    [self compareCSSFilterValues:@[ @"hue-rotate()", @"hue-rotate(90deg)", @"hue-rotate(-.25turn)", @"hue-rotate(100grad)" ] name:@"css-huerotate"];
}

- (void)testCSSInvertMatchesWebKit
{
    [self compareCSSFilterValues:@[ @"invert()", @"invert(0)", @"invert(45%)", @"invert(2)" ] name:@"css-invert"];
}

- (void)testCSSOpacityMatchesWebKit
{
    [self compareCSSFilterValues:@[ @"opacity()", @"opacity(0)", @"opacity(45%)", @"opacity(2)" ] name:@"css-opacity"];
}

- (void)testCSSSaturateMatchesWebKit
{
    [self compareCSSFilterValues:@[ @"saturate()", @"saturate(0)", @"saturate(45%)", @"saturate(2)" ] name:@"css-saturate"];
}

- (void)testCSSSepiaMatchesWebKit
{
    [self compareCSSFilterValues:@[ @"sepia()", @"sepia(0)", @"sepia(45%)", @"sepia(2)" ] name:@"css-sepia"];
}

- (void)testCSSFilterChainsMatchWebKit
{
    [self compareCSSFilterValues:@[ @"invert(.8) brightness(.7)", @"brightness(.7) invert(.8)", @"grayscale(.4) sepia(.3) saturate(1.8) hue-rotate(35deg)", @"opacity(.6) contrast(1.4)" ] name:@"css-chains"];
}

- (void)testCSSFiltersMixedWithURLMatchWebKit
{
    NSString* body = @"<defs><filter id='f' x='-50%' y='-50%' width='200%' height='200%' color-interpolation-filters='sRGB'><feOffset dx='12' dy='8'/><feComponentTransfer><feFuncR type='linear' slope='.5'/></feComponentTransfer></filter></defs><rect width='400' height='200' fill='#d0c0b0'/><g filter='invert(.8) url(#f) opacity(.7)'><rect x='30' y='30' width='140' height='120' fill='#b04020'/></g><g filter='url(#f) invert(.8) opacity(.7)'><rect x='220' y='30' width='140' height='120' fill='#b04020'/></g>";
    self.referenceHTML = @"<div style='position:absolute;width:400px;height:200px;background:#d0c0b0'></div><svg width='0' height='0'><defs><filter id='f' x='-50%' y='-50%' width='200%' height='200%' color-interpolation-filters='sRGB'><feOffset dx='12' dy='8'/><feComponentTransfer><feFuncR type='linear' slope='.5'/></feComponentTransfer></filter></defs></svg><div style='position:absolute;width:400px;height:200px;filter:invert(.8) url(#f) opacity(.7)'><svg width='400' height='200'><rect x='30' y='30' width='140' height='120' fill='#b04020'/></svg></div><div style='position:absolute;width:400px;height:200px;filter:url(#f) invert(.8) opacity(.7)'><svg width='400' height='200'><rect x='220' y='30' width='140' height='120' fill='#b04020'/></svg></div>";
    [self compareBody:body name:@"css-url-chains" tolerance:.008];
}

- (void)testCSSFilterVariablesAndClippingMatchWebKit
{
    NSString* body = @"<style>.filtered { --amount: 40%; filter: grayscale(var(--amount)) brightness(calc(.5 + .25)); }</style><defs><clipPath id='c'><circle cx='170' cy='100' r='70'/></clipPath></defs><rect width='400' height='200' fill='#c0d0e0'/><g class='filtered' opacity='.7' clip-path='url(#c)' transform='translate(20 5) rotate(5 170 100)'><rect x='40' y='20' width='260' height='150' fill='#e04020'/><rect x='140' y='60' width='180' height='100' fill='#2070d0' fill-opacity='.5'/></g>";
    self.referenceHTML = @"<div style='position:absolute;width:400px;height:200px;background:#c0d0e0'></div><div style='width:400px;height:200px;transform:translate(20px,5px) rotate(5deg);transform-origin:170px 100px;opacity:.7;clip-path:circle(70px at 170px 100px)'><div style='--amount:40%;filter:grayscale(var(--amount)) brightness(calc(.5 + .25))'><svg width='400' height='200'><rect x='40' y='20' width='260' height='150' fill='#e04020'/><rect x='140' y='60' width='180' height='100' fill='#2070d0' fill-opacity='.5'/></svg></div></div>";
    [self compareBody:body name:@"css-variables-clip" tolerance:.008];
}

- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)navigation
{
    [self.navigation fulfill];
}

- (void)webView:(WKWebView*)webView didFailNavigation:(WKNavigation*)navigation withError:(NSError*)error
{
    XCTFail(@"WebKit navigation failed: %@", error);
    [self.navigation fulfill];
}

- (void)testATMInnerShadowsMatchWebKit
{
    NSString* path = [@(__FILE__).stringByDeletingLastPathComponent stringByAppendingPathComponent:@"Fixtures/atm-sign-color.svg"];
    NSError* error = nil;
    NSString* svg = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(svg);
    if (svg == nil) {
        return;
    }
    NSString* body = [NSString stringWithFormat:@"<g transform='translate(100 0) scale(6.25)'>%@</g>", svg];

    // Allow small rasterizer and blur differences; the clipped blue strip
    // exceeds this tolerance.
    [self compareBody:body name:@"atm-inner-shadows" tolerance:0.011];
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
    CGContextRef context = CGBitmapContextCreate(NULL, 400 * scale, 200 * scale, 8, 1600 * scale, space, bitmapInfo);
    CGColorSpaceRelease(space);
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 400 * scale, 200 * scale));
    return context;
}

- (NSData*)pixelsForImage:(CGImageRef)image
{
    CGContextRef context = [self newBitmap];
    CGContextDrawImage(context, CGRectMake(0, 0, 400, 200), image);
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:400 * 200 * 4];
    CGContextRelease(context);
    return pixels;
}

- (void)saveImage:(CGImageRef)image name:(NSString*)name
{
    NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    NSData* png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSString* directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"IJSVGCompositingComparisons"];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    [png writeToFile:[directory stringByAppendingPathComponent:[name stringByAppendingString:@".png"]] atomically:YES];
    XCTAttachment* attachment = [XCTAttachment attachmentWithData:png uniformTypeIdentifier:@"public.png"];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
    NSLog(@"Symbol comparison image: %@", [directory stringByAppendingPathComponent:name]);
}

- (void)compareBody:(NSString*)body name:(NSString*)name tolerance:(double)tolerance
{
    [self compareBody:body referenceBody:body name:name tolerance:tolerance];
}

- (void)compareBody:(NSString*)body referenceBody:(NSString*)referenceBody name:(NSString*)name tolerance:(double)tolerance
{
    NSString* svgString = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' "
                                                      "width='400' height='200' viewBox='0 0 400 200'>"
                                                      "%@</svg>",
        body];
    self.navigation = [self expectationWithDescription:@"WebKit loaded"];
    WKWebViewConfiguration* configuration = [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 400, 200) configuration:configuration];
    self.webView.navigationDelegate = self;
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 200) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    self.window.releasedWhenClosed = NO;
    self.window.contentView = self.webView;
    NSString* html = [NSString stringWithFormat:@"<!doctype html><html><head><style>html,body{margin:0;"
                                                 "padding:0;background:white;}svg{display:block;}</style>"
                                                 "</head><body>%@</body></html>",
        [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' "
                                    "width='400' height='200' viewBox='0 0 400 200'>%@</svg>",
            referenceBody]];
    if (self.referenceHTML != nil) {
        html = [NSString stringWithFormat:@"<!doctype html><html><head><style>html,body{margin:0;padding:0;background:white;}svg{display:block;}</style></head><body>%@</body></html>", self.referenceHTML];
        self.referenceHTML = nil;
    }
    [self.webView loadHTMLString:html baseURL:nil];
    [self waitForExpectations:@[ self.navigation ] timeout:20];
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
    [self waitForExpectations:@[ snapshot ] timeout:20];
    XCTAssertNotNil(referenceImage);
    if (!referenceImage) {
        return;
    }
    CGRect rect = CGRectMake(0, 0, 400, 200);
    CGImageRef reference = [referenceImage CGImageForProposedRect:&rect context:nil hints:nil];
    NSData* expected = [self pixelsForImage:reference];
    CGContextRef referenceContext = [self newBitmap];
    CGContextDrawImage(referenceContext, CGRectMake(0, 0, 400, 200), reference);
    CGImageRef normalizedReference = CGBitmapContextCreateImage(referenceContext);
    [self saveImage:normalizedReference name:[name stringByAppendingString:@"-webkit"]];
    CGImageRelease(normalizedReference);
    CGContextRelease(referenceContext);

    IJSVG* svg = [[IJSVG alloc] initWithSVGString:svgString];
    CGFloat renderScale = (CGFloat)CGImageGetWidth(reference) / 400;
    CGContextRef context = [self newBitmapWithScale:renderScale];
    CGContextTranslateCTM(context, 0, 200 * renderScale);
    CGContextScaleCTM(context, renderScale, -renderScale);
    [svg drawInRect:CGRectMake(0, 0, 400, 200) context:context];
    CGImageRef rendered = CGBitmapContextCreateImage(context);
    NSData* actual = [self pixelsForImage:rendered];
    [self saveImage:rendered name:[name stringByAppendingString:@"-ijsvg"]];
    CGImageRelease(rendered);
    CGContextRelease(context);

    const uint8_t* a = actual.bytes;
    const uint8_t* b = expected.bytes;
    double difference = 0;
    NSUInteger ink = 0;
    for (NSUInteger i = 0; i < actual.length; i += 4) {
        if (MIN(MIN(a[i], a[i + 1]), a[i + 2]) < 245 || MIN(MIN(b[i], b[i + 1]), b[i + 2]) < 245) {
            ink++;
            difference += (abs(a[i] - b[i]) + abs(a[i + 1] - b[i + 1]) + abs(a[i + 2] - b[i + 2])) / (3. * 255.);
        }
    }
    double error = ink ? difference / ink : 0;
    NSLog(@"WebKit symbol comparison %@: mean ink error %.4f (%lu pixels)", name, error, (unsigned long)ink);
    XCTAssertGreaterThan(ink, 10);
    void (^assertPixels)(void) = ^{
        XCTAssertLessThan(error, tolerance, @"%@ differs from WebKit; inspect attached PNGs", name);
    };
    if (self.expectedDifference != nil) {
        XCTExpectFailureInBlock(self.expectedDifference, assertPixels);
    } else {
        assertPixels();
    }
    self.webView.navigationDelegate = nil;
    self.webView = nil;
    [self.window close];
    self.window = nil;
}

- (void)testExplicitIsolationMatchesWebKit
{
    for (NSString* isolation in @[ @"isolate", @"auto", @"initial", @"unset" ]) {
        NSString* body = [NSString stringWithFormat:@"<rect width='400' height='200' fill='#4080c0'/>"
                                                     "<g style='isolation:%@' transform='translate(20 10)'>"
                                                     "<rect x='30' y='20' width='180' height='140' "
                                                     "fill='orange' style='mix-blend-mode:multiply'/>"
                                                     "<rect x='120' y='60' width='220' height='100' "
                                                     "fill='lime' style='mix-blend-mode:screen'/>"
                                                     "</g>",
            isolation];
        [self compareBody:body name:[@"isolation-" stringByAppendingString:isolation] tolerance:.025];
    }
}

- (void)testIsolationDoesNotInheritImplicitly
{
    for (NSString* isolation in @[ @"auto", @"inherit" ]) {
        NSString* body = [NSString stringWithFormat:@"<g style='isolation:isolate'><rect width='400' height='200' "
                                                    @"fill='#4080c0'/>"
                                                     "<g style='isolation:%@'><rect x='30' y='20' width='300' "
                                                     "height='140'"
                                                     " fill='orange' style='mix-blend-mode:multiply'/></g></g>",
            isolation];
        [self compareBody:body name:[@"nested-isolation-" stringByAppendingString:isolation] tolerance:.025];
    }
}

- (void)testIsolatedSymbolMatchesWebKit
{
    [self compareBody:@"<rect width='400' height='200' fill='#4080c0'/>"
                       "<symbol id='s' viewBox='0 0 40 20' style='isolation:isolate'>"
                       "<rect width='40' height='20' fill='orange' "
                       "style='mix-blend-mode:multiply'/>"
                       "</symbol><use href='#s' x='40' y='20' width='280' height='140'/>"
                 name:@"symbol-isolation"
            tolerance:.025];
}

- (void)testGroupBlendModesMatchWebKit
{
    for (NSString* mode in @[ @"multiply", @"screen", @"difference", @"overlay", @"darken", @"lighten", @"color-dodge", @"color-burn", @"hard-light", @"soft-light", @"exclusion", @"hue", @"saturation", @"color", @"luminosity" ]) {
        NSString* body = [NSString stringWithFormat:@"<rect width='400' height='200' fill='#4080c0'/>"
                                                     "<g style='mix-blend-mode:%@'>"
                                                     "<rect x='30' y='20' width='180' height='140' fill='#e06020'/>"
                                                     "<rect x='120' y='60' width='220' height='100' "
                                                     "fill='#20c080'/></g>",
            mode];
        [self compareBody:body name:mode tolerance:.025];
    }
}

- (void)testOrdinaryGroupsDoNotIsolateChildBlending
{
    [self compareBody:@"<rect width='400' height='200' fill='#4080c0'/>"
                       "<g transform='translate(30 20)'><g>"
                       "<rect width='280' height='140' fill='orange' "
                       "style='mix-blend-mode:multiply'/>"
                       "</g></g>"
                 name:@"ordinary-group-backdrop"
            tolerance:.025];
}

- (void)testBlendedShapeCompositesFillAndStrokeTogether
{
    [self compareBody:@"<rect width='400' height='200' fill='#4080c0'/>"
                       "<rect x='70' y='50' width='220' height='100' "
                       "fill='orange' stroke='lime'"
                       " stroke-width='30' style='mix-blend-mode:multiply'/>"
                 name:@"fill-stroke-blending"
            tolerance:.025];
}

- (void)testBlendedGroupEffectsMatchWebKit
{
    for (NSString* effect in @[ @"clip-path='url(#c)'", @"mask='url(#m)'", @"filter='url(#f)'", @"opacity='.6'", @"clip-path='url(#c)' mask='url(#m)' opacity='.7'" ]) {
        NSString* body = [NSString stringWithFormat:@"<defs><clipPath id='c'><rect x='40' y='20' width='200' "
                                                    @"height='140'/></clipPath>"
                                                     "<mask id='m'><rect width='400' height='200' fill='white' "
                                                     "opacity='.7'/></mask>"
                                                     "<filter id='f'><feOffset dx='10' dy='5'/></filter></defs>"
                                                     "<rect width='400' height='200' fill='#4080c0'/>"
                                                     "<g style='mix-blend-mode:multiply' %@>"
                                                     "<rect x='30' y='20' width='180' height='140' fill='orange'/>"
                                                     "<rect x='120' y='60' width='220' height='100' fill='lime'/></g>",
            effect];
        [self compareBody:body name:[@"effects-" stringByAppendingString:effect] tolerance:.025];
    }
}

- (void)testBlendedSymbolMatchesWebKit
{
    [self compareBody:@"<rect width='400' height='200' fill='#4080c0'/>"
                       "<symbol id='s' viewBox='0 0 40 20' style='mix-blend-mode:multiply'>"
                       "<rect width='30' height='20' fill='orange'/>"
                       "<rect x='10' y='5' width='30' height='15' fill='lime'/></symbol>"
                       "<use href='#s' x='40' y='20' width='280' height='140'/>"
                 name:@"symbol-blend"
            tolerance:.025];
}

- (void)testNestedBlendAndOpacityMatchWebKit
{
    [self compareBody:@"<rect width='400' height='200' fill='#4080c0'/>"
                       "<g style='mix-blend-mode:multiply' transform='translate(20 10)'>"
                       "<rect width='160' height='140' fill='orange'/>"
                       "<g opacity='.6'><rect x='80' y='30' width='180' height='130' "
                       "fill='red'/>"
                       "<rect x='120' y='60' width='180' height='100' fill='lime'/></g></g>"
                 name:@"nested-blend-opacity"
            tolerance:.025];
}

@end
