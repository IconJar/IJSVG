//
//  IJSVGGradientGeometry.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGGradientGeometry.h>
#import <IJSVGParserUtils.h>

IJSVGGradientGeometry* IJSVGGradientGeometryCreateLinear(IJSVGLinearGradient* gradient)
{
    IJSVGGradientGeometry* geometry = calloc(1, sizeof(*geometry));
    if (geometry == NULL) {
        return NULL;
    }
    geometry->units = gradient.units;
    geometry->spreadMethod = gradient.spreadMethod;
    geometry->coordinates[0] = CFBridgingRetain(gradient.x1);
    geometry->coordinates[1] = CFBridgingRetain(gradient.x2);
    geometry->coordinates[2] = CFBridgingRetain(gradient.y1);
    geometry->coordinates[3] = CFBridgingRetain(gradient.y2);
    return geometry;
}

void IJSVGGradientGeometryApplyLinear(const IJSVGGradientGeometry* geometry, IJSVGLinearGradient* gradient)
{
    gradient.x1 = (__bridge IJSVGUnitLength*)geometry->coordinates[0];
    gradient.x2 = (__bridge IJSVGUnitLength*)geometry->coordinates[1];
    gradient.y1 = (__bridge IJSVGUnitLength*)geometry->coordinates[2];
    gradient.y2 = (__bridge IJSVGUnitLength*)geometry->coordinates[3];
    gradient.spreadMethod = geometry->spreadMethod;
}

IJSVGGradientGeometry* IJSVGGradientGeometryCreateRadial(IJSVGRadialGradient* gradient)
{
    IJSVGGradientGeometry* geometry = calloc(1, sizeof(*geometry));
    if (geometry == NULL) {
        return NULL;
    }
    geometry->units = gradient.units;
    geometry->spreadMethod = gradient.spreadMethod;
    geometry->coordinates[0] = CFBridgingRetain(gradient.cx);
    geometry->coordinates[1] = CFBridgingRetain(gradient.cy);
    geometry->coordinates[2] = CFBridgingRetain(gradient.r);
    geometry->coordinates[3] = CFBridgingRetain(gradient.fx);
    geometry->coordinates[4] = CFBridgingRetain(gradient.fy);
    geometry->coordinates[5] = CFBridgingRetain(gradient.fr);
    return geometry;
}

void IJSVGGradientGeometryApplyRadial(const IJSVGGradientGeometry* geometry, IJSVGRadialGradient* gradient)
{
    gradient.cx = (__bridge IJSVGUnitLength*)geometry->coordinates[0];
    gradient.cy = (__bridge IJSVGUnitLength*)geometry->coordinates[1];
    gradient.r = (__bridge IJSVGUnitLength*)geometry->coordinates[2];
    gradient.fx = (__bridge IJSVGUnitLength*)geometry->coordinates[3];
    gradient.fy = (__bridge IJSVGUnitLength*)geometry->coordinates[4];
    gradient.fr = (__bridge IJSVGUnitLength*)geometry->coordinates[5];
    gradient.spreadMethod = geometry->spreadMethod;
}

void IJSVGGradientGeometryDestroy(IJSVGGradientGeometry* geometry)
{
    if (geometry == NULL) {
        return;
    }
    for (NSUInteger index = 0; index < 6; index++) {
        if (geometry->coordinates[index] != NULL) {
            CFRelease(geometry->coordinates[index]);
        }
    }
    free(geometry);
}
