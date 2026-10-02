//
//  IJSVGCompositeFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGCompositeFilterEffect.h>
#import <IJSVG/IJSVGParser.h>
#import <Accelerate/Accelerate.h>

static void IJSVGCompositePixels(const float* a, const float* b, float* dst,
                                 NSInteger w, NSInteger h, double k1, double k2,
                                 double k3, double k4)
{
    // Figma style inner shadows subtract blurred alpha from hard alpha.
    // Vectorize this common case without changing premultiplied semantics.
    if(k1 == 0 && k2 == -1 && k3 == 1 && k4 == 0) {
        vDSP_Length count = (vDSP_Length)w * h;
        float minimum = 0.f, maximum = 1.f;
        vDSP_vsub(a, 1, b, 1, dst, 1, count * 4);
        vDSP_vclip(dst, 1, &minimum, &maximum, dst, 1, count * 4);
        for(NSUInteger c = 0; c < 3; c++) {
            vDSP_vmin(dst + c, 4, dst + 3, 4, dst + c, 4, count);
        }
        return;
    }
    // Batch double precision evaluation with bounded scratch storage.
    vDSP_Length total = (vDSP_Length)w * h * 4;
    vDSP_Length capacity = MIN(total, 4096);
    NSMutableData* scratch = [NSMutableData dataWithLength:capacity * 3 * sizeof(double)];
    double* first = scratch.mutableBytes;
    double* second = first + capacity;
    double* result = second + capacity;
    double minimum = 0., maximum = 1.;
    for(vDSP_Length offset = 0; offset < total; offset += capacity) {
        vDSP_Length count = MIN(capacity, total - offset);
        vDSP_vspdp(a + offset, 1, first, 1, count);
        vDSP_vspdp(b + offset, 1, second, 1, count);
        vDSP_vsmulD(first, 1, &k1, result, 1, count);
        vDSP_vmulD(result, 1, second, 1, result, 1, count);
        vDSP_vsmaD(first, 1, &k2, result, 1, result, 1, count);
        vDSP_vsmaD(second, 1, &k3, result, 1, result, 1, count);
        vDSP_vsaddD(result, 1, &k4, result, 1, count);
        for(vDSP_Length i = 0; i < count; i++) {
            if(!isfinite(result[i])) {
                result[i] = 0.;
            }
        }
        vDSP_vclipD(result, 1, &minimum, &maximum, result, 1, count);
        vDSP_vdpsp(result, 1, dst + offset, 1, count);
    }
    for(NSUInteger c = 0; c < 3; c++) {
        vDSP_vmin(dst + c, 4, dst + 3, 4, dst + c, 4, (vDSP_Length)w * h);
    }
}

static CIImage* IJSVGCompositeXor(CIImage* input, CIImage* other, IJSVGFilterContext* context)
{
    CIImage* first = [context imageInPrimitiveColorSpace:input];
    CIImage* second = [context imageInPrimitiveColorSpace:other];
    CIImage* firstOnly = [first imageByApplyingFilter:@"CISourceOutCompositing"
                                  withInputParameters:@{
        kCIInputBackgroundImageKey: second
    }];
    CIImage* secondOnly = [second imageByApplyingFilter:@"CISourceOutCompositing"
                                    withInputParameters:@{
        kCIInputBackgroundImageKey: first
    }];
    return [context imageFromPrimitiveColorSpace:[firstOnly imageByApplyingFilter:@"CIAdditionCompositing"
                                                              withInputParameters:@{
        kCIInputBackgroundImageKey: secondOnly
    }]];
}

static CIColorKernel* IJSVGCompositeArithmeticKernel(void)
{
    static CIColorKernel* arithmeticKernel;
    static dispatch_once_t kernelToken;
    dispatch_once(&kernelToken, ^{
        NSString* source = IJSVGFilterShaderSource(@"IJSVGSubtract");
        if(source == nil) {
            return;
        }
        CIKernel* kernel = [CIKernel kernelsWithMetalString:source
                                                      error:NULL].firstObject;
        if([kernel isKindOfClass:CIColorKernel.class]) {
            arithmeticKernel = (CIColorKernel*)kernel;
        }
    });
    return arithmeticKernel;
}

static CIImage* IJSVGCompositeArithmetic(IJSVGFilterPrimitive* primitive, CIImage* input,
    CIImage* other, IJSVGFilterContext* context)
{
    double k1 = [primitive numberForParameter:IJSVGAttributeK1
                                 defaultValue:0];
    double k2 = [primitive numberForParameter:IJSVGAttributeK2
                                 defaultValue:0];
    double k3 = [primitive numberForParameter:IJSVGAttributeK3
                                 defaultValue:0];
    double k4 = [primitive numberForParameter:IJSVGAttributeK4
                                 defaultValue:0];
    // Keep ordinary arithmetic in the lazy graph instead of reading float
    // bitmaps back. Large/nonfinite coefficients retain double precision CPU
    // evaluation; sample_t uses the same premultiplied channels as that path.
    BOOL boundedCoefficients = fabs(k1) <= 16 && fabs(k2) <= 16 && fabs(k3) <= 16
        && fabs(k4) <= 16;
    if(context.supportsMetalKernels && boundedCoefficients) {
        CIColorKernel* arithmeticKernel = IJSVGCompositeArithmeticKernel();
        if(arithmeticKernel != nil) {
            CIImage* result = [arithmeticKernel applyWithExtent:context.extent
                                                      arguments:@[
                [context imageInPrimitiveColorSpace:input],
                [context imageInPrimitiveColorSpace:other],
                [CIVector vectorWithX:k1 Y:k2 Z:k3 W:k4]
            ]];
            if(result != nil) {
                return [context imageFromPrimitiveColorSpace:result];
            }
        }
        // Retain the CPU evaluator if Metal kernel creation is unavailable.
    }
    // Nonnegative weighted sums are exactly expressible with opacity scaling
    // and addition; keep signed/product arithmetic on the general path.
    if(k1 == 0 && k4 == 0 && k2 >= 0 && k3 >= 0 && k2 + k3 <= 1) {
        CIImage* first = [[context imageInPrimitiveColorSpace:input]
            imageByApplyingFilter:@"CIColorMatrix"
              withInputParameters:@{
            @"inputAVector": [CIVector vectorWithX:0 Y:0 Z:0 W:k2]
        }];
        CIImage* second = [[context imageInPrimitiveColorSpace:other]
            imageByApplyingFilter:@"CIColorMatrix"
              withInputParameters:@{
            @"inputAVector": [CIVector vectorWithX:0 Y:0 Z:0 W:k3]
        }];
        return [context imageFromPrimitiveColorSpace:[first imageByApplyingFilter:@"CIAdditionCompositing"
                                                              withInputParameters:@{
                kCIInputBackgroundImageKey: second
            }]];
    }
    return [context mapImage:input
                       other:other
                   operation:^(const float* a, const float* b, float* dst, NSInteger w, NSInteger h) {
      IJSVGFilterApplyRows(w, h, ^(NSInteger firstRow, NSInteger lastRow) {
          NSInteger offset = firstRow * w * 4;
          IJSVGCompositePixels(a + offset, b + offset, dst + offset, w, lastRow - firstRow, k1, k2, k3, k4);
      });
    }];
}

@implementation IJSVGCompositeFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;
    CIImage* other = inputs.count > 1 ? inputs[1] : CIImage.emptyImage;
    NSString* op = primitive.parameters[IJSVGAttributeOperator] ?: IJSVGStringOver;
    static NSDictionary<NSString*, NSString*>* filters;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        filters = @{
            IJSVGStringOver: @"CISourceOverCompositing",
            IJSVGStringIn: @"CISourceInCompositing",
            IJSVGStringOut: @"CISourceOutCompositing",
            IJSVGStringAtop: @"CISourceAtopCompositing",
            IJSVGStringLighter: @"CIAdditionCompositing"
        };
    });
    if([op isEqualToString:IJSVGStringXor]) {
        return IJSVGCompositeXor(input, other, context);
    }
    if(filters[op] != nil) {
        return [context applyFilter:filters[op]
                            toImage:input
                         parameters:@{
            kCIInputBackgroundImageKey: [context imageInPrimitiveColorSpace:other]
        }];
    }
    if([op isEqualToString:IJSVGStringArithmetic] == NO) {
        return [context applyFilter:@"CISourceOverCompositing"
                            toImage:input
                         parameters:@{
            kCIInputBackgroundImageKey: [context imageInPrimitiveColorSpace:other]
        }];
    }
    return IJSVGCompositeArithmetic(primitive, input, other, context);
}

@end
