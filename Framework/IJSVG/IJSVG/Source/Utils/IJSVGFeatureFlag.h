//
//  IJSVGFeatureFlag.h
//  IJSVG
//
//  Created by Curtis Hard on 12/07/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGFeatureFlag : NSObject

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, copy) NSString* userDefaultsKey;

+ (instancetype)featureFlagWithEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
