//
//  IJSVGMath.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGMath.h"

@implementation IJSVGMath

CGFloat IJSVGMathRad(CGFloat val) {
    return val * M_PI / 180;
};

CGFloat IJSVGMathDeg(CGFloat val) {
    return val * 180.f / M_PI;
};

CGFloat IJSVGMathAcos(CGFloat val) {
    return IJSVGMathDeg(acosf(val));
};

CGFloat IJSVGMathSin(CGFloat val) {
    return sinf(IJSVGMathRad(val));
};

CGFloat IJSVGMathAsin(CGFloat val) {
    return IJSVGMathDeg(asinf(val));
};

CGFloat IJSVGMathTan(CGFloat val) {
    return tanf(IJSVGMathRad(val));
};

CGFloat IJSVGMathAtan(CGFloat val) {
    return IJSVGMathDeg(atanf(val));
};

@end
