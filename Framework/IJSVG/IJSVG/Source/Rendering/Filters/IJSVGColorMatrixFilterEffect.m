//
//  IJSVGColorMatrixFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColorMatrixFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGColorMatrixFilterEffect

- (BOOL)requiresSupersamplingForPrimitive:(IJSVGFilterPrimitive*)primitive
{
    // Alpha amplifying matrices need extra coverage samples at shape edges.
    NSString* type = primitive.parameters[IJSVGAttributeType] ?: IJSVGStringMatrix;
    NSArray<NSNumber*>* values = [primitive numbersForParameter:IJSVGAttributeValues];
    return [type isEqualToString:IJSVGStringMatrix] && values.count == 20
        && values[18].doubleValue > 1.;
}

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;
    double matrix[20] = { 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0 };
    NSString* type = primitive.parameters[IJSVGAttributeType] ?: IJSVGStringMatrix;
    NSArray<NSNumber*>* values = [primitive numbersForParameter:IJSVGAttributeValues];
    if([type isEqualToString:IJSVGStringMatrix]) {
        if(values.count != 0 && values.count != 20) {
            return CIImage.emptyImage;
        }
        for(NSUInteger i = 0; i < values.count; i++) {
            matrix[i] = values[i].doubleValue;
        }
    } else if([type isEqualToString:IJSVGStringSaturate]) {
        double s = [primitive numberForParameter:IJSVGAttributeValues
                                    defaultValue:1];
        double m[] = { .213 + .787 * s, .715 - .715 * s, .072 - .072 * s, 0, 0, .213 - .213 * s, .715 + .285 * s,
            .072 - .072 * s, 0, 0, .213 - .213 * s, .715 - .715 * s, .072 + .928 * s, 0, 0, 0, 0, 0, 1, 0 };
        memcpy(matrix, m, sizeof(matrix));
    } else if([type isEqualToString:IJSVGStringHueRotate]) {
        double angle = [primitive numberForParameter:IJSVGAttributeValues
                                        defaultValue:0] * M_PI / 180.;
        double c = cos(angle), s = sin(angle);
        double m[] = { .213 + .787 * c - .213 * s, .715 - .715 * c - .715 * s, .072 - .072 * c + .928 * s, 0, 0,
            .213 - .213 * c + .143 * s, .715 + .285 * c + .140 * s, .072 - .072 * c - .283 * s, 0, 0,
            .213 - .213 * c - .787 * s, .715 - .715 * c + .715 * s, .072 + .928 * c + .072 * s, 0, 0, 0, 0, 0, 1, 0 };
        memcpy(matrix, m, sizeof(matrix));
    } else if([type isEqualToString:IJSVGStringLuminanceToAlpha]) {
        memset(matrix, 0, sizeof(matrix));
        matrix[15] = .2125;
        matrix[16] = .7154;
        matrix[17] = .0721;
    }
    // Opacity scaling commutes with RGB transfer functions. Keep the clamp,
    // including its RGB bounds, but omit the two color space conversion nodes.
    // Do not combine general matrices: each primitive must clamp independently.
    BOOL opacityOnly = isfinite(matrix[18]) && matrix[18] >= 0 && matrix[18] <= 1;
    for(NSUInteger i = 0; i < 20 && opacityOnly; i++) {
        if(i != 18 && matrix[i] != ((i == 0 || i == 6 || i == 12) ? 1. : 0.)) {
            opacityOnly = NO;
        }
    }
    NSMutableDictionary* parameters = [[NSMutableDictionary alloc] init];
    NSArray* keys = @[@"inputRVector", @"inputGVector", @"inputBVector", @"inputAVector"];
    for(NSUInteger c = 0; c < 4; c++) {
        parameters[keys[c]] = [CIVector vectorWithX:matrix[c * 5]
                                                  Y:matrix[c * 5 + 1]
                                                  Z:matrix[c * 5 + 2]
                                                  W:matrix[c * 5 + 3]];
    }
    parameters[@"inputBiasVector"] = [CIVector vectorWithX:matrix[4] Y:matrix[9]
                                                         Z:matrix[14] W:matrix[19]];
    CIImage* image =
        [(opacityOnly ? input : [context imageInPrimitiveColorSpace:input]) imageByApplyingFilter:@"CIColorMatrix"
                                                                              withInputParameters:parameters];
    image = [image imageByApplyingFilter:@"CIColorClamp"
                     withInputParameters:@{
        @"inputMinComponents": [CIVector vectorWithX:0 Y:0 Z:0 W:0],
        @"inputMaxComponents": [CIVector vectorWithX:1 Y:1 Z:1 W:1]
    }];
    return opacityOnly ? image : [context imageFromPrimitiveColorSpace:image];
}

@end
