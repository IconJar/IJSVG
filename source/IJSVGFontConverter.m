//
//  IJSVGFontConverter.m
//  IJSVGExample
//
//  Created by Curtis Hard on 21/05/2015.
//  Copyright (c) 2015 Curtis Hard. All rights reserved.
//

#import "IJSVGFontConverter.h"
#import "IJSVGBezierPathAdditions.h"
#import "IJSVGShapeLayer.h"

@implementation IJSVGFontConverter

- (void)dealloc
{
    [_transformedPaths release], _transformedPaths = nil;
    [_url release], _url = nil;
    [_font release], _font = nil;
    [super dealloc];
}

- (id)initWithFontAtFileURL:(NSURL *)url
{
    if( ( self = [super init] ) != nil ) {
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
    NSStringEncoding encoding = NSUTF32LittleEndianStringEncoding;
    for( int plane = 0; plane <= 16; plane++ ) {
        if( [charSet hasMemberInPlane:plane] ) {
            UTF32Char c;
            for( c = plane << 16; c < (plane+1) << 16; c++ ) {
                if( [charSet longCharacterIsMember:c] ) {
                    UTF32Char c1 = NSSwapHostIntToLittle(c);
                    [array addObject:[[[NSString alloc] initWithBytes:&c1
                                                               length:4
                                                             encoding:encoding] autorelease]];
                }
            }
        }
    }
    return array;
}

- (void)generateMap
{
    CTFontRef font = (CTFontRef)_font;
    for( NSString * charString in [self allCharacters] ) {
        // get the characters in each char
        NSUInteger count = charString.length;
        unichar characters[count];
        [charString getCharacters:characters
                            range:NSMakeRange( 0, count )];
        
        // get the glyphs
        CGGlyph glyphs[count];
        CTFontGetGlyphsForCharacters( font, characters, glyphs, count);
        CGPathRef path = CTFontCreatePathForGlyph( font, glyphs[0], NULL );
        if(path != NULL) {
            // add SVG to the dictionary
            NSString * key = [NSString stringWithFormat:@"%04x",[charString characterAtIndex:0]];
            CGPathRef flippedPath = [IJSVGUtils newFlippedCGPath:path];
            _transformedPaths[key] = (id)flippedPath;
            CGPathRelease(flippedPath);
        }
        CGPathRelease(path);
    }
}

- (void)enumerateUsingBlock:(IJSVGFontConverterEnumerateBlock)block
{
    if(_transformedPaths == nil) {
        _transformedPaths = [[NSMutableDictionary alloc] init];
        [self generateMap];
    }
    
    for(NSString * key in _transformedPaths.allKeys) {
        block(key, [self.class convertPathToSVG:(CGPathRef)_transformedPaths[key]]);
    }
}

+ (IJSVG *)convertIJSVGPathToSVG:(IJSVGPath *)path
{
    CGPathRef cgPath = [IJSVGUtils newCGPathFromBezierPath:path.path];
    CGPathRef flippedPath = [IJSVGUtils newFlippedCGPath:cgPath];
    IJSVG * svg = [self convertPathToSVG:flippedPath];
    CGPathRelease(flippedPath);
    CGPathRelease(cgPath);
    return svg;
}

+ (IJSVG *)convertPathToSVG:(CGPathRef)path
{
    __block IJSVG * svg = nil;
    IJSVGObtainTransactionLock(^{
        IJSVGGroupLayer * layer = [[[IJSVGGroupLayer alloc] init] autorelease];
        IJSVGShapeLayer * shape = [[[IJSVGShapeLayer alloc] init] autorelease];
        [layer addSublayer:shape];
        shape.path = path;
        CGRect box = CGPathGetPathBoundingBox(path);
        svg = [[IJSVG alloc] initWithSVGLayer:layer
                                      viewBox:box];
    }, NO);
    return [svg autorelease];
}

@end
