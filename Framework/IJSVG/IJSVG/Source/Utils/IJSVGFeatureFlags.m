//
//  IJSVGFeatureFlags.m
//  IJSVG
//
//  Created by Curtis Hard on 12/07/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFeatureFlags.h>

@implementation IJSVGFeatureFlags

- (instancetype)init
{
    if((self = [super init]) != nil) {
        // filters
        _filters = [IJSVGFeatureFlag featureFlagWithEnabled:NO];
        
        // viewBox normalization
        _viewBoxNormalization = [IJSVGFeatureFlag featureFlagWithEnabled:YES];
      
        // Inferring of viewBoxes
        _inferViewBoxes = [IJSVGFeatureFlag featureFlagWithEnabled:YES];
    }
    return self;
}

@end
