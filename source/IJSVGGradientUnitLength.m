//
//  IJSVGGradientUnitLength.m
//  IconJar
//
//  Created by Curtis Hard on 29/03/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGGradientUnitLength.h"

@implementation IJSVGGradientUnitLength

- (NSString *)stringValue
{
    if(self.type == IJSVGUnitLengthTypePercentage) {
        return [NSString stringWithFormat:@"%g",self.value];
    }
    return [super stringValue];
}

@end
