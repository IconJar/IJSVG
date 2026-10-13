//
//  IJSVGGradientGeometry.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGGradientGeometry.h>

@implementation IJSVGGradientGeometry {
    IJSVGUnitLength* _coordinates[6];
    IJSVGGradientSpreadMethod _spreadMethod;
}

- (instancetype)initWithLinearGradient:(IJSVGLinearGradient*)gradient
{
    if ((self = [super init]) != nil) {
        _units = gradient.units;
        _spreadMethod = gradient.spreadMethod;
        _coordinates[0] = gradient.x1;
        _coordinates[1] = gradient.x2;
        _coordinates[2] = gradient.y1;
        _coordinates[3] = gradient.y2;
    }
    return self;
}

- (instancetype)initWithRadialGradient:(IJSVGRadialGradient*)gradient
{
    if ((self = [super init]) != nil) {
        _units = gradient.units;
        _spreadMethod = gradient.spreadMethod;
        _coordinates[0] = gradient.cx;
        _coordinates[1] = gradient.cy;
        _coordinates[2] = gradient.r;
        _coordinates[3] = gradient.fx;
        _coordinates[4] = gradient.fy;
        _coordinates[5] = gradient.fr;
    }
    return self;
}

- (void)applyToLinearGradient:(IJSVGLinearGradient*)gradient
{
    gradient.x1 = _coordinates[0];
    gradient.x2 = _coordinates[1];
    gradient.y1 = _coordinates[2];
    gradient.y2 = _coordinates[3];
    gradient.spreadMethod = _spreadMethod;
}

- (void)applyToRadialGradient:(IJSVGRadialGradient*)gradient
{
    gradient.cx = _coordinates[0];
    gradient.cy = _coordinates[1];
    gradient.r = _coordinates[2];
    gradient.fx = _coordinates[3];
    gradient.fy = _coordinates[4];
    gradient.fr = _coordinates[5];
    gradient.spreadMethod = _spreadMethod;
}

@end
