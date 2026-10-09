#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGFilterPrimitive.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGColorNode.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// Standalone profiling only: no hooks are installed in the framework or app.
// Count explicit bitmap requests, not resident memory or internal GPU allocations.
extern BOOL recording;
extern NSUInteger bitmapCount, bitmapBytes, snapshotCount;
#ifdef IJSVG_BITMAP_PROBE
BOOL recording;
NSUInteger bitmapCount, bitmapBytes, snapshotCount;
#else
static NSUInteger conversionCount;
static IMP originalFilterDraw;
static NSMutableDictionary<NSString*, NSNumber*>* filterTimes;
static void countedFilterDraw(id paint, SEL selector, CGContextRef context)
{
    double start = CACurrentMediaTime();
    ((void (*)(id, SEL, CGContextRef))originalFilterDraw)(paint, selector, context);
    if(recording) {
        NSString* key = [[paint valueForKey:@"filter"] valueForKey:@"identifier"] ?: @"unnamed";
        filterTimes[key] = @([filterTimes[key] doubleValue] + (CACurrentMediaTime() - start) * 1000);
    }
}
#endif

#ifdef IJSVG_BITMAP_PROBE
static CGContextRef countedBitmap(void* data, size_t width, size_t height,
    size_t bits, size_t stride, CGColorSpaceRef space, uint32_t info)
{
    CGContextRef result = CGBitmapContextCreate(data, width, height, bits, stride, space, info);
    if(recording && result != NULL) {
        bitmapCount++;
        bitmapBytes += CGBitmapContextGetBytesPerRow(result) * CGBitmapContextGetHeight(result);
    }
    return result;
}

static CGImageRef countedSnapshot(CGContextRef context)
{
    if(recording) snapshotCount++;
    return CGBitmapContextCreateImage(context);
}

__attribute__((used, section("__DATA,__interpose"))) static const struct {
    const void* replacement;
    const void* original;
} interpositions[] = {
    { (const void*)countedBitmap, (const void*)CGBitmapContextCreate },
    { (const void*)countedSnapshot, (const void*)CGBitmapContextCreateImage }
};

#else

static IMP originalConversion;
// Benchmark-only control: retain the preceding cache policy while disabling
// the newly added detached feImage snapshots. Never changes framework files.
static void disableImageSnapshots(id paint, SEL selector) {}
static CGImageRef countedConversion(id context, SEL selector, CIImage* image,
    CGRect rect, CIFormat format, CGColorSpaceRef space)
{
    if(recording) conversionCount++;
    return ((CGImageRef (*)(id, SEL, CIImage*, CGRect, CIFormat, CGColorSpaceRef))
        originalConversion)(context, selector, image, rect, format, space);
}

static IJSVG* newSVG(NSString* xml, NSUInteger size)
{
    NSError* error = nil;
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml error:&error];
    if(svg == nil) {
        NSLog(@"Cannot parse SVG: %@", error);
        exit(2);
    }
    if(getenv("IJSVG_BENCH_VECTOR_IMAGE") != NULL) {
        IJSVGFilterPrimitive* primitive = svg.rootNode.children.firstObject.filter.primitives.firstObject;
        if(primitive.type != IJSVGNodeTypeFilterImage) exit(8);
        IJSVGPath* image = [[IJSVGPath alloc] init];
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathAddRoundedRect(path, NULL, CGRectMake(4, 4, 24, 24), 4, 4);
        image.path = path;
        CGPathRelease(path);
        image.fill = [IJSVGColorNode colorNodeWithColor:NSColor.orangeColor];
        primitive.imageNode = image;
    }
    svg.renderingBackingScaleHelper = ^CGFloat { return 1.f; };
    return svg;
}

static double draw(IJSVG* svg, CGContextRef bitmap, NSUInteger size)
{
    CGRect rect = CGRectMake(0, 0, size, size);
    CGContextClearRect(bitmap, rect);
    double start = CACurrentMediaTime();
    CGContextSaveGState(bitmap);
    [svg drawInRect:rect context:bitmap];
    CGContextRestoreGState(bitmap);
    return (CACurrentMediaTime() - start) * 1000;
}

static double median(NSArray<NSNumber*>* values)
{
    NSArray* sorted = [values sortedArrayUsingSelector:@selector(compare:)];
    return [sorted[sorted.count / 2] doubleValue];
}

static void profile(IJSVG* svg, CGContextRef bitmap, NSUInteger size,
    NSString* asset, const char* phase)
{
    bitmapCount = bitmapBytes = snapshotCount = conversionCount = 0;
    filterTimes = [[NSMutableDictionary alloc] init];
    recording = YES;
    draw(svg, bitmap, size);
    recording = NO;
    fprintf(stderr, "%s,%lu,%s,%lu,%lu,%lu,%lu\n", asset.UTF8String,
        size, phase, bitmapCount, bitmapBytes, snapshotCount, conversionCount);
    for(NSString* name in [[filterTimes allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        fprintf(stderr, "filter_inclusive_ms,%s,%s,%.3f\n", phase,
            name.UTF8String, filterTimes[name].doubleValue);
    }
}

int main(int argc, char** argv)
{
    @autoreleasepool {
        if(argc != 4) {
            fprintf(stderr, "Usage: StickerRendering input.svg size output.rgba\n");
            return 1;
        }
        // IJSVG omits filter paints when Metal is unavailable. Reject that run
        // instead of publishing misleading unfiltered rendering measurements.
        if(MTLCreateSystemDefaultDevice() == nil) {
            fprintf(stderr, "Metal unavailable; filter profiling cannot run in this environment.\n");
            return 7;
        }
        if(getenv("IJSVG_BENCH_DISABLE_IMAGE_SNAPSHOTS") != NULL) {
            Method snapshots = class_getInstanceMethod(NSClassFromString(@"IJSVGFilterPaint"),
                NSSelectorFromString(@"prepareImageSnapshots"));
            if(snapshots == NULL) return 9;
            method_setImplementation(snapshots, (IMP)disableImageSnapshots);
        }
        NSUInteger size = [@(argv[2]) integerValue];
        if(size == 0 || size > 4096) return 1;
        NSString* xml = [NSString stringWithContentsOfFile:@(argv[1])
            encoding:NSUTF8StringEncoding error:NULL];
        if(xml == nil) return 2;
        NSString* asset = [@(argv[1]) lastPathComponent];
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef bitmap = CGBitmapContextCreate(NULL, size, size, 8,
            size * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(space);
        if(bitmap == NULL) return 3;

        // Parsing and destination allocation are excluded. The first draw includes
        // paint preparation and process-wide lazy initialization; report it alone.
        IJSVG* svg = newSVG(xml, size);
        double processFirst = draw(svg, bitmap, size);
        NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(bitmap)
            length:CGBitmapContextGetBytesPerRow(bitmap) * size];
        if(![pixels writeToFile:@(argv[3]) atomically:YES]) return 4;
        NSMutableArray* fresh = [[NSMutableArray alloc] init];
        NSMutableArray* repeated = [[NSMutableArray alloc] init];
        for(NSUInteger index = 0; index < 15; index++) {
            @autoreleasepool {
                // Alternate order to reduce systematic temperature/order bias.
                IJSVG* instance = newSVG(xml, size);
                if(index % 2 == 0) {
                    [fresh addObject:@(draw(instance, bitmap, size))];
                    [repeated addObject:@(draw(svg, bitmap, size))];
                } else {
                    [repeated addObject:@(draw(svg, bitmap, size))];
                    [fresh addObject:@(draw(instance, bitmap, size))];
                }
            }
        }
        // Save a repeated draw too, so cache-hit output can be compared separately.
        draw(svg, bitmap, size);
        NSData* repeatedPixels = [NSData dataWithBytes:CGBitmapContextGetData(bitmap)
            length:CGBitmapContextGetBytesPerRow(bitmap) * size];
        if(![repeatedPixels writeToFile:[@(argv[3]) stringByAppendingString:@".repeated"]
                            atomically:YES]) return 4;
        puts("asset,size,process_first_ms,fresh_instance_median_ms,repeated_median_ms");
        printf("%s,%lu,%.3f,%.3f,%.3f\n", asset.UTF8String, size,
            processFirst, median(fresh), median(repeated));

        // Conversion instrumentation is installed after timing. The two bitmap
        // interpositions above remain installed but counters are disabled then.
        Method conversion = class_getInstanceMethod(CIContext.class,
            @selector(createCGImage:fromRect:format:colorSpace:));
        if(conversion == NULL) return 5;
        originalConversion = method_setImplementation(conversion, (IMP)countedConversion);
        Method filterDraw = class_getInstanceMethod(NSClassFromString(@"IJSVGFilterPaint"),
            NSSelectorFromString(@"drawFilterInContext:"));
        if(filterDraw == NULL) return 6;
        originalFilterDraw = method_setImplementation(filterDraw, (IMP)countedFilterDraw);
        fprintf(stderr, "asset,size,phase,bitmap_requests,requested_bitmap_bytes,snapshots,ci_cgimage_calls\n");
        IJSVG* profiled = newSVG(xml, size);
        profile(profiled, bitmap, size, asset, "fresh");
        profile(profiled, bitmap, size, asset, "repeated");
        method_setImplementation(conversion, originalConversion);
        method_setImplementation(filterDraw, originalFilterDraw);
        CGContextRelease(bitmap);
    }
    return 0;
}
#endif
