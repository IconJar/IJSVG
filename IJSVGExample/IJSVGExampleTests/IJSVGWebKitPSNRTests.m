//
//  IJSVGWebKitPSNRTests.m
//  IJSVGExampleTests
//
//  Compares IJSVG drawInRect:context: output against WebKit WKWebView snapshots
//  using PSNR (Peak Signal-to-Noise Ratio) as the quality metric.
//
//  Adapted from Sitely's TestIJSVGFilters.m — only the comparison
//  infrastructure is kept here, plus a few example test cases that use SVGs
//  already bundled in the IJSVGExample target.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <WebKit/WebKit.h>
#import <ImageIO/ImageIO.h>
#import <IJSVG/IJSVG.h>

static const CGFloat kDefaultPSNRThreshold = 30.0;
static NSString * const kOutputFolder      = @"IJSVGWebKitPSNRResults";


#pragma mark - WebKit snapshot helper (navigation delegate)

@interface _IJSVGWebKitSnapshotHelper : NSObject <WKNavigationDelegate>
@property (nonatomic, copy)   void (^completionBlock)(void);
@property (nonatomic, assign) BOOL loaded;
@end

@implementation _IJSVGWebKitSnapshotHelper

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.loaded = YES;
    if (self.completionBlock) {
        self.completionBlock();
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    NSLog(@"WebKit navigation failed: %@", error);
    self.loaded = YES;
    if (self.completionBlock) {
        self.completionBlock();
    }
}

@end


#pragma mark - Test class

@interface IJSVGWebKitPSNRTests : XCTestCase
@end

@implementation IJSVGWebKitPSNRTests


#pragma mark - Output directory

+ (NSString *)outputDirectory {
    NSString *override = NSProcessInfo.processInfo.environment[@"IJSVG_OUTPUT_DIR"];
    if (override.length != 0) {
        [[NSFileManager defaultManager] createDirectoryAtPath:override
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        return override;
    }
    NSString *desktop = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dir = [desktop stringByAppendingPathComponent:kOutputFolder];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return dir;
}

+ (NSString *)webKitSandboxHomeDirectory {
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ijsvg-webkit-home"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager createDirectoryAtPath:[dir stringByAppendingPathComponent:@"Library/Caches/com.apple.dt.xctest.tool/WebKit"]
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:nil];
    [fileManager createDirectoryAtPath:[dir stringByAppendingPathComponent:@"Library/WebKit"]
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:nil];
    return dir;
}

+ (NSTimeInterval)webKitRenderSettleDelay {
    NSString *override = NSProcessInfo.processInfo.environment[@"IJSVG_WEBKIT_SETTLE_DELAY"];
    if (override.length != 0) {
        double parsed = override.doubleValue;
        if (parsed >= 0.0) {
            return parsed;
        }
    }
    return 2.0;
}


#pragma mark - SVG loading

- (NSString *)svgStringForBundledResource:(NSString *)name {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:name ofType:@"svg"];
    if (path == nil) {
        XCTFail(@"Could not find bundled SVG resource '%@.svg'", name);
        return nil;
    }
    NSError *error = nil;
    NSString *svg = [NSString stringWithContentsOfFile:path
                                              encoding:NSUTF8StringEncoding
                                                 error:&error];
    if (svg == nil) {
        NSLog(@"Failed to load SVG %@: %@", path, error);
    }
    return svg;
}


#pragma mark - HTML / data URL helpers

- (NSString *)webKitDataURLForSVGString:(NSString *)svgString {
    NSData *data = [svgString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64 = [data base64EncodedStringWithOptions:0];
    return [NSString stringWithFormat:@"data:image/svg+xml;charset=utf-8;base64,%@", base64];
}

- (NSString *)webKitHTMLForImageSource:(NSString *)imageSource size:(CGSize)size {
    return [NSString stringWithFormat:
        @"<!DOCTYPE html><html><head><meta charset='utf-8'>"
        @"<style>html,body{margin:0;padding:0;background:white;overflow:hidden;width:%dpx;height:%dpx;}"
        @"div.svgcontainer{width:%dpx;height:%dpx;overflow:hidden;}"
        @"div.svgcontainer img{display:block;width:100%%;height:100%%;}</style>"
        @"</head><body><div class='svgcontainer'><img src='%@' alt='svg'/></div></body></html>",
        (int)size.width, (int)size.height,
        (int)size.width, (int)size.height, imageSource];
}

- (NSString *)webKitHTMLForInlineSVGString:(NSString *)svgString size:(CGSize)size {
    return [NSString stringWithFormat:
        @"<!DOCTYPE html><html><head><meta charset='utf-8'>"
        @"<style>html,body{margin:0;padding:0;background:white;overflow:hidden;width:%dpx;height:%dpx;}"
        @"div.svgcontainer{width:%dpx;height:%dpx;overflow:hidden;}"
        @"div.svgcontainer svg{display:block;width:100%%;height:100%%;}</style>"
        @"</head><body><div class='svgcontainer'>%@</div></body></html>",
        (int)size.width, (int)size.height,
        (int)size.width, (int)size.height, svgString];
}

- (BOOL)webKitImageElementLoaded:(WKWebView *)webView {
    __block BOOL loaded = NO;
    XCTestExpectation *jsExp = [self expectationWithDescription:@"WebKit image state"];
    NSString *script = @"(function(){var img=document.querySelector('img'); return !!img && img.complete && img.naturalWidth > 0 && img.naturalHeight > 0;})();";
    [webView evaluateJavaScript:script completionHandler:^(id _Nullable value, NSError * _Nullable error) {
        if([value isKindOfClass:NSNumber.class]) {
            loaded = ((NSNumber *)value).boolValue;
        }
        [jsExp fulfill];
    }];
    [self waitForExpectations:@[jsExp] timeout:10.0];
    return loaded;
}


#pragma mark - IJSVG rendering (2x bitmap with white background)

- (CGImageRef)renderIJSVG:(NSString *)svgString size:(CGSize)size CF_RETURNS_RETAINED {
    IJSVG *svg = [[IJSVG alloc] initWithSVGString:svgString];
    XCTAssertNotNil(svg, @"IJSVG failed to parse SVG string");
    if (!svg) return NULL;

    svg.renderingBackingScaleHelper = ^CGFloat {
        return 2.0;
    };

    NSUInteger pixelW = (NSUInteger)(size.width  * 2);
    NSUInteger pixelH = (NSUInteger)(size.height * 2);

    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(NULL, pixelW, pixelH, 8,
                                              pixelW * 4,
                                              cs,
                                              kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    if (!ctx) return NULL;

    CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, pixelW, pixelH));

    CGContextTranslateCTM(ctx, 0, pixelH);
    CGContextScaleCTM(ctx, 2.0, -2.0);

    [svg drawInRect:CGRectMake(0, 0, size.width, size.height) context:ctx];

    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return image;
}


#pragma mark - WebKit rendering (snapshot with white background)

- (CGImageRef)renderWebKit:(NSString *)svgString size:(CGSize)size CF_RETURNS_RETAINED {
    __block CGImageRef resultImage = NULL;
    NSString *svgDataURLString = [self webKitDataURLForSVGString:svgString];

    void (^work)(void) = ^{
        static dispatch_once_t onceToken;
        static NSWindow *window = nil;
        static WKWebView *webView = nil;
        static _IJSVGWebKitSnapshotHelper *delegate = nil;

        dispatch_once(&onceToken, ^{
            NSString *webKitHome = [IJSVGWebKitPSNRTests webKitSandboxHomeDirectory];
            setenv("CFFIXED_USER_HOME", webKitHome.fileSystemRepresentation, 1);
            setenv("HOME", webKitHome.fileSystemRepresentation, 1);

            NSRect windowRect = NSMakeRect(-10000, -10000, 256, 256);
            window = [[NSWindow alloc] initWithContentRect:windowRect
                                                 styleMask:NSWindowStyleMaskBorderless
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
            [window setBackgroundColor:[NSColor whiteColor]];

            WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
            config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
            webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 256, 256)
                                         configuration:config];
            [[window contentView] addSubview:webView];
            [window orderBack:nil];

            delegate = [[_IJSVGWebKitSnapshotHelper alloc] init];
            webView.navigationDelegate = delegate;
        });

        [window setFrame:NSMakeRect(-10000, -10000, size.width, size.height) display:NO];
        webView.frame = NSMakeRect(0, 0, size.width, size.height);

        // Load the SVG via an <img> data URL so WebKit uses its SVG parser
        // rather than HTML inline-SVG parsing.
        NSString *html = [self webKitHTMLForImageSource:svgDataURLString
                                                   size:size];

        XCTestExpectation *loadExp = [self expectationWithDescription:@"WebKit page loaded"];
        delegate.loaded = NO;
        delegate.completionBlock = ^{
            [loadExp fulfill];
        };

        [webView loadHTMLString:html baseURL:nil];
        [self waitForExpectations:@[loadExp] timeout:10.0];

        if([self webKitImageElementLoaded:webView] == NO) {
            // Fall back to inline SVG if <img> didn't load.
            NSString *fallbackHTML = [self webKitHTMLForInlineSVGString:svgString
                                                                   size:size];
            XCTestExpectation *fallbackExp = [self expectationWithDescription:@"WebKit fallback loaded"];
            delegate.loaded = NO;
            delegate.completionBlock = ^{
                [fallbackExp fulfill];
            };
            [webView loadHTMLString:fallbackHTML baseURL:nil];
            [self waitForExpectations:@[fallbackExp] timeout:10.0];
        }

        NSTimeInterval settleDelay = [IJSVGWebKitPSNRTests webKitRenderSettleDelay];
        if (settleDelay > 0.0) {
            XCTestExpectation *renderDelay = [self expectationWithDescription:@"render settle"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(settleDelay * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [renderDelay fulfill];
            });
            [self waitForExpectations:@[renderDelay] timeout:MAX(10.0, settleDelay + 1.0)];
        }

        WKSnapshotConfiguration *snapConfig = [[WKSnapshotConfiguration alloc] init];
        snapConfig.snapshotWidth = @(size.width);

        XCTestExpectation *snapExp = [self expectationWithDescription:@"WebKit snapshot"];

        [webView takeSnapshotWithConfiguration:snapConfig
                             completionHandler:^(NSImage * _Nullable snapshotImage,
                                                 NSError * _Nullable error) {
            if (error) {
                NSLog(@"Snapshot error: %@", error);
            }
            if (snapshotImage) {
                NSUInteger targetW = (NSUInteger)(size.width * 2);
                NSUInteger targetH = (NSUInteger)(size.height * 2);

                CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
                CGContextRef bmpCtx = CGBitmapContextCreate(NULL, targetW, targetH, 8,
                                                             targetW * 4, cs,
                                                             kCGImageAlphaPremultipliedLast);
                CGColorSpaceRelease(cs);

                if (bmpCtx) {
                    CGContextSetRGBFillColor(bmpCtx, 1, 1, 1, 1);
                    CGContextFillRect(bmpCtx, CGRectMake(0, 0, targetW, targetH));

                    NSGraphicsContext *nsCtx = [NSGraphicsContext graphicsContextWithCGContext:bmpCtx flipped:NO];
                    [NSGraphicsContext saveGraphicsState];
                    [NSGraphicsContext setCurrentContext:nsCtx];
                    [snapshotImage drawInRect:NSMakeRect(0, 0, targetW, targetH)
                                    fromRect:NSZeroRect
                                   operation:NSCompositingOperationSourceOver
                                    fraction:1.0];
                    [NSGraphicsContext restoreGraphicsState];

                    resultImage = CGBitmapContextCreateImage(bmpCtx);
                    CGContextRelease(bmpCtx);
                }
            }
            [snapExp fulfill];
        }];

        [self waitForExpectations:@[snapExp] timeout:10.0];
    };

    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_sync(dispatch_get_main_queue(), work);
    }

    return resultImage;
}


#pragma mark - PSNR computation

- (double)psnrBetweenImageA:(CGImageRef)imageA imageB:(CGImageRef)imageB {
    if (!imageA || !imageB) return 0.0;

    size_t wA = CGImageGetWidth(imageA);
    size_t hA = CGImageGetHeight(imageA);
    size_t wB = CGImageGetWidth(imageB);
    size_t hB = CGImageGetHeight(imageB);

    size_t w = MIN(wA, wB);
    size_t h = MIN(hA, hB);

    size_t bytesPerRow = w * 4;
    size_t bufSize = bytesPerRow * h;

    uint8_t *bufA = (uint8_t *)calloc(1, bufSize);
    uint8_t *bufB = (uint8_t *)calloc(1, bufSize);

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctxA = CGBitmapContextCreate(bufA, w, h, 8, bytesPerRow, cs,
                                               kCGImageAlphaPremultipliedLast);
    CGContextRef ctxB = CGBitmapContextCreate(bufB, w, h, 8, bytesPerRow, cs,
                                               kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);

    CGContextDrawImage(ctxA, CGRectMake(0, 0, w, h), imageA);
    CGContextDrawImage(ctxB, CGRectMake(0, 0, w, h), imageB);

    CGContextRelease(ctxA);
    CGContextRelease(ctxB);

    double sumSqDiff = 0.0;
    NSUInteger pixelCount = 0;

    for (size_t y = 0; y < h; y++) {
        for (size_t x = 0; x < w; x++) {
            size_t idx = (y * bytesPerRow) + (x * 4);
            uint8_t rA = bufA[idx], gA = bufA[idx+1], bA = bufA[idx+2], aA = bufA[idx+3];
            uint8_t rB = bufB[idx], gB = bufB[idx+1], bB = bufB[idx+2], aB = bufB[idx+3];

            // Only compare pixels where at least one image has alpha > 0
            if (aA > 0 || aB > 0) {
                double dr = (double)rA - (double)rB;
                double dg = (double)gA - (double)gB;
                double db = (double)bA - (double)bB;
                double da = (double)aA - (double)aB;
                sumSqDiff += dr*dr + dg*dg + db*db + da*da;
                pixelCount++;
            }
        }
    }

    free(bufA);
    free(bufB);

    if (pixelCount == 0) return 100.0;

    double mse = sumSqDiff / (pixelCount * 4.0);
    if (mse == 0.0) return 100.0;

    double psnr = 10.0 * log10((255.0 * 255.0) / mse);
    return psnr;
}


#pragma mark - Diff image generation

- (CGImageRef)diffImageBetweenA:(CGImageRef)imageA B:(CGImageRef)imageB CF_RETURNS_RETAINED {
    if (!imageA || !imageB) return NULL;

    size_t w = MIN(CGImageGetWidth(imageA), CGImageGetWidth(imageB));
    size_t h = MIN(CGImageGetHeight(imageA), CGImageGetHeight(imageB));
    size_t bytesPerRow = w * 4;
    size_t bufSize = bytesPerRow * h;

    uint8_t *bufA = (uint8_t *)calloc(1, bufSize);
    uint8_t *bufB = (uint8_t *)calloc(1, bufSize);
    uint8_t *bufD = (uint8_t *)calloc(1, bufSize);

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctxA = CGBitmapContextCreate(bufA, w, h, 8, bytesPerRow, cs,
                                               kCGImageAlphaPremultipliedLast);
    CGContextRef ctxB = CGBitmapContextCreate(bufB, w, h, 8, bytesPerRow, cs,
                                               kCGImageAlphaPremultipliedLast);
    CGContextRef ctxD = CGBitmapContextCreate(bufD, w, h, 8, bytesPerRow, cs,
                                               kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);

    CGContextDrawImage(ctxA, CGRectMake(0, 0, w, h), imageA);
    CGContextDrawImage(ctxB, CGRectMake(0, 0, w, h), imageB);

    CGContextRelease(ctxA);
    CGContextRelease(ctxB);

    for (size_t i = 0; i < bufSize; i += 4) {
        int dr = abs((int)bufA[i]   - (int)bufB[i]);
        int dg = abs((int)bufA[i+1] - (int)bufB[i+1]);
        int db = abs((int)bufA[i+2] - (int)bufB[i+2]);
        // Amplify differences for visibility (x4)
        bufD[i]   = (uint8_t)MIN(255, dr * 4);
        bufD[i+1] = (uint8_t)MIN(255, dg * 4);
        bufD[i+2] = (uint8_t)MIN(255, db * 4);
        bufD[i+3] = 255;
    }

    CGImageRef diffImage = CGBitmapContextCreateImage(ctxD);
    CGContextRelease(ctxD);

    free(bufA);
    free(bufB);
    free(bufD);

    return diffImage;
}


#pragma mark - PNG saving

- (void)saveCGImage:(CGImageRef)image toPath:(NSString *)path {
    if (!image) return;
    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)url,
                                                                  CFSTR("public.png"), 1, NULL);
    if (dest) {
        CGImageDestinationAddImage(dest, image, NULL);
        CGImageDestinationFinalize(dest);
        CFRelease(dest);
    }
}


#pragma mark - Core comparison

- (void)compareSVGString:(NSString *)svgString
                    name:(NSString *)name
                    size:(CGSize)size
           psnrThreshold:(double)threshold {
    CGImageRef ijsvgImage = [self renderIJSVG:svgString size:size];
    XCTAssertTrue(ijsvgImage != NULL, @"IJSVG render failed for %@", name);
    if (ijsvgImage == NULL) {
        return;
    }

    CGImageRef webkitImage = [self renderWebKit:svgString size:size];
    XCTAssertTrue(webkitImage != NULL, @"WebKit render failed for %@", name);
    if (webkitImage == NULL) {
        CGImageRelease(ijsvgImage);
        return;
    }

    NSString *outDir = [IJSVGWebKitPSNRTests outputDirectory];
    [self saveCGImage:ijsvgImage  toPath:[outDir stringByAppendingPathComponent:
                                          [NSString stringWithFormat:@"%@-ijsvg.png", name]]];
    [self saveCGImage:webkitImage toPath:[outDir stringByAppendingPathComponent:
                                          [NSString stringWithFormat:@"%@-webkit.png", name]]];

    CGImageRef diffImage = [self diffImageBetweenA:ijsvgImage B:webkitImage];
    if (diffImage) {
        [self saveCGImage:diffImage toPath:[outDir stringByAppendingPathComponent:
                                            [NSString stringWithFormat:@"%@-diff.png", name]]];
        CGImageRelease(diffImage);
    }

    double psnr = [self psnrBetweenImageA:ijsvgImage imageB:webkitImage];
    NSLog(@"[%@] PSNR = %.2f dB  IJSVG: %zux%zu  WebKit: %zux%zu",
          name, psnr,
          CGImageGetWidth(ijsvgImage), CGImageGetHeight(ijsvgImage),
          CGImageGetWidth(webkitImage), CGImageGetHeight(webkitImage));

    NSString *psnrLine = [NSString stringWithFormat:@"[%@] PSNR = %.2f dB\n", name, psnr];
    NSString *logPath = [outDir stringByAppendingPathComponent:@"psnr-results.txt"];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (fh == nil) {
        [psnrLine writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [fh seekToEndOfFile];
        [fh writeData:[psnrLine dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }

    CGImageRelease(ijsvgImage);
    CGImageRelease(webkitImage);

    XCTAssertGreaterThanOrEqual(psnr, threshold,
                                @"%@: PSNR %.2f dB is below threshold %.2f dB",
                                name, psnr, threshold);
}

- (void)compareBundledSVG:(NSString *)resourceName
                     size:(CGSize)size
            psnrThreshold:(double)threshold {
    NSString *svg = [self svgStringForBundledResource:resourceName];
    if (svg == nil) {
        return;
    }
    [self compareSVGString:svg name:resourceName size:size psnrThreshold:threshold];
}


#pragma mark - Example test methods (use SVGs already bundled in IJSVGExample)

- (void)testRectangle {
    [self compareBundledSVG:@"Rectangle" size:CGSizeMake(256, 256) psnrThreshold:kDefaultPSNRThreshold];
}

- (void)testGroup {
    [self compareBundledSVG:@"Group" size:CGSizeMake(256, 256) psnrThreshold:kDefaultPSNRThreshold];
}

- (void)testAJDigitalCamera {
    [self compareBundledSVG:@"AJ_Digital_Camera" size:CGSizeMake(256, 256) psnrThreshold:kDefaultPSNRThreshold];
}

- (void)testNewTux {
    [self compareBundledSVG:@"NewTux" size:CGSizeMake(256, 256) psnrThreshold:kDefaultPSNRThreshold];
}

@end
