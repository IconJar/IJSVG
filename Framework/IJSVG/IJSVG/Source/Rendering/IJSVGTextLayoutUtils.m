//
//  IJSVGTextLayoutUtils.m
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTextLayoutUtils.h>
#import <IJSVG/IJSVGParser.h>
#import <math.h>
#import <stdlib.h>
#import <stdint.h>

@implementation IJSVGTextComputedStyle

@end

IJSVGTextKeyword IJSVGTextRenderingForNode(IJSVGNode* node)
{
    for(IJSVGNode* current = node; current != nil; current = current.parentNode) {
        IJSVGTextKeyword keyword = current.textStyle[IJSVGAttributeTextRendering].keyword;
        if(keyword == IJSVGTextKeywordInitial) {
            return IJSVGTextKeywordAuto;
        }
        if(keyword != IJSVGTextKeywordUnspecified &&
           keyword != IJSVGTextKeywordInherit && keyword != IJSVGTextKeywordUnset) {
            return keyword;
        }
    }
    return IJSVGTextKeywordAuto;
}

CGFloat IJSVGTextLength(IJSVGTextAttributeValue* value, CGFloat fontSize,
                        CGFloat xHeight, CGFloat percentage)
{
    switch(value.lengthBasis) {
        case IJSVGTextLengthBasisFontSize:
            return value.number * fontSize;
        case IJSVGTextLengthBasisXHeight:
            return value.number * xHeight;
        case IJSVGTextLengthBasisPercentage:
            return value.number * percentage;
        case IJSVGTextLengthBasisAbsolute:
            return value.number;
    }
    return 0;
}

void IJSVGTextAppendCharacter(IJSVGTextCharacter** characters,
                              NSUInteger* count, NSUInteger* capacity,
                              const IJSVGTextCharacter* character)
{
    // Leave room for more characters instead of reallocating each time.
    if(*count == *capacity) {
        if(*capacity > SIZE_MAX / (2 * sizeof(IJSVGTextCharacter))) {
            [NSException raise:NSMallocException
                        format:@"SVG text character capacity exceeded"];
        }
        NSUInteger next = MAX((NSUInteger)32, *capacity * 2);
        IJSVGTextCharacter* resized = realloc(*characters,
                                              next * sizeof(IJSVGTextCharacter));
        if(resized == NULL) {
            [NSException raise:NSMallocException
                        format:@"Unable to allocate SVG text characters"];
        }
        *characters = resized;
        *capacity = next;
    }
    (*characters)[(*count)++] = *character;
}

CGFloat IJSVGTextBaselineOffset(IJSVGTextComputedStyle* style)
{
    // Characters sharing a style use the same baseline offset.
    if(style.hasResolvedBaseline == YES) {
        return style.resolvedBaseline;
    }
    CTFontRef font = (__bridge CTFontRef)style.font;
    IJSVGTextAttributeValue* baseline = style.values[IJSVGAttributeAlignmentBaseline]
        ?: style.values[IJSVGAttributeDominantBaseline];
    CGFloat result = style.baseline;
    switch(baseline.keyword) {
        case IJSVGTextKeywordMiddle:
        case IJSVGTextKeywordMathematical:
            result += (CTFontGetXHeight(font) / style.fontScale) * .5;
            break;
        case IJSVGTextKeywordCentral:
            result += ((CTFontGetAscent(font) / style.fontScale) - (CTFontGetDescent(font) / style.fontScale)) * .5;
            break;
        case IJSVGTextKeywordHanging:
            result += (CTFontGetAscent(font) / style.fontScale) * .8;
            break;
        case IJSVGTextKeywordTextBeforeEdge:
        case IJSVGTextKeywordBeforeEdge:
        case IJSVGTextKeywordTextTop:
            result += (CTFontGetAscent(font) / style.fontScale);
            break;
        case IJSVGTextKeywordTextAfterEdge:
        case IJSVGTextKeywordAfterEdge:
        case IJSVGTextKeywordIdeographic:
        case IJSVGTextKeywordTextBottom:
            result -= (CTFontGetDescent(font) / style.fontScale);
            break;
        default:
            break;
    }
    style.resolvedBaseline = result;
    style.hasResolvedBaseline = YES;
    return result;
}

CGFloat IJSVGTextFontXHeight(CTFontRef font, CGFloat fontSize, CGFloat scale)
{
    if(fontSize == 0) {
        return 0;
    }
    CGFloat xHeight = CTFontGetXHeight(font) / scale;
    // Use the usual fallback only when the font has no usable metric.
    return isfinite(xHeight) && xHeight > 0 ? xHeight : fontSize * .5;
}

CGFloat IJSVGTextFontSize(IJSVGTextAttributeValue* size, CGFloat parentSize,
                          CGFloat parentXHeight)
{
    CGFloat result = parentSize;
    if(size == nil || size.keyword == IJSVGTextKeywordInherit ||
       size.keyword == IJSVGTextKeywordUnset) {
        result = parentSize;
    } else {
        switch(size.keyword) {
            case IJSVGTextKeywordInitial:
                result = 16.;
                break;
            case IJSVGTextKeywordSmaller:
                result = parentSize / 1.2;
                break;
            case IJSVGTextKeywordLarger:
                result = parentSize * 1.2;
                break;
            case IJSVGTextKeywordXXSmall:
                result = 9;
                break;
            case IJSVGTextKeywordXSmall:
                result = 10;
                break;
            case IJSVGTextKeywordSmall:
                result = 13;
                break;
            case IJSVGTextKeywordMedium:
                result = 16;
                break;
            case IJSVGTextKeywordLarge:
                result = 18;
                break;
            case IJSVGTextKeywordXLarge:
                result = 24;
                break;
            case IJSVGTextKeywordXXLarge:
                result = 32;
                break;
            default:
                result = IJSVGTextLength(size, parentSize, parentXHeight,
                                         parentSize);
                break;
        }
    }
    return MAX(0, MIN(1000000, result));
}

BOOL IJSVGTextCanReuseFont(IJSVGTextComputedStyle* parent,
                           NSDictionary<NSString*, IJSVGTextAttributeValue*>* values,
                           CGFloat size)
{
    return parent != nil && parent.size == size &&
        parent.values[IJSVGAttributeFontFamily] == values[IJSVGAttributeFontFamily] &&
        parent.values[IJSVGAttributeTextRendering] == values[IJSVGAttributeTextRendering] &&
        parent.values[IJSVGAttributeFontWeight] == values[IJSVGAttributeFontWeight] &&
        parent.values[IJSVGAttributeFontStyle] == values[IJSVGAttributeFontStyle] &&
        parent.values[IJSVGAttributeFontStretch] == values[IJSVGAttributeFontStretch] &&
        parent.values[IJSVGAttributeFontVariant] == values[IJSVGAttributeFontVariant] &&
        parent.values[IJSVGAttributeFontFeatureSettings] == values[IJSVGAttributeFontFeatureSettings];
}


NSUInteger IJSVGTextBuildSpacingUnits(IJSVGTextCharacter* characters,
                                      NSRange range, IJSVGText* node,
                                      NSUInteger* spacingUnits)
{
    CFMutableDictionaryRef units = NULL;
    IJSVGText* previousOwner = nil;
    IJSVGText* resolved = nil;
    NSUInteger ownerUnit = 0;
    NSUInteger unitCount = 0;
    NSUInteger end = NSMaxRange(range);
    for(NSUInteger index = range.location; index < end; index++) {
        IJSVGTextCharacter* character = &characters[index];
        if(character->middle) {
            continue;
        }
        if(character->owner != previousOwner) {
            previousOwner = character->owner;
            resolved = nil;
            for(IJSVGNode* parent = previousOwner; parent != nil && parent != node; parent = parent.parentNode) {
                if([parent isKindOfClass:IJSVGText.class] &&
                   ((IJSVGText*)parent).positioning[IJSVGAttributeTextLength] != nil) {
                    resolved = (IJSVGText*)parent;
                }
            }
            // Keep a child with its own textLength together as one spacing unit.
            if(resolved != nil) {
                if(units == NULL) {
                    units = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
                }
                const void* key = (__bridge const void*)resolved;
                uintptr_t stored = (uintptr_t)CFDictionaryGetValue(units, key);
                if(stored != 0) {
                    ownerUnit = stored - 1;
                } else {
                    ownerUnit = unitCount++;
                    const void* value = (const void*)(uintptr_t)(ownerUnit + 1);
                    CFDictionarySetValue(units, key, value);
                }
            }
        }
        spacingUnits[index - range.location] = resolved != nil ? ownerUnit : unitCount++;
    }
    if(units != NULL) {
        CFRelease(units);
    }
    return unitCount;
}
