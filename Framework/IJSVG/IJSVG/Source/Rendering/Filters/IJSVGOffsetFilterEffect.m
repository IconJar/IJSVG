//
//  IJSVGOffsetFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGOffsetFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGOffsetFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    return [context offsetImage:inputs.firstObject ?: CIImage.emptyImage
                             dx:[primitive numberForParameter:IJSVGAttributeDX
                                                 defaultValue:0]
                             dy:[primitive numberForParameter:IJSVGAttributeDY
                                                 defaultValue:0]];
}

@end
