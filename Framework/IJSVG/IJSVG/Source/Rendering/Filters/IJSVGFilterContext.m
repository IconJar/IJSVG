//
//  IJSVGFilterContext.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterContext.h>

// Read shader text from the framework or Swift package resource bundle.
NSString* IJSVGFilterShaderSource(NSString* name)
{
#if SWIFT_PACKAGE
    NSBundle* bundle = SWIFTPM_MODULE_BUNDLE;
#else
    NSBundle* bundle = [NSBundle bundleForClass:IJSVGFilterContext.class];
#endif
    NSURL* sourceURL = [bundle URLForResource:name
                                withExtension:@"metal"];
    return sourceURL != nil ? [NSString stringWithContentsOfURL:sourceURL
                                                      encoding:NSUTF8StringEncoding
                                                         error:NULL] : nil;
}

float IJSVGFilterClamp(double value)
{
    return isfinite(value) ? fmin(1., fmax(0., value)) : 0.f;
}

BOOL IJSVGFilterValidRect(CGRect rect)
{
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height) &&
        !CGRectIsEmpty(rect);
}

// Find the pixel limits once so each sample can reuse them.
IJSVGFilterSampler IJSVGFilterSamplerMake(const float* pixels, NSInteger width, NSInteger height,
    CGRect region, NSInteger edgeMode)
{
    IJSVGFilterSampler sampler = { .pixels = pixels, .width = width, .right = -1, .bottom = -1, .edgeMode = edgeMode };
    if(CGRectIsEmpty(region)) {
        return sampler;
    }
    CGFloat left = MAX(0, floor(CGRectGetMinX(region)));
    CGFloat top = MAX(0, floor(CGRectGetMinY(region)));
    CGFloat right = MIN(width, ceil(CGRectGetMaxX(region))) - 1;
    CGFloat bottom = MIN(height, ceil(CGRectGetMaxY(region))) - 1;
    if(!isfinite(left) || !isfinite(top) || !isfinite(right) || !isfinite(bottom) || right < left ||
        bottom < top) {
        return sampler;
    }
    sampler.left = left;
    sampler.top = top;
    sampler.right = right;
    sampler.bottom = bottom;
    return sampler;
}

static BOOL IJSVGFilterSampleCoordinates(const IJSVGFilterSampler* sampler, CGFloat x, CGFloat y,
    NSInteger xs[2], NSInteger ys[2], double weightsX[2], double weightsY[2])
{
    if(!isfinite(x) || !isfinite(y) || sampler->right < sampler->left || sampler->bottom < sampler->top) {
        return NO;
    }
    NSInteger left = sampler->left, top = sampler->top;
    NSInteger right = sampler->right, bottom = sampler->bottom;
    NSInteger width = right - left + 1, height = bottom - top + 1;
    if(sampler->edgeMode == 1) {
        x = MIN(right, MAX(left, x));
        y = MIN(bottom, MAX(top, y));
    } else if(sampler->edgeMode == 2) {
        // Only wrap coordinates that fall outside the image.
        if(x < left || x > right) {
            x = left + fmod(fmod(x - left, width) + width, width);
        }
        if(y < top || y > bottom) {
            y = top + fmod(fmod(y - top, height) + height, height);
        }
    } else if(x < left - 1. || x >= right + 1. || y < top - 1. || y >= bottom + 1.) {
        // Reject distant samples before turning their positions into array indexes.
        return NO;
    }
    xs[0] = floor(x);
    ys[0] = floor(y);
    xs[1] = xs[0] + 1;
    ys[1] = ys[0] + 1;
    weightsX[1] = x - xs[0];
    weightsY[1] = y - ys[0];
    weightsX[0] = 1. - weightsX[1];
    weightsY[0] = 1. - weightsY[1];
    for(NSUInteger i = 0; i < 2; i++) {
        if(sampler->edgeMode == 1) {
            xs[i] = MIN(right, MAX(left, xs[i]));
            ys[i] = MIN(bottom, MAX(top, ys[i]));
        } else if(sampler->edgeMode == 2) {
            // Only the next pixel can cross the edge after wrapping.
            xs[i] = xs[i] > right ? xs[i] - width : xs[i];
            ys[i] = ys[i] > bottom ? ys[i] - height : ys[i];
        }
    }
    return YES;
}

// Blend nearby pixels to sample a position between pixel centers.
float IJSVGFilterSamplerValue(const IJSVGFilterSampler* sampler, CGFloat x, CGFloat y, NSUInteger channel)
{
    NSInteger xs[2], ys[2];
    double weightsX[2], weightsY[2];
    if(!IJSVGFilterSampleCoordinates(sampler, x, y, xs, ys, weightsX, weightsY)) {
        return 0.f;
    }
    double value = 0.;
    for(NSUInteger j = 0; j < 2; j++) {
        for(NSUInteger i = 0; i < 2; i++) {
            if(xs[i] < sampler->left || xs[i] > sampler->right || ys[j] < sampler->top ||
                ys[j] > sampler->bottom) {
                continue;
            }
            value += sampler->pixels[(ys[j] * sampler->width + xs[i]) * 4 + channel] * weightsX[i] * weightsY[j];
        }
    }
    return value;
}

// Reuse the same sample positions for all four channels.
void IJSVGFilterSamplerPixel(const IJSVGFilterSampler* sampler, CGFloat x, CGFloat y, float pixel[4])
{
    double values[4] = { 0 };
    NSInteger xs[2], ys[2];
    double weightsX[2], weightsY[2];
    if(IJSVGFilterSampleCoordinates(sampler, x, y, xs, ys, weightsX, weightsY)) {
        for(NSUInteger j = 0; j < 2; j++) {
            for(NSUInteger i = 0; i < 2; i++) {
                if(xs[i] < sampler->left || xs[i] > sampler->right || ys[j] < sampler->top ||
                    ys[j] > sampler->bottom) {
                    continue;
                }
                const float* source = sampler->pixels + (ys[j] * sampler->width + xs[i]) * 4;
                for(NSUInteger c = 0; c < 4; c++) {
                    values[c] += source[c] * weightsX[i] * weightsY[j];
                }
            }
        }
    }
    for(NSUInteger c = 0; c < 4; c++) {
        pixel[c] = values[c];
    }
}

float IJSVGFilterSample(const float* pixels, NSInteger width, NSInteger height, CGFloat x, CGFloat y,
    NSUInteger channel, CGRect region, NSInteger edgeMode)
{
    IJSVGFilterSampler sampler = IJSVGFilterSamplerMake(pixels, width, height, region, edgeMode);
    return IJSVGFilterSamplerValue(&sampler, x, y, channel);
}


void IJSVGFilterApplyRows(NSInteger width, NSInteger height, void (^operation)(NSInteger, NSInteger))
{
    // Process small images directly.
    // Split larger images into rows that can run at the same time.
    if(width * height < 65536 || height < 2) {
        operation(0, height);
        return;
    }
    // Use smaller groups of rows for short images so more workers can help.
    const NSInteger rowsPerBand = height < 128 ? MAX(1, height / 8) : 32;
    size_t bands = (height + rowsPerBand - 1) / rowsPerBand;
    dispatch_apply(bands, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t band) {
        NSInteger first = band * rowsPerBand;
        @autoreleasepool {
            operation(first, MIN(height, first + rowsPerBand));
        }
    });
}

@implementation IJSVGFilterContext

- (CGSize)pixelUnits
{
    CGFloat scale = self.imageTransform.a;
    return self.filter.contentUnits == IJSVGUnitObjectBoundingBox
        ? CGSizeMake(self.boundingBox.size.width * scale, self.boundingBox.size.height * scale)
        : CGSizeMake(scale, scale);
}

- (NSMutableData*)pixelsForImage:(CIImage*)image
{
    return [self pixelsForImage:image bounds:self.extent];
}

- (NSMutableData*)pixelsForImage:(CIImage*)image bounds:(CGRect)bounds
{
    size_t width = bounds.size.width, height = bounds.size.height;
    NSMutableData* data = [NSMutableData dataWithLength:width * height * 4 * sizeof(float)];
    CGColorSpaceRef space = CGColorSpaceCreateWithName(self.linearRGB ? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
    // Flip the image so the CPU receives rows in the expected order.
    CGFloat flipY = CGRectGetMinY(bounds) + CGRectGetMaxY(bounds);
    image = [image imageByApplyingTransform:CGAffineTransformMake(1.f, 0.f, 0.f, -1.f, 0.f, flipY)];
    [self.context render:image
                toBitmap:data.mutableBytes
                rowBytes:width * 4 * sizeof(float)
                  bounds:bounds
                  format:kCIFormatRGBAf
              colorSpace:space];
    CGColorSpaceRelease(space);
    return data;
}

- (CIImage*)imageForPixels:(NSData*)pixels
{
    return [self imageForPixels:pixels
                         bounds:self.extent];
}

- (CIImage*)imageForPixels:(NSData*)pixels
                    bounds:(CGRect)bounds
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(self.linearRGB ? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
    CIImage* image = [CIImage imageWithBitmapData:pixels
                                      bytesPerRow:bounds.size.width * 4 * sizeof(float)
                                             size:bounds.size
                                           format:kCIFormatRGBAf
                                       colorSpace:space];
    CGColorSpaceRelease(space);
    // Restore the image position without copying the pixels.
    return [image imageByApplyingTransform:CGAffineTransformMake(1.f, 0.f, 0.f, -1.f,
                                                                 bounds.origin.x,
                                                                 CGRectGetMaxY(bounds))];
}

// Read pixels only when Core Image cannot perform the effect.
- (CIImage*)mapImage:(CIImage*)image
               other:(CIImage*)other
           operation:(void (^)(const float*, const float*, float*, NSInteger, NSInteger))operation
{
    return [self mapImage:image
                    other:other
                   region:self.extent
                operation:operation];
}

- (CIImage*)mapImage:(CIImage*)image
               other:(CIImage*)other
              region:(CGRect)region
           operation:(void (^)(const float*, const float*, float*, NSInteger, NSInteger))operation
{
    if(!IJSVGFilterValidRect(region)) {
        return CIImage.emptyImage;
    }
    // Keep whole pixels here. The graph applies the exact fractional crop later.
    CGRect bounds = CGRectIntersection(CGRectIntegral(region), self.extent);
    if(!IJSVGFilterValidRect(bounds)) {
        return CIImage.emptyImage;
    }
    NSData* first = [self pixelsForImage:image
                                  bounds:bounds];
    NSData* second = other == image ? first : (other == nil ? nil : [self pixelsForImage:other
                                                                                  bounds:bounds]);
    NSMutableData* output = [NSMutableData dataWithLength:first.length];
    operation(first.bytes, second.bytes, output.mutableBytes, bounds.size.width,
              bounds.size.height);
    return [self imageForPixels:output
                         bounds:bounds];
}

// Convert colors through Core Image without reading pixels back to the CPU.

- (CIImage*)imageInPrimitiveColorSpace:(CIImage*)image
{
    if(self.inputIsAlphaOnly) {
        return image;
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(self.linearRGB ? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
    CIImage* result = [image imageByColorMatchingWorkingSpaceToColorSpace:space];
    CGColorSpaceRelease(space);
    return result;
}

- (CIImage*)imageFromPrimitiveColorSpace:(CIImage*)image
{
    if(self.outputIsAlphaOnly) {
        return image;
    }
    CGColorSpaceRef space = CGColorSpaceCreateWithName(self.linearRGB ? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
    CIImage* result = [image imageByColorMatchingColorSpaceToWorkingSpace:space];
    CGColorSpaceRelease(space);
    return result;
}

- (CIImage*)applyFilter:(NSString*)name
                toImage:(CIImage*)image
             parameters:(NSDictionary*)parameters
{
    CIImage* result = [[self imageInPrimitiveColorSpace:image] imageByApplyingFilter:name
                                                                 withInputParameters:parameters];
    return [self imageFromPrimitiveColorSpace:result];
}

- (CIImage*)alphaForImage:(CIImage*)image
{
    return [image imageByApplyingFilter:@"CIColorMatrix"
                    withInputParameters:@{
        @"inputRVector": [CIVector vectorWithX:0 Y:0 Z:0 W:0],
        @"inputGVector": [CIVector vectorWithX:0 Y:0 Z:0 W:0],
        @"inputBVector": [CIVector vectorWithX:0 Y:0 Z:0 W:0]
    }];
}

- (CIImage*)offsetImage:(CIImage*)input
                     dx:(CGFloat)dx
                     dy:(CGFloat)dy
{
    CGSize units = self.pixelUnits;
    return [input imageByApplyingTransform:CGAffineTransformMakeTranslation(dx * units.width, dy * units.height)];
}

- (CIImage*)floodWithColor:(NSColor*)color
                   opacity:(CGFloat)opacity
{
    color = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] ?: NSColor.blackColor;
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CIColor* ciColor = [CIColor colorWithRed:color.redComponent
                                       green:color.greenComponent
                                        blue:color.blueComponent
                                       alpha:color.alphaComponent * IJSVGFilterClamp(opacity)
                                  colorSpace:space];
    CGColorSpaceRelease(space);
    return [CIImage imageWithColor:ciColor];
}

@end
