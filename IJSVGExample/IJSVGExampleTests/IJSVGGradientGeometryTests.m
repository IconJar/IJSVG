#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGGradient.h>
#import <IJSVG/IJSVGTransform.h>
#import <XCTest/XCTest.h>

@interface IJSVGGradientGeometryTests: XCTestCase
@end

@implementation IJSVGGradientGeometryTests

- (NSString*)documentWithRadialGradient:(BOOL)radial
                              userSpace:(BOOL)userSpace
{
    NSString* kind = radial ? @"radialGradient" : @"linearGradient";
    NSString* coordinates = radial ?
        @"cx='60%' cy='45%' fx='35%' fy='30%' r='65%' fr='10%'" :
        @"x1='5%' y1='10%' x2='100%' y2='85%'";
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' "
                                       "viewBox='0 0 32 32'><defs><%@ id='g' gradientUnits='%@' %@ "
                                       "gradientTransform='translate(.1 .2) rotate(8) scale(.9 1.1)'>"
                                       "<stop stop-color='#e93152'/><stop offset='.45' "
                                       "stop-color='#f3c849'/><stop offset='1' stop-color='#238add'/>"
                                       "</%@></defs><path d='M3 4H26V24H3Z' fill='url(#g)' "
                                       "stroke='url(#g)' stroke-width='2'/><circle cx='22' cy='23' r='6' "
                                       "fill='url(#g)' transform='rotate(12 16 16)'/></svg>",
                                      kind,
                                      userSpace ? @"userSpaceOnUse" : @"objectBoundingBox",
                                      coordinates,
                                      kind];
}

- (NSData*)render:(IJSVG*)svg
             size:(CGSize)size
            scale:(CGFloat)scale
{
    svg.renderingBackingScaleHelper = ^CGFloat { return scale; };
    size_t width = (size_t)ceil((size.width + 6.f) * scale);
    size_t height = (size_t)ceil((size.height + 6.f) * scale);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8,
                                                 width * 4, space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) return nil;
    CGContextScaleCTM(context, scale, scale);
    [svg drawInRect:CGRectMake(1.25f, 2.5f, size.width, size.height)
            context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context)
                                    length:width * height * 4];
    CGContextRelease(context);
    return pixels;
}

- (void)testGradientGeometryMatchesFreshRenderingAfterResize
{
    const CGSize sizes[] = {{32, 32}, {32, 32}, {160, 160}, {47, 83}, {24, 24}, {32, 32}};
    const CGFloat scales[] = {1, 1, 2, 2, 1, 1};
    for(NSNumber* radial in @[@NO, @YES]) {
        for(NSNumber* userSpace in @[@NO, @YES]) {
            NSString* document = [self documentWithRadialGradient:radial.boolValue
                                                        userSpace:userSpace.boolValue];
            IJSVG* reused = [[IJSVG alloc] initWithSVGString:document];
            XCTAssertNotNil(reused);
            for(NSUInteger index = 0; index < sizeof(scales) / sizeof(scales[0]); index++) {
                IJSVG* fresh = [[IJSVG alloc] initWithSVGString:document];
                XCTAssertNotNil(fresh);
                NSData* actual = [self render:reused
                                         size:sizes[index]
                                        scale:scales[index]];
                NSData* expected = [self render:fresh
                                           size:sizes[index]
                                          scale:scales[index]];
                XCTAssertNotNil(actual);
                XCTAssertEqualObjects(actual, expected,
                                      @"Radial %@ user space %@ step %lu",
                                      radial, userSpace, index);
            }
        }
    }
}

- (void)testInvalidationRefreshesGradientEndpointsAndTransforms
{
    NSString* document = [self documentWithRadialGradient:NO
                                                userSpace:YES];
    IJSVG* reused = [[IJSVG alloc] initWithSVGString:document];
    XCTAssertNotNil(reused);
    CGSize size = CGSizeMake(64, 64);
    NSData* before = [self render:reused
                             size:size
                            scale:1.f];
    IJSVGGradient* gradient = (IJSVGGradient*)reused.rootNode.children.firstObject.fill;
    XCTAssertTrue([gradient isKindOfClass:IJSVGGradient.class]);
    gradient.x2 = [IJSVGUnitLength unitWithString:@"20%"
                                     fromUnitType:gradient.units];
    gradient.transforms = [IJSVGTransform transformsForString:@"rotate(-15) scale(.8 1.2)"];
    [reused setNeedsDisplay];
    NSData* actual = [self render:reused
                             size:size
                            scale:1.f];
    IJSVG* fresh = [[IJSVG alloc] initWithSVGString:document];
    IJSVGGradient* freshGradient = (IJSVGGradient*)fresh.rootNode.children.firstObject.fill;
    freshGradient.x2 = [IJSVGUnitLength unitWithString:@"20%"
                                          fromUnitType:freshGradient.units];
    freshGradient.transforms = [IJSVGTransform transformsForString:@"rotate(-15) scale(.8 1.2)"];
    NSData* expected = [self render:fresh
                               size:size
                              scale:1.f];
    XCTAssertNotNil(actual);
    XCTAssertNotEqualObjects(before, actual);
    XCTAssertEqualObjects(actual, expected);
}

@end
