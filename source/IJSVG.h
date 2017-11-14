//
//  IJSVGImage.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGParser.h"
#import "IJSVGBezierPathAdditions.h"
#import "IJSVGLayerTree.h"
#import "IJSVGGroupLayer.h"
#import "IJSVGImageLayer.h"

@class IJSVG;

void IJSVGBeginTransactionLock();
void IJSVGEndTransactionLock();
void IJSVGObtainTransactionLock(dispatch_block_t block, BOOL renderOnMainThread);

@protocol IJSVGDelegate <NSObject,IJSVGParserDelegate>

@optional
- (BOOL)svg:(IJSVG *)svg
shouldHandleForeignObject:(IJSVGForeignObject *)foreignObject;
- (void)svg:(IJSVG *)svg
handleForeignObject:(IJSVGForeignObject *)foreignObject
   document:(NSXMLDocument *)document;
- (void)svg:(IJSVG *)svg
foundSubSVG:(IJSVG *)subSVG
withSVGString:(NSString *)subSVGString;

@end

typedef CGFloat (^IJSVGRenderingBackingScaleFactorHelper)();

@interface IJSVG : NSObject <NSPasteboardWriting, IJSVGParserDelegate> {
    
@private
    IJSVGParser * _group;
    CGFloat _scale;
    CGFloat _clipScale;
    id<IJSVGDelegate> _delegate;
    IJSVGLayer * _layerTree;
    CGRect _viewBox;
    CGSize _proposedViewSize;
    CGFloat _lastProposedBackingScale;
    NSMutableDictionary * _replacementColors;
    
    struct {
        unsigned int shouldHandleForeignObject: 1;
        unsigned int handleForeignObject: 1;
        unsigned int shouldHandleSubSVG: 1;
    } _respondsTo;
    
}

// set this to be called when the layer is about to draw, it will call this
// and ask for the scale of the backing store where its going to be drawn
// and apply the scale to each layer that has custom drawing against it, mainly
// pattern and gradient layers
@property (nonatomic, copy) IJSVGRenderingBackingScaleFactorHelper renderingBackingScaleHelper;

// global overwriting rules for when rendering an SVG, this will overide any
// fillColor, strokeColor, pattern and gradient fill
@property (nonatomic, retain) NSColor * fillColor;
@property (nonatomic, retain) NSColor * strokeColor;
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, assign) IJSVGLineCapStyle lineCapStyle;
@property (nonatomic, assign) IJSVGLineJoinStyle lineJoinStyle;

- (void)prepForDrawingInView:(NSView *)view;
- (BOOL)isFont;
- (NSRect)viewBox;
- (NSArray *)glyphs;
- (NSString *)identifier;
- (IJSVGLayer *)layer;
- (IJSVGLayer *)layerWithTree:(IJSVGLayerTree *)tree;
- (NSArray<IJSVG *> *)subSVGs:(BOOL)recursive;

- (CGFloat)computeBackingScale:(CGFloat)scale;
- (void)discardDOM;

+ (id)svgNamed:(NSString *)string;
+ (id)svgNamed:(NSString *)string
      delegate:(id<IJSVGDelegate>)delegate;
+ (id)svgNamed:(NSString *)string
      useCache:(BOOL)useCache
      delegate:(id<IJSVGDelegate>)delegate;

- (id)initWithImage:(NSImage *)image;

- (id)initWithSVGLayer:(IJSVGGroupLayer *)group
               viewBox:(NSRect)viewBox;

- (id)initWithSVGString:(NSString *)string
                  error:(NSError **)error
               delegate:(id<IJSVGDelegate>)delegate;

- (id)initWithSVGString:(NSString *)string;
- (id)initWithSVGString:(NSString *)string
                  error:(NSError **)error;

- (id)initWithFile:(NSString *)file
          useCache:(BOOL)useCache;
- (id)initWithFile:(NSString *)file;
- (id)initWithFile:(NSString *)file
             error:(NSError **)error;
- (id)initWithFile:(NSString *)file
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFile:(NSString *)file
             error:(NSError **)error
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFile:(NSString *)file
          useCache:(BOOL)useCache
             error:(NSError **)error
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFilePathURL:(NSURL *)aURL;
- (id)initWithFilePathURL:(NSURL *)aURL
                 useCache:(BOOL)useCache;
- (id)initWithFilePathURL:(NSURL *)aURL
                    error:(NSError **)error;
- (id)initWithFilePathURL:(NSURL *)aURL
                 delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFilePathURL:(NSURL *)aURL
                 useCache:(BOOL)useCache
                    error:(NSError **)error
                 delegate:(id<IJSVGDelegate>)delegate;
- (NSImage *)imageWithSize:(NSSize)aSize;
- (NSImage *)imageWithSize:(NSSize)aSize
                     error:(NSError **)error;
- (NSImage *)imageWithSize:(NSSize)aSize
                   flipped:(BOOL)flipped;
- (BOOL)drawAtPoint:(NSPoint)point
               size:(NSSize)size;
- (BOOL)drawAtPoint:(NSPoint)point
               size:(NSSize)aSize
              error:(NSError **)error;
- (BOOL)drawInRect:(NSRect)rect;
- (BOOL)drawInRect:(NSRect)rect
             error:(NSError **)error;
- (void)drawInRect:(NSRect)rect
           context:(CGContextRef)context;

- (NSData *)PDFData;
- (NSData *)PDFData:(NSError **)error;
- (NSData *)PDFDataWithRect:(NSRect)rect;
- (NSData *)PDFDataWithRect:(NSRect)rect
                      error:(NSError **)error;

// colors
- (NSArray<NSColor *> *)visibleColors;
- (void)setReplacementColors:(NSDictionary<NSColor *, NSColor *> *)colors;
- (void)removeReplacementColor:(NSColor *)color;
- (void)replaceColor:(NSColor *)color
           withColor:(NSColor *)newColor;
- (void)removeAllReplacementColors;

@end
