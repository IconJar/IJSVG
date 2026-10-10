//
//  IJSVGBlendFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGBlendFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGBlendFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;
    CIImage* other = inputs.count > 1 ? inputs[1] : CIImage.emptyImage;
    // Convert colors before and after blending to follow the SVG color space.
    static NSDictionary<NSNumber*, NSString*>* modes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        modes = @{
            @(IJSVGBlendModeNormal): @"CISourceOverCompositing",
            @(IJSVGBlendModeMultiply): @"CIMultiplyBlendMode",
            @(IJSVGBlendModeScreen): @"CIScreenBlendMode",
            @(IJSVGBlendModeDarken): @"CIDarkenBlendMode",
            @(IJSVGBlendModeLighten): @"CILightenBlendMode",
            @(IJSVGBlendModeOverlay): @"CIOverlayBlendMode",
            @(IJSVGBlendModeColorDodge): @"CIColorDodgeBlendMode",
            @(IJSVGBlendModeColorBurn): @"CIColorBurnBlendMode",
            @(IJSVGBlendModeHardLight): @"CIHardLightBlendMode",
            @(IJSVGBlendModeSoftLight): @"CISoftLightBlendMode",
            @(IJSVGBlendModeDifference): @"CIDifferenceBlendMode",
            @(IJSVGBlendModeExclusion): @"CIExclusionBlendMode",
            @(IJSVGBlendModeHue): @"CIHueBlendMode",
            @(IJSVGBlendModeSaturation): @"CISaturationBlendMode",
            @(IJSVGBlendModeColor): @"CIColorBlendMode",
            @(IJSVGBlendModeLuminosity): @"CILuminosityBlendMode"
        };
    });
    return [context applyFilter:modes[@(primitive.filterBlendMode)] ?: @"CISourceOverCompositing"
                        toImage:input
                     parameters:@{
        kCIInputBackgroundImageKey: [context imageInPrimitiveColorSpace:other]
    }];
}

@end
