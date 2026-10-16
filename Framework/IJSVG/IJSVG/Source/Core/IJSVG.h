//
//  IJSVG.h
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGExporter.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGRendering.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGStyle.h>
#import <IJSVG/IJSVGTraitedColorStorage.h>
#import <IJSVG/IJSVGUnitSize.h>

@class IJSVG;
@class IJSVGParser;

NS_ASSUME_NONNULL_BEGIN

@interface IJSVG : NSObject {
@private
    IJSVGRootNode* _rootNode;
    CGRect _viewBox;
    CGFloat _backingScale;
    IJSVGUnitSize* _intrinsicSize;
    IJSVGParser* _parser;
    IJSVGRenderingOptions* _renderingOptions;
}

// Supplies the backing scale for Quartz rendering.
@property (nonatomic, copy, nullable) IJSVGRenderingBackingScaleFactorHelper renderingBackingScaleHelper;

// Global overwriting rules for when rendering an SVG, this will overide any
// fillColor, strokeColor, pattern and gradient fill.
// Reads and writes independent snapshots. Reassign edited options to apply
// them.
@property (nonatomic, copy, nullable) IJSVGRenderingOptions* renderingOptions;

@property (nonatomic, strong, nullable) IJSVGStyle* style;

@property (nonatomic, copy, nullable) NSString* title;
@property (nonatomic, copy, nullable) NSString* desc;

@property (nonatomic, readonly, nullable) IJSVGTraitedColorStorage* colors;

// The size of the SVG either computed by its intrinsicSize of its viewBox
// If the size if % values, it will use the defaultSize
@property (nonatomic, readonly) CGSize size;

// The unresolved unit backed intrinsic size of the SVG.
@property (nonatomic, readonly, nullable) IJSVGUnitSize* intrinsicUnitSize;

// Will return true if the intrinsic size is a % value
@property (nonatomic, readonly) BOOL hasDynamicSize;

// Bitmask of which dimensions were implicitly set on the SVG
@property (nonatomic, readonly) IJSVGIntrinsicDimensions intrinsicDimensions;

- (IJSVGRootNode* _Nullable)rootNode;
- (CGRect)viewBox;

// Cached measurements, call setNeedsDisplay after node or style edits.
// Painted bounds in viewBox coordinates, excluding filters.
- (CGRect)artworkBounds;

// Conservative extent including enabled filters, before viewport clipping.
- (CGRect)artworkExtent;

// Cached proof that painted geometry is outside the viewBox. Query before
// fitting. NO includes unknown, does not detect overlap by other nodes.
- (BOOL)isNodeOutsideViewBox:(IJSVGNode*)node NS_SWIFT_NAME(isNodeOutsideViewBox(_:));

// Fits painted geometry into the viewBox while preserving canvas size and
// aspect ratio. Call after geometry or style changes. Passing NO removes the
// previous fitting scale.
- (void)fitArtworkToViewBox:(BOOL)enabled NS_SWIFT_NAME(fitArtworkToViewBox(enabled:));

// Fits the completed effects as well as geometry when requested.
- (void)fitArtworkToViewBox:(BOOL)enabled includingFilters:(BOOL)includingFilters NS_SWIFT_NAME(fitArtworkToViewBox(enabled:includingFilters:));

// Temporarily hides outside nodes via shouldRender. Reapply after edits.
// Disabling fitting or this option restores their flags.
- (void)fitArtworkToViewBox:(BOOL)enabled ignoringNodesOutsideViewBox:(BOOL)ignoreOutside NS_SWIFT_NAME(fitArtworkToViewBox(enabled:ignoringNodesOutsideViewBox:));
- (void)fitArtworkToViewBox:(BOOL)enabled includingFilters:(BOOL)includingFilters ignoringNodesOutsideViewBox:(BOOL)ignoreOutside NS_SWIFT_NAME(fitArtworkToViewBox(enabled:includingFilters:ignoringNodesOutsideViewBox:));

- (CGSize)sizeByMaintainingAspectRatioWithSize:(CGSize)aSize;
- (NSString* _Nullable)identifier;
- (NSSet<IJSVG*>*)directDescendSVGs;
- (IJSVGExporter*)exporterWithSize:(CGSize)size options:(IJSVGExporterOptions)options floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
- (NSString*)SVGStringWithSize:(CGSize)size options:(IJSVGExporterOptions)options;
- (NSString*)SVGStringWithSize:(CGSize)size options:(IJSVGExporterOptions)options floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
- (NSString*)SVGStringWithOptions:(IJSVGExporterOptions)options;
- (NSString*)SVGStringWithOptions:(IJSVGExporterOptions)options floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;

+ (nullable instancetype)SVGNamed:(NSString*)string;

+ (IJSVG*)SVGFromCGPathRef:(CGPathRef)path;
+ (IJSVG*)SVGFromCGPathRef:(CGPathRef)path flipped:(BOOL)flipped;

- (instancetype)initWithCGImage:(CGImageRef)image NS_SWIFT_NAME(init(cgImage:));
- (instancetype)initWithRootNode:(IJSVGRootNode*)rootNode;

// Returns nil when parsing fails. Use init(parsing:) in Swift to receive
// errors.
- (nullable instancetype)initWithSVGString:(NSString*)string;
- (nullable instancetype)initWithSVGString:(NSString*)string error:(NSError* _Nullable* _Nullable)error NS_SWIFT_NAME(init(parsing:));

- (nullable instancetype)initWithSVGData:(NSData*)data;
- (nullable instancetype)initWithSVGData:(NSData*)data error:(NSError* _Nullable* _Nullable)error NS_SWIFT_NAME(init(data:));

- (nullable instancetype)initWithFile:(NSString*)file;
- (nullable instancetype)initWithFile:(NSString*)file error:(NSError* _Nullable* _Nullable)error NS_SWIFT_NAME(init(filePath:));
- (nullable instancetype)initWithFilePathURL:(NSURL*)aURL;
- (nullable instancetype)initWithFilePathURL:(NSURL*)aURL error:(NSError* _Nullable* _Nullable)error NS_SWIFT_NAME(init(contentsOf:));

// Renders using sRGB by default. Output scale defaults to 1 on every platform.
- (CGImageRef _Nullable)newCGImageRefWithSize:(CGSize)size flipped:(BOOL)flipped error:(NSError* _Nullable* _Nullable)error CF_RETURNS_RETAINED NS_SWIFT_NAME(renderCGImage(size:flipped:));

// Renders into an RGB bitmap with 8 bits per component in the supplied destination color space.
// The color space is borrowed. The returned image is owned by the caller.
// Unsupported spaces or bitmap creation failures return NULL and IJSVGErrorDrawing.
- (CGImageRef _Nullable)newCGImageRefWithSize:(CGSize)size flipped:(BOOL)flipped colorSpace:(CGColorSpaceRef)colorSpace error:(NSError* _Nullable* _Nullable)error CF_RETURNS_RETAINED NS_SWIFT_NAME(renderCGImage(size:flipped:colorSpace:));

- (void)drawInRect:(CGRect)rect context:(CGContextRef)context;
- (BOOL)drawInRect:(CGRect)rect context:(CGContextRef)context error:(NSError* _Nullable* _Nullable)error;

// PDF output is nonnull even when drawing reports an error. Swift checks the
// error itself.
- (NSData*)PDFData NS_SWIFT_NAME(pdfData());
- (NSData*)PDFData:(NSError* _Nullable* _Nullable)error __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(renderPDF());
- (NSData*)PDFDataWithRect:(CGRect)rect NS_SWIFT_NAME(pdfData(in:));
- (NSData*)PDFDataWithRect:(CGRect)rect error:(NSError* _Nullable* _Nullable)error __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(renderPDF(in:));

- (CGPathRef _Nullable)outlinePathIncludingFilterExtents:(BOOL)includingFilterExtents preservingHoles:(BOOL)preservingHoles CF_RETURNS_NOT_RETAINED NS_SWIFT_NAME(outlinePath(includingFilterExtents:preservingHoles:));

// call this to invalidate the render tree when you change the style
- (void)setNeedsDisplay;

// colors
- (void)performBlock:(dispatch_block_t)block;

// matching
- (BOOL)containsNodesMatchingTraits:(IJSVGNodeTraits)mask;
@end

NS_ASSUME_NONNULL_END
