//
//  IJSVGTurbulenceFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTurbulenceFilterEffect.h>
#import <IJSVG/IJSVGParser.h>
// Build the noise here so the seed and repeating edges follow SVG rules.
// Each render keeps its own noise data.
typedef struct {
    int permutation[514];
    double gradient[514][2][4];
} IJSVGFilterNoise;

static int32_t IJSVGFilterRandom(int32_t* seed)
{
    int32_t next = 16807 * (*seed % 127773) - 2836 * (*seed / 127773);
    *seed = next > 0 ? next : next + 2147483647;
    return *seed;
}

static void IJSVGFilterInitNoise(IJSVGFilterNoise* noise, double seedValue)
{
    // Keep the seed within the range of a signed 32 bit number.
    int32_t normalized = (int32_t)fmax(-2147483646., fmin(2147483646., trunc(seedValue)));
    int32_t seed = normalized <= 0 ? -(normalized % 2147483646) + 1 : normalized;
    for(int channel = 0; channel < 4; channel++) {
        for(int i = 0; i < 256; i++) {
            noise->permutation[i] = i;
            double x, y, length;
            do {
                x = (IJSVGFilterRandom(&seed) % 512 - 256) / 256.;
                y = (IJSVGFilterRandom(&seed) % 512 - 256) / 256.;
                length = hypot(x, y);
            } while(length == 0 || length > 1);
            noise->gradient[i][0][channel] = x / length;
            noise->gradient[i][1][channel] = y / length;
        }
    }
    for(int i = 255; i > 0; i--) {
        int other = IJSVGFilterRandom(&seed) % 256;
        int saved = noise->permutation[i];
        noise->permutation[i] = noise->permutation[other];
        noise->permutation[other] = saved;
    }
    for(int i = 0; i < 258; i++) {
        noise->permutation[256 + i] = noise->permutation[i];
        memcpy(noise->gradient[256 + i], noise->gradient[i], sizeof(noise->gradient[i]));
    }
}

// Reuse the same noise positions for all four color channels.
static void IJSVGFilterNoiseValues(const IJSVGFilterNoise* noise, double x, double y,
                                   double tileWidth, double tileHeight, double wrapX,
                                   double wrapY, BOOL stitch, double values[4])
{
    x += 4096.;
    y += 4096.;
    double ix = floor(x), iy = floor(y);
    double fx = x - ix, fy = y - iy;
    double smoothX = fx * fx * (3. - 2. * fx), smoothY = fy * fy * (3. - 2. * fy);
    int px[2], py[2];
    for(int i = 0; i < 2; i++) {
        double bx = ix + i, by = iy + i;
        if(stitch) {
            if(bx >= wrapX) {
                bx -= tileWidth;
            }
            if(by >= wrapY) {
                by -= tileHeight;
            }
        }
        // Move negative positions into the valid range.
        px[i] = (int)fmod(bx, 256.);
        py[i] = (int)fmod(by, 256.);
        px[i] += px[i] < 0 ? 256 : 0;
        py[i] += py[i] < 0 ? 256 : 0;
    }
    double dots[2][2][4];
    for(int j = 0; j < 2; j++) {
        for(int i = 0; i < 2; i++) {
            int index = noise->permutation[noise->permutation[px[i]] + py[j]];
            for(int c = 0; c < 4; c++) {
                dots[j][i][c] = (fx - i) * noise->gradient[index][0][c]
                    + (fy - j) * noise->gradient[index][1][c];
            }
        }
    }
    for(int c = 0; c < 4; c++) {
        double top = dots[0][0][c] + smoothX * (dots[0][1][c] - dots[0][0][c]);
        double bottom = dots[1][0][c] + smoothX * (dots[1][1][c] - dots[1][0][c]);
        values[c] = top + smoothY * (bottom - top);
    }
}

// Add layers of noise with smaller details and less strength each time.
static inline void IJSVGTurbulenceValues(const IJSVGFilterNoise* noise, double px,
                                         double py, CGSize frequency, double tileWidth,
                                         double tileHeight, double wrapX, double wrapY,
                                         NSInteger octaves, BOOL fractal, BOOL stitch,
                                         double values[4])
{
    double nx = px * frequency.width, ny = py * frequency.height, amplitude = 1.;
    double tw = tileWidth, th = tileHeight, wx = wrapX, wy = wrapY;
    for(NSInteger octave = 0; octave < octaves; octave++) {
        double samples[4];
        IJSVGFilterNoiseValues(noise, nx, ny, tw, th, wx, wy, stitch, samples);
        for(int c = 0; c < 4; c++) {
            values[c] += amplitude * (fractal ? samples[c] : fabs(samples[c]));
        }
        nx *= 2;
        ny *= 2;
        amplitude *= .5;
        tw *= 2;
        th *= 2;
        wx = wx * 2 - 4096.;
        wy = wy * 2 - 4096.;
    }
}

// Adjust the frequency so opposite tile edges match.
static CGSize IJSVGTurbulenceStitchedFrequency(CGSize frequency, CGSize tileSize)
{
    double f[] = { frequency.width, frequency.height }, size[] = {
      tileSize.width, tileSize.height
    };
    for(int axis = 0; axis < 2; axis++) {
        if(f[axis] > 0 && size[axis] > 0) {
            double low = floor(size[axis] * f[axis]) / size[axis];
            double high = ceil(size[axis] * f[axis]) / size[axis];
            f[axis] = low > 0 && f[axis] / low < high / f[axis] ? low : high;
        }
    }
    return CGSizeMake(f[0], f[1]);
}

@implementation IJSVGTurbulenceFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CGSize frequency = [primitive pairForParameter:IJSVGAttributeBaseFrequency
                                      defaultValue:CGSizeZero];
    if(frequency.width < 0 || frequency.height < 0) {
        return CIImage.emptyImage;
    }
    NSInteger octaves = MIN(16, MAX(0, [primitive numberForParameter:IJSVGAttributeNumOctaves
                                                        defaultValue:1]));
    BOOL fractal = [primitive.parameters[IJSVGAttributeType] isEqualToString:IJSVGStringFractalNoise];
    BOOL stitch = [primitive.parameters[IJSVGAttributeStitchTiles] isEqualToString:IJSVGStringStitch];
    CGSize units = context.pixelUnits;
    CGRect tile = CGRectMake((region.origin.x - context.imageTransform.tx) / units.width,
        (region.origin.y - context.imageTransform.ty) / units.height, region.size.width / units.width,
        region.size.height / units.height);
    if(context.filter.contentUnits == IJSVGUnitObjectBoundingBox) {
        tile.origin.x -= context.boundingBox.origin.x / context.boundingBox.size.width;
        tile.origin.y -= context.boundingBox.origin.y / context.boundingBox.size.height;
    }
    if(stitch) {
        frequency = IJSVGTurbulenceStitchedFrequency(frequency, tile.size);
    }
    CGRect outputRegion = CGRectIntersection(region, context.extent);
    if(CGRectIsEmpty(outputRegion)) {
        return CIImage.emptyImage;
    }
    // Keep the original tile position so the edges still match.
    // Only create pixels inside the visible region.
    NSInteger left = floor(CGRectGetMinX(outputRegion));
    NSInteger top = floor(CGRectGetMinY(outputRegion));
    NSInteger right = ceil(CGRectGetMaxX(outputRegion));
    NSInteger bottom = ceil(CGRectGetMaxY(outputRegion));
    NSMutableData* state = [NSMutableData dataWithLength:sizeof(IJSVGFilterNoise)];
    IJSVGFilterInitNoise(state.mutableBytes, [primitive numberForParameter:IJSVGAttributeSeed
                                                              defaultValue:0]);
    NSInteger w = context.extent.size.width, h = context.extent.size.height;
    NSMutableData* pixels = [NSMutableData dataWithLength:w * h * 4 * sizeof(float)];
    float* output = pixels.mutableBytes;
    const IJSVGFilterNoise* noise = state.bytes;
    double tileWidth = round(tile.size.width * frequency.width);
    double tileHeight = round(tile.size.height * frequency.height);
    double wrapX = floor(tile.origin.x * frequency.width + 4096. + tileWidth);
    double wrapY = floor(tile.origin.y * frequency.height + 4096. + tileHeight);
    IJSVGFilterApplyRows(right - left, bottom - top, ^(NSInteger firstRow, NSInteger lastRow) {
        for(NSInteger y = top + firstRow; y < top + lastRow; y++) {
            double py = tile.origin.y + (y + .5 - region.origin.y) / units.height;
            for(NSInteger x = left; x < right; x++) {
                double px = tile.origin.x + (x + .5 - region.origin.x) / units.width;
                double values[4] = { 0 };
                IJSVGTurbulenceValues(noise, px, py, frequency, tileWidth, tileHeight,
                    wrapX, wrapY, octaves, fractal, stitch, values);
                NSInteger index = (y * w + x) * 4;
                for(int c = 0; c < 4; c++) {
                    output[index + c] = IJSVGFilterClamp(fractal ? (values[c] + 1.) * .5 : values[c]);
                }
                for(int c = 0; c < 3; c++) {
                    output[index + c] *= output[index + 3];
                }
            }
        }
    });
    return [context imageForPixels:pixels];
}

@end
