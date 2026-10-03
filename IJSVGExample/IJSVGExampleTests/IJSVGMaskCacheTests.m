#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <XCTest/XCTest.h>

@interface IJSVGMaskCacheTests : XCTestCase
@end

@implementation IJSVGMaskCacheTests

- (NSString*)document
{
    return @"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'>"
        "<defs>"
        "<linearGradient id='fade'><stop stop-color='white'/><stop offset='1' stop-color='black'/></linearGradient>"
        "<mask id='m' maskUnits='userSpaceOnUse' x='0' y='0' width='32' height='32'>"
        "<circle cx='16' cy='16' r='13' fill='url(#fade)'/>"
        "</mask></defs>"
        "<rect width='32' height='32' fill='#ef4732' mask='url(#m)'/>"
        "</svg>";
}

- (NSData*)render:(IJSVG*)svg size:(CGSize)size scale:(CGFloat)scale translated:(BOOL)translated
{
    svg.renderingBackingScaleHelper = ^CGFloat { return scale; };
    size_t width = (size_t)ceil((size.width + 8.f) * scale);
    size_t height = (size_t)ceil((size.height + 8.f) * scale);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
        space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) return nil;
    CGContextScaleCTM(context, scale, scale);
    CGPoint origin = translated ? CGPointMake(2.25f, 1.75f) : CGPointZero;
    [svg drawInRect:(CGRect){ origin, size } context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:width * height * 4];
    CGContextRelease(context);
    return pixels;
}

- (void)testRedrawAtDifferentSizesAndBackingScalesMatchesFreshRendering
{
    IJSVG* reused = [[IJSVG alloc] initWithSVGString:self.document];
    XCTAssertNotNil(reused);
    const CGSize sizes[] = {
        {32, 32}, {32, 32}, {160, 160}, {160, 160},
        {47, 83}, {23, 23}, {32, 32}
    };
    const CGFloat scales[] = {1, 1, 1, 2, 2, 1, 1};
    for(NSUInteger index = 0; index < sizeof(scales) / sizeof(scales[0]); index++) {
        for(NSNumber* translated in @[@NO, @YES]) {
            IJSVG* fresh = [[IJSVG alloc] initWithSVGString:self.document];
            XCTAssertNotNil(fresh);
            NSData* actual = [self render:reused size:sizes[index] scale:scales[index]
                              translated:translated.boolValue];
            NSData* expected = [self render:fresh size:sizes[index] scale:scales[index]
                                translated:translated.boolValue];
            XCTAssertNotNil(actual);
            XCTAssertEqualObjects(actual, expected, @"Step %lu, translated %@", index, translated);
        }
    }
}

- (void)testChangingRenderQualityMatchesFreshRendering
{
    IJSVG* reused = [[IJSVG alloc] initWithSVGString:self.document];
    NSArray<NSNumber*>* qualities = @[@(kIJSVGRenderQualityFullResolution),
        @(kIJSVGRenderQualityLow), @(kIJSVGRenderQualityOptimized),
        @(kIJSVGRenderQualityFullResolution)];
    for(NSNumber* quality in qualities) {
        IJSVGRenderingOptions* options = reused.renderingOptions;
        options.renderQuality = quality.integerValue;
        reused.renderingOptions = options;
        IJSVG* fresh = [[IJSVG alloc] initWithSVGString:self.document];
        fresh.renderingOptions = options;
        CGSize size = CGSizeMake(79, 79);
        NSData* actual = [self render:reused size:size scale:2.f translated:NO];
        NSData* expected = [self render:fresh size:size scale:2.f translated:NO];
        XCTAssertNotNil(actual);
        XCTAssertEqualObjects(actual, expected);
    }
}

- (void)testArtworkInvalidationRebuildsMask
{
    IJSVG* reused = [[IJSVG alloc] initWithSVGString:self.document];
    XCTAssertNotNil(reused);
    CGSize size = CGSizeMake(64, 64);
    NSData* before = [self render:reused size:size scale:1.f translated:NO];
    IJSVGPath* circle = (IJSVGPath*)reused.rootNode.children.firstObject.mask.children.firstObject;
    XCTAssertTrue([circle isKindOfClass:IJSVGPath.class]);
    XCTAssertNotNil(circle.r);
    circle.r.value = 6.f;
    [reused setNeedsDisplay];
    NSData* after = [self render:reused size:size scale:1.f translated:NO];
    IJSVG* fresh = [[IJSVG alloc] initWithSVGString:self.document];
    IJSVGPath* freshCircle = (IJSVGPath*)fresh.rootNode.children.firstObject.mask.children.firstObject;
    freshCircle.r.value = 6.f;
    NSData* expected = [self render:fresh size:size scale:1.f translated:NO];
    XCTAssertNotNil(before);
    XCTAssertNotNil(after);
    XCTAssertNotEqualObjects(before, after);
    XCTAssertEqualObjects(after, expected);
}

@end
