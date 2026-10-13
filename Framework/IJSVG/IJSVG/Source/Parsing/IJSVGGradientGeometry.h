//
//  IJSVGGradientGeometry.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGRadialGradient.h>

@interface IJSVGGradientGeometry : NSObject
@property (nonatomic, readonly) IJSVGUnitType units;
- (instancetype)initWithLinearGradient:(IJSVGLinearGradient*)gradient;
- (instancetype)initWithRadialGradient:(IJSVGRadialGradient*)gradient;
- (void)applyToLinearGradient:(IJSVGLinearGradient*)gradient;
- (void)applyToRadialGradient:(IJSVGRadialGradient*)gradient;
@end
