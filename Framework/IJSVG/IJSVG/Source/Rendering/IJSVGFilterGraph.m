//
//  IJSVGFilterGraph.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterGraph.h>
#import <IJSVG/IJSVGFilterEffect.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <Accelerate/Accelerate.h>

// Small isotropic blurs use the current Core Image impulse response. This avoids
// approximating its subpixel radius kernel, which differs from a point sampled
// Gaussian. Calibration is shared across icons and bounded to 64 small kernels.
static NSData* IJSVGSmallBlurWeights(CGFloat sigma)
{
    if(sigma == 0) {
        float one = 1.f;
        return [NSData dataWithBytes:&one length:sizeof(one)];
    }
    static NSCache<NSNumber*, NSData*>* cache;
    static NSObject* lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 64;
        lock = [[NSObject alloc] init];
    });
    NSNumber* key = @(sigma);
    NSData* cached = [cache objectForKey:key];
    if(cached != nil) {
        return cached;
    }
    @synchronized(lock) {
        cached = [cache objectForKey:key];
        if(cached != nil) {
            return cached;
        }
        NSUInteger radius = (NSUInteger)ceil(3 * sigma) + 1;
        NSUInteger side = radius * 2 + 1;
        NSMutableData* pixels = [NSMutableData dataWithLength:side * side * sizeof(float)];
        float* values = pixels.mutableBytes;
        for(NSUInteger y = 0; y < side; y++) {
            values[y * side + radius] = 1.f;
        }
        CIImage* stripe = [CIImage imageWithBitmapData:pixels
                                         bytesPerRow:side * sizeof(float)
                                                size:CGSizeMake(side, side)
                                              format:kCIFormatAf colorSpace:NULL];
        CIImage* blurred = [stripe imageByApplyingFilter:@"CIGaussianBlur"
                                    withInputParameters:@{ kCIInputRadiusKey: key }];
        NSMutableData* weights = [NSMutableData dataWithLength:side * sizeof(float)];
        [IJSVGThreadManager performBlockWithCIContext:^(CIContext* context, BOOL supportsMetalKernels) {
            [context render:blurred toBitmap:weights.mutableBytes
                   rowBytes:side * sizeof(float) bounds:CGRectMake(0, radius, side, 1)
                     format:kCIFormatAf colorSpace:NULL];
        }];
        float* samples = weights.mutableBytes;
        double total = 0;
        for(NSUInteger i = 0; i < side; i++) {
            if(!isfinite(samples[i]) || samples[i] < 0) {
                return nil;
            }
            total += samples[i];
        }
        if(total < .99 || total > 1.01) {
            return nil;
        }
        for(NSUInteger i = 0; i < side; i++) {
            samples[i] /= total;
        }
        [cache setObject:weights forKey:key];
        return weights;
    }
}

static BOOL IJSVGSmallBlur(const float* source, float* output, NSUInteger width,
                          NSUInteger height, NSUInteger channels, NSData* weights)
{
    NSUInteger count = width * height;
    NSUInteger taps = weights.length / sizeof(float);
    if(taps == 1) {
        memcpy(output, source, count * channels * sizeof(float));
        return YES;
    }
    NSMutableData* plane = [NSMutableData dataWithLength:count * sizeof(float)];
    NSMutableData* result = [NSMutableData dataWithLength:plane.length];
    vImage_Buffer input = { plane.mutableBytes, height, width, width * sizeof(float) };
    vImage_Buffer destination = { result.mutableBytes, height, width, width * sizeof(float) };
    vImage_Flags flags = kvImageBackgroundColorFill | kvImageDoNotTile;
    vImage_Error size = vImageSepConvolve_PlanarF(&input, &destination, NULL, 0, 0,
        weights.bytes, (uint32_t)taps, weights.bytes, (uint32_t)taps, 0, 0,
        flags | kvImageGetTempBufferSize);
    if(size < 0) {
        return NO;
    }
    NSMutableData* scratch = [NSMutableData dataWithLength:(NSUInteger)size];
    for(NSUInteger channel = 0; channel < channels; channel++) {
        float zero = 0;
        vDSP_vsadd(source + channel, channels, &zero, plane.mutableBytes, 1, count);
        if(vImageSepConvolve_PlanarF(&input, &destination, scratch.mutableBytes, 0, 0,
            weights.bytes, (uint32_t)taps, weights.bytes, (uint32_t)taps, 0, 0, flags) != kvImageNoError) {
            return NO;
        }
        vDSP_vsadd(result.bytes, 1, &zero, output + channel, channels, count);
    }
    return YES;
}

static float IJSVGSmallPixelCoverage(CGFloat x, CGFloat y, NSUInteger height, CGRect region)
{
    // CI crops preserve fractional pixel coverage, and each primitive can crop
    // again. A center point test loses edge alpha in exported filter regions.
    double bottom = height - y - 1;
    double horizontal = fmax(0, fmin(x + 1, CGRectGetMaxX(region)) - fmax(x, CGRectGetMinX(region)));
    double vertical = fmax(0, fmin(bottom + 1, CGRectGetMaxY(region)) - fmax(bottom, CGRectGetMinY(region)));
    return horizontal * vertical;
}

@implementation IJSVGFilterGraph

- (CGRect)regionForNode:(IJSVGNode*)node
                  units:(IJSVGUnitType)units
          defaultRegion:(CGRect)region
{
    CGRect bounds = units == IJSVGUnitObjectBoundingBox ? self.boundingBox : self.viewPort;
    BOOL objectUnits = units == IJSVGUnitObjectBoundingBox;
    IJSVGUnitLength* lengths[] = { node.x, node.y, node.width, node.height };
    CGFloat values[] = { region.origin.x, region.origin.y, region.size.width, region.size.height };
    for(NSUInteger index = 0; index < 4; index++) {
        IJSVGUnitLength* length = lengths[index];
        if(length == nil) {
            continue;
        }
        if(objectUnits) {
            length = [length lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        }
        values[index] = [length computeValue:index % 2 == 0 ? bounds.size.width : bounds.size.height];
        if(index < 2 && (objectUnits || length.type == IJSVGUnitLengthTypePercentage)) {
            values[index] += index == 0 ? bounds.origin.x : bounds.origin.y;
        }
    }
    return CGRectMake(values[0], values[1], values[2], values[3]);
}

- (BOOL)usesLinearRGB:(IJSVGNode*)node
{
    for(IJSVGNode* current = node; current != nil; current = current.parentNode) {
        if([current.filterColorInterpolation isEqualToString:IJSVGStringSRGB]) {
            return NO;
        }
        if([current.filterColorInterpolation isEqualToString:IJSVGStringLinearRGB]) {
            return YES;
        }
    }
    return YES;
}

- (CIImage*)inputNamed:(NSString*)name
              previous:(CIImage*)previous
               sources:(NSDictionary<NSString*, CIImage*>*)sources
               results:(NSDictionary<NSString*, CIImage*>*)results
{
    if(name.length == 0) {
        return previous;
    }
    return sources[name] ?: results[name] ?: previous;
}

- (CIImage*)imageByFilteringSource:(CIImage*)source
{
    IJSVGFilterContext* renderingContext = [[IJSVGFilterContext alloc] init];
    renderingContext.filter = self.filter;
    renderingContext.boundingBox = self.boundingBox;
    renderingContext.viewPort = self.viewPort;
    renderingContext.extent = self.extent;
    renderingContext.imageTransform = self.imageTransform;
    renderingContext.context = self.context;
    renderingContext.supportsMetalKernels = self.supportsMetalKernels;
    renderingContext.imageProvider = self.imageProvider;
    CGRect userRegion = [self regionForNode:self.filter
                                      units:self.filter.units
                              defaultRegion:CGRectZero];
    CGRect filterRegion = CGRectApplyAffineTransform(userRegion, self.imageTransform);
    if(!IJSVGFilterValidRect(filterRegion)) {
        return CIImage.emptyImage;
    }
    source = [source imageByCroppingToRect:filterRegion];

    NSSet<NSString*>* inputNames = self.filter.inputNames;
    NSMutableDictionary<NSString*, CIImage*>* sources = [@{
        IJSVGStringSourceGraphic: source,
        IJSVGStringBackgroundImage: CIImage.emptyImage,
        IJSVGStringBackgroundAlpha: CIImage.emptyImage
    } mutableCopy];

    // Ordinary blurs and drop shadows do not reference SourceAlpha in the graph.
    if([inputNames containsObject:IJSVGStringSourceAlpha]) {
        sources[IJSVGStringSourceAlpha] = [renderingContext alphaForImage:source];
    }

    if(self.backgroundProvider != nil
        && ([inputNames containsObject:IJSVGStringBackgroundImage] || [inputNames containsObject:IJSVGStringBackgroundAlpha])) {
        CIImage* background = [self.backgroundProvider() imageByCroppingToRect:filterRegion] ?: CIImage.emptyImage;
        sources[IJSVGStringBackgroundImage] = background;
        if([inputNames containsObject:IJSVGStringBackgroundAlpha]) {
            sources[IJSVGStringBackgroundAlpha] = [renderingContext alphaForImage:background];
        }
    }

    if(self.paintProvider != nil) {
        if([inputNames containsObject:IJSVGStringFillPaint]) {
            sources[IJSVGStringFillPaint] = [self.paintProvider(NO) imageByCroppingToRect:filterRegion] ?: CIImage.emptyImage;
        }
        if([inputNames containsObject:IJSVGStringStrokePaint]) {
            sources[IJSVGStringStrokePaint] =
                [self.paintProvider(YES) imageByCroppingToRect:filterRegion] ?: CIImage.emptyImage;
        }
    }

    NSMutableDictionary<NSString*, CIImage*>* results = [[NSMutableDictionary alloc] init];
    NSArray<IJSVGFilterPrimitive*>* primitives = self.filter.primitives;
    BOOL preserveInnerShadowCoverage = self.filter.preservesInnerShadowCoverage;
    NSMutableDictionary<NSString*, NSNumber*>* lastReferences = [[NSMutableDictionary alloc] init];

    for(NSUInteger index = 0; index < primitives.count; index++) {
        IJSVGFilterPrimitive* primitive = primitives[index];
        if(primitive.input != nil) {
            lastReferences[primitive.input] = @(index);
        }
        if(primitive.input2 != nil) {
            lastReferences[primitive.input2] = @(index);
        }
        for(IJSVGFilterPrimitive* child in primitive.children) {
            if(child.input != nil) {
                lastReferences[child.input] = @(index);
            }
        }
    }

    // Schedule the release of each named result once instead of scanning all live results per primitive.
    NSMutableDictionary<NSNumber*, NSMutableArray<NSString*>*>* expiredNames = [[NSMutableDictionary alloc] init];
    for(NSString* name in lastReferences) {
        NSNumber* index = lastReferences[name];
        NSMutableArray<NSString*>* names = expiredNames[index];
        if(names == nil) {
            names = [[NSMutableArray alloc] init];
            expiredNames[index] = names;
        }
        [names addObject:name];
    }

    CGAffineTransform inverseTransform = CGAffineTransformInvert(self.imageTransform);
    CIImage* output = source;
    for(NSUInteger index = 0; index < primitives.count; index++) {
        IJSVGFilterPrimitive* primitive = primitives[index];
        @autoreleasepool {
            renderingContext.linearRGB = [self usesLinearRGB:primitive];
            // Recognized inner shadows keep RGB identically zero through the
            // hard alpha, offset, blur and subtract stages. Colour matching those
            // intermediates cannot change their pixels, only their graph cost.
            NSUInteger shadowStage = index >= 2 ? (index - 2) % 6 : NSNotFound;
            renderingContext.inputIsAlphaOnly = preserveInnerShadowCoverage && shadowStage <= 4;
            renderingContext.outputIsAlphaOnly = preserveInnerShadowCoverage && shadowStage <= 3;
            CIImage* input = [self inputNamed:primitive.input
                                     previous:output
                                      sources:sources
                                      results:results];
            CIImage* other = [self inputNamed:primitive.input2
                                     previous:output
                                      sources:sources
                                      results:results];
            CGRect defaultRegion = input.extent;
            BOOL generator = primitive.type == IJSVGNodeTypeFilterFlood
                || primitive.type == IJSVGNodeTypeFilterTurbulence || primitive.type == IJSVGNodeTypeFilterImage
                || primitive.type == IJSVGNodeTypeFilterTile;
            if(generator) {
                defaultRegion = filterRegion;
            } else if(primitive.type == IJSVGNodeTypeFilterBlend || primitive.type == IJSVGNodeTypeFilterComposite
                || primitive.type == IJSVGNodeTypeFilterDisplacementMap) {
                defaultRegion = CGRectUnion(defaultRegion, other.extent);
            }
            NSMutableArray<CIImage*>* mergeInputs = nil;
            if(primitive.type == IJSVGNodeTypeFilterMerge) {
                defaultRegion = CGRectNull;
                mergeInputs = [[NSMutableArray alloc] init];
                for(IJSVGFilterPrimitive* child in primitive.children) {
                    CIImage* image = [self inputNamed:child.input
                                             previous:output
                                              sources:sources
                                              results:results];
                    [mergeInputs addObject:image];
                    defaultRegion = CGRectUnion(defaultRegion, image.extent);
                }
            }
            // Empty inputs still allow operations such as arithmetic k4 or an
            // alpha transfer intercept to produce pixels in the filter region.
            if(!IJSVGFilterValidRect(defaultRegion)) {
                defaultRegion = filterRegion;
            }
            CGRect defaultUserRegion
                = CGRectApplyAffineTransform(defaultRegion, inverseTransform);
            CGRect primitiveRegion = [self regionForNode:primitive
                                                   units:self.filter.contentUnits
                                           defaultRegion:defaultUserRegion];
            CGRect pixelRegion = CGRectApplyAffineTransform(primitiveRegion, self.imageTransform);
            if(!IJSVGFilterValidRect(pixelRegion)) {
                output = CIImage.emptyImage;
            } else {
                if(preserveInnerShadowCoverage && index > 1
                   && primitive.type == IJSVGNodeTypeFilterBlend) {
                    // A hard alpha inner shadow must shade the foreground without
                    // making its partially covered edge pixels opaque. Source atop
                    // preserves the original outline through successive shadows.
                    output = [renderingContext applyFilter:@"CISourceAtopCompositing"
                                                   toImage:input
                                                parameters:@{
                      kCIInputBackgroundImageKey: [renderingContext imageInPrimitiveColorSpace:other]
                    }];
                } else {
                    IJSVGFilterEffect* effect = [IJSVGFilterEffect effectForType:primitive.type];
                    NSArray<CIImage*>* inputs = mergeInputs ?: @[input, other];
                    output = [effect outputImageForPrimitive:primitive
                                                      inputs:inputs
                                                      region:pixelRegion
                                                     context:renderingContext] ?: CIImage.emptyImage;
                }
                CGRect clip = CGRectIntersection(filterRegion, pixelRegion);
                output = IJSVGFilterValidRect(clip) ? [output imageByCroppingToRect:clip] : CIImage.emptyImage;
            }
            // Keep only named intermediates with future consumers. The previous
            // output remains available independently for implicit chaining.
            for(NSString* name in expiredNames[@(index)]) {
                [results removeObjectForKey:name];
            }
            if(primitive.result.length != 0 && lastReferences[primitive.result].unsignedIntegerValue > index) {
                results[primitive.result] = output;
            }
        }
    }
    return primitives.count == 0 ? CIImage.emptyImage : output;
}

- (IJSVGMetalShadowJob*)metalShadowJobForBitmap:(CGContextRef)bitmap
{
    NSUInteger width = CGBitmapContextGetWidth(bitmap), height = CGBitmapContextGetHeight(bitmap);
    if(width == 0 || height == 0 || width > 512 || height > 512
        || self.imageTransform.b != 0 || self.imageTransform.c != 0
        || self.imageTransform.a <= 0 || self.imageTransform.a != self.imageTransform.d
        || !self.filter.preservesInnerShadowCoverage) {
        return nil;
    }
    NSArray<IJSVGFilterPrimitive*>* primitives = self.filter.primitives;
    NSUInteger shadows = (primitives.count - 2) / 6;
    if(shadows > 4) {
        return nil;
    }
    for(IJSVGFilterPrimitive* primitive in primitives) {
        if([self usesLinearRGB:primitive]) {
            return nil;
        }
    }
    CGRect region = CGRectApplyAffineTransform([self regionForNode:self.filter units:self.filter.units
        defaultRegion:CGRectZero], self.imageTransform);
    if(!IJSVGFilterValidRect(region)) {
        return nil;
    }
    CGSize units = self.filter.contentUnits == IJSVGUnitObjectBoundingBox
        ? CGSizeMake(self.boundingBox.size.width * self.imageTransform.a, self.boundingBox.size.height * self.imageTransform.a)
        : CGSizeMake(self.imageTransform.a, self.imageTransform.a);
    IJSVGMetalShadowParameters parameters = {0};
    parameters.geometry = (simd_uint4){(uint32_t)width, (uint32_t)height, 0, 0};
    parameters.region = (simd_float4){CGRectGetMinX(region), CGRectGetMinY(region),
        CGRectGetMaxX(region), CGRectGetMaxY(region)};
    parameters.config.x = (uint32_t)shadows;
    for(NSUInteger stage = 0; stage < shadows; stage++) {
        NSUInteger index = 2 + stage * 6;
        IJSVGFilterPrimitive* blur = primitives[index + 2];
        CGSize deviation = [blur pairForParameter:IJSVGAttributeStdDeviation defaultValue:CGSizeZero];
        CGFloat sigma = deviation.width * units.width;
        CGFloat dy = [primitives[index + 1] numberForParameter:IJSVGAttributeDY defaultValue:0] * units.height;
        CGFloat dx = [primitives[index + 1] numberForParameter:IJSVGAttributeDX defaultValue:0] * units.width;
        if(!isfinite(sigma) || sigma < .2 || sigma > 4 || !isfinite(deviation.height * units.height)
            || fabs(sigma - deviation.height * units.height) > .00001 || !isfinite(dx) || !isfinite(dy)
            || fabs(dx) >= region.size.width || fabs(dy) >= region.size.height
            || ![(blur.parameters[IJSVGAttributeEdgeMode] ?: IJSVGStringNone) isEqualToString:IJSVGStringNone]) {
            return nil;
        }
        NSData* weights = IJSVGSmallBlurWeights(sigma);
        if(weights == nil || weights.length > 32 * sizeof(float)) {
            return nil;
        }
        CGFloat gain = [primitives[index] numbersForParameter:IJSVGAttributeValues][18].doubleValue;
        if(gain > 65504) {
            return nil;
        }
        NSArray<NSNumber*>* tint = [primitives[index + 4] numbersForParameter:IJSVGAttributeValues];
        parameters.offsets[stage] = (simd_float4){dx, dy, gain, weights.length / sizeof(float)};
        parameters.tints[stage] = (simd_float4){tint[4].doubleValue, tint[9].doubleValue, tint[14].doubleValue, 1};
        memcpy(parameters.weights + stage * 32, weights.bytes, weights.length);
    }
    if(![IJSVGMetalShadowJob isAvailable]) {
        return nil;
    }
    NSMutableData* source = [NSMutableData dataWithLength:width * height * 4];
    NSUInteger stride = CGBitmapContextGetBytesPerRow(bitmap);
    for(NSUInteger y = 0; y < height; y++) {
        memcpy((uint8_t*)source.mutableBytes + y * width * 4,
            (uint8_t*)CGBitmapContextGetData(bitmap) + y * stride, width * 4);
    }
    IJSVGMetalShadowJob* job = [[IJSVGMetalShadowJob alloc] init];
    job.source = source;
    job.parameters = parameters;
    return job;
}

- (CGImageRef)newCGImageForSmallBlur:(CGContextRef)bitmap
{
    NSUInteger width = CGBitmapContextGetWidth(bitmap), height = CGBitmapContextGetHeight(bitmap);
    if(width == 0 || height == 0 || width > 256 || height > 256
        || self.imageTransform.b != 0 || self.imageTransform.c != 0
        || self.imageTransform.a <= 0 || self.imageTransform.a != self.imageTransform.d) {
        return NULL;
    }
    NSArray<IJSVGFilterPrimitive*>* primitives = self.filter.primitives;
    if(primitives.count != 1 && primitives.count != 3) {
        return NULL;
    }
    IJSVGFilterPrimitive* blur = primitives.lastObject;
    if(blur.type != IJSVGNodeTypeFilterGaussianBlur
        || (blur.input.length != 0 && !(primitives.count == 1 && [blur.input isEqualToString:IJSVGStringSourceGraphic]))) {
        return NULL;
    }
    if(primitives.count == 3) {
        IJSVGFilterPrimitive* flood = primitives[0];
        IJSVGFilterPrimitive* blend = primitives[1];
        NSSet* reserved = [NSSet setWithArray:@[
            IJSVGStringSourceGraphic, IJSVGStringSourceAlpha,
            IJSVGStringBackgroundImage, IJSVGStringBackgroundAlpha,
            IJSVGStringFillPaint, IJSVGStringStrokePaint
        ]];
        if(flood.type != IJSVGNodeTypeFilterFlood
            || [flood numberForParameter:IJSVGAttributeFloodOpacity defaultValue:1] != 0
            || flood.result.length == 0 || [reserved containsObject:flood.result]
            || blend.type != IJSVGNodeTypeFilterBlend
            || ![blend.input isEqualToString:IJSVGStringSourceGraphic]
            || ![blend.input2 isEqualToString:flood.result]
            || ![(blend.parameters[IJSVGAttributeMode] ?: IJSVGStringNormal) isEqualToString:IJSVGStringNormal]) {
            return NULL;
        }
    }
    for(IJSVGFilterPrimitive* primitive in primitives) {
        if([self usesLinearRGB:primitive] || primitive.x != nil || primitive.y != nil
            || primitive.width != nil || primitive.height != nil || primitive.children.count != 0) {
            return NULL;
        }
    }
    CGSize units = self.filter.contentUnits == IJSVGUnitObjectBoundingBox
        ? CGSizeMake(self.boundingBox.size.width * self.imageTransform.a, self.boundingBox.size.height * self.imageTransform.a)
        : CGSizeMake(self.imageTransform.a, self.imageTransform.a);
    CGSize deviation = [blur pairForParameter:IJSVGAttributeStdDeviation defaultValue:CGSizeZero];
    CGFloat sigma = deviation.width * units.width;
    // Core Image can fuse crops for effectively identity blurs. Preserve its
    // fractional edge coverage by leaving those radii on the general path.
    if(!isfinite(sigma) || sigma < .2 || sigma > 4 || !isfinite(deviation.height * units.height)
        || fabs(sigma - deviation.height * units.height) > .00001
        || ![(blur.parameters[IJSVGAttributeEdgeMode] ?: IJSVGStringNone) isEqualToString:IJSVGStringNone]) {
        return NULL;
    }
    CGRect region = CGRectApplyAffineTransform([self regionForNode:self.filter units:self.filter.units
                                                     defaultRegion:CGRectZero], self.imageTransform);
    if(!IJSVGFilterValidRect(region)) {
        return NULL;
    }
    NSData* weights = IJSVGSmallBlurWeights(sigma);
    if(weights == nil) {
        return NULL;
    }
    NSUInteger count = width * height;
    NSMutableData* source = [NSMutableData dataWithLength:count * 4 * sizeof(float)];
    NSMutableData* output = [NSMutableData dataWithLength:source.length];
    const uint8_t* bytes = CGBitmapContextGetData(bitmap);
    NSUInteger stride = CGBitmapContextGetBytesPerRow(bitmap);
    float* src = source.mutableBytes;
    for(NSUInteger y = 0; y < height; y++) {
        for(NSUInteger x = 0; x < width; x++) {
            float coverage = IJSVGSmallPixelCoverage(x, y, height, region);
            // SourceGraphic is cropped once. The optional transparent blend
            // introduces another primitive crop, including fractional coverage.
            if(primitives.count == 3) {
                coverage *= coverage;
            }
            for(NSUInteger c = 0; c < 4; c++) {
                src[(y * width + x) * 4 + c] = coverage * bytes[y * stride + x * 4 + c] / 255.f;
            }
        }
    }
    if(!IJSVGSmallBlur(src, output.mutableBytes, width, height, 4, weights)) {
        return NULL;
    }
    CGContextRef result = CGBitmapContextCreate(NULL, width, height, 8, 0,
        CGBitmapContextGetColorSpace(bitmap), kCGImageAlphaPremultipliedLast);
    if(result == NULL) {
        return NULL;
    }
    uint8_t* destination = CGBitmapContextGetData(result);
    NSUInteger rowBytes = CGBitmapContextGetBytesPerRow(result);
    const float* dst = output.bytes;
    for(NSUInteger y = 0; y < height; y++) {
        for(NSUInteger x = 0; x < width; x++) {
            float coverage = IJSVGSmallPixelCoverage(x, y, height, region);
            for(NSUInteger c = 0; c < 4; c++) {
                float value = coverage * dst[(y * width + x) * 4 + c];
                destination[y * rowBytes + x * 4 + c] = (uint8_t)lrintf(fminf(1, fmaxf(0, value)) * 255);
            }
        }
    }
    CGImageRef image = CGBitmapContextCreateImage(result);
    CGContextRelease(result);
    return image;
}

@end
