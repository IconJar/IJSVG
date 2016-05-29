//
//  IJSVGUnits.h
//  IJSVGExample
//
//  Created by Curtis Hard on 27/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

@class IJSVGPath;

typedef struct {
    CGFloat value;
    BOOL isPercentage;
} IJSVGUnit;

IJSVGUnit IJSVGUnitFromString(NSString * string);
CGFloat IJSVGFloatFromUnit(IJSVGUnit unit, IJSVGPath * path, BOOL width);
