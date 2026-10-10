//
//  IJSVGLightingFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGLightingFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

static const double IJSVGSpotLightConeTransition = .016;

typedef struct {
    IJSVGNodeType lightType;
    BOOL specular;
    double surfaceScale;
    double lightingConstant;
    double specularExponent;
    CGSize units;
    CGSize step;
    double azimuth;
    double elevation;
    double lightX;
    double lightY;
    double lightZ;
    double spotDirectionX;
    double spotDirectionY;
    double spotDirectionZ;
    double spotDirectionLength;
    double spotExponent;
    double coneCosine;
    double red;
    double green;
    double blue;
    CGRect inputRegion;
    CGRect outputRegion;
    CGAffineTransform imageTransform;
    BOOL objectUnits;
    CGRect boundingBox;
} IJSVGLightingParameters;

typedef struct {
    double x, y, z;
} IJSVGLightingVector;

// Use nearby opacity values to find the surface direction.
static inline IJSVGLightingVector IJSVGLightingSurfaceNormal(const IJSVGFilterSampler* sampler,
                                                             NSInteger x, NSInteger y, double dx,
                                                             double dy, IJSVGLightingParameters parameters)
{
    BOOL left = x - dx < CGRectGetMinX(parameters.inputRegion),
         right = x + dx >= CGRectGetMaxX(parameters.inputRegion);
    BOOL top = y - dy < CGRectGetMinY(parameters.inputRegion),
         bottom = y + dy >= CGRectGetMaxY(parameters.inputRegion);
    double gx = 0, gy = 0, wx = 0, wy = 0;
    // Reuse corner samples when the pixel is away from the edges.
    // At an edge only use samples that are inside the image.
    if(!left && !right && !top && !bottom) {
        double topLeft = IJSVGFilterSamplerValue(sampler, x - dx, y - dy, 3);
        double topRight = IJSVGFilterSamplerValue(sampler, x + dx, y - dy, 3);
        double bottomLeft = IJSVGFilterSamplerValue(sampler, x - dx, y + dy, 3);
        double bottomRight = IJSVGFilterSamplerValue(sampler, x + dx, y + dy, 3);
        double middleLeft = IJSVGFilterSamplerValue(sampler, x - dx, y, 3);
        double middleRight = IJSVGFilterSamplerValue(sampler, x + dx, y, 3);
        double topMiddle = IJSVGFilterSamplerValue(sampler, x, y - dy, 3);
        double bottomMiddle = IJSVGFilterSamplerValue(sampler, x, y + dy, 3);
        gx = (topRight - topLeft) + 2 * (middleRight - middleLeft) + (bottomRight - bottomLeft);
        gy = (bottomLeft - topLeft) + 2 * (bottomMiddle - topMiddle) + (bottomRight - topRight);
        wx = wy = 4;
    } else {
        // Measure the change in opacity along each edge.
        for(int j = -1; j <= 1; j++) {
            if((j < 0 && top) || (j > 0 && bottom)) {
                continue;
            }
            double weight = j == 0 ? 2 : 1;
            double a = IJSVGFilterSamplerValue(sampler, x + (left ? 0 : -dx), y + j * dy, 3);
            double b = IJSVGFilterSamplerValue(sampler, x + (right ? 0 : dx), y + j * dy, 3);
            gx += weight * (b - a);
            wx += weight;
        }
        for(int i = -1; i <= 1; i++) {
            if((i < 0 && left) || (i > 0 && right)) {
                continue;
            }
            double weight = i == 0 ? 2 : 1;
            double a = IJSVGFilterSamplerValue(sampler, x + i * dx, y + (top ? 0 : -dy), 3);
            double b = IJSVGFilterSamplerValue(sampler, x + i * dx, y + (bottom ? 0 : dy), 3);
            gy += weight * (b - a);
            wy += weight;
        }
    }
    double nx = -parameters.surfaceScale * gx * (left || right ? 2 : 1) / (MAX(1, wx) * parameters.step.width);
    double ny = -parameters.surfaceScale * gy * (top || bottom ? 2 : 1) / (MAX(1, wy) * parameters.step.height);
    double norm = hypot(hypot(nx, ny), 1);
    nx /= norm;
    ny /= norm;
    double nz = 1 / norm;
    return (IJSVGLightingVector){ nx, ny, nz };
}

static void IJSVGApplyLightingToPixels(const float* src, float* dst, NSInteger w,
                                       NSInteger h, IJSVGLightingParameters parameters)
{
    IJSVGFilterSampler sampler = IJSVGFilterSamplerMake(src, w, h, parameters.inputRegion, IJSVGFilterEdgeModeDuplicate);
    double dx = parameters.step.width * parameters.units.width;
    double dy = parameters.step.height * parameters.units.height;
    double distantX = cos(parameters.azimuth) * cos(parameters.elevation);
    double distantY = sin(parameters.azimuth) * cos(parameters.elevation);
    double distantZ = sin(parameters.elevation);
    NSInteger minX = floor(CGRectGetMinX(parameters.outputRegion));
    NSInteger minY = floor(CGRectGetMinY(parameters.outputRegion));
    NSInteger maxX = ceil(CGRectGetMaxX(parameters.outputRegion));
    NSInteger maxY = ceil(CGRectGetMaxY(parameters.outputRegion));
  
    IJSVGFilterApplyRows(maxX - minX, maxY - minY, ^(NSInteger firstRow, NSInteger lastRow) {
        for(NSInteger y = minY + firstRow; y < minY + lastRow; y++) {
            for(NSInteger x = minX; x < maxX; x++) {
                IJSVGLightingVector normal = IJSVGLightingSurfaceNormal(&sampler, x, y, dx, dy, parameters);
                double nx = normal.x, ny = normal.y, nz = normal.z;
                double ux = distantX, uy = distantY, uz = distantZ;
                if(parameters.lightType != IJSVGNodeTypeFilterDistantLight) {
                    double px = (x + .5 - parameters.imageTransform.tx) / parameters.units.width;
                    double py = (y + .5 - parameters.imageTransform.ty) / parameters.units.height;
                    if(parameters.objectUnits) {
                        px -= parameters.boundingBox.origin.x / parameters.boundingBox.size.width;
                        py -= parameters.boundingBox.origin.y / parameters.boundingBox.size.height;
                    }
                    ux = parameters.lightX - px;
                    uy = parameters.lightY - py;
                    uz = parameters.lightZ - parameters.surfaceScale * src[(y * w + x) * 4 + 3];
                    double length = hypot(hypot(ux, uy), uz);
                    if(length > 0) {
                        ux /= length;
                        uy /= length;
                        uz /= length;
                    }
                }
                double intensity = 1;
                if(parameters.lightType == IJSVGNodeTypeFilterSpotLight) {
                    double cosine = parameters.spotDirectionLength > 0 ?
                        -(ux * parameters.spotDirectionX + uy * parameters.spotDirectionY + uz * parameters.spotDirectionZ) / parameters.spotDirectionLength
                        : 0;
                    // Fade inside the cone boundary to keep narrow lights smooth.
                    double coverage = IJSVGFilterClamp((cosine - parameters.coneCosine) / IJSVGSpotLightConeTransition);
                    intensity = cosine <= 0 ? 0 : coverage * pow(cosine, parameters.spotExponent);
                }
                double dot;
                if(parameters.specular) {
                    double hz = uz + 1, hn = hypot(hypot(ux, uy), hz);
                    dot = hn > 0 ? (nx * ux + ny * uy + nz * hz) / hn : 0;
                    intensity *= parameters.lightingConstant * pow(MAX(0, dot), parameters.specularExponent);
                } else {
                    dot = nx * ux + ny * uy + nz * uz;
                    intensity *= parameters.lightingConstant * MAX(0, dot);
                }
                NSInteger index = (y * w + x) * 4;
                dst[index] = IJSVGFilterClamp(parameters.red * intensity);
                dst[index + 1] = IJSVGFilterClamp(parameters.green * intensity);
                dst[index + 2] = IJSVGFilterClamp(parameters.blue * intensity);
                dst[index + 3] = parameters.specular ? MAX(dst[index], MAX(dst[index + 1], dst[index + 2])) : 1;
            }
        }
    });

}

static IJSVGLightingVector IJSVGLightingColor(NSColor* color, IJSVGFilterContext* context)
{
    // The light has one color so only one pixel needs color conversion.
    CIImage* flood = [context floodWithColor:color
                                     opacity:1];
    float colorValues[4] = { 0 };
    CGColorSpaceRef space = CGColorSpaceCreateWithName(context.linearRGB ? kCGColorSpaceLinearSRGB : kCGColorSpaceSRGB);
    [context.context render:flood
                   toBitmap:colorValues
                   rowBytes:sizeof(colorValues)
                     bounds:CGRectMake(0.f, 0.f, 1.f, 1.f)
                     format:kCIFormatRGBAf
                 colorSpace:space];
    CGColorSpaceRelease(space);
    return (IJSVGLightingVector){ colorValues[0], colorValues[1], colorValues[2] };
}

@implementation IJSVGLightingFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    CIImage* input = inputs.firstObject ?: CIImage.emptyImage;
    IJSVGFilterPrimitive* light = (IJSVGFilterPrimitive*)primitive.children.firstObject;
    if(light == nil) {
        return CIImage.emptyImage;
    }
    CGRect outputRegion = CGRectIntersection(region, context.extent);
    if(CGRectIsEmpty(outputRegion)) {
        return CIImage.emptyImage;
    }
    BOOL specular = primitive.type == IJSVGNodeTypeFilterSpecularLighting;
    double surface = [primitive numberForParameter:IJSVGAttributeSurfaceScale
                                      defaultValue:1];
    double constant =
        [primitive numberForParameter:specular ? IJSVGAttributeSpecularConstant : IJSVGAttributeDiffuseConstant
                         defaultValue:1];
    double exponent = [primitive numberForParameter:IJSVGAttributeSpecularExponent
                                       defaultValue:1];
    if(constant < 0 || (specular && (exponent < 1 || exponent > 128))) {
        return CIImage.emptyImage;
    }
    CGSize units = context.pixelUnits;
    CGSize step = [primitive pairForParameter:IJSVGAttributeKernelUnitLength
                                 defaultValue:CGSizeMake(1 / units.width, 1 / units.height)];
    if(step.width <= 0 || step.height <= 0) {
        return CIImage.emptyImage;
    }
    double azimuth = [light numberForParameter:IJSVGAttributeAzimuth
                                  defaultValue:0] * M_PI / 180.;
    double elevation = [light numberForParameter:IJSVGAttributeElevation
                                    defaultValue:0] * M_PI / 180.;
    double lx = [light numberForParameter:IJSVGAttributeX
                             defaultValue:0],
           ly = [light numberForParameter:IJSVGAttributeY
                             defaultValue:0];
    double lz = [light numberForParameter:IJSVGAttributeZ
                             defaultValue:0];
    double sx = [light numberForParameter:IJSVGAttributePointsAtX
                             defaultValue:0] - lx;
    double sy = [light numberForParameter:IJSVGAttributePointsAtY
                             defaultValue:0] - ly;
    double sz = [light numberForParameter:IJSVGAttributePointsAtZ
                             defaultValue:0] - lz;
    double sn = hypot(hypot(sx, sy), sz);
    double spotExponent = [light numberForParameter:IJSVGAttributeSpecularExponent
                                       defaultValue:1];
    double cone = cos([light numberForParameter:IJSVGAttributeLimitingConeAngle
                                   defaultValue:90] * M_PI / 180.);
    NSColor* color = [IJSVGColor colorFromString:primitive.parameters[IJSVGAttributeLightingColor] ?: IJSVGStringWhite];
    IJSVGLightingVector colorValues = IJSVGLightingColor(color, context);
    double red = colorValues.x, green = colorValues.y, blue = colorValues.z;
    CGRect inputRegion = CGRectIntersection(input.extent, context.extent);
    CGAffineTransform imageTransform = context.imageTransform;
    BOOL objectUnits = context.filter.contentUnits == IJSVGUnitObjectBoundingBox;
    CGRect boundingBox = context.boundingBox;
    IJSVGLightingParameters parameters = {
        .lightType = light.type,
        .specular = specular,
        .surfaceScale = surface,
        .lightingConstant = constant,
        .specularExponent = exponent,
        .units = units,
        .step = step,
        .azimuth = azimuth,
        .elevation = elevation,
        .lightX = lx,
        .lightY = ly,
        .lightZ = lz,
        .spotDirectionX = sx,
        .spotDirectionY = sy,
        .spotDirectionZ = sz,
        .spotDirectionLength = sn,
        .spotExponent = spotExponent,
        .coneCosine = cone,
        .red = red,
        .green = green,
        .blue = blue,
        .inputRegion = inputRegion,
        .outputRegion = outputRegion,
        .imageTransform = imageTransform,
        .objectUnits = objectUnits,
        .boundingBox = boundingBox,
    };
    return [context
         mapImage:input
            other:nil
        operation:^(const float* src, const float* unused, float* dst, NSInteger w, NSInteger h) {
            IJSVGApplyLightingToPixels(src, dst, w, h, parameters);
        }];
}

@end
