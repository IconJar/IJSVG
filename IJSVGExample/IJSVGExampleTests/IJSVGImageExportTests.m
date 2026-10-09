#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGExporter.h>
#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGFilterPrimitive.h>
#import <IJSVG/IJSVGGradient.h>
#import <IJSVG/IJSVGPath.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>
#import <XCTest/XCTest.h>

@interface IJSVGImageExportTests : XCTestCase <WKNavigationDelegate>
@property (nonatomic, strong) XCTestExpectation* navigation;
@end

@implementation IJSVGImageExportTests

- (NSString*)document:(NSString*)body origin:(NSInteger)origin
{
    return [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='128' height='128' viewBox='%ld %ld 128 128'>%@</svg>",
        (long)origin, (long)origin, body];
}

- (IJSVG*)fixtureAtOrigin:(NSInteger)origin corner:(NSUInteger)corner
              percentage:(BOOL)percentage reference:(NSString**)reference
{
    BOOL left = corner % 2 == 0;
    BOOL top = corner < 2;
    CGFloat x = origin + (left ? 12 : 76);
    CGFloat y = origin + (top ? 16 : 72);
    CGFloat a = x + (left ? 2 : 34);
    CGFloat b = y + (top ? 2 : 38);
    NSString* path = [NSString stringWithFormat:@"M%g %gL%g %gL%g %gZ",
        a, b, x + (left ? 34 : 2), b, a, y + (top ? 38 : 2)];
    NSString* coordinates = percentage
        ? [NSString stringWithFormat:@"x1='0%%' y1='0%%' x2='100%%' y2='100%%' gradientTransform='translate(%ld %ld)'",
            (long)origin, (long)origin]
        : [NSString stringWithFormat:@"x1='%ld' y1='%ld' x2='%ld' y2='%ld'",
            (long)origin, (long)origin, (long)origin + 128, (long)origin + 128];
    NSString* artwork = [NSString stringWithFormat:
        @"<defs><linearGradient id='paper' gradientUnits='userSpaceOnUse' %@>"
         "<stop stop-color='#777'/><stop offset='1' stop-color='#fff'/></linearGradient></defs>"
         "<path d='%@' fill='url(#paper)'/>", coordinates, path];
    *reference = [self document:artwork origin:origin];
    IJSVG* source = [[IJSVG alloc] initWithSVGString:*reference];
    IJSVGPath* shape = (IJSVGPath*)[source.rootNode.children.firstObject copy];
    shape.parentNode = nil;
    shape.styleParent = nil;
    shape.svg = nil;
    IJSVGGradient* fill = (IJSVGGradient*)[shape.fill copy];
    fill.parentNode = nil;
    fill.styleParent = nil;
    fill.svg = nil;
    shape.fill = fill;
    NSString* region = percentage
        ? [NSString stringWithFormat:@"x='%g%%' y='%g%%' width='28.125%%' height='31.25%%'",
            (x - origin) / 1.28, (y - origin) / 1.28]
        : [NSString stringWithFormat:@"x='%g' y='%g' width='36' height='40'", x, y];
    NSString* body = [NSString stringWithFormat:
        @"<defs><filter id='f' filterUnits='userSpaceOnUse' primitiveUnits='userSpaceOnUse' "
         "x='%g' y='%g' width='36' height='40' color-interpolation-filters='sRGB'>"
         "<feImage %@ result='paper'/></filter></defs>"
         "<path d='M%g %gh36v40h-36Z' filter='url(#f)'/>", x, y, region, x, y];
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:[self document:body origin:origin]];
    IJSVGFilterPrimitive* primitive = svg.rootNode.children.firstObject.filter.primitives.firstObject;
    XCTAssertNotNil(primitive);
    primitive.imageNode = shape;
    return svg;
}

- (NSData*)pixels:(CGImageRef)image size:(NSUInteger)size
{
    if(image == NULL) return nil;
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, size, size, 8, size * 4,
                                                 space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if(context == NULL) return nil;
    // Missing paper opacity is conspicuous against this dark background.
    CGContextSetRGBFillColor(context, 36.f / 255, 0, 97.f / 255, 1);
    CGContextFillRect(context, CGRectMake(0, 0, size, size));
    CGContextDrawImage(context, CGRectMake(0, 0, size, size), image);
    NSData* data = [NSData dataWithBytes:CGBitmapContextGetData(context) length:size * size * 4];
    CGContextRelease(context);
    return data;
}

- (NSData*)native:(IJSVG*)svg size:(NSUInteger)size
{
    svg.renderingBackingScaleHelper = ^CGFloat { return 1; };
    CGImageRef image = [svg newCGImageRefWithSize:CGSizeMake(size, size) flipped:YES error:nil];
    NSData* data = [self pixels:image size:size];
    if(image != NULL) CGImageRelease(image);
    return data;
}

- (void)compare:(NSData*)actual expected:(NSData*)expected label:(NSString*)label
{
    XCTAssertNotNil(actual, @"%@", label);
    XCTAssertNotNil(expected, @"%@", label);
    XCTAssertEqual(actual.length, expected.length, @"%@", label);
    if(actual == nil || expected == nil || actual.length != expected.length) return;
    const UInt8* a = actual.bytes;
    const UInt8* b = expected.bytes;
    NSUInteger total = 0, large = 0;
    for(NSUInteger index = 0; index < actual.length; index++) {
        NSUInteger error = labs((NSInteger)a[index] - b[index]);
        total += error;
        large += error > 12;
    }
    XCTAssertLessThan((double)total / actual.length, .6, @"%@", label);
    XCTAssertLessThan((double)large / actual.length, .007, @"%@", label);
}

- (void)testDetachedPaperNativeExportReimport
{
    XCTAssertNotNil(MTLCreateSystemDefaultDevice());
    if(MTLCreateSystemDefaultDevice() == nil) return;
    for(NSNumber* origin in @[@(-80), @0, @20]) {
        for(NSUInteger corner = 0; corner < 4; corner++) {
            for(NSNumber* percentage in @[@NO, @YES]) {
                for(NSNumber* compressed in @[@NO, @YES]) {
                    @autoreleasepool {
                        NSString* reference = nil;
                        IJSVG* svg = [self fixtureAtOrigin:origin.integerValue corner:corner
                            percentage:percentage.boolValue reference:&reference];
                        IJSVGFilterPrimitive* primitive = svg.rootNode.children.firstObject.filter.primitives.firstObject;
                        IJSVGNode* originalNode = primitive.imageNode;
                        NSDictionary* parameters = primitive.parameters.copy;
                        NSString* label = [NSString stringWithFormat:@"origin=%@ corner=%lu percentage=%@ compressed=%@",
                            origin, (unsigned long)corner, percentage, compressed];
                        IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg size:CGSizeMake(128, 128)
                            options:compressed.boolValue ? IJSVGExporterOptionAll : IJSVGExporterOptionNone];
                        NSString* exported = exporter.SVGString;
                        XCTAssertTrue([exported containsString:@"data:image/svg+xml;base64,"], @"%@", label);
                        NSXMLDocument* document = [[NSXMLDocument alloc] initWithXMLString:exported options:0 error:nil];
                        NSXMLElement* filter = [document nodesForXPath:@"//filter" error:nil].firstObject;
                        XCTAssertEqualObjects([filter attributeForName:@"width"].stringValue, @"36", @"%@", label);
                        XCTAssertEqualObjects([filter attributeForName:@"height"].stringValue, @"40", @"%@", label);
                        IJSVG* imported = [[IJSVG alloc] initWithSVGString:exported];
                        IJSVG* attached = [[IJSVG alloc] initWithSVGString:reference];
                        // First render, automatic snapshot reuse, resizing, and restore.
                        for(NSNumber* size in @[@128, @128, @384, @128]) {
                            NSData* expected = [self native:attached size:size.unsignedIntegerValue];
                            [self compare:[self native:svg size:size.unsignedIntegerValue] expected:expected label:label];
                            [self compare:[self native:imported size:size.unsignedIntegerValue] expected:expected label:label];
                        }
                        XCTAssertEqual(primitive.imageNode, originalNode);
                        XCTAssertEqualObjects(primitive.parameters, parameters);
                        // An unused bitmap disables automatic imageNode snapshots.
                        primitive.image = [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];
                        [self compare:[self native:svg size:128] expected:[self native:attached size:128] label:label];
                    }
                }
            }
        }
    }
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

- (void)webView:(WKWebView*)webView didFailProvisionalNavigation:(WKNavigation*)navigation withError:(NSError*)error
{
    [self webView:webView didFailNavigation:navigation withError:error];
}

- (NSData*)capture:(NSString*)svg webView:(WKWebView*)webView
{
    self.navigation = [self expectationWithDescription:@"WebKit loaded"];
    [webView loadHTMLString:[NSString stringWithFormat:
        @"<html><style>body{margin:0;background:rgb(36,0,97)}svg{width:256px;height:256px}</style>%@</html>", svg]
                   baseURL:nil];
    [self waitForExpectations:@[self.navigation] timeout:15];
    XCTestExpectation* snapshot = [self expectationWithDescription:@"WebKit snapshot"];
    __block NSData* pixels = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.1 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            WKSnapshotConfiguration* configuration = [[WKSnapshotConfiguration alloc] init];
            configuration.afterScreenUpdates = YES;
            [webView takeSnapshotWithConfiguration:configuration completionHandler:^(NSImage* image, NSError* error) {
                XCTAssertNil(error);
                CGImageRef bitmap = [image CGImageForProposedRect:NULL context:nil hints:nil];
                pixels = [self pixels:bitmap size:256];
                [snapshot fulfill];
            }];
        });
    [self waitForExpectations:@[snapshot] timeout:15];
    return pixels;
}

- (void)testDetachedPaperWebKitExport
{
    WKWebViewConfiguration* configuration = [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
    WKWebView* webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 256, 256) configuration:configuration];
    webView.navigationDelegate = self;
    NSWindow* window = [[NSWindow alloc] initWithContentRect:webView.frame styleMask:NSWindowStyleMaskBorderless
                                                  backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed = NO;
    window.contentView = webView;
    [window orderBack:nil];
    @try {
        for(NSNumber* origin in @[@(-80), @0, @20]) {
            for(NSUInteger corner = 0; corner < 4; corner++) {
                for(NSNumber* percentage in @[@NO, @YES]) {
                    NSString* reference = nil;
                    IJSVG* svg = [self fixtureAtOrigin:origin.integerValue corner:corner
                        percentage:percentage.boolValue reference:&reference];
                    NSData* expected = [self capture:reference webView:webView];
                    for(NSNumber* compressed in @[@NO, @YES]) {
                        IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg size:CGSizeMake(128, 128)
                            options:compressed.boolValue ? IJSVGExporterOptionAll : IJSVGExporterOptionNone];
                        NSString* label = [NSString stringWithFormat:@"origin=%@ corner=%lu percentage=%@ compressed=%@",
                            origin, (unsigned long)corner, percentage, compressed];
                        [self compare:[self capture:exporter.SVGString webView:webView] expected:expected label:label];
                    }
                }
            }
        }
    } @finally {
        [window close];
    }
}

@end
