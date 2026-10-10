//
//  IJSVGDropShadowFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGDropShadowFilterEffect.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVGGaussianBlurFilterEffect.h>

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
    CGFloat dx = [primitive numberForParameter:IJSVGAttributeDX defaultValue:2];
    CGFloat dy = [primitive numberForParameter:IJSVGAttributeDY defaultValue:2];
    CGSize units = context.pixelUnits;
    // Find the shadow samples before moving them into the output.
    CGRect blurRegion = CGRectOffset(region, -dx * units.width, -dy * units.height);
    // Blur the opacity to get the shadow shape.
    CIImage* blurred = [blur blurImage:[context alphaForImage:input]
                             deviation:deviation
                              edgeMode:IJSVGFilterEdgeModeNone
                             alphaOnly:YES
                                region:blurRegion
                               context:context];
    // Move the shadow away from the original image.
    CIImage* offset = [context offsetImage:blurred
                                        dx:dx
                                        dy:dy];
    CIImage* flood = [[IJSVGFilterEffect effectForType:IJSVGNodeTypeFilterFlood] outputImageForPrimitive:primitive
                                                                                                  inputs:@[]
                                                                                                  region:region
                                                                                                 context:context];
    // Give the shadow its color and draw the original image over it.
    CIImage* colored = [flood imageByApplyingFilter:@"CISourceInCompositing"
                                withInputParameters:@{
        kCIInputBackgroundImageKey: offset
    }];
    return [context applyFilter:@"CISourceOverCompositing"
                        toImage:input
                     parameters:@{
        kCIInputBackgroundImageKey: [context imageInPrimitiveColorSpace:colored]
    }];
}

@end
