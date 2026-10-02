//
//  IJSVGMergeFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGMergeFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGMergeFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CIImage* output = CIImage.emptyImage;
    // Keep the result in the filter color space until all images are merged.
    for(CIImage* image in inputs) {
        output = [[context imageInPrimitiveColorSpace:image] imageByApplyingFilter:@"CISourceOverCompositing"
                                                               withInputParameters:@{
            kCIInputBackgroundImageKey: output
        }];
    }
    return [context imageFromPrimitiveColorSpace:output];
}

@end
