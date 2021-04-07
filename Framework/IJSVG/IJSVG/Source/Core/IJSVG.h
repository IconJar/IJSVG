//
//  IJSVGImage.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGColorList.h"
#import "IJSVGExporter.h"
#import "IJSVGGradientLayer.h"
#import "IJSVGGroupLayer.h"
#import "IJSVGImageLayer.h"
#import "IJSVGLayerTree.h"
#import "IJSVGParser.h"
#import "IJSVGRendering.h"
#import "IJSVGRenderingStyle.h"
#import "IJSVGTransaction.h"
#import <Foundation/Foundation.h>

@class IJSVG;

@protocol IJSVGDelegate <NSObject, IJSVGParserDelegate>

@optional
- (BOOL)svg:(IJSVG*)svg
    shouldHandleForeignObject:(IJSVGForeignObject*)foreignObject;
- (void)svg:(IJSVG*)svg
    handleForeignObject:(IJSVGForeignObject*)foreignObject
               document:(NSXMLDocument*)document;
- (void)svg:(IJSVG*)svg
      foundSubSVG:(IJSVG*)subSVG
    withSVGString:(NSString*)subSVGString;

@end

@interface IJSVG : NSObject <NSPasteboardWriting, IJSVGParserDelegate> {

@private
    IJSVGParser* _group;
    CGFloat _scale;
    CGFloat _clipScale;
    id<IJSVGDelegate> _delegate;
    IJSVGLayer* _layerTree;
    CGRect _viewBox;
    CGFloat _backingScaleFactor;
    CGFloat _lastProposedBackingScale;
    IJSVGRenderQuality _lastProposedRenderQuality;
    CGFloat _backingScale;
    NSMutableDictionary* _replacementColors;

    struct {
        unsigned int shouldHandleForeignObject : 1;
        unsigned int handleForeignObject : 1;
        unsigned int shouldHandleSubSVG : 1;
    } _respondsTo;
}

// set this to be called when the layer is about to draw, it will call this
// and ask for the scale of the backing store where its going to be drawn
// and apply the scale to each layer that has custom drawing against it, mainly
// pattern and gradient layers
@property (nonatomic, copy) IJSVGRenderingBackingScaleFactorHelper renderingBackingScaleHelper;

// global overwriting rules for when rendering an SVG, this will overide any
// fillColor, strokeColor, pattern and gradient fill
@property (nonatomic, assign) IJSVGRenderQuality renderQuality;
@property (nonatomic, assign) BOOL clipToViewport;
@property (nonatomic, retain) IJSVGRenderingStyle* renderingStyle;
@property (nonatomic, readonly) IJSVGUnitSize * intrinsicSize;
@property (nonatomic, copy) NSString* title;
@property (nonatomic, copy) NSString* desc;

- (void)prepForDrawingInView:(NSView*)view;
- (BOOL)isFont;
- (IJSVGGroup*)rootNode;
- (NSRect)viewBox;
- (NSArray<IJSVGPath*>*)glyphs;
- (NSString*)identifier;
- (IJSVGLayer*)layer;
- (IJSVGLayer*)layerWithTree:(IJSVGLayerTree*)tree;
- (NSArray<IJSVG*>*)subSVGs:(BOOL)recursive;
- (NSString*)SVGStringWithOptions:(IJSVGExporterOptions)options;
- (NSString*)SVGStringWithOptions:(IJSVGExporterOptions)options
             floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;

- (CGFloat)computeBackingScale:(CGFloat)scale;
- (void)discardDOM;

+ (id)svgNamed:(NSString*)string;
+ (id)svgNamed:(NSString*)string
      delegate:(id<IJSVGDelegate>)delegate;

- (id)initWithImage:(NSImage*)image;

- (id)initWithSVGLayer:(IJSVGGroupLayer*)group
               viewBox:(NSRect)viewBox;

- (id)initWithSVGString:(NSString*)string
                  error:(NSError**)error
               delegate:(id<IJSVGDelegate>)delegate;

- (id)initWithSVGString:(NSString*)string;
- (id)initWithSVGString:(NSString*)string
                  error:(NSError**)error;

- (id)initWithSVGData:(NSData*)data;
- (id)initWithSVGData:(NSData*)data
                error:(NSError**)error;

- (id)initWithFile:(NSString*)file;
- (id)initWithFile:(NSString*)file
             error:(NSError**)error;
- (id)initWithFile:(NSString*)file
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFile:(NSString*)file
             error:(NSError**)error
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFilePathURL:(NSURL*)aURL;
- (id)initWithFilePathURL:(NSURL*)aURL
                    error:(NSError**)error;
- (id)initWithFilePathURL:(NSURL*)aURL
                 delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFilePathURL:(NSURL*)aURL
                    error:(NSError**)error
                 delegate:(id<IJSVGDelegate>)delegate;

- (id)initWithDataAssetNamed:(NSDataAssetName)name
                       error:(NSError**)error;
- (id)initWithDataAssetNamed:(NSDataAssetName)name
                      bundle:(NSBundle*)bundle
                       error:(NSError**)error;

- (NSImage*)imageWithSize:(NSSize)aSize;
- (NSImage*)imageWithSize:(NSSize)aSize
                    error:(NSError**)error;
- (NSImage*)imageWithSize:(NSSize)aSize
                  flipped:(BOOL)flipped;
- (NSImage*)imageWithSize:(NSSize)aSize
                  flipped:(BOOL)flipped
                    error:(NSError**)error;
- (NSImage*)imageByMaintainingAspectRatioWithSize:(NSSize)aSize
                                          flipped:(BOOL)flipped
                                            error:(NSError**)error;
- (CGImageRef)newCGImageRefWithSize:(CGSize)size
                            flipped:(BOOL)flipped
                              error:(NSError**)error;

- (BOOL)drawAtPoint:(NSPoint)point
               size:(NSSize)size;
- (BOOL)drawAtPoint:(NSPoint)point
               size:(NSSize)aSize
              error:(NSError**)error;
- (BOOL)drawInRect:(NSRect)rect;
- (BOOL)drawInRect:(NSRect)rect
             error:(NSError**)error;
- (void)drawInRect:(NSRect)rect
           context:(CGContextRef)context;

- (NSData*)PDFData;
- (NSData*)PDFData:(NSError**)error;
- (NSData*)PDFDataWithRect:(NSRect)rect;
- (NSData*)PDFDataWithRect:(NSRect)rect
                     error:(NSError**)error;

- (void)beginVectorDraw;
- (void)endVectorDraw;

- (NSRect)computeOriginalDrawingFrameWithSize:(NSSize)aSize;
- (void)setNeedsDisplay;

// colors
- (IJSVGColorList*)computedColorList:(BOOL*)hasPatternFills;
- (void)performBlock:(dispatch_block_t)block;
@end
