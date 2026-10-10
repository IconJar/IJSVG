//
//  IJSVGClipPath.h
//  IJSVG
//
//  Created by Curtis Hard on 29/05/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>

@interface IJSVGClipPath : IJSVGGroup {
}

@property (nonatomic, readonly) IJSVGWindingRule computedClipRule;
@property (nonatomic, readonly) BOOL hasBasicShape;

+ (instancetype)clipPathWithBasicShape:(NSString*)value;
- (CGPathRef)newBasicShapePathWithFillBox:(CGRect)fillBox
                                strokeBox:(CGRect)strokeBox
                                  viewBox:(CGRect)viewBox
                           lengthResolver:(CGFloat (^)(IJSVGUnitLength* length, CGFloat percentage))resolver;

@end
