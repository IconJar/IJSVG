//
//  IJSVGFeatureFlag.m
//  IJSVG
//
//  Created by Curtis Hard on 12/07/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFeatureFlag.h>

@implementation IJSVGFeatureFlag

+ (instancetype)featureFlagWithEnabled:(BOOL)enabled
{
    IJSVGFeatureFlag* flag = [[self alloc] init];
    flag->_enabled = enabled;
    return flag;
}

@end
