//
//  IJSVGFilter.m
//  IJSVG
//
//  Created by Curtis Hard on 18/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGFilter.h"
#import "IJSVGFilterEffect.h"
#import "IJSVGLayer.h"

@implementation IJSVGFilter

- (CGImageRef)newImageByApplyFilterToLayer:(CALayer<IJSVGDrawableLayer>*)layer
                                     scale:(CGFloat)scale
{
    IJSVGFilter* filter = layer.filter;
    layer.filter = nil;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef originalImage = [IJSVGLayer newImageForLayer:layer
                                                 colorSpace:colorSpace
                                                 bitmapInfo:kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little
                                                      scale:1.f];
    CIImage* image = [CIImage imageWithCGImage:originalImage];
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(originalImage);
    for(IJSVGFilterEffect* effect in self.children) {
        image = [effect processImage:image];
    }
    CIContext* context = [CIContext context];
    CGImageRef outputImage = [context createCGImage:image
                                           fromRect:image.extent];
    NSImage* nimage = [[[NSImage alloc] initWithCGImage:outputImage
                                                   size:NSMakeSize(CGImageGetWidth(outputImage),
                                                                   CGImageGetHeight(outputImage))] autorelease];
    layer.filter = filter;
    return outputImage;
}

@end
