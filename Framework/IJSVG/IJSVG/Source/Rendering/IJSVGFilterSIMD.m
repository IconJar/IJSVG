//
//  IJSVGFilterSIMD.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

// Some algorithms in this file are adapted from or inspired by WebKit.

#import <IJSVGFilterSIMD.h>
#import <IJSVGFilterGraph.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVGColorMatrixFilterEffect.h>
#import <simd/simd.h>
#import <Accelerate/Accelerate.h>
#import <float.h>
#import <limits.h>

BOOL IJSVGFilterSIMDUsesBackdropAddition(IJSVGFilter* filter)
{
    if(filter.primitives.count != 1) {
        return NO;
    }
    IJSVGFilterPrimitive* primitive = filter.primitives.firstObject;
    return primitive.type == IJSVGNodeTypeFilterComposite
        && [primitive.input isEqualToString:IJSVGStringSourceGraphic]
        && [primitive.input2 isEqualToString:IJSVGStringBackgroundImage]
        && primitive.compositeOperator == IJSVGFilterCompositeOperatorArithmetic
        && [primitive numberForParameter:IJSVGAttributeK1 defaultValue:0] == 0
        && [primitive numberForParameter:IJSVGAttributeK2 defaultValue:0] == 1
        && [primitive numberForParameter:IJSVGAttributeK3 defaultValue:0] == 1
        && [primitive numberForParameter:IJSVGAttributeK4 defaultValue:0] == 0;
}

typedef NS_ENUM(NSUInteger, IJSVGSIMDCompositeOperation) {
    IJSVGSIMDCompositeUnsupported,
    IJSVGSIMDCompositeAddition,
    IJSVGSIMDCompositeLighter,
    IJSVGSIMDCompositeOver,
    IJSVGSIMDCompositeIn,
    IJSVGSIMDCompositeOut,
    IJSVGSIMDCompositeAtop,
    IJSVGSIMDCompositeXor,
    IJSVGSIMDCompositeMultiply,
    IJSVGSIMDCompositeScreen,
    IJSVGSIMDCompositeDarken,
    IJSVGSIMDCompositeLighten,
};

static IJSVGSIMDCompositeOperation IJSVGFilterSIMDOperation(IJSVGFilter* filter)
{
    if(filter.primitives.count != 1) {
        return IJSVGSIMDCompositeUnsupported;
    }
    IJSVGFilterPrimitive* primitive = filter.primitives.firstObject;
    if(![primitive.input isEqualToString:IJSVGStringSourceGraphic] ||
        ![primitive.input2 isEqualToString:IJSVGStringBackgroundImage]) {
        return IJSVGSIMDCompositeUnsupported;
    }
    if(primitive.type == IJSVGNodeTypeFilterBlend) {
        IJSVGBlendMode mode = primitive.filterBlendMode;
        if(mode == IJSVGBlendModeNormal) {
            return IJSVGSIMDCompositeOver;
        }
        if(mode == IJSVGBlendModeMultiply) {
            return IJSVGSIMDCompositeMultiply;
        }
        if(mode == IJSVGBlendModeScreen) {
            return IJSVGSIMDCompositeScreen;
        }
        if(mode == IJSVGBlendModeDarken) {
            return IJSVGSIMDCompositeDarken;
        }
        if(mode == IJSVGBlendModeLighten) {
            return IJSVGSIMDCompositeLighten;
        }
    } else if(primitive.type == IJSVGNodeTypeFilterComposite) {
        IJSVGFilterCompositeOperator op = primitive.compositeOperator;
        if(op == IJSVGFilterCompositeOperatorOver) {
            return IJSVGSIMDCompositeOver;
        }
        if(op == IJSVGFilterCompositeOperatorIn) {
            return IJSVGSIMDCompositeIn;
        }
        if(op == IJSVGFilterCompositeOperatorOut) {
            return IJSVGSIMDCompositeOut;
        }
        if(op == IJSVGFilterCompositeOperatorAtop) {
            return IJSVGSIMDCompositeAtop;
        }
        if(op == IJSVGFilterCompositeOperatorXor) {
            return IJSVGSIMDCompositeXor;
        }
        if(op == IJSVGFilterCompositeOperatorLighter) {
            return IJSVGSIMDCompositeLighter;
        }
        if(IJSVGFilterSIMDUsesBackdropAddition(filter)) {
            return IJSVGSIMDCompositeAddition;
        }
    }
    return IJSVGSIMDCompositeUnsupported;
}

static simd_float4 IJSVGCompositeApply(simd_float4 a, simd_float4 b,
                                     IJSVGSIMDCompositeOperation operation)
{
    switch(operation) {
        case IJSVGSIMDCompositeAddition:
        case IJSVGSIMDCompositeLighter:
            return a + b;
        case IJSVGSIMDCompositeOver:
            return a + b * (1.f - a.a);
        case IJSVGSIMDCompositeIn:
            return a * b.a;
        case IJSVGSIMDCompositeOut:
            return a * (1.f - b.a);
        case IJSVGSIMDCompositeAtop:
            return a * b.a + b * (1.f - a.a);
        case IJSVGSIMDCompositeXor:
            return a * (1.f - b.a) + b * (1.f - a.a);
        case IJSVGSIMDCompositeMultiply:
            return a * (1.f - b.a) + b * (1.f - a.a) + a * b;
        case IJSVGSIMDCompositeScreen:
            return a + b - a * b;
        case IJSVGSIMDCompositeDarken:
            return a * (1.f - b.a) + b * (1.f - a.a) + simd_min(a * b.a, b * a.a);
        case IJSVGSIMDCompositeLighten:
            return a * (1.f - b.a) + b * (1.f - a.a) + simd_max(a * b.a, b * a.a);
        case IJSVGSIMDCompositeUnsupported:
            return 0;
    }
}

// CPU arithmetic on small, renderer-owned surfaces avoids a GPU submission per
// primitive. Fractional placement retains Core Image's texture sampler.
static simd_float4 IJSVGCompositeDecode(simd_float4 value)
{
    if(value.a > 0.f) {
        for(NSUInteger channel = 0; channel < 3; channel++) {
            float straight = value[channel] / value.a;
            value[channel] = (straight <= .04045f ? straight / 12.92f
                : powf((straight + .055f) / 1.055f, 2.4f)) * value.a;
        }
    }
    return value;
}

static simd_float4 IJSVGCompositeEncode(simd_float4 value)
{
    if(value.a > 0.f) {
        for(NSUInteger channel = 0; channel < 3; channel++) {
            float straight = value[channel] / value.a;
            value[channel] = (straight <= .0031308f ? straight * 12.92f
                : 1.055f * powf(straight, 1.f / 2.4f) - .055f) * value.a;
        }
    }
    return value;
}

// Interpolate the transfer curve, but use the original expression near a
// final byte-rounding boundary. This avoids powf for ordinary pixels without
// accepting a different 8-bit result at the sensitive boundaries.
uint8_t IJSVGFilterSIMDEncodeLinearComponent(float component, float alpha,
                                             float coverage)
{
    if(alpha <= 0.f) {
        return 0;
    }
    static float table[16385];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for(NSUInteger index = 0; index <= 16384; index++) {
            float value = index / 16384.f;
            table[index] = value <= .0031308f ? value * 12.92f
                : 1.055f * powf(value, 1.f / 2.4f) - .055f;
        }
    });
    float straight = component / alpha;
    float encoded;
    if(straight <= .0031308f) {
        encoded = straight * 12.92f;
    } else {
        float position = fminf(1.f, straight) * 16384.f;
        NSUInteger index = MIN((NSUInteger)position, 16383u);
        float fraction = position - index;
        encoded = table[index] + (table[index + 1] - table[index]) * fraction;
    }
    float value = (encoded * alpha) * (coverage * 255.f);
    // The interpolation error on this grid is below .002 of an output byte,
    // including float arithmetic. Use a wider .01 guard around half integers.
    if(fabsf(value - floorf(value) - .5f) < .01f) {
        encoded = straight <= .0031308f ? straight * 12.92f
            : 1.055f * powf(straight, 1.f / 2.4f) - .055f;
        value = (encoded * alpha) * (coverage * 255.f);
    }
    return (uint8_t)lrintf(fminf(255.f, fmaxf(0.f, value)));
}

// RGBA8 has only 65,536 channel/alpha pairs. Retain the exact float
// conversion for each pair instead of evaluating transfer functions per pixel.
static const float* IJSVGCompositeDecodeTable(void)
{
    static float table[256 * 256];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for(NSUInteger alpha = 0; alpha < 256; alpha++) {
            for(NSUInteger channel = 0; channel < 256; channel++) {
                simd_float4 value = (simd_float4){channel, 0, 0, alpha} / 255.f;
                table[alpha * 256 + channel] = IJSVGCompositeDecode(value).r;
            }
        }
    });
    return table;
}

static simd_float4 IJSVGCompositeLoad(const uint8_t* pixel, const float* decodeTable)
{
    if(decodeTable != NULL) {
        const float* row = decodeTable + pixel[3] * 256;
        return (simd_float4){row[pixel[0]], row[pixel[1]], row[pixel[2]], pixel[3] / 255.f};
    }
    return (simd_float4){pixel[0], pixel[1], pixel[2], pixel[3]} / 255.f;
}

CGImageRef IJSVGFilterSIMDNewComposite(CGContextRef source, CGContextRef backdrop,
                                       IJSVGFilterGraph* graph, CGRect region)
{
    IJSVGSIMDCompositeOperation operation = IJSVGFilterSIMDOperation(graph.filter);
    if(operation == IJSVGSIMDCompositeUnsupported) {
        return NULL;
    }
    NSUInteger width = CGBitmapContextGetWidth(source);
    NSUInteger height = CGBitmapContextGetHeight(source);
    if(width == 0 || height == 0 || width > 128 || height > 128 || width * height > 4096) {
        return NULL;
    }
    IJSVGFilterPrimitive* primitive = graph.filter.primitives.firstObject;
    if(primitive.x != nil || primitive.y != nil || primitive.width != nil || primitive.height != nil) {
        return NULL;
    }
    BOOL linear = primitive.resolvedFilterColorInterpolation == IJSVGColorInterpolationLinearRGB;
    CGAffineTransform mapping = CGAffineTransformConcat(CGAffineTransformInvert(graph.imageTransform),
                                                        CGContextGetCTM(backdrop));
    if(!isfinite(mapping.a) || !isfinite(mapping.b) || !isfinite(mapping.c) ||
        !isfinite(mapping.d) || !isfinite(mapping.tx) || !isfinite(mapping.ty) ||
        fabs(mapping.tx) > INT_MAX || fabs(mapping.ty) > INT_MAX ||
        fabs(mapping.b) > 1e-9 || fabs(mapping.c) > 1e-9 ||
        fabs(fabs(mapping.a) - 1) > 1e-9 || fabs(fabs(mapping.d) - 1) > 1e-9 ||
        fabs(mapping.tx - round(mapping.tx)) > 1e-9 ||
        fabs(mapping.ty - round(mapping.ty)) > 1e-9) {
        return NULL;
    }
    CGRect crop = CGRectApplyAffineTransform(region, graph.imageTransform);
    if(!isfinite(crop.origin.x) || !isfinite(crop.origin.y) ||
        !isfinite(crop.size.width) || !isfinite(crop.size.height) || CGRectIsEmpty(crop)) {
        return NULL;
    }
  
    float minX = CGRectGetMinX(crop), maxX = CGRectGetMaxX(crop);
    float minY = CGRectGetMinY(crop), maxY = CGRectGetMaxY(crop);
    NSUInteger backdropWidth = CGBitmapContextGetWidth(backdrop);
    NSUInteger backdropHeight = CGBitmapContextGetHeight(backdrop);
    NSUInteger sourceStride = CGBitmapContextGetBytesPerRow(source);
    NSUInteger backdropStride = CGBitmapContextGetBytesPerRow(backdrop);
    const uint8_t* pixels = CGBitmapContextGetData(source);
    const uint8_t* background = CGBitmapContextGetData(backdrop);
    if(pixels == NULL || background == NULL) {
        return NULL;
    }
  
    // Leave SourceGraphic untouched: a rounding-sensitive pixel can abandon the
    // entire candidate and continue through the original graph.
    NSMutableData* output = [NSMutableData dataWithLength:width * height * 4];
    uint8_t* destination = output.mutableBytes;
  
    // Allow for transfer-function error and float crop coordinates. Grow the
    // margin with the surface size instead of penalizing every tiny primitive.
    float roundingMargin = .001f + MAX(width, height) * FLT_EPSILON * 512.f;
    const float* decodeTable = linear ? IJSVGCompositeDecodeTable() : NULL;
    NSInteger stepX = mapping.a > 0 ? 1 : -1;
    NSInteger stepY = mapping.d > 0 ? 1 : -1;
    NSInteger originX = llround(mapping.tx) + (stepX > 0 ? 0 : -1);
    NSInteger originY = llround(mapping.ty) + (stepY > 0 ? 0 : -1);
    for(NSUInteger y = 0; y < height; y++) {
        NSInteger by = (NSInteger)backdropHeight - 1
            - (originY + stepY * ((NSInteger)height - (NSInteger)y - 1));
        for(NSUInteger x = 0; x < width; x++) {
            float px = x, py = height - y - 1;
            // CI uses distance to the nearest crop edge, even when both edges
            // fall inside one pixel. Intersection area is incorrect in that case.
            float coverage = fmaxf(0, fminf(1, fminf(px + 1 - minX, maxX - px)))
                * fmaxf(0, fminf(1, fminf(py + 1 - minY, maxY - py)));
            if(coverage == 0) {
                continue;
            }
            NSInteger bx = originX + stepX * (NSInteger)x;
            const uint8_t* sourcePixel = pixels + y * sourceStride + x * 4;
            const uint8_t* backgroundPixel = NULL;
            if(bx >= 0 && bx < (NSInteger)backdropWidth &&
                by >= 0 && by < (NSInteger)backdropHeight) {
                backgroundPixel = background + by * backdropStride + bx * 4;
            }
            // Addition of transparent black is an identity. Avoid decoding and
            // re-encoding the unchanged pixel in the empty parts of a triangle.
            // Fractional crops still need both coverage applications below.
            if(operation == IJSVGSIMDCompositeAddition && coverage == 1.f &&
                sourcePixel[0] == 0 && sourcePixel[1] == 0 &&
                sourcePixel[2] == 0 && sourcePixel[3] == 0) {
                if(backgroundPixel != NULL) {
                    memcpy(destination + (y * width + x) * 4, backgroundPixel, 4);
                }
                continue;
            }
            simd_float4 b = backgroundPixel != NULL
                ? IJSVGCompositeLoad(backgroundPixel, decodeTable) : 0;
            simd_float4 a = IJSVGCompositeLoad(sourcePixel, decodeTable);
            simd_float4 value = IJSVGCompositeApply(a * coverage, b * coverage, operation);
            // Lighter preserves extended values through colour matching and the
            // final crop; arithmetic addition clamps before those operations.
            if(operation != IJSVGSIMDCompositeLighter) {
                value = simd_clamp(value, 0.f, 1.f);
                value = simd_min(value, (simd_float4)value.a);
            }
            if(linear && operation == IJSVGSIMDCompositeAddition) {
                for(NSUInteger channel = 0; channel < 3; channel++) {
                    destination[(y * width + x) * 4 + channel] =
                        IJSVGFilterSIMDEncodeLinearComponent(value[channel], value.a, coverage);
                }
                destination[(y * width + x) * 4 + 3] = (uint8_t)lrintf(value.a * (coverage * 255.f));
                continue;
            }
            if(linear) {
                value = IJSVGCompositeEncode(value);
            }
            value *= coverage * 255.f;
            for(NSUInteger channel = 0; channel < 4; channel++) {
                // Arithmetic addition stays on the CPU at rounding boundaries:
                // a GPU wait per triangle dominates dense meshes. Other modes
                // retain the exact-output fallback for sensitive pixels.
                float component = fminf(255.f, fmaxf(0.f, value[channel]));
                if(operation != IJSVGSIMDCompositeAddition &&
                    fabsf(component - floorf(component) - .5f) < roundingMargin) {
                    return NULL;
                }
                destination[(y * width + x) * 4 + channel] = (uint8_t)lrintf(component);
            }
        }
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)output);
    if(provider == NULL) {
        return NULL;
    }
    CGImageRef image = CGImageCreate(width, height, 8, 32, width * 4,
        CGBitmapContextGetColorSpace(source),
        (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big,
        provider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    return image;
}


// Local filters have no backdrop dependency and can also be collected by the
// batch renderer. Keep fractional crops on Core Image's texture sampler.
static BOOL IJSVGLocalFilterUsesLinearRGB(IJSVGFilterPrimitive* primitive)
{
    return primitive.resolvedFilterColorInterpolation == IJSVGColorInterpolationLinearRGB;
}

static CGImageRef IJSVGLocalFilterImage(CGContextRef source, NSData* pixels)
{
    NSUInteger width = CGBitmapContextGetWidth(source);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
    if(provider == NULL) {
        return NULL;
    }
    CGImageRef image = CGImageCreate(width, CGBitmapContextGetHeight(source), 8, 32,
        width * 4, CGBitmapContextGetColorSpace(source),
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big,
        provider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    return image;
}

static CGImageRef IJSVGLocalColorMatrix(CGContextRef source,
                                        IJSVGFilterPrimitive* primitive,
                                        CGRect crop)
{
    if(primitive.input.length != 0 &&
        ![primitive.input isEqualToString:IJSVGStringSourceGraphic]) {
        return NULL;
    }
    NSDictionary* prepared = [IJSVGColorMatrixFilterEffect preparedMatrixForPrimitive:primitive];
    NSData* coefficients = prepared[@"matrix"];
    if(coefficients.length != 20 * sizeof(double)) {
        return NULL;
    }
    const double* svgMatrix = coefficients.bytes;
    float matrix[16], bias[4];
    for(NSUInteger row = 0; row < 4; row++) {
        for(NSUInteger column = 0; column < 5; column++) {
            double value = svgMatrix[row * 5 + column];
            if(!isfinite(value) || fabs(value) > 16) {
                return NULL;
            }
            if(column == 4) {
                bias[row] = value;
            } else {
                // vImage multiplies row vectors; SVG stores output rows.
                matrix[column * 4 + row] = value;
            }
        }
    }
    NSUInteger width = CGBitmapContextGetWidth(source);
    NSUInteger height = CGBitmapContextGetHeight(source);
    NSUInteger stride = CGBitmapContextGetBytesPerRow(source);
    BOOL linear = ![prepared[@"opacityOnly"] boolValue] && IJSVGLocalFilterUsesLinearRGB(primitive);
    const float* decode = linear ? IJSVGCompositeDecodeTable() : NULL;
    NSMutableData* input = [NSMutableData dataWithLength:width * height * 4 * sizeof(float)];
    NSMutableData* output = [NSMutableData dataWithLength:input.length];
    simd_float4* values = input.mutableBytes;
    const uint8_t* pixels = CGBitmapContextGetData(source);
    for(NSUInteger y = 0; y < height; y++) {
        for(NSUInteger x = 0; x < width; x++) {
            if(CGRectContainsPoint(crop, CGPointMake(x + .5, height - y - .5))) {
                simd_float4 value = IJSVGCompositeLoad(pixels + y * stride + x * 4, decode);
                if(value.a > 0) {
                    value.rgb /= value.a;
                }
                values[y * width + x] = value;
            }
        }
    }
    vImage_Buffer src = {input.mutableBytes, height, width, width * 4 * sizeof(float)};
    vImage_Buffer dst = {output.mutableBytes, height, width, width * 4 * sizeof(float)};
    if(vImageMatrixMultiply_ARGBFFFF(&src, &dst, matrix, NULL, bias, kvImageDoNotTile) != kvImageNoError) {
        return NULL;
    }
    NSMutableData* bytes = [NSMutableData dataWithLength:width * height * 4];
    uint8_t* destination = bytes.mutableBytes;
    const simd_float4* result = output.bytes;
    for(NSUInteger y = 0; y < height; y++) {
        for(NSUInteger x = 0; x < width; x++) {
            if(!CGRectContainsPoint(crop, CGPointMake(x + .5, height - y - .5))) {
                continue;
            }
            NSUInteger index = y * width + x;
            simd_float4 value = simd_clamp(result[index], 0.f, 1.f);
            value.rgb *= value.a;
            for(NSUInteger channel = 0; channel < 4; channel++) {
                destination[index * 4 + channel] = linear && channel < 3
                    ? IJSVGFilterSIMDEncodeLinearComponent(value[channel], value.a, 1)
                    : (uint8_t)lrintf(value[channel] * 255.f);
            }
        }
    }
    return IJSVGLocalFilterImage(source, bytes);
}

static NSData* IJSVGLocalInput(NSString* name, NSData* previous, NSData* source,
                               NSData* alpha, NSString* resultName)
{
    if(name.length == 0) {
        return previous;
    }
    if([name isEqualToString:IJSVGStringSourceGraphic]) {
        return source;
    }
    if([name isEqualToString:IJSVGStringSourceAlpha]) {
        return alpha;
    }
    // Other reserved inputs must never resolve to a user result of that name.
    if([@[IJSVGStringBackgroundImage, IJSVGStringBackgroundAlpha,
           IJSVGStringFillPaint, IJSVGStringStrokePaint] containsObject:name]) {
        return nil;
    }
    return [name isEqualToString:resultName] ? previous : nil;
}

CGImageRef IJSVGFilterSIMDNewLocalFilter(CGContextRef source,
                                         IJSVGFilterGraph* graph, CGRect region)
{
    // Most artwork does not use these recipes. Inspect the existing child
    // array before building the primitive list or allocating intermediates.
    NSArray<IJSVGNode*>* children = graph.filter.children;
    IJSVGNodeType lastType = children.lastObject.type;
    if(children.count == 0 || children.count > 2 ||
        (lastType != IJSVGNodeTypeFilterColorMatrix && lastType != IJSVGNodeTypeFilterComposite)) {
        return NULL;
    }
    NSArray<IJSVGFilterPrimitive*>* primitives = graph.filter.primitives;
    NSUInteger width = CGBitmapContextGetWidth(source);
    NSUInteger height = CGBitmapContextGetHeight(source);
    if(primitives.count == 0 || primitives.count > 2 || width == 0 || height == 0 ||
        width > 256 || height > 256 || width * height > 4096 ||
        CGBitmapContextGetData(source) == NULL || graph.hasNestedFilters) {
        return NULL;
    }
    IJSVGFilterPrimitive* last = primitives.lastObject;
    BOOL colorMatrix = primitives.count == 1 && last.type == IJSVGNodeTypeFilterColorMatrix;
    if(!colorMatrix && (last.type != IJSVGNodeTypeFilterComposite ||
        IJSVGLocalFilterUsesLinearRGB(last))) {
        return NULL;
    }
    // A backdrop filter is already handled by the dedicated composite path.
    // Reject it before any local intermediate allocation.
    if([last.input isEqualToString:IJSVGStringBackgroundImage] ||
        [last.input2 isEqualToString:IJSVGStringBackgroundImage] ||
        [last.input isEqualToString:IJSVGStringBackgroundAlpha] ||
        [last.input2 isEqualToString:IJSVGStringBackgroundAlpha]) {
        return NULL;
    }
    CGRect crop = CGRectApplyAffineTransform(region, graph.imageTransform);
    if(!isfinite(crop.origin.x) || !isfinite(crop.origin.y) ||
        !isfinite(crop.size.width) || !isfinite(crop.size.height) ||
        CGRectIsEmpty(crop) || !CGRectEqualToRect(crop, CGRectIntegral(crop))) {
        return NULL;
    }
    for(IJSVGFilterPrimitive* primitive in primitives) {
        if(primitive.x != nil || primitive.y != nil || primitive.width != nil || primitive.height != nil) {
            return NULL;
        }
    }
    if(colorMatrix) {
        return IJSVGLocalColorMatrix(source, last, crop);
    }
    IJSVGFilterCompositeOperator operation = last.compositeOperator;
    if(operation > IJSVGFilterCompositeOperatorXor) {
        return NULL;
    }
    static const CGBlendMode modes[] = {kCGBlendModeNormal, kCGBlendModeSourceIn,
        kCGBlendModeSourceOut, kCGBlendModeSourceAtop, kCGBlendModeXOR};
    NSInteger dx = 0, dy = 0;
    IJSVGFilterPrimitive* offset = primitives.count == 2 ? primitives.firstObject : nil;
    if(offset != nil) {
        if(offset.type != IJSVGNodeTypeFilterOffset ||
            graph.filter.contentUnits != IJSVGUnitUserSpaceOnUse ||
            graph.imageTransform.b != 0 || graph.imageTransform.c != 0) {
            return NULL;
        }
        double x = [offset numberForParameter:IJSVGAttributeDX
                                 defaultValue:0] * graph.imageTransform.a;
        double y = [offset numberForParameter:IJSVGAttributeDY
                                 defaultValue:0] * graph.imageTransform.d;
        if(!isfinite(x) || !isfinite(y) || fabs(x) > INT_MAX || fabs(y) > INT_MAX ||
            x != round(x) || y != round(y)) {
            return NULL;
        }
        dx = (NSInteger)x;
        dy = (NSInteger)y;
    }
    NSMutableData* graphic = [NSMutableData dataWithLength:width * height * 4];
    NSMutableData* alpha = [NSMutableData dataWithLength:graphic.length];
    uint8_t* graphicBytes = graphic.mutableBytes;
    uint8_t* alphaBytes = alpha.mutableBytes;
    const uint8_t* original = CGBitmapContextGetData(source);
    NSUInteger stride = CGBitmapContextGetBytesPerRow(source);
    for(NSUInteger y = 0; y < height; y++) {
        for(NSUInteger x = 0; x < width; x++) {
            if(CGRectContainsPoint(crop, CGPointMake(x + .5, height - y - .5))) {
                NSUInteger index = (y * width + x) * 4;
                memcpy(graphicBytes + index, original + y * stride + x * 4, 4);
                alphaBytes[index + 3] = graphicBytes[index + 3];
            }
        }
    }
    NSData* previous = graphic;
    if(offset != nil) {
        NSData* input = IJSVGLocalInput(offset.input, graphic, graphic, alpha, nil);
        if(input == nil) {
            return NULL;
        }
        NSMutableData* shifted = [NSMutableData dataWithLength:graphic.length];
        uint8_t* shiftedBytes = shifted.mutableBytes;
        const uint8_t* inputBytes = input.bytes;
        for(NSInteger y = 0; y < (NSInteger)height; y++) {
            for(NSInteger x = 0; x < (NSInteger)width; x++) {
                NSInteger sx = x - dx, sy = y + dy;
                if(sx >= 0 && sx < (NSInteger)width && sy >= 0 && sy < (NSInteger)height &&
                    CGRectContainsPoint(crop, CGPointMake(x + .5, height - y - .5))) {
                    memcpy(shiftedBytes + (y * width + x) * 4,
                           inputBytes + (sy * width + sx) * 4, 4);
                }
            }
        }
        previous = shifted;
    }
    NSData* first = IJSVGLocalInput(last.input, previous, graphic, alpha, offset.result);
    NSData* second = IJSVGLocalInput(last.input2, previous, graphic, alpha, offset.result);
    if(first == nil || second == nil) {
        return NULL;
    }
    CGImageRef foreground = IJSVGLocalFilterImage(source, first);
    CGContextRef destination = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
        CGBitmapContextGetColorSpace(source), kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    if(foreground == NULL || destination == NULL) {
        if(foreground != NULL) {
            CGImageRelease(foreground);
        }
        if(destination != NULL) {
            CGContextRelease(destination);
        }
        return NULL;
    }
    memcpy(CGBitmapContextGetData(destination), second.bytes, second.length);
    CGContextSetInterpolationQuality(destination, kCGInterpolationNone);
    CGContextSetBlendMode(destination, modes[operation]);
    CGContextDrawImage(destination, CGRectMake(0, 0, width, height), foreground);
    CGImageRef image = CGBitmapContextCreateImage(destination);
    CGImageRelease(foreground);
    CGContextRelease(destination);
    return image;
}

// Keep RGBA interleaved for short kernels so Accelerate can process channels
// together without four planar copies. Wider kernels retain its separable path.
static BOOL IJSVGSmallInterleavedBlur(const float* source, float* output,
                                      NSUInteger width, NSUInteger height,
                                      const float* weights, NSUInteger taps)
{
    NSMutableData* temporary = [NSMutableData dataWithLength:width * height * 4 * sizeof(float)];
    vImage_Buffer input = { (void*)source, height, width, width * 4 * sizeof(float) };
    vImage_Buffer intermediate = { temporary.mutableBytes, height, width, width * 4 * sizeof(float) };
    vImage_Buffer destination = { output, height, width, width * 4 * sizeof(float) };
    Pixel_FFFF background = { 0, 0, 0, 0 };
    vImage_Flags flags = kvImageBackgroundColorFill | kvImageDoNotTile;
    vImage_Error horizontalSize = vImageConvolve_ARGBFFFF(&input, &intermediate,
        NULL, 0, 0, weights, 1, (uint32_t)taps, background, flags | kvImageGetTempBufferSize);
    vImage_Error verticalSize = vImageConvolve_ARGBFFFF(&intermediate, &destination,
        NULL, 0, 0, weights, (uint32_t)taps, 1, background, flags | kvImageGetTempBufferSize);
    if(horizontalSize < 0 || verticalSize < 0) {
        return NO;
    }
    NSMutableData* workspace = [NSMutableData dataWithLength:MAX(horizontalSize, verticalSize)];
    if(vImageConvolve_ARGBFFFF(&input, &intermediate, workspace.mutableBytes,
        0, 0, weights, 1, (uint32_t)taps, background, flags) != kvImageNoError) {
        return NO;
    }
    return vImageConvolve_ARGBFFFF(&intermediate, &destination, workspace.mutableBytes,
        0, 0, weights, (uint32_t)taps, 1, background, flags) == kvImageNoError;
}

// Each running sum feeds the next box immediately. Only trailing samples live
// in the rings, so the intermediate halo needs no full-size padded images.
static void IJSVGFilterSIMDBoxLine(const simd_float4* source, simd_float4* output,
                                  NSUInteger count, NSUInteger stride,
                                  const NSUInteger sides[3], simd_float4* rings)
{
    NSUInteger offsets[3] = {0, sides[0], sides[0] + sides[1]};
    memset(rings, 0, (sides[0] + sides[1] + sides[2]) * sizeof(simd_float4));
    simd_float4 sums[3] = {0, 0, 0};
    NSUInteger positions[3] = {0, 0, 0};
    NSUInteger delay = sides[0] / 2 + sides[1] / 2 + sides[2] / 2;
    float reciprocals[3] = {1.f / sides[0], 1.f / sides[1], 1.f / sides[2]};
    for(NSUInteger i = 0; i < count + delay; i++) {
        simd_float4 value = i < count ? source[i * stride] : 0;
        for(NSUInteger stage = 0; stage < 3; stage++) {
            simd_float4* old = rings + offsets[stage] + positions[stage];
            sums[stage] += value - *old;
            *old = value;
            value = sums[stage] * reciprocals[stage];
            if(++positions[stage] == sides[stage]) {
                positions[stage] = 0;
            }
        }
        if(i >= delay) {
            output[(i - delay) * stride] = simd_clamp(value, 0.f, 1.f);
        }
    }
}

BOOL IJSVGFilterSIMDThreeBoxBlur(const float* source, float* output,
                                NSUInteger width, NSUInteger height,
                                const NSUInteger sides[3])
{
    if(source == NULL || output == NULL || source == output || sides == NULL ||
        ((uintptr_t)source & 15) != 0 || ((uintptr_t)output & 15) != 0 ||
        width == 0 || height == 0 || width > 4096 || height > 4096 ||
        width * height > 4194304) {
        return NO;
    }
    for(NSUInteger stage = 0; stage < 3; stage++) {
        if(sides[stage] == 0 || sides[stage] > 501 || sides[stage] % 2 == 0) {
            return NO;
        }
    }
    NSMutableData* temporary = [NSMutableData dataWithLength:width * height * sizeof(simd_float4)];
    NSMutableData* scratch = [NSMutableData dataWithLength:
        (sides[0] + sides[1] + sides[2]) * sizeof(simd_float4)];
    simd_float4* intermediate = temporary.mutableBytes;
    for(NSUInteger y = 0; y < height; y++) {
        IJSVGFilterSIMDBoxLine((const simd_float4*)source + y * width,
            intermediate + y * width, width, 1, sides, scratch.mutableBytes);
    }
    for(NSUInteger x = 0; x < width; x++) {
        IJSVGFilterSIMDBoxLine(intermediate + x, (simd_float4*)output + x,
            height, width, sides, scratch.mutableBytes);
    }
    return YES;
}

// Approximate wide Gaussian kernels with three variance-matched box passes.
// Box convolution avoids evaluating every Gaussian tap at every pixel.
// Narrow kernels retain convolution for their profile and lower setup cost.
static BOOL IJSVGThreeBoxBlur(const float* source, float* output,
                              NSUInteger width, NSUInteger height, NSData* weights)
{
    if(width * height < 512) {
        return NO;
    }
    NSUInteger taps = weights.length / sizeof(float);
    const float* kernel = weights.bytes;
    double variance = 0;
    for(NSUInteger i = 0; i < taps; i++) {
        double distance = (double)i - (double)(taps / 2);
        variance += kernel[i] * distance * distance;
    }
    if(variance < 64) {
        return NO;
    }
    NSUInteger lower = (NSUInteger)floor(sqrt(4 * variance + 1));
    if(lower % 2 == 0) {
        lower--;
    }
    NSInteger lowerPasses = lround((12 * variance - 3 * lower * lower - 12 * lower - 9)
        / (-4. * lower - 4));
    lowerPasses = MAX(0, MIN(3, lowerPasses));
    // Retain the full halo between passes. Cropping each pass to the final
    // output would discard samples that later passes bring back into view.
    NSUInteger padding = 3 * (lower + 1) / 2;
    NSUInteger paddedWidth = width + 2 * padding, paddedHeight = height + 2 * padding;
    // A huge blur around a tiny source spends more time on its halo than a
    // direct convolution spends on the source. Keep those cases on convolution.
    if(paddedWidth * paddedHeight > width * height * 16) {
        return NO;
    }
#if defined(__OPTIMIZE__)
    // The fused loop wins with optimized code generation; Accelerate remains
    // faster in unoptimized builds. Both retain the same box widths and halo.
    NSUInteger sides[3];
    for(NSUInteger stage = 0; stage < 3; stage++) {
        sides[stage] = stage < lowerPasses ? lower : lower + 2;
    }
    // Larger images benefit when the compiler optimizes for speed.
#if defined(__OPTIMIZE_SIZE__)
    NSUInteger maximumPixels = 4096;
#else
    NSUInteger maximumPixels = 16384;
#endif
    BOOL useFusedBlur = width * height <= 4096 ||
        (width <= 128 && height <= 128 && width * height <= maximumPixels);
    if(useFusedBlur && IJSVGFilterSIMDThreeBoxBlur(source, output, width, height, sides)) {
        return YES;
    }
#endif
    NSUInteger offset = (padding * paddedWidth + padding) * 4;
    NSMutableData* first = [NSMutableData dataWithLength:paddedWidth * paddedHeight * 4];
    NSMutableData* second = [NSMutableData dataWithLength:first.length];
    vImage_Buffer floats = { (void*)source, height, width * 4, width * 4 * sizeof(float) };
    vImage_Buffer bytes = { (uint8_t*)first.mutableBytes + offset, height, width * 4, paddedWidth * 4 };
    if(vImageConvert_PlanarFtoPlanar8(&floats, &bytes, 1, 0, kvImageDoNotTile) != kvImageNoError) {
        return NO;
    }
    vImage_Buffer a = { first.mutableBytes, paddedHeight, paddedWidth, paddedWidth * 4 };
    vImage_Buffer b = { second.mutableBytes, paddedHeight, paddedWidth, paddedWidth * 4 };
    Pixel_8888 transparent = { 0, 0, 0, 0 };
    vImage_Flags flags = kvImageBackgroundColorFill | kvImageDoNotTile;
    vImage_Error lowerSize = vImageBoxConvolve_ARGB8888(&a, &b, NULL, 0, 0,
        (uint32_t)lower, (uint32_t)lower, transparent, flags | kvImageGetTempBufferSize);
    vImage_Error upperSize = vImageBoxConvolve_ARGB8888(&a, &b, NULL, 0, 0,
        (uint32_t)(lower + 2), (uint32_t)(lower + 2), transparent, flags | kvImageGetTempBufferSize);
    if(lowerSize < 0 || upperSize < 0) {
        return NO;
    }
    NSMutableData* scratch = [NSMutableData dataWithLength:(NSUInteger)MAX(lowerSize, upperSize)];
    for(NSUInteger pass = 0; pass < 3; pass++) {
        uint32_t side = (uint32_t)(pass < lowerPasses ? lower : lower + 2);
        if(vImageBoxConvolve_ARGB8888(&a, &b, scratch.mutableBytes, 0, 0,
            side, side, transparent, flags) != kvImageNoError) {
            return NO;
        }
        vImage_Buffer swap = a;
        a = b;
        b = swap;
    }
    a.data = (uint8_t*)a.data + offset;
    a.width = width * 4;
    a.height = height;
    floats.data = output;
    return vImageConvert_Planar8toPlanarF(&a, &floats, 1, 0, kvImageDoNotTile) == kvImageNoError;
}

BOOL IJSVGFilterSIMDBlur(const float* source, float* output, NSUInteger width,
                          NSUInteger height, NSUInteger channels, NSData* weights)
{
    NSUInteger count = width * height;
    NSUInteger taps = weights.length / sizeof(float);
    if(taps == 1) {
        memcpy(output, source, count * channels * sizeof(float));
        return YES;
    }
    if(channels == 4 && taps > 9 && IJSVGThreeBoxBlur(source, output, width, height, weights)) {
        return YES;
    }
    if(channels == 4 && taps <= 9 &&
        IJSVGSmallInterleavedBlur(source, output, width, height, weights.bytes, taps)) {
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

