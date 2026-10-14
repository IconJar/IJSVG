//
//  IJSVGOffsetFilterEffect.m
//  IJSVG
//
//  Created by Curtis Hard on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGParser.h>
#import <IJSVGOffsetFilterEffect.h>

@implementation IJSVGOffsetFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive inputs:(NSArray<CIImage*>*)inputs region:(CGRect)region context:(IJSVGFilterContext*)context
{
    // Move the image using the filter coordinate units.
    CIImage* image = [context offsetImage:inputs.firstObject ?: CIImage.emptyImage dx:[primitive numberForParameter:IJSVGAttributeDX defaultValue:0] dy:[primitive numberForParameter:IJSVGAttributeDY defaultValue:0]];

    // Moving pixels does not move the primitive subregion. Preserve its
    // transparent margins so a following blur can spread back into them.
    CIImage* background = [[CIImage imageWithColor:CIColor.clearColor] imageByCroppingToRect:region];
    return [[image imageByCompositingOverImage:background] imageByCroppingToRect:region];
}

@end
