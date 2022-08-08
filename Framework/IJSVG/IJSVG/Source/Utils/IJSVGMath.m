//
//  IJSVGMath.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGMath.h>
#import <IJSVG/IJSVGCommandParser.h>

@implementation IJSVGMath

CGFloat IJSVGMathRad(CGFloat val)
{
    return val * M_PI / 180;
};

CGFloat IJSVGMathDeg(CGFloat val)
{
    return val * 180.f / M_PI;
};

CGFloat IJSVGMathToFixed(CGFloat val, NSInteger decimalPlaces)
{
    int p = pow(10, decimalPlaces);
    return (CGFloat)floor(p * val) / p;
}

CGFloat IJSVGMathAcos(CGFloat val)
{
    return IJSVGMathDeg(acosf(val));
};

CGFloat IJSVGMathSin(CGFloat val)
{
    return sinf(IJSVGMathRad(val));
};

CGFloat IJSVGMathAsin(CGFloat val)
{
    return IJSVGMathDeg(asinf(val));
};

CGFloat IJSVGMathTan(CGFloat val)
{
    return tanf(IJSVGMathRad(val));
};

CGFloat IJSVGMathAtan(CGFloat val)
{
    return IJSVGMathDeg(atanf(val));
};

@end
