#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

int main(void) { @autoreleasepool {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if(device == nil) return 1;
    CIContext* context = [CIContext contextWithMTLDevice:device options:nil];
    puts("size,space,original_ms,optimized_ms,max_error");
    for(NSNumber* size in @[@128, @512, @1024]) for(NSNumber* linear in @[@NO, @YES]) { @autoreleasepool {
        NSUInteger width = size.unsignedIntegerValue, length = width * width * 4;
        NSMutableData* source = [NSMutableData dataWithLength:length];
        uint8_t* p = source.mutableBytes;
        for(NSUInteger i = 0; i < length; i += 4) {
            p[i + 3] = (i / 4) % 256;
            p[i] = p[i + 3]; p[i + 1] = p[i + 3] / 2; p[i + 2] = p[i + 3] / 3;
        }
        CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGColorSpaceRef space = CGColorSpaceCreateWithName(linear.boolValue ? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
        NSMutableData* outputs[2] = {[NSMutableData dataWithLength:length], [NSMutableData dataWithLength:length]};
        NSMutableArray* times[2] = {[[NSMutableArray alloc] init], [[NSMutableArray alloc] init]};
        for(int iteration = -4; iteration < 30; iteration++) for(int order = 0; order < 2; order++) { @autoreleasepool {
            int method = (iteration + 4 + order) % 2;
            double start = CACurrentMediaTime();
            CIImage* image = [CIImage imageWithBitmapData:[NSData dataWithBytes:source.bytes length:length] bytesPerRow:width * 4 size:CGSizeMake(width, width) format:kCIFormatRGBA8 colorSpace:srgb];
            CIImage* background = image;
            for(int stage = 0; stage < 6; stage++) {
                if(!method) image = [image imageByColorMatchingWorkingSpaceToColorSpace:space];
                image = [image imageByApplyingFilter:@"CIColorMatrix" withInputParameters:@{@"inputAVector":[CIVector vectorWithX:0 Y:0 Z:0 W:.83]}];
                image = [image imageByApplyingFilter:@"CIColorClamp" withInputParameters:@{@"inputMinComponents":[CIVector vectorWithX:0 Y:0 Z:0 W:0], @"inputMaxComponents":[CIVector vectorWithX:1 Y:1 Z:1 W:1]}];
                if(!method) image = [image imageByColorMatchingColorSpaceToWorkingSpace:space];
                image = [image imageByCroppingToRect:CGRectMake(.3, .7, width - 1, width - 1)];
            }
            image = [image imageByCompositingOverImage:background];
            [context render:image toBitmap:outputs[method].mutableBytes rowBytes:width * 4 bounds:CGRectMake(0, 0, width, width) format:kCIFormatRGBA8 colorSpace:srgb];
            if(iteration >= 0) [times[method] addObject:@((CACurrentMediaTime() - start) * 1000)];
        }}
        int maximum = 0;
        const uint8_t* a = outputs[0].bytes; const uint8_t* b = outputs[1].bytes;
        for(NSUInteger i = 0; i < length; i++) maximum = MAX(maximum, abs((int)a[i] - b[i]));
        printf("%lu,%s,%.3f,%.3f,%d\n", width, linear.boolValue ? "linearRGB" : "sRGB",
            [[times[0] sortedArrayUsingSelector:@selector(compare:)][15] doubleValue],
            [[times[1] sortedArrayUsingSelector:@selector(compare:)][15] doubleValue], maximum);
        CGColorSpaceRelease(space); CGColorSpaceRelease(srgb);
    }}
} return 0; }
