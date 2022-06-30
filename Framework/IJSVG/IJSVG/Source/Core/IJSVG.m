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
        return [[self alloc] initWithFile:str
                                     error:error
                                  delegate:delegate];
    }
    
    // check the asset catalogues
    return [[self alloc] initWithDataAssetNamed:string
                                           error:error];
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
    if (hasTransaction == YES) {
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
    if ((self = [super init]) != nil) {
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
        _rootNode = parser.rootNode;
        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];

        // something went wrong...
        if (_rootNode == nil) {
            if (error != NULL) {
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
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:string
                                                                error:&anError
                                                             delegate:self];
        _rootNode = parser.rootNode;

        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];

        // something went wrong :(
        if (_rootNode == nil) {
            if (error != NULL) {
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
    if (hasTransaction == YES) {
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

- (CGRect)viewBox
{
    return _viewBox;
}

- (IJSVGGroup*)rootNode
{
    return _rootNode;
}

- (BOOL)isFont
{
    return NO;//[_rootNode isFont];
}

- (NSArray<IJSVGPath*>*)glyphs
{
    return @[];//[_rootNode glyphs];
}

- (NSArray<IJSVG*>*)subSVGs:(BOOL)recursive
{
    NSMutableArray<IJSVG*>* svgs = [[NSMutableArray alloc] init];
    IJSVGNodeWalkHandler handler = ^(IJSVGNode *node,
                                     BOOL *allowChildNodes,
                                     BOOL *stop) {
        if(node.class == IJSVGRootNode.class) {
            IJSVGRootNode* root = (IJSVGRootNode*)node.copy;
            IJSVG* newSVG = [[self.class alloc] initWithRootNode:root];
            if(newSVG != nil) {
                [svgs addObject:newSVG];
            }
        }
    };
    [IJSVGNode walkNodeTree:_rootNode
                    handler:handler];
    return svgs;
}

- (IJSVGExporter*)exporterWithOptions:(IJSVGExporterOptions)options
                 floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
 return [[IJSVGExporter alloc] initWithSVG:self
                                      size:_viewBox.size
                                   options:options
                      floatingPointOptions:floatingPointOptions];
}

- (NSString*)SVGStringWithOptions:(IJSVGExporterOptions)options
{
    IJSVGFloatingPointOptions fpo = IJSVGFloatingPointOptionsDefault();
    return [self exporterWithOptions:options
                floatingPointOptions:fpo].SVGString;
}

- (NSString*)SVGStringWithOptions:(IJSVGExporterOptions)options
             floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    return [self exporterWithOptions:options
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
    CGFloat ratio = ogSize.height / ogSize.width;
    ogSize.width = aSize.width * ratio;
    ogSize.height = aSize.height * ratio;
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
    if (view == nil) {
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
    if (@available(macOS 10.10, *)) {
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
    CGFloat backingScale = [self backingScaleFactor];
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
    (void)(_layerTree), _layerTree = nil;
}

- (IJSVGColorList*)colorList
{
    IJSVGColorList* sheet = [[IJSVGColorList alloc] init];
    void (^block)(CALayer* layer, BOOL* stop) =
    ^void(CALayer* layer, BOOL* stop) {
        
//        // dont do anything
//        if(([layer isKindOfClass:IJSVGShapeLayer.class] &&
//            layer.isHidden == NO) == NO) {
//            return;
//        }
//        
//          
//        // compute
//        IJSVGShapeLayer* sLayer = (IJSVGShapeLayer*)layer;
//        NSColor* color = nil;
//
//        // fill color
//        if (sLayer.fillColor != nil) {
//            color = [NSColor colorWithCGColor:sLayer.fillColor];
//            color = [IJSVGColor computeColorSpace:color];
//            if (color.alphaComponent != 0.f) {
//                IJSVGColorType* type = nil;
//                type = [IJSVGColorType typeWithColor:color
//                                               flags:IJSVGColorTypeFlagFill];
//                [sheet addColor:type];
//            }
//        }
//
//        // stroke color
//        if (sLayer.strokeColor != nil) {
//            color = [NSColor colorWithCGColor:sLayer.strokeColor];
//            color = [IJSVGColor computeColorSpace:color];
//            if (color.alphaComponent != 0.f) {
//                IJSVGColorType* type = nil;
//                type = [IJSVGColorType typeWithColor:color
//                                               flags:IJSVGColorTypeFlagStroke];
//                [sheet addColor:type];
//            }
//        }
//
//        // check for any patterns or strokes
//        if (sLayer.patternFillLayer != nil || sLayer.gradientFillLayer != nil ||
//           sLayer.gradientStrokeLayer != nil || sLayer.patternStrokeLayer != nil) {
//            
//           // add any colors from gradients
//            IJSVGGradientLayer* gradLayer = nil;
//            IJSVGGradientLayer* gradStrokeLayer = nil;
//            
//            // gradient fill
//            if ((gradLayer = sLayer.gradientFillLayer) != nil) {
//                IJSVGColorList* gradSheet = gradLayer.gradient.colorList;
//                [sheet addColorsFromList:gradSheet];
//            }
//            
//            // gradient stroke layers
//            if ((gradStrokeLayer = sLayer.gradientStrokeLayer) != nil) {
//                IJSVGColorList* gradSheet = gradStrokeLayer.gradient.colorList;
//                [sheet addColorsFromList:gradSheet];
//            }
//        }
    };
    
    // gogogo!
    [IJSVGLayer recursivelyWalkLayer:self.rootLayer
                           withBlock:block];
    return sheet;
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
