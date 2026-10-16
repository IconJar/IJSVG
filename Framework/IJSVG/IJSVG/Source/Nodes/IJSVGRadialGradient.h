//
//  IJSVGRadialGradient.h
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGGradient.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGRadialGradient : IJSVGGradient

@property (nonatomic, strong, nullable) IJSVGUnitLength* cx;
@property (nonatomic, strong, nullable) IJSVGUnitLength* cy;
@property (nonatomic, strong, nullable) IJSVGUnitLength* fx;
@property (nonatomic, strong, nullable) IJSVGUnitLength* fy;
@property (nonatomic, strong, nullable) IJSVGUnitLength* fr;
@property (nonatomic, strong, nullable) IJSVGUnitLength* r;

@end

NS_ASSUME_NONNULL_END
