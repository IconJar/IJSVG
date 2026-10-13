//
//  IJSVGGradientPaint.h
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradient.h>
#import <IJSVGPaint.h>

@interface IJSVGGradientPaint : IJSVGPaint

@property (nonatomic, strong) IJSVGGradient* gradient;
@property (nonatomic, assign) CGRect viewBox;

@end
