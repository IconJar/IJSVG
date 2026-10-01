#import <IJSVG/IJSVG.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
static IMP original;
static IMP originalJob;
static IMP originalBatch;
static BOOL disableBatch;
static BOOL serialHook(id self, SEL selector, NSSet* paints, CGContextRef context, id block) { return NO; }
static NSUInteger batchedJobs, batchSubmissions;
static id jobHook(id self, SEL selector, CGContextRef bitmap) {
    return disableBatch ? nil : ((id(*)(id,SEL,CGContextRef))originalJob)(self,selector,bitmap);
}
static BOOL batchHook(id self, SEL selector, NSArray* jobs) {
    if(jobs.count > 1) { batchedJobs += jobs.count; batchSubmissions++; }
    return ((BOOL(*)(id,SEL,NSArray*))originalBatch)(self,selector,jobs);
}
static NSMutableDictionary* sizes;
static CGImageRef record(id self, SEL selector, CGContextRef bitmap) {
    NSString* key=[NSString stringWithFormat:@"%lux%lu",CGBitmapContextGetWidth(bitmap),CGBitmapContextGetHeight(bitmap)];
    sizes[key]=@([sizes[key] integerValue]+1);
    return ((CGImageRef(*)(id,SEL,CGContextRef))original)(self,selector,bitmap);
}
int main(int argc,char** argv) { @autoreleasepool {
    if(argc<4) return 1;
    NSString* xml=[NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:NULL];
    if(!xml) return 2;
    sizes=[[NSMutableDictionary alloc] init];
    if([@(argv[3]) hasPrefix:@"serial"]) {
        Method method = class_getClassMethod(NSClassFromString(@"IJSVGFilterPaint"), NSSelectorFromString(@"renderBatchedPaints:inContext:drawingBlock:"));
        if(method) method_setImplementation(method, (IMP)serialHook);
    }
    disableBatch=[@(argv[3]) hasPrefix:@"control"];
    Method jm=class_getInstanceMethod(NSClassFromString(@"IJSVGFilterGraph"),NSSelectorFromString(@"metalBlurJobForBitmap:"));
    if(jm) originalJob=method_setImplementation(jm,(IMP)jobHook);
    Method bm=class_getClassMethod(NSClassFromString(@"IJSVGMetalBlurRenderer"),NSSelectorFromString(@"renderJobs:"));
    if(bm) originalBatch=method_setImplementation(bm,(IMP)batchHook);
    SEL selector=NSSelectorFromString(@"newCGImageForSmallBlur:");
    Class graph=NSClassFromString(@"IJSVGFilterGraph");
    Method method=class_getInstanceMethod(graph,selector);
    if(method) original=method_setImplementation(method,(IMP)record);
    for(NSNumber* size in @[@512,@900,@1800]) {
        NSMutableArray* times=[[NSMutableArray alloc] init];
        NSUInteger w=size.unsignedIntegerValue,h=w*2/3;
        for(int i=-2;i<12;i++) { @autoreleasepool {
            NSError* error=nil;
            IJSVG* svg=[[IJSVG alloc] initWithSVGString:xml error:&error];
            if(!svg) {NSLog(@"%@",error); return 3;}
            svg.renderingBackingScaleHelper=^CGFloat {return 1;};
            CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            CGContextRef bitmap=CGBitmapContextCreate(NULL,w,h,8,w*4,space,(CGBitmapInfo)kCGImageAlphaPremultipliedLast);
            CGColorSpaceRelease(space);
            double start=CACurrentMediaTime();
            [svg drawInRect:CGRectMake(0,0,w,h) context:bitmap];
            double elapsed=(CACurrentMediaTime()-start)*1000;
            if(i>=0) [times addObject:@(elapsed)];
            if(i==0) {
                NSData* data=[NSData dataWithBytes:CGBitmapContextGetData(bitmap) length:w*h*4];
                [data writeToFile:[NSString stringWithFormat:@"%s/%s-%lu.rgba",argv[2],argv[3],w] atomically:YES];
                CGImageRef image=CGBitmapContextCreateImage(bitmap);
                NSBitmapImageRep* rep=[[NSBitmapImageRep alloc] initWithCGImage:image];
                [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[NSString stringWithFormat:@"%s/%s-%lu.png",argv[2],argv[3],w] atomically:YES];
                CGImageRelease(image);
            }
            CGContextRelease(bitmap);
        }}
        NSArray* sorted=[times sortedArrayUsingSelector:@selector(compare:)];
        printf("%s %lux%lu %.3f ms; batches=%lu jobs=%lu\n",argv[3],w,h,[sorted[sorted.count/2] doubleValue],batchSubmissions,batchedJobs);fflush(stdout);
        batchSubmissions=batchedJobs=0;
    }
    NSLog(@"Blur bitmap sizes: %@",sizes);
} return 0; }
