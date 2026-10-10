#import <XCTest/XCTest.h>
#import <WebKit/WebKit.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGTextLayout.h>
#import <IJSVG/IJSVGParser.h>

static NSDictionary* IJSVGMDNCorpus(void)
{
    static NSDictionary* corpus;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL* url = [[NSBundle bundleForClass:NSClassFromString(@"IJSVGMDNWebKitTests")]
            URLForResource:@"corpus" withExtension:@"json" subdirectory:@"MDN"];
        NSData* data = url ? [NSData dataWithContentsOfURL:url] : nil;
        corpus = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    });
    return corpus;
}

static NSDictionary* IJSVGMDNPolicies(void)
{
    static NSDictionary* policies;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL* url = [[NSBundle bundleForClass:NSClassFromString(@"IJSVGMDNWebKitTests")]
            URLForResource:@"expectations" withExtension:@"json" subdirectory:@"MDN"];
        NSData* data = url ? [NSData dataWithContentsOfURL:url] : nil;
        policies = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    });
    return policies;
}

static CGContextRef IJSVGMDNBitmap(size_t width, size_t height, CGFloat background)
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space,
        (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if(bitmap) {
        CGContextSetRGBFillColor(bitmap, background, background, background, 1);
        CGContextFillRect(bitmap, CGRectMake(0, 0, width, height));
    }
    return bitmap;
}

// Each comparison owns its WebKit lifetime; timeout and navigation errors are
// infrastructure failures, never covered by a known pixel difference.
@interface IJSVGMDNComparison : NSObject <WKNavigationDelegate>
@property (nonatomic, strong) WKWebView* webView;
@property (nonatomic, strong) NSWindow* window;
@property (nonatomic, copy) NSString* xml;
@property (nonatomic, copy) void (^referenceTransform)(NSXMLDocument*);
@property (nonatomic) CGSize size;
@property (nonatomic) CGFloat background;
@property (nonatomic, copy) void (^fixtureTransform)(NSXMLDocument*);
@property (nonatomic) BOOL compareTextMetrics;
@property (nonatomic, strong) NSDictionary* metrics;
@property (nonatomic, copy) void (^completion)(NSDictionary*);
- (void)run:(NSString*)xml completion:(void (^)(NSDictionary*))completion;
@end

@implementation IJSVGMDNComparison

- (void)finish:(NSDictionary*)result
{
    if(!self.completion) return;
    void (^completion)(NSDictionary*) = self.completion;
    self.completion = nil;
    self.webView.navigationDelegate = nil;
    [self.webView stopLoading];
    [self.window close];
    self.window = nil;
    self.webView = nil;
    completion(result);
}

- (void)run:(NSString*)xml completion:(void (^)(NSDictionary*))completion
{
    self.completion = completion;
    NSError* error = nil;
    NSXMLDocument* document = [[NSXMLDocument alloc] initWithXMLString:xml options:0 error:&error];
    if(!document) {
        [self finish:@{@"error": error.description ?: @"Invalid fixture XML"}];
        return;
    }
    if(self.fixtureTransform != nil) {
        self.fixtureTransform(document);
    }
    NSXMLElement* root = document.rootElement;
    NSString* viewBox = [[root attributeForName:@"viewBox"] stringValue];
    NSScanner* scanner = [NSScanner scannerWithString:[viewBox stringByReplacingOccurrencesOfString:@"," withString:@" "] ?: @""];
    double x, y, width = 300, height = 150, vw, vh;
    if([scanner scanDouble:&x] && [scanner scanDouble:&y] &&
       [scanner scanDouble:&vw] && [scanner scanDouble:&vh] && vw > 0 && vh > 0) {
        // A viewBox is a coordinate system, not an intrinsic pixel size.
        // Use integral coordinate zoom to avoid fractional font rasterization noise.
        width = MAX(1, ceil(400 / vw)) * vw;
        height = width * vh / vw;
    }
    NSString* w = [[root attributeForName:@"width"] stringValue];
    NSString* h = [[root attributeForName:@"height"] stringValue];
    if(w.doubleValue > 0 && ![w containsString:@"%"] &&
       ([w isEqualToString:[@(w.doubleValue) stringValue]] || [w hasSuffix:@"px"])) width = w.doubleValue;
    if(h.doubleValue > 0 && ![h containsString:@"%"] &&
       ([h isEqualToString:[@(h.doubleValue) stringValue]] || [h hasSuffix:@"px"])) height = h.doubleValue;
    self.size = CGSizeMake(MAX(1, MIN(800, ceil(width))), MAX(1, MIN(800, ceil(height))));
    // Supply the same definite viewport to both engines, including %/auto roots.
    [root removeAttributeForName:@"width"];
    [root removeAttributeForName:@"height"];
    [root addAttribute:[NSXMLNode attributeWithName:@"width" stringValue:[@(self.size.width) stringValue]]];
    [root addAttribute:[NSXMLNode attributeWithName:@"height" stringValue:[@(self.size.height) stringValue]]];
    // Use the same initial font size instead of browser preference defaults.
    if([root attributeForName:IJSVGAttributeFontSize] == nil) {
        [root addAttribute:[NSXMLNode attributeWithName:IJSVGAttributeFontSize stringValue:@"16"]];
    }
    NSString* style = [root attributeForName:@"style"].stringValue ?: @"";
    style = [style stringByAppendingFormat:@";width:%gpx!important;height:%gpx!important;-webkit-font-smoothing:antialiased;", self.size.width, self.size.height];
    if(self.background != 1) {
        int component = (int)round(self.background * 255);
        style = [style stringByAppendingFormat:@"background-color:rgb(%d,%d,%d)!important;", component, component, component];
    }
    [root removeAttributeForName:@"style"];
    [root addAttribute:[NSXMLNode attributeWithName:@"style" stringValue:style]];
    self.xml = document.XMLString;
    WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];
    config.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
    self.webView = [[WKWebView alloc] initWithFrame:(CGRect){CGPointZero, self.size} configuration:config];
    self.webView.underPageBackgroundColor = [NSColor colorWithSRGBRed:self.background green:self.background blue:self.background alpha:1];
    self.webView.navigationDelegate = self;
    self.window = [[NSWindow alloc] initWithContentRect:(CGRect){CGPointZero, self.size}
        styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    self.window.releasedWhenClosed = NO;
    self.window.contentView = self.webView;
    if(self.referenceTransform != nil) {
        self.referenceTransform(document);
    }
    [self.webView loadData:[document.XMLString dataUsingEncoding:NSUTF8StringEncoding]
        MIMEType:@"image/svg+xml" characterEncodingName:@"UTF-8" baseURL:[NSURL URLWithString:@"about:blank"]];
    __weak IJSVGMDNComparison* weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [weakSelf finish:@{@"error": @"WebKit comparison timed out"}];
    });
}

- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)navigation
{
    [webView callAsyncJavaScript:@"await document.fonts.ready; const root = document.documentElement; "
        "return {languages:navigator.languages,viewport:[root.getBoundingClientRect().width,root.getBoundingClientRect().height], "
        "texts:Array.from(document.querySelectorAll('text')).map(t=>({text:t.textContent, "
        "textLength:t.textLength.baseVal.value,computedLength:t.getComputedTextLength(), "
        "font:getComputedStyle(t).font,baseline:getComputedStyle(t).dominantBaseline, "
        "positions:metrics?Array.from({length:t.getNumberOfChars()},(_,i)=>{let p=t.getStartPositionOfChar(i);return [p.x,p.y]}):null}))};"
        arguments:@{@"metrics":@(self.compareTextMetrics)} inFrame:nil inContentWorld:WKContentWorld.pageWorld
        completionHandler:^(id value, NSError* error) {
        if(!self.completion) return;
        if(error) {
            [self finish:@{@"error": error.description}];
            return;
        }
        NSMutableDictionary* metrics = [value mutableCopy];
        metrics[@"nativeLanguages"] = NSLocale.preferredLanguages;
        self.metrics = metrics;
        WKSnapshotConfiguration* config = [[WKSnapshotConfiguration alloc] init];
        config.rect = (CGRect){CGPointZero, self.size};
        config.snapshotWidth = @(self.size.width);
        config.afterScreenUpdates = YES;
        [self.webView takeSnapshotWithConfiguration:config completionHandler:^(NSImage* image, NSError* snapshotError) {
            if(!self.completion) return;
            if(!image || snapshotError) {
                [self finish:@{@"error": snapshotError.description ?: @"No WebKit snapshot"}];
                return;
            }
            [self compare:image];
        }];
    }];
}

- (void)webView:(WKWebView*)webView didFailNavigation:(WKNavigation*)navigation withError:(NSError*)error
{
    [self finish:@{@"error": error.description}];
}

- (void)webView:(WKWebView*)webView didFailProvisionalNavigation:(WKNavigation*)navigation withError:(NSError*)error
{
    [self finish:@{@"error": error.description}];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView*)webView
{
    [self finish:@{@"error": @"WebKit content process terminated"}];
}

- (void)compare:(NSImage*)snapshot
{
    CGRect rect = (CGRect){CGPointZero, self.size};
    CGImageRef reference = [snapshot CGImageForProposedRect:&rect context:nil hints:nil];
    if(!reference) {
        [self finish:@{@"error": @"Snapshot has no CGImage"}];
        return;
    }
    size_t width = CGImageGetWidth(reference), height = CGImageGetHeight(reference);
    CGContextRef expected = IJSVGMDNBitmap(width, height, self.background);
    CGContextRef actual = IJSVGMDNBitmap(width, height, self.background);
    CGContextRef diff = IJSVGMDNBitmap(width, height, self.background);
    if(!expected || !actual || !diff) {
        if(expected) CGContextRelease(expected);
        if(actual) CGContextRelease(actual);
        if(diff) CGContextRelease(diff);
        [self finish:@{@"error": @"Could not allocate comparison bitmaps"}];
        return;
    }
    CGContextDrawImage(expected, CGRectMake(0, 0, width, height), reference);
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:self.xml];
    if(self.compareTextMetrics) {
        NSMutableArray* texts = [NSMutableArray array];
        for(IJSVGNode* node in svg.rootNode.children) {
            if([node isKindOfClass:IJSVGText.class]) {
                IJSVGTextLayout* layout = [[IJSVGTextLayout alloc] initWithText:(IJSVGText*)node
                                                                     viewport:svg.rootNode.bounds.size
                                                                 pathResolver:nil];
                NSMutableArray* positions = [NSMutableArray array];
                for(NSValue* value in layout.characterPositions) {
                    CGPoint point = value.pointValue;
                    [positions addObject:@[@(point.x), @(point.y)]];
                }
                [texts addObject:@{@"advance":@(layout.advance), @"positions":positions}];
            }
        }
        NSMutableDictionary* metrics = self.metrics.mutableCopy;
        metrics[@"native"] = texts;
        self.metrics = metrics;
    }
    CGFloat scale = width / self.size.width;
    svg.renderingBackingScaleHelper = ^CGFloat { return scale; };
    CGContextTranslateCTM(actual, 0, height);
    CGContextScaleCTM(actual, scale, -scale);
    [svg drawInRect:rect context:actual];
    const unsigned char* a = CGBitmapContextGetData(actual);
    const unsigned char* b = CGBitmapContextGetData(expected);
    unsigned char* d = CGBitmapContextGetData(diff);
    double difference = 0;
    NSUInteger ink = 0;
    for(size_t i = 0; i < width * height * 4; i += 4) {
        BOOL marked = NO;
        double delta = 0;
        for(NSUInteger channel = 0; channel < 3; channel++) {
            int background = (int)round(self.background * 255);
            marked |= abs(a[i + channel] - background) > 10 || abs(b[i + channel] - background) > 10;
            unsigned char distance = abs(a[i + channel] - b[i + channel]);
            d[i + channel] = distance;
            delta += distance;
        }
        d[i + 3] = 255;
        if(marked) { ink++; difference += delta; }
    }
    NSMutableDictionary* result = [@{@"meanInkError": @(difference / (MAX(ink, 1) * 3. * 255.)),
        @"inkPixels": @(ink), @"parsed": @(svg.rootNode != nil), @"svg": self.xml} mutableCopy];
    CGContextRef contexts[] = {actual, expected, diff};
    NSArray* names = @[@"ijsvg", @"webkit", @"diff"];
    for(NSUInteger i = 0; i < 3; i++) {
        CGImageRef image = CGBitmapContextCreateImage(contexts[i]);
        NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
        result[names[i]] = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        CGImageRelease(image);
        CGContextRelease(contexts[i]);
    }
    [self finish:result];
}
@end

@interface IJSVGMDNWebKitTests : XCTestCase
@property (nonatomic, copy) void (^fixtureTransform)(NSXMLDocument*);
@property (nonatomic) BOOL compareTextMetrics;
@end

@implementation IJSVGMDNWebKitTests

- (void)testCorpusInventory
{
    NSDictionary* corpus = IJSVGMDNCorpus();
    XCTAssertEqualObjects(corpus[@"schemaVersion"], @1);
    XCTAssertGreaterThan([corpus[@"pages"] count], 300u);
    XCTAssertGreaterThan([corpus[@"examples"] count], 700u);
    XCTAssertGreaterThan([corpus[@"cases"] count], 400u);
    NSDictionary* policies = IJSVGMDNPolicies();
    XCTAssertNotNil(policies);
    NSMutableSet* identifiers = [NSMutableSet set];
    for(NSDictionary* fixture in corpus[@"cases"]) {
        XCTAssertFalse([identifiers containsObject:fixture[@"id"]]);
        [identifiers addObject:fixture[@"id"]];
        NSDictionary* policy = policies[fixture[@"id"]];
        BOOL excluded = [policy[@"excludeComparison"] boolValue] &&
            [policy[@"sha256"] isEqual:fixture[@"sha256"]];
        NSString* method = [@"test_" stringByAppendingString:fixture[@"id"]];
        XCTAssertEqual([self respondsToSelector:NSSelectorFromString(method)], !excluded,
                       @"Regenerate MDN tests after changing exclusions");
        if(excluded) {
            XCTAssertGreaterThan([policy[@"reason"] length], 0u);
        }
        XCTAssertTrue([fixture[@"svg"] length] > 0 || [fixture[@"skip"] length] > 0);
    }
}

- (void)compareCase:(NSString*)identifier
{
    [self compareCase:identifier referenceTransform:nil];
}

- (void)compareCase:(NSString*)identifier
 referenceTransform:(void (^)(NSXMLDocument*))referenceTransform
{
    NSDictionary* fixture = nil;
    for(NSDictionary* candidate in IJSVGMDNCorpus()[@"cases"]) {
        if([candidate[@"id"] isEqual:identifier]) { fixture = candidate; break; }
    }
    XCTAssertNotNil(fixture, @"Missing MDN fixture %@", identifier);
    if(!fixture) return;
    XCTSkipIf(fixture[@"skip"] != nil, @"%@: %@", fixture[@"url"], fixture[@"skip"]);
    NSDictionary* policies = IJSVGMDNPolicies();
    XCTAssertNotNil(policies, @"Missing or invalid MDN expectations");
    if(!policies) return;
    NSDictionary* policy = policies[identifier];
    NSString* xml = fixture[@"svg"];
    // Existing text comparisons use .16 for Core Text/WebKit rasterization.
    // Shape-only examples retain the existing .025 geometry threshold.
    double tolerance = [xml containsString:@"<text"] ? .16 : .025;
    if(policy[@"tolerance"]) tolerance = [policy[@"tolerance"] doubleValue];
    if(policy) {
        XCTAssertGreaterThan([policy[@"reason"] length], 0u);
        XCTAssertEqualObjects(policy[@"sha256"], fixture[@"sha256"], @"Review this expectation after updating the fixture");
        if(![policy[@"sha256"] isEqual:fixture[@"sha256"]]) return;
    }
    if(referenceTransform != nil || self.fixtureTransform != nil) {
        identifier = [identifier stringByAppendingString:@"_reference"];
    }
    XCTestExpectation* done = [self expectationWithDescription:identifier];
    __block NSDictionary* result;
    __block IJSVGMDNComparison* comparison;
    dispatch_async(dispatch_get_main_queue(), ^{
        comparison = [[IJSVGMDNComparison alloc] init];
        comparison.referenceTransform = referenceTransform;
        comparison.fixtureTransform = self.fixtureTransform;
        comparison.compareTextMetrics = self.compareTextMetrics;
        comparison.background = policy[@"background"] ? [policy[@"background"] doubleValue] : 1;
        [comparison run:xml completion:^(NSDictionary* value) {
            result = value;
            [done fulfill];
        }];
    });
    [self waitForExpectations:@[done] timeout:20];
    XCTAssertNotNil(result);
    XCTAssertNil(result[@"error"], @"%@", result[@"error"]);
    if(!result || result[@"error"]) return;
    XCTAssertTrue([result[@"parsed"] boolValue], @"IJSVG could not parse %@", identifier);
    if(self.compareTextMetrics) {
        NSArray* native = comparison.metrics[@"native"];
        NSArray* reference = comparison.metrics[@"texts"];
        XCTAssertGreaterThan(native.count, 0);
        XCTAssertEqual(native.count, reference.count);
        for(NSUInteger index = 0; index < MIN(native.count, reference.count); index++) {
            XCTAssertEqualWithAccuracy([native[index][@"advance"] doubleValue],
                                       [reference[index][@"computedLength"] doubleValue], .001);
            NSArray* actual = native[index][@"positions"];
            NSArray* expected = reference[index][@"positions"];
            XCTAssertEqual(actual.count, expected.count);
            for(NSUInteger character = 0; character < MIN(actual.count, expected.count); character++) {
                XCTAssertEqualWithAccuracy([actual[character][0] doubleValue], [expected[character][0] doubleValue], .001);
                XCTAssertEqualWithAccuracy([actual[character][1] doubleValue], [expected[character][1] doubleValue], .001);
            }
        }
        return;
    }
    double error = [result[@"meanInkError"] doubleValue];
    BOOL blank = [result[@"inkPixels"] unsignedIntegerValue] == 0;
    NSLog(@"MDN %@ meanInkError=%.6f tolerance=%.3f ink=%@", identifier, error, tolerance, result[@"inkPixels"]);
    if(blank || error > tolerance) {
        NSString* directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"IJSVGMDNComparisons"];
        [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        NSLog(@"MDN comparison artifacts: %@/%@", directory, identifier);
        NSData* metrics = [NSJSONSerialization dataWithJSONObject:comparison.metrics ?: @{} options:NSJSONWritingPrettyPrinted error:nil];
        [metrics writeToFile:[directory stringByAppendingPathComponent:[identifier stringByAppendingString:@"-metrics.json"]] atomically:YES];
        for(NSString* name in @[@"ijsvg", @"webkit", @"diff"]) {
            XCTAttachment* attachment = [XCTAttachment attachmentWithData:result[name] uniformTypeIdentifier:@"public.png"];
            attachment.name = [NSString stringWithFormat:@"%@-%@.png", identifier, name];
            attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
            [self addAttachment:attachment];
            [result[name] writeToFile:[directory stringByAppendingPathComponent:attachment.name] atomically:YES];
        }
        XCTAttachment* source = [XCTAttachment attachmentWithString:result[@"svg"]];
        source.name = [identifier stringByAppendingString:@".svg"];
        source.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:source];
    }
    XCTAssertFalse(blank, @"%@ produced no visible ink on the comparison background; inspect the fixture and snapshots", identifier);
    XCTAssertLessThanOrEqual(error, tolerance, @"%@ (%@): %@", identifier, fixture[@"url"],
                             policy[@"reason"] ?: @"Unexpected rendering difference");
}

- (void)testBaselineExamplesMatchExplicitReferenceBaselines
{
    for(NSString* identifier in @[@"reference_attribute_dominant_baseline_block_3_1",
                                  @"tutorials_svg_from_scratch_texts_block_2_1",
                                  @"tutorials_svg_from_scratch_texts_block_3_1"]) {
        [self compareCase:identifier referenceTransform:^(NSXMLDocument* document) {
            for(NSXMLElement* element in [document nodesForXPath:@"//*[local-name()='tspan' or local-name()='textPath']" error:nil]) {
                [element addAttribute:[NSXMLNode attributeWithName:IJSVGAttributeDominantBaseline stringValue:@"hanging"]];
            }
            for(NSXMLElement* element in [document nodesForXPath:@"//*[@dominant-baseline='text-top']" error:nil]) {
                [element attributeForName:IJSVGAttributeDominantBaseline].stringValue = @"text-before-edge";
            }
        }];
    }
}

- (void)testDisplacementExampleImageGeometry
{
    self.fixtureTransform = ^(NSXMLDocument* document) {
        for(NSXMLNode* primitive in [document nodesForXPath:@"//*[local-name()='feDisplacementMap']" error:nil]) {
            [primitive detach];
        }
    };
    [self compareCase:@"reference_attribute_xchannelselector_block_2_1"];
}

- (void)testSpanExampleCharacterPositionsWithoutKerning
{
    self.compareTextMetrics = YES;
    self.fixtureTransform = ^(NSXMLDocument* document) {
        for(NSXMLElement* element in [document nodesForXPath:@"//*[local-name()='text' or local-name()='tspan']" error:nil]) {
            [element addAttribute:[NSXMLNode attributeWithName:IJSVGAttributeStyle stringValue:@"font-kerning:none"]];
        }
    };
    [self compareCase:@"reference_element_tspan_block_2_1"];
}

- (void)testSwitchExampleMatchesRegionalReference
{
    XCTAssertGreaterThan(NSLocale.preferredLanguages.count, 0);
    NSString* language = NSLocale.preferredLanguages.firstObject.lowercaseString;
    NSDictionary* regional = @{@"en-us":@"Howdy!", @"en-gb":@"Wotcha!", @"en-au":@"G'day!"};
    NSString* expected = regional[language];
    XCTSkipIf(expected == nil || NSLocale.preferredLanguages.count != 1, @"This control requires one regional English preference");
    [self compareCase:@"reference_element_switch_block_1_1" referenceTransform:^(NSXMLDocument* document) {
        for(NSXMLElement* element in [document nodesForXPath:@"//*[local-name()='switch']" error:nil]) {
            NSXMLElement* text = [NSXMLElement elementWithName:@"text"];
            text.stringValue = expected;
            [(NSXMLElement*)element.parent insertChild:text atIndex:element.index];
            [element detach];
        }
    }];
}

#include <IJSVGMDNGeneratedTests.inc>
@end
