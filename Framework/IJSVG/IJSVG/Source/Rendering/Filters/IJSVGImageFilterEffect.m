//
//  IJSVGImageFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGImageFilterEffect.h>
#import <IJSVG/IJSVGViewBox.h>
#import <IJSVG/IJSVGShapeLayer.h>
#import <IJSVG/IJSVGLayerTree.h>

@implementation IJSVGImageFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    if(context.imageProvider != nil) {
        return context.imageProvider(primitive, region);
    }

    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(
        NULL, context.extent.size.width, context.extent.size.height, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if(bitmap == NULL) {
        return CIImage.emptyImage;
    }
    CGContextClipToRect(bitmap, region);
    if(primitive.imageNode != nil) {
        IJSVGLayerTree* tree = [[IJSVGLayerTree alloc] init];
        CALayer<IJSVGDrawableLayer>* layer = [tree drawableLayerForNode:primitive.imageNode
                                                             inViewPort:context.viewPort];
        CGContextConcatCTM(bitmap, context.imageTransform);
        CGContextTranslateCTM(bitmap, layer.frame.origin.x, layer.frame.origin.y);
        [layer renderInContext:bitmap];
    } else if(primitive.image != nil) {
        CGImageRef image = [primitive.image CGImageForProposedRect:NULL
                                                           context:nil
                                                             hints:nil];
        if(image != NULL) {
            CGRect viewBox = CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image));
            CGContextTranslateCTM(bitmap, region.origin.x, region.origin.y);
            CGRect drawingRect = (CGRect) { CGPointZero, region.size };
            IJSVGContextDrawViewBox(bitmap, viewBox, drawingRect, primitive.viewBoxAlignment,
                primitive.viewBoxMeetOrSlice, ^(CGFloat scale[]) { CGContextDrawImage(bitmap, viewBox, image); });
        }
    }
    CGImageRef result = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    CIImage* image = result != NULL ? [CIImage imageWithCGImage:result] : CIImage.emptyImage;
    if(result != NULL) {
        CGImageRelease(result);
    }
    return [image imageByCroppingToRect:region];
}

@end
