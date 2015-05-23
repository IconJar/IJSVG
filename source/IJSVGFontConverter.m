//
//  IJSVGFontConverter.m
//  IJSVGExample
//
//  Created by Curtis Hard on 21/05/2015.
//  Copyright (c) 2015 Curtis Hard. All rights reserved.
//

#import "IJSVGFontConverter.h"
#import "IJSVGBezierPathAdditions.h"

@implementation IJSVGFontConverter

- (void)dealloc
{
    [_paths release], _paths = nil;
    [_url release], _url = nil;
    [_font release], _font = nil;
    [super dealloc];
}

- (id)initWithFontAtFileURL:(NSURL *)url
{
    if( ( self = [super init] ) != nil )
    {
        _url = [url copy];
        
        // load the font
        CGDataProviderRef dataProvider = CGDataProviderCreateWithURL((CFURLRef)_url);
        CGFontRef fontRef = CGFontCreateWithDataProvider(dataProvider);
        CTFontRef font = CTFontCreateWithGraphicsFont( fontRef, 30.f, NULL, NULL );
        
        // toll free bridge between NSFont at CTFont :)
        _font = [(NSFont *)font copy];
        CGFontRelease(fontRef);
        CGDataProviderRelease(dataProvider);
        CFRelease(font);
    }
    return self;
}

- (NSFont *)font
{
    return _font;
}

- (NSArray *)allCharacters
{
    NSCharacterSet * charSet = _font.coveredCharacterSet;
    NSMutableArray * array = [[[NSMutableArray alloc] init] autorelease];
    for( int plane = 0; plane <= 16; plane++ )
    {
        if( [charSet hasMemberInPlane:plane] )
        {
            UTF32Char c;
            for( c = plane << 16; c < (plane+1) << 16; c++ )
            {
                if( [charSet longCharacterIsMember:c] )
                {
                    UTF32Char c1 = NSSwapHostIntToLittle(c);
                    // add it...
                    [array addObject:[[[NSString alloc] initWithBytes:&c1
                                                               length:4
                                                             encoding:NSUTF32LittleEndianStringEncoding] autorelease]];
                }
            }
        }
    }
    return array;
}

- (void)generateMap
{
    // we have already been made!
    if( _paths.count != 0 )
        return;
    
    _paths = [[NSMutableDictionary alloc] init];
    CTFontRef font = (CTFontRef)_font;
    for( NSString * charString in [self allCharacters] )
    {
        // get the characters in each char
        NSUInteger count = charString.length;
        unichar characters[count];
        [charString getCharacters:characters
                            range:NSMakeRange( 0, count )];
        
        // get the glyphs
        CGGlyph glyphs[count];
        CTFontGetGlyphsForCharacters( font, characters, glyphs, count);
        CGPathRef path = CTFontCreatePathForGlyph( font, glyphs[0], NULL );
        if( path != NULL )
        {
            NSString * k = [NSString stringWithFormat:@"%04x",[charString characterAtIndex:0]];
            [self parseCGPath:path
           forCharacterString:k];
        }
        CGPathRelease(path);
    }
}

- (void)parseCGPath:(CGPathRef)path
 forCharacterString:(NSString *)string
{
    [_paths setObject:[[self class] bezierpathFromCGPath:path]
               forKey:string];
}

- (NSDictionary *)paths
{
    [self generateMap];
    return _paths;
}

static void IJSVGCGPathCallback(void * info, const CGPathElement * element)
{
    NSBezierPath * path = (NSBezierPath *)info;
    CGPoint * points = element->points;
    switch( element->type )
    {
        // move to
        case kCGPathElementMoveToPoint:
        {
            [path moveToPoint:NSMakePoint( points[0].x, points[0].y)];
            break;
        }
            
        // line to
        case kCGPathElementAddLineToPoint:
        {
            [path lineToPoint:NSMakePoint( points[0].x, points[0].y)];;
            break;
        }
            
        // quad curve
        case kCGPathElementAddQuadCurveToPoint:
        {
            [path addQuadCurveToPoint:points[1] controlPoint:points[0]];
            break;
        }
            
        // curve to
        case kCGPathElementAddCurveToPoint:
        {
            [path curveToPoint:NSMakePoint(points[2].x, points[2].y)
                 controlPoint1:NSMakePoint( points[0].x, points[0].y)
                 controlPoint2:NSMakePoint( points[1].x, points[1].y)];
            break;
        }
            
        // close
        case kCGPathElementCloseSubpath: {
            [path closePath];
            break;
        }
    }
}

+ (NSBezierPath *)bezierpathFromCGPath:(CGPathRef)path
{
    NSBezierPath * bezPath = [NSBezierPath bezierPath];
    
    // pass the path
    CGPathApply( path, bezPath, IJSVGCGPathCallback );
    
    // the glyph will be upside down, so we need to turn it up the right way!
    NSAffineTransform * trans = [NSAffineTransform transform];
    
    // scale -1 on the Y axis so its now correct but to far up
    [trans scaleXBy:1.f
                yBy:-1.f];
    
    // move it back down by its height
    [trans translateXBy:0.f
                    yBy:bezPath.controlPointBounds.size.height];
    
    [bezPath transformUsingAffineTransform:trans];
    return bezPath;
}

@end
