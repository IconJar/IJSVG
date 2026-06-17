//
//  IJSVGColorUtils.m
//  IconJar
//
//  Created by Curtis Hard on 31/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColorUtils.h>
#import <IJSVG/IJSVGStringAdditions.h>
#import <IJSVG/IJSVGUnitLength.h>

static CGFloat IJSVGColorClamp(CGFloat value, CGFloat minimumValue,
                               CGFloat maximumValue)
{
    return fmin(maximumValue, fmax(minimumValue, value));
}

static CGFloat IJSVGColorLinearSRGBToSRGB(CGFloat value)
{
    if(value <= 0.0031308f) {
        return 12.92f * value;
    }
    return 1.055f * pow(value, 1.f / 2.4f) - 0.055f;
}

static CGFloat IJSVGColorComponentFromOKLCHString(NSString* string,
                                                  CGFloat percentageBase)
{
    IJSVGUnitLength* unit = [IJSVGUnitLength unitWithString:string];
    if(unit == nil) {
        return NAN;
    }
    if(unit.type == IJSVGUnitLengthTypePercentage) {
        return [unit computeValue:percentageBase];
    }
    return unit.value;
}

static NSArray<NSString*>* IJSVGColorOKLCHComponentsFromParameters(NSString* parameters)
{
    // split on commas, the alpha slash and any whitespace in a single pass.
    // the slash is consumed as a delimiter, so alpha is simply the 4th component.
    return [parameters ijsvg_componentsSeparatedByChars:", /\t\n\r"];
}

NSColor* IJSVGColorCreateFromOKLCHParameters(NSString* parameters)
{
    NSArray<NSString*>* components = IJSVGColorOKLCHComponentsFromParameters(parameters);
    if(components.count < 3) {
        return nil;
    }

    CGFloat lightness = IJSVGColorComponentFromOKLCHString(components[0], 1.f);
    if(isnan(lightness) == YES) {
        return nil;
    }
    if(lightness > 1.f) {
        lightness /= 100.f;
    }
    lightness = IJSVGColorClamp(lightness, 0.f, 1.f);

    CGFloat chroma = IJSVGColorComponentFromOKLCHString(components[1], 0.4f);
    CGFloat hue = IJSVGColorComponentFromOKLCHString(components[2], 360.f);
    if(isnan(chroma) || isnan(hue)) {
        return nil;
    }
    chroma = fmax(0.f, chroma);

    CGFloat alpha = 1.f;
    if(components.count >= 4) {
        alpha = IJSVGColorComponentFromOKLCHString(components[3], 1.f);
        if(isnan(alpha) == YES) {
            return nil;
        }
        alpha = IJSVGColorClamp(alpha, 0.f, 1.f);
    }

    CGFloat hueRadians = hue * ((CGFloat)M_PI / 180.f);
    CGFloat a = chroma * cos(hueRadians);
    CGFloat b = chroma * sin(hueRadians);

    CGFloat lPrime = lightness + 0.3963377774f * a + 0.2158037573f * b;
    CGFloat mPrime = lightness - 0.1055613458f * a - 0.0638541728f * b;
    CGFloat sPrime = lightness - 0.0894841775f * a - 1.2914855480f * b;

    CGFloat l = lPrime * lPrime * lPrime;
    CGFloat m = mPrime * mPrime * mPrime;
    CGFloat s = sPrime * sPrime * sPrime;

    CGFloat red = 4.0767416621f * l - 3.3077115913f * m + 0.2309699292f * s;
    CGFloat green = -1.2684380046f * l + 2.6097574011f * m - 0.3413193965f * s;
    CGFloat blue = -0.0041960863f * l - 0.7034186147f * m + 1.7076147010f * s;

    red = IJSVGColorClamp(IJSVGColorLinearSRGBToSRGB(red), 0.f, 1.f);
    green = IJSVGColorClamp(IJSVGColorLinearSRGBToSRGB(green), 0.f, 1.f);
    blue = IJSVGColorClamp(IJSVGColorLinearSRGBToSRGB(blue), 0.f, 1.f);

    return [NSColor colorWithDeviceRed:red
                                 green:green
                                  blue:blue
                                 alpha:alpha];
}

CGFloat* IJSVGColorCSSHSLToHSB(CGFloat hue, CGFloat saturation,
                               CGFloat lightness)
{
    hue *= (1.f / 360.f);
    hue = (hue - floorf(hue));
    saturation *= 0.01;
    lightness *= 0.01;
    lightness *= 2.f;

    CGFloat s = saturation * ((lightness < 1.f) ? lightness : (2.f - lightness));
    CGFloat brightness = (lightness + s) * .5f;
    if(s != 0.f) {
        s = (2.f * s) / (lightness + s);
    }
    CGFloat* floats = (CGFloat*)malloc(3 * sizeof(CGFloat));
    floats[0] = hue;
    floats[1] = s;
    floats[2] = brightness;
    return floats;
};
