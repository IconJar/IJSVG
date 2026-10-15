#import <IJSVG/IJSVGFilterPrimitive.h>
#import <IJSVGComponentTransferFilterEffect.h>
#import <IJSVGConvolveMatrixFilterEffect.h>
#import <IJSVGFilterContext.h>
#import <IJSVGLightingFilterEffect.h>
#import <Metal/Metal.h>
#import <XCTest/XCTest.h>

// Supply exact floating-point pixels without rasterization or colour conversion
// obscuring the CPU kernels' numerical results.
@interface IJSVGVectorTestContext : IJSVGFilterContext
@property (nonatomic) NSData* source;
@property (nonatomic) NSMutableData* output;
@property (nonatomic) NSInteger width;
@property (nonatomic) NSInteger height;
@end

@implementation IJSVGVectorTestContext
- (CIImage*)mapImage:(CIImage*)image other:(CIImage*)other operation:(void (^)(const float*, const float*, float*, NSInteger, NSInteger))operation
{
    self.output = [NSMutableData dataWithLength:self.source.length];
    operation(self.source.bytes, NULL, self.output.mutableBytes, self.width, self.height);
    return CIImage.emptyImage;
}

- (CIImage*)mapImage:(CIImage*)image other:(CIImage*)other region:(CGRect)region operation:(void (^)(const float*, const float*, float*, NSInteger, NSInteger))operation
{
    return [self mapImage:image other:other operation:operation];
}
@end

@interface IJSVGFilterVectorTests : XCTestCase
@end

@implementation IJSVGFilterVectorTests
- (IJSVGVectorTestContext*)contextWithWidth:(NSInteger)width height:(NSInteger)height
{
    IJSVGVectorTestContext* context = [[IJSVGVectorTestContext alloc] init];
    context.width = width;
    context.height = height;
    context.extent = context.boundingBox = context.viewPort = CGRectMake(0, 0, width, height);
    context.imageTransform = CGAffineTransformIdentity;
    context.filter = [[IJSVGFilter alloc] init];
    context.filter.contentUnits = IJSVGUnitUserSpaceOnUse;
    NSMutableData* source = [NSMutableData dataWithLength:width * height * 4 * sizeof(float)];
    float* pixels = source.mutableBytes;
    for (NSInteger i = 0; i < width * height; i++) {
        float alpha = (i % 29) / 28.f;
        pixels[i * 4] = alpha * ((i * 3) % 17) / 16.f;
        pixels[i * 4 + 1] = alpha * ((i * 5) % 23) / 22.f;
        pixels[i * 4 + 2] = alpha * ((i * 7) % 31) / 30.f;
        pixels[i * 4 + 3] = alpha;
    }
    context.source = source;
    return context;
}

- (void)testFractionalConvolutionMatchesScalarChannels
{
    IJSVGConvolveMatrixFilterEffect* effect = [[IJSVGConvolveMatrixFilterEffect alloc] init];
    const double weights[] = { 1, 2, -1, 0, 3, 0, -1, 0, 1 };
    for (NSNumber* width in @[ @1, @7, @17 ]) {
        IJSVGVectorTestContext* context = [self contextWithWidth:width.integerValue height:9];
        CIImage* input = [[CIImage imageWithColor:CIColor.whiteColor] imageByCroppingToRect:context.extent];
        for (NSString* edge in @[ @"none", @"duplicate", @"wrap" ]) {
            for (NSNumber* preserve in @[ @NO, @YES ]) {
                IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
                primitive.type = IJSVGNodeTypeFilterConvolveMatrix;
                primitive.parameters = @{ @"kernelMatrix" : @"1 2 -1 0 3 0 -1 0 1", @"divisor" : @"5", @"bias" : @".03", @"kernelUnitLength" : @"1.25 .75", @"edgeMode" : edge, @"preserveAlpha" : preserve.boolValue ? @"true" : @"false" };
                [effect outputImageForPrimitive:primitive inputs:@[ input ] region:context.extent context:context];
                XCTAssertEqual(context.output.length, context.source.length);
                if (context.output == nil) {
                    continue;
                }
                const float* source = context.source.bytes;
                const float* actual = context.output.bytes;
                IJSVGFilterSampler sampler = IJSVGFilterSamplerMake(source, context.width, context.height, input.extent, primitive.edgeMode);
                double maximumError = 0;
                for (NSInteger y = 0; y < context.height; y++) {
                    for (NSInteger x = 0; x < context.width; x++) {
                        double sums[4] = { 0 };
                        for (NSInteger j = 0; j < 3; j++) {
                            for (NSInteger i = 0; i < 3; i++) {
                                double px = x + (i - 1) * 1.25, py = y + (j - 1) * .75;
                                double alpha = IJSVGFilterSamplerValue(&sampler, px, py, 3);
                                for (NSUInteger c = 0; c < 4; c++) {
                                    double value = IJSVGFilterSamplerValue(&sampler, px, py, c);
                                    if (preserve.boolValue) {
                                        value = alpha > 0 ? value / alpha : 0;
                                    }
                                    sums[c] += value * weights[(2 - j) * 3 + 2 - i];
                                }
                            }
                        }
                        NSInteger index = (y * context.width + x) * 4;
                        double alpha = preserve.boolValue ? source[index + 3] : IJSVGFilterClamp(sums[3] / 5 + .03);
                        for (NSUInteger c = 0; c < 4; c++) {
                            double expected = alpha;
                            if (c < 3) {
                                expected = preserve.boolValue ? IJSVGFilterClamp(sums[c] / 5 + .03) * alpha : MIN(alpha, IJSVGFilterClamp(sums[c] / 5 + .03 * alpha));
                            }
                            maximumError = MAX(maximumError, fabs(actual[index + c] - expected));
                        }
                    }
                }
                XCTAssertLessThanOrEqual(maximumError, 1e-7, @"width %@ edge %@ preserve %@", width, edge, preserve);
            }
        }
    }
}

- (void)testComponentTransferMatchesEquationsAcrossBlockAndRowBoundaries
{
    IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
    primitive.type = IJSVGNodeTypeFilterComponentTransfer;
    NSArray* settings = @[
        @{ @"type" : @"gamma", @"amplitude" : @".8", @"exponent" : @".7", @"offset" : @"-.1" },
        @{ @"type" : @"table", @"tableValues" : @"0 .9 .2" },
        @{ @"type" : @"linear", @"slope" : @"1.4", @"intercept" : @"-.2" },
        @{ @"type" : @"discrete", @"tableValues" : @"0 .25 .6 1" }
    ];
    for (NSUInteger c = 0; c < 4; c++) {
        IJSVGFilterPrimitive* child = [[IJSVGFilterPrimitive alloc] init];
        child.type = IJSVGNodeTypeFilterFuncR + c;
        child.parameters = settings[c];
        [primitive addChild:child];
    }
    IJSVGComponentTransferFilterEffect* effect = [[IJSVGComponentTransferFilterEffect alloc] init];
    for (NSNumber* width in @[ @1, @31, @33, @1023, @1024, @1025, @4097 ]) {
        IJSVGVectorTestContext* context = [self contextWithWidth:width.integerValue height:17];
        [effect outputImageForPrimitive:primitive inputs:@[ CIImage.emptyImage ] region:context.extent context:context];
        XCTAssertEqual(context.output.length, context.source.length);
        const float* source = context.source.bytes;
        const float* actual = context.output.bytes;
        if (actual == NULL) {
            continue;
        }
        for (NSInteger i = 0; i < context.width * context.height; i++) {
            float alpha = source[i * 4 + 3];
            float r = alpha > 0 ? source[i * 4] / alpha : 0;
            float g = alpha > 0 ? source[i * 4 + 1] / alpha : 0;
            float b = alpha > 0 ? source[i * 4 + 2] / alpha : 0;
            float a = (float[]) { 0, .25, .6, 1 }[MIN((NSUInteger)(alpha * 4), 3)];
            float red = fmin(1, fmax(0, .8 * pow(r, .7) - .1));
            float green = g < .5 ? 1.8 * g : .9 - 1.4 * (g - .5);
            float blue = fmin(1, fmax(0, 1.4 * b - .2));
            float expected[] = { red * a, green * a, blue * a, a };
            for (NSUInteger c = 0; c < 4; c++) {
                XCTAssertEqualWithAccuracy(actual[i * 4 + c], expected[c], 2e-6);
            }
        }
    }
}

- (void)testPairedLightingNormalsMatchFractionalSamplerAtEdgesAndTails
{
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    XCTAssertNotNil(device, @"Run renderer tests with Metal access.");
    if (device == nil) {
        return;
    }
    CIContext* metal = [CIContext contextWithMTLDevice:device options:nil];
    IJSVGLightingFilterEffect* effect = [[IJSVGLightingFilterEffect alloc] init];
    for (NSNumber* width in @[ @1, @2, @3, @7, @31, @257 ]) {
        IJSVGVectorTestContext* context = [self contextWithWidth:width.integerValue height:width.integerValue + 2];
        context.context = metal;
        for (NSNumber* specular in @[ @NO, @YES ]) {
            for (NSNumber* kind in @[ @(IJSVGNodeTypeFilterDistantLight), @(IJSVGNodeTypeFilterPointLight), @(IJSVGNodeTypeFilterSpotLight) ]) {
                IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
                primitive.type = specular.boolValue ? IJSVGNodeTypeFilterSpecularLighting : IJSVGNodeTypeFilterDiffuseLighting;
                IJSVGFilterPrimitive* light = [[IJSVGFilterPrimitive alloc] init];
                light.type = kind.integerValue;
                light.parameters = @{ @"azimuth" : @"35", @"elevation" : @"50", @"x" : @"4", @"y" : @"5", @"z" : @"20", @"pointsAtX" : @"4", @"pointsAtY" : @"5", @"pointsAtZ" : @"0", @"limitingConeAngle" : @"70" };
                [primitive addChild:light];
                CGRect region = CGRectInset(context.extent, .125, .125);
                CIImage* input = [[CIImage imageWithColor:CIColor.whiteColor] imageByCroppingToRect:region];
                primitive.parameters = @{ @"surfaceScale" : @"3", @"specularExponent" : @"8" };
                [effect outputImageForPrimitive:primitive inputs:@[ input ] region:context.extent context:context];
                NSData* paired = context.output;

                // A negligible fractional change forces the general sampler.
                primitive.parameters = @{ @"surfaceScale" : @"3", @"specularExponent" : @"8", @"kernelUnitLength" : @"1.000000000001 1.000000000001" };
                [effect outputImageForPrimitive:primitive inputs:@[ input ] region:context.extent context:context];
                XCTAssertEqual(paired.length, context.output.length);
                const float* a = paired.bytes;
                const float* b = context.output.bytes;
                double maximum = 0;
                NSUInteger worst = 0;
                CGRect sampledRegion = CGRectIntersection(input.extent, context.extent);
                NSUInteger compared = 0;
                for (NSUInteger index = 0; index < paired.length / sizeof(float); index++) {
                    NSInteger x = (index / 4) % context.width;
                    NSInteger y = (index / 4) / context.width;

                    // Core Image can round the input extent. At exact edge
                    // thresholds, changing spacing selects a different SVG
                    // edge stencil, so those are not equivalent reference cases.
                    double epsilon = 1e-12;
                    if ((x - 1 < CGRectGetMinX(sampledRegion)) != (x - 1 - epsilon < CGRectGetMinX(sampledRegion))
                        || (x + 1 >= CGRectGetMaxX(sampledRegion)) != (x + 1 + epsilon >= CGRectGetMaxX(sampledRegion))
                        || (y - 1 < CGRectGetMinY(sampledRegion)) != (y - 1 - epsilon < CGRectGetMinY(sampledRegion))
                        || (y + 1 >= CGRectGetMaxY(sampledRegion)) != (y + 1 + epsilon >= CGRectGetMaxY(sampledRegion))) {
                        continue;
                    }
                    compared++;
                    double difference = fabs(a[index] - b[index]);
                    if (difference > maximum) {
                        maximum = difference;
                        worst = index;
                    }
                }
                XCTAssertGreaterThan(compared, 0u);
                XCTAssertLessThanOrEqual(maximum, 2e-5, @"width %@ specular %@ kind %@ index %lu", width, specular, kind, (unsigned long)worst);
            }
        }
    }
}
@end
