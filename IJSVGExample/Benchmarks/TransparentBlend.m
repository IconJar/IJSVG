// Alternating reference/optimized renders; fails above 2/255 channel error.
// The eligibility hook is confined to this standalone single threaded benchmark.
#import <IJSVG/IJSVG.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
static IMP originalEligibility;
static BOOL referenceMode;
static NSUInteger elidedBlends;
static BOOL eligibilityHook(id graph, SEL selector, NSUInteger index, NSArray* primitives) {
    if(referenceMode) return NO;
    BOOL eligible = ((BOOL(*)(id,SEL,NSUInteger,NSArray*))originalEligibility)(graph,selector,index,primitives);
    if(eligible) elidedBlends++;
    return eligible;
}

int main(int argc, char** argv) { @autoreleasepool {
    if(argc < 2 || MTLCreateSystemDefaultDevice() == nil) return 1;
    NSArray* fixtures = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[1])] options:0 error:NULL];
    if(fixtures == nil) return 2;
    Method method = class_getInstanceMethod(NSClassFromString(@"IJSVGFilterGraph"), NSSelectorFromString(@"canElideTransparentBlendAtIndex:primitives:"));
    if(method == NULL) return 7;
    originalEligibility = method_setImplementation(method, (IMP)eligibilityHook);
    puts("name,size,reference_ms,optimized_ms,max_difference,elided_blends");
    for(NSDictionary* fixture in fixtures) {
        if([fixture[@"tier"] isEqual:@"simple"]) continue;
        for(NSNumber* size in (argc > 2 ? @[@32, @64, @128, @256] : @[@32, @64, @128, @256, @512, @1024])) { @autoreleasepool {
            NSUInteger width = size.unsignedIntegerValue;
            NSMutableArray* times[2] = {[[NSMutableArray alloc] init], [[NSMutableArray alloc] init]};
            NSData* pixels[2] = {nil, nil};
            elidedBlends = 0;
            for(int iteration = -3; iteration < 21; iteration++) for(int order = 0; order < 2; order++) { @autoreleasepool {
                int variant = (iteration + 3 + order) % 2;
                referenceMode = variant == 0;
                NSError* error = nil;
                IJSVG* svg = [[IJSVG alloc] initWithSVGString:fixture[@"document"] error:&error];
                if(svg == nil) { NSLog(@"%@",error); return 3; }
                svg.renderingBackingScaleHelper = ^CGFloat { return 1; };
                CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
                CGContextRef bitmap = CGBitmapContextCreate(NULL, width, width, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
                CGColorSpaceRelease(space);
                if(bitmap == NULL) return 4;
                double start = CACurrentMediaTime();
                [svg drawInRect:CGRectMake(0,0,width,width) context:bitmap];
                if(iteration >= 0) [times[variant] addObject:@((CACurrentMediaTime()-start)*1000)];
                if(iteration == 0) pixels[variant] = [NSData dataWithBytes:CGBitmapContextGetData(bitmap) length:width*width*4];
                CGContextRelease(bitmap);
            }}
            if(pixels[0].length != pixels[1].length) return 5;
            int difference = 0;
            const uint8_t* a = pixels[0].bytes; const uint8_t* b = pixels[1].bytes;
            for(NSUInteger i=0;i<pixels[0].length;i++) difference=MAX(difference,abs((int)a[i]-b[i]));
            printf("%s,%lu,%.3f,%.3f,%d,%lu\n",[fixture[@"name"] UTF8String],width,
                [[times[0] sortedArrayUsingSelector:@selector(compare:)][10] doubleValue],
                [[times[1] sortedArrayUsingSelector:@selector(compare:)][10] doubleValue],difference,elidedBlends);
            fflush(stdout);
            if(difference>2) return 6;
        }}
    }
    method_setImplementation(method, originalEligibility);
} return 0; }
