//
//  IJSVGRoundedShape.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGPath.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGRoundedShape : IJSVGPath
@property (nonatomic, strong, nullable) IJSVGUnitLength* rx;
@property (nonatomic, strong, nullable) IJSVGUnitLength* ry;

@end

NS_ASSUME_NONNULL_END
