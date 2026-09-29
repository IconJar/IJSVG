//
//  IJSVGFilterContext.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterContext.h>

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

// Prepare pixel bounds once per effect, rather than once per sample and channel.
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
    if(!isfinite(left) || !isfinite(top) || !isfinite(right) || !isfinite(bottom) || right < left || bottom < top) {
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
        x = left + fmod(fmod(x - left, width) + width, width);
        y = top + fmod(fmod(y - top, height) + height, height);
    } else if(x < left - 1. || x >= right + 1. || y < top - 1. || y >= bottom + 1.) {
        // Reject distant coordinates before converting them to integer indices.
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
            // Coordinates are already wrapped; only the next neighbour can cross the edge.
            xs[i] = xs[i] > right ? xs[i] - width : xs[i];
            ys[i] = ys[i] > bottom ? ys[i] - height : ys[i];
        }
    }
    return YES;
}

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
            if(xs[i] < sampler->left || xs[i] > sampler->right || ys[j] < sampler->top || ys[j] > sampler->bottom) {
                continue;
            }
            value += sampler->pixels[(ys[j] * sampler->width + xs[i]) * 4 + channel] * weightsX[i] * weightsY[j];
        }
    }
    return value;
}

void IJSVGFilterSamplerPixel(const IJSVGFilterSampler* sampler, CGFloat x, CGFloat y, float pixel[4])
{
    double values[4] = { 0 };
    NSInteger xs[2], ys[2];
    double weightsX[2], weightsY[2];
    if(IJSVGFilterSampleCoordinates(sampler, x, y, xs, ys, weightsX, weightsY)) {
        for(NSUInteger j = 0; j < 2; j++) {
            for(NSUInteger i = 0; i < 2; i++) {
                if(xs[i] < sampler->left || xs[i] > sampler->right || ys[j] < sampler->top || ys[j] > sampler->bottom) {
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
    // Small icons are cheaper to evaluate directly. Larger independent CPU loops
    // use row bands; vImage convolutions keep their own internal scheduling.
    if(width * height < 65536 || height < 2) {
        operation(0, height);
        return;
    }
    // Short, wide images still need enough bands to occupy the worker queue.
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
    size_t width = self.extent.size.width, height = self.extent.size.height;
    NSMutableData* data = [NSMutableData dataWithLength:width * height * 4 * sizeof(float)];
    CGColorSpaceRef space = CGColorSpaceCreateWithName(self.linearRGB ? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
    // Flip in the lazy image graph so rendering writes directly in CPU row order.
    CGFloat flipY = CGRectGetMinY(self.extent) + CGRectGetMaxY(self.extent);
    image = [image imageByApplyingTransform:CGAffineTransformMake(1.f, 0.f, 0.f, -1.f, 0.f, flipY)];
    [self.context render:image
                toBitmap:data.mutableBytes
                rowBytes:width * 4 * sizeof(float)
                  bounds:self.extent
                  format:kCIFormatRGBAf
              colorSpace:space];
    CGColorSpaceRelease(space);
    return data;
}

- (CIImage*)imageForPixels:(NSData*)pixels
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(self.linearRGB ? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
    CIImage* image = [CIImage imageWithBitmapData:pixels
                                      bytesPerRow:self.extent.size.width * 4 * sizeof(float)
                                             size:self.extent.size
                                           format:kCIFormatRGBAf
                                       colorSpace:space];
    CGColorSpaceRelease(space);
    // Keep the existing pixel storage and restore image coordinates without a row copy.
    return [image imageByApplyingTransform:CGAffineTransformMake(1.f, 0.f, 0.f, -1.f, 0.f, self.extent.size.height)];
}

// Only effects without an equivalent Core Image operation materialize pixels.
- (CIImage*)mapImage:(CIImage*)image
               other:(CIImage*)other
           operation:(void (^)(const float*, const float*, float*, NSInteger, NSInteger))operation
{
    NSData* first = [self pixelsForImage:image];
    NSData* second = other == image ? first : (other == nil ? nil : [self pixelsForImage:other]);
    NSMutableData* output = [NSMutableData dataWithLength:first.length];
    operation(first.bytes, second.bytes, output.mutableBytes, self.extent.size.width,
              self.extent.size.height);
    return [self imageForPixels:output];
}

// Color matching remains part of the lazy Core Image graph. No bitmap readback
// is needed to evaluate a primitive in its SVG interpolation space.

- (CIImage*)imageInPrimitiveColorSpace:(CIImage*)image
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(self.linearRGB ? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
    CIImage* result = [image imageByColorMatchingWorkingSpaceToColorSpace:space];
    CGColorSpaceRelease(space);
    return result;
}

- (CIImage*)imageFromPrimitiveColorSpace:(CIImage*)image
{
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
                        @"inputRVector": [CIVector vectorWithX:0 Y:0
                                                             Z:0 W:0],
                        @"inputGVector": [CIVector vectorWithX:0 Y:0
                                                             Z:0 W:0],
                        @"inputBVector": [CIVector vectorWithX:0 Y:0
                                                             Z:0 W:0]
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
