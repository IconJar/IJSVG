//
//  IJSVGGradientPaint.h
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGPaint.h>
#import <IJSVG/IJSVGGradient.h>

@interface IJSVGGradientPaint : IJSVGPaint

@property (nonatomic, strong) IJSVGGradient* gradient;
@property (nonatomic, assign) CGRect viewBox;

@end
