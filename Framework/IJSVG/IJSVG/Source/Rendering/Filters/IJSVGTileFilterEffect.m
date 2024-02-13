//
//  IJSVGTileFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTileFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGTileFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CGAffineTransform xform = CGAffineTransformIdentity;
    NSValue *xformObj = [NSValue valueWithBytes:&xform objCType:@encode(CGAffineTransform)];

    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;
    // Repeat the input image only when it has valid bounds.
    return IJSVGFilterValidRect(input.extent) ? [input imageByApplyingFilter:@"CIAffineTile"
                                                         withInputParameters:@{
        kCIInputTransformKey: xformObj
    }] : CIImage.emptyImage;
}

@end
