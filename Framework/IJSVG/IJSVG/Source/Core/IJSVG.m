//
//  IJSVGImage.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGExporter.h>
#import <IJSVG/IJSVGTransaction.h>

@implementation IJSVG

// these are explicitly implemented
@synthesize title = _title;
@synthesize desc = _desc;

- (void)dealloc
{
    // this can all be called on the background thread to be released
    BOOL hasTransaction = IJSVGBeginTransaction();
    // kill any memory that has been around
    (void)(_layerTree), _layerTree = nil;
    if(hasTransaction == YES) {
        IJSVGEndTransaction();
    }
}

+ (id)SVGNamed:(NSString*)string
{
    return [self.class svgNamed:string
                          error:nil];
}

+ (id)svgNamed:(NSString*)string
         error:(NSError**)error
{
    NSBundle* bundle = NSBundle.mainBundle;
    NSString* str = nil;
    NSString* ext = [string pathExtension];
    if(ext == nil || ext.length == 0) {
        ext = @"svg";
    }
    if((str = [bundle pathForResource:[string stringByDeletingPathExtension]
                                ofType:ext]) != nil) {
        return [[self alloc] initWithFile:str
                                    error:error];
    }
    
    // check the asset catalogues
    return [[self alloc] initWithDataAssetNamed:string
                                           error:error];
}

+ (IJSVG*)SVGFromCGPathRef:(CGPathRef)path
{
    return [self SVGFromCGPathRef:path
                          flipped:NO];
}

+ (IJSVG*)SVGFromCGPathRef:(CGPathRef)path
                   flipped:(BOOL)flipped
{
    CGRect box = CGPathGetPathBoundingBox(path);
    IJSVGRootNode* rootNode = [[IJSVGRootNode alloc] init];
    rootNode.viewBox = [IJSVGUnitRect rectWithCGRect:box];
    CGMutablePathRef nPath = NULL;
    if(flipped) {
        CGPathRef transformedPath = [IJSVGUtils newFlippedCGPath:path];
        nPath = CGPathCreateMutableCopy(transformedPath);
        CGPathRelease(transformedPath);
    } else {
        nPath = CGPathCreateMutableCopy(path);
    }
    IJSVGPath* childPath = [[IJSVGPath alloc] init];
    childPath.path = nPath;
    [rootNode addChild:childPath];
    CGPathRelease(nPath);
    return [[self.class alloc] initWithRootNode:rootNode];
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
    NSDataAsset* dataAsset = [[NSDataAsset alloc] initWithName:name
                                                         bundle:bundle];
    if(dataAsset != nil) {
        return [self initWithSVGData:dataAsset.data
                                error:error];
    }
    return nil;
}

- (id)initWithImage:(NSImage*)image
{
    __block IJSVGGroupLayer* layer = nil;
    __block IJSVGImageLayer* imageLayer = nil;

    // create the layers we require
    IJSVGImage* imageNode = [[IJSVGImage alloc] init];
    imageNode.image = image;
    
    BOOL hasTransaction = IJSVGBeginTransaction();
    layer = [[IJSVGGroupLayer alloc] init];
    imageLayer =
        [[IJSVGImageLayer alloc] initWithImage:imageNode];
    [layer addSublayer:imageLayer];
    if(hasTransaction == YES) {
        IJSVGEndTransaction();
    }

    // return the initialized SVG
    return [self initWithSVGLayer:layer
                          viewBox:imageLayer.frame];
}

- (id)initWithSVGLayer:(IJSVGGroupLayer*)group
               viewBox:(CGRect)viewBox
{
    // this completely bypasses passing of files
    if((self = [super init]) != nil) {
        // keep the layer tree
        _viewBox = viewBox;

        // any setups
        [self _setupBasicsFromAnyInitializer];
    }
    return self;
}

- (id)initWithRootNode:(IJSVGRootNode*)rootNode
{
    if((self = [super init]) != nil) {
        _rootNode = rootNode;
        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];
    }
    return self;
}

- (id)initWithFile:(NSString*)file
{
    return [self initWithFile:file
                        error:nil];
}

- (id)initWithFile:(NSString*)file
             error:(NSError**)error
{
    return [self initWithFilePathURL:[NSURL fileURLWithPath:file isDirectory:NO]
                               error:error];
}

- (id)initWithFilePathURL:(NSURL*)aURL
{
    return [self initWithFilePathURL:aURL
                               error:nil];
}

- (id)initWithFilePathURL:(NSURL*)aURL
                    error:(NSError**)error
{
    // create the object
    if((self = [super init]) != nil) {
        NSError* anError = nil;

        // create the group
        IJSVGParser* parser = [IJSVGParser parserForFileURL:aURL
                                                      error:&anError];
        _rootNode = parser.rootNode;
        
        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];

        // something went wrong...
        if(_rootNode == nil) {
            if(error != NULL) {
                *error = anError;
            }
            (void)(self), self = nil;
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
    return [self initWithSVGString:svgString
                             error:error];
}

- (id)initWithSVGString:(NSString*)string
{
    return [self initWithSVGString:string
                             error:nil];
}

- (id)initWithSVGString:(NSString*)string
                  error:(NSError**)error
{
    if((self = [super init]) != nil) {
        // this is basically the same as init with URL just
        // bypasses the loading of a file
        NSError* anError = nil;

        // setup the parser
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:string
                                                                error:&anError];
        _rootNode = parser.rootNode;

        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];

        // something went wrong :(
        if(_rootNode == nil) {
            if(error != NULL) {
                *error = anError;
            }
            (void)(self), self = nil;
            return nil;
        }
    }
    return self;
}

- (void)performBlock:(dispatch_block_t)block
{
    BOOL hasTransaction = IJSVGBeginTransaction();
    block();
    if(hasTransaction == YES) {
        IJSVGEndTransaction();
    }
}

- (void)_setupBasicInfoFromGroup
{
    _viewBox = [_rootNode.viewBox computeValue:CGSizeZero];
    _intrinsicSize = _rootNode.intrinsicSize;
}

- (CGSize)size
{
    return [_intrinsicSize computeValue:self.defaultSize];
}

- (CGSize)sizeWithDefaultSize:(CGSize)size
{
    return [_intrinsicSize computeValue:size];
}

- (void)_setupBasicsFromAnyInitializer
{
    self.style = [[IJSVGStyle alloc] init];
    self.ignoreIntrinsicSize = YES;
    self.renderQuality = kIJSVGRenderQualityFullResolution;
    self.defaultSize = CGSizeMake(200.f, 200.f);
    self.renderingBackingScaleHelper = ^CGFloat {
        if(NSScreen.mainScreen != nil) {
            return NSScreen.mainScreen.backingScaleFactor;
        }
        return 1.f;
    };
}

- (BOOL)hasDynamicSize
{
    IJSVGUnitSize* size = _intrinsicSize;
    return size.width.type == IJSVGUnitLengthTypePercentage ||
        size.height.type == IJSVGUnitLengthTypePercentage;
}

- (IJSVGIntrinsicDimensions)intrinsicDimensions
{
    return self.rootNode.intrinsicDimensions;
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


- (CGRect)viewBox
{
    return _viewBox;
}

- (IJSVGRootNode*)rootNode
{
    return _rootNode;
}

- (NSSet<IJSVG*>*)directDescendSVGs
{
    NSMutableSet<IJSVG*>* svgs = [[NSMutableSet alloc] init];
    NSSet<IJSVGNode*>* nodes = [self.rootNode childrenOfType:IJSVGNodeTypeSVG];
    for(IJSVGNode* node in nodes) {
        IJSVG* newSVG = nil;
        newSVG = [[self.class alloc] initWithRootNode:(IJSVGRootNode*)node];
        [svgs addObject:newSVG];
    }
    return svgs;
}

- (IJSVGExporter*)exporterWithSize:(CGSize)size
                           options:(IJSVGExporterOptions)options
              floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    return [[IJSVGExporter alloc] initWithSVG:self
                                         size:size
                                      options:options
                         floatingPointOptions:floatingPointOptions];
}

- (NSString*)SVGStringWithOptions:(IJSVGExporterOptions)options
{
    IJSVGFloatingPointOptions fpo = IJSVGFloatingPointOptionsDefault();
    return [self exporterWithSize:_viewBox.size
                          options:options
                floatingPointOptions:fpo].SVGString;
}

- (NSString*)SVGStringWithOptions:(IJSVGExporterOptions)options
             floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    return [self exporterWithSize:_viewBox.size
                          options:options
             floatingPointOptions:floatingPointOptions].SVGString;
}

- (NSString *)SVGStringWithSize:(CGSize)size
                        options:(IJSVGExporterOptions)options
{
    IJSVGFloatingPointOptions fpo = IJSVGFloatingPointOptionsDefault();
    return [self exporterWithSize:size
                          options:options
             floatingPointOptions:fpo].SVGString;
}

- (NSString *)SVGStringWithSize:(CGSize)size
                        options:(IJSVGExporterOptions)options
           floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    return [self exporterWithSize:size
                          options:options
             floatingPointOptions:floatingPointOptions].SVGString;
}

- (NSImage*)imageWithSize:(CGSize)aSize
{
    return [self imageWithSize:aSize
                       flipped:NO
                         error:nil];
}

- (NSImage*)imageWithSize:(CGSize)aSize
                    error:(NSError**)error;
{
    return [self imageWithSize:aSize
                       flipped:NO
                         error:error];
}

- (NSImage*)imageWithSize:(CGSize)aSize
                  flipped:(BOOL)flipped
{
    return [self imageWithSize:aSize
                       flipped:flipped
                         error:nil];
}

- (CGImageRef)newCGImageRefWithSize:(CGSize)size
                            flipped:(BOOL)flipped
                              error:(NSError**)error
{
    // setup the drawing rect, this is used for both the intial drawing
    // and the backing scale helper block
    CGRect rect = (CGRect) {
        .origin = CGPointZero,
        .size = (CGSize)size
    };

    // make sure we setup the scale based on the backing scale factor
    CGFloat scale = [self backingScaleFactor];

    // create the context and colorspace
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ref = CGBitmapContextCreate(NULL, (int)size.width * scale,
        (int)size.height * scale, 8, 0, colorSpace,
        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);

    // scale the context
    CGContextScaleCTM(ref, scale, scale);

    if(flipped == YES) {
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

- (NSImage*)imageWithSize:(CGSize)aSize
                  flipped:(BOOL)flipped
                    error:(NSError**)error
{
    CGImageRef ref = [self newCGImageRefWithSize:aSize
                                         flipped:flipped
                                           error:error];

    NSImage* image = [[NSImage alloc] initWithCGImage:ref
                                                 size:aSize];
    CGImageRelease(ref);
    return image;
}

- (NSImage*)imageByMaintainingAspectRatioWithSize:(CGSize)aSize
                                          flipped:(BOOL)flipped
                                            error:(NSError**)error
{
    CGSize ogSize = _rootNode.intrinsicSize.value;
    CGFloat ratio = 0.f;
    CGFloat imageWidth = ogSize.width;
    CGFloat imageHeight = ogSize.height;
    CGFloat maxWidth = aSize.width;
    CGFloat maxHeight = aSize.height;
    if(imageWidth > imageHeight) {
        ratio = maxWidth / imageWidth;
    } else {
        ratio = maxHeight / imageHeight;
    }
    ogSize.width = imageWidth * ratio;
    ogSize.height = imageHeight * ratio;
    return [self imageWithSize:ogSize
                       flipped:flipped
                         error:error];
}

- (NSData*)PDFData
{
    return [self PDFData:nil];
}

- (NSData*)PDFData:(NSError**)error
{
    return [self
        PDFDataWithRect:(CGRect) { .origin = NSZeroPoint, .size = _viewBox.size }
                  error:error];
}

- (NSData*)PDFDataWithRect:(CGRect)rect
{
    return [self PDFDataWithRect:rect error:nil];
}

- (NSData*)PDFDataWithRect:(CGRect)rect
                     error:(NSError**)error
{
    // create the data for the PDF
    NSMutableData* data = [[NSMutableData alloc] init];

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
    // draw the icon
    [self _drawInRect:(CGRect)box
              context:context
                error:error];

    CGContextEndPage(context);

    // clean up
    CGPDFContextClose(context);
    CGContextRelease(context);
    CGDataConsumerRelease(dataConsumer);
    return data;
}

- (void)prepForDrawingInView:(NSView*)view
{
    // kill the render
    if(view == nil) {
        self.renderingBackingScaleHelper = nil;
        return;
    }

    // construct the layer before drawing
    [self rootLayer];

    // set the scale
    __weak NSView* weakView = view;
    self.renderingBackingScaleHelper = ^CGFloat {
        return weakView.window.screen.backingScaleFactor;
    };
}

- (BOOL)drawAtPoint:(CGPoint)point
               size:(CGSize)aSize
{
    return [self drawAtPoint:point
                        size:aSize
                       error:nil];
}

- (BOOL)drawAtPoint:(CGPoint)point
               size:(CGSize)aSize
              error:(NSError**)error
{
    return [self drawInRect:NSMakeRect(point.x, point.y,
                                       aSize.width, aSize.height)
                      error:error];
}

- (BOOL)drawInRect:(CGRect)rect
{
    return [self drawInRect:rect error:nil];
}

- (BOOL)drawInRect:(CGRect)rect
             error:(NSError**)error
{
    CGContextRef currentCGContext;
    if(@available(macOS 10.10, *)) {
        currentCGContext = NSGraphicsContext.currentContext.CGContext;
    } else {
        currentCGContext = NSGraphicsContext.currentContext.graphicsPort;
    }
    return [self _drawInRect:rect
                     context:currentCGContext
                       error:error];
}

- (void)drawInRect:(CGRect)rect
           context:(CGContextRef)context
{
    [self _drawInRect:rect
              context:context
                error:nil];
}

- (BOOL)_drawInRect:(CGRect)rect
            context:(CGContextRef)ctx
              error:(NSError**)error
{
    BOOL transaction = IJSVGBeginTransaction();
    CGContextSaveGState(ctx);
    CGFloat backingScale = MAX([self backingScaleFactor], 1.f);
    CGInterpolationQuality quality;
    switch (_renderQuality) {
        case kIJSVGRenderQualityLow: {
            quality = kCGInterpolationLow;
            break;
        }
        case kIJSVGRenderQualityOptimized: {
            quality = kCGInterpolationMedium;
            break;
        }
        default: {
            quality = kCGInterpolationHigh;
        }
    }
    CGContextSetInterpolationQuality(ctx, quality);
    IJSVGRootLayer* rootLayer = self.rootLayer;
    [rootLayer renderInContext:ctx
                      viewPort:rect
                  backingScale:backingScale
                       quality:_renderQuality
           ignoreIntrinsicSize:_ignoreIntrinsicSize];
    CGContextRestoreGState(ctx);
    if(transaction == YES) {
        IJSVGEndTransaction();
    }
    return YES;
}

- (IJSVGLayerTree*)layerTree
{
    if(_layerTree == nil) {
        _layerTree = [[IJSVGLayerTree alloc] init];
        _layerTree.style = _style;
    }
    return _layerTree;
}

- (IJSVGRootLayer*)rootLayer
{
    if(_rootLayer == nil) {
        _rootLayer = [self.layerTree rootLayerForRootNode:_rootNode];
    }
    return _rootLayer;
}

- (CGFloat)backingScaleFactor
{
    __block CGFloat scale = 1.f;
    if(self.renderingBackingScaleHelper != nil) {
        scale = (self.renderingBackingScaleHelper)();
    }
    scale = MAX(1.f, scale);
    return _backingScale = scale;
}

- (void)setNeedsDisplay
{
    [self invalidateLayerTree];
}

- (void)invalidateLayerTree
{
    (void)(_rootLayer), _rootLayer = nil;
    (void)(_layerTree), _layerTree = nil;
}

- (IJSVGTraitedColorStorage*)colors
{
    return self.rootLayer.colors;
}

#pragma mark NSPasteboard

- (NSArray*)writableTypesForPasteboard:(NSPasteboard*)pasteboard
{
    return @[ NSPasteboardTypePDF ];
}

- (id)pasteboardPropertyListForType:(NSString*)type
{
    if([type isEqualToString:NSPasteboardTypePDF]) {
        return [self PDFData];
    }
    return nil;
}

#pragma mark matching

- (BOOL)containsNodesMatchingTraits:(IJSVGNodeTraits)traits
{
    return [_rootNode containsNodesMatchingTraits:traits];
}

@end
