//
//  IJSVGFilter.m
//  IJSVG
//
//  Created by Curtis Hard on 18/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGFilterEffect.h>
#import <IJSVG/IJSVGLayer.h>
#import <IJSVG/IJSVGThreadManager.h>

@implementation IJSVGFilter

- (BOOL)valid
{
    return self.children.count != 0;
}

- (CGImageRef)newImageByApplyFilterToLayer:(CALayer<IJSVGDrawableLayer>*)layer
                                     scale:(CGFloat)scale
{
    IJSVGFilter* filter = layer.filter;
    layer.filter = nil;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    uint32_t info = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little;
    CGImageRef originalImage = [IJSVGLayer newImageForLayer:layer
                                                 colorSpace:colorSpace
                                                 bitmapInfo:info
                                                      scale:scale];
    CIImage* image = [CIImage imageWithCGImage:originalImage];
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(originalImage);
    
    for(IJSVGFilterEffect* effect in self.children) {
        image = [effect processImage:image];
    }
    
    IJSVGThreadManager* manager = IJSVGThreadManager.currentManager;
    CIContext* context = manager.CIContext;
    CGImageRef outputImage = [context createCGImage:image
                                           fromRect:image.extent];
    layer.filter = filter;
    return outputImage;
}

- (void)addChild:(IJSVGNode*)child
{
    if([child isKindOfClass:IJSVGFilterEffect.class] == NO) {
        return;
    }
    [super addChild:child];
}

@end
