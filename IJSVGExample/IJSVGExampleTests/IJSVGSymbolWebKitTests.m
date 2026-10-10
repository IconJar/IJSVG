//
//  IJSVGSymbolWebKitTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <WebKit/WebKit.h>
#import <IJSVG/IJSVG.h>

@interface IJSVGSymbolWebKitTests: XCTestCase <WKNavigationDelegate>

@property (nonatomic, strong) XCTestExpectation* navigation;
@property (nonatomic, strong) WKWebView* webView;
@property (nonatomic, strong) NSWindow* window;
@property (nonatomic, copy) NSString* expectedDifference;

@end

@implementation IJSVGSymbolWebKitTests

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
    NSString* directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"IJSVGSymbolComparisons"];
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

- (void)testDefinitionsAndIndependentInstancesMatchesWebKit
{
    [self compareBody:@"<symbol id='s' viewBox='0 0 20 10'><rect width='20' height='10'/>"
                       "<circle cx='10' cy='5' r='3' fill='gold'/></symbol>"
                       "<use href='#s' x='20' y='20' width='100' height='100' fill='navy'/>"
                       "<use href='#s' x='160' y='30' width='180' height='120' fill='red'/>"
                 name:@"symbol-DefinitionsAndIndependentInstances"
            tolerance:.025];
}

- (void)testContentClipMatchesWebKit
{
    [self compareBody:@"<defs><clipPath id='c'><rect x='12' y='24' width='10' height='6'/></clipPath></defs>"
                       "<symbol id='s' viewBox='10 20 20 10' clip-path='url(#c)'>"
                       "<rect x='0' y='0' width='60' height='60' fill='navy'/></symbol>"
                       "<use href='#s' x='30' y='20' width='240' height='120' transform='rotate(8 150 80)'/>"
                 name:@"symbol-ContentClip"
            tolerance:.025];
}

- (void)testMaskAndGradientMatchesWebKit
{
    [self compareBody:@"<defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/>"
                       "</linearGradient><mask id='m' maskContentUnits='objectBoundingBox'>"
                       "<rect width='.7' height='1' fill='white'/></mask></defs><symbol id='s' viewBox='0 0 20 10'>"
                       "<rect width='20' height='10' fill='url(#g)' mask='url(#m)'/></symbol>"
                       "<use href='#s' x='30' y='30' width='300' height='120'/>"
                 name:@"symbol-MaskAndGradient"
            tolerance:.025];
}

- (void)testSymbolEffectsMatchesWebKit
{
    [self compareBody:@"<defs><clipPath id='c'><rect x='2' y='1' width='16' height='8'/></clipPath>"
                       "<filter id='f' x='-50%' y='-50%' width='200%' height='200%'><feOffset dx='1' dy='1'/>"
                       "</filter></defs>"
                       "<symbol id='s' viewBox='0 0 20 10' clip-path='url(#c)' filter='url(#f)' opacity='.6'>"
                       "<rect width='14' height='10' fill='navy'/><rect x='8' width='12' height='10' fill='red'/>"
                       "</symbol><use href='#s' x='30' y='30' width='280' height='120' opacity='.7'/>"
                 name:@"symbol-SymbolEffects"
            tolerance:.025];
}

- (void)testNestedSymbolsMatchesWebKit
{
    [self compareBody:@"<symbol id='a' viewBox='0 0 10 10'><rect x='-5' y='-5' width='20' height='20' fill='navy'/>"
                       "<circle cx='5' cy='5' r='3' fill='orange'/></symbol><symbol id='b' viewBox='0 0 30 20'>"
                       "<use href='#a' x='4' y='3' width='20' height='10' transform='rotate(12 14 8)'/></symbol>"
                       "<use href='#b' x='20' y='20' width='300' height='160'/>"
                 name:@"symbol-NestedSymbols"
            tolerance:.025];
}

- (void)testPercentageGeometryMatchesWebKit
{
    [self compareBody:@"<symbol id='s'><rect width='80%' height='60%' fill='navy'/>"
                       "<rect x='20%' y='30%' width='30%' height='40%' fill='orange'/></symbol>"
                       "<use href='#s' x='20' y='20' width='70%' height='70%'/>"
                 name:@"symbol-PercentageGeometry"
            tolerance:.025];
}

- (void)testDefaultDimensionsMatchesWebKit
{
    [self compareBody:@"<symbol id='s' viewBox='0 0 40 20'><rect x='5' y='5' width='25' height='10' fill='navy'/></symbol><use href='#s'/>"
                 name:@"symbol-DefaultDimensions"
            tolerance:.025];
}

- (void)testSymbolDimensionsMatchesWebKit
{
    [self compareBody:@"<symbol id='s' width='160' height='100' viewBox='0 0 20 10'>"
                       "<rect width='20' height='10' fill='navy'/></symbol><use href='#s' x='20' y='20'/>"
                       "<use href='#s' x='200' y='20' width='100'/>"
                 name:@"symbol-SymbolDimensions"
            tolerance:.025];
}

- (void)testReferencePointMatchesWebKit
{
    // WebKit currently ignores symbol refX/refY. Keep this strict expectation so
    // browser support changes require reviewing the difference.
    self.expectedDifference = @"WebKit ignores symbol reference points; SVG 2 positions the reference at the use origin.";
    [self compareBody:@"<symbol id='s' viewBox='10 20 20 10' refX='20' refY='25'>"
                       "<rect x='10' y='20' width='20' height='10' fill='navy'/></symbol>"
                       "<use href='#s' x='200' y='100' width='160' height='80'/>"
                 name:@"symbol-ReferencePoint"
            tolerance:.025];
}

- (void)testFontRelativeDimensionsMatchesWebKit
{
    // Known IJSVG limitation: symbol viewport lengths currently resolve without
    // the font metrics required by em/ex. Do not relax the pixel tolerance.
    self.expectedDifference = @"IJSVG symbol viewport dimensions do not yet resolve em/ex using font metrics.";
    [self compareBody:@"<symbol id='s' viewBox='0 0 20 10'><rect width='20' height='10' fill='navy'/></symbol>"
                       "<use href='#s' x='20' y='20' width='10em' height='5em' font-size='20'/>"
                 name:@"symbol-FontRelativeDimensions"
            tolerance:.025];
}

- (void)testInheritedStylesAndStrokeMatchesWebKit
{
    [self compareBody:@"<symbol id='s' viewBox='0 0 40 20'><path d='M5 15 L15 5 L25 15' fill='none'/>"
                       "<rect x='28' y='5' width='8' height='10' stroke='none'/></symbol>"
                       "<g fill='orange' stroke='navy' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>"
                       "<use href='#s' x='20' y='20' width='320' height='160'/></g>"
                 name:@"symbol-InheritedStylesAndStroke"
            tolerance:.025];
}

- (void)testNonScalingStrokeMatchesWebKit
{
    [self compareBody:@"<symbol id='s' viewBox='0 0 40 20'>"
                       "<rect x='5' y='5' width='30' height='10' fill='orange' stroke='navy' stroke-width='3' vector-effect='non-scaling-stroke'/>"
                       "</symbol>"
                       "<use href='#s' x='20' y='20' width='300' height='150' transform='rotate(7 160 90)'/>"
                 name:@"symbol-NonScalingStroke"
            tolerance:.025];
}

- (void)testReferencePointMatchesExplicitWebKitViewport
{
    // (20,25) maps to (80,40) within the 160x80 viewport. Positioning that
    // reference at (200,100) therefore places the viewport at (120,60).
    [self compareBody:@"<symbol id='s' viewBox='10 20 20 10' refX='20' refY='25'>"
                       "<rect x='10' y='20' width='20' height='10' fill='navy'/></symbol>"
                       "<use href='#s' x='200' y='100' width='160' height='80'/>"
         referenceBody:@"<svg x='120' y='60' width='160' height='80' viewBox='10 20 20 10'>"
                       "<rect x='10' y='20' width='20' height='10' fill='navy'/></svg>"
                  name:@"symbol-reference-explicit-viewport"
             tolerance:.025];
}

- (void)testWebKitReferencePointIsIgnored
{
    // Compare WebKit's symbol with references against IJSVG's unshifted
    // viewport to distinguish a browser omission from a placement bug.
    [self compareBody:@"<svg x='200' y='100' width='160' height='80' viewBox='10 20 20 10'>"
                       "<rect x='10' y='20' width='20' height='10' fill='navy'/></svg>"
         referenceBody:@"<symbol id='s' viewBox='10 20 20 10' refX='20' refY='25'>"
                       "<rect x='10' y='20' width='20' height='10' fill='navy'/></symbol>"
                       "<use href='#s' x='200' y='100' width='160' height='80'/>"
                  name:@"symbol-webkit-ignores-reference"
             tolerance:.025];
}

- (void)testAspectRatioMatchesWebKit
{
    for(NSString* aspect in @[@"none", @"xMinYMin meet", @"xMidYMid meet", @"xMaxYMax meet",
                              @"xMinYMin slice", @"xMidYMid slice", @"xMaxYMax slice"]) {
        NSString* body = [NSString stringWithFormat:@"<symbol id='s' viewBox='10 20 20 10' preserveAspectRatio='%@'>"
                                                     "<rect x='10' y='20' width='20' height='10' fill='navy'/>"
                                                     "<rect x='12' y='22' width='5' height='4' fill='orange'/></symbol>"
                                                     "<use href='#s' x='30' y='20' width='180' height='150'/>", aspect];
        [self compareBody:body
                     name:[@"symbol-aspect-" stringByAppendingString:aspect]
                tolerance:.025];
    }
}

- (void)testTransformsAndOverflowMatchWebKit
{
    for(NSString* overflow in @[@"hidden", @"visible"]) {
        for(NSString* transform in @[@"translate(15 10)", @"rotate(17 150 80)", @"matrix(-1 .2 .3 1 350 0)"]) {
            NSString* body = [NSString stringWithFormat:@"<symbol id='s' viewBox='0 0 20 10' overflow='%@'>"
                                                         "<rect x='-5' y='-5' width='30' height='20' fill='navy'/>"
                                                         "<circle cx='10' cy='5' r='4' fill='orange'/></symbol>"
                                                         "<use href='#s' x='60' y='50' width='180' height='90' transform='%@'/>",
                                                        overflow, transform];
            [self compareBody:body
                         name:[NSString stringWithFormat:@"symbol-%@-%@", overflow, transform]
                    tolerance:.025];
        }
    }
}

@end
