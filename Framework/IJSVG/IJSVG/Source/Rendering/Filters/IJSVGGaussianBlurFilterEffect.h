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
             edgeMode:(IJSVGFilterEdgeMode)edgeMode
              context:(IJSVGFilterContext*)context;

// Use this for images that only contain opacity values.
- (CIImage*)blurImage:(CIImage*)image
            deviation:(CGSize)deviation
             edgeMode:(IJSVGFilterEdgeMode)edgeMode
            alphaOnly:(BOOL)alphaOnly
              context:(IJSVGFilterContext*)context;

// Keep the samples needed around the requested output.
- (CIImage*)blurImage:(CIImage*)image
            deviation:(CGSize)deviation
             edgeMode:(IJSVGFilterEdgeMode)edgeMode
            alphaOnly:(BOOL)alphaOnly
               region:(CGRect)region
              context:(IJSVGFilterContext*)context;

@end
