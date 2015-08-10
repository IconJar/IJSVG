//
//  IJSVGImage.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVG.h"
#import "IJSVGCache.h"

@implementation IJSVG

- (void)dealloc
{
    [_group release], _group = nil;
    [_colors release], _colors = nil;
    [super dealloc];
}

static NSColor * _baseColor = nil;

+ (void)setBaseColor:(NSColor *)color
{
    if( _baseColor != nil )
        [_baseColor release], _baseColor = nil;
    if( color == nil )
        _baseColor = nil;
    else
        _baseColor = [color retain];
}

+ (NSColor *)baseColor
{
    return [[_baseColor copy] autorelease];
}

+ (id)svgNamed:(NSString *)string
{
    return [[self class] svgNamed:string
                         delegate:nil];
}

+ (id)svgNamed:(NSString *)string
      delegate:(id<IJSVGDelegate>)delegate
{
    NSBundle * bundle = [NSBundle mainBundle];
    NSString * str = nil;
    NSString * ext = [string pathExtension];
    if( ext == nil || ext.length == 0 )
        ext = @"svg";
    if( ( str = [bundle pathForResource:[string stringByDeletingPathExtension]
                                 ofType:ext] ) != nil )
        return [[[self alloc] initWithFile:str
                                  delegate:delegate] autorelease];
    return nil;
}

- (id)initWithFile:(NSString *)file
{
    if( ( self = [self initWithFile:file
                           delegate:nil] ) != nil )
    {
    }
    return self;
}

- (id)initWithFile:(NSString *)file
          delegate:(id<IJSVGDelegate>)delegate
{
    if( ( self = [self initWithFilePathURL:[NSURL fileURLWithPath:file]
                                  delegate:delegate] ) )
    {
    }
    return self;
}

- (id)initWithFilePathURL:(NSURL *)aURL
{
    if( ( self = [self initWithFilePathURL:aURL
                                  delegate:nil] ) != nil )
    {
    }
    return self;
}

- (id)initWithFilePathURL:(NSURL *)aURL
                 delegate:(id<IJSVGDelegate>)delegate
{
#ifndef __clang_analyzer__
    if( [IJSVGCache enabled] )
    {
        IJSVG * svg = nil;
        if( ( svg = [IJSVGCache cachedSVGForFileURL:aURL] ) != nil )
        {
            // have to release, as this was called from an alloc..!
            [self release];
            return [svg retain];
        }
    }
    
    if( ( self = [super init] ) != nil )
    {
        _delegate = delegate;
        _group = [[IJSVGParser groupForFileURL:aURL] retain];
        if( [IJSVGCache enabled] )
            [IJSVGCache cacheSVG:self
                         fileURL:aURL];
    }
#endif
    return self;
}

- (BOOL)isFont
{
    return [_group isFont];
}

- (NSArray *)glyphs
{
    return [_group glyphs];
}

- (NSImage *)imageWithSize:(NSSize)aSize
{
    NSImage * im = [[[NSImage alloc] initWithSize:aSize] autorelease];
    [im lockFocus];
    [self drawAtPoint:NSMakePoint( 0.f, 0.f )
                 size:aSize];
    [im unlockFocus];
    return im;
}

- (NSData *)PDFData
{
    return [self PDFDataWithRect:(NSRect){
        .origin=NSZeroPoint,
        .size=_group.size}];
}

- (NSData *)PDFDataWithRect:(NSRect)rect
{
    NSColor * oldBaseColour = [[self class] baseColor];
    [[self class] setBaseColor:nil];
    // store the old context
    NSGraphicsContext * oldGraphicsContext = [NSGraphicsContext currentContext];
    
    // create the data for the PDF
    NSMutableData * data = [[[NSMutableData alloc] init] autorelease];
    
    // assign the data to the consumer
    CGDataConsumerRef dataConsumer = CGDataConsumerCreateWithCFData((CFMutableDataRef)data);
    const CGRect box = CGRectMake( rect.origin.x, rect.origin.y, rect.size.width, rect.size.height );
    
    // create the context
    CGContextRef context = CGPDFContextCreate( dataConsumer, &box, NULL );
    NSGraphicsContext * newContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context
                                                                                flipped:NO];
    
    CGContextSaveGState(context);
    
    // set it as the current
    [NSGraphicsContext setCurrentContext:newContext];
    CGContextBeginPage( context, &box );
    
    // the context is currently upside down, doh! flip it...
    CGContextScaleCTM( context, 1, -1 );
    CGContextTranslateCTM( context, 0, -box.size.height);
    
    // draw the icon
    [self _drawInRect:(NSRect)box
              context:context];
    CGContextEndPage(context);
    
    //clean up
    CGPDFContextClose(context);
    CGContextRelease(context);
    CGDataConsumerRelease(dataConsumer);
    
    CGContextRestoreGState(context);
    
    // set the graphics context back to its original
    [NSGraphicsContext setCurrentContext:oldGraphicsContext];
    [[self class] setBaseColor:oldBaseColour];
    return data;
}

- (NSArray *)colors
{
    if( _colors == nil )
    {
        _colors = [[NSMutableArray alloc] init];
        [self _recursiveColors:_group];
    }
    return [[_colors copy] autorelease];
}

- (void)drawAtPoint:(NSPoint)point
               size:(NSSize)aSize
{
    [self drawInRect:NSMakeRect( point.x, point.y, aSize.width, aSize.height )];
}

- (void)drawInRect:(NSRect)rect
{
    [self _drawInRect:rect
              context:[[NSGraphicsContext currentContext] graphicsPort]];
}

- (void)_drawInRect:(NSRect)rect
           context:(CGContextRef)ref
{
    // prep for draw...
    [self _beginDraw:rect];
    
    // setup the transforms and scale on the main context
    CGContextSaveGState(ref);
    {
    
        // scale the whole drawing context, but first, we need
        // to translate the context so its centered
        CGFloat tX = round(rect.size.width/2-(_group.size.width/2)*_scale);
        CGFloat tY = round(rect.size.height/2-(_group.size.height/2)*_scale);
        
        // we also need to calculate the viewport so we can clip
        // the drawing if needed
        NSRect viewPort = NSZeroRect;
        viewPort.origin.x = round(rect.size.width/2-(_group.proposedViewSize.width/2)*_clipScale);
        viewPort.origin.y = round(rect.size.height/2-(_group.proposedViewSize.height/2)*_clipScale);;
        viewPort.size.width = _group.proposedViewSize.width*_clipScale;
        viewPort.size.height = _group.proposedViewSize.height*_clipScale;
        
        // attempt to not crash when dealing with dodgy SVG's
        if( isnan(viewPort.origin.x) || isnan(viewPort.origin.y) || isnan(viewPort.size.width) || isnan(viewPort.size.height) )
        {
            CGContextRestoreGState(ref);
            return;
        }
        
        // clip any drawing to the view port
        [[NSBezierPath bezierPathWithRect:viewPort] addClip];
        
        tX -= _group.viewBox.origin.x*_scale;
        tY -= _group.viewBox.origin.y*_scale;
        
        CGContextTranslateCTM( ref, tX, tY );
        CGContextScaleCTM( ref, _scale, _scale );
        
        // apply standard defaults
        [self _applyDefaults:ref
                        node:_group];
        
        // begin draw
        [self _drawGroup:_group
                    rect:rect
                 context:ref];
        
    }
    CGContextRestoreGState(ref);
    
}

- (NSRect)computedViewPort
{
    return NSMakeRect( 0.f, 0.f, 200.f, 200.f);
}

- (void)_recursiveColors:(IJSVGGroup *)group
{
    if( group.fillColor != nil && !group.usesDefaultFillColor )
        [self _addColor:group.fillColor];
    if( group.strokeColor != nil )
        [self _addColor:group.strokeColor];
    for( id node in [group children] )
    {
        if( [node isKindOfClass:[IJSVGGroup class]] )
            [self _recursiveColors:node];
        else {
            IJSVGPath * p = (IJSVGPath*)node;
            if( p.fillColor != nil )
                [self _addColor:p.fillColor];
            if( p.strokeColor != nil )
                [self _addColor:p.strokeColor];
        }
    }
}

- (void)_addColor:(NSColor *)color
{
    if( [_colors containsObject:color] || color == [NSColor clearColor] )
        return;
    [_colors addObject:color];
}

- (void)_beginDraw:(NSRect)rect
{
    // in order to correctly fit the the SVG into the
    // rect, we need to work out the ratio scale in order
    // to transform the paths into our viewbox
    NSSize dest = rect.size;
    NSSize source = _group.viewBox.size;
    _clipScale = MIN(dest.width/_group.proposedViewSize.width,dest.height/_group.proposedViewSize.height);
   
    // work out the actual scale based on the clip scale
    CGFloat w = _group.proposedViewSize.width*_clipScale;
    CGFloat h = _group.proposedViewSize.height*_clipScale;
    _scale = MIN(w/source.width,h/source.height);
}

- (void)_prepClip:(IJSVGNode *)node
          context:(CGContextRef)context
        drawBlock:(dispatch_block_t)block
             rect:(NSRect)rect
{
    if( node.clipPath != nil )
    {
        for( id clip in node.clipPath.children )
        {
            // save the context
            CGContextSaveGState(context);
            {
                
                if( [clip isKindOfClass:[IJSVGGroup class]] )
                {
                    [self _drawGroup:clip
                                rect:rect
                             context:context];
                } else {
                    
                    // add the clip and draw
                    IJSVGPath * path = (IJSVGPath *)clip;
                    [[IJSVGTransform transformedPath:path] addClip];
                    block();
                }
                
                // restore the context
            }
            CGContextRestoreGState(context);
        }
        return;
    }
    
    // just draw
    block();
}

- (void)_drawGroup:(IJSVGGroup *)group
              rect:(NSRect)rect
           context:(CGContextRef)context
{
    
    if( !group.shouldRender )
        return;
    
    CGContextSaveGState( context );
    {
        
        // perform any transforms
        [self _applyDefaults:context
                        node:group];
        
        dispatch_block_t drawBlock = ^(void)
        {
            // it could be a group or a path
            for( id child in [group children] )
            {
                if( [child isKindOfClass:[IJSVGPath class]] )
                {
                    dispatch_block_t block = ^(void)
                    {
                        IJSVGPath * p = (IJSVGPath *)child;
                        if( p.shouldRender )
                            [self _drawPath:p
                                       rect:rect
                                    context:context];
                    };
                    
                    // draw the clip
                    [self _prepClip:child
                            context:context
                          drawBlock:block
                               rect:rect];
                    
                } else if( [child isKindOfClass:[IJSVGGroup class]] ) {
                    
                    // if its a group, we recursively call this method
                    // to generate the paths required
                    [self _drawGroup:child
                                rect:rect
                             context:context];
                }
            }
            
        };
        
        // main group clipping
        [self _prepClip:group
                context:context
              drawBlock:drawBlock
                   rect:rect];
        
    }
    // restore the context
    CGContextRestoreGState(context);
}

- (void)_applyDefaults:(CGContextRef)context
                  node:(IJSVGNode *)node
{
    // the opacity, if its 0, assume its broken
    // so set it to 1.f
    CGFloat opacity = node.opacity;
    if( opacity == 0.f )
        opacity = 1.f;
    
    // scale it
    CGContextSetAlpha( context, opacity );
    CGContextTranslateCTM( context, node.x, node.y);
    
    // perform any transforms
    for( IJSVGTransform * transform in node.transforms )
    {
        [IJSVGTransform performTransform:transform
                               inContext:context];
    }
    
}

- (void)_drawPath:(IJSVGPath *)path
             rect:(NSRect)rect
          context:(CGContextRef)ref
{
    // there should be a colour on it...
    // defaults to black if not existant
    CGContextSaveGState(ref);
    {
        // there could be transforms per path
        [self _applyDefaults:ref
                        node:path];
        
        // fill the path
        if( path.fillGradient != nil )
        {
            CGContextSaveGState(ref);
            {
                // for this to work, we need to add the clip so when
                // drawing occurs, it doesnt go outside the path bounds
                [path.path addClip];
                
                // apply any gradient fill transforms
                for( IJSVGTransform * transform in path.gradientTransforms )
                {
                    [IJSVGTransform performTransform:transform
                                           inContext:ref];
                }
                
                if( [path.fillGradient isKindOfClass:[IJSVGLinearGradient class]] )
                {
                    // linear gradient
                    NSGradient * gradient = [path.fillGradient gradient];;
                    [gradient drawInBezierPath:path.path
                                         angle:path.fillGradient.angle];
                } else if( [path.fillGradient isKindOfClass:[IJSVGRadialGradient class]] )
                {
                    // radial gradient
                    // very rudimentary at the moment
                    IJSVGRadialGradient * radGrad = (IJSVGRadialGradient *)path.fillGradient;
                    [radGrad.gradient drawInBezierPath:path.path
                                relativeCenterPosition:NSZeroPoint];
                }
            }
            CGContextRestoreGState(ref);
        } else {
            // no gradient specified
            // just use the color instead
            if( path.windingRule != IJSVGWindingRuleInherit )
                [path.path setWindingRule:(NSWindingRule)path.windingRule];
            
            if( path.fillColor != nil )
            {
                [path.fillColor set];
                [path.path fill];
            } else if( _baseColor != nil ) {
                
                // is there a base color?
                // this is basically used whenever no color
                // is set, its also set via [IJSVG setBaseColor],
                // this must be defined!
                
                [_baseColor set];
                [path.path fill];
            } else {
                [path.path fill];
            }
        }
        
        // any stroke?
        if( path.strokeColor != nil )
        {
            // default line width is 1
            // if its defined elsewhere, then
            // use that one instead
            CGFloat lineWidth = 1.f;
            if( path.strokeWidth > 0.f )
                lineWidth = path.strokeWidth;
            
            if( path.lineCapStyle != IJSVGLineCapStyleInherit )
                [path.path setLineCapStyle:(NSLineCapStyle)path.lineCapStyle];
            else
                [path.path setLineCapStyle:NSButtLineCapStyle];
            
            if( path.lineJoinStyle != IJSVGLineJoinStyleInherit )
                [path.path setLineJoinStyle:(NSLineJoinStyle)path.lineJoinStyle];
            
            [path.strokeColor setStroke];
            [path.path setLineWidth:lineWidth];
            
            // any dashed array?
            if( path.strokeDashArrayCount != 0 )
                [path.path setLineDash:path.strokeDashArray
                                 count:path.strokeDashArrayCount
                                 phase:path.strokeDashOffset];
            
            [path.path stroke];
        }
        
    }
    // restore the graphics state
    CGContextRestoreGState(ref);
    
}

#pragma mark NSPasteboard

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return @[NSPasteboardTypePDF];
}

- (id)pasteboardPropertyListForType:(NSString *)type
{
    if( [type isEqualToString:NSPasteboardTypePDF] )
        return [self PDFData];
    return nil;
}

#pragma mark IJSVGParserDelegate

- (BOOL)svgParser:(IJSVGParser *)parser
shouldHandleForeignObject:(IJSVGForeignObject *)foreignObject
{
    if( _delegate == nil )
        return NO;
    if( [_delegate respondsToSelector:@selector(svg:shouldHandleForeignObject:)] )
        return [_delegate svg:self
    shouldHandleForeignObject:foreignObject];
    return NO;
}

- (void)svgParser:(IJSVGParser *)parser
handleForeignObject:(IJSVGForeignObject *)foreignObject
         document:(NSXMLDocument *)document
{
    if( _delegate == nil )
        return;
    if( [_delegate respondsToSelector:@selector(svg:handleForeignObject:document:)] )
        [_delegate svg:self
   handleForeignObject:foreignObject
              document:document];
}

@end
