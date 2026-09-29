//
//  IJSVGBlendFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGBlendFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGBlendFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;
    CIImage* other = inputs.count > 1 ? inputs[1] : CIImage.emptyImage;
    // Core Image blend operators run in its working space; explicitly match
    // sRGB primitives into/out of that space so the SVG property is respected.
    static NSDictionary<NSString*, NSString*>* modes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        modes = @{
            IJSVGStringNormal: @"CISourceOverCompositing",
            IJSVGStringMultiply: @"CIMultiplyBlendMode",
            IJSVGStringScreen: @"CIScreenBlendMode",
            IJSVGStringDarken: @"CIDarkenBlendMode",
            IJSVGStringLighten: @"CILightenBlendMode",
            IJSVGStringOverlay: @"CIOverlayBlendMode",
            IJSVGStringColorDodge: @"CIColorDodgeBlendMode",
            IJSVGStringColorBurn: @"CIColorBurnBlendMode",
            IJSVGStringHardLight: @"CIHardLightBlendMode",
            IJSVGStringSoftLight: @"CISoftLightBlendMode",
            IJSVGStringDifference: @"CIDifferenceBlendMode",
            IJSVGStringExclusion: @"CIExclusionBlendMode",
            IJSVGStringHue: @"CIHueBlendMode",
            IJSVGStringSaturation: @"CISaturationBlendMode",
            IJSVGStringColor: @"CIColorBlendMode",
            IJSVGStringLuminosity: @"CILuminosityBlendMode"
        };
    });
    return [context applyFilter:modes[primitive.parameters[IJSVGAttributeMode]] ?: @"CISourceOverCompositing"
                        toImage:input
                     parameters:@{
        kCIInputBackgroundImageKey: [context imageInPrimitiveColorSpace:other]
    }];
}

@end
