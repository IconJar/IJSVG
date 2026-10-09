//
//  IJSVGShapePaint.h
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGPaint.h>
#import <IJSVG/IJSVGPath.h>

@interface IJSVGShapePaint : IJSVGPaint

@property (nonatomic, assign) CGPathRef path;
@property (nonatomic, assign) CGColorRef fillColor;
@property (nonatomic, assign) CGColorRef strokeColor;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, assign) BOOL nonScalingStroke;
// Linear map from local geometry to the outer SVG viewport (excludes backing scale).
@property (nonatomic, assign) CGAffineTransform strokeHostTransform;
@property (nonatomic, assign) CGLineCap lineCap;
@property (nonatomic, assign) CGLineJoin lineJoin;
@property (nonatomic, assign) CGFloat miterLimit;
@property (nonatomic, copy) NSArray<NSNumber*>* lineDashPattern;
@property (nonatomic, assign) CGFloat lineDashPhase;
@property (nonatomic, assign) IJSVGPrimitivePathType primitiveType;
// Resolved fill, stroke paint, and stroke geometry shared with vector export.
@property (nonatomic, strong) IJSVGPaint* fillPaint;
@property (nonatomic, strong) IJSVGPaint* strokePaint;
@property (nonatomic, strong) IJSVGShapePaint* strokeStyle;

@end
