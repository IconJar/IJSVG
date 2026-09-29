//
//  IJSVGDropShadowFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGDropShadowFilterEffect.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGGaussianBlurFilterEffect.h>

@implementation IJSVGDropShadowFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;
    CGSize deviation = [primitive pairForParameter:IJSVGAttributeStdDeviation
                                      defaultValue:CGSizeMake(2, 2)];
    if(deviation.width < 0 || deviation.height < 0) {
        deviation = CGSizeMake(2, 2);
    }
    IJSVGGaussianBlurFilterEffect* blur = [IJSVGGaussianBlurFilterEffect effectForType:IJSVGNodeTypeFilterGaussianBlur];
    CIImage* blurred = [blur blurImage:[context alphaForImage:input]
                             deviation:deviation
                              edgeMode:IJSVGStringNone
                             alphaOnly:YES
                               context:context];
    CIImage* offset = [context offsetImage:blurred
                                        dx:[primitive numberForParameter:IJSVGAttributeDX
                                                            defaultValue:2]
                                        dy:[primitive numberForParameter:IJSVGAttributeDY
                                                            defaultValue:2]];
    CIImage* flood = [[IJSVGFilterEffect effectForType:IJSVGNodeTypeFilterFlood] outputImageForPrimitive:primitive
                                                                                                  inputs:@[]
                                                                                                  region:region
                                                                                                 context:context];
    CIImage* colored = [flood imageByApplyingFilter:@"CISourceInCompositing"
                                withInputParameters:@{ kCIInputBackgroundImageKey: offset }];
    return [context applyFilter:@"CISourceOverCompositing"
                        toImage:input
                     parameters:@{ kCIInputBackgroundImageKey: [context imageInPrimitiveColorSpace:colored] }];
}

@end
