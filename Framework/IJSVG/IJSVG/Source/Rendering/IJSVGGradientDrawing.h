//
//  IJSVGGradientDrawing.h
//  IJSVG
//
//  Created by Curtis Hard on 25/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLinearGradient.h>

// Draw using prepared stops, or resolve the node normally when stops is NULL.
void IJSVGDrawLinearGradient(IJSVGLinearGradient* gradient, CGGradientRef stops,
    CGContextRef context, CGRect bounds, CGAffineTransform transform);
