//
//  IJSVGTextGlyphUtils.h
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTextLayoutUtils.h>

void IJSVGTextAppendGlyphPath(CGMutablePathRef destination, CGPathRef outline,
                              CGAffineTransform transform);

void IJSVGTextAppendGlyphRun(CTRunRef run, IJSVGTextCharacter* characters,
                             NSMutableData* output, NSHashTable* fonts,
                             NSUInteger utf16Start, NSUInteger utf16Length,
                             const NSUInteger* mapping, CGPoint origin);

CGAffineTransform IJSVGTextGlyphTransform(IJSVGTextCharacter* c,
                                          const IJSVGTextGlyph* glyph);

typedef struct {
    CTFontRef font;
    CGFloat thickness;
    CGFloat underline;
    CGFloat overline;
    CGFloat lineThrough;
} IJSVGTextDecorationMetrics;

void IJSVGTextAppendDecorations(CGMutablePathRef destination,
                                IJSVGTextCharacter* c,
                                const IJSVGTextGlyph* glyph,
                                CGAffineTransform transform,
                                IJSVGTextDecorationMetrics* metrics);
