//
//  IJSVGImage.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTraitedColorStorage.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGExporter.h>
#import <IJSVG/IJSVGGradientLayer.h>
#import <IJSVG/IJSVGGroupLayer.h>
#import <IJSVG/IJSVGRootLayer.h>
#import <IJSVG/IJSVGImageLayer.h>
#import <IJSVG/IJSVGLayerTree.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGRendering.h>
#import <IJSVG/IJSVGStyle.h>
#import <IJSVG/IJSVGTransaction.h>
#import <Foundation/Foundation.h>

@class IJSVG;
@class IJSVGParser;

@interface IJSVG : NSObject <NSPasteboardWriting> {

@private
    IJSVGRootNode* _rootNode;
    IJSVGLayerTree* _layerTree;
    CGRect _viewBox;
    CGFloat _backingScale;
    IJSVGUnitSize* _intrinsicSize;
    IJSVGParser* _parser;
}

// set this to be called when the layer is about to draw, it will call this
// and ask for the scale of the backing store where its going to be drawn
// and apply the scale to each layer that has custom drawing against it, mainly
// pattern and gradient layers
@property (nonatomic, copy) IJSVGRenderingBackingScaleFactorHelper renderingBackingScaleHelper;

// global overwriting rules for when rendering an SVG, this will overide any
// fillColor, strokeColor, pattern and gradient fill
@property (nonatomic, assign) IJSVGRenderQuality renderQuality;
@property (nonatomic, strong) IJSVGStyle* style;

@property (nonatomic, copy) NSString* title;
@property (nonatomic, copy) NSString* desc;
@property (nonatomic, strong) IJSVGLayerTree* layerTree;
@property (nonatomic, strong) IJSVGRootLayer* rootLayer;
@property (nonatomic, assign) BOOL ignoreIntrinsicSize;

@property (nonatomic, readonly) IJSVGTraitedColorStorage* colors;

// The size of the SVG either computed by its intrinsicSize of its viewBox
// If the size if % values, it will use the defaultSize
@property (nonatomic, readonly) CGSize size;

// Will return true if the intrinsic size is a % value
@property (nonatomic, readonly) BOOL hasDynamicSize;

// This is used when the intrinsic size is a % value, e.g. 100% x 100%
@property (nonatomic, assign) CGSize defaultSize;

// bitmask of which dimentions were implicitly set on the SVG
@property (nonatomic, readonly) IJSVGIntrinsicDimensions intrinsicDimensions;

- (void)prepForDrawingInView:(NSView*)view;
- (IJSVGRootNode*)rootNode;
- (CGRect)viewBox;
- (CGSize)sizeWithDefaultSize:(CGSize)size;
- (CGSize)sizeByMaintainingAspectRatioWithSize:(CGSize)aSize;
- (NSString*)identifier;
- (NSSet<IJSVG*>*)directDescendSVGs;
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

+ (id)SVGNamed:(NSString*)string;

+ (IJSVG*)SVGFromCGPathRef:(CGPathRef)path;
+ (IJSVG*)SVGFromCGPathRef:(CGPathRef)path
                   flipped:(BOOL)flipped;


- (id)initWithImage:(NSImage*)image;
- (id)initWithRootNode:(IJSVGRootNode*)rootNode;

- (id)initWithSVGLayer:(IJSVGGroupLayer*)group
               viewBox:(CGRect)viewBox;

- (id)initWithSVGString:(NSString*)string;
- (id)initWithSVGString:(NSString*)string
                  error:(NSError**)error;

- (id)initWithSVGData:(NSData*)data;
- (id)initWithSVGData:(NSData*)data
                error:(NSError**)error;

- (id)initWithFile:(NSString*)file;
- (id)initWithFile:(NSString*)file
             error:(NSError**)error;
- (id)initWithFilePathURL:(NSURL*)aURL;
- (id)initWithFilePathURL:(NSURL*)aURL
                    error:(NSError**)error;

- (id)initWithDataAssetNamed:(NSDataAssetName)name
                       error:(NSError**)error;
- (id)initWithDataAssetNamed:(NSDataAssetName)name
                      bundle:(NSBundle*)bundle
                       error:(NSError**)error;

- (NSImage*)imageWithSize:(CGSize)aSize;
- (NSImage*)imageWithSize:(CGSize)aSize
                    error:(NSError**)error;
- (NSImage*)imageWithSize:(CGSize)aSize
                  flipped:(BOOL)flipped;
- (NSImage*)imageWithSize:(CGSize)aSize
                  flipped:(BOOL)flipped
                    error:(NSError**)error;
- (NSImage*)imageByMaintainingAspectRatioWithSize:(CGSize)aSize
                                          flipped:(BOOL)flipped
                                            error:(NSError**)error;
- (CGImageRef)newCGImageRefWithSize:(CGSize)size
                            flipped:(BOOL)flipped
                              error:(NSError**)error;

- (BOOL)drawAtPoint:(CGPoint)point
               size:(CGSize)size;
- (BOOL)drawAtPoint:(CGPoint)point
               size:(CGSize)aSize
              error:(NSError**)error;
- (BOOL)drawInRect:(CGRect)rect;
- (BOOL)drawInRect:(CGRect)rect
             error:(NSError**)error;
- (void)drawInRect:(CGRect)rect
           context:(CGContextRef)context;

- (NSData*)PDFData;
- (NSData*)PDFData:(NSError**)error;
- (NSData*)PDFDataWithRect:(CGRect)rect;
- (NSData*)PDFDataWithRect:(CGRect)rect
                     error:(NSError**)error;

// call this to invalidate the render tree when you change the style
- (void)setNeedsDisplay;

// colors
- (void)performBlock:(dispatch_block_t)block;

// matching
- (BOOL)containsNodesMatchingTraits:(IJSVGNodeTraits)mask;
@end
