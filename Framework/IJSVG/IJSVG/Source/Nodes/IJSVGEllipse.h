//
//  IJSVGEllipse.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRoundedShape.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGEllipse : IJSVGRoundedShape
@property (nonatomic, strong, nullable) IJSVGUnitLength* cx;
@property (nonatomic, strong, nullable) IJSVGUnitLength* cy;

@end

NS_ASSUME_NONNULL_END
