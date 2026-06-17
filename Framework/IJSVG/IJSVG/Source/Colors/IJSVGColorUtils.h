//
//  IJSVGColorUtils.h
//  IconJar
//
//  Created by Curtis Hard on 17/06/2026.
//  Copyright (c) 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>

@interface IJSVGColor (Utils)

/// Converts a CSS HSL triplet into HSB components. Returns a malloc'd buffer of
/// three CGFloats (hue, saturation, brightness) that the caller must free.
+ (CGFloat*)HSBFromCSSHSLHue:(CGFloat)hue
                  saturation:(CGFloat)saturation
                   lightness:(CGFloat)lightness;

/// Creates an NSColor from the parameter list of an oklch() color function,
/// e.g. the "62.8% 0.25 29.23" portion. Returns nil if the parameters are invalid.
+ (NSColor*)colorFromOKLCHParameters:(NSString*)parameters;

@end
