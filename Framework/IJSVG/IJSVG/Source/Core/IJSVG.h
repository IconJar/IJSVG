//
//  IJSVG.h
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <TargetConditionals.h>

#import <IJSVG/IJSVGTraitedColorStorage.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGUnitSize.h>
#import <IJSVG/IJSVGExporter.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGRendering.h>
#import <IJSVG/IJSVGStyle.h>
#import <IJSVG/IJSVGXEntities.h>
#import <Foundation/Foundation.h>

@class IJSVG;
@class IJSVGParser;

NS_ASSUME_NONNULL_BEGIN

@interface IJSVG : NSObject
#if TARGET_OS_OSX
<NSPasteboardWriting>
#endif
{

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
// Reads and writes independent snapshots. Reassign edited options to apply them.
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

- (void)prepForDrawingInView:(XView* _Nullable)view;
- (IJSVGRootNode* _Nullable)rootNode;
- (CGRect)viewBox;
// Painted geometry in viewBox coordinates, excluding filter effects.
- (CGRect)artworkBounds;
// Fits painted geometry into the viewBox while preserving canvas size and aspect ratio.
// Call after geometry or style changes. Passing NO removes the previous fitting scale.
- (void)fitArtworkToViewBox:(BOOL)enabled NS_SWIFT_NAME(fitArtworkToViewBox(enabled:));
- (CGSize)sizeByMaintainingAspectRatioWithSize:(CGSize)aSize;
- (NSString* _Nullable)identifier;
- (NSSet<IJSVG*>*)directDescendSVGs;
#if TARGET_OS_OSX
- (IJSVGExporter*)exporterWithSize:(CGSize)size
                           options:(IJSVGExporterOptions)options
              floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
- (NSString*)SVGStringWithSize:(CGSize)size
                       options:(IJSVGExporterOptions)options;
- (NSString*)SVGStringWithSize:(CGSize)size
                       options:(IJSVGExporterOptions)options
          floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
- (NSString*)SVGStringWithOptions:(IJSVGExporterOptions)options;
- (NSString*)SVGStringWithOptions:(IJSVGExporterOptions)options
             floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
#endif

+ (nullable instancetype)SVGNamed:(NSString*)string;

+ (IJSVG*)SVGFromCGPathRef:(CGPathRef)path;
+ (IJSVG*)SVGFromCGPathRef:(CGPathRef)path
                   flipped:(BOOL)flipped;


- (instancetype)initWithImage:(XImage*)image;
- (instancetype)initWithRootNode:(IJSVGRootNode*)rootNode;

// Returns nil when parsing fails. Use init(parsing:) in Swift to receive errors.
- (nullable instancetype)initWithSVGString:(NSString*)string;
- (nullable instancetype)initWithSVGString:(NSString*)string
                  error:(NSError* _Nullable * _Nullable)error NS_SWIFT_NAME(init(parsing:));

- (nullable instancetype)initWithSVGData:(NSData*)data;
- (nullable instancetype)initWithSVGData:(NSData*)data
                error:(NSError* _Nullable * _Nullable)error NS_SWIFT_NAME(init(data:));

- (nullable instancetype)initWithFile:(NSString*)file;
- (nullable instancetype)initWithFile:(NSString*)file
             error:(NSError* _Nullable * _Nullable)error NS_SWIFT_NAME(init(filePath:));
- (nullable instancetype)initWithFilePathURL:(NSURL*)aURL;
- (nullable instancetype)initWithFilePathURL:(NSURL*)aURL
                    error:(NSError* _Nullable * _Nullable)error NS_SWIFT_NAME(init(contentsOf:));

- (nullable instancetype)initWithDataAssetNamed:(NSDataAssetName)name
                       error:(NSError* _Nullable * _Nullable)error;
- (nullable instancetype)initWithDataAssetNamed:(NSDataAssetName)name
                      bundle:(NSBundle*)bundle
                       error:(NSError* _Nullable * _Nullable)error;

- (XImage* _Nullable)imageWithSize:(CGSize)aSize;
- (XImage* _Nullable)imageWithSize:(CGSize)aSize
                    error:(NSError* _Nullable * _Nullable)error NS_SWIFT_NAME(renderImage(size:));
- (XImage* _Nullable)imageWithSize:(CGSize)aSize
                  flipped:(BOOL)flipped;
- (XImage* _Nullable)imageWithSize:(CGSize)aSize
                  flipped:(BOOL)flipped
                    error:(NSError* _Nullable * _Nullable)error NS_SWIFT_NAME(renderImage(size:flipped:));
- (XImage* _Nullable)imageByMaintainingAspectRatioWithSize:(CGSize)aSize
                                          flipped:(BOOL)flipped
                                            error:(NSError* _Nullable * _Nullable)error NS_SWIFT_NAME(renderImage(fitting:flipped:));
- (CGImageRef _Nullable)newCGImageRefWithSize:(CGSize)size
                            flipped:(BOOL)flipped
                              error:(NSError* _Nullable * _Nullable)error CF_RETURNS_RETAINED NS_SWIFT_NAME(renderCGImage(size:flipped:));

- (BOOL)drawAtPoint:(CGPoint)point
               size:(CGSize)size;
- (BOOL)drawAtPoint:(CGPoint)point
               size:(CGSize)aSize
              error:(NSError* _Nullable * _Nullable)error;
- (BOOL)drawInRect:(CGRect)rect;
- (BOOL)drawInRect:(CGRect)rect
             error:(NSError* _Nullable * _Nullable)error;
- (void)drawInRect:(CGRect)rect
           context:(CGContextRef)context;

// PDF output is nonnull even when drawing reports an error. Swift checks the error itself.
- (NSData*)PDFData NS_SWIFT_NAME(pdfData());
- (NSData*)PDFData:(NSError* _Nullable * _Nullable)error __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(renderPDF());
- (NSData*)PDFDataWithRect:(CGRect)rect NS_SWIFT_NAME(pdfData(in:));
- (NSData*)PDFDataWithRect:(CGRect)rect
                     error:(NSError* _Nullable * _Nullable)error __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(renderPDF(in:));

// call this to invalidate the render tree when you change the style
- (void)setNeedsDisplay;

// colors
- (void)performBlock:(dispatch_block_t)block;

// matching
- (BOOL)containsNodesMatchingTraits:(IJSVGNodeTraits)mask;
@end

NS_ASSUME_NONNULL_END
