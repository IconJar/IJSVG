//
//  IJSVGImageFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGImageFilterEffect.h>
#import <IJSVG/IJSVGViewBox.h>
#import <IJSVG/IJSVGPaint.h>
#import <IJSVG/IJSVGQuartzRenderer.h>
#import <IJSVG/IJSVGImageRep.h>
#import <IJSVG/IJSVG.h>

@implementation IJSVGImageFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    if(context.imageProvider != nil) {
        return context.imageProvider(primitive, region);
    }

    if(primitive.imageNode == nil && primitive.image == nil) {
        return CIImage.emptyImage;
    }
    CGRect bounds = CGRectIntersection(context.extent, CGRectIntegral(region));
    if(!IJSVGFilterValidRect(bounds)) {
        return CIImage.emptyImage;
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(
        NULL, bounds.size.width, bounds.size.height, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if(bitmap == NULL) {
        return CIImage.emptyImage;
    }
    // Allocate only the visible region while keeping pixels aligned.
    CGContextTranslateCTM(bitmap, -bounds.origin.x, -bounds.origin.y);
    CGContextClipToRect(bitmap, region);
    if(primitive.imageNode != nil) {
        IJSVGQuartzRenderer* tree = [[IJSVGQuartzRenderer alloc] init];
        IJSVGPaint* layer = [tree drawablePaintForNode:primitive.imageNode
                                            inViewPort:context.viewPort];
        CGContextConcatCTM(bitmap, context.imageTransform);
        CGContextTranslateCTM(bitmap, layer.frame.origin.x, layer.frame.origin.y);
        [layer renderInContext:bitmap];
    } else if(primitive.image != nil) {
        // Embedded SVGs must be drawn at the filters current resolution.
        // Asking NSImage for a CGImage first rasterizes at its intrinsic size.
        IJSVGImageRep* vector = nil;
        for(NSImageRep* representation in primitive.image.representations) {
            if([representation isKindOfClass:IJSVGImageRep.class]) {
                vector = (IJSVGImageRep*)representation;
                break;
            }
        }
        if(vector != nil) {
            CGRect viewBox = (CGRect){ CGPointZero, vector.viewBox.size };
            CGContextTranslateCTM(bitmap, region.origin.x, region.origin.y);
            IJSVGContextDrawViewBox(bitmap, viewBox, (CGRect){ CGPointZero, region.size },
                primitive.viewBoxAlignment, primitive.viewBoxMeetOrSlice, ^(CGFloat scale[]) {
                    [vector.SVG drawInRect:viewBox context:bitmap];
                });
        }
        CGImageRef image = vector == nil ? [primitive.image CGImageForProposedRect:NULL
                                                                           context:nil
                                                                             hints:nil] : NULL;
        if(image != NULL) {
            CGRect viewBox = CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image));
            CGContextTranslateCTM(bitmap, region.origin.x, region.origin.y);
            CGRect drawingRect = (CGRect) { CGPointZero, region.size };
            IJSVGContextDrawViewBox(bitmap, viewBox, drawingRect, primitive.viewBoxAlignment,
                primitive.viewBoxMeetOrSlice, ^(CGFloat scale[]) {
                    CGContextDrawImage(bitmap, viewBox, image);
                });
        }
    }
    CGImageRef result = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    CIImage* image = result != NULL ? [CIImage imageWithCGImage:result] : CIImage.emptyImage;
    if(result != NULL) {
        CGImageRelease(result);
    }
    image = [image imageByApplyingTransform:CGAffineTransformMakeTranslation(bounds.origin.x, bounds.origin.y)];
    return [image imageByCroppingToRect:region];
}

@end
