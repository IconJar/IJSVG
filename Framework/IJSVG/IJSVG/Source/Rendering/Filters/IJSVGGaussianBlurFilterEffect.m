//
//  IJSVGGaussianBlurFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGaussianBlurFilterEffect.h>
#import <IJSVG/IJSVGParser.h>
#import <Accelerate/Accelerate.h>

static NSData* IJSVGFilterKernel(CGFloat sigma)
{
    NSUInteger radius = sigma > 0.f ? (NSUInteger)ceil(3.f * MIN(sigma, 4096.f)) : 0;
    NSMutableData* data = [NSMutableData dataWithLength:(radius * 2 + 1) * sizeof(float)];
    float* weights = data.mutableBytes;
    double total = 0.;
    for(NSUInteger i = 0; i <= radius * 2; i++) {
        double distance = (double)i - radius;
        weights[i] = radius == 0 ? 1.f : exp(-.5 * pow(distance / sigma, 2.));
        total += weights[i];
    }
    for(NSUInteger i = 0; i <= radius * 2; i++) {
        weights[i] /= total;
    }
    return data;
}

@implementation IJSVGGaussianBlurFilterEffect

- (BOOL)applyInterleavedBlurToPixels:(const float*)src
                              output:(float*)dst
                               width:(NSInteger)w
                              height:(NSInteger)h
                    horizontalKernel:(NSData*)kernelX
                      verticalKernel:(NSData*)kernelY
{
    uint32_t nx = (uint32_t)(kernelX.length / sizeof(float));
    uint32_t ny = (uint32_t)(kernelY.length / sizeof(float));
    if(nx == 1 && ny == 1) {
        return NO;
    }
    // A single-axis blur can write directly to the destination.
    NSMutableData* temporary = nx > 1 && ny > 1
        ? [NSMutableData dataWithLength:w * h * 4 * sizeof(float)] : nil;
    vImage_Buffer input = { (void*)src, h, w, w * 4 * sizeof(float) };
    vImage_Buffer output = { dst, h, w, w * 4 * sizeof(float) };
    vImage_Buffer intermediate = temporary == nil ? output
        : (vImage_Buffer){ temporary.mutableBytes, h, w, w * 4 * sizeof(float) };
    vImage_Buffer verticalInput = nx > 1 ? intermediate : input;
    Pixel_FFFF background = { 0, 0, 0, 0 };
    vImage_Flags query = kvImageBackgroundColorFill | kvImageGetTempBufferSize;
    vImage_Error horizontalSize = nx > 1 ? vImageConvolve_ARGBFFFF(&input, &intermediate,
        NULL, 0, 0, kernelX.bytes, 1, nx, background, query) : 0;
    vImage_Error verticalSize = ny > 1 ? vImageConvolve_ARGBFFFF(&verticalInput, &output,
        NULL, 0, 0, kernelY.bytes, ny, 1, background, query) : 0;
    if(horizontalSize < 0 || verticalSize < 0) {
        return NO;
    }
    NSMutableData* workspace = [NSMutableData dataWithLength:MAX(horizontalSize, verticalSize)];
    vImage_Error error = kvImageNoError;
    if(nx > 1) {
        error = vImageConvolve_ARGBFFFF(&input, &intermediate, workspace.mutableBytes,
            0, 0, kernelX.bytes, 1, nx, background, kvImageBackgroundColorFill);
    }
    if(error == kvImageNoError && ny > 1) {
        error = vImageConvolve_ARGBFFFF(&verticalInput, &output, workspace.mutableBytes,
            0, 0, kernelY.bytes, ny, 1, background, kvImageBackgroundColorFill);
    }
    if(error != kvImageNoError) {
        vDSP_vclr(dst, 1, (vDSP_Length)w * h * 4);
        return NO;
    }
    for(NSInteger i = 0; i < w * h * 4; i++) {
        if(!isfinite(dst[i])) {
            dst[i] = 0.f;
        }
    }
    float minimum = 0.f, maximum = 1.f;
    vDSP_vclip(dst, 1, &minimum, &maximum, dst, 1, (vDSP_Length)w * h * 4);
    return YES;
}

- (void)applyGaussianBlurToPixels:(const float*)src
                           output:(float*)dst
                            width:(NSInteger)w
                           height:(NSInteger)h
                 horizontalKernel:(NSData*)kernelX
                   verticalKernel:(NSData*)kernelY
                         channels:(NSUInteger)channels
{
    // Direct RGBA convolution avoids eight strided channel copies for larger
    // images. Long kernels and small icons are faster on the planar path.
    if(channels == 4 && w * h >= 65536
        && kernelX.length + kernelY.length <= 64 * sizeof(float)
        && [self applyInterleavedBlurToPixels:src
                                      output:dst
                                       width:w
                                      height:h
                            horizontalKernel:kernelX
                              verticalKernel:kernelY]) {
        return;
    }
    // Alpha-only bitmaps are already planar; convolve directly into their output.
    NSMutableData* plane = channels == 1 ? nil : [NSMutableData dataWithLength:w * h * sizeof(float)];
    NSMutableData* result = channels == 1 ? nil : [NSMutableData dataWithLength:plane.length];
    float* inPlane = channels == 1 ? (float*)src : plane.mutableBytes;
    float* outPlane = channels == 1 ? dst : result.mutableBytes;
    vImage_Buffer input = { inPlane, h, w, w * sizeof(float) };
    vImage_Buffer output = { outPlane, h, w, w * sizeof(float) };
    uint32_t kernelWidth = (uint32_t)(kernelX.length / sizeof(float));
    uint32_t kernelHeight = (uint32_t)(kernelY.length / sizeof(float));
    vImage_Error bufferSize = vImageSepConvolve_PlanarF(&input, &output, NULL, 0, 0,
        kernelX.bytes, kernelWidth, kernelY.bytes, kernelHeight, 0.f, 0.f,
        kvImageBackgroundColorFill | kvImageGetTempBufferSize);
    NSMutableData* workspace = bufferSize > 0 ? [NSMutableData dataWithLength:(NSUInteger)bufferSize] : nil;
    for(NSUInteger channel = 0; channel < channels; channel++) {
        float zero = 0.f;
        if(channels != 1) {
            vDSP_vsadd(src + channel, channels, &zero, inPlane, 1, w * h);
        }
        vImage_Error error = vImageSepConvolve_PlanarF(&input, &output, workspace.mutableBytes, 0, 0,
            kernelX.bytes, kernelWidth, kernelY.bytes, kernelHeight, 0.f, 0.f, kvImageBackgroundColorFill);
        if(error == kvImageNoError) {
            // Preserve the treatment by the scalar evaluator of nonfinite pixels.
            for(NSInteger i = 0; i < w * h; i++) {
                if(!isfinite(outPlane[i])) {
                    outPlane[i] = 0.f;
                }
            }
            float maximum = 1.f;
            vDSP_vclip(outPlane, 1, &zero, &maximum, dst + channel, channels, w * h);
        }
    }
}

- (CIImage*)blurImage:(CIImage*)image
            deviation:(CGSize)deviation
             edgeMode:(NSString*)edgeMode
              context:(IJSVGFilterContext*)context
{
    return [self blurImage:image
                 deviation:deviation
                  edgeMode:edgeMode
                 alphaOnly:NO
                   context:context];
}

- (CIImage*)blurImage:(CIImage*)image
            deviation:(CGSize)deviation
             edgeMode:(NSString*)edgeMode
            alphaOnly:(BOOL)alphaOnly
              context:(IJSVGFilterContext*)context
{
    if(deviation.width < 0 || deviation.height < 0) {
        return CIImage.emptyImage;
    }
    CGSize units = context.pixelUnits;
    CGFloat sigmaX = deviation.width * units.width, sigmaY = deviation.height * units.height;
    if([edgeMode isEqualToString:IJSVGStringDuplicate]) {
        image = [image imageByClampingToExtent];
    } else if([edgeMode isEqualToString:IJSVGStringWrap]) {
        image = [image imageByApplyingFilter:@"CIAffineTile"
                         withInputParameters:@{ kCIInputTransformKey: [NSAffineTransform transform] }];
    }
    if(sigmaX == 0 && sigmaY == 0) {
        return image;
    }
    if(fabs(sigmaX - sigmaY) < 0.00001) {
        return [context applyFilter:@"CIGaussianBlur"
                            toImage:image
                         parameters:@{ kCIInputRadiusKey: @(sigmaX) }];
    }
    NSData* kernelX = IJSVGFilterKernel(sigmaX);
    NSData* kernelY = IJSVGFilterKernel(sigmaY);
    // A nine tap convolution expresses small single axis or unequal axis blurs
    // exactly, including the SVG axis with zero deviation, without a bitmap readback.
    if(kernelX.length <= 9 * sizeof(float) && kernelY.length <= 9 * sizeof(float)) {
        CIImage* output = [context imageInPrimitiveColorSpace:image];
        NSArray<NSData*>* kernels = @[kernelX, kernelY];
        NSArray<NSString*>* names = @[@"CIConvolution9Horizontal",
                                      @"CIConvolution9Vertical"];
        for(NSUInteger axis = 0; axis < 2; axis++) {
            NSUInteger count = kernels[axis].length / sizeof(float);
            if(count == 1) {
                continue;
            }
            CGFloat coefficients[9] = { 0 };
            const float* weights = kernels[axis].bytes;
            for(NSUInteger i = 0; i < count; i++) {
                coefficients[(9 - count) / 2 + i] = weights[i];
            }
            output = [output imageByApplyingFilter:names[axis]
                               withInputParameters:@{
                                   @"inputWeights": [CIVector vectorWithValues:coefficients
                                                                         count:9],
                                   @"inputBias": @0
                               }];
        }
        return [context imageFromPrimitiveColorSpace:output];
    }
    if(alphaOnly) {
        // Shadows need no RGB storage or color conversion. Keep Core Image's row
        // order on both sides; the symmetric Gaussian kernels need no row flip.
        NSInteger w = context.extent.size.width, h = context.extent.size.height;
        NSMutableData* source = [NSMutableData dataWithLength:w * h * sizeof(float)];
        NSMutableData* output = [NSMutableData dataWithLength:source.length];
        [context.context render:image
                       toBitmap:source.mutableBytes
                       rowBytes:w * sizeof(float)
                         bounds:context.extent
                         format:kCIFormatAf
                     colorSpace:NULL];
        [self applyGaussianBlurToPixels:source.bytes
                                 output:output.mutableBytes
                                  width:w
                                 height:h
                       horizontalKernel:kernelX
                         verticalKernel:kernelY
                               channels:1];
        CIImage* result = [CIImage imageWithBitmapData:output
                                           bytesPerRow:w * sizeof(float)
                                                  size:context.extent.size
                                                format:kCIFormatAf
                                            colorSpace:NULL];
        return [result imageByApplyingTransform:CGAffineTransformMakeTranslation(
            context.extent.origin.x, context.extent.origin.y)];
    }
    // SVG supports independent deviations, including an exactly zero axis.
    // Keep the separable fallback for cases the isotropic CI filter cannot express.
    return [context mapImage:image
                       other:nil
                   operation:^(const float* src, const float* unused, float* dst, NSInteger w, NSInteger h) {
                       [self applyGaussianBlurToPixels:src
                                                output:dst
                                                 width:w
                                                height:h
                                      horizontalKernel:kernelX
                                        verticalKernel:kernelY
                                              channels:4];
                   }];
}

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    return [self blurImage:inputs.firstObject ?: CIImage.emptyImage
                 deviation:[primitive pairForParameter:IJSVGAttributeStdDeviation
                                          defaultValue:CGSizeZero]
                  edgeMode:primitive.parameters[IJSVGAttributeEdgeMode] ?: IJSVGStringNone
                   context:context];
}

@end
