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

// Build blur weights and scale them so their total is one.
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

static BOOL IJSVGApplyInterleavedBlurToPixels(const float* src, float* dst,
                                              NSInteger w, NSInteger h,
    NSData* kernelX, NSData* kernelY)
{
    uint32_t nx = (uint32_t)(kernelX.length / sizeof(float));
    uint32_t ny = (uint32_t)(kernelY.length / sizeof(float));
    if(nx == 1 && ny == 1) {
        return NO;
    }
    // A blur in one direction can write straight to the output.
    NSMutableData* temporary = nx > 1 && ny > 1 ? [NSMutableData dataWithLength:w * h * 4 * sizeof(float)] : nil;
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

static void IJSVGApplyGaussianBlurToPixels(const float* src, float* dst, NSInteger w, NSInteger h,
                                           NSData* kernelX, NSData* kernelY, NSUInteger channels)
{
    // Process all color channels together for large images with short kernels.
    // Small images and long kernels use one channel at a time.
    if(channels == 4 && w * h >= 65536 &&
        kernelX.length + kernelY.length <= 64 * sizeof(float) &&
        IJSVGApplyInterleavedBlurToPixels(src, dst, w, h, kernelX, kernelY)) {
        return;
    }
    // Opacity images have one channel and can use the output directly.
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
            // Replace invalid pixel values with zero.
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

static CIImage* IJSVGSmallKernelBlur(CIImage* image, NSData* kernelX, NSData* kernelY,
                                     IJSVGFilterContext* context)
{
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
            @"inputWeights": [CIVector vectorWithValues:coefficients count:9],
            @"inputBias": @0
        }];
    }
    return [context imageFromPrimitiveColorSpace:output];
}

static CIImage* IJSVGAlphaBlur(CIImage* image, NSData* kernelX, NSData* kernelY,
    IJSVGFilterContext* context, CGRect bounds)
{
    // Shadows only need opacity values.
    // The blur is symmetric so the rows do not need to be flipped.
    NSInteger w = bounds.size.width, h = bounds.size.height;
    NSMutableData* source = [NSMutableData dataWithLength:w * h * sizeof(float)];
    NSMutableData* output = [NSMutableData dataWithLength:source.length];
    [context.context render:image
                   toBitmap:source.mutableBytes
                   rowBytes:w * sizeof(float)
                     bounds:bounds
                     format:kCIFormatAf
                 colorSpace:NULL];
    IJSVGApplyGaussianBlurToPixels(source.bytes, output.mutableBytes, w, h, kernelX, kernelY, 1);
    CIImage* result = [CIImage imageWithBitmapData:output
                                       bytesPerRow:w * sizeof(float)
                                              size:bounds.size
                                            format:kCIFormatAf
                                        colorSpace:NULL];
    return [result imageByApplyingTransform:CGAffineTransformMakeTranslation(
        bounds.origin.x, bounds.origin.y)];
}

@implementation IJSVGGaussianBlurFilterEffect

// Blur in two directions on the GPU without copying pixels to the CPU.
// Very wide blurs use the CPU path.
- (CIImage*)metalBlurImage:(CIImage*)image
          horizontalKernel:(NSData*)kernelX
            verticalKernel:(NSData*)kernelY
                 alphaOnly:(BOOL)alphaOnly
                   context:(IJSVGFilterContext*)context
{
    NSUInteger counts[] = { kernelX.length / sizeof(float), kernelY.length / sizeof(float) };
    // Only use this path for a single color blur.
    // Later effects may need samples between pixels.
    if(alphaOnly || context.filter.primitives.count != 1 || !context.supportsMetalKernels ||
        counts[0] > 257 || counts[1] > 257 ||
        !IJSVGFilterValidRect(context.extent)) {
        return nil;
    }
    static CIKernel* convolution;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString* source = IJSVGFilterShaderSource(@"IJSVGSeparableBlur");
        if(source == nil) {
            return;
        }
        convolution = [CIKernel kernelsWithMetalString:source
                                                 error:NULL].firstObject;
    });
    if(convolution == nil) {
        return nil;
    }
    CGRect extent = context.extent;
    CIImage* output = alphaOnly ? image : [context imageInPrimitiveColorSpace:image];
    output = [output imageByCroppingToRect:extent];
    NSArray<NSData*>* kernels = @[kernelX, kernelY];
    for(NSUInteger axis = 0; axis < 2; axis++) {
        NSUInteger count = counts[axis];
        if(count == 1) {
            continue;
        }
        CIImage* weights = [CIImage imageWithBitmapData:kernels[axis] bytesPerRow:count * sizeof(float)
                                                   size:CGSizeMake(count, 1) format:kCIFormatAf colorSpace:NULL];
        CGFloat radius = count / 2;
        BOOL horizontal = axis == 0;
        output = [convolution applyWithExtent:extent roiCallback:^CGRect(int index, CGRect rect) {
            return index == 1 ? CGRectMake(0, 0, count, 1)
                : CGRectIntersection(extent, CGRectInset(rect, horizontal ? -radius : 0, horizontal ? 0 : -radius));
        } arguments:@[output, weights, [CIVector vectorWithX:horizontal ? 1 : 0 Y:horizontal ? 0 : 1],
            @(count), [CIVector vectorWithX:CGRectGetMinX(extent) Y:CGRectGetMinY(extent)
                                          Z:CGRectGetMaxX(extent) W:CGRectGetMaxY(extent)],
                      @(axis == 1 || counts[1] == 1)]];
        if(output == nil) {
            return nil;
        }
    }
    return alphaOnly ? output : [context imageFromPrimitiveColorSpace:output];
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
    return [self blurImage:image
                 deviation:deviation
                  edgeMode:edgeMode
                 alphaOnly:alphaOnly
                    region:context.extent
                   context:context];
}

- (CIImage*)blurImage:(CIImage*)image
            deviation:(CGSize)deviation
             edgeMode:(NSString*)edgeMode
            alphaOnly:(BOOL)alphaOnly
               region:(CGRect)region
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
                         withInputParameters:@{
            kCIInputTransformKey: [NSAffineTransform transform]
        }];
    }
    if(sigmaX == 0 && sigmaY == 0) {
        return image;
    }
    if(fabs(sigmaX - sigmaY) < 0.00001) {
        return [context applyFilter:@"CIGaussianBlur"
                            toImage:image
                         parameters:@{
            kCIInputRadiusKey: @(sigmaX)
        }];
    }
    NSData* kernelX = IJSVGFilterKernel(sigmaX);
    NSData* kernelY = IJSVGFilterKernel(sigmaY);
    // Use Core Image directly when both blur kernels fit within nine values.
    if(kernelX.length <= 9 * sizeof(float) && kernelY.length <= 9 * sizeof(float)) {
        return IJSVGSmallKernelBlur(image, kernelX, kernelY, context);
    }
    CIImage* metal = [self metalBlurImage:image
                         horizontalKernel:kernelX
                           verticalKernel:kernelY
                                alphaOnly:alphaOnly
                                  context:context];
    if(metal != nil) {
        return metal;
    }
    // Keep the blur radius and one extra pixel for sampling fractional offsets.
    CGRect bounds = CGRectIntersection(context.extent, CGRectIntegral(CGRectInset(region,
        -(CGFloat)(kernelX.length / sizeof(float) / 2 + 1),
        -(CGFloat)(kernelY.length / sizeof(float) / 2 + 1))));
  
    if(!IJSVGFilterValidRect(bounds)) {
        return CIImage.emptyImage;
    }
  
    if(alphaOnly) {
        return IJSVGAlphaBlur(image, kernelX, kernelY, context, bounds);
    }
  
    // Blur each direction separately when one blur radius cannot describe both.
    return [context mapImage:image
                       other:nil
                      region:bounds
                   operation:^(const float* src, const float* unused, float* dst, NSInteger w, NSInteger h) {
      
        IJSVGApplyGaussianBlurToPixels(src, dst, w, h, kernelX, kernelY, 4);
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
                 alphaOnly:context.inputIsAlphaOnly ||
                     [primitive.input isEqualToString:IJSVGStringSourceAlpha] ||
                     [primitive.input isEqualToString:IJSVGStringBackgroundAlpha]
                    region:region
                   context:context];
}

@end
