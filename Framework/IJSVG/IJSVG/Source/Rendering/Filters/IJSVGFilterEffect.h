//
//  IJSVGFilterEffect.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterContext.h>

// Effects read their input images and return a Core Image result.
// Most effects use one or two inputs. Merge uses all inputs in order.
// The filter graph crops the final result.
@interface IJSVGFilterEffect : NSObject
+ (instancetype)effectForType:(IJSVGNodeType)type;
- (BOOL)requiresSupersamplingForPrimitive:(IJSVGFilterPrimitive*)primitive;
- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context;
@end
