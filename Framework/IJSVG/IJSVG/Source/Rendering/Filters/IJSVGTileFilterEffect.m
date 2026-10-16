//
//  IJSVGTileFilterEffect.m
//  IJSVG
//
//  Created by Curtis Hard on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <CoreImage/CIFilterBuiltins.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVGTileFilterEffect.h>

@implementation IJSVGTileFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive inputs:(NSArray<CIImage*>*)inputs region:(CGRect)region context:(IJSVGFilterContext*)context
{
    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;

    // Repeat the input image only when it has valid bounds.
    if (!IJSVGFilterValidRect(input.extent)) {
        return CIImage.emptyImage;
    }
    CIFilter<CIAffineTile>* filter = CIFilter.affineTileFilter;
    filter.inputImage = input;
    filter.transform = CGAffineTransformIdentity;
    return filter.outputImage ?: CIImage.emptyImage;
}

@end
