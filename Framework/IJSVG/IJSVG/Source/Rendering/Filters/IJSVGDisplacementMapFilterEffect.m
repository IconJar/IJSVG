//
//  IJSVGDisplacementMapFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGDisplacementMapFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGDisplacementMapFilterEffect

- (void)displacePixels:(const float*)src
                   map:(const float*)map
                output:(float*)dst
                 width:(NSInteger)w
                height:(NSInteger)h
              xChannel:(IJSVGFilterColorChannel)xc
              yChannel:(IJSVGFilterColorChannel)yc
                 scale:(double)scale
                 units:(CGSize)units
           inputRegion:(CGRect)inputRegion
          outputRegion:(CGRect)outputRegion
{
    IJSVGFilterSampler sampler = IJSVGFilterSamplerMake(src, w, h, inputRegion,
                                                        IJSVGFilterEdgeModeNone);
    double scaleX = scale * units.width, scaleY = scale * units.height;
    NSInteger minX = floor(CGRectGetMinX(outputRegion));
    NSInteger minY = floor(CGRectGetMinY(outputRegion));
    NSInteger maxX = ceil(CGRectGetMaxX(outputRegion));
    NSInteger maxY = ceil(CGRectGetMaxY(outputRegion));
    IJSVGFilterApplyRows(maxX - minX, maxY - minY, ^(NSInteger firstRow, NSInteger lastRow) {
        for(NSInteger y = minY + firstRow; y < minY + lastRow; y++) {
            for(NSInteger x = minX; x < maxX; x++) {
                NSInteger i = (y * w + x) * 4;
                double alpha = map[i + 3];
                double dx = xc == IJSVGFilterColorChannelAlpha ? alpha : (alpha > 0 ? map[i + xc] / alpha : 0);
                double dy = yc == IJSVGFilterColorChannelAlpha ? alpha : (alpha > 0 ? map[i + yc] / alpha : 0);
                IJSVGFilterSamplerPixel(&sampler, x + scaleX * (dx - .5), y + scaleY * (dy - .5), dst + i);
            }
        }
    });

}


- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;
    CIImage* other = inputs.count > 1 ? inputs[1] : CIImage.emptyImage;
    IJSVGFilterColorChannel xc = primitive.xChannel;
    IJSVGFilterColorChannel yc = primitive.yChannel;
    double scale = [primitive numberForParameter:IJSVGAttributeScale
                                    defaultValue:0];
    if(scale == 0) {
        return input;
    }
    CGRect outputRegion = CGRectIntersection(region, context.extent);
    if(CGRectIsEmpty(outputRegion)) {
        return CIImage.emptyImage;
    }
    CGSize units = context.pixelUnits;
    CGRect inputRegion = input.extent;
    // SVG uses separate color channels to move pixels in each direction.
    // The Core Image displacement filter uses one gray value so it cannot do the same job.
    return [context mapImage:input
                       other:other
                   operation:^(const float* src, const float* map, float* dst, NSInteger w, NSInteger h) {
        [self displacePixels:src
                         map:map
                      output:dst
                       width:w
                      height:h
                    xChannel:xc
                    yChannel:yc
                       scale:scale
                       units:units
                 inputRegion:inputRegion
                outputRegion:outputRegion];
    }];
}

@end
