//
//  IJSVGImage.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVG.h"
#import "IJSVGCache.h"
#import "IJSVGTransaction.h"
#import "IJSVGExporter.h"
#import "IJSVGQuartzRenderer.h"

@implementation IJSVG

@synthesize fillColor;
@synthesize strokeColor;
@synthesize strokeWidth;
@synthesize lineCapStyle;
@synthesize lineJoinStyle;
@synthesize renderingBackingScaleHelper;
@synthesize renderingEngine;
@synthesize clipToViewport;

- (void)dealloc
{
    [renderingBackingScaleHelper release], renderingBackingScaleHelper = nil;
    [fillColor release], fillColor = nil;
    [strokeColor release], strokeColor = nil;
    [_group release], _group = nil;
    [_layerTree release], _layerTree = nil;
    [_replacementColors release], _replacementColors = nil;
    [_quartzRenderer release], _quartzRenderer = nil;
    [super dealloc];
}

+ (id)svgNamed:(NSString *)string
         error:(NSError **)error
{
    return [[self class] svgNamed:string
                            error:error
                         delegate:nil];
}

+ (id)svgNamed:(NSString *)string
{
    return [[self class] svgNamed:string
                            error:nil];
}

+ (id)svgNamed:(NSString *)string
      useCache:(BOOL)useCache
      delegate:(id<IJSVGDelegate>)delegate
{
    return [[self class] svgNamed:string
                         useCache:useCache
                            error:nil
                         delegate:delegate];
}

+ (id)svgNamed:(NSString *)string
      delegate:(id<IJSVGDelegate>)delegate
{
    return [[self class] svgNamed:string
                            error:nil
                         delegate:delegate];
}

+ (id)svgNamed:(NSString *)string
         error:(NSError **)error
      delegate:(id<IJSVGDelegate>)delegate
{
    return [self svgNamed:string
                 useCache:YES
                    error:error
                 delegate:delegate];
}

+ (id)svgNamed:(NSString *)string
      useCache:(BOOL)useCache
         error:(NSError **)error
      delegate:(id<IJSVGDelegate>)delegate
{
    NSBundle * bundle = [NSBundle mainBundle];
    NSString * str = nil;
    NSString * ext = [string pathExtension];
    if( ext == nil || ext.length == 0 ) {
        ext = @"svg";
    }
    if( ( str = [bundle pathForResource:[string stringByDeletingPathExtension] ofType:ext] ) != nil ) {
        return [[[self alloc] initWithFile:str
                                  useCache:useCache
                                     error:error
                                  delegate:delegate] autorelease];
    }
    return nil;
}

- (id)initWithImage:(NSImage *)image
{
    __block IJSVGGroupLayer * layer = nil;
    __block IJSVGImageLayer * imageLayer = nil;
    
    // make sure we obtain a lock, with whatever we do with layers!
    IJSVGObtainTransactionLock(^{
        // create the layers we require
        layer = [[[IJSVGGroupLayer alloc] init] autorelease];
        imageLayer = [[[IJSVGImageLayer alloc] initWithImage:image] autorelease];
        [layer addSublayer:imageLayer];
    }, NO);
    
    // return the initialized SVG
    return [self initWithSVGLayer:layer
                          viewBox:imageLayer.frame];
}

- (id)initWithSVGLayer:(IJSVGGroupLayer *)group
               viewBox:(NSRect)viewBox
{
    // this completely bypasses passing of files
    if((self = [super init]) != nil) {
        // keep the layer tree
        _layerTree = [group retain];
        _viewBox = viewBox;
        
        // any setups
        [self _setupBasicsFromAnyInitializer];
    }
    return self;
}


- (id)initWithFile:(NSString *)file
{
    return [self initWithFile:file
                     delegate:nil];
}

- (id)initWithFile:(NSString *)file
          useCache:(BOOL)useCache
{
    return [self initWithFile:file
                     useCache:useCache
                        error:nil
                     delegate:nil];
}

- (id)initWithFile:(NSString *)file
          useCache:(BOOL)useCache
             error:(NSError **)error
          delegate:(id<IJSVGDelegate>)delegate
{
    return [self initWithFilePathURL:[NSURL fileURLWithPath:file]
                            useCache:useCache
                               error:error
                            delegate:delegate];
}

- (id)initWithFile:(NSString *)file
             error:(NSError **)error
{
    return [self initWithFile:file
                        error:error
                     delegate:nil];
}

- (id)initWithFile:(NSString *)file
          delegate:(id<IJSVGDelegate>)delegate
{
    return [self initWithFile:file
                        error:nil
                     delegate:delegate];
}

- (id)initWithFile:(NSString *)file
             error:(NSError **)error
          delegate:(id<IJSVGDelegate>)delegate
{
    return [self initWithFilePathURL:[NSURL fileURLWithPath:file]
                            useCache:YES
                               error:error
                            delegate:delegate];
}

- (id)initWithFilePathURL:(NSURL *)aURL
{
    return [self initWithFilePathURL:aURL
                            useCache:YES
                               error:nil
                            delegate:nil];
}

- (id)initWithFilePathURL:(NSURL *)aURL
                    error:(NSError **)error
{
    return [self initWithFilePathURL:aURL
                            useCache:YES
                               error:error
                            delegate:nil];
}

- (id)initWithFilePathURL:(NSURL *)aURL
                 useCache:(BOOL)useCache
{
    return [self initWithFilePathURL:aURL
                            useCache:useCache
                               error:nil
                            delegate:nil];
}

- (id)initWithFilePathURL:(NSURL *)aURL
                 delegate:(id<IJSVGDelegate>)delegate
{
    return [self initWithFilePathURL:aURL
                            useCache:YES
                               error:nil
                            delegate:delegate];
}

- (id)initWithFilePathURL:(NSURL *)aURL
                 useCache:(BOOL)useCache
                    error:(NSError **)error
                 delegate:(id<IJSVGDelegate>)delegate
{
#ifndef __clang_analyzer__
    
    // check the cache first
    if( useCache && [IJSVGCache enabled] ) {
        IJSVG * svg = nil;
        if( ( svg = [IJSVGCache cachedSVGForFileURL:aURL] ) != nil ) {
            // have to release, as this was called from an alloc..!
            [self release];
            return [svg retain];
        }
    }
    
    // create the object
    if( ( self = [super init] ) != nil ) {
        NSError * anError = nil;
        _delegate = delegate;
        
        // this is a really quick check against the delegate
        // for methods that exist
        [self _checkDelegate];
        
        // create the group
        _group = [[IJSVGParser groupForFileURL:aURL
                                         error:&anError
                                      delegate:self] retain];
        
        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];
        
        // something went wrong...
        if( _group == nil ) {
            if( error != NULL ) {
                *error = anError;
            }
            [self release], self = nil;
            return nil;
        }
        
        // cache the file
        if( useCache && [IJSVGCache enabled] ) {
            [IJSVGCache cacheSVG:self
                         fileURL:aURL];
        }
        
    }
#endif
    return self;
}

- (id)initWithSVGString:(NSString *)string
{
    return [self initWithSVGString:string
                             error:nil
                          delegate:nil];
}

- (id)initWithSVGString:(NSString *)string
                  error:(NSError **)error
{
    return [self initWithSVGString:string
                             error:error
                          delegate:nil];
}

- (id)initWithSVGString:(NSString *)string
                  error:(NSError **)error
               delegate:(id<IJSVGDelegate>)delegate
{
    if((self = [super init]) != nil) {
        // this is basically the same as init with URL just
        // bypasses the loading of a file
        NSError * anError = nil;
        _delegate = delegate;
        [self _checkDelegate];
        
        // setup the parser
        _group = [[IJSVGParser alloc] initWithSVGString:string
                                                  error:&anError
                                               delegate:self];
        
        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];
        
        // something went wrong :(
        if(_group == nil) {
            if(error != NULL) {
                *error = anError;
            }
            [self release], self = nil;
            return nil;
        }
    }
    return self;
}

- (void)discardDOM
{
    // if we discard, we can no longer create a tree, so lets create tree
    // upfront before we kill anything
    [self layer];
    
    // now clear memory
    [_group release], _group = nil;
}

- (void)_setupBasicInfoFromGroup
{
    // store the viewbox
    _viewBox = _group.viewBox;
    _proposedViewSize = _group.proposedViewSize;
}

- (void)_setupBasicsFromAnyInitializer
{
    renderingEngine = IJSVGRenderingEngineCoreAnimation;
    self.clipToViewport = YES;
    
    // setup low level backing scale
    _lastProposedBackingScale = 0.f;
    self.renderingBackingScaleHelper = ^CGFloat{
        return 1.f;
    };
}

- (NSString *)identifier
{
    return _group.identifier;
}

- (void)_checkDelegate
{
    _respondsTo.shouldHandleForeignObject = [_delegate respondsToSelector:@selector(svg:shouldHandleForeignObject:)];
    _respondsTo.handleForeignObject = [_delegate respondsToSelector:@selector(svg:handleForeignObject:document:)];
    _respondsTo.shouldHandleSubSVG = [_delegate respondsToSelector:@selector(svg:foundSubSVG:withSVGString:)];
}

- (NSRect)viewBox
{
    return _viewBox;
}

- (IJSVGGroup *)rootNode
{
    return _group;
}

- (BOOL)isFont
{
    return [_group isFont];
}

- (NSArray<IJSVGPath *> *)glyphs
{
    return [_group glyphs];
}

- (NSArray<IJSVG *> *)subSVGs:(BOOL)recursive
{
    return [_group subSVGs:recursive];
}

- (NSString *)SVGStringWithOptions:(IJSVGExporterOptions)options
{
    IJSVGExporter * exporter = [[[IJSVGExporter alloc] initWithSVG:self
                                                              size:self.viewBox.size
                                                           options:options] autorelease];
    return [exporter SVGString];
}

- (NSImage *)imageWithSize:(NSSize)aSize
{
    return [self imageWithSize:aSize
                       flipped:NO
                         error:nil];
}

- (NSImage *)imageWithSize:(NSSize)aSize
                     error:(NSError **)error;
{
    return [self imageWithSize:aSize
                       flipped:NO
                         error:error];
}

- (NSImage *)imageWithSize:(NSSize)aSize
                   flipped:(BOOL)flipped
{
    return [self imageWithSize:aSize
                       flipped:flipped
                         error:nil];
}

- (NSImage *)imageWithSize:(NSSize)aSize
                   flipped:(BOOL)flipped
                     error:(NSError **)error
{
    NSImage * im = [[[NSImage alloc] initWithSize:aSize] autorelease];
    [im lockFocus];
    CGContextRef ref = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(ref);
    if(flipped) {
        CGContextTranslateCTM(ref, 0.f, aSize.height);
        CGContextScaleCTM(ref, 1.f, -1.f);
    }
    [self drawAtPoint:NSMakePoint( 0.f, 0.f )
                 size:aSize
                error:error];
    CGContextRestoreGState(ref);
    [im unlockFocus];
    return im;
}

- (NSData *)PDFData
{
    return [self PDFData:nil];
}

- (NSData *)PDFData:(NSError **)error
{
    return [self PDFDataWithRect:(NSRect){
        .origin=NSZeroPoint,
        .size=_viewBox.size
    } error:error];
}

- (NSData *)PDFDataWithRect:(NSRect)rect
{
    return [self PDFDataWithRect:rect
                           error:nil];
}

- (NSData *)PDFDataWithRect:(NSRect)rect
                      error:(NSError **)error
{
    // create the data for the PDF
    NSMutableData * data = [[[NSMutableData alloc] init] autorelease];
    
    // assign the data to the consumer
    CGDataConsumerRef dataConsumer = CGDataConsumerCreateWithCFData((CFMutableDataRef)data);
    const CGRect box = CGRectMake( rect.origin.x, rect.origin.y,
                                  rect.size.width, rect.size.height );
    
    // create the context
    CGContextRef context = CGPDFContextCreate( dataConsumer, &box, NULL );
    
    CGContextBeginPage( context, &box );
    
    // the context is currently upside down, doh! flip it...
    CGContextScaleCTM( context, 1, -1 );
    CGContextTranslateCTM( context, 0, -box.size.height);
    
    // make sure we set the masks to path bits n bobs
    [self _beginVectorDraw]; {
        // draw the icon
        [self _drawInRect:(NSRect)box
                  context:context
                    error:error];
    } [self _endVectorDraw];
    
    CGContextEndPage(context);
    
    //clean up
    CGPDFContextClose(context);
    CGContextRelease(context);
    CGDataConsumerRelease(dataConsumer);
    return data;
}

- (void)endVectorDraw
{
    [self _endVectorDraw];
}

- (void)beginVectorDraw
{
    [self _beginVectorDraw];
}

- (void)_beginVectorDraw
{
    // turn on converts masks to PDF's
    // as PDF context and layer masks dont work
    void (^block)(CALayer * layer, BOOL isMask) = ^void (CALayer * layer, BOOL isMask) {
        ((IJSVGLayer *)layer).convertMasksToPaths = YES;
    };
    [IJSVGLayer recursivelyWalkLayer:self.layer
                           withBlock:block];
}

- (void)_endVectorDraw
{
    // turn of convert masks to paths as not
    // needed for generic rendering
    void (^block)(CALayer * layer, BOOL isMask) = ^void (CALayer * layer, BOOL isMask) {
        ((IJSVGLayer *)layer).convertMasksToPaths = NO;
    };
    [IJSVGLayer recursivelyWalkLayer:self.layer
                           withBlock:block];
}

- (void)prepForDrawingInView:(NSView *)view
{
    // kill the render
    if(view == nil) {
        self.renderingBackingScaleHelper = nil;
        return;
    }
    
    // construct the layer before drawing
    [self layer];
    
    // set the scale
    __block NSView * weakView = view;
    self.renderingBackingScaleHelper = ^CGFloat{
        return weakView.window.screen.backingScaleFactor;
    };
}

- (BOOL)drawAtPoint:(NSPoint)point
               size:(NSSize)aSize
{
    return [self drawAtPoint:point
                        size:aSize
                       error:nil];
}

- (BOOL)drawAtPoint:(NSPoint)point
               size:(NSSize)aSize
              error:(NSError **)error
{
    return [self drawInRect:NSMakeRect( point.x, point.y, aSize.width, aSize.height )
                      error:error];
}

- (BOOL)drawInRect:(NSRect)rect
{
    return [self drawInRect:rect
                     error:nil];
}

- (BOOL)drawInRect:(NSRect)rect
             error:(NSError **)error
{
    return [self _drawInRect:rect
                     context:[[NSGraphicsContext currentContext] graphicsPort]
                       error:error];
}

- (CGFloat)computeBackingScale:(CGFloat)actualScale
{
    _backingScale = actualScale;
    return (CGFloat)(_scale + actualScale);
}

- (NSRect)computeRectDrawingInRect:(NSRect)rect
                       isValid:(BOOL *)valid
{
    // we also need to calculate the viewport so we can clip
    // the drawing if needed
    NSRect viewPort = NSZeroRect;
    viewPort.origin.x = round((rect.size.width/2-(_proposedViewSize.width/2)*_clipScale) + rect.origin.x);
    viewPort.origin.y = round((rect.size.height/2-(_proposedViewSize.height/2)*_clipScale) + rect.origin.y);
    viewPort.size.width = _proposedViewSize.width*_clipScale;
    viewPort.size.height = _proposedViewSize.height*_clipScale;
    
    // check the viewport
    if( NSEqualRects( _viewBox, NSZeroRect )
       || _viewBox.size.width <= 0
       || _viewBox.size.height <= 0
       || NSEqualRects( NSZeroRect, viewPort)
       || CGRectIsEmpty(viewPort)
       || CGRectIsNull(viewPort)
       || viewPort.size.width <= 0
       || viewPort.size.height <= 0 )
    {
        *valid = NO;
        return NSZeroRect;
    }

    *valid = YES;
    return viewPort;
}

- (void)drawInRect:(NSRect)rect
           context:(CGContextRef)context
{
    [self _drawInRect:rect
              context:context 
                error:nil];
}

- (BOOL)_drawInRect:(NSRect)rect
            context:(CGContextRef)ref
              error:(NSError **)error
{
    // prep for draw...
    @synchronized (self) {
        CGContextSaveGState(ref);
        @try {
            [self _beginDraw:rect];
            
            // we also need to calculate the viewport so we can clip
            // the drawing if needed
            BOOL canDraw = NO;
            NSRect viewPort = [self computeRectDrawingInRect:rect isValid:&canDraw];
            // check the viewport
            if( canDraw == NO ) {
                if( error != NULL ) {
                    *error = [[[NSError alloc] initWithDomain:IJSVGErrorDomain
                                                         code:IJSVGErrorDrawing
                                                     userInfo:nil] autorelease];
                }
            } else {
                // clip to mask
                if(self.clipToViewport == YES) {
                    CGContextClipToRect( ref, viewPort);
                }
                
                // add the origin back onto the viewport
                viewPort.origin.x -= round((_viewBox.origin.x)*_scale);
                viewPort.origin.y -= round((_viewBox.origin.y)*_scale);
                viewPort = CGRectIntegral(viewPort);
                
                // transforms
                CGContextTranslateCTM( ref, viewPort.origin.x, viewPort.origin.y);
                CGContextScaleCTM( ref, _scale, _scale );
                
                // render the layer, its really important we lock
                // the transaction when drawing
                IJSVGBeginTransactionLock();
                // do we need to update the backing scales on the
                // layers?
                if(self.renderingBackingScaleHelper != nil) {
                    [self _askHelperForBackingScale];
                }
                
                // render the layers
                switch(self.renderingEngine) {
                    // CoreGraphics / Quartz
                    case IJSVGRenderingEngineCoreGraphics: {
                        if(_quartzRenderer == nil) {
                            // init the renderer if its not already defined
                            _quartzRenderer = [[IJSVGQuartzRenderer alloc] init];
                        }
                        _quartzRenderer.scale = _scale;
                        _quartzRenderer.backingScale = _backingScale;
                        _quartzRenderer.viewPort = viewPort;
                        
                        // render it
                        [_quartzRenderer renderLayer:self.layer
                                           inContext:ref];
                        break;
                    }
                    // CALayer tree
                    case IJSVGRenderingEngineCoreAnimation: {
                        [self.layer renderInContext:ref];
                    }
                }
                IJSVGEndTransactionLock();
            }
        }
        @catch (NSException *exception) {
            // just catch and give back a drawing error to the caller
            if( error != NULL ) {
                *error = [[[NSError alloc] initWithDomain:IJSVGErrorDomain
                                                     code:IJSVGErrorDrawing
                                                 userInfo:nil] autorelease];
            }
        }
        CGContextRestoreGState(ref);
    }
    return (error == nil);
}

- (void)_askHelperForBackingScale
{
    CGFloat scale = (self.renderingBackingScaleHelper)();
    if(scale < 1.f) {
        scale = 1.f;
    }
    
    // dont do anything, nothing has changed, no point of iterating over
    // every layer for no reason!
    if(scale == _lastProposedBackingScale) {
        return;
    }
    _lastProposedBackingScale = scale;
    
    // walk the tree
    void (^block)(CALayer * layer, BOOL isMask) = ^void (CALayer * layer, BOOL isMask) {
        IJSVGLayer * propLayer = ((IJSVGLayer *)layer);
        if(propLayer.requiresBackingScaleHelp == YES) {
            propLayer.backingScaleFactor = scale;
        }
    };
    
    // gogogo
    [IJSVGLayer recursivelyWalkLayer:self.layer
                           withBlock:block];
    
}

- (void)setFillColor:(NSColor *)aColor
{
    if(fillColor != nil) {
        [fillColor release], fillColor = nil;
    }
    fillColor = [aColor retain];
    [_layerTree release], _layerTree = nil;
}

- (void)setStrokeColor:(NSColor *)aColor
{
    if(strokeColor != nil) {
        [strokeColor release], strokeColor = nil;
    }
    strokeColor = [aColor retain];
    [_layerTree release], _layerTree = nil;
}

- (void)setStrokeWidth:(CGFloat)aWidth
{
    strokeWidth = aWidth;
    [_layerTree release], _layerTree = nil;
}

- (void)setLineCapStyle:(IJSVGLineCapStyle)aLineCapStyle
{
    lineCapStyle = aLineCapStyle;
    [_layerTree release], _layerTree = nil;
}

- (void)setLineJoinStyle:(IJSVGLineJoinStyle)aLineJoinStyle
{
    lineJoinStyle = aLineJoinStyle;
    [_layerTree release], _layerTree = nil;
}

- (IJSVGLayer *)layerWithTree:(IJSVGLayerTree *)tree
{
    // clear memory
    if(_layerTree != nil) {
        [_layerTree release], _layerTree = nil;
    }
    
    // force rebuild of the tree
    IJSVGBeginTransactionLock();
    _layerTree = [[tree layerForNode:_group] retain];
    
    IJSVGEndTransactionLock();
    return _layerTree;
}

- (IJSVGLayer *)layer
{
    if(_layerTree != nil) {
        return _layerTree;
    }
    
    // create the renderer and assign default values
    // from this SVG object
    IJSVGLayerTree * renderer = [[[IJSVGLayerTree alloc] init] autorelease];
    renderer.viewBox = self.viewBox;
    renderer.fillColor = self.fillColor;
    renderer.strokeColor = self.strokeColor;
    renderer.strokeWidth = self.strokeWidth;
    renderer.lineCapStyle = self.lineCapStyle;
    renderer.lineJoinStyle = self.lineJoinStyle;
    renderer.replacementColors = _replacementColors;
    
    // return the rendered layer
    return [self layerWithTree:renderer];
}

- (NSArray<NSColor *> *)visibleColors
{
    // set for the colors
    NSMutableSet * colors = [[[NSMutableSet alloc] init] autorelease];
    
    // block to find colors in stroke and fill
    void (^block)(CALayer * layer, BOOL isMask) = ^void (CALayer * layer, BOOL isMask) {
        if([layer isKindOfClass:[IJSVGShapeLayer class]] && isMask == NO) {
            IJSVGShapeLayer * sLayer = (IJSVGShapeLayer *)layer;
            NSColor * color = nil;
            if(sLayer.fillColor != nil) {
                color = [NSColor colorWithCGColor:sLayer.fillColor];
                if(color.alphaComponent != 0.f) {
                    [colors addObject:color];
                }
            }
            if(sLayer.strokeColor != nil) {
                color = [NSColor colorWithCGColor:sLayer.strokeColor];
                if(color.alphaComponent != 0.f) {
                    [colors addObject:color];
                }
            }
        }
    };
    
    // walk
    [IJSVGLayer recursivelyWalkLayer:self.layer
                           withBlock:block];
    
    // return the colours!
    return colors.allObjects;
}

- (void)removeAllReplacementColors
{
    [_replacementColors release], _replacementColors = nil;
}

- (void)removeReplacementColor:(NSColor *)color
{
    if(_replacementColors == nil) {
        return;
    }
    [_replacementColors removeObjectForKey:[IJSVGColor computeColorSpace:color]];
}

- (void)replaceColor:(NSColor *)color
           withColor:(NSColor *)newColor
{
    if(_replacementColors == nil) {
        _replacementColors = [[NSMutableDictionary alloc] init];
    }
    color = [IJSVGColor computeColorSpace:color];
    newColor = [IJSVGColor computeColorSpace:newColor];
    _replacementColors[color] = newColor;
    [_layerTree release], _layerTree = nil;
}

- (void)setReplacementColors:(NSDictionary<NSColor *, NSColor *> *)colors
{
    if(_replacementColors != nil) {
        [_replacementColors release], _replacementColors = nil;
    }
    for(NSColor * oldColor in colors) {
        [self replaceColor:oldColor
                 withColor:colors[oldColor]];
    }
}

- (void)_beginDraw:(NSRect)rect
{
    // in order to correctly fit the the SVG into the
    // rect, we need to work out the ratio scale in order
    // to transform the paths into our viewbox
    NSSize dest = rect.size;
    NSSize source = _viewBox.size;
    _clipScale = MIN(dest.width/_proposedViewSize.width,
                     dest.height/_proposedViewSize.height);
   
    // work out the actual scale based on the clip scale
    CGFloat w = _proposedViewSize.width*_clipScale;
    CGFloat h = _proposedViewSize.height*_clipScale;
    _scale = MIN(w/source.width,h/source.height);
}

#pragma mark NSPasteboard

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return @[NSPasteboardTypePDF];
}

- (id)pasteboardPropertyListForType:(NSString *)type
{
    if( [type isEqualToString:NSPasteboardTypePDF] ) {
        return [self PDFData];
    }
    return nil;
}

#pragma mark IJSVGParserDelegate

- (void)svgParser:(IJSVGParser *)svg
      foundSubSVG:(IJSVG *)subSVG
    withSVGString:(NSString *)string
{
    if(_delegate != nil && _respondsTo.shouldHandleSubSVG == 1) {
        [_delegate svg:self
           foundSubSVG:subSVG
         withSVGString:string];
    }
}

- (BOOL)svgParser:(IJSVGParser *)parser
shouldHandleForeignObject:(IJSVGForeignObject *)foreignObject
{
    if( _delegate != nil && _respondsTo.shouldHandleForeignObject == 1 ) {
        return [_delegate svg:self shouldHandleForeignObject:foreignObject];
    }
    return NO;
}

- (void)svgParser:(IJSVGParser *)parser
handleForeignObject:(IJSVGForeignObject *)foreignObject
         document:(NSXMLDocument *)document
{
    if( _delegate != nil && _respondsTo.handleForeignObject == 1 ) {
        [_delegate svg:self
   handleForeignObject:foreignObject
              document:document];
    }
}

@end
