#import <AppKit/AppKit.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGFilterPrimitive.h>
#import <IJSVG/IJSVGGradient.h>
#import <IJSVG/IJSVGPath.h>
#import <Metal/Metal.h>
#import <XCTest/XCTest.h>

@interface IJSVGDetachedGradientTests : XCTestCase
@end

@implementation IJSVGDetachedGradientTests

- (NSString*)document:(NSString*)body
{
    return [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='80' height='60' viewBox='10 20 80 60'>%@</svg>", body];
}

- (NSString*)artworkWithRadialGradient:(BOOL)radial percentage:(BOOL)percentage
{
    NSString* kind = radial ? @"radialGradient" : @"linearGradient";
    NSString* coordinates;
    if(radial) {
        coordinates = percentage ?
            @"cx='60%' cy='70%' fx='35%' fy='55%' r='45%' fr='10%'" :
            @"cx='48' cy='42' fx='28' fy='33' r='27' fr='6'";
    } else {
        coordinates = percentage ?
            @"x1='25%' y1='25%' x2='100%' y2='100%'" :
            @"x1='20' y1='15' x2='80' y2='60'";
    }
    return [NSString stringWithFormat:
        @"<defs><%@ id='g' gradientUnits='userSpaceOnUse' %@ "
         "gradientTransform='translate(3 -2) rotate(8)'>"
         "<stop stop-color='#e93152'/><stop offset='.45' stop-color='#f3c849'/>"
         "<stop offset='1' stop-color='#238add'/></%@></defs>"
         "<path d='M26 32H70V66H26Z' fill='url(#g)'/>", kind, coordinates, kind];
}

- (NSData*)render:(IJSVG*)svg width:(NSUInteger)width
{
    NSUInteger height = width * 3 / 4;
    svg.renderingBackingScaleHelper = ^CGFloat { return 1.f; };
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
                                                 space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) return nil;
    [svg drawInRect:CGRectMake(0, 0, width, height) context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context)
                                   length:width * height * 4];
    CGContextRelease(context);
    return pixels;
}

- (void)assertPixels:(NSData*)actual match:(NSData*)expected
{
    XCTAssertNotNil(actual);
    XCTAssertNotNil(expected);
    XCTAssertEqual(actual.length, expected.length);
    if(actual == nil || expected == nil || actual.length != expected.length) return;
    const UInt8* a = actual.bytes;
    const UInt8* b = expected.bytes;
    NSInteger largestError = 0;
    BOOL hasVisiblePixels = NO;
    for(NSUInteger index = 0; index < actual.length; index++) {
        largestError = MAX(largestError, labs((NSInteger)a[index] - b[index]));
        if(index % 4 == 3 && b[index] != 0) hasVisiblePixels = YES;
    }
    XCTAssertTrue(hasVisiblePixels);
    XCTAssertLessThanOrEqual(largestError, 1);
}

- (void)checkRadialGradient:(BOOL)radial percentage:(BOOL)percentage
{
    // Without Metal, filters may silently omit their output.
    XCTAssertNotNil(MTLCreateSystemDefaultDevice());
    if(MTLCreateSystemDefaultDevice() == nil) return;
    NSString* artwork = [self document:[self artworkWithRadialGradient:radial percentage:percentage]];
    IJSVG* attached = [[IJSVG alloc] initWithSVGString:artwork];
    IJSVG* absolute = [[IJSVG alloc] initWithSVGString:
        [self document:[self artworkWithRadialGradient:radial percentage:NO]]];
    XCTAssertNotNil(attached);
    XCTAssertNotNil(absolute);
    for(NSNumber* snapshots in @[@NO, @YES]) {
        IJSVG* source = [[IJSVG alloc] initWithSVGString:artwork];
        IJSVGPath* shape = (IJSVGPath*)[source.rootNode.children.firstObject copy];
        XCTAssertTrue([shape isKindOfClass:IJSVGPath.class]);
        shape.parentNode = nil;
        shape.styleParent = nil;
        shape.svg = nil;
        IJSVGGradient* gradient = (IJSVGGradient*)[shape.fill copy];
        XCTAssertTrue([gradient isKindOfClass:IJSVGGradient.class]);
        gradient.parentNode = nil;
        gradient.styleParent = nil;
        gradient.svg = nil;
        shape.fill = gradient;
        IJSVG* filtered = [[IJSVG alloc] initWithSVGString:[self document:
            @"<defs><filter id='f' filterUnits='userSpaceOnUse' x='10' y='20' width='80' height='60'>"
             "<feImage x='10' y='20' width='80' height='60'/></filter></defs>"
             "<path d='M10 20H90V80H10Z' filter='url(#f)'/>"]];
        IJSVGFilterPrimitive* primitive = filtered.rootNode.children.firstObject.filter.primitives.firstObject;
        XCTAssertNotNil(primitive);
        primitive.imageNode = shape;
        // imageNode takes precedence in the evaluator. An unused bitmap fallback
        // disables automatic snapshots without changing process-wide behavior.
        if(!snapshots.boolValue) primitive.image = [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];
        // Exercise first render, cache reuse, resizing, and restoring the original size.
        for(NSNumber* width in @[@160, @160, @240, @160]) {
            NSData* expected = [self render:attached width:width.unsignedIntegerValue];
            [self assertPixels:[self render:absolute width:width.unsignedIntegerValue] match:expected];
            [self assertPixels:[self render:filtered width:width.unsignedIntegerValue] match:expected];
        }
    }
}

- (void)testDetachedLinearAbsoluteGradient
{
    [self checkRadialGradient:NO percentage:NO];
}

- (void)testDetachedLinearPercentageGradient
{
    [self checkRadialGradient:NO percentage:YES];
}

- (void)testDetachedRadialAbsoluteGradient
{
    [self checkRadialGradient:YES percentage:NO];
}

- (void)testDetachedRadialPercentageGradient
{
    [self checkRadialGradient:YES percentage:YES];
}

@end
