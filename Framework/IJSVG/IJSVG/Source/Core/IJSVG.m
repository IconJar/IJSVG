//
//  IJSVGImage.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVG.h"
#import "IJSVGExporter.h"
#import "IJSVGTransaction.h"

@implementation IJSVG

// these are explicitly implemented
@synthesize title = _title;
@synthesize desc = _desc;

- (void)dealloc
{
    // this can all be called on the background thread to be released
    BOOL hasTransaction = IJSVGBeginTransaction();
    (void)([_renderingBackingScaleHelper release]), _renderingBackingScaleHelper = nil;
    (void)([_replacementColors release]), _replacementColors = nil;
    (void)([_renderingStyle release]), _renderingStyle = nil;
    (void)([_rootNode release]), _rootNode = nil;
    (void)([_intrinsicSize release]), _intrinsicSize = nil;
    (void)([_title release]), _title = nil;
    (void)([_desc release]), _desc = nil;
    (void)([_rootLayer release]), _rootLayer = nil;

    // kill any memory that has been around
    (void)([_layerTree release]), _layerTree = nil;
    [super dealloc];
    if (hasTransaction == YES) {
        IJSVGEndTransaction();
    }
}

+ (id)svgNamed:(NSString*)string
         error:(NSError**)error
{
    return [self.class svgNamed:string
                          error:error
                       delegate:nil];
}

+ (id)svgNamed:(NSString*)string
{
    return [self.class svgNamed:string
                          error:nil];
}

+ (id)svgNamed:(NSString*)string
      delegate:(id<IJSVGDelegate>)delegate
{
    return [self.class svgNamed:string
                          error:nil
                       delegate:delegate];
}

+ (id)svgNamed:(NSString*)string
         error:(NSError**)error
      delegate:(id<IJSVGDelegate>)delegate
{
    NSBundle* bundle = NSBundle.mainBundle;
    NSString* str = nil;
    NSString* ext = [string pathExtension];
    if (ext == nil || ext.length == 0) {
        ext = @"svg";
    }
    if ((str = [bundle pathForResource:[string stringByDeletingPathExtension]
                                ofType:ext]) != nil) {
        return [[[self alloc] initWithFile:str
                                     error:error
                                  delegate:delegate] autorelease];
    }
    
    // check the asset catalogues
    return [[[self alloc] initWithDataAssetNamed:string
                                           error:error] autorelease];
}

- (id)initWithDataAssetNamed:(NSDataAssetName)name
                       error:(NSError**)error
{
    return [self initWithDataAssetNamed:name
                                 bundle:NSBundle.mainBundle
                                  error:error];
}

- (id)initWithDataAssetNamed:(NSDataAssetName)name
                      bundle:(NSBundle*)bundle
                       error:(NSError**)error
{
    NSDataAsset* dataAsset = [[[NSDataAsset alloc] initWithName:name
                                                         bundle:bundle] autorelease];
    if(dataAsset != nil) {
        return [[self initWithSVGData:dataAsset.data
                                error:error] autorelease];
    }
    return nil;
}

- (id)initWithImage:(NSImage*)image
{
    __block IJSVGGroupLayer* layer = nil;
    __block IJSVGImageLayer* imageLayer = nil;

    // create the layers we require
    IJSVGImage* imageNode = [[[IJSVGImage alloc] init] autorelease];
    imageNode.image = image;
    
    BOOL hasTransaction = IJSVGBeginTransaction();
    layer = [[[IJSVGGroupLayer alloc] init] autorelease];
    imageLayer =
        [[[IJSVGImageLayer alloc] initWithImage:imageNode] autorelease];
    [layer addSublayer:imageLayer];
    if (hasTransaction == YES) {
        IJSVGEndTransaction();
    }

    // return the initialized SVG
    return [self initWithSVGLayer:layer
                          viewBox:imageLayer.frame];
}

- (id)initWithSVGLayer:(IJSVGGroupLayer*)group
               viewBox:(NSRect)viewBox
{
    // this completely bypasses passing of files
    if ((self = [super init]) != nil) {
        // keep the layer tree
        _viewBox = viewBox;

        // any setups
        [self _setupBasicsFromAnyInitializer];
    }
    return self;
}

- (id)initWithFile:(NSString*)file
{
    return [self initWithFile:file
                        error:nil
                     delegate:nil];
}

- (id)initWithFile:(NSString*)file
             error:(NSError**)error
          delegate:(id<IJSVGDelegate>)delegate
{
    return [self initWithFilePathURL:[NSURL fileURLWithPath:file isDirectory:NO]
                               error:error
                            delegate:delegate];
}

- (id)initWithFile:(NSString*)file
             error:(NSError**)error
{
    return [self initWithFile:file
                        error:error
                     delegate:nil];
}

- (id)initWithFile:(NSString*)file
          delegate:(id<IJSVGDelegate>)delegate
{
    return [self initWithFile:file
                        error:nil
                     delegate:delegate];
}

- (id)initWithFilePathURL:(NSURL*)aURL
{
    return [self initWithFilePathURL:aURL
                               error:nil
                            delegate:nil];
}

- (id)initWithFilePathURL:(NSURL*)aURL
                    error:(NSError**)error
{
    return [self initWithFilePathURL:aURL
                               error:error
                            delegate:nil];
}

- (id)initWithFilePathURL:(NSURL*)aURL
                 delegate:(id<IJSVGDelegate>)delegate
{
    return [self initWithFilePathURL:aURL
                               error:nil
                            delegate:delegate];
}

- (id)initWithFilePathURL:(NSURL*)aURL
                    error:(NSError**)error
                 delegate:(id<IJSVGDelegate>)delegate
{
    // create the object
    if ((self = [super init]) != nil) {
        NSError* anError = nil;
        _delegate = delegate;

        // this is a really quick check against the delegate
        // for methods that exist
        [self _checkDelegate];

        // create the group
        IJSVGParser* parser = [IJSVGParser groupForFileURL:aURL
                                                      error:&anError
                                                   delegate:self];
        _rootNode = parser.rootNode.retain;
        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];

        // something went wrong...
        if (_rootNode == nil) {
            if (error != NULL) {
                *error = anError;
            }
            (void)([self release]), self = nil;
            return nil;
        }
    }
    return self;
}

- (id)initWithSVGData:(NSData*)data
{
    return [self initWithSVGData:data
                           error:nil];
}

- (id)initWithSVGData:(NSData*)data
                error:(NSError**)error
{
    NSString* svgString = [[NSString alloc] initWithData:data
                                                encoding:NSUTF8StringEncoding];
    return [self initWithSVGString:svgString.autorelease
                             error:error];
}

- (id)initWithSVGString:(NSString*)string
{
    return [self initWithSVGString:string
                             error:nil
                          delegate:nil];
}

- (id)initWithSVGString:(NSString*)string
                  error:(NSError**)error
{
    return [self initWithSVGString:string
                             error:error
                          delegate:nil];
}

- (id)initWithSVGString:(NSString*)string
                  error:(NSError**)error
               delegate:(id<IJSVGDelegate>)delegate
{
    if ((self = [super init]) != nil) {
        // this is basically the same as init with URL just
        // bypasses the loading of a file
        NSError* anError = nil;
        _delegate = delegate;
        [self _checkDelegate];

        // setup the parser
        IJSVGParser* parser = [[[IJSVGParser alloc] initWithSVGString:string
                                                                error:&anError
                                                             delegate:self] autorelease];
        _rootNode = parser.rootNode.retain;

        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];

        // something went wrong :(
        if (_rootNode == nil) {
            if (error != NULL) {
                *error = anError;
            }
            (void)([self release]), self = nil;
            return nil;
        }
    }
    return self;
}

- (void)performBlock:(dispatch_block_t)block
{
    BOOL hasTransaction = IJSVGBeginTransaction();
    block();
    if (hasTransaction == YES) {
        IJSVGEndTransaction();
    }
}

- (void)_setupBasicInfoFromGroup
{
    _viewBox = [_rootNode.viewBox computeValue:CGSizeZero];
    _intrinsicSize = _rootNode.intrinsicSize.retain;
}

- (void)_setupBasicsFromAnyInitializer
{
    self.renderingStyle = [[[IJSVGRenderingStyle alloc] init] autorelease];
    self.clipToViewport = YES;
    self.renderQuality = kIJSVGRenderQualityFullResolution;

    // setup low level backing scale
    self.renderingBackingScaleHelper = ^CGFloat {
        return NSScreen.mainScreen.backingScaleFactor;
    };
}

- (void)setTitle:(NSString*)title
{
    _rootNode.title = title;
}

- (NSString*)title
{
    return _rootNode.title;
}

- (void)setDesc:(NSString*)description
{
    _rootNode.desc = description;
}

- (NSString*)desc
{
    return _rootNode.desc;
}

- (NSString*)identifier
{
    return _rootNode.identifier;
}

- (void)_checkDelegate
{
    _respondsTo.shouldHandleSubSVG = [_delegate respondsToSelector:@selector(svg:foundSubSVG:withSVGString:)];
}

- (NSRect)viewBox
{
    return _viewBox;
}

- (IJSVGGroup*)rootNode
{
    return _rootNode;
}

- (BOOL)isFont
{
    return [_rootNode isFont];
}

- (NSArray<IJSVGPath*>*)glyphs
{
    return [_rootNode glyphs];
}

- (NSArray<IJSVG*>*)subSVGs:(BOOL)recursive
{
    return [_rootNode subSVGs:recursive];
}

- (NSString*)SVGStringWithOptions:(IJSVGExporterOptions)options
{
    IJSVGExporter* exporter = [[[IJSVGExporter alloc] initWithSVG:self
                                                             size:self.viewBox.size
                                                          options:options] autorelease];
    return [exporter SVGString];
}

- (NSString*)SVGStringWithOptions:(IJSVGExporterOptions)options
             floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    IJSVGExporter* exporter = [[[IJSVGExporter alloc] initWithSVG:self
                                                             size:self.viewBox.size
                                                          options:options
                                             floatingPointOptions:floatingPointOptions] autorelease];
    return [exporter SVGString];
}

- (NSImage*)imageWithSize:(NSSize)aSize
{
    return [self imageWithSize:aSize
                       flipped:NO
                         error:nil];
}

- (NSImage*)imageWithSize:(NSSize)aSize
                    error:(NSError**)error;
{
    return [self imageWithSize:aSize
                       flipped:NO
                         error:error];
}

- (NSImage*)imageWithSize:(NSSize)aSize
                  flipped:(BOOL)flipped
{
    return [self imageWithSize:aSize
                       flipped:flipped
                         error:nil];
}

- (NSSize)computeSVGSizeWithRenderSize:(NSSize)size
{
    IJSVGUnitSize* svgSize = _intrinsicSize;
    return NSMakeSize([svgSize.width computeValue:size.width],
        [svgSize.height computeValue:size.height]);
}

- (NSRect)computeOriginalDrawingFrameWithSize:(NSSize)aSize
{
    NSSize propSize = [self computeSVGSizeWithRenderSize:aSize];
    [self _beginDraw:(NSRect) { .origin = CGPointZero, .size = aSize }];
    return NSMakeRect(0.f, 0.f, propSize.width * _clipScale,
        propSize.height * _clipScale);
}

- (CGImageRef)newCGImageRefWithSize:(CGSize)size
                            flipped:(BOOL)flipped
                              error:(NSError**)error
{
    // setup the drawing rect, this is used for both the intial drawing
    // and the backing scale helper block
    NSRect rect = (CGRect) {
        .origin = CGPointZero,
        .size = (CGSize)size
    };

    // this is highly important this is setup
    [self _beginDraw:rect];

    // make sure we setup the scale based on the backing scale factor
    CGFloat scale = [self backingScaleFactor];

    // create the context and colorspace
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ref = CGBitmapContextCreate(NULL, (int)size.width * scale,
        (int)size.height * scale, 8, 0, colorSpace,
        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);

    // scale the context
    CGContextScaleCTM(ref, scale, scale);

    if (flipped == YES) {
        CGContextTranslateCTM(ref, 0.f, size.height);
        CGContextScaleCTM(ref, 1.f, -1.f);
    }

    // draw the SVG into the context
    [self _drawInRect:rect
              context:ref
                error:error];

    // create the image from the context
    CGImageRef imageRef = CGBitmapContextCreateImage(ref);

    // release all things!
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(ref);
    return imageRef;
}

- (NSImage*)imageWithSize:(NSSize)aSize
                  flipped:(BOOL)flipped
                    error:(NSError**)error
{
    CGImageRef ref = [self newCGImageRefWithSize:aSize
                                         flipped:flipped
                                           error:error];

    NSImage* image = [[NSImage alloc] initWithCGImage:ref
                                                 size:aSize];
    CGImageRelease(ref);
    return image.autorelease;
}

- (NSImage*)imageByMaintainingAspectRatioWithSize:(NSSize)aSize
                                          flipped:(BOOL)flipped
                                            error:(NSError**)error
{
    NSRect rect = [self computeOriginalDrawingFrameWithSize:aSize];
    return [self imageWithSize:rect.size flipped:flipped error:error];
}

- (NSData*)PDFData
{
    return [self PDFData:nil];
}

- (NSData*)PDFData:(NSError**)error
{
    return [self
        PDFDataWithRect:(NSRect) { .origin = NSZeroPoint, .size = _viewBox.size }
                  error:error];
}

- (NSData*)PDFDataWithRect:(NSRect)rect
{
    return [self PDFDataWithRect:rect error:nil];
}

- (NSData*)PDFDataWithRect:(NSRect)rect
                     error:(NSError**)error
{
    // create the data for the PDF
    NSMutableData* data = [[[NSMutableData alloc] init] autorelease];

    // assign the data to the consumer
    CGDataConsumerRef dataConsumer = CGDataConsumerCreateWithCFData((CFMutableDataRef)data);
    const CGRect box = CGRectMake(rect.origin.x, rect.origin.y, rect.size.width,
        rect.size.height);

    // create the context
    CGContextRef context = CGPDFContextCreate(dataConsumer, &box, NULL);

    CGContextBeginPage(context, &box);

    // the context is currently upside down, doh! flip it...
    CGContextScaleCTM(context, 1, -1);
    CGContextTranslateCTM(context, 0, -box.size.height);

    // make sure we set the masks to path bits n bobs
//    [self _beginVectorDraw];
    // draw the icon
    [self _drawInRect:(NSRect)box context:context error:error];
//    [self _endVectorDraw];

    CGContextEndPage(context);

    // clean up
    CGPDFContextClose(context);
    CGContextRelease(context);
    CGDataConsumerRelease(dataConsumer);
    return data;
}

//- (void)endVectorDraw
//{
//    [self _endVectorDraw];
//}
//
//- (void)beginVectorDraw
//{
//    [self _beginVectorDraw];
//}

//- (void)_beginVectorDraw
//{
//    // turn on converts masks to PDF's
//    // as PDF context and layer masks dont work
//    void (^block)(CALayer* layer, BOOL isMask, BOOL* stop) =
//    ^void(CALayer* layer, BOOL isMask, BOOL* stop) {
//        ((IJSVGLayer*)layer).convertMasksToPaths = YES;
//    };
//    [IJSVGLayer recursivelyWalkLayer:self.layer
//                           withBlock:block];
//}
//
//- (void)_endVectorDraw
//{
//    // turn of convert masks to paths as not
//    // needed for generic rendering
//    void (^block)(CALayer* layer, BOOL isMask, BOOL* stop) =
//    ^void(CALayer* layer, BOOL isMask, BOOL* stop) {
//        ((IJSVGLayer*)layer).convertMasksToPaths = NO;
//    };
//    [IJSVGLayer recursivelyWalkLayer:self.layer
//                           withBlock:block];
//}

- (void)prepForDrawingInView:(NSView*)view
{
    // kill the render
    if (view == nil) {
        self.renderingBackingScaleHelper = nil;
        return;
    }

    // construct the layer before drawing
    [self rootLayer];

    // set the scale
    __block NSView* weakView = view;
    self.renderingBackingScaleHelper = ^CGFloat {
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
              error:(NSError**)error
{
    return
        [self drawInRect:NSMakeRect(point.x, point.y,
                             aSize.width, aSize.height)
                   error:error];
}

- (BOOL)drawInRect:(NSRect)rect
{
    return [self drawInRect:rect error:nil];
}

- (BOOL)drawInRect:(NSRect)rect
             error:(NSError**)error
{
    CGContextRef currentCGContext;
    if (@available(macOS 10.10, *)) {
        currentCGContext = NSGraphicsContext.currentContext.CGContext;
    } else {
        currentCGContext = NSGraphicsContext.currentContext.graphicsPort;
    }
    return [self _drawInRect:rect
                     context:currentCGContext
                       error:error];
}

- (NSRect)computeRectDrawingInRect:(NSRect)rect
                           isValid:(BOOL*)valid
{
    // we also need to calculate the viewport so we can clip
    // the drawing if needed
    NSRect viewPort = NSZeroRect;
    NSSize propSize = [self computeSVGSizeWithRenderSize:rect.size];
    viewPort.origin.x = round((rect.size.width / 2 - (propSize.width / 2) * _clipScale) + rect.origin.x);
    viewPort.origin.y = round(
        (rect.size.height / 2 - (propSize.height / 2) * _clipScale) + rect.origin.y);
    viewPort.size.width = propSize.width * _clipScale;
    viewPort.size.height = propSize.height * _clipScale;

    // check the viewport
    if (NSEqualRects(_viewBox, NSZeroRect) ||
        _viewBox.size.width <= 0 ||
        _viewBox.size.height <= 0 ||
        NSEqualRects(NSZeroRect, viewPort) ||
        CGRectIsEmpty(viewPort) ||
        CGRectIsNull(viewPort) ||
        viewPort.size.width <= 0 ||
        viewPort.size.height <= 0) {
        *valid = NO;
        return NSZeroRect;
    }

    *valid = YES;
    return viewPort;
}

- (void)drawInRect:(NSRect)rect
           context:(CGContextRef)context
{
    [self _drawInRect:rect context:context error:nil];
}

//- (BOOL)_drawInRect:(NSRect)rect
//            context:(CGContextRef)ref
//              error:(NSError**)error
//{
//    // prep for draw...
//    CGContextSaveGState(ref);
//    @try {
//        [self _beginDraw:rect];
//
//        // we also need to calculate the viewport so we can clip
//        // the drawing if needed
//        BOOL canDraw = NO;
//        NSRect viewPort = [self computeRectDrawingInRect:rect isValid:&canDraw];
//        // check the viewport
//        if (canDraw == NO) {
//            if (error != NULL) {
//                *error = [[[NSError alloc] initWithDomain:IJSVGErrorDomain
//                                                     code:IJSVGErrorDrawing
//                                                 userInfo:nil] autorelease];
//            }
//        } else {
//            // clip to mask
//            if (self.clipToViewport == YES) {
//                CGContextClipToRect(ref, viewPort);
//            }
//
//            // add the origin back onto the viewport
//            viewPort.origin.x -= (_viewBox.origin.x) * _scale;
//            viewPort.origin.y -= (_viewBox.origin.y) * _scale;
//
//            // transforms
//            CGContextTranslateCTM(ref, viewPort.origin.x, viewPort.origin.y);
//            CGContextScaleCTM(ref, _scale, _scale);
//
//            // do we need to update the backing scales on the
//            // layers?
//            [self backingScaleFactor:nil];
//
//            CGInterpolationQuality quality;
//            switch (self.renderQuality) {
//            case kIJSVGRenderQualityLow: {
//                quality = kCGInterpolationLow;
//                break;
//            }
//            case kIJSVGRenderQualityOptimized: {
//                quality = kCGInterpolationMedium;
//                break;
//            }
//            default: {
//                quality = kCGInterpolationHigh;
//            }
//            }
//            CGContextSetInterpolationQuality(ref, quality);
//            BOOL hasTransaction = IJSVGBeginTransaction();
//            [self.layer renderInContext:ref];
//            if (hasTransaction == YES) {
//                IJSVGEndTransaction();
//            }
//        }
//    } @catch (NSException* exception) {
//        // just catch and give back a drawing error to the caller
//        if (error != NULL) {
//            *error = [[[NSError alloc] initWithDomain:IJSVGErrorDomain
//                                                 code:IJSVGErrorDrawing
//                                             userInfo:nil] autorelease];
//        }
//    }
//    CGContextRestoreGState(ref);
//    return (error == nil);
//}

- (BOOL)_drawInRect:(NSRect)rect
            context:(CGContextRef)ref
              error:(NSError**)error
{
    BOOL transaction = IJSVGBeginTransaction();
    CGContextSaveGState(ref);
    // make sure we setup a transaction
    CGFloat backingScale = [self backingScaleFactor];
    [IJSVGLayer logLayer:self.rootLayer];
    [self.rootLayer renderInContext:ref
                           viewPort:rect
                       backingScale:backingScale
                            quality:_renderQuality];    
    CGContextRestoreGState(ref);
    if(transaction) {
        IJSVGEndTransaction();
    }
    return YES;
}

- (IJSVGLayerTree*)layerTree
{
    if(_layerTree == nil) {
        _layerTree = [[IJSVGLayerTree alloc] init];
    }
    return _layerTree;
}

- (IJSVGRootLayer*)rootLayer
{
    if(_rootLayer == nil) {
        _rootLayer = [self.layerTree rootLayerForRootNode:_rootNode].retain;
    }
    return _rootLayer;
}

- (CGFloat)backingScaleFactor
{
    __block CGFloat scale = 1.f;
    scale = (self.renderingBackingScaleHelper)();
    if (scale < 1.f) {
        scale = 1.f;
    }
    return _backingScale = scale;
}

- (void)setRenderingStyle:(IJSVGRenderingStyle*)style
{
    (void)([_renderingStyle release]), _renderingStyle = nil;
    _renderingStyle = style.retain;
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id>*)change
                       context:(void*)context
{
    // invalidate the tree if a style is set
    if (object == _renderingStyle) {
        [self invalidateLayerTree];
    }
}

- (void)setNeedsDisplay
{
    [self invalidateLayerTree];
}

- (void)invalidateLayerTree
{
    (void)([_layerTree release]), _layerTree = nil;
}

- (IJSVGColorList*)colorList
{
    IJSVGColorList* sheet = [[[IJSVGColorList alloc] init] autorelease];
    void (^block)(CALayer* layer, BOOL* stop) =
    ^void(CALayer* layer, BOOL* stop) {
        
        // dont do anything
        if(([layer isKindOfClass:IJSVGShapeLayer.class] &&
            layer.isHidden == NO) == NO) {
            return;
        }
        
          
        // compute
        IJSVGShapeLayer* sLayer = (IJSVGShapeLayer*)layer;
        NSColor* color = nil;

        // fill color
        if (sLayer.fillColor != nil) {
            color = [NSColor colorWithCGColor:sLayer.fillColor];
            color = [IJSVGColor computeColorSpace:color];
            if (color.alphaComponent != 0.f) {
                IJSVGColorType* type = nil;
                type = [IJSVGColorType typeWithColor:color
                                               flags:IJSVGColorTypeFlagFill];
                [sheet addColor:type];
            }
        }

        // stroke color
        if (sLayer.strokeColor != nil) {
            color = [NSColor colorWithCGColor:sLayer.strokeColor];
            color = [IJSVGColor computeColorSpace:color];
            if (color.alphaComponent != 0.f) {
                IJSVGColorType* type = nil;
                type = [IJSVGColorType typeWithColor:color
                                               flags:IJSVGColorTypeFlagStroke];
                [sheet addColor:type];
            }
        }

        // check for any patterns or strokes
        if (sLayer.patternFillLayer != nil || sLayer.gradientFillLayer != nil ||
           sLayer.gradientStrokeLayer != nil || sLayer.patternStrokeLayer != nil) {
            
           // add any colors from gradients
            IJSVGGradientLayer* gradLayer = nil;
            IJSVGGradientLayer* gradStrokeLayer = nil;
            
            // gradient fill
            if ((gradLayer = sLayer.gradientFillLayer) != nil) {
                IJSVGColorList* gradSheet = gradLayer.gradient.colorList;
                [sheet addColorsFromList:gradSheet];
            }
            
            // gradient stroke layers
            if ((gradStrokeLayer = sLayer.gradientStrokeLayer) != nil) {
                IJSVGColorList* gradSheet = gradStrokeLayer.gradient.colorList;
                [sheet addColorsFromList:gradSheet];
            }
        }
    };
    
    // gogogo!
    [IJSVGLayer recursivelyWalkLayer:self.rootLayer
                           withBlock:block];
    return sheet;
}

- (void)_beginDraw:(NSRect)rect
{
    // in order to correctly fit the the SVG into the
    // rect, we need to work out the ratio scale in order
    // to transform the paths into our viewbox
    NSSize dest = rect.size;
    NSSize source = _viewBox.size;
    NSSize propSize = [self computeSVGSizeWithRenderSize:rect.size];
    _clipScale = MIN(dest.width / propSize.width,
        dest.height / propSize.height);

    // work out the actual scale based on the clip scale
    CGFloat w = propSize.width * _clipScale;
    CGFloat h = propSize.height * _clipScale;
    _scale = MIN(w / source.width, h / source.height);
}

#pragma mark NSPasteboard

- (NSArray*)writableTypesForPasteboard:(NSPasteboard*)pasteboard
{
    return @[ NSPasteboardTypePDF ];
}

- (id)pasteboardPropertyListForType:(NSString*)type
{
    if ([type isEqualToString:NSPasteboardTypePDF]) {
        return [self PDFData];
    }
    return nil;
}

#pragma mark IJSVGParserDelegate

- (void)svgParser:(IJSVGParser*)svg
      foundSubSVG:(IJSVG*)subSVG
    withSVGString:(NSString*)string
{
    if (_delegate != nil && _respondsTo.shouldHandleSubSVG == 1) {
        [_delegate svg:self
              foundSubSVG:subSVG
            withSVGString:string];
    }
}

#pragma mark matching

- (BOOL)matchesPropertiesWithMask:(IJSVGMatchPropertiesMask)mask
{
    __block IJSVGMatchPropertiesMask matchedMask = IJSVGMatchPropertyNone;
    IJSVGNodeWalkHandler handler = ^(IJSVGNode* node, BOOL* allowChildNodes,
                                     BOOL* stop) {
        // dont compute nodes that are not designed
        // to be rendered
        if(node.shouldRender == NO) {
            *allowChildNodes = NO;
            return;
        }
        
        // check for stroke
        IJSVGPath* path = (IJSVGPath*)node;
        if((mask & IJSVGMatchPropertyContainsStrokedElement) != 0 &&
           [node isKindOfClass:IJSVGPath.class] == YES &&
           [path matchesTraits:IJSVGNodeTraitStroked] == YES) {
            matchedMask |= IJSVGMatchPropertyContainsStrokedElement;
        }
        
        // check for mask
        if((mask & IJSVGMatchPropertyContainsMaskedElement) != 0 &&
           node.mask != nil) {
            matchedMask |= IJSVGMatchPropertyContainsMaskedElement;
        }
        
        // simply check if masks equal, if they are, stop this loop
        // and return the evaluation
        if(matchedMask == mask) {
            *stop = YES;
        }
    };
    [IJSVGNode walkNodeTree:_rootNode
                    handler:handler];
    return matchedMask == mask;
}

@end
