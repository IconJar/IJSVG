// Standalone experiment built with Clang optimization and automatic reference counting.
// Links Foundation, CoreImage, CoreGraphics, Metal and QuartzCore.
#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

static double median(NSArray* samples) {
    return [[samples sortedArrayUsingSelector:@selector(compare:)][samples.count / 2] doubleValue];
}

int main(void) { @autoreleasepool {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if(device == nil) return 1;
    CIContext* context = [CIContext contextWithMTLDevice:device options:nil];
    fprintf(stderr, "%s; %s\n", device.name.UTF8String, NSProcessInfo.processInfo.operatingSystemVersionString.UTF8String);
    puts("size,radius,space,pattern,full_ms,half_ms,quarter_ms,half_max,quarter_max,half_mean,quarter_mean");
    for(NSNumber* size in @[@128, @512, @1024]) {
        NSUInteger width = size.unsignedIntegerValue, length = width * width * 4;
        for(NSNumber* radius in @[@6, @12, @24]) {
            for(NSNumber* linear in @[@NO, @YES]) {
                for(NSNumber* pattern in @[@0, @1]) { @autoreleasepool {
                    NSMutableData* source = [NSMutableData dataWithLength:length];
                    uint8_t* pixels = source.mutableBytes;
                    for(NSUInteger y = 0; y < width; y++) for(NSUInteger x = 0; x < width; x++) {
                        NSUInteger i = (y * width + x) * 4;
                        uint8_t alpha = pattern.boolValue ? ((x % 13 == 0 || y % 17 == 0) ? 255 : 5)
                            : ((x < width * .73 && y > width * .18) ? 180 : 0);
                        pixels[i] = x < width / 2 ? alpha : 0;
                        pixels[i + 1] = y < width / 2 ? alpha : 0;
                        pixels[i + 2] = alpha; pixels[i + 3] = alpha;
                    }
                    NSMutableArray* times[3] = {[[NSMutableArray alloc] init], [[NSMutableArray alloc] init], [[NSMutableArray alloc] init]};
                    NSMutableData* outputs[3] = {[NSMutableData dataWithLength:length], [NSMutableData dataWithLength:length], [NSMutableData dataWithLength:length]};
                    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
                    CGColorSpaceRef space = CGColorSpaceCreateWithName(linear.boolValue ? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
                    for(int iteration = -3; iteration < 15; iteration++) for(int order = 0; order < 3; order++) { @autoreleasepool {
                        int method = (iteration + 3 + order) % 3;
                        double start = CACurrentMediaTime();
                        NSData* fresh = [NSData dataWithBytes:source.bytes length:length];
                        CIImage* image = [CIImage imageWithBitmapData:fresh bytesPerRow:width * 4 size:CGSizeMake(width, width) format:kCIFormatRGBA8 colorSpace:srgb];
                        image = [image imageByCroppingToRect:CGRectMake(.35, .7, width - 1.2, width - 1.6)];
                        // Apply all sampling in the same primitive color space as the reference.
                        image = [image imageByColorMatchingWorkingSpaceToColorSpace:space];
                        double scale = 1.0 / (1 << method);
                        if(method) image = [image imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale) highQualityDownsample:YES];
                        image = [image imageByApplyingFilter:@"CIGaussianBlur" withInputParameters:@{kCIInputRadiusKey:@(radius.doubleValue * scale)}];
                        if(method) image = [image imageByApplyingTransform:CGAffineTransformMakeScale(1 / scale, 1 / scale)];
                        image = [image imageByColorMatchingColorSpaceToWorkingSpace:space];
                        [context render:image toBitmap:outputs[method].mutableBytes rowBytes:width * 4 bounds:CGRectMake(0, 0, width, width) format:kCIFormatRGBA8 colorSpace:srgb];
                        if(iteration >= 0) [times[method] addObject:@((CACurrentMediaTime() - start) * 1000)];
                    }}
                    CGColorSpaceRelease(space);
                    CGColorSpaceRelease(srgb);
                    double maximum[2] = {0}, mean[2] = {0};
                    const uint8_t* reference = outputs[0].bytes;
                    for(int method = 1; method < 3; method++) {
                        const uint8_t* actual = outputs[method].bytes;
                        for(NSUInteger i = 0; i < length; i++) {
                            double difference = abs((int)actual[i] - reference[i]);
                            maximum[method - 1] = MAX(maximum[method - 1], difference);
                            mean[method - 1] += difference / length;
                        }
                    }
                    printf("%lu,%g,%s,%d,%.3f,%.3f,%.3f,%.0f,%.0f,%.4f,%.4f\n", width, radius.doubleValue,
                        linear.boolValue ? "linearRGB" : "sRGB", pattern.intValue, median(times[0]), median(times[1]), median(times[2]), maximum[0], maximum[1], mean[0], mean[1]);
                    fflush(stdout);
                }}
            }
        }
    }
} return 0; }
