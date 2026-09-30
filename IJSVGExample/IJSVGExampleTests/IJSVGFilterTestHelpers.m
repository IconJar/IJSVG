#import "IJSVGFilterTestHelpers.h"

static NSUInteger IJSVGTestFilterLayerCount(CALayer* layer)
{
    if(layer == nil) return 0;
    NSUInteger count = [layer isKindOfClass:NSClassFromString(@"IJSVGFilterLayer")] ? 1 : 0;
    count += IJSVGTestFilterLayerCount(layer.mask);
    for(CALayer* child in layer.sublayers) {
        count += IJSVGTestFilterLayerCount(child);
    }
    return count;
}

static void IJSVGDisableTransparencyClip(CALayer* layer)
{
    if([layer isKindOfClass:IJSVGShapeLayer.class] && layer.sublayers.count != 0) {
        CGColorRef clear = CGColorCreateGenericGray(0, 0);
        layer.backgroundColor = clear;
        CGColorRelease(clear);
    }
    for(CALayer* child in layer.sublayers) {
        IJSVGDisableTransparencyClip(child);
    }
}

@implementation XCTestCase (IJSVGFilterTestHelpers)

- (CGContextRef)newBitmapWithSize:(NSUInteger)size flipped:(BOOL)flipped
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    XCTAssertTrue(space != NULL);
    if(space == NULL) {
        return NULL;
    }
    CGContextRef bitmap = CGBitmapContextCreate(NULL, size, size, 8, size * 4,
        space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(bitmap != NULL);
    if(bitmap != NULL && flipped) {
        CGContextTranslateCTM(bitmap, 0, size);
        CGContextScaleCTM(bitmap, 1, -1);
    }
    return bitmap;
}

- (NSData*)renderDocument:(NSString*)document flipped:(BOOL)flipped
{
    return [self renderDocument:document flipped:flipped clipped:NO generalTransparency:NO];
}

- (NSData*)renderDocument:(NSString*)document flipped:(BOOL)flipped
                 clipped:(BOOL)clipped generalTransparency:(BOOL)generalTransparency
{
    XCTAssertNotNil(document);
    if(document == nil) {
        return nil;
    }
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:document error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(svg);
    if(svg == nil) {
        return nil;
    }
    CGContextRef bitmap = [self newBitmapWithSize:64 flipped:flipped];
    if(bitmap == NULL) {
        return nil;
    }
    if(clipped) {
        CGContextClipToRect(bitmap, CGRectMake(7, 5, 46, 51));
    }
    [svg drawInRect:CGRectMake(0, 0, 64, 64) context:bitmap];
    if(generalTransparency) {
        // A transparent background selects the general container path without
        // changing painted pixels. Modify only this reference instance.
        XCTAssertNotNil(svg.rootLayer);
        IJSVGDisableTransparencyClip(svg.rootLayer);
        CGContextClearRect(bitmap, CGRectMake(0, 0, 64, 64));
        [svg drawInRect:CGRectMake(0, 0, 64, 64) context:bitmap];
    }
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(bitmap) length:64 * 64 * 4];
    CGContextRelease(bitmap);
    return pixels;
}

- (NSData*)compositeDocuments:(NSArray<NSString*>*)documents flipped:(BOOL)flipped clipped:(BOOL)clipped
{
    CGContextRef bitmap = [self newBitmapWithSize:64 flipped:NO];
    if(bitmap == NULL) {
        return nil;
    }
    for(NSString* document in documents) {
        NSData* pixels = [self renderDocument:document flipped:flipped clipped:clipped generalTransparency:NO];
        if(pixels == nil) {
            CGContextRelease(bitmap);
            return nil;
        }
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
        XCTAssertTrue(provider != NULL);
        if(provider == NULL) {
            CGContextRelease(bitmap);
            return nil;
        }
        CGImageRef image = CGImageCreate(64, 64, 8, 32, 256, CGBitmapContextGetColorSpace(bitmap),
            (CGBitmapInfo)kCGImageAlphaPremultipliedLast, provider, NULL, false, kCGRenderingIntentDefault);
        CGDataProviderRelease(provider);
        XCTAssertTrue(image != NULL);
        if(image == NULL) {
            CGContextRelease(bitmap);
            return nil;
        }
        CGContextDrawImage(bitmap, CGRectMake(0, 0, 64, 64), image);
        CGImageRelease(image);
    }
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(bitmap) length:64 * 64 * 4];
    CGContextRelease(bitmap);
    return pixels;
}

- (NSInteger)maximumDifference:(NSData*)first other:(NSData*)second
{
    XCTAssertNotNil(first);
    XCTAssertNotNil(second);
    XCTAssertEqual(first.length, second.length);
    if(first == nil || second == nil || first.length == 0 || first.length != second.length) {
        return NSIntegerMax;
    }
    const uint8_t* a = first.bytes;
    const uint8_t* b = second.bytes;
    NSInteger maximum = 0;
    for(NSUInteger index = 0; index < first.length; index++) {
        maximum = MAX(maximum, abs((int)a[index] - (int)b[index]));
    }
    return maximum;
}

- (BOOL)containsPaintedPixels:(NSData*)pixels
{
    const uint8_t* bytes = pixels.bytes;
    for(NSUInteger index = 0; index < pixels.length; index++) {
        if(bytes[index] != 0) {
            return YES;
        }
    }
    return NO;
}

- (void)runWorkers:(NSUInteger)count freshThreads:(BOOL)freshThreads
             block:(void (^)(NSUInteger))block
{
    XCTestExpectation* finished = [self expectationWithDescription:@"All rendering workers finished"];
    finished.expectedFulfillmentCount = count;
    for(NSUInteger index = 0; index < count; index++) {
        dispatch_block_t work = ^{
            @autoreleasepool {
                @try {
                    block(index);
                } @finally {
                    [finished fulfill];
                }
            }
        };
        if(freshThreads) {
            [NSThread detachNewThreadWithBlock:work];
        } else {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), work);
        }
    }
    [self waitForExpectations:@[finished] timeout:30];
}

- (NSData*)filterOptionPixelsForSVG:(IJSVG*)svg flipped:(BOOL)flipped exportImage:(BOOL)exportImage
{
    XCTAssertNotNil(svg);
    if(svg == nil) return nil;
    svg.renderingBackingScaleHelper = ^CGFloat { return 1; };
    CGContextRef bitmap = [self newBitmapWithSize:64 flipped:exportImage ? NO : flipped];
    if(bitmap == NULL) return nil;
    if(exportImage) {
        NSError* error = nil;
        CGImageRef image = [svg newCGImageRefWithSize:CGSizeMake(64, 64) flipped:flipped error:&error];
        XCTAssertNil(error);
        XCTAssertTrue(image != NULL);
        if(image == NULL) {
            CGContextRelease(bitmap);
            return nil;
        }
        CGContextDrawImage(bitmap, CGRectMake(0, 0, 64, 64), image);
        CGImageRelease(image);
    } else {
        [svg drawInRect:CGRectMake(0, 0, 64, 64) context:bitmap];
    }
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(bitmap) length:64 * 64 * 4];
    CGContextRelease(bitmap);
    return pixels;
}

- (void)assertFilterOptionsForDocument:(NSString*)document flipped:(BOOL)flipped exportImage:(BOOL)exportImage
{
    // Strip only filter attributes from these fixtures. Preserve masks, clips,
    // opacity, transforms and definitions to form an independent plain reference.
    NSError* error = nil;
    NSXMLDocument* xml = [[NSXMLDocument alloc] initWithXMLString:document options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(xml);
    if(xml == nil) return;
    NSArray<NSXMLElement*>* elements = [xml nodesForXPath:@"//*[@filter]" error:&error];
    XCTAssertNil(error);
    XCTAssertGreaterThan(elements.count, 0u);
    for(NSXMLElement* element in elements) {
        [element removeAttributeForName:@"filter"];
    }
    IJSVG* reference = IJSVGTestSVGObject(xml.XMLString);
    NSData* plain = [self filterOptionPixelsForSVG:reference flipped:flipped exportImage:exportImage];
    XCTAssertNotNil(plain);
    XCTAssertTrue([self containsPaintedPixels:plain]);
    if(plain == nil) return;

    IJSVG* svg = IJSVGTestSVGObject(document);
    XCTAssertNotNil(svg);
    XCTAssertTrue(svg.renderingOptions.filtersEnabled);
    NSData* enabled = [self filterOptionPixelsForSVG:svg flipped:flipped exportImage:exportImage];
    XCTAssertNotNil(enabled);
    XCTAssertGreaterThan(IJSVGTestFilterLayerCount(svg.rootLayer), 0u);
    if(enabled == nil) return;

    // Reuse an already rendered instance across two off/on cycles, exercising
    // cached layer invalidation and any accelerated filter outputs.
    for(NSNumber* state in @[@NO, @YES, @NO, @YES]) {
        IJSVGRenderingOptions* options = svg.renderingOptions;
        options.filtersEnabled = state.boolValue;
        svg.renderingOptions = options;
        NSData* actual = [self filterOptionPixelsForSVG:svg flipped:flipped exportImage:exportImage];
        XCTAssertEqualObjects(actual, state.boolValue ? enabled : plain, @"filtersEnabled=%@", state);
        if(state.boolValue) {
            XCTAssertGreaterThan(IJSVGTestFilterLayerCount(svg.rootLayer), 0u);
        } else {
            XCTAssertEqual(IJSVGTestFilterLayerCount(svg.rootLayer), 0u);
        }
    }

    // Also disable before the first render, then enable that same instance.
    IJSVG* initiallyDisabled = IJSVGTestSVGObject(document);
    IJSVGRenderingOptions* options = initiallyDisabled.renderingOptions;
    options.filtersEnabled = NO;
    initiallyDisabled.renderingOptions = options;
    XCTAssertEqualObjects([self filterOptionPixelsForSVG:initiallyDisabled flipped:flipped exportImage:exportImage], plain);
    XCTAssertEqual(IJSVGTestFilterLayerCount(initiallyDisabled.rootLayer), 0u);
    options.filtersEnabled = YES;
    initiallyDisabled.renderingOptions = options;
    XCTAssertEqualObjects([self filterOptionPixelsForSVG:initiallyDisabled flipped:flipped exportImage:exportImage], enabled);
    XCTAssertGreaterThan(IJSVGTestFilterLayerCount(initiallyDisabled.rootLayer), 0u);
}

@end
