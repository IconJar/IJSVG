//
//  IJSVGMorphologyFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGMorphologyFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGMorphologyFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;
    CGSize radius = [primitive pairForParameter:IJSVGAttributeRadius
                                   defaultValue:CGSizeZero];
    if(radius.width <= 0 || radius.height <= 0) {
        return input;
    }
    CGSize units = context.pixelUnits;
    NSInteger rx = MIN(context.extent.size.width, floor(radius.width * units.width));
    NSInteger ry = MIN(context.extent.size.height, floor(radius.height * units.height));
    BOOL dilate = primitive.morphologyOperator == IJSVGFilterMorphologyOperatorDilate;
    // SVG grows or shrinks pixels using a rectangular area.
    return [context applyFilter:dilate ? @"CIMorphologyRectangleMaximum" : @"CIMorphologyRectangleMinimum"
                        toImage:[input imageByCroppingToRect:context.extent]
                     parameters:@{
        @"inputWidth": @(2 * rx + 1),
        @"inputHeight": @(2 * ry + 1)
    }];
}

@end
