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
    _baseColor = [color retain];
}

+ (NSColor *)baseColor
{
    return _baseColor;
}

- (id)initWithFile:(NSString *)file
{
    if( ( self = [self initWithFilePathURL:[NSURL fileURLWithPath:file]] ) != nil )
    {
    }
    return self;
}

- (id)initWithFilePathURL:(NSURL *)aURL
{
    if( [IJSVGCache enabled] )
    {
        IJSVG * svg = nil;
        if( ( svg = [IJSVGCache cachedSVGForFileURL:aURL] ) != nil )
            return [svg retain];
    }
    
    if( ( self = [super init] ) != nil )
    {
        _group = [[IJSVGParser groupForFileURL:aURL] retain];
        if( [IJSVGCache enabled] )
            [IJSVGCache cacheSVG:self
                         fileURL:aURL];
    }
    return self;
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
    [self _beginDraw:rect];
    [self _drawGroup:_group
                rect:rect];
}

- (void)_recursiveColors:(IJSVGGroup *)group
{
    if( group.fillColor != nil )
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
    _scale = MIN(dest.width/source.width,dest.height/source.height);
}

- (void)_drawGroup:(IJSVGGroup *)group
              rect:(NSRect)rect
{
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState( context );
    
    // perform any transforms
    [self _applyDefaults:context
                    node:group];
    
    // it could be a group or a path
    for( id child in [group children] )
    {
        if( [child isKindOfClass:[IJSVGPath class]] )
            // as its just a path, we can happily
            // just draw it in the current context
            [self _drawPath:child
                       rect:rect];
        else if( [child isKindOfClass:[IJSVGGroup class]] )
            
            // if its a group, we recursively call this method
            // to generate the paths required
            [self _drawGroup:child
                        rect:rect];
    }
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
    
    // perform any transforms
    for( IJSVGTransform * transform in node.transforms )
    {
        [IJSVGTransform performTransform:transform
                               inContext:context];
    }
}

- (void)_drawPath:(IJSVGPath *)path
             rect:(NSRect)rect
{
    // there should be a colour on it...
    // defaults to black if not existant
    CGContextRef ref = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(ref);
    
    // scale the whole drawing context, but first, we need
    // to translate the context so its centered
    CGFloat tX = round(rect.size.width/2-(_group.size.width/2)*_scale);
    CGFloat tY = round(rect.size.height/2-(_group.size.height/2)*_scale);
    CGContextTranslateCTM( ref, tX, tY );
    CGContextScaleCTM( ref, _scale, _scale );
    
    // apply standard defaults
    [self _applyDefaults:ref
                    node:path];
    
    // set the fill color,
    // use the base if its not set
    if( path.fillColor == nil && _baseColor != nil )
        [_baseColor set];
    else
        [path.fillColor set];
    
    // fill the path
    [path.path fill];
    
    // any stroke?
    if( path.strokeColor != nil )
    {
        CGFloat lineWidth = 1.f;
        if( path.strokeWidth != 0 )
            lineWidth = path.strokeWidth;
        [path.strokeColor setStroke];
        [path.path setLineWidth:lineWidth];
        [path.path stroke];
    }
    
    // restore the graphics state
    CGContextRestoreGState(ref);
    
}

@end
