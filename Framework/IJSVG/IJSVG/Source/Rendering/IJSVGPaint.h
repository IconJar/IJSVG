//
//  IJSVGPaint.h
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGraphicsNode.h>
#import <IJSVG/IJSVGRendering.h>

typedef NS_ENUM(NSUInteger, IJSVGPaintFillType) {
    IJSVGPaintFillTypeUnknown,
    IJSVGPaintFillTypeColor,
    IJSVGPaintFillTypeGradient,
    IJSVGPaintFillTypePattern
};

typedef NS_OPTIONS(NSUInteger, IJSVGPaintTraits) {
    IJSVGPaintTraitNone = 0,
    IJSVGPaintTraitFilter = 1 << 0,
    IJSVGPaintTraitPattern = 1 << 1,
    IJSVGPaintTraitShape = 1 << 2,
    IJSVGPaintTraitRoot = 1 << 3,
    IJSVGPaintTraitGroup = 1 << 4,
    IJSVGPaintTraitImage = 1 << 5,
    IJSVGPaintTraitGradient = 1 << 6,
    IJSVGPaintTraitTransform = 1 << 7
};

typedef NS_OPTIONS(NSUInteger, IJSVGPaintDrawingOptions) {
    IJSVGPaintDrawingOptionNone = 0,
    IJSVGPaintDrawingOptionIgnoreClipping = 1 << 1
};

typedef NS_ENUM(uint8_t, IJSVGBuiltInPaintKind) {
    IJSVGBuiltInPaintCustom = 0,
    IJSVGBuiltInPaintBase,
    IJSVGBuiltInPaintGroup,
    IJSVGBuiltInPaintTransform,
    IJSVGBuiltInPaintShape,
    IJSVGBuiltInPaintRect,
    IJSVGBuiltInPaintStroke,
    IJSVGBuiltInPaintRoot,
    IJSVGBuiltInPaintGradient,
    IJSVGBuiltInPaintPattern,
    IJSVGBuiltInPaintImage,
};

// Resolved drawing data. Paints own CG resources and never allocate CA objects.
@interface IJSVGPaint : NSObject {
@package
    IJSVGBuiltInPaintKind _builtInPaintKind;
}

@property (nonatomic, strong) IJSVGGraphicsNode* sourceNode;

// Keeps an instance copy alive when redundant container paints are omitted.
@property (nonatomic, strong) IJSVGGraphicsNode* contextPaintOwner;
@property (nonatomic, assign) CGRect viewPort;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, assign) CGRect boundingBox;
@property (nonatomic, assign) CGRect outerBoundingBox;
@property (nonatomic, readonly) CGRect innerBoundingBox;
@property (nonatomic, assign) CGAffineTransform affineTransform;

// Maps local geometry into parent coordinates using the original frame.
@property (nonatomic, readonly) CGAffineTransform placementTransform;
@property (nonatomic, copy) NSArray<IJSVGPaint*>* children;
@property (nonatomic, weak) IJSVGPaint* parentPaint;
@property (nonatomic, weak) IJSVGPaint* referencingPaint;
@property (nonatomic, strong) IJSVGPaint* maskPaint;
@property (nonatomic, copy) NSArray<IJSVGPaint*>* clipPaints;
@property (nonatomic, assign) CGPathRef clipPath;
@property (nonatomic, assign) IJSVGWindingRule clipRule;
@property (nonatomic, assign) IJSVGWindingRule fillRule;

// Raster coverage includes filters without changing mask coordinate placement.
@property (nonatomic, assign) CGRect maskingSourceBounds;
@property (nonatomic, assign) CGRect maskingBoundingBox;
@property (nonatomic, assign) CGRect maskingClippingRect;
@property (nonatomic, assign) CGRect clippingBoundingBox;
@property (nonatomic, assign) CGAffineTransform clippingTransform;
@property (nonatomic, assign) CGFloat opacity;
@property (nonatomic, assign) BOOL hidden;
@property (nonatomic, assign) BOOL hiddenByVisibility;
@property (nonatomic, assign) CGBlendMode blendingMode;
@property (nonatomic, assign) BOOL isolated;
@property (nonatomic, assign) IJSVGShapeRendering shapeRendering;
@property (nonatomic, assign) IJSVGImageRendering imageRendering;
@property (nonatomic, assign) CGFloat backingScaleFactor;
@property (nonatomic, assign) IJSVGRenderQuality renderQuality;
@property (nonatomic, readonly) BOOL treatImplicitOriginAsTransform;

// Subclasses inherit paint traits without walking the class hierarchy.
@property (nonatomic, readonly) IJSVGPaintTraits paintTraits;

+ (instancetype)paint;
+ (IJSVGPaintFillType)fillTypeForFill:(IJSVGNode*)fill;
+ (CGRect)calculateFrameForChildren:(NSArray<IJSVGPaint*>*)children;

// Object bounding box resources use geometry bounds, excluding strokes.
+ (CGRect)calculateBoundingBoxForChildren:(NSArray<IJSVGPaint*>*)children;
+ (CGAffineTransform)userSpaceTransformForPaint:(IJSVGPaint*)paint;
+ (IJSVGPaint*)rootPaintForPaint:(IJSVGPaint*)paint;
+ (void)setBackingScaleFactor:(CGFloat)scale renderQuality:(IJSVGRenderQuality)quality recursivelyToPaint:(IJSVGPaint*)paint;
+ (void)renderPaint:(IJSVGPaint*)paint inContext:(CGContextRef)ctx options:(IJSVGPaintDrawingOptions)options;
+ (void)clipContextWithMask:(IJSVGPaint*)mask toPaint:(IJSVGPaint*)paint inContext:(CGContextRef)ctx drawingBlock:(dispatch_block_t)drawingBlock;

// Enable raster reuse only after a masks resolved geometry is finalized.
// Rebuild the resolved graph when its artwork changes.
- (void)prepareMaskCaching;

// Copies simple marker artwork with independent parent links and shared
// immutable resources. Returns nil when the artwork depends on its placement or
// rendering context.
- (IJSVGPaint*)copyForMarker;
- (void)addChild:(IJSVGPaint*)paint;
- (void)renderInContext:(CGContextRef)ctx;
- (void)drawInContext:(CGContextRef)ctx;
- (void)drawContentsInContext:(CGContextRef)ctx;
- (void)performRenderInContext:(CGContextRef)ctx;
- (CGRect)transparencyBounds;

@end

CGRect IJSVGPaintGetBoundingBoxBounds(IJSVGPaint* paint);

IJSVGPaint* IJSVGCreateBuiltInPaint(IJSVGBuiltInPaintKind kind);

static inline IJSVGBuiltInPaintKind IJSVGGetBuiltInPaintKind(IJSVGPaint* paint)
{
    return paint != nil ? paint->_builtInPaintKind : IJSVGBuiltInPaintCustom;
}
