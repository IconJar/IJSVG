//
//  IJSVGLine.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGPath.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGLine : IJSVGPath
@property (nonatomic, strong, nullable) IJSVGUnitLength* x1;
@property (nonatomic, strong, nullable) IJSVGUnitLength* y1;
@property (nonatomic, strong, nullable) IJSVGUnitLength* x2;
@property (nonatomic, strong, nullable) IJSVGUnitLength* y2;

@end

NS_ASSUME_NONNULL_END
