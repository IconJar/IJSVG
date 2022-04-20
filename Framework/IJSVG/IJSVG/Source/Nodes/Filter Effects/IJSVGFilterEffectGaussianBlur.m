//
//  IJSVGFilterEffectGaussianBlur.m
//  IJSVG
//
//  Created by Curtis Hard on 18/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGFilterEffectGaussianBlur.h"
#import <IJSVG/IJSVGThreadManager.h>

@implementation IJSVGFilterEffectGaussianBlur

+ (CIFilter*)sharedFilter
{
    IJSVGThreadManager* manager = IJSVGThreadManager.currentManager;
    NSString* key = @"CIFilterGaussianBlur";
    CIFilter* filter = nil;
    if((filter = [manager userInfoObjectForKey:key]) == nil) {
        filter = [CIFilter filterWithName:@"CIGaussianBlur"];
        [manager setUserInfoObject:filter
                            forKey:key];
    }
    return filter;
}

- (CIImage*)processImage:(CIImage*)image
{
    CIFilter* filter = [self.class sharedFilter];
    [filter setDefaults];
    [filter setValue:image forKey:kCIInputImageKey];
    [filter setValue:@(self.stdDeviation.value) forKey:kCIInputRadiusKey];
    return [filter valueForKey:kCIOutputImageKey];
}

@end
