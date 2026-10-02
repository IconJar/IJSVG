//
//  IJSVGComponentTransferFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGComponentTransferFilterEffect.h>
#import <IJSVG/IJSVGParser.h>
#import <Accelerate/Accelerate.h>

typedef struct {
    NSUInteger type, offset, count;
    double slope, intercept, amplitude, exponent, bias;
} IJSVGComponentTransferFunction;

static void IJSVGApplyTransferToPixels(const float* src, float* dst, NSInteger w,
                                       NSInteger h, NSData* configuration, NSData* tables)
{
    const IJSVGComponentTransferFunction* functions = configuration.bytes;
    const double* values = tables.bytes;
    // Process small groups of pixels to keep memory use low.
    NSInteger capacity = MIN(w * h, 4096);
    NSMutableData* scratch = [NSMutableData dataWithLength:capacity * 3 * sizeof(double)];
    double* channel = scratch.mutableBytes;
    double* transformed = channel + capacity;
    double* powers = transformed + capacity;
    for(NSUInteger c = 0; c < 4; c++) {
        IJSVGComponentTransferFunction f = functions[c];
        if(f.type == 4) {
            vDSP_vfillD(&f.exponent, powers, 1, capacity);
        }
        for(NSInteger start = 0; start < w * h; start += capacity) {
            int count = (int)MIN(capacity, w * h - start);
            NSInteger offset = start * 4;
            for(NSInteger x = 0; x < count; x++) {
                NSInteger i = offset + x * 4;
                float alpha = src[i + 3];
                channel[x] = IJSVGFilterClamp(c == 3 ? alpha : (alpha > 0 ? src[i + c] / alpha : 0));
            }
            if(f.type == 4) {
                vvpow(transformed, powers, channel, &count);
                vDSP_vsmsaD(transformed, 1, &f.amplitude, &f.bias, channel, 1, count);
            } else if(f.type == 3) {
                vDSP_vsmsaD(channel, 1, &f.slope, &f.intercept, channel, 1, count);
            } else if((f.type == 1 || f.type == 2) && f.count > 0) {
                // Look up each value using the SVG table rules.
                for(NSInteger x = 0; x < count; x++) {
                    double v = channel[x];
                    if(f.type == 1) {
                        double index = v * (f.count - 1);
                        NSUInteger k = floor(index), next = MIN(k + 1, f.count - 1);
                        channel[x] = values[f.offset + k]
                            + (index - k) * (values[f.offset + next] - values[f.offset + k]);
                    } else {
                        channel[x] = values[f.offset + MIN((NSUInteger)(v * f.count), f.count - 1)];
                    }
                }
            }
            for(NSInteger x = 0; x < count; x++) {
                dst[offset + x * 4 + c] = IJSVGFilterClamp(channel[x]);
            }
        }
    }
    for(NSUInteger c = 0; c < 3; c++) {
        vDSP_vmul(dst + c, 4, dst + 3, 4, dst + c, 4, (vDSP_Length)w * h);
    }
}

// Read the settings for each color channel and store their table values.
static void IJSVGPrepareTransferFunctions(IJSVGFilterPrimitive* primitive,
                                          IJSVGComponentTransferFunction functions[4],
                                          NSMutableData* tables)
{
    NSArray* types = @[IJSVGStringIdentity, IJSVGStringTable, IJSVGStringDiscrete, IJSVGStringLinear, IJSVGStringGamma];
    for(NSUInteger c = 0; c < 4; c++) {
        IJSVGFilterPrimitive* function = nil;
        for(IJSVGFilterPrimitive* child in primitive.children) {
            if(child.type == IJSVGNodeTypeFilterFuncR + c) {
                function = child;
            }
        }
        functions[c].type = [types indexOfObject:function.parameters[IJSVGAttributeType] ?: IJSVGStringIdentity];
        functions[c].slope = [function numberForParameter:IJSVGAttributeSlope
                                             defaultValue:1];
        functions[c].intercept = [function numberForParameter:IJSVGAttributeIntercept
                                                 defaultValue:0];
        functions[c].amplitude = [function numberForParameter:IJSVGAttributeAmplitude
                                                 defaultValue:1];
        functions[c].exponent = [function numberForParameter:IJSVGAttributeExponent
                                                defaultValue:1];
        functions[c].bias = [function numberForParameter:IJSVGAttributeOffset
                                            defaultValue:0];
        NSArray<NSNumber*>* values = [function numbersForParameter:IJSVGAttributeTableValues];
        functions[c].offset = tables.length / sizeof(double);
        functions[c].count = values.count;
        for(NSNumber* number in values) {
            double value = number.doubleValue;
            [tables appendBytes:&value
                         length:sizeof(value)];
        }
    }

}

// Check whether Core Image can represent this channel function.
static BOOL IJSVGTransferPolynomialCoefficients(IJSVGComponentTransferFunction f,
                                                const double* tableValues,
                                                CGFloat coefficients[4])
{
    if(f.type == 3) {
        coefficients[0] = f.intercept;
        coefficients[1] = f.slope;
    } else if(f.type == 1 && f.count == 2) {
        coefficients[0] = tableValues[f.offset];
        coefficients[1] = tableValues[f.offset + 1] - coefficients[0];
    } else if((f.type == 1 || f.type == 2) && f.count == 1) {
        coefficients[0] = tableValues[f.offset];
        coefficients[1] = 0;
    } else if(f.type == 4 && f.exponent >= 0 && f.exponent <= 3 && floor(f.exponent) == f.exponent) {
        memset(coefficients, 0, 4 * sizeof(*coefficients));
        coefficients[0] = f.bias;
        coefficients[(NSUInteger)f.exponent] += f.amplitude;
    } else if(f.type == 4 || ((f.type == 1 || f.type == 2) && f.count > 0)) {
        return NO;
    }
    return YES;
}

@implementation IJSVGComponentTransferFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;
    IJSVGComponentTransferFunction functions[4] = { 0 };
    NSMutableData* tables = [[NSMutableData alloc] init];
    IJSVGPrepareTransferFunctions(primitive, functions, tables);

    // Use Core Image for functions that fit a simple polynomial.
    // Other functions use the pixel calculation below.
    NSMutableDictionary* polynomial = [[NSMutableDictionary alloc] init];
    NSArray* coefficientKeys = @[@"inputRedCoefficients", @"inputGreenCoefficients",
                                 @"inputBlueCoefficients", @"inputAlphaCoefficients"];
    BOOL supportsPolynomial = YES;
    const double* tableValues = tables.bytes;
    for(NSUInteger c = 0; c < 4; c++) {
        IJSVGComponentTransferFunction f = functions[c];
        CGFloat coefficients[4] = { 0, 1, 0, 0 };
        if(!IJSVGTransferPolynomialCoefficients(f, tableValues, coefficients)) {
            supportsPolynomial = NO;
        }
        polynomial[coefficientKeys[c]] = [CIVector vectorWithValues:coefficients
                                                              count:4];
    }
    if(supportsPolynomial) {
        CIImage* output = [[context imageInPrimitiveColorSpace:input] imageByApplyingFilter:@"CIColorPolynomial"
                                                                        withInputParameters:polynomial];
        output = [output imageByApplyingFilter:@"CIColorClamp"
                           withInputParameters:@{
            @"inputMinComponents": [CIVector vectorWithX:0 Y:0 Z:0 W:0],
            @"inputMaxComponents": [CIVector vectorWithX:1 Y:1 Z:1 W:1]
        }];
        return [context imageFromPrimitiveColorSpace:output];
    }
    // A shared RGB exponent can use one gamma adjustment.
    // Apply the remaining color changes and opacity separately.
    if(functions[0].type == 4 && functions[1].type == 4 && functions[2].type == 4 &&
        functions[0].exponent > 0 &&
        functions[0].exponent == functions[1].exponent && functions[0].exponent == functions[2].exponent &&
        (functions[3].type == 0 || functions[3].type == 3)) {
        for(NSUInteger c = 0; c < 3; c++) {
            polynomial[coefficientKeys[c]] = [CIVector vectorWithX:functions[c].bias Y:functions[c].amplitude
                                                                 Z:0 W:0];
        }
        CIImage* output = [[context imageInPrimitiveColorSpace:input]
            imageByApplyingFilter:@"CIGammaAdjust"
              withInputParameters:@{
            @"inputPower": @(functions[0].exponent)
        }];
        output = [output imageByApplyingFilter:@"CIColorPolynomial"
                           withInputParameters:polynomial];
        output = [output imageByApplyingFilter:@"CIColorClamp"
                           withInputParameters:@{
            @"inputMinComponents": [CIVector vectorWithX:0 Y:0 Z:0 W:0],
            @"inputMaxComponents": [CIVector vectorWithX:1 Y:1 Z:1 W:1]
        }];
        return [context imageFromPrimitiveColorSpace:output];
    }
    NSData* configuration = [NSData dataWithBytes:functions
                                           length:sizeof(functions)];
    return [context mapImage:input
                       other:nil
                   operation:^(const float* src, const float* unused, float* dst, NSInteger w, NSInteger h) {
        IJSVGFilterApplyRows(w, h, ^(NSInteger firstRow, NSInteger lastRow) {
           NSInteger offset = firstRow * w * 4;
           IJSVGApplyTransferToPixels(src + offset, dst + offset, w, lastRow - firstRow,
                                      configuration, tables);
        });
    }];
}

@end
