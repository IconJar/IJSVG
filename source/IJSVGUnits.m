//
//  IJSVGUnits.m
//  IJSVGExample
//
//  Created by Curtis Hard on 27/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGUnits.h"
#import "IJSVGPath.h"

IJSVGUnit IJSVGUnitFromString(NSString * string)
{
    IJSVGUnit unit;
    unit.value = [string floatValue];
    if([string hasSuffix:@"%"]) {
        unit.isPercentage = YES;
    }
    return unit;
};

CGFloat IJSVGFloatFromUnit(IJSVGUnit unit, IJSVGPath * path, BOOL width) {
    NSSize bounds = path.path.bounds.size;
    if(unit.isPercentage) {
        CGFloat val = width ? bounds.width : bounds.height;
        return ((val/100)*unit.value);
    }
    return unit.value;
};
