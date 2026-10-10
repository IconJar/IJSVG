//
//  IJSVGTileFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTileFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGTileFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;
    // Repeat the input image only when it has valid bounds.
    return IJSVGFilterValidRect(input.extent) ? [input imageByApplyingFilter:@"CIAffineTile"
                                                         withInputParameters:@{
        kCIInputTransformKey: NSAffineTransform.transform
    }] : CIImage.emptyImage;
}

@end
