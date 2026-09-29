//
//  IJSVGGaussianBlurFilterEffect.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterEffect.h>

@interface IJSVGGaussianBlurFilterEffect : IJSVGFilterEffect

- (CIImage*)blurImage:(CIImage*)image
            deviation:(CGSize)deviation
             edgeMode:(NSString*)edgeMode
              context:(IJSVGFilterContext*)context;

// Use for alpha images whose RGB channels are already zero.
- (CIImage*)blurImage:(CIImage*)image
            deviation:(CGSize)deviation
             edgeMode:(NSString*)edgeMode
            alphaOnly:(BOOL)alphaOnly
              context:(IJSVGFilterContext*)context;

@end
