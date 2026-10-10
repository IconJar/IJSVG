#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <IJSVG/IJSVG.h>

static double Median(double* values, NSUInteger count)
{
    for(NSUInteger i = 1; i < count; i++) {
        double value = values[i];
        NSUInteger j = i;
        while(j > 0 && values[j - 1] > value) {
            values[j] = values[j - 1];
            j--;
        }
        values[j] = value;
    }
    return values[count / 2];
}

static IJSVG* Parse(NSString* xml, NSUInteger size)
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml];
    if(svg == nil) abort();
    svg.rootNode.clientSize = CGSizeMake(size, size);
    svg.renderingBackingScaleHelper = ^CGFloat { return 1; };
    return svg;
}

int main(int argc, const char** argv)
{
    @autoreleasepool {
        if(argc < 3) return 2;
        NSData* data = [NSData dataWithContentsOfFile:@(argv[1])];
        NSArray* cases = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSUInteger size = strtoul(argv[2], NULL, 10);
        if(cases == nil || size == 0 || size > 2048) return 3;
        NSString* match = argc > 3 ? @(argv[3]) : nil;
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef context = CGBitmapContextCreate(NULL, size, size, 8, size * 4, space,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space);
        if(context == NULL) return 4;
        CGContextTranslateCTM(context, 0, size);
        CGContextScaleCTM(context, 1, -1);
        CGRect rect = CGRectMake(0, 0, size, size);
        puts("case,size,bytes,parse_ms,first_draw_ms,warm_draw_ms,invalidated_draw_ms,svg_export_ms,png_encode_ms,image_ms,pdf_ms,pixel_hash");
        for(NSDictionary* fixture in cases) {
            @autoreleasepool {
                NSString* name = fixture[@"id"];
                if(match != nil && ![name containsString:match]) continue;
                NSString* xml = fixture[@"svg"];
                double times[8][5] = { 0 };
                IJSVG* warm = Parse(xml, size);
                [warm drawInRect:rect context:context];
                for(NSUInteger round = 0; round < 6; round++) {
                    @autoreleasepool {
                        double start = CACurrentMediaTime();
                        IJSVG* fresh = Parse(xml, size);
                        double parsed = CACurrentMediaTime() - start;
                        CGContextClearRect(context, rect);
                        start = CACurrentMediaTime();
                        [fresh drawInRect:rect context:context];
                        double first = CACurrentMediaTime() - start;
                        CGContextClearRect(context, rect);
                        start = CACurrentMediaTime();
                        [warm drawInRect:rect context:context];
                        double redraw = CACurrentMediaTime() - start;
                        [fresh setNeedsDisplay];
                        CGContextClearRect(context, rect);
                        start = CACurrentMediaTime();
                        [fresh drawInRect:rect context:context];
                        double invalidated = CACurrentMediaTime() - start;
                        start = CACurrentMediaTime();
                        NSString* exported = [fresh SVGStringWithSize:rect.size options:IJSVGExporterOptionNone];
                        double vector = CACurrentMediaTime() - start;
                        if(exported.length == 0) abort();
                        CGImageRef image = CGBitmapContextCreateImage(context);
                        start = CACurrentMediaTime();
                        NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
                        NSData* png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                        double encoded = CACurrentMediaTime() - start;
                        CGImageRelease(image);
                        if(png.length == 0) abort();
                        start = CACurrentMediaTime();
                        CGImageRef rendered = [fresh newCGImageRefWithSize:rect.size flipped:YES error:nil];
                        double imageTime = CACurrentMediaTime() - start;
                        if(rendered == NULL) abort();
                        CGImageRelease(rendered);
                        start = CACurrentMediaTime();
                        NSData* pdf = [fresh PDFDataWithRect:rect];
                        double pdfTime = CACurrentMediaTime() - start;
                        if(pdf.length == 0) abort();
                        if(round > 0) {
                            double row[] = { parsed, first, redraw, invalidated, vector, encoded, imageTime, pdfTime };
                            for(NSUInteger stage = 0; stage < 8; stage++) times[stage][round - 1] = row[stage] * 1000;
                        }
                    }
                }
                const unsigned char* pixels = CGBitmapContextGetData(context);
                uint64_t hash = 14695981039346656037ULL;
                for(NSUInteger byte = 0; byte < size * size * 4; byte++) hash = (hash ^ pixels[byte]) * 1099511628211ULL;
                printf("%s,%lu,%lu", name.UTF8String, (unsigned long)size, (unsigned long)[xml lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
                for(NSUInteger stage = 0; stage < 8; stage++) printf(",%.6f", Median(times[stage], 5));
                printf(",%016llx\n", (unsigned long long)hash);
                fflush(stdout);
            }
        }
        CGContextRelease(context);
    }
    return 0;
}
