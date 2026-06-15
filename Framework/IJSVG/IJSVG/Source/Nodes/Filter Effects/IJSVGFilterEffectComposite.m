//
//  IJSVGFilterEffectComposite.m
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffectComposite.h>
#import <IJSVG/IJSVGFilterGraph.h>

@implementation IJSVGFilterEffectComposite

- (void)parseEffectAttributes:(NSDictionary<NSString*, NSString*>*)attributes
{
    NSString* op = attributes[@"operator"];
    if(op != nil) {
        NSString* lower = op.lowercaseString;
        if([lower isEqualToString:@"over"]) _compositeOperator = IJSVGFilterCompositeOperatorOver;
        else if([lower isEqualToString:@"in"]) _compositeOperator = IJSVGFilterCompositeOperatorIn;
        else if([lower isEqualToString:@"out"]) _compositeOperator = IJSVGFilterCompositeOperatorOut;
        else if([lower isEqualToString:@"atop"]) _compositeOperator = IJSVGFilterCompositeOperatorAtop;
        else if([lower isEqualToString:@"xor"]) _compositeOperator = IJSVGFilterCompositeOperatorXor;
        else if([lower isEqualToString:@"lighter"]) _compositeOperator = IJSVGFilterCompositeOperatorLighter;
        else if([lower isEqualToString:@"arithmetic"]) _compositeOperator = IJSVGFilterCompositeOperatorArithmetic;
    }
    if(attributes[@"k1"]) _k1 = [attributes[@"k1"] doubleValue];
    if(attributes[@"k2"]) _k2 = [attributes[@"k2"] doubleValue];
    if(attributes[@"k3"]) _k3 = [attributes[@"k3"] doubleValue];
    if(attributes[@"k4"]) _k4 = [attributes[@"k4"] doubleValue];
}

- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph
{
    CIImage* in1 = [graph imageForInput:self.inputName];
    CIImage* in2 = [graph imageForInput:self.inputName2];
    CIImage* output = nil;

    switch(_compositeOperator) {
        case IJSVGFilterCompositeOperatorOver:
            output = [self compositeImage:in1 over:in2 filterName:@"CISourceOverCompositing"];
            break;
        case IJSVGFilterCompositeOperatorIn:
            output = [self compositeImage:in1 over:in2 filterName:@"CISourceInCompositing"];
            break;
        case IJSVGFilterCompositeOperatorOut:
            output = [self compositeImage:in1 over:in2 filterName:@"CISourceOutCompositing"];
            break;
        case IJSVGFilterCompositeOperatorAtop:
            output = [self compositeImage:in1 over:in2 filterName:@"CISourceAtopCompositing"];
            break;
        case IJSVGFilterCompositeOperatorXor: {
            CIImage* aOutB = [self compositeImage:in1 over:in2 filterName:@"CISourceOutCompositing"];
            CIImage* bOutA = [self compositeImage:in2 over:in1 filterName:@"CISourceOutCompositing"];
            output = [self compositeImage:aOutB over:bOutA filterName:@"CIAdditionCompositing"];
            break;
        }
        case IJSVGFilterCompositeOperatorLighter:
            output = [self compositeImage:in1 over:in2 filterName:@"CIAdditionCompositing"];
            break;
        case IJSVGFilterCompositeOperatorArithmetic:
            output = [self arithmeticComposite:in1 with:in2];
            break;
    }
    if(output == nil) output = in1;
    [graph setImage:output forResult:self.resultName];
    return output;
}

- (CIImage*)arithmeticComposite:(CIImage*)in1 with:(CIImage*)in2
{
    // SVG arithmetic: result = k1*in1*in2 + k2*in1 + k3*in2 + k4
    // Use CIColorMatrix on each input to scale, then combine.
    // For the general case, we render to bitmaps and compute per-pixel.

    CGRect extent = CGRectUnion(in1.extent, in2.extent);
    if (CGRectIsInfinite(extent) || CGRectIsEmpty(extent)) return in1;

    NSInteger w = (NSInteger)CGRectGetWidth(extent);
    NSInteger h = (NSInteger)CGRectGetHeight(extent);
    if (w <= 0 || h <= 0) return in1;

    NSInteger bytesPerRow = w * 4;
    uint8_t* pix1 = (uint8_t*)calloc(bytesPerRow * h, 1);
    uint8_t* pix2 = (uint8_t*)calloc(bytesPerRow * h, 1);
    uint8_t* outPix = (uint8_t*)calloc(bytesPerRow * h, 1);

    CIContext* ctx = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceLinearSRGB);
    [ctx render:in1 toBitmap:pix1 rowBytes:bytesPerRow bounds:extent
         format:kCIFormatRGBA8 colorSpace:cs];
    [ctx render:in2 toBitmap:pix2 rowBytes:bytesPerRow bounds:extent
         format:kCIFormatRGBA8 colorSpace:cs];

    CGFloat k1 = _k1, k2 = _k2, k3 = _k3, k4 = _k4;
    NSInteger numPixels = w * h;
    for (NSInteger p = 0; p < numPixels; p++) {
        NSInteger i = p * 4;
        for (NSInteger c = 0; c < 4; c++) {
            CGFloat a = pix1[i + c] / 255.0;
            CGFloat b = pix2[i + c] / 255.0;
            CGFloat result = k1 * a * b + k2 * a + k3 * b + k4;
            result = fmax(0.0, fmin(1.0, result));
            outPix[i + c] = (uint8_t)(result * 255.0 + 0.5);
        }
    }

    free(pix1);
    free(pix2);

    NSData* data = [NSData dataWithBytesNoCopy:outPix length:bytesPerRow * h freeWhenDone:YES];
    CIImage* output = [CIImage imageWithBitmapData:data bytesPerRow:bytesPerRow
                                              size:CGSizeMake(w, h)
                                            format:kCIFormatRGBA8 colorSpace:cs];
    CGColorSpaceRelease(cs);

    if (extent.origin.x != 0 || extent.origin.y != 0) {
        output = [output imageByApplyingTransform:
                  CGAffineTransformMakeTranslation(extent.origin.x, extent.origin.y)];
    }
    return output;
}

- (CIImage*)compositeImage:(CIImage*)foreground over:(CIImage*)background filterName:(NSString*)filterName
{
    CIFilter* filter = [CIFilter filterWithName:filterName];
    [filter setDefaults];
    [filter setValue:foreground forKey:kCIInputImageKey];
    [filter setValue:background forKey:kCIInputBackgroundImageKey];
    return [filter valueForKey:kCIOutputImageKey];
}

@end
