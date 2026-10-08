//
//  IJSVGPaint.h
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGRendering.h>

typedef NS_ENUM(NSUInteger, IJSVGPaintFillType) {
    IJSVGPaintFillTypeUnknown,
    IJSVGPaintFillTypeColor,
    IJSVGPaintFillTypeGradient,
    IJSVGPaintFillTypePattern
};

typedef NS_OPTIONS(NSUInteger, IJSVGPaintDrawingOptions) {
    IJSVGPaintDrawingOptionNone = 0,
    IJSVGPaintDrawingOptionIgnoreClipping = 1 << 1
};

// Resolved drawing data. Paints own CG resources and never allocate CA objects.
@interface IJSVGPaint : NSObject

@property (nonatomic, strong) IJSVGNode* sourceNode;
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
@property (nonatomic, assign) CGBlendMode blendingMode;
@property (nonatomic, assign) CGFloat backingScaleFactor;
@property (nonatomic, assign) IJSVGRenderQuality renderQuality;
@property (nonatomic, readonly) BOOL treatImplicitOriginAsTransform;

+ (instancetype)paint;
+ (IJSVGPaintFillType)fillTypeForFill:(id)fill;
+ (CGRect)calculateFrameForChildren:(NSArray<IJSVGPaint*>*)children;
+ (CGAffineTransform)userSpaceTransformForPaint:(IJSVGPaint*)paint;
+ (IJSVGPaint*)rootPaintForPaint:(IJSVGPaint*)paint;
+ (void)setBackingScaleFactor:(CGFloat)scale
                renderQuality:(IJSVGRenderQuality)quality
           recursivelyToPaint:(IJSVGPaint*)paint;
+ (void)renderPaint:(IJSVGPaint*)paint
          inContext:(CGContextRef)ctx
            options:(IJSVGPaintDrawingOptions)options;
+ (void)clipContextWithMask:(IJSVGPaint*)mask
                    toPaint:(IJSVGPaint*)paint
                  inContext:(CGContextRef)ctx
               drawingBlock:(dispatch_block_t)drawingBlock;
// Enable raster reuse only after a mask's resolved geometry is finalized.
// Rebuild the resolved graph when its artwork changes.
- (void)prepareMaskCaching;
- (void)addChild:(IJSVGPaint*)paint;
- (void)renderInContext:(CGContextRef)ctx;
- (void)drawInContext:(CGContextRef)ctx;
- (void)drawContentsInContext:(CGContextRef)ctx;
- (void)performRenderInContext:(CGContextRef)ctx;
- (CGRect)transparencyBounds;

@end

CGRect IJSVGPaintGetBoundingBoxBounds(IJSVGPaint* paint);
