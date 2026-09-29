//
//  IJSVGFilterEffect.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterContext.h>

// Stateless effects accept resolved CIImage inputs and return a lazy CIImage.
// Single input effects use inputs[0], binary effects use inputs[0...1], and
// merge consumes the entire ordered array. The graph owns final region clipping.
@interface IJSVGFilterEffect : NSObject
+ (instancetype)effectForType:(IJSVGNodeType)type;
- (BOOL)requiresSupersamplingForPrimitive:(IJSVGFilterPrimitive*)primitive;
- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context;
@end
