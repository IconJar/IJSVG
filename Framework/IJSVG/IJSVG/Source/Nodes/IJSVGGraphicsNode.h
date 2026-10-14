//
//  IJSVGGraphicsNode.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGPaintNode.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IJSVGTransformBox) {
    IJSVGTransformBoxUnspecified = 0,
    IJSVGTransformBoxViewBox,
    IJSVGTransformBoxFillBox,
    IJSVGTransformBoxStrokeBox,
    IJSVGTransformBoxContentBox,
    IJSVGTransformBoxBorderBox
};

@interface IJSVGGraphicsNode : IJSVGPaintNode

@property (nonatomic, strong, nullable) IJSVGMarker* markerStart;
@property (nonatomic, strong, nullable) IJSVGMarker* markerMid;
@property (nonatomic, strong, nullable) IJSVGMarker* markerEnd;
@property (nonatomic, strong, nullable) IJSVGUnitLength* x;
@property (nonatomic, strong, nullable) IJSVGUnitLength* y;
@property (nonatomic, strong, nullable) IJSVGUnitLength* width;
@property (nonatomic, strong, nullable) IJSVGUnitLength* height;
@property (nonatomic, strong, nullable) IJSVGUnitLength* opacity;
@property (nonatomic, strong, nullable) IJSVGUnitLength* strokeOpacity;
@property (nonatomic, strong, nullable) IJSVGUnitLength* strokeWidth;
@property (nonatomic, strong, nullable) IJSVGNode* stroke;
@property (nonatomic, strong, nullable) IJSVGClipPath* clipPath;
@property (nonatomic, strong, nullable) IJSVGMask* mask;
@property (nonatomic, strong, nullable) IJSVGFilter* filter;
@property (nonatomic, copy, nullable) NSArray<IJSVGFilter*>* filters;
@property (nonatomic, assign) IJSVGColorInterpolation filterColorInterpolation;
@property (nonatomic, readonly) IJSVGColorInterpolation resolvedFilterColorInterpolation;
@property (nonatomic, assign) IJSVGBackgroundEnabled backgroundEnabled;
@property (nonatomic, assign) CGRect backgroundBounds;
@property (nonatomic, readonly) CGRect backgroundRect;
@property (nonatomic, assign) IJSVGWindingRule windingRule;
@property (nonatomic, assign) IJSVGWindingRule clipRule;
@property (nonatomic, assign) IJSVGLineCapStyle lineCapStyle;
@property (nonatomic, assign) IJSVGLineJoinStyle lineJoinStyle;
@property (nonatomic, strong, nullable) IJSVGUnitLength* strokeMiterLimit;
@property (nonatomic, strong, nullable) NSArray<IJSVGTransform*>* transforms;
@property (nonatomic, copy, nullable) NSArray<IJSVGUnitLength*>* transformOrigin;
@property (nonatomic, assign) IJSVGTransformBox transformBox;
@property (nonatomic, assign, nullable) CGFloat* strokeDashArray;
@property (nonatomic, assign) NSInteger strokeDashArrayCount;
@property (nonatomic, readonly) NSArray<NSNumber*>* lineDashPattern;
@property (nonatomic, copy, nullable) NSArray<IJSVGUnitLength*>* strokeDashLengths;
@property (nonatomic, strong, nullable) IJSVGUnitLength* strokeDashOffset;
@property (nonatomic, assign) IJSVGUnitType contentUnits;
@property (nonatomic, assign) IJSVGUnitType units;
@property (nonatomic, assign) IJSVGBlendMode blendMode;
@property (nonatomic, assign) BOOL isolated;
@property (nonatomic, assign) IJSVGPaintOrder paintOrder;
@property (nonatomic, copy, nullable) NSDictionary<NSNumber*, IJSVGUnitLength*>* geometryLengths;
@property (nonatomic, assign) IJSVGVectorEffect vectorEffect;
@property (nonatomic, readonly) IJSVGVectorEffect resolvedVectorEffect;
@property (nonatomic, assign) IJSVGOverflowVisibility overflowVisibility;

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect*)bounds;
- (IJSVGUnitType)contentUnitsWithReferencingNode:(IJSVGGraphicsNode* _Nonnull* _Nonnull)referencingNode;

@end

NS_ASSUME_NONNULL_END
