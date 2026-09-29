//
//  IJSVGConvolveMatrixFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGConvolveMatrixFilterEffect.h>
#import <IJSVG/IJSVGParser.h>
#import <Accelerate/Accelerate.h>

typedef struct {
    NSInteger kernelWidth;
    NSInteger kernelHeight;
    double targetX;
    double targetY;
    double divisor;
    double bias;
    BOOL preserveAlpha;
    NSInteger edgeMode;
    CGSize step;
    CGRect inputRegion;
} IJSVGConvolutionParameters;

@implementation IJSVGConvolveMatrixFilterEffect

- (void)convolvePixels:(const float*)src
                output:(float*)dst
                 width:(NSInteger)w
                height:(NSInteger)h
                kernel:(NSData*)kernel
            parameters:(IJSVGConvolutionParameters)parameters
{
    const double* k = kernel.bytes;
    IJSVGFilterSampler sampler = IJSVGFilterSamplerMake(src, w, h, parameters.inputRegion, parameters.edgeMode);
    if(parameters.step.width == 1 && parameters.step.height == 1) {
        // Padding explicitly applies SVG edge modes and noncentral targets.
        // vImage requires odd kernels; an extra zero tap handles even orders.
        NSInteger kw = parameters.kernelWidth | 1, kh = parameters.kernelHeight | 1;
        NSInteger pw = w + kw - 1, ph = h + kh - 1;
        NSMutableData* taps = [NSMutableData dataWithLength:kw * kh * sizeof(float)];
        float* coefficients = taps.mutableBytes;
        BOOL representable = YES;
        for(NSInteger j = 0; j < parameters.kernelHeight; j++) {
            for(NSInteger i = 0; i < parameters.kernelWidth; i++) {
                double value = k[(parameters.kernelHeight - j - 1) * parameters.kernelWidth + parameters.kernelWidth - i - 1] / parameters.divisor;
                coefficients[j * kw + i] = value;
                representable &= isfinite(coefficients[j * kw + i]);
            }
        }
        if(representable) {
            NSMutableData* padded = [NSMutableData dataWithLength:pw * ph * 4 * sizeof(float)];
            float* pixels = padded.mutableBytes;
            IJSVGFilterApplyRows(pw, ph, ^(NSInteger firstRow, NSInteger lastRow) {
                for(NSInteger y = firstRow; y < lastRow; y++) {
                    for(NSInteger x = 0; x < pw; x++) {
                        CGFloat px = x - parameters.targetX, py = y - parameters.targetY;
                        float sample[4];
                        IJSVGFilterSamplerPixel(&sampler, px, py, sample);
                        float alpha = sample[3];
                        for(NSUInteger c = 0; c < 4; c++) {
                            float value = sample[c];
                            pixels[(y * pw + x) * 4 + c] = parameters.preserveAlpha && c < 3
                                ? (alpha > 0 ? value / alpha : 0) : value;
                        }
                    }
                }
            });
            vImage_Buffer source = { pixels, ph, pw, pw * 4 * sizeof(float) };
            vImage_Buffer destination = { dst, h, w, w * 4 * sizeof(float) };
            float background[4] = { 0 };
            vImage_Error error = vImageConvolve_ARGBFFFF(&source, &destination, NULL,
                kw / 2, kh / 2, coefficients, (uint32_t)kh, (uint32_t)kw,
                background, kvImageBackgroundColorFill);
            if(error == kvImageNoError) {
                IJSVGFilterApplyRows(w, h, ^(NSInteger firstRow, NSInteger lastRow) {
                    for(NSInteger i = firstRow * w; i < lastRow * w; i++) {
                        float alpha = parameters.preserveAlpha ? src[i * 4 + 3]
                            : IJSVGFilterClamp(dst[i * 4 + 3] + parameters.bias);
                        dst[i * 4 + 3] = alpha;
                        for(NSUInteger c = 0; c < 3; c++) {
                            dst[i * 4 + c] = parameters.preserveAlpha
                                ? IJSVGFilterClamp(dst[i * 4 + c] + parameters.bias) * alpha
                                : MIN(alpha, IJSVGFilterClamp(dst[i * 4 + c] + parameters.bias * alpha));
                        }
                    }
                });
                return;
            }
        }
    }
    // Fractional sampling and unrepresentable float kernels retain the general evaluator.
    IJSVGFilterApplyRows(w, h, ^(NSInteger firstRow, NSInteger lastRow) {
        for(NSInteger y = firstRow; y < lastRow; y++) {
            for(NSInteger x = 0; x < w; x++) {
                NSInteger index = (y * w + x) * 4;
                double result[4] = { 0, 0, 0, 0 };
                for(NSInteger j = 0; j < parameters.kernelHeight; j++) {
                    for(NSInteger i = 0; i < parameters.kernelWidth; i++) {
                        double px = x + (i - parameters.targetX) * parameters.step.width, py = y + (j - parameters.targetY) * parameters.step.height;
                        float sample[4];
                        IJSVGFilterSamplerPixel(&sampler, px, py, sample);
                        double alpha = sample[3];
                        for(NSUInteger c = 0; c < (parameters.preserveAlpha ? 3 : 4); c++) {
                            double value = sample[c];
                            if(parameters.preserveAlpha) {
                                value = alpha > 0 ? value / alpha : 0;
                            }
                            result[c] += value * k[(parameters.kernelHeight - j - 1) * parameters.kernelWidth + parameters.kernelWidth - i - 1];
                        }
                    }
                }
                double alpha = parameters.preserveAlpha ? src[index + 3] : IJSVGFilterClamp(result[3] / parameters.divisor + parameters.bias);
                dst[index + 3] = alpha;
                for(NSUInteger c = 0; c < 3; c++) {
                    dst[index + c] = parameters.preserveAlpha
                        ? IJSVGFilterClamp(result[c] / parameters.divisor + parameters.bias) * alpha
                        : MIN(alpha, IJSVGFilterClamp(result[c] / parameters.divisor + parameters.bias * alpha));
                }
            }
        }
    });
}

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;
    CGSize order = [primitive pairForParameter:IJSVGAttributeOrder
                                  defaultValue:CGSizeMake(3, 3)];
    NSArray<NSNumber*>* coefficients = [primitive numbersForParameter:IJSVGAttributeKernelMatrix];
    if(order.width < 1 || order.height < 1 || order.width > 256 || order.height > 256
        || floor(order.width) != order.width || floor(order.height) != order.height
        || coefficients.count != (NSUInteger)(order.width * order.height)) {
        return CIImage.emptyImage;
    }
    NSInteger ox = order.width, oy = order.height;
    double tx = [primitive numberForParameter:IJSVGAttributeTargetX
                                 defaultValue:floor(ox / 2.)];
    double ty = [primitive numberForParameter:IJSVGAttributeTargetY
                                 defaultValue:floor(oy / 2.)];
    if(tx < 0 || tx >= ox || ty < 0 || ty >= oy || tx != floor(tx) || ty != floor(ty)) {
        return CIImage.emptyImage;
    }
    NSMutableData* kernel = [NSMutableData dataWithLength:coefficients.count * sizeof(double)];
    double *weights = kernel.mutableBytes, sum = 0;
    for(NSUInteger i = 0; i < coefficients.count; i++) {
        weights[i] = coefficients[i].doubleValue;
        sum += weights[i];
    }
    double divisor = [primitive numberForParameter:IJSVGAttributeDivisor
                                      defaultValue:sum == 0 ? 1 : sum];
    if(divisor == 0) {
        return CIImage.emptyImage;
    }
    double bias = [primitive numberForParameter:IJSVGAttributeBias
                                   defaultValue:0];
    BOOL preserveAlpha = [primitive.parameters[IJSVGAttributePreserveAlpha] isEqualToString:IJSVGStringTrue];
    NSString* edge = primitive.parameters[IJSVGAttributeEdgeMode] ?: IJSVGStringDuplicate;
    NSInteger edgeMode = [edge isEqualToString:IJSVGStringDuplicate] ? 1 : ([edge isEqualToString:IJSVGStringWrap] ? 2 : 0);
    CGSize step = [primitive pairForParameter:IJSVGAttributeKernelUnitLength
                                 defaultValue:CGSizeZero];
    if(primitive.parameters[IJSVGAttributeKernelUnitLength] != nil && (step.width <= 0 || step.height <= 0)) {
        return CIImage.emptyImage;
    }
    CGSize units = context.pixelUnits;
    step = CGSizeEqualToSize(step, CGSizeZero) ? CGSizeMake(1, 1)
                                               : CGSizeMake(step.width * units.width, step.height * units.height);
    // Built in convolution filters evaluate premultiplied RGBA. SVG
    // preserveAlpha and nonzero bias have different equations, so those cases
    // use the general evaluator below.
    if(!preserveAlpha && bias == 0 && step.width == 1 && step.height == 1) {
        NSInteger cw = 0, ch = 0;
        NSString* filterName = nil;
        if(oy == 1 && ox <= 9) {
            cw = 9;
            ch = 1;
            filterName = @"CIConvolution9Horizontal";
        } else if(ox == 1 && oy <= 9) {
            cw = 1;
            ch = 9;
            filterName = @"CIConvolution9Vertical";
        } else if(MAX(ox, oy) <= 7) {
            cw = ch = MAX(ox, oy) <= 3 ? 3 : (MAX(ox, oy) <= 5 ? 5 : 7);
            filterName = [NSString stringWithFormat:@"CIConvolution%ldX%ld", (long)cw, (long)ch];
        }
        if(filterName != nil) {
            CGFloat ciWeights[49] = { 0 };
            // CI lists rows from high to low y; SVG reverses the kernel in both
            // axes. The translation below preserves noncentral SVG targets.
            for(NSInteger y = 0; y < oy; y++) {
                for(NSInteger x = 0; x < ox; x++) {
                    ciWeights[(ch - y - 1) * cw + x] = weights[(oy - y - 1) * ox + ox - x - 1] / divisor;
                }
            }
            CIImage* source = [context imageInPrimitiveColorSpace:input];
            if(edgeMode == 1) {
                source = [source imageByClampingToExtent];
            }
            if(edgeMode == 2) {
                source = [source imageByApplyingFilter:@"CIAffineTile"
                                   withInputParameters:@{
                    kCIInputTransformKey: [NSAffineTransform transform]
                }];
            }
            CIImage* output = [source imageByApplyingFilter:filterName
                                        withInputParameters:@{
                @"inputWeights": [CIVector vectorWithValues:ciWeights count:cw * ch],
                @"inputBias": @0
            }];
            output = [output imageByApplyingTransform:CGAffineTransformMakeTranslation(tx - cw / 2, ty - ch / 2)];
            return [context imageFromPrimitiveColorSpace:output];
        }
    }
    CGRect inputRegion = input.extent;
    IJSVGConvolutionParameters parameters = {
        .kernelWidth = ox,
        .kernelHeight = oy,
        .targetX = tx,
        .targetY = ty,
        .divisor = divisor,
        .bias = bias,
        .preserveAlpha = preserveAlpha,
        .edgeMode = edgeMode,
        .step = step,
        .inputRegion = inputRegion,
    };
    return [context mapImage:input
                       other:nil
                   operation:^(const float* src, const float* unused, float* dst, NSInteger w, NSInteger h) {
      [self convolvePixels:src
                    output:dst
                     width:w
                    height:h
                    kernel:kernel
                parameters:parameters];
    }];
}

@end
