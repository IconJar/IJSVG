//
//  IJSVGFilterEffectGaussianBlur.m
//  IJSVG
//
//  Created by Curtis Hard on 18/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterEffectGaussianBlur.h>
#import <IJSVG/IJSVGFilterGraph.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <Accelerate/Accelerate.h>

@implementation IJSVGFilterEffectGaussianBlur

- (void)parseEffectAttributes:(NSDictionary<NSString*,NSString*> *)attributes
{
    [super parseEffectAttributes:attributes];

    NSString *colorInterpolation = attributes[@"color-interpolation-filters"];
    if(colorInterpolation.length == 0) {
        return;
    }

    _usesSRGBColorInterpolation = [colorInterpolation caseInsensitiveCompare:@"sRGB"] == NSOrderedSame;
}

- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph
{
    CIImage* input = [graph imageForInput:self.inputName];
    CGRect inputExtent = input.extent;
    CGFloat scaledSigma = self.stdDeviation.value * graph.scale;

    if(scaledSigma < 0.5f) {
        [graph setImage:input forResult:self.resultName];
        return input;
    }
    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setDefaults];
    [filter setValue:[input imageByClampingToExtent] forKey:kCIInputImageKey];
    [filter setValue:@(scaledSigma) forKey:kCIInputRadiusKey];
    CIImage *output = [filter valueForKey:kCIOutputImageKey];

    CGFloat expand = scaledSigma * 3.0;
    CGRect blurRegion = CGRectInset(inputExtent, -expand, -expand);
    output = [output imageByCroppingToRect:blurRegion];
    [graph setImage:output forResult:self.resultName];
    return output;
}

- (CIImage*)processImage:(CIImage*)image
{
    IJSVGThreadManager* manager = IJSVGThreadManager.currentManager;
    NSString* key = @"CIFilterGaussianBlur";
    CIFilter* filter = [manager userInfoObjectForKey:key];
    if(filter == nil) {
        filter = [CIFilter filterWithName:@"CIGaussianBlur"];
        [manager setUserInfoObject:filter forKey:key];
    }
    [filter setDefaults];
    [filter setValue:image forKey:kCIInputImageKey];
    [filter setValue:@(self.stdDeviation.value) forKey:kCIInputRadiusKey];
    return [filter valueForKey:kCIOutputImageKey];
}

@end
