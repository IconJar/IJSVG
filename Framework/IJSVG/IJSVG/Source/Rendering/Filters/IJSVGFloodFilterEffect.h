//
//  IJSVGFloodFilterEffect.h
//  IJSVG
//
//  Created by Curtis Hard on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterEffect.h>

@interface IJSVGFloodFilterEffect : IJSVGFilterEffect

+ (CGColorRef)colorForPrimitive:(IJSVGFilterPrimitive*)primitive;
+ (CGFloat)opacityForPrimitive:(IJSVGFilterPrimitive*)primitive;

@end
