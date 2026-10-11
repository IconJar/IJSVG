//
//  IJSVGFloodFilterEffect.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterEffect.h>

@interface IJSVGFloodFilterEffect : IJSVGFilterEffect

+ (NSColor*)colorForPrimitive:(IJSVGFilterPrimitive*)primitive;
+ (CGFloat)opacityForPrimitive:(IJSVGFilterPrimitive*)primitive;

@end
