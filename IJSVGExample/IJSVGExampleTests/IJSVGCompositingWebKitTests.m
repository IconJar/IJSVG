//
//  IJSVGCompositingWebKitTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <WebKit/WebKit.h>
#import <IJSVG/IJSVG.h>

@interface IJSVGCompositingWebKitTests: XCTestCase <WKNavigationDelegate>

@property (nonatomic, strong) XCTestExpectation* navigation;
@property (nonatomic, strong) WKWebView* webView;
@property (nonatomic, strong) NSWindow* window;
@property (nonatomic, copy) NSString* expectedDifference;

@end

@implementation IJSVGCompositingWebKitTests

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
    NSString* directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"IJSVGCompositingComparisons"];
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
    NSLog(@"WebKit symbol comparison %@: mean ink error %.4f (%lu pixels)", name,
          error, (unsigned long)ink);
    XCTAssertGreaterThan(ink, 10);
    void (^assertPixels)(void) = ^{
        XCTAssertLessThan(error, tolerance,
                          @"%@ differs from WebKit; inspect attached PNGs", name);
    };
    if(self.expectedDifference != nil) {
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
    for(NSString* isolation in @[@"isolate", @"auto", @"initial", @"unset"]) {
        NSString* body = [NSString stringWithFormat:
            @"<rect width='400' height='200' fill='#4080c0'/>"
             "<g style='isolation:%@' transform='translate(20 10)'>"
             "<rect x='30' y='20' width='180' height='140' fill='orange' style='mix-blend-mode:multiply'/>"
             "<rect x='120' y='60' width='220' height='100' fill='lime' style='mix-blend-mode:screen'/>"
             "</g>", isolation];
        [self compareBody:body name:[@"isolation-" stringByAppendingString:isolation] tolerance:.025];
    }
}

- (void)testIsolationDoesNotInheritImplicitly
{
    for(NSString* isolation in @[@"auto", @"inherit"]) {
        NSString* body = [NSString stringWithFormat:
            @"<g style='isolation:isolate'><rect width='400' height='200' fill='#4080c0'/>"
             "<g style='isolation:%@'><rect x='30' y='20' width='300' height='140'"
             " fill='orange' style='mix-blend-mode:multiply'/></g></g>", isolation];
        [self compareBody:body name:[@"nested-isolation-" stringByAppendingString:isolation] tolerance:.025];
    }
}

- (void)testIsolatedSymbolMatchesWebKit
{
    [self compareBody:@"<rect width='400' height='200' fill='#4080c0'/>"
                       "<symbol id='s' viewBox='0 0 40 20' style='isolation:isolate'>"
                       "<rect width='40' height='20' fill='orange' style='mix-blend-mode:multiply'/>"
                       "</symbol><use href='#s' x='40' y='20' width='280' height='140'/>"
                 name:@"symbol-isolation" tolerance:.025];
}

- (void)testGroupBlendModesMatchWebKit
{
    for(NSString* mode in @[@"multiply", @"screen", @"difference", @"overlay", @"darken", @"lighten",
                            @"color-dodge", @"color-burn", @"hard-light", @"soft-light", @"exclusion",
                            @"hue", @"saturation", @"color", @"luminosity"]) {
        NSString* body = [NSString stringWithFormat:
            @"<rect width='400' height='200' fill='#4080c0'/>"
             "<g style='mix-blend-mode:%@'>"
             "<rect x='30' y='20' width='180' height='140' fill='#e06020'/>"
             "<rect x='120' y='60' width='220' height='100' fill='#20c080'/></g>", mode];
        [self compareBody:body name:mode tolerance:.025];
    }
}


- (void)testOrdinaryGroupsDoNotIsolateChildBlending
{
    [self compareBody:@"<rect width='400' height='200' fill='#4080c0'/>"
                       "<g transform='translate(30 20)'><g>"
                       "<rect width='280' height='140' fill='orange' style='mix-blend-mode:multiply'/>"
                       "</g></g>"
                 name:@"ordinary-group-backdrop" tolerance:.025];
}

- (void)testBlendedShapeCompositesFillAndStrokeTogether
{
    [self compareBody:@"<rect width='400' height='200' fill='#4080c0'/>"
                       "<rect x='70' y='50' width='220' height='100' fill='orange' stroke='lime'"
                       " stroke-width='30' style='mix-blend-mode:multiply'/>"
                 name:@"fill-stroke-blending" tolerance:.025];
}

- (void)testBlendedGroupEffectsMatchWebKit
{
    for(NSString* effect in @[@"clip-path='url(#c)'", @"mask='url(#m)'", @"filter='url(#f)'",
                              @"opacity='.6'", @"clip-path='url(#c)' mask='url(#m)' opacity='.7'"]) {
        NSString* body = [NSString stringWithFormat:
            @"<defs><clipPath id='c'><rect x='40' y='20' width='200' height='140'/></clipPath>"
             "<mask id='m'><rect width='400' height='200' fill='white' opacity='.7'/></mask>"
             "<filter id='f'><feOffset dx='10' dy='5'/></filter></defs>"
             "<rect width='400' height='200' fill='#4080c0'/>"
             "<g style='mix-blend-mode:multiply' %@>"
             "<rect x='30' y='20' width='180' height='140' fill='orange'/>"
             "<rect x='120' y='60' width='220' height='100' fill='lime'/></g>", effect];
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
                 name:@"symbol-blend" tolerance:.025];
}

- (void)testNestedBlendAndOpacityMatchWebKit
{
    [self compareBody:@"<rect width='400' height='200' fill='#4080c0'/>"
                       "<g style='mix-blend-mode:multiply' transform='translate(20 10)'>"
                       "<rect width='160' height='140' fill='orange'/>"
                       "<g opacity='.6'><rect x='80' y='30' width='180' height='130' fill='red'/>"
                       "<rect x='120' y='60' width='180' height='100' fill='lime'/></g></g>"
                 name:@"nested-blend-opacity" tolerance:.025];
}

@end
