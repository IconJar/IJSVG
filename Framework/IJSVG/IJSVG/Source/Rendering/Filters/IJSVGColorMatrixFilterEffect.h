//
//  IJSVGColorMatrixFilterEffect.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterEffect.h>

@interface IJSVGColorMatrixFilterEffect : IJSVGFilterEffect

+ (NSDictionary*)preparedMatrixForPrimitive:(IJSVGFilterPrimitive*)primitive;

@end
