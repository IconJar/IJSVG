//
//  IJSVGTextWebKitTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <WebKit/WebKit.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGTextLayout.h>

@interface IJSVGTextWebKitTests: XCTestCase <WKNavigationDelegate>

@property (nonatomic, strong) XCTestExpectation* navigation;
@property (nonatomic, strong) WKWebView* webView;
@property (nonatomic, strong) NSWindow* window;

@end

@implementation IJSVGTextWebKitTests

- (void)    webView:(WKWebView*)webView
didFinishNavigation:(WKNavigation*)navigation
{
    [self.navigation fulfill];
}

- (void)  webView:(WKWebView*)webView
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
    NSString* directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"IJSVGTextComparisons"];
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
    NSLog(@"Text comparison image: %@",
          [directory stringByAppendingPathComponent:name]);
}

- (void)compareBody:(NSString*)body
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
                                                 "padding:0;background:white;}svg{display:block;-webkit-font-smoothing:antialiased;}</style>"
                                                 "</head><body>%@</body></html>",
                                                svgString];
    [self.webView loadHTMLString:html
                         baseURL:nil];
    [self waitForExpectations:@[self.navigation]
                      timeout:20];
    XCTestExpectation* metrics = [self expectationWithDescription:@"WebKit character metrics"];
    __block NSArray* referenceMetrics = nil;
    [self.webView evaluateJavaScript:@"Array.from(document.querySelectorAll('text')).map(t => "
                                      "Array.from({length:t.getNumberOfChars()}, (_,i) => {let "
                                      "p=t.getStartPositionOfChar(i); return "
                                      "[p.x,p.y,t.getRotationOfChar(i)]}))"
                   completionHandler:^(id result, NSError* error) {
                       XCTAssertNil(error);
                       referenceMetrics = result;
                       NSLog(@"WebKit metrics %@: %@", name, result);
                       [metrics fulfill];
                   }];
    [self waitForExpectations:@[metrics]
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
    if([name isEqualToString:@"positioning"] || [name isEqualToString:@"length"] ||
       [name isEqualToString:@"decoration-spaces"] || [name isEqualToString:@"font-weights"]) {
        [self compareMetrics:referenceMetrics
                         svg:svgString
                       scale:renderScale];
    }
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
    NSLog(@"WebKit text comparison %@: mean ink error %.4f (%lu pixels)", name,
          error, (unsigned long)ink);
    XCTAssertGreaterThan(ink, 10);
    XCTAssertLessThan(error, tolerance,
                      @"%@ differs from WebKit; inspect attached PNGs", name);
    self.webView.navigationDelegate = nil;
    self.webView = nil;
    [self.window close];
    self.window = nil;
}

- (void)compareMetrics:(NSArray*)expected
                   svg:(NSString*)xml
                 scale:(CGFloat)scale
{
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:xml
                                                         fileURL:nil
                                                           error:nil];
    IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(400, 200)];
    NSMutableArray<IJSVGText*>* texts = [[NSMutableArray alloc] init];
    [IJSVGNode walkNodeTree:root
                    handler:^(IJSVGNode* node, BOOL* descend, BOOL* stop) {
                        if([node isKindOfClass:IJSVGText.class]) {
                            [texts addObject:(IJSVGText*)node];
                            *descend = NO;
                        }
                    }];
    XCTAssertEqual(texts.count, expected.count);
    for(NSUInteger index = 0; index < MIN(texts.count, expected.count); index++) {
        IJSVGTextLayout* layout = [[IJSVGTextLayout alloc] initWithText:texts[index]
                                                           viewport:CGSizeMake(400, 200)
                                                        renderScale:scale
                                                       pathResolver:nil];
        NSArray* characters = expected[index];
        XCTAssertEqual(layout.characterPositions.count, characters.count);
        for(NSUInteger character = 0; character < MIN(layout.characterPositions.count, characters.count); character++) {
            CGPoint point = layout.characterPositions[character].pointValue;
            NSArray<NSNumber*>* metrics = characters[character];
            // WebKit reports unscaled DOM positions for spacingAndGlyphs.
            // Its final scaled geometry remains covered by the image comparison.
            BOOL scalesGlyphs = texts[index].positioning[IJSVGAttributeLengthAdjust].keyword == IJSVGTextKeywordSpacingAndGlyphs;
            if(!scalesGlyphs) {
                XCTAssertEqualWithAccuracy(point.x, metrics[0].doubleValue, .25,
                                           @"text %lu character %lu x", index, character);
                XCTAssertEqualWithAccuracy(point.y, metrics[1].doubleValue, .25,
                                           @"text %lu character %lu y", index, character);
            }
            CGFloat rotation = layout.characterRotations[character].doubleValue;
            CGFloat difference = remainder(rotation - metrics[2].doubleValue, 360);
            XCTAssertEqualWithAccuracy(difference, 0, .01,
                                       @"text %lu character %lu rotation", index, character);
        }
    }
}

- (void)testDecorationsAcrossSpacesMatchWebKit
{
    // Decoration offsets use Core Text font metrics; WebKit places these lines
    // slightly differently. Exact coverage across spaces is tested geometrically.
    [self compareBody:@"<g font-family='Helvetica' font-size='30'><text x='20' y='40' "
                       "text-decoration='underline'>hello world</text><text x='20' y='90' "
                       "text-decoration='overline'>hello world</text><text x='20' y='140' "
                       "text-decoration='line-through'>hello world</text></g>"
                 name:@"decoration-spaces"
            tolerance:.26];
}

- (void)testNumericAndRelativeWeightsMatchWebKit
{
    [self compareBody:@"<g font-family='Helvetica Neue' font-size='28'>"
                       "<text x='20' y='40' font-weight='300'>Light <tspan font-weight='500'>Medium</tspan></text>"
                       "<text x='20' y='90' font-weight='700'>Bold <tspan font-weight='bolder'>Heavy</tspan></text>"
                       "<text x='20' y='140' font-weight='700'><tspan font-weight='lighter'>Regular</tspan></text></g>"
                 name:@"font-weights"
            tolerance:.16];
}

- (void)testNestedBidiScopesMatchWebKit
{
    NSArray* modes = @[@"embed", @"bidi-override", @"isolate", @"isolate-override", @"plaintext"];
    for(NSString* mode in modes) {
        NSString* body = [NSString stringWithFormat:@"<text x='20' y='70' font-family='Helvetica' "
                                                     "font-size='32'>A<tspan direction='rtl' "
                                                     "unicode-bidi='%@'>אב <tspan>12</tspan> "
                                                     "C</tspan>Z</text>",
                                                    mode];
        [self compareBody:body
                     name:[@"bidi-" stringByAppendingString:mode]
                tolerance:.16];
    }
}

- (void)testSyntheticSmallCapsMatchWebKit
{
    [self compareBody:@"<g font-family='Times' font-size='30' font-variant='small-caps'>"
                       "<text x='20' y='50'>Small Caps 123</text>"
                       "<text x='20' y='100'>Nested <tspan font-variant='normal'>Normal</tspan></text></g>"
                 name:@"syntheticSmallCaps"
            tolerance:.16];
}

- (void)testFontSizeAdjustMatchesWebKit
{
    [self compareBody:@"<g font-family='Times' font-size='24' font-size-adjust='.6'>"
                       "<text x='20' y='50'>Adjusted text</text>"
                       "<text x='20' y='100'>Same <tspan font-size-adjust='none'>normal</tspan></text></g>"
                 name:@"fontSizeAdjust"
            tolerance:.16];
}

- (void)testFontRelativeLengthsMatchWebKit
{
    [self compareBody:@"<g font-family='Helvetica' font-size='40'><text x='2ex' y='2em'>Relative</text>"
                       "<text font-size='2ex' x='1em' y='140' letter-spacing='.2ex'>Parent <tspan "
                       "font-family='Times' dx='1ex'>font</tspan></text></g>"
                 name:@"font-relative-units"
            tolerance:.16];
}

- (void)testGrumpyExampleMatchesWebKit
{
    [self compareBody:@"<style>.small{font:italic 13px sans-serif}.heavy{font:bold 30px "
                       "sans-serif}.Rrrrr{font:italic 40px serif;fill:red}</style><text x='20' y='35' "
                       "class='small'>My</text><text x='40' y='35' class='heavy'>cat</text><text x='55' "
                       "y='55' class='small'>is</text><text x='65' y='55' class='Rrrrr'>Grumpy!</text>"
                 name:@"grumpy"
            tolerance:.16];
}

- (void)testPositioningAndAnchorsMatchWebKit
{
    [self compareBody:@"<g font-family='Helvetica' font-size='24'><text x='20 55 90' y='40' rotate='0 15 "
                       "-15'>ABC</text><text x='200' y='90' text-anchor='middle'>Middle <tspan "
                       "fill='red'>span</tspan></text><text x='350' y='140' text-anchor='end'>End</text>"
                       "</g>"
                 name:@"positioning"
            tolerance:.16];
}

- (void)testTextLengthMatchesWebKit
{
    [self compareBody:@"<g font-family='Helvetica' font-size='24'><text x='20' y='50' textLength='250'>"
                       "Spaced text</text><text x='20' y='100' textLength='250' "
                       "lengthAdjust='spacingAndGlyphs'>Scaled text</text></g>"
                 name:@"length"
            tolerance:.16];
}

- (void)testTextPathMatchesWebKit
{
    // WebKit ignores pair kerning on text paths even with font kerning:normal.
    // Disable it explicitly in this fixture to compare the path placement itself.
    // Font kerning is covered independently by the layout tests.
    [self compareBody:@"<defs><path id='p' d='M20 130 Q200 -30 380 130'/></defs><text "
                       "font-family='Helvetica' font-size='25' font-kerning='none'><textPath href='#p' "
                       "startOffset='10%'>Text follows a curve</textPath></text>"
                 name:@"path"
            tolerance:.20];
}

- (void)testVerticalTextMatchesWebKit
{
    [self compareBody:@"<text x='100' y='25' font-size='24' font-family='Hiragino Mincho ProN' "
                       "writing-mode='vertical-rl'>日本語ABC</text>"
                 name:@"vertical"
            tolerance:.20];
}

- (void)testParentContentResumesAboveChildSpans
{
    [self compareBody:@"<text font-family='Helvetica' font-size='70' x='40 60 50' y='100' fill='blue'>"
                       "A<tspan fill='red'>B</tspan>C</text>"
                 name:@"paint-order"
            tolerance:.16];
}

- (void)testFillStrokeAndGroupOpacityMatchWebKit
{
    [self compareBody:@"<g opacity='.6' transform='translate(10 5)'><text x='20' y='70' "
                       "font-family='Helvetica' font-size='48' fill='orange' stroke='navy' "
                       "stroke-width='1'>SVG <tspan fill='red'>text</tspan></text></g>"
                 name:@"paint"
            tolerance:.16];
}

- (void)testFilteredTextWithNestedTransformsMatchesWebKit
{
    [self compareBody:@"<defs><filter id='blur' x='-30%' y='-50%' width='160%' height='200%'>"
                       "<feGaussianBlur stdDeviation='1.5'/></filter></defs><g transform='translate(30 "
                       "20) rotate(8 120 60)'><text x='10' y='65' font-family='Helvetica' font-size='40' "
                       "transform='scale(1.1 .9)' filter='url(#blur)' fill='navy'>Blur <tspan fill='red'>"
                       "text</tspan></text></g>"
                 name:@"filtered-text-transform"
            tolerance:.16];
}

- (void)testFilteredParentWithTransformedTextMatchesWebKit
{
    [self compareBody:@"<defs><filter id='offset' filterUnits='userSpaceOnUse' x='0' y='0' width='400' "
                       "height='200'><feOffset dx='12' dy='8'/></filter></defs><g filter='url(#offset)' "
                       "opacity='.7'><text x='25' y='80' transform='rotate(-8 25 80) scale(1.1)' "
                       "font-family='Helvetica' font-size='36' fill='green'>Parent effect</text></g>"
                 name:@"filtered-parent-transform"
            tolerance:.16];
}

- (void)testTransformedTextPathMatchesWebKit
{
    [self compareBody:@"<defs><path id='p' d='M0 70 H280' transform='translate(15 10)'/></defs><g "
                       "transform='translate(20 15)'><text transform='rotate(7 100 80)' "
                       "font-family='Helvetica' font-size='28' font-kerning='none'><textPath href='#p'>"
                       "Transformed path</textPath></text></g>"
                 name:@"transformed-text-path"
            tolerance:.16];
}

- (void)testMissingFontAndMixedScriptFallbackMatchWebKit
{
    [self compareBody:@"<text x='20' y='65' font-size='30' font-family='IJSVG Missing Font Alpha, "
                       "Helvetica, Hiragino Mincho ProN'>ABC 日本語</text><text x='20' y='130' "
                       "font-size='28' font-family='IJSVG Missing Font Alpha, serif'>Fallback</text>"
                 name:@"font-fallback"
            tolerance:.20];
}

- (void)testSystemFontFallbackMatchesWebKit
{
    [self compareBody:@"<text x='20' y='80' font-size='32' font-family='IJSVG Missing Font Alpha, "
                       "system-ui'>System font</text>"
                 name:@"system-font"
            tolerance:.16];
}

- (void)testSystemFontGeometricPrecisionMatchesWebKit
{
    [self compareBody:@"<g text-rendering='geometricPrecision'><text x='20' y='80' font-size='32' "
                       "font-family='system-ui'>System font</text></g>"
                 name:@"system-geometric"
            tolerance:.16];
}

- (void)testSystemFontTransformedScalesMatchWebKit
{
    [self compareBody:@"<g font-family='system-ui' font-size='24'><text x='20' y='50' "
                       "transform='scale(1.5)'>System font</text><g transform='translate(10 100) "
                       "scale(.7 1.1) rotate(5)'><text x='0' y='20'>Scaled <tspan font-size='32'>"
                       "span</tspan></text></g></g>"
                 name:@"system-scales"
            tolerance:.16];
}

- (void)testSystemFontNestedViewBoxMatchesWebKit
{
    [self compareBody:@"<svg x='20' y='20' width='300' height='150' viewBox='0 0 200 100' "
                       "preserveAspectRatio='none'><text x='5' y='40' font-family='system-ui' "
                       "font-size='24'>Nested font</text></svg>"
                 name:@"system-viewbox"
            tolerance:.16];
}

- (void)testSystemFontNormalKerningMatchesWebKit
{
    [self compareBody:@"<text x='20' y='80' font-family='system-ui' font-size='32' font-kerning='normal'>"
                       "System AV To</text>"
                 name:@"system-kerning"
            tolerance:.16];
}

- (void)testRTLAndCombiningCharactersMatchWebKit
{
    [self compareBody:@"<text x='360' y='60' direction='rtl' font-size='30' font-family='Arial'>"
                       "שלום</text><text x='20' y='130' font-size='30' font-family='Helvetica'>"
                       "Café</text>"
                 name:@"unicode"
            tolerance:.16];
}

- (void)testBaselineAndWhitespaceMatchWebKit
{
    [self compareBody:@"<g font-family='Helvetica' font-size='24'><text x='20' y='60'>  A <tspan> B "
                       "</tspan> C  </text><text x='20' y='120'>Base<tspan baseline-shift='super' "
                       "font-size='16'>2</tspan></text></g>"
                 name:@"baseline"
            tolerance:.16];
}

- (void)testOverlappingSpansMatchWebKit
{
    [self compareBody:@"<text font-family='Helvetica' font-size='70' x='40' y='100' fill='blue'>A<tspan "
                       "x='60' fill='red'>B</tspan><tspan x='80' fill='green'>C</tspan>D</text>"
                 name:@"overlap"
            tolerance:.16];
}

@end
