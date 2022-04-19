//
//  IJSVGFilterEffectGaussianBlur.m
//  IJSVG
//
//  Created by Curtis Hard on 18/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGFilterEffectGaussianBlur.h"

@implementation IJSVGFilterEffectGaussianBlur

- (CIImage*)processImage:(CIImage*)image
{
    CIFilter* filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setDefaults];
    [filter setValue:image forKey:kCIInputImageKey];
    [filter setValue:@(self.stdDeviation.value) forKey:kCIInputRadiusKey];
    return [filter valueForKey:kCIOutputImageKey];
}

@end
