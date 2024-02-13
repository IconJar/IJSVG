//
//  IJSVG.m
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <IJSVGQuartzRenderer.h>
#import <IJSVG/IJSVGExporter.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGXEntities.h>

@interface IJSVG (private)
@property (nonatomic, strong) IJSVGParser* parser;
@end

@interface IJSVG () {
  IJSVGQuartzRenderer* _quartzRenderer;
  IJSVGRootNode* _artworkFittingRoot;
  IJSVGGroup* _artworkFittingGroup;
}
@end

@implementation IJSVG

// these are explicitly implemented
@synthesize title = _title;
@synthesize desc = _desc;

- (void)dealloc
{
    IJSVGThreadManager* threadManager = IJSVGThreadManager.currentManager;
    // tell the thread manager we are done with
    [threadManager remove:self];
}

+ (id)SVGNamed:(NSString*)string
{
    return [self.class SVGNamed:string
                          error:nil];
}

+ (id)SVGNamed:(NSString*)string
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
    IJSVGPath* childPath = [[IJSVGPath alloc] init];
    CGAffineTransform transform = flipped ? IJSVGPathFlippingTransform(path) : CGAffineTransformIdentity;
    CGPathAddPath(childPath.path, &transform, path);
    [rootNode addChild:childPath];
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

- (id)initWithImage:(XImage*)image
{
    IJSVGRootNode* rootNode = [[IJSVGRootNode alloc] init];
    IJSVGImage* imageNode = [[IJSVGImage alloc] init];
    imageNode.image = image;
    IJSVGUnitSize* size = [IJSVGUnitSize sizeWithCGSize:imageNode.intrinsicSize];
    IJSVGUnitRect* viewBox = [IJSVGUnitRect rectWithOrigin:IJSVGUnitPoint.zeroPoint
                                                      size:size];
    imageNode.width = size.width.copy;
    imageNode.height = size.height.copy;
    rootNode.intrinsicSize = [IJSVGUnitSize sizeWithWidth:imageNode.width.copy
                                                   height:imageNode.height.copy];
    rootNode.viewBox = viewBox;
    [rootNode addChild:imageNode];
    return [self initWithRootNode:rootNode];
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
        IJSVGParser *parser = [IJSVGParser parserForFileURL:aURL
                                                      error:&anError];
        self.parser = parser;
      
        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];

        // something went wrong...
        if(_rootNode == nil) {
            if(error != NULL) {
                *error = anError;
            }
            self = nil;
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

- (void)setParser:(IJSVGParser*)parser {
    _rootNode = [parser rootNodeWithSize:CGSizeZero];
    _parser = nil;
}

- (id)initWithSVGData:(NSData*)data
                error:(NSError**)error
{
    if((self = [super init]) != nil) {
        NSError* anError = nil;

        // setup the parser directly from data to avoid creating an intermediate SVG string
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGData:data
                                                           fileURL:nil
                                                             error:&anError];
        self.parser = parser;
      
        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];

        // something went wrong :(
        if(_rootNode == nil) {
            if(error != NULL) {
                *error = anError;
            }
            self = nil;
            return nil;
        }
    }
    return self;
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
                                                             fileURL:nil
                                                               error:&anError];
        self.parser = parser;
      
        [self _setupBasicInfoFromGroup];
        [self _setupBasicsFromAnyInitializer];

        // something went wrong :(
        if(_rootNode == nil) {
            if(error != NULL) {
                *error = anError;
            }
            self = nil;
            return nil;
        }
    }
    return self;
}

- (void)performBlock:(dispatch_block_t)block
{
    block();
}

- (void)_setupBasicInfoFromGroup
{
    CGSize resolvingSize = _rootNode.clientSize;
    _viewBox = [_rootNode.viewBox computeValue:resolvingSize];
    _intrinsicSize = _rootNode.intrinsicSize;
}

- (CGSize)size
{
    return [_intrinsicSize computeValue:IJSVG_SIZE_DEFAULT_CLIENT];
}

- (IJSVGUnitSize*)intrinsicUnitSize
{
    return _intrinsicSize.copy;
}

// Sets the rendering defaults shared by every initializer.
- (void)_setupBasicsFromAnyInitializer
{
    _renderingOptions = [[IJSVGRenderingOptions alloc] init];
    self.style = [[IJSVGStyle alloc] init];
    self.renderingBackingScaleHelper = ^CGFloat {
        if(XScreen.mainScreen != nil) {
            return XScreen.mainScreen.backingScaleFactor;
        }
        return 1.f;
    };
    
    // tell the thread manager we exist
    [IJSVGThreadManager.currentManager adopt:self];
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


// Calculates uniform fitting around the original canvas center.
- (CGAffineTransform)artworkFittingTransform
{
    CGRect viewport = self.viewBox;
    if(CGRectIsEmpty(viewport) ||
       !isfinite(CGRectGetMinX(viewport)) || !isfinite(CGRectGetMinY(viewport)) ||
       !isfinite(CGRectGetMaxX(viewport)) || !isfinite(CGRectGetMaxY(viewport))) {
        return CGAffineTransformIdentity;
    }
    CGRect bounds = self.artworkBounds;
    if(CGRectIsEmpty(bounds) ||
       !isfinite(CGRectGetMinX(viewport)) || !isfinite(CGRectGetMinY(viewport)) ||
       !isfinite(CGRectGetMaxX(viewport)) || !isfinite(CGRectGetMaxY(viewport)) ||
       !isfinite(CGRectGetMinX(bounds)) || !isfinite(CGRectGetMinY(bounds)) ||
       !isfinite(CGRectGetMaxX(bounds)) || !isfinite(CGRectGetMaxY(bounds)) ||
       CGRectContainsRect(viewport, bounds)) {
        return CGAffineTransformIdentity;
    }
    CGFloat horizontal = MAX(CGRectGetMidX(viewport) - CGRectGetMinX(bounds),
                             CGRectGetMaxX(bounds) - CGRectGetMidX(viewport));
    CGFloat vertical = MAX(CGRectGetMidY(viewport) - CGRectGetMinY(bounds),
                           CGRectGetMaxY(bounds) - CGRectGetMidY(viewport));
    // Divide before multiplying to avoid overflow for very large coordinates.
    CGFloat scale = MIN(1.f, MIN((viewport.size.width / 2.f) / horizontal,
                                (viewport.size.height / 2.f) / vertical));
    if(!isfinite(scale) || scale <= 0.f || scale >= 1.f - 1e-12) {
        return CGAffineTransformIdentity;
    }
    return CGAffineTransformMake(scale, 0.f, 0.f, scale,
                                 CGRectGetMidX(viewport) * (1.f - scale),
                                 CGRectGetMidY(viewport) * (1.f - scale));
}

// Replaces the fitting transform so repeated adjustments never accumulate scale.
- (void)fitArtworkToViewBox:(BOOL)enabled
{
    IJSVGRootNode* root = self.rootNode;
    if(root == nil) {
        return;
    }
    if(_artworkFittingRoot != root ||
       (_artworkFittingGroup != nil && _artworkFittingGroup.rootNode != root)) {
        _artworkFittingRoot = nil;
        _artworkFittingGroup = nil;
    }
    _artworkFittingGroup.transforms = @[];
    if(enabled) {
        CGAffineTransform transform = [self artworkFittingTransform];
        if(!CGAffineTransformIsIdentity(transform)) {
            if(_artworkFittingGroup == nil) {
                _artworkFittingGroup = [[IJSVGGroup alloc] init];
                [_artworkFittingGroup addChildren:root.children];
                [root addChild:_artworkFittingGroup];
                _artworkFittingRoot = root;
            }
            // Preserve full precision without formatting and parsing an SVG string.
            IJSVGTransform* fitting = [[IJSVGTransform alloc] init];
            fitting.command = IJSVGTransformCommandMatrix;
            CGFloat parameters[] = { transform.a, transform.b, transform.c,
                                     transform.d, transform.tx, transform.ty };
            [fitting setParameters:parameters count:6];
            _artworkFittingGroup.transforms = @[fitting];
        }
    }
    [self setNeedsDisplay];
}

// Measures styled geometry without clipping it to the outer viewport.
- (CGRect)artworkBounds
{
    IJSVGRootNode* root = self.rootNode;
    if(root == nil) {
        return CGRectNull;
    }
    IJSVGQuartzRenderer* renderer = [[IJSVGQuartzRenderer alloc] init];
    renderer.style = self.style;
    // This query measures geometry only and must not prepare filter resources.
    IJSVGRenderingOptions* options = self.renderingOptions ?: [[IJSVGRenderingOptions alloc] init];
    options.filtersEnabled = NO;
    renderer.renderingOptions = options;
    return [renderer artworkBoundsForRootNode:root];
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
    NSArray<IJSVGNode*>* nodes = [self.rootNode childrenOfType:IJSVGNodeTypeSVG];
    for(IJSVGNode* node in nodes) {
        IJSVG* newSVG = nil;
        newSVG = [[self.class alloc] initWithRootNode:(IJSVGRootNode*)node];
        [svgs addObject:newSVG];
    }
    return svgs;
}

#if __has_include(<AppKit/AppKit.h>)
- (IJSVGExporter*)exporterWithSize:(CGSize)size
                           options:(IJSVGExporterOptions)options
              floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    return [[IJSVGExporter alloc] initWithRootNode:_rootNode
                                              size:size
                                             style:_style
                                  renderingOptions:_renderingOptions
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
#endif

- (XImage*)imageWithSize:(CGSize)aSize
{
    return [self imageWithSize:aSize
                       flipped:NO
                         error:nil];
}

- (XImage*)imageWithSize:(CGSize)aSize
                    error:(NSError**)error;
{
    return [self imageWithSize:aSize
                       flipped:NO
                         error:error];
}

- (XImage*)imageWithSize:(CGSize)aSize
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
    int width = (int)size.width * scale;
    int height = (int)size.height * scale;
  
    // use correct memory alignment for performance.
    size_t bytesPerRow = ((width * 4) + 15) & ~15;
    size_t bufferSize = height * bytesPerRow;

    CGColorSpaceRef colorSpace = IJSVGDeviceRGBColorSpace();
    void* data = valloc(bufferSize);
    memset(data, 0, bufferSize);
    
    CGBitmapInfo info = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
    CGContextRef ref = CGBitmapContextCreate(data, width, height, 8,
                                             bytesPerRow, colorSpace,
                                             info);

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

    // release all things! (colorSpace is shared and owned by IJSVG)
    CGContextRelease(ref);
    free(data);
    return imageRef;
}

- (XImage*)imageWithSize:(CGSize)aSize
                  flipped:(BOOL)flipped
                    error:(NSError**)error
{
    CGImageRef ref = [self newCGImageRefWithSize:aSize
                                         flipped:flipped
                                           error:error];

    XImage* image = [[XImage alloc] initWithCGImage:ref
                                                 size:aSize];
    CGImageRelease(ref);
    return image;
}

- (CGSize)sizeByMaintainingAspectRatioWithSize:(CGSize)aSize
{
    CGSize ogSize = [_rootNode.intrinsicSize computeValue:aSize];
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
    ogSize.width = ceilf(imageWidth * ratio);
    ogSize.height = ceilf(imageHeight * ratio);
    return ogSize;
}

- (XImage*)imageByMaintainingAspectRatioWithSize:(CGSize)aSize
                                          flipped:(BOOL)flipped
                                            error:(NSError**)error
{
    CGSize ogSize = [self sizeByMaintainingAspectRatioWithSize:aSize];
    // Make suer we actually have a size, if not, just return nil.
    if(isnan(ogSize.width) || isnan(ogSize.height)) {
      return nil;
    }
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
        PDFDataWithRect:(CGRect) { .origin = XPointZero, .size = _viewBox.size }
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

- (void)prepForDrawingInView:(XView*)view
{
    // kill the render
    if(view == nil) {
        self.renderingBackingScaleHelper = nil;
        return;
    }

    // set the scale
    __weak XView* weakView = view;
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
    return [self drawInRect:XRectMake(point.x, point.y,
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
#if __has_include(<AppKit/AppKit.h>)
    currentCGContext = NSGraphicsContext.currentContext.CGContext;
#endif
#if __has_include(<UIKit/UIKit.h>)
    currentCGContext = UIGraphicsGetCurrentContext();
#endif
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

// Draws using the current rendering quality and sizing options.
- (BOOL)_drawInRect:(CGRect)rect
            context:(CGContextRef)ctx
              error:(NSError**)error
{
    if(ctx == NULL) {
        return NO;
    }
    CGContextSaveGState(ctx);
    @try {
        CGFloat backingScale = MAX([self backingScaleFactor], 1.f);
        CGInterpolationQuality quality;
        switch (_renderingOptions.renderQuality) {
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
        if(_rootNode.containsRelativeUnits && !CGSizeEqualToSize(_rootNode.clientSize, rect.size)) {
            _rootNode.clientSize = rect.size;
            [self _setupBasicInfoFromGroup];
        }
        if(_quartzRenderer == nil) {
            _quartzRenderer = [[IJSVGQuartzRenderer alloc] init];
            _quartzRenderer.style = _style;
            _quartzRenderer.renderingOptions = _renderingOptions;
        }
        [_quartzRenderer renderNode:_rootNode
                          inContext:ctx
                           viewPort:rect
                       backingScale:backingScale];
    } @finally {
        CGContextRestoreGState(ctx);
    }
    return YES;
}

// Returns a snapshot that can be edited without changing active rendering.
- (IJSVGRenderingOptions*)renderingOptions
{
    return _renderingOptions.copy;
}

// Captures options and rebuilds the resolved Quartz paints.
- (void)setRenderingOptions:(IJSVGRenderingOptions*)renderingOptions
{
    _renderingOptions = renderingOptions.copy;
    _quartzRenderer = nil;
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
    [self invalidatePaints];
}

- (void)invalidatePaints
{
    __weak IJSVG* weakSelf = self;
    [self performBlock:^{
        IJSVG* strongSelf = weakSelf;
        strongSelf->_quartzRenderer = nil;
    }];
}

- (IJSVGTraitedColorStorage*)colors
{
    return [_rootNode colorsWithStyle:_style];
}

#pragma mark NSPasteboard

#if __has_include(<AppKit/AppKit.h>)
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
#endif

#pragma mark matching

- (BOOL)containsNodesMatchingTraits:(IJSVGNodeTraits)traits
{
    return [_rootNode containsNodesMatchingTraits:traits];
}

@end
