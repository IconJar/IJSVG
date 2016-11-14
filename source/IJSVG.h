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

@class IJSVG;

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

@interface IJSVG : NSObject <NSPasteboardWriting, IJSVGParserDelegate> {
    
@private
    IJSVGParser * _group;
    CGFloat _scale;
    CGFloat _clipScale;
    NSMutableArray * _colors;
    id<IJSVGDelegate> _delegate;
    
    struct {
        unsigned int shouldHandleForeignObject: 1;
        unsigned int handleForeignObject: 1;
        unsigned int shouldHandleSubSVG: 1;
    } _respondsTo;
    
}

+ (NSColor *)baseColor;
- (BOOL)isFont;
- (NSRect)viewBox;
- (NSArray *)glyphs;
- (NSArray<IJSVG *> *)subSVGs:(BOOL)recursive;
+ (void)setBaseColor:(NSColor *)color;
+ (id)svgNamed:(NSString *)string;
+ (id)svgNamed:(NSString *)string
      delegate:(id<IJSVGDelegate>)delegate;

- (id)initWithSVGString:(NSString *)string
                  error:(NSError **)error
               delegate:(id<IJSVGDelegate>)delegate;

- (id)initWithSVGString:(NSString *)string;
- (id)initWithSVGString:(NSString *)string
                  error:(NSError **)error;

- (id)initWithFile:(NSString *)file;
- (id)initWithFile:(NSString *)file
             error:(NSError **)error;
- (id)initWithFile:(NSString *)file
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFile:(NSString *)file
             error:(NSError **)error
          delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFilePathURL:(NSURL *)aURL;
- (id)initWithFilePathURL:(NSURL *)aURL
                    error:(NSError **)error;
- (id)initWithFilePathURL:(NSURL *)aURL
                 delegate:(id<IJSVGDelegate>)delegate;
- (id)initWithFilePathURL:(NSURL *)aURL
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
- (NSArray *)colors;
- (NSData *)PDFData;
- (NSData *)PDFData:(NSError **)error;
- (NSData *)PDFDataWithRect:(NSRect)rect;
- (NSData *)PDFDataWithRect:(NSRect)rect
                      error:(NSError **)error;

@end
