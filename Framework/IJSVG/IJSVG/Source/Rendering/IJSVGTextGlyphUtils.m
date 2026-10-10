//
//  IJSVGTextGlyphUtils.m
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTextGlyphUtils.h>
#import <IJSVG/IJSVGParser.h>
#import <math.h>

// Append commands directly to avoid repeated whole path concatenation.
void IJSVGTextAppendGlyphPath(CGMutablePathRef destination, CGPathRef outline,
                              CGAffineTransform transform)
{
    CGPathApplyWithBlock(outline,
                         ^(const CGPathElement* element) {
        const CGPoint* points = element->points;
        switch(element->type) {
            case kCGPathElementMoveToPoint:
                CGPathMoveToPoint(destination, &transform, points[0].x,
                                  points[0].y);
                break;
            case kCGPathElementAddLineToPoint:
                CGPathAddLineToPoint(destination, &transform, points[0].x,
                                     points[0].y);
                break;
            case kCGPathElementAddQuadCurveToPoint:
                CGPathAddQuadCurveToPoint(destination, &transform, points[0].x,
                                          points[0].y, points[1].x,
                                          points[1].y);
                break;
            case kCGPathElementAddCurveToPoint:
                CGPathAddCurveToPoint(destination, &transform, points[0].x,
                                      points[0].y, points[1].x, points[1].y,
                                      points[2].x, points[2].y);
                break;
            case kCGPathElementCloseSubpath:
                CGPathCloseSubpath(destination);
                break;
        }
    });
}

void IJSVGTextAppendGlyphRun(CTRunRef run, IJSVGTextCharacter* characters,
                             NSMutableData* output, NSHashTable* fonts,
                             NSUInteger utf16Start, NSUInteger utf16Length,
                             const NSUInteger* mapping, CGPoint origin)
{
    CFIndex count = CTRunGetGlyphCount(run);
    if(count == 0) {
        return;
    }
    // Use the run buffers directly when Core Text exposes them.
    const CGGlyph* glyphs = CTRunGetGlyphsPtr(run);
    __attribute__((objc_precise_lifetime)) NSMutableData* glyphsData = nil;
    if(glyphs == NULL) {
        glyphsData = [NSMutableData dataWithLength:count * sizeof(CGGlyph)];
        CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphsData.mutableBytes);
        glyphs = glyphsData.bytes;
    }
    const CGPoint* positions = CTRunGetPositionsPtr(run);
    __attribute__((objc_precise_lifetime)) NSMutableData* positionsData = nil;
    if(positions == NULL) {
        positionsData = [NSMutableData dataWithLength:count * sizeof(CGPoint)];
        CTRunGetPositions(run, CFRangeMake(0, 0), positionsData.mutableBytes);
        positions = positionsData.bytes;
    }
    const CGSize* advances = CTRunGetAdvancesPtr(run);
    __attribute__((objc_precise_lifetime)) NSMutableData* advancesData = nil;
    if(advances == NULL) {
        advancesData = [NSMutableData dataWithLength:count * sizeof(CGSize)];
        CTRunGetAdvances(run, CFRangeMake(0, 0), advancesData.mutableBytes);
        advances = advancesData.bytes;
    }
    const CFIndex* indices = CTRunGetStringIndicesPtr(run);
    __attribute__((objc_precise_lifetime)) NSMutableData* indicesData = nil;
    if(indices == NULL) {
        indicesData = [NSMutableData dataWithLength:count * sizeof(CFIndex)];
        CTRunGetStringIndices(run, CFRangeMake(0, 0), indicesData.mutableBytes);
        indices = indicesData.bytes;
    }
    CFDictionaryRef attributes = CTRunGetAttributes(run);
    id font = (__bridge id)CFDictionaryGetValue(attributes,
                                                kCTFontAttributeName);
    // Keep fallback fonts alive after the Core Text line is released.
    [fonts addObject:font];
    NSUInteger start = output.length / sizeof(IJSVGTextGlyph);
    [output increaseLengthBy:(NSUInteger)count * sizeof(IJSVGTextGlyph)];
    IJSVGTextGlyph* records = output.mutableBytes;
    NSUInteger written = start;
    for(CFIndex i = 0; i < count; i++) {
        if(indices[i] < 0 || indices[i] >= (CFIndex)utf16Length) {
            continue;
        }
        NSUInteger index = mapping[utf16Start + indices[i]];
        if(index == NSNotFound) {
            continue;
        }
        // Core Text can report separate string indices for combining marks.
        // Keep combining marks attached to the same cluster origin.
        index = characters[index].cluster;
        IJSVGTextCharacter* character = &characters[index];
        IJSVGTextGlyph* glyph = &records[written++];
        glyph->font = (__bridge CTFontRef)font;
        glyph->glyph = glyphs[i];
        glyph->character = index;
        CGFloat fontScale = character->style.fontScale;
        CGFloat positionX = origin.x + positions[i].x / fontScale;
        // SVG and Core Text use opposite directions for the vertical axis.
        CGFloat positionY = origin.y - positions[i].y / fontScale;
        CGPoint point = CGPointMake(positionX, positionY);
        if(character->middle) {
            character->position = point;
            character->middle = NO;
        }
        glyph->offset = CGPointMake(point.x - character->position.x,
                                    point.y - character->position.y);
        CGSize advance = advances[i];
        // Moving a mark across the text direction does not change the advance.
        CGFloat distance = character->style.vertical
            ? (advance.height == 0 ? advance.width : fabs(advance.height))
            : advance.width;
        character->advance += distance / fontScale;
    }
    if(written != start + (NSUInteger)count) {
        [output setLength:written * sizeof(IJSVGTextGlyph)];
    }
}

CGAffineTransform IJSVGTextGlyphTransform(IJSVGTextCharacter* c,
                                          const IJSVGTextGlyph* glyph)
{
    CGFloat angle = c->rotation;
    IJSVGTextComputedStyle* style = c->style;
    CGFloat fontScale = 1 / style.fontScale;
    CGPoint position = c->position;
    CGPoint offset = glyph->offset;
    if(angle == 0 && !style.vertical) {
        return CGAffineTransformMake(c->scale * fontScale, 0, 0, -fontScale,
                                     position.x + offset.x * c->scale,
                                     position.y + offset.y);
    }
    BOOL upright = NO;
    if(c->style.vertical) {
        IJSVGTextKeyword orientation = style.orientation;
        unichar scalar = c->firstCodeUnit;
        upright = orientation == IJSVGTextKeywordUpright ||
            (orientation != IJSVGTextKeywordSideways && scalar >= u'⺀');
        // Core Text supplies rotated glyphs for sideways vertical runs.
    }
    CGAffineTransform transform = CGAffineTransformMakeTranslation(position.x,
                                                                   position.y);
    transform = CGAffineTransformRotate(transform, angle);
    // Offsets are already in SVG coordinates. Scale them along the text direction
    // and rotate them with the cluster before converting the glyph outline.
    CGFloat offsetX = style.vertical ? offset.x : offset.x * c->scale;
    CGFloat offsetY = style.vertical ? offset.y * c->scale : offset.y;
    transform = CGAffineTransformTranslate(transform, offsetX, offsetY);
    if(c->style.vertical) {
        CGSize translation;
        CGGlyph glyphID = glyph->glyph;
        CTFontGetVerticalTranslationsForGlyphs(glyph->font, &glyphID,
                                               &translation, 1);
        transform = CGAffineTransformTranslate(transform,
                                               translation.width / c->style.fontScale,
                                               -translation.height / c->style.fontScale);
    }
    BOOL verticalUpright = c->style.vertical && upright;
    CGFloat scaleX = verticalUpright ? 1 : c->scale;
    CGFloat scaleY = verticalUpright ? -c->scale : -1;
    transform = CGAffineTransformScale(transform, scaleX, scaleY);
    return CGAffineTransformScale(transform, 1 / c->style.fontScale,
                                  1 / c->style.fontScale);
}

void IJSVGTextAppendDecorations(CGMutablePathRef destination,
                                IJSVGTextCharacter* c,
                                const IJSVGTextGlyph* glyph,
                                CGAffineTransform transform,
                                IJSVGTextDecorationMetrics* metrics)
{
    IJSVGTextDecoration decorations = c->style.decorations;
    if(decorations != IJSVGTextDecorationNone && c->advance > 0) {
        CTFontRef font = glyph->font;
        // A fallback font needs its own decoration measurements.
        if(metrics->font != font) {
            metrics->font = font;
            CGFloat ascent, descent;
            IJSVGTextFontExtents(font, &ascent, &descent);
            metrics->thickness = CTFontGetSize(font) / 20;
            metrics->underline = -2.5 * metrics->thickness;
            metrics->overline = ascent - 2 * metrics->thickness;
            metrics->lineThrough = ascent * .375 - metrics->thickness;
        }
        CGFloat thickness = metrics->thickness;
        for(IJSVGTextDecoration flag = IJSVGTextDecorationUnderline;
            flag <= IJSVGTextDecorationLineThrough; flag <<= 1) {
            if((decorations & flag) == 0) {
                continue;
            }
            CGFloat y = 0;
            switch(flag) {
                case IJSVGTextDecorationUnderline:
                    y = metrics->underline;
                    break;
                case IJSVGTextDecorationOverline:
                    y = metrics->overline;
                    break;
                case IJSVGTextDecorationLineThrough:
                    y = metrics->lineThrough;
                    break;
                default:
                    break;
            }
            CGFloat width = c->advance * c->style.fontScale / MAX(c->scale,
                                                                  .001);
            CGRect bounds = CGRectMake(0, y, width, thickness);
            CGPathAddRect(destination, &transform, bounds);
        }
    }
}

