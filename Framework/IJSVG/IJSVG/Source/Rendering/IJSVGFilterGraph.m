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
#import "IJSVGFilterSIMD.h"
#import <IJSVGMetalBlurRenderer.h>

// Gaussian. Calibration is shared across icons. Complex artwork can use more
// than 64 radii in a single draw; retain that working set without recalibrating
// each frame, and give NSCache a small byte budget for memory-pressure eviction.
static NSData* IJSVGSmallBlurWeights(CGFloat sigma)
{
    if(sigma == 0) {
        float one = 1.f;
        return [NSData dataWithBytes:&one
                              length:sizeof(one)];
    }
    static NSCache<NSNumber*, NSData*>* cache;
    static NSObject* lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 1024;
        cache.totalCostLimit = 256 * 1024;
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
                                                format:kCIFormatAf
                                            colorSpace:NULL];
        CIImage* blurred = [stripe imageByApplyingFilter:@"CIGaussianBlur"
                                     withInputParameters:@{ kCIInputRadiusKey: key }];
        NSMutableData* weights = [NSMutableData dataWithLength:side * sizeof(float)];
        [IJSVGThreadManager performBlockWithCIContext:^(CIContext* context, BOOL supportsMetalKernels) {
            [context render:blurred
                   toBitmap:weights.mutableBytes
                   rowBytes:side * sizeof(float)
                     bounds:CGRectMake(0, radius, side, 1)
                     format:kCIFormatAf
                 colorSpace:NULL];
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
        [cache setObject:weights
                  forKey:key
                    cost:weights.length];
        return weights;
    }
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

static BOOL IJSVGFilterUsesLinearRGB(IJSVGNode* node)
{
    return node.resolvedFilterColorInterpolation == IJSVGColorInterpolationLinearRGB;
}


static CIImage* IJSVGFilterInputNamed(
    NSString* name,
    CIImage* previous,
    NSDictionary<NSString*, CIImage*>* sources,
    NSDictionary<NSString*, CIImage*>* results)
{
    if(name.length == 0) {
        return previous;
    }
    return sources[name] ?: results[name] ?: previous;
}


static BOOL IJSVGFilterCanElideTransparentBlendAtIndex(NSUInteger index,
                                                       NSArray<IJSVGFilterPrimitive*>* primitives)
{
    if(index != 1) {
        return NO;
    }
    IJSVGFilterPrimitive* flood = primitives[0];
    IJSVGFilterPrimitive* blend = primitives[1];
  
    // Exporters commonly introduce SourceGraphic by blending over a named
    // transparent flood. Only that exact dependency is an identity operation.
    NSSet* sources = [NSSet setWithArray:@[IJSVGStringSourceGraphic, IJSVGStringSourceAlpha,
        IJSVGStringBackgroundImage, IJSVGStringBackgroundAlpha, IJSVGStringFillPaint, IJSVGStringStrokePaint]];
    return flood.type == IJSVGNodeTypeFilterFlood
        && [flood numberForParameter:IJSVGAttributeFloodOpacity defaultValue:1] == 0
        && flood.result.length != 0 && ![sources containsObject:flood.result]
        && blend.type == IJSVGNodeTypeFilterBlend
  
        // Linear light chains retain the original half float conversion boundary;
        // removing it accumulates visible rounding in overlapping compositions.
        && !IJSVGFilterUsesLinearRGB(blend)
        && [blend.input isEqualToString:IJSVGStringSourceGraphic]
        && [blend.input2 isEqualToString:flood.result]
        && blend.filterBlendMode == IJSVGBlendModeNormal;
}


static NSDictionary<NSString*, NSNumber*>* IJSVGFilterLastReferencesForPrimitives(
    NSArray<IJSVGFilterPrimitive*>* primitives)
{
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

    return lastReferences;
}


static NSDictionary<NSNumber*, NSArray<NSString*>*>* IJSVGFilterExpiredNamesForReferences(
    NSDictionary<NSString*, NSNumber*>* lastReferences)
{
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

    return expiredNames;
}


static NSArray<CIImage*>* IJSVGFilterMergeInputsForPrimitive(
    IJSVGFilterPrimitive* primitive,
    CIImage* output,
    NSDictionary<NSString*, CIImage*>* sources,
    NSDictionary<NSString*, CIImage*>* results)
{
    if(primitive.type != IJSVGNodeTypeFilterMerge) {
        return nil;
    }
    NSMutableArray<CIImage*>* inputs = [[NSMutableArray alloc] init];
    for(IJSVGFilterPrimitive* child in primitive.children) {
        [inputs addObject:IJSVGFilterInputNamed(child.input, output, sources, results)];
    }
    return inputs;
}


static CGColorRef IJSVGFilterNewShadowTintForPrimitive(IJSVGFilterPrimitive* primitive)
{
    NSString* value = [primitive.parameters[IJSVGAttributeFloodOpacity]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString* number = [value hasSuffix:@"%"] ? [value substringToIndex:value.length - 1] : value;
    CGFloat opacity = [IJSVGUtils numbersFromString:number].count == 1
        ? [IJSVGUtils floatValue:value fallBackForPercent:1] : 1;
    NSColor* color = [[IJSVGColor colorFromString:primitive.parameters[IJSVGAttributeFloodColor] ?: IJSVGStringBlack]
        colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    if(color == nil) {
        return NULL;
    }
    CGFloat components[] = {color.redComponent, color.greenComponent, color.blueComponent,
        color.alphaComponent * fmin(1, fmax(0, opacity))};
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGColorRef tint = CGColorCreate(space, components);
    CGColorSpaceRelease(space);
    return tint;
}


static NSData* IJSVGFilterBlurPixelsForBitmap(
    CGContextRef bitmap,
    CGRect region,
    BOOL linearRGB,
    NSUInteger sourceCrops)
{
    NSUInteger width = CGBitmapContextGetWidth(bitmap), height = CGBitmapContextGetHeight(bitmap);
    NSUInteger count = width * height;
    NSMutableData* source = [NSMutableData dataWithLength:count * 4 * sizeof(float)];
    const uint8_t* bytes = CGBitmapContextGetData(bitmap);
    NSUInteger stride = CGBitmapContextGetBytesPerRow(bitmap);
    float* src = source.mutableBytes;
    for(NSUInteger y = 0; y < height; y++) {
        for(NSUInteger x = 0; x < width; x++) {
            float coverage = IJSVGSmallPixelCoverage(x, y, height, region);
            // SourceGraphic is cropped once. The optional transparent blend
            // introduces another primitive crop, including fractional coverage.
            if(sourceCrops == 2) {
                coverage *= coverage;
            }
            float alpha = bytes[y * stride + x * 4 + 3] / 255.f;
            for(NSUInteger c = 0; c < 4; c++) {
                float value = bytes[y * stride + x * 4 + c] / 255.f;
                if(linearRGB && c < 3) {
                    // Convert straight colour, then premultiply for convolution.
                    value = alpha > 0 ? fminf(1, value / alpha) : 0;
                    value = value <= .04045f ? value / 12.92f :
                        powf((value + .055f) / 1.055f, 2.4f);
                    value *= alpha;
                }
                src[(y * width + x) * 4 + c] = coverage * value;
            }
        }
    }
    return source;
}


static CGImageRef IJSVGFilterNewImageForBlurPixels(NSData* output, CGContextRef bitmap,
                                                   CGRect region, BOOL linearRGB)
{
    NSUInteger width = CGBitmapContextGetWidth(bitmap), height = CGBitmapContextGetHeight(bitmap);
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
                float value = dst[(y * width + x) * 4 + c];
                if(linearRGB && c < 3) {
                    float alpha = dst[(y * width + x) * 4 + 3];
                    value = alpha > 0 ? fminf(1, fmaxf(0, value / alpha)) : 0;
                    value = value <= .0031308f ? value * 12.92f :
                        1.055f * powf(value, 1.f / 2.4f) - .055f;
                    value *= alpha;
                }
                value *= coverage;
                destination[y * rowBytes + x * 4 + c] = (uint8_t)lrintf(fminf(1, fmaxf(0, value)) * 255);
            }
        }
    }
    CGImageRef image = CGBitmapContextCreateImage(result);
    CGContextRelease(result);
    return image;
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

- (IJSVGFilterContext*)renderingContext
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
    return renderingContext;
}

- (NSDictionary<NSString*, CIImage*>*)sourcesForImage:(CIImage*)source
                                               region:(CGRect)filterRegion
                                              context:(IJSVGFilterContext*)renderingContext
{
    NSSet<NSString*>* inputNames = self.filter.inputNames;
    // Transparent inputs still need bounds when a filter creates visible pixels.
    CIImage* transparent = [[CIImage imageWithColor:CIColor.clearColor] imageByCroppingToRect:filterRegion];
    NSMutableDictionary<NSString*, CIImage*>* sources = [@{
        IJSVGStringSourceGraphic: source,
        IJSVGStringBackgroundImage: transparent,
        IJSVGStringBackgroundAlpha: transparent
    } mutableCopy];

    // Ordinary blurs and drop shadows do not reference SourceAlpha in the graph.
    if([inputNames containsObject:IJSVGStringSourceAlpha]) {
        sources[IJSVGStringSourceAlpha] = [renderingContext alphaForImage:source];
    }

    if(self.backgroundProvider != nil &&
        ([inputNames containsObject:IJSVGStringBackgroundImage] ||
        [inputNames containsObject:IJSVGStringBackgroundAlpha])) {
        CIImage* background = [self.backgroundProvider() imageByCroppingToRect:filterRegion];
        if(background == nil || !IJSVGFilterValidRect(background.extent)) {
            background = transparent;
        }
        sources[IJSVGStringBackgroundImage] = background;
        if([inputNames containsObject:IJSVGStringBackgroundAlpha]) {
            sources[IJSVGStringBackgroundAlpha] = [renderingContext alphaForImage:background];
        }
    }

    if(self.paintProvider != nil) {
        if([inputNames containsObject:IJSVGStringFillPaint]) {
            sources[IJSVGStringFillPaint] = [self.paintProvider(NO) imageByCroppingToRect:filterRegion]
                ?: CIImage.emptyImage;
        }
        if([inputNames containsObject:IJSVGStringStrokePaint]) {
            sources[IJSVGStringStrokePaint] = [self.paintProvider(YES) imageByCroppingToRect:filterRegion]
                ?: CIImage.emptyImage;
        }
    }

    return sources;
}

- (CIImage*)evaluatePrimitiveAtIndex:(NSUInteger)index
                               input:(CIImage*)input
                               other:(CIImage*)other
                         mergeInputs:(NSArray<CIImage*>*)mergeInputs
                              region:(CGRect)pixelRegion
                        filterRegion:(CGRect)filterRegion
                             context:(IJSVGFilterContext*)renderingContext
         preserveInnerShadowCoverage:(BOOL)preserveInnerShadowCoverage
{
    NSArray<IJSVGFilterPrimitive*>* primitives = self.filter.primitives;
    IJSVGFilterPrimitive* primitive = primitives[index];
    CIImage* output;
    if(!IJSVGFilterValidRect(pixelRegion)) {
        output = CIImage.emptyImage;
    } else {
        if(index == 1 && CGRectEqualToRect(filterRegion, CGRectIntegral(filterRegion)) &&
            CGRectEqualToRect(pixelRegion, CGRectIntegral(pixelRegion)) &&
            IJSVGFilterCanElideTransparentBlendAtIndex(index, primitives)) {
            output = input;
        } else if(preserveInnerShadowCoverage && index > 1 &&
            primitive.type == IJSVGNodeTypeFilterBlend) {
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
    return output;
}

- (CGRect)pixelRegionForPrimitive:(IJSVGFilterPrimitive*)primitive
                            input:(CIImage*)input
                            other:(CIImage*)other
                      mergeInputs:(NSArray<CIImage*>*)mergeInputs
                     filterRegion:(CGRect)filterRegion
{
    CGRect defaultRegion = input.extent;
    BOOL generator = primitive.type == IJSVGNodeTypeFilterFlood
        || primitive.type == IJSVGNodeTypeFilterTurbulence || primitive.type == IJSVGNodeTypeFilterImage
        || primitive.type == IJSVGNodeTypeFilterTile;
    if(generator) {
        defaultRegion = filterRegion;
    } else if(primitive.type == IJSVGNodeTypeFilterBlend || primitive.type == IJSVGNodeTypeFilterComposite ||
        primitive.type == IJSVGNodeTypeFilterDisplacementMap) {
        defaultRegion = CGRectUnion(defaultRegion, other.extent);
    }
    if(mergeInputs != nil) {
        defaultRegion = CGRectNull;
        for(CIImage* image in mergeInputs) {
            defaultRegion = CGRectUnion(defaultRegion, image.extent);
        }
    }
    // Empty inputs can still generate pixels through arithmetic or alpha transfer.
    if(!IJSVGFilterValidRect(defaultRegion)) {
        defaultRegion = filterRegion;
    }
    CGRect defaultUserRegion = CGRectApplyAffineTransform(defaultRegion,
                                                          CGAffineTransformInvert(self.imageTransform));
    CGRect primitiveRegion = [self regionForNode:primitive
                                           units:self.filter.contentUnits
                                   defaultRegion:defaultUserRegion];
    return CGRectApplyAffineTransform(primitiveRegion, self.imageTransform);
}

- (CIImage*)imageByFilteringSource:(CIImage*)source
{
    IJSVGFilterContext* renderingContext = [self renderingContext];
    CGRect userRegion = [self regionForNode:self.filter
                                      units:self.filter.units
                              defaultRegion:CGRectZero];
    CGRect filterRegion = CGRectApplyAffineTransform(userRegion, self.imageTransform);
    if(!IJSVGFilterValidRect(filterRegion)) {
        return CIImage.emptyImage;
    }
    source = [source imageByCroppingToRect:filterRegion];

    NSDictionary<NSString*, CIImage*>* sources = [self sourcesForImage:source
                                                                region:filterRegion
                                                               context:renderingContext];

    NSMutableDictionary<NSString*, CIImage*>* results = [[NSMutableDictionary alloc] init];
    NSArray<IJSVGFilterPrimitive*>* primitives = self.filter.primitives;
    BOOL preserveInnerShadowCoverage = self.filter.preservesInnerShadowCoverage;
    NSDictionary<NSString*, NSNumber*>* lastReferences = IJSVGFilterLastReferencesForPrimitives(primitives);

    NSDictionary<NSNumber*, NSArray<NSString*>*>* expiredNames = IJSVGFilterExpiredNamesForReferences(lastReferences);

    CIImage* output = source;
    for(NSUInteger index = 0; index < primitives.count; index++) {
        IJSVGFilterPrimitive* primitive = primitives[index];
        @autoreleasepool {
            renderingContext.linearRGB = IJSVGFilterUsesLinearRGB(primitive);
            // Recognized inner shadows keep RGB identically zero through the
            // hard alpha, offset, blur and subtract stages. Colour matching those
            // intermediates cannot change their pixels, only their graph cost.
            NSUInteger shadowStage = index >= 2 ? (index - 2) % 6 : NSNotFound;
            renderingContext.inputIsAlphaOnly = preserveInnerShadowCoverage && shadowStage <= 4;
            renderingContext.outputIsAlphaOnly = preserveInnerShadowCoverage && shadowStage <= 3;
            CIImage* input = IJSVGFilterInputNamed(primitive.input, output, sources, results);
            CIImage* other = IJSVGFilterInputNamed(primitive.input2, output, sources, results);
            NSArray<CIImage*>* mergeInputs = IJSVGFilterMergeInputsForPrimitive(primitive, output, sources, results);
            CGRect pixelRegion = [self pixelRegionForPrimitive:primitive
                                                         input:input
                                                         other:other
                                                   mergeInputs:mergeInputs
                                                  filterRegion:filterRegion];
            output = [self evaluatePrimitiveAtIndex:index
                                              input:input
                                              other:other
                                        mergeInputs:mergeInputs
                                             region:pixelRegion
                                       filterRegion:filterRegion
                                            context:renderingContext
                        preserveInnerShadowCoverage:preserveInnerShadowCoverage];
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

- (BOOL)populateShadowParameters:(IJSVGMetalShadowParameters*)parameters
                          region:(CGRect)region
                           units:(CGSize)units
{
    NSArray<IJSVGFilterPrimitive*>* primitives = self.filter.primitives;
    NSUInteger shadows = parameters->config.x;
    for(NSUInteger stage = 0; stage < shadows; stage++) {
        NSUInteger index = 2 + stage * 6;
        IJSVGFilterPrimitive* blur = primitives[index + 2];
        CGSize deviation = [blur pairForParameter:IJSVGAttributeStdDeviation
                                     defaultValue:CGSizeZero];
        CGFloat sigma = deviation.width * units.width;
        CGFloat dy = [primitives[index + 1] numberForParameter:IJSVGAttributeDY
                                                  defaultValue:0] * units.height;
        CGFloat dx = [primitives[index + 1] numberForParameter:IJSVGAttributeDX
                                                  defaultValue:0] * units.width;
        if(!isfinite(sigma) || sigma < .2 || sigma > 4 || !isfinite(deviation.height * units.height) ||
            fabs(sigma - deviation.height * units.height) > .00001 || !isfinite(dx) || !isfinite(dy) ||
            fabs(dx) >= region.size.width || fabs(dy) >= region.size.height ||
            blur.edgeMode != IJSVGFilterEdgeModeNone) {
            return NO;
        }
        NSData* weights = IJSVGSmallBlurWeights(sigma);
        if(weights == nil || weights.length > 32 * sizeof(float)) {
            return NO;
        }
        CGFloat gain = [primitives[index] numbersForParameter:IJSVGAttributeValues][18].doubleValue;
        if(gain > 65504) {
            return NO;
        }
        NSArray<NSNumber*>* tint = [primitives[index + 4] numbersForParameter:IJSVGAttributeValues];
        parameters->offsets[stage] = (simd_float4){dx, dy, gain, weights.length / sizeof(float)};
        parameters->tints[stage] = (simd_float4){tint[4].doubleValue, tint[9].doubleValue, tint[14].doubleValue, 1};
        memcpy(parameters->weights + stage * 32, weights.bytes, weights.length);
    }
    return YES;
}

- (IJSVGMetalShadowJob*)metalShadowJobForBitmap:(CGContextRef)bitmap
{
    NSUInteger width = CGBitmapContextGetWidth(bitmap), height = CGBitmapContextGetHeight(bitmap);
    if(width == 0 || height == 0 || width > 512 || height > 512 ||
        self.imageTransform.b != 0 || self.imageTransform.c != 0 ||
        self.imageTransform.a <= 0 || self.imageTransform.a != self.imageTransform.d ||
        !self.filter.preservesInnerShadowCoverage) {
        return nil;
    }
    NSArray<IJSVGFilterPrimitive*>* primitives = self.filter.primitives;
    NSUInteger shadows = (primitives.count - 2) / 6;
    if(shadows > 4) {
        return nil;
    }
    for(IJSVGFilterPrimitive* primitive in primitives) {
        if(IJSVGFilterUsesLinearRGB(primitive)) {
            return nil;
        }
    }
    CGRect region = CGRectApplyAffineTransform([self regionForNode:self.filter
                                                             units:self.filter.units
                                                     defaultRegion:CGRectZero],
                                               self.imageTransform);
    if(!IJSVGFilterValidRect(region)) {
        return nil;
    }
    CGSize units = self.filter.contentUnits == IJSVGUnitObjectBoundingBox
        ? CGSizeMake(self.boundingBox.size.width * self.imageTransform.a,
                     self.boundingBox.size.height * self.imageTransform.a)
        : CGSizeMake(self.imageTransform.a, self.imageTransform.a);
    IJSVGMetalShadowParameters parameters = {0};
    parameters.geometry = (simd_uint4){(uint32_t)width, (uint32_t)height, 0, 0};
    parameters.region = (simd_float4){CGRectGetMinX(region), CGRectGetMinY(region),
        CGRectGetMaxX(region), CGRectGetMaxY(region)};
    parameters.config.x = (uint32_t)shadows;
    if(![self populateShadowParameters:&parameters
                                region:region
                                 units:units]) {
        return nil;
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

- (BOOL)supportsDirectBlurPrimitives
{
    NSArray<IJSVGFilterPrimitive*>* primitives = self.filter.primitives;
    if(primitives.count != 1 && primitives.count != 3) {
        return NO;
    }
    IJSVGFilterPrimitive* blur = primitives.lastObject;
    if(blur.type != IJSVGNodeTypeFilterGaussianBlur ||
        (blur.input.length != 0 && !(primitives.count == 1 &&
        [blur.input isEqualToString:IJSVGStringSourceGraphic]))) {
        return NO;
    }
    if(primitives.count == 3) {
        IJSVGFilterPrimitive* flood = primitives[0];
        IJSVGFilterPrimitive* blend = primitives[1];
        NSSet* reserved = [NSSet setWithArray:@[
            IJSVGStringSourceGraphic, IJSVGStringSourceAlpha,
            IJSVGStringBackgroundImage, IJSVGStringBackgroundAlpha,
            IJSVGStringFillPaint, IJSVGStringStrokePaint
        ]];
        if(flood.type != IJSVGNodeTypeFilterFlood ||
            [flood numberForParameter:IJSVGAttributeFloodOpacity defaultValue:1] != 0 ||
            flood.result.length == 0 || [reserved containsObject:flood.result] ||
            blend.type != IJSVGNodeTypeFilterBlend ||
            ![blend.input isEqualToString:IJSVGStringSourceGraphic] ||
            ![blend.input2 isEqualToString:flood.result] ||
            blend.filterBlendMode != IJSVGBlendModeNormal) {
            return NO;
        }
    }
    for(IJSVGFilterPrimitive* primitive in primitives) {
        if((IJSVGFilterUsesLinearRGB(primitive) && primitives.count != 1) || primitive.x != nil ||
            primitive.y != nil ||
            primitive.width != nil || primitive.height != nil || primitive.children.count != 0) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)prepareBlurForBitmap:(CGContextRef)bitmap
                      region:(CGRect*)outRegion
                     weights:(NSData**)outWeights
                   linearRGB:(BOOL*)outLinearRGB
                 sourceCrops:(NSUInteger*)outSourceCrops
{
    NSUInteger width = CGBitmapContextGetWidth(bitmap), height = CGBitmapContextGetHeight(bitmap);
    if(width == 0 || height == 0 || width > 2048 || height > 2048 || width * height > 1048576 ||
        self.imageTransform.b != 0 || self.imageTransform.c != 0 ||
        self.imageTransform.a <= 0 || self.imageTransform.a != self.imageTransform.d) {
        return NO;
    }
    if(![self supportsDirectBlurPrimitives]) {
        return NO;
    }
    NSArray<IJSVGFilterPrimitive*>* primitives = self.filter.primitives;
    IJSVGFilterPrimitive* blur = primitives.lastObject;
    BOOL linearRGB = IJSVGFilterUsesLinearRGB(blur);
    CGSize units = self.filter.contentUnits == IJSVGUnitObjectBoundingBox
        ? CGSizeMake(
              self.boundingBox.size.width * self.imageTransform.a, self.boundingBox.size.height * self.imageTransform.a)
        : CGSizeMake(self.imageTransform.a, self.imageTransform.a);
    CGSize deviation = [blur pairForParameter:IJSVGAttributeStdDeviation
                                 defaultValue:CGSizeZero];
    CGFloat sigma = deviation.width * units.width;
    // Core Image can fuse crops for effectively identity blurs. Preserve its
    // fractional edge coverage by leaving those radii on the general path.
    if(!isfinite(sigma) || sigma < .2 || sigma > 12 || !isfinite(deviation.height * units.height) ||
        fabs(sigma - deviation.height * units.height) > .00001 ||
        blur.edgeMode != IJSVGFilterEdgeModeNone) {
        return NO;
    }
    CGRect region = CGRectApplyAffineTransform([self regionForNode:self.filter
                                                             units:self.filter.units
                                                     defaultRegion:CGRectZero],
                                               self.imageTransform);
    if(!IJSVGFilterValidRect(region)) {
        return NO;
    }
    NSData* weights = IJSVGSmallBlurWeights(sigma);
    if(weights == nil) {
        return NO;
    }
    *outRegion = region;
    *outWeights = weights;
    *outLinearRGB = linearRGB;
    *outSourceCrops = primitives.count == 3 ? 2 : 1;
    return YES;
}

- (IJSVGMetalBlurJob*)metalDropShadowJobForBitmap:(CGContextRef)bitmap
{
    // Direct shadow dispatch wins for icons; Core Image scales better for large surfaces.
    if(self.hasNestedFilters || CGBitmapContextGetWidth(bitmap) * CGBitmapContextGetHeight(bitmap) > 4096 ||
        self.filter.primitives.count != 1 || self.imageTransform.b != 0 || self.imageTransform.c != 0 ||
        self.imageTransform.a <= 0 || self.imageTransform.a != self.imageTransform.d) {
        return nil;
    }
    IJSVGFilterPrimitive* primitive = self.filter.primitives.firstObject;
    if(primitive.type != IJSVGNodeTypeFilterDropShadow || primitive.x != nil || primitive.y != nil ||
        primitive.width != nil || primitive.height != nil || primitive.children.count != 0 ||
        (primitive.input.length != 0 && ![primitive.input isEqualToString:IJSVGStringSourceGraphic])) {
        return nil;
    }
    CGRect region = CGRectApplyAffineTransform([self regionForNode:self.filter
                                                             units:self.filter.units
                                                     defaultRegion:CGRectZero],
                                               self.imageTransform);
    if(!IJSVGFilterValidRect(region)) {
        return nil;
    }
    CGSize units = self.filter.contentUnits == IJSVGUnitObjectBoundingBox
        ? CGSizeMake(
              self.boundingBox.size.width * self.imageTransform.a, self.boundingBox.size.height * self.imageTransform.a)
        : CGSizeMake(self.imageTransform.a, self.imageTransform.a);
    CGSize deviation = [primitive pairForParameter:IJSVGAttributeStdDeviation
                                      defaultValue:CGSizeMake(2, 2)];
    if(deviation.width < 0 || deviation.height < 0) {
        deviation = CGSizeMake(2, 2);
    }
    CGFloat sigma = deviation.width * units.width;
    CGFloat dx = [primitive numberForParameter:IJSVGAttributeDX defaultValue:2] * units.width;
    CGFloat dy = [primitive numberForParameter:IJSVGAttributeDY defaultValue:2] * units.height;
    if(!isfinite(sigma) || sigma < .5 || sigma > 12 ||
        !isfinite(deviation.height * units.height) ||
        fabs(sigma - deviation.height * units.height) > .00001 ||
        !isfinite(dx) || !isfinite(dy) || fabs(dx) >= region.size.width || fabs(dy) >= region.size.height) {
        return nil;
    }
    NSData* weights = IJSVGSmallBlurWeights(sigma);
    if(weights == nil) {
        return nil;
    }
    CGColorRef tint = IJSVGFilterNewShadowTintForPrimitive(primitive);
    if(tint == NULL) {
        return nil;
    }
    IJSVGMetalBlurJob* job = [IJSVGMetalBlurRenderer shadowJobForBitmap:bitmap
                                                                 region:region
                                                                weights:weights
                                                              linearRGB:IJSVGFilterUsesLinearRGB(primitive)
                                                                 offset:CGSizeMake(dx, dy)
                                                                  color:tint];
    CGColorRelease(tint);
    return job;
}

- (IJSVGMetalBlurJob*)metalBlurJobForBitmap:(CGContextRef)bitmap
{
    IJSVGMetalBlurJob* shadow = [self metalDropShadowJobForBitmap:bitmap];
    if(shadow != nil) {
        return shadow;
    }
    CGRect region;
    NSData* weights;
    BOOL linearRGB;
    NSUInteger sourceCrops;
    if(![self prepareBlurForBitmap:bitmap
                            region:&region
                           weights:&weights
                         linearRGB:&linearRGB
                       sourceCrops:&sourceCrops]) {
        return nil;
    }
    return [IJSVGMetalBlurRenderer jobForBitmap:bitmap
                                         region:region
                                        weights:weights
                                      linearRGB:linearRGB
                                    sourceCrops:sourceCrops];
}

- (CGImageRef)newCGImageForSmallBlur:(CGContextRef)bitmap
{
    IJSVGMetalBlurJob* shadow = [self metalDropShadowJobForBitmap:bitmap];
    if(shadow != nil && [IJSVGMetalBlurRenderer renderJobs:@[shadow]]) {
        return CGImageRetain(shadow.renderedImage);
    }
    CGRect region;
    NSData* weights;
    BOOL linearRGB;
    NSUInteger sourceCrops;
    if(![self prepareBlurForBitmap:bitmap
                            region:&region
                           weights:&weights
                         linearRGB:&linearRGB
                       sourceCrops:&sourceCrops]) {
        return NULL;
    }
    NSUInteger width = CGBitmapContextGetWidth(bitmap), height = CGBitmapContextGetHeight(bitmap);
    NSUInteger count = width * height;
    // CPU colour conversion dominates medium linearRGB surfaces. Measurements
    // favour Metal earlier there, except for the shortest convolution kernels.
    NSUInteger taps = weights.length / sizeof(float);
    NSUInteger cpuLimit = linearRGB && taps > 9 ? 2048 : 4096;
    if(count > cpuLimit) {
        CGImageRef image = [IJSVGMetalBlurRenderer newImageForBitmap:bitmap
                                                              region:region
                                                             weights:weights
                                                           linearRGB:linearRGB
                                                         sourceCrops:sourceCrops];
        if(image != NULL) {
            return image;
        }
    }
    if(width > 256 || height > 256) {
        return NULL;
    }
    NSData* source = IJSVGFilterBlurPixelsForBitmap(bitmap, region, linearRGB, sourceCrops);
    NSMutableData* output = [NSMutableData dataWithLength:source.length];
    if(!IJSVGFilterSIMDBlur(source.bytes, output.mutableBytes, width, height, 4, weights)) {
        return NULL;
    }
    return IJSVGFilterNewImageForBlurPixels(output, bitmap, region, linearRGB);
}

@end
