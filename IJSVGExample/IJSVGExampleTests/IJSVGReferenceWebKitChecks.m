//
//  IJSVGReferenceWebKitChecks.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 07/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGCSSFontParserChecks.h>
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <IJSVG/IJSVG.h>

static NSDictionary<NSString*, NSString*>* IJSVGReferenceFixtures(void)
{
    static NSDictionary* fixtures;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString* mask = @"<defs><mask id='m'><path fill='white' d='M43 31 H128 V57 H69 V112 H43 Z'/><text x='145' y='91' fill='white' font-family='Helvetica' font-size='40'>Mask F</text></mask></defs>";
        NSString* content = @"<g mask='url(#m)'><rect width='350' height='150' fill='#09f'/></g>";
        fixtures = @{
            @"translatedMask": [NSString stringWithFormat:@"%@<g transform='translate(23 17)'>%@</g>", mask, content],
            @"rotatedMask": [NSString stringWithFormat:@"%@<g transform='rotate(12 180 90)'>%@</g>", mask, content],
            @"fractionalMask": [NSString stringWithFormat:@"%@<g transform='translate(13.25 7.75) scale(.85 1.1)'>%@</g>", mask, content],
            @"nestedMask": [NSString stringWithFormat:@"%@<defs><mask id='outer'><rect x='20' y='20' width='300' height='130' fill='white'/></mask></defs><g mask='url(#outer)' transform='translate(11 9)'>%@</g>", mask, content],
            @"innerShadowText": @"<svg width='350' height='75' viewBox='0 0 350 75'><rect width='350' height='75' fill='#09f'/><g text-anchor='middle' font-size='45' font-weight='bold' font-family='Verdana,Helvetica,Arial,sans-serif'><defs><mask id='textMask'><text fill='white' x='175' y='55'>InnerShadow</text></mask><filter id='innerShadow' x='-20%' y='-20%' width='140%' height='140%'><feGaussianBlur in='SourceGraphic' stdDeviation='3' result='blur'/><feOffset in='blur' dx='2.5' dy='2.5'/></filter></defs><g mask='url(#textMask)'><rect width='350' height='75' fill='black'/><text fill='#09f' filter='url(#innerShadow)' x='175' y='55'>InnerShadow</text></g></g></svg>"
        };
    });
    return fixtures;
}

static CGContextRef IJSVGReferenceBitmap(size_t width, size_t height)
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if(bitmap != NULL) {
        CGContextSetRGBFillColor(bitmap, 1, 1, 1, 1);
        CGContextFillRect(bitmap, CGRectMake(0, 0, width, height));
    }
    return bitmap;
}

static void IJSVGSaveReferenceImage(CGImageRef image, NSString* name)
{
    NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    NSString* directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"IJSVGReferenceComparisons"];
    [NSFileManager.defaultManager createDirectoryAtPath:directory
                           withIntermediateDirectories:YES attributes:nil error:nil];
    [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}]
        writeToFile:[directory stringByAppendingPathComponent:[name stringByAppendingString:@".png"]]
         atomically:YES];
}

@interface IJSVGReferenceWebKitCheck: NSObject <WKNavigationDelegate>
@property (nonatomic, strong) WKWebView* view;
@property (nonatomic, strong) NSWindow* window;
@property (nonatomic, copy) NSString* xml;
@property (nonatomic, copy) NSString* name;
@property (nonatomic, copy) void (^completion)(NSArray<NSString*>*);
@end

@implementation IJSVGReferenceWebKitCheck

- (void)finish:(NSArray<NSString*>*)failures
{
    if(self.completion == nil) {
        return;
    }
    void (^completion)(NSArray<NSString*>*) = self.completion;
    self.completion = nil;
    self.view.navigationDelegate = nil;
    [self.view stopLoading];
    [self.window close];
    self.window = nil;
    self.view = nil;
    completion(failures);
}

- (void)webView:(WKWebView*)view didFinishNavigation:(WKNavigation*)navigation
{
    WKSnapshotConfiguration* options = [[WKSnapshotConfiguration alloc] init];
    options.rect = CGRectMake(0, 0, 400, 200);
    options.snapshotWidth = @400;
    [view takeSnapshotWithConfiguration:options completionHandler:^(NSImage* image, NSError* error) {
        if(self.completion == nil) {
            return;
        }
        [self finish:image != nil ? [self compareImage:image] :
            @[error.description ?: @"WebKit did not return a snapshot"]];
    }];
}

- (void)webView:(WKWebView*)webView didFailNavigation:(WKNavigation*)navigation
       withError:(NSError*)error
{
    [self finish:@[error.description]];
}

- (void)webView:(WKWebView*)webView didFailProvisionalNavigation:(WKNavigation*)navigation
       withError:(NSError*)error
{
    [self finish:@[error.description]];
}

- (void)run:(NSString*)name completion:(void (^)(NSArray<NSString*>*))completion
{
    self.completion = completion;
    self.name = name;
    NSString* body = IJSVGReferenceFixtures()[name];
    if(body == nil) {
        [self finish:@[@"Unknown WebKit fixture"]];
        return;
    }
    self.xml = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='400' height='200'>%@</svg>", body];
    WKWebViewConfiguration* configuration = [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
    self.view = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)
                                  configuration:configuration];
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 200)
                                              styleMask:NSWindowStyleMaskBorderless
                                                backing:NSBackingStoreBuffered defer:NO];
    self.window.releasedWhenClosed = NO;
    self.window.contentView = self.view;
    self.view.navigationDelegate = self;
    [self.view loadHTMLString:[NSString stringWithFormat:
        @"<!doctype html><style>html,body{margin:0;background:white}svg{display:block}</style>%@", self.xml]
                     baseURL:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self finish:@[@"WebKit comparison timed out"]];
    });
}

- (NSArray<NSString*>*)compareImage:(NSImage*)snapshot
{
    CGRect rect = CGRectMake(0, 0, 400, 200);
    CGImageRef reference = [snapshot CGImageForProposedRect:&rect context:nil hints:nil];
    size_t width = CGImageGetWidth(reference);
    size_t height = CGImageGetHeight(reference);
    CGContextRef expected = IJSVGReferenceBitmap(width, height);
    CGContextRef actual = IJSVGReferenceBitmap(width, height);
    if(expected == NULL || actual == NULL) {
        if(expected != NULL) {
            CGContextRelease(expected);
        }
        if(actual != NULL) {
            CGContextRelease(actual);
        }
        return @[@"Could not allocate comparison bitmaps"];
    }
    CGContextDrawImage(expected, CGRectMake(0, 0, width, height), reference);
    CGFloat scale = width / 400.;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:self.xml];
    svg.renderingBackingScaleHelper = ^CGFloat { return scale; };
    CGContextTranslateCTM(actual, 0, height);
    CGContextScaleCTM(actual, scale, -scale);
    [svg drawInRect:rect context:actual];
    CGImageRef rendered = CGBitmapContextCreateImage(actual);
    IJSVGSaveReferenceImage(reference, [self.name stringByAppendingString:@"-webkit"]);
    IJSVGSaveReferenceImage(rendered, [self.name stringByAppendingString:@"-ijsvg"]);
    CGImageRelease(rendered);
    const unsigned char* a = CGBitmapContextGetData(actual);
    const unsigned char* b = CGBitmapContextGetData(expected);
    double difference = 0;
    NSUInteger ink = 0;
    for(size_t pixel = 0; pixel < width * height * 4; pixel += 4) {
        BOOL marked = NO;
        double delta = 0;
        for(NSUInteger channel = 0; channel < 3; channel++) {
            marked |= a[pixel + channel] < 245 || b[pixel + channel] < 245;
            delta += abs(a[pixel + channel] - b[pixel + channel]);
        }
        if(marked) {
            ink++;
            difference += delta;
        }
    }
    CGContextRelease(actual);
    CGContextRelease(expected);
    double error = difference / (MAX(ink, 1) * 3. * 255.);
    NSLog(@"Reference comparison %@: mean ink error %.5f", self.name, error);
    if(ink < 100 || error > .06) {
        return @[[NSString stringWithFormat:@"%@ differs from WebKit: %.5f", self.name, error]];
    }
    return @[];
}

@end

NSArray<NSString*>* IJSVGReferenceWebKitCaseNames(void)
{
    return [IJSVGReferenceFixtures().allKeys sortedArrayUsingSelector:@selector(compare:)];
}

void IJSVGRunReferenceWebKitCase(NSString* name, void (^completion)(NSArray<NSString*>*))
{
    if(!NSThread.isMainThread) {
        completion(@[@"WebKit comparisons must run on the main thread"]);
        return;
    }
    [[[IJSVGReferenceWebKitCheck alloc] init] run:name completion:completion];
}
