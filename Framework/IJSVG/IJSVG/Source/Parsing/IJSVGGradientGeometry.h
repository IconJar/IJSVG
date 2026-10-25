//
//  IJSVGGradientGeometry.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGRadialGradient.h>

typedef struct {
    CFTypeRef coordinates[6];
    IJSVGUnitType units;
    IJSVGGradientSpreadMethod spreadMethod;
} IJSVGGradientGeometry;

IJSVGGradientGeometry* IJSVGGradientGeometryCreateLinear(IJSVGLinearGradient* gradient);
IJSVGGradientGeometry* IJSVGGradientGeometryCreateRadial(IJSVGRadialGradient* gradient);
void IJSVGGradientGeometryDestroy(IJSVGGradientGeometry* geometry);
void IJSVGGradientGeometryApplyLinear(const IJSVGGradientGeometry* geometry, IJSVGLinearGradient* gradient);
void IJSVGGradientGeometryApplyRadial(const IJSVGGradientGeometry* geometry, IJSVGRadialGradient* gradient);
