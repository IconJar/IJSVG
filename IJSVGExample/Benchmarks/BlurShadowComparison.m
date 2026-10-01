#import <IJSVG/IJSVG.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
static IMP originalBlur, originalShadow;
static BOOL referenceMode;
static NSUInteger gpuBlurs, gpuShadows;
static id blurHook(id effect, SEL selector, id image, id x, id y, BOOL alphaOnly, id context) {
    if(referenceMode) return nil;
    id result = ((id(*)(id,SEL,id,id,id,BOOL,id))originalBlur)(effect,selector,image,x,y,alphaOnly,context);
    if(result) gpuBlurs++;
    return result;
}
static id shadowHook(id effect, SEL selector, CGContextRef bitmap) {
    if(referenceMode) return nil;
    id result = ((id(*)(id,SEL,CGContextRef))originalShadow)(effect,selector,bitmap);
    if(result) gpuShadows++;
    return result;
}

int main(int argc, char** argv) { @autoreleasepool {
    if(argc != 2 || MTLCreateSystemDefaultDevice() == nil) return 1;
    NSArray* fixtures = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[1])] options:0 error:NULL];
    if(fixtures == nil) return 2;
    Method blur = class_getInstanceMethod(NSClassFromString(@"IJSVGGaussianBlurFilterEffect"), NSSelectorFromString(@"metalBlurImage:horizontalKernel:verticalKernel:alphaOnly:context:"));
    Method shadow = class_getInstanceMethod(NSClassFromString(@"IJSVGFilterGraph"), NSSelectorFromString(@"metalDropShadowJobForBitmap:"));
    if(!blur || !shadow) return 7;
    originalBlur = method_setImplementation(blur,(IMP)blurHook);
    originalShadow = method_setImplementation(shadow,(IMP)shadowHook);
    BOOL failed = NO;
    puts("name,size,reference_ms,optimized_ms,max_difference,gpu_blurs,gpu_shadows");
    for(NSDictionary* fixture in fixtures) {
        
        for(NSNumber* size in (fixture[@"sizes"] ?: @[@64, @256])) { @autoreleasepool {
            NSUInteger width = size.unsignedIntegerValue;
            NSUInteger height = MAX(1, lround(width * (fixture[@"aspect"] ? [fixture[@"aspect"] doubleValue] : 1)));
            NSMutableArray* times[2] = {[[NSMutableArray alloc] init], [[NSMutableArray alloc] init]};
            NSData* pixels[2] = {nil,nil};
            gpuBlurs = gpuShadows = 0;
            for(int iteration = -3; iteration < 15; iteration++) for(int order=0;order<2;order++) { @autoreleasepool {
                int variant = (iteration+3+order)%2;
                referenceMode = variant == 0;
                NSError* error = nil;
                IJSVG* svg = [[IJSVG alloc] initWithSVGString:fixture[@"document"] error:&error];
                if(svg == nil) { NSLog(@"%@",error); return 3; }
                svg.renderingBackingScaleHelper = ^CGFloat { return 1; };
                CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
                CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
                CGColorSpaceRelease(space);
                if(bitmap == NULL) return 4;
                if([fixture[@"flipped"] boolValue]) { CGContextTranslateCTM(bitmap,0,height); CGContextScaleCTM(bitmap,1,-1); }
                double start = CACurrentMediaTime();
                [svg drawInRect:CGRectMake(0,0,width,height) context:bitmap];
                if(iteration >= 0) [times[variant] addObject:@((CACurrentMediaTime()-start)*1000)];
                if(iteration == 0) pixels[variant] = [NSData dataWithBytes:CGBitmapContextGetData(bitmap) length:width*height*4];
                CGContextRelease(bitmap);
            }}
            if(pixels[0].length != pixels[1].length) return 5;
            int difference = 0;
            const uint8_t* a = pixels[0].bytes; const uint8_t* b = pixels[1].bytes;
            for(NSUInteger i=0;i<pixels[0].length;i++) difference=MAX(difference,abs((int)a[i]-b[i]));
            printf("%s,%lu,%.3f,%.3f,%d,%lu,%lu\n",[fixture[@"name"] UTF8String],width,
                [[times[0] sortedArrayUsingSelector:@selector(compare:)][7] doubleValue],
                [[times[1] sortedArrayUsingSelector:@selector(compare:)][7] doubleValue],difference,gpuBlurs,gpuShadows);
            fflush(stdout);
            if(difference>2) failed = YES;
        }}
    }
    if(failed) return 6;
    method_setImplementation(blur,originalBlur);
    method_setImplementation(shadow,originalShadow);
} return 0; }
