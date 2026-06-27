//
//  IJSVGFeatureFlags.h
//  IJSVG
//
//  Created by Curtis Hard on 12/07/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGFeatureFlag.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGFeatureFlags : NSObject

@property (nonatomic, readonly, strong) IJSVGFeatureFlag* viewBoxNormalization;
@property (nonatomic, readonly, strong) IJSVGFeatureFlag* inferViewBoxes;

@end

NS_ASSUME_NONNULL_END
