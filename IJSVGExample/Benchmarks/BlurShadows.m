#import <IJSVG/IJSVG.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
static IMP originalDraw;
static NSMutableDictionary* profiles;
static void profileDraw(id layer, SEL selector, CGContextRef context) {
    double start = CACurrentMediaTime();
    ((void(*)(id,SEL,CGContextRef))originalDraw)(layer,selector,context);
    id filter = [layer valueForKey:@"filter"];
    NSString* key = [filter valueForKey:@"identifier"] ?: @"unnamed";
    profiles[key] = @([profiles[key] doubleValue] + (CACurrentMediaTime()-start)*1000);
}

int main(int argc, char** argv) { @autoreleasepool {
    if(argc != 4 || MTLCreateSystemDefaultDevice() == nil) return 1;
    NSArray* fixtures = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[1])] options:0 error:NULL];
    if(fixtures == nil) return 2;
    [[NSFileManager defaultManager] createDirectoryAtPath:@(argv[2]) withIntermediateDirectories:YES attributes:nil error:NULL];
    if(getenv("IJSVG_PROFILE_CHAINS")) {
        profiles = [[NSMutableDictionary alloc] init];
        Method method = class_getInstanceMethod(NSClassFromString(@"IJSVGFilterPaint"), NSSelectorFromString(@"drawFilterInContext:"));
        originalDraw = method_setImplementation(method, (IMP)profileDraw);
    }
    puts("name,size,median_ms,max_difference");
    for(NSDictionary* fixture in fixtures) {
        
        for(NSNumber* size in (fixture[@"sizes"] ?: @[@64, @256])) { @autoreleasepool {
            NSUInteger width = size.unsignedIntegerValue;
            NSUInteger height = MAX(1, lround(width * (fixture[@"aspect"] ? [fixture[@"aspect"] doubleValue] : 1)));
            NSMutableArray* times = [[NSMutableArray alloc] init];
            NSData* pixels = nil;
            for(int iteration = -2; iteration < 9; iteration++) { @autoreleasepool {
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
                if(iteration >= 0) [times addObject:@((CACurrentMediaTime()-start)*1000)];
                if(iteration == 0) pixels = [NSData dataWithBytes:CGBitmapContextGetData(bitmap) length:width*height*4];
                CGContextRelease(bitmap);
            }}
            NSString* path = [NSString stringWithFormat:@"%s/%@-%lu.rgba", argv[2], fixture[@"name"], width];
            int difference = 0;
            if(strcmp(argv[3], "record") == 0) {
                [pixels writeToFile:path atomically:YES];
            } else {
                NSData* reference = [NSData dataWithContentsOfFile:path];
                if(reference.length != pixels.length) return 5;
                const uint8_t* a = reference.bytes; const uint8_t* b = pixels.bytes;
                for(NSUInteger i=0;i<pixels.length;i++) difference=MAX(difference,abs((int)a[i]-b[i]));
            }
            printf("%s,%lu,%.3f,%d\n",[fixture[@"name"] UTF8String],width,[[times sortedArrayUsingSelector:@selector(compare:)][4] doubleValue],difference);
            fflush(stdout);
            if(difference>2) return 6;
        }}
    }
    if(profiles) NSLog(@"Inclusive filter draw totals (ms): %@", profiles);
} return 0; }
