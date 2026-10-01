#import <IJSVGFilterTestHelpers.h>
#import <CoreImage/CoreImage.h>

@interface IJSVGFilterConcurrencyTests : XCTestCase
@end

static double IJSVGTestLinearChannel(double value)
{
    return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
}

static double IJSVGTestEncodedChannel(double value)
{
    return value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1 / 2.4) - 0.055;
}

static double IJSVGTestArithmetic(double a, double b, NSArray<NSNumber*>* coefficients)
{
    return coefficients[0].doubleValue * a * b + coefficients[1].doubleValue * a
        + coefficients[2].doubleValue * b + coefficients[3].doubleValue;
}

static void IJSVGTestNestedOutput(NSUInteger depth)
{
    [IJSVGThreadManager performCIOutputBlock:^{
        if(depth > 0) {
            IJSVGTestNestedOutput(depth - 1);
        }
    }];
}

@implementation IJSVGFilterConcurrencyTests

- (void)testArithmeticPreservesPremultipliedChannels
{
    // Signed/product arithmetic, constants, alpha clamping and the CPU fallback
    // above the Metal coefficient limit must obey the same scalar equation.
    NSArray<NSArray<NSNumber*>*>* combinations = @[
        @[@0, @-1, @1, @0], @[@0.4, @-0.3, @0.8, @0.07], @[@0, @0, @0, @0.2],
        @[@0, @0.3, @0.7, @0], @[@16, @-16, @16, @-1], @[@17, @-16, @16, @-1],
        @[@0, @-1, @0, @0]
    ];
    for(NSString* colorSpace in @[@"sRGB", @"linearRGB"]) {
        for(NSArray<NSNumber*>* coefficients in combinations) {
            NSString* name = [NSString stringWithFormat:@"%@ coefficients=%@", colorSpace, coefficients];
            [XCTContext runActivityNamed:name block:^(id<XCTActivity> activity) {
                NSString* xml = [NSString stringWithFormat:
                    @"<svg xmlns='http://www.w3.org/2000/svg' width='8' height='8'>"
                    "<defs><filter id='f' x='0' y='0' width='8' height='8' filterUnits='userSpaceOnUse' "
                    "color-interpolation-filters='%@'>"
                    "<feFlood flood-color='#804020' flood-opacity='.5' result='a'/>"
                    "<feFlood flood-color='#2080c0' flood-opacity='.75' result='b'/>"
                    "<feComposite in='a' in2='b' operator='arithmetic' k1='%@' k2='%@' k3='%@' k4='%@'/>"
                    "</filter></defs><rect width='8' height='8' filter='url(#f)'/></svg>",
                    colorSpace, coefficients[0], coefficients[1], coefficients[2], coefficients[3]];
                IJSVG* svg = IJSVGTestSVGObject(xml);
                XCTAssertNotNil(svg);
                CGContextRef bitmap = [self newBitmapWithSize:8 flipped:NO];
                if(svg == nil || bitmap == NULL) {
                    if(bitmap != NULL) CGContextRelease(bitmap);
                    return;
                }
                [svg drawInRect:CGRectMake(0, 0, 8, 8) context:bitmap];
                const uint8_t* bytes = CGBitmapContextGetData(bitmap);
                double first[] = {128, 64, 32}, second[] = {32, 128, 192};
                double alpha = MIN(1, MAX(0, IJSVGTestArithmetic(0.5, 0.75, coefficients)));
                BOOL linear = [colorSpace isEqualToString:@"linearRGB"];
                for(NSUInteger channel = 0; channel < 3; channel++) {
                    double a = first[channel] / 255, b = second[channel] / 255;
                    double result = IJSVGTestArithmetic((linear ? IJSVGTestLinearChannel(a) : a) * 0.5,
                        (linear ? IJSVGTestLinearChannel(b) : b) * 0.75, coefficients);
                    double clamped = MIN(alpha, MAX(0, result));
                    double expected = linear && alpha > 0 ? IJSVGTestEncodedChannel(clamped / alpha) * alpha : clamped;
                    XCTAssertLessThanOrEqual(fabs(bytes[4 * (4 * 8 + 4) + channel] - expected * 255), 2,
                        @"%@ channel=%lu", name, (unsigned long)channel);
                }
                XCTAssertLessThanOrEqual(fabs(bytes[4 * (4 * 8 + 4) + 3] - alpha * 255), 1, @"%@", name);
                CGContextRelease(bitmap);
            }];
        }
    }
}

- (void)leaseDepth:(NSUInteger)depth contexts:(NSHashTable<CIContext*>*)contexts callbacks:(NSUInteger*)callbacks
{
    [IJSVGThreadManager performBlockWithCIContext:^(CIContext* context, BOOL supportsMetalKernels) {
        (*callbacks)++;
        XCTAssertNotNil(context);
        if(context != nil) {
            [contexts addObject:context];
        }
        if(depth > 0) {
            [self leaseDepth:depth - 1 contexts:contexts callbacks:callbacks];
        }
    }];
}

- (void)testNestedContextLeasesDoNotDeadlock
{
    // Retain contexts and compare identity, so addresses cannot be reused.
    NSHashTable* contexts = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory
        | NSPointerFunctionsObjectPointerPersonality];
    __block NSUInteger callbacks = 0;
    [self runWorkers:1 freshThreads:YES block:^(NSUInteger index) {
        [self leaseDepth:12 contexts:contexts callbacks:&callbacks];
    }];
    XCTAssertEqual(callbacks, 13u);
    // Other callers may hold slots; nested leases can reuse fewer than six contexts.
    XCTAssertGreaterThan(contexts.count, 0u);
    XCTAssertLessThanOrEqual(contexts.count, 6u);
}

- (void)testOutputSlotsSupportNestedCallsAndWorkerReplacement
{
    NSObject* lock = [[NSObject alloc] init];
    __block NSUInteger active = 0, maximum = 0, finished = 0;
    for(NSUInteger batch = 0; batch < 3; batch++) {
        [self runWorkers:12 freshThreads:YES block:^(NSUInteger index) {
            [IJSVGThreadManager performCIOutputBlock:^{
                @synchronized(lock) {
                    active++;
                    maximum = MAX(maximum, active);
                }
                IJSVGTestNestedOutput(12);
                [NSThread sleepForTimeInterval:0.002];
                @synchronized(lock) {
                    active--;
                    finished++;
                }
            }];
        }];
    }
    XCTAssertLessThanOrEqual(maximum, 2u);
    XCTAssertEqual(finished, 36u);
}

- (NSData*)atlasPixelsForIndex:(NSUInteger)index nested:(BOOL)nested
{
    NSMutableString* shapes = [[NSMutableString alloc] init];
    for(NSUInteger shape = 0; shape < 6; shape++) {
        [shapes appendFormat:@"<circle cx='%lu' cy='%lu' r='9' fill='rgb(%lu,%lu,150)' opacity='.7' filter='url(#blur)'/>",
            (unsigned long)(8 + shape * 8), (unsigned long)(12 + (shape + index) % 4 * 9),
            (unsigned long)(30 + index * 13), (unsigned long)(40 + shape * 23)];
    }
    NSString* xml = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64'><defs>"
        "<filter id='blur' color-interpolation-filters='linearRGB'>"
        "<feGaussianBlur stdDeviation='.9 1.3'/><feOffset dx='.4' dy='-.6'/></filter>"
        "<filter id='outer'><feGaussianBlur stdDeviation='.5'/></filter></defs>"
        "<g %@>%@</g></svg>", nested ? @"filter='url(#outer)'" : @"", shapes];
    return [self renderDocument:xml flipped:index % 2 == 0];
}

- (void)testConcurrentAtlasPixelsMatchSerialRendering
{
    for(NSNumber* nested in @[@NO, @YES]) {
        [XCTContext runActivityNamed:[NSString stringWithFormat:@"nested=%@", nested]
                              block:^(id<XCTActivity> activity) {
            NSMutableArray<NSData*>* references = [[NSMutableArray alloc] init];
            for(NSUInteger index = 0; index < 12; index++) {
                NSData* pixels = [self atlasPixelsForIndex:index nested:nested.boolValue];
                XCTAssertNotNil(pixels);
                if(pixels == nil) return;
                [references addObject:pixels];
            }
            for(NSUInteger batch = 0; batch < 3; batch++) {
                [self runWorkers:12 freshThreads:NO block:^(NSUInteger index) {
                    NSData* pixels = [self atlasPixelsForIndex:index nested:nested.boolValue];
                    XCTAssertEqualObjects(pixels, references[index], @"nested=%@ index=%lu batch=%lu",
                        nested, (unsigned long)index, (unsigned long)batch);
                }];
            }
        }];
    }
}

- (void)testContextsSurviveWorkerReplacement
{
    NSObject* lock = [[NSObject alloc] init];
    NSHashTable* contexts = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory
        | NSPointerFunctionsObjectPointerPersonality];
    __block NSUInteger renders = 0;
    // Each batch uses fresh dedicated threads, with more callers than pool slots.
    for(NSUInteger batch = 0; batch < 3; batch++) {
        [self runWorkers:12 freshThreads:YES block:^(NSUInteger index) {
            [IJSVGThreadManager performBlockWithCIContext:^(CIContext* context, BOOL supportsMetalKernels) {
                XCTAssertNotNil(context);
                if(context == nil) return;
                @synchronized(lock) {
                    [contexts addObject:context];
                }
                CIImage* image = [CIImage imageWithColor:[CIColor colorWithRed:1 green:0 blue:0]];
                CGImageRef output = [context createCGImage:image fromRect:CGRectMake(0, 0, 4, 4)];
                if(output != NULL) {
                    @synchronized(lock) {
                        renders++;
                    }
                    CGImageRelease(output);
                }
            }];
        }];
    }
    XCTAssertGreaterThan(contexts.count, 0u);
    XCTAssertLessThanOrEqual(contexts.count, 6u);
    XCTAssertEqual(renders, 36u);
}

@end
