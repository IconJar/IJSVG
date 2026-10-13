//
//  IJSVGCircle.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGPath.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGCircle : IJSVGPath
@property (nonatomic, strong, nullable) IJSVGUnitLength* cx;
@property (nonatomic, strong, nullable) IJSVGUnitLength* cy;
@property (nonatomic, strong, nullable) IJSVGUnitLength* r;

@end

NS_ASSUME_NONNULL_END
