//
//  IJSVGTextLayout.m
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTextLayout.h>
#import <IJSVG/IJSVGParser.h>
#import <CoreText/CoreText.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGUtils.h>
#import <math.h>
#import <stdlib.h>
#import <IJSVGTextFontResolver.h>
#import <IJSVGTextLayoutUtils.h>
#import <IJSVGTextGlyphUtils.h>
#import <IJSVGTextPathMetrics.h>

// Keep shaping runs separate when their text belongs to different nodes.
static NSString* const IJSVGTextOwnerKey = @"IJSVGTextOwner";

static NSUInteger IJSVGTextChunkEnd(IJSVGTextCharacter* characters,
                                    NSUInteger count, NSUInteger start,
                                    CGFloat inlineSize)
{
    IJSVGTextCharacter* first = &characters[start];
    NSUInteger end = start + 1;
    while(end < count) {
        IJSVGTextCharacter* next = &characters[end];
        if(next->firstCodeUnit == '\n' || next->firstCodeUnit == '\r') {
            break;
        }
        if(inlineSize <= 0 &&
           (!isnan(next->x) || !isnan(next->y) || next->pathNode != first->pathNode)) {
            break;
        }
        end++;
    }
    return end;
}

static NSUInteger IJSVGTextWrappedEnd(CTTypesetterRef typesetter,
                                      IJSVGTextCharacter* first,
                                      NSUInteger start, NSUInteger end,
                                      CGFloat inlineSize,
                                      NSAttributedString* attributed,
                                      NSData* map)
{
    if(inlineSize > 0) {
        CGFloat scaledWidth = inlineSize * first->style.fontScale;
        CFIndex length = CTTypesetterSuggestLineBreak(typesetter, first->utf16,
                                                      scaledWidth);
        if(length <= 0) {
            length = CTTypesetterSuggestClusterBreak(typesetter, first->utf16,
                                                     scaledWidth);
        }
        if(length > 0 && first->utf16 + length < attributed.length) {
            NSUInteger candidate = ((const NSUInteger*)map.bytes)[first->utf16 + length];
            if(candidate < end && candidate > start) {
                end = candidate;
            }
        }
    }
    return end;
}

typedef struct {
    CGFloat length;
    CGFloat offset;
    CGFloat anchorStart;
    BOOL closed;
    BOOL reverse;
    BOOL vertical;
} IJSVGTextPathPositioning;

static IJSVGTextPathPositioning IJSVGTextResolvePathPositioning(IJSVGText* node,
                                                                IJSVGTextComputedStyle* style,
                                                                IJSVGTextComputedStyle* pathStyle,
                                                                IJSVGTextPathMetrics* metrics)
{
    IJSVGTextAttributeValue* offsetValue = node.positioning[IJSVGAttributeStartOffset];
    CGFloat length = metrics.length;
    CGFloat offset = IJSVGTextLength(offsetValue, pathStyle.size, pathStyle.xHeight,
                                     length);
    CGFloat authorLength = node.positioning[IJSVGAttributePathLength].number;
    if(authorLength > 0 && offsetValue.lengthBasis != IJSVGTextLengthBasisPercentage) {
        offset *= length / authorLength;
    }
    IJSVGTextKeyword anchor = style.values[IJSVGAttributeTextAnchor].keyword;
    BOOL anchoredAtEnd = (anchor == IJSVGTextKeywordEnd) != style.rtl;
    CGFloat anchorStart = anchor == IJSVGTextKeywordMiddle ? -length * .5 : (anchoredAtEnd ? -length : 0);
    IJSVGTextPathPositioning positioning = {
        .length = length,
        .offset = offset,
        .anchorStart = anchorStart,
        .closed = metrics.closed,
        .reverse = node.positioning[IJSVGAttributeSide].keyword == IJSVGTextKeywordRight,
        .vertical = style.vertical
    };
    return positioning;
}

static void IJSVGTextPositionOnPath(IJSVGTextCharacter* c,
                                    const IJSVGTextPathPositioning* positioning,
                                    IJSVGTextPathMetrics* metrics)
{
    CGFloat length = positioning->length;
    CGFloat offset = positioning->offset;
    BOOL vertical = positioning->vertical;
    CGFloat inlinePosition = vertical ? c->position.y : c->position.x;
    CGFloat middle = inlinePosition + c->advance * .5 + offset;
    if(positioning->closed) {
        CGFloat low = positioning->anchorStart;
        c->hidden = middle - offset < low || middle - offset > low + length;
        CGFloat wrappedPosition = fmod(middle, length) + length;
        middle = fmod(wrappedPosition, length);
    } else {
        c->hidden = middle < 0 || middle > length;
    }
    BOOL reverse = positioning->reverse;
    CGPoint point, tangent;
    CGFloat pathPosition = reverse ? length - middle : middle;
    [metrics pointAt:pathPosition
               point:&point
             tangent:&tangent];
    if(reverse) {
        tangent = CGPointMake(-tangent.x, -tangent.y);
    }
    CGFloat cross = vertical ? -c->position.x : c->position.y;
    CGFloat positionX = point.x - tangent.x * c->advance * .5 - tangent.y * cross;
    CGFloat positionY = point.y - tangent.y * c->advance * .5 + tangent.x * cross;
    c->position = CGPointMake(positionX, positionY);
    c->rotation += atan2(tangent.y, tangent.x) - (vertical ? M_PI_2 : 0);
}

static NSRange IJSVGTextAccumulateRanges(IJSVGText* node,
                                         CFMutableDictionaryRef indices,
                                         NSRange* ranges, NSUInteger* count)
{
    const void* key = (__bridge const void*)node;
    uintptr_t entry = (uintptr_t)CFDictionaryGetValue(indices, key);
    NSRange range = entry != 0 ? ranges[entry - 1] : NSMakeRange(NSNotFound, 0);
    for(IJSVGText* child in node.children) {
        // Include child text without walking back through every ancestor.
        NSRange childRange = IJSVGTextAccumulateRanges(child, indices, ranges,
                                                       count);
        if(childRange.location == NSNotFound) {
            continue;
        }
        range = range.location == NSNotFound ? childRange : NSUnionRange(range,
                                                                         childRange);
    }
    if(range.location != NSNotFound) {
        if(entry == 0) {
            entry = ++*count;
            CFDictionarySetValue(indices, key, (const void*)entry);
        }
        ranges[entry - 1] = range;
    }
    return range;
}

@interface IJSVGTextLayout () {
    CFMutableDictionaryRef _rangeIndices;
    NSMutableData* _rangeRecords;
    id _paragraphStyles[2];
    NSUInteger _characterCapacity;
    IJSVGTextCharacter* _characters;
    NSUInteger _characterCount;
    IJSVGTextCharacter _pendingSpace;
    BOOL _hasPendingSpace;
    BOOL _hasBidiScopes;
    BOOL _hasCapitalization;
    NSData* _positionData;
    NSArray<NSValue*>* _characterPositions;
    NSData* _rotationData;
    NSArray<NSNumber*>* _characterRotations;
}

@property (nonatomic, readwrite) IJSVGGroup* group;
@property (nonatomic, readwrite) NSString* string;
@property (nonatomic, readwrite) NSUInteger glyphCount;
@property (nonatomic, readwrite) CGFloat advance;
@property (nonatomic, assign) CGSize viewport;
@property (nonatomic, strong) IJSVGText* root;
@property (nonatomic, strong) NSMutableData* glyphs;
@property (nonatomic, strong) NSHashTable* glyphFonts;
@property (nonatomic, strong) NSMapTable<IJSVGNode*, IJSVGTextComputedStyle*>* styles;
@property (nonatomic, strong) NSMapTable<IJSVGText*, IJSVGGroup*>* groups;
@property (nonatomic, strong) IJSVGTextFontResolver* fontResolver;
@property (nonatomic, copy) IJSVGTextPathResolver pathResolver;

@end

@implementation IJSVGTextLayout

- (void)dealloc
{
    if(_rangeIndices != NULL) {
        CFRelease(_rangeIndices);
    }
    free(_characters);
}

- (IJSVGTextComputedStyle*)styleForNode:(IJSVGNode*)node
{
    if(node == nil) {
        return nil;
    }
    IJSVGTextComputedStyle* style = [self.styles objectForKey:node];
    if(style != nil) {
        return style;
    }
    IJSVGTextComputedStyle* parent = [self styleForNode:node.styleParent];
    if(parent != nil && node.textStyle.count == 0 &&
       parent.values[IJSVGAttributeInlineSize] == nil &&
       parent.values[IJSVGAttributeAlignmentBaseline] == nil &&
       parent.values[IJSVGAttributeBaselineShift] == nil &&
       parent.values[IJSVGAttributeUnicodeBidi] == nil) {
        [self.styles setObject:parent
                        forKey:node];
        return parent;
    }
    NSMutableDictionary<NSString*, IJSVGTextAttributeValue*>* values = [parent.values mutableCopy] ?: [[NSMutableDictionary alloc] init];
    [values removeObjectForKey:IJSVGAttributeInlineSize];
    [values removeObjectForKey:IJSVGAttributeAlignmentBaseline];
    [values removeObjectForKey:IJSVGAttributeBaselineShift];
    [values removeObjectForKey:IJSVGAttributeUnicodeBidi];
    NSDictionary<NSString*, IJSVGTextAttributeValue*>* specified = node.textStyle;
    for(NSString* key in specified) {
        IJSVGTextAttributeValue* value = specified[key];
        switch(value.keyword) {
            case IJSVGTextKeywordInherit:
                if(parent.values[key] != nil) {
                    values[key] = parent.values[key];
                }
                break;
            case IJSVGTextKeywordUnset:
                break;
            case IJSVGTextKeywordInitial:
                [values removeObjectForKey:key];
                break;
            default:
                values[key] = value;
                break;
        }
    }
    IJSVGTextAttributeValue* weight = values[IJSVGAttributeFontWeight];
    if(weight.keyword == IJSVGTextKeywordBolder || weight.keyword == IJSVGTextKeywordLighter) {
        IJSVGTextAttributeValue* inherited = parent.values[IJSVGAttributeFontWeight];
        CGFloat parentWeight = inherited.keyword == IJSVGTextKeywordBold ? 700 :
            (inherited.number > 0 ? inherited.number : 400);
        CGFloat resolved;
        if(weight.keyword == IJSVGTextKeywordBolder) {
            resolved = parentWeight < 350 ? 400 : (parentWeight < 550 ? 700 : MAX(900, parentWeight));
        } else {
            resolved = parentWeight < 550 ? MIN(100, parentWeight) : (parentWeight < 750 ? 400 : 700);
        }
        // Parsed values may be shared by other nodes; never mutate them.
        IJSVGTextAttributeValue* computed = [[IJSVGTextAttributeValue alloc] init];
        computed.number = resolved;
        values[IJSVGAttributeFontWeight] = computed;
    }
    style = [[IJSVGTextComputedStyle alloc] init];
    CGFloat parentSize = parent != nil ? parent.size : 16.;
    IJSVGTextAttributeValue* size = specified[IJSVGAttributeFontSize];
    CGFloat parentXHeight = parent.xHeight;
    if(parent == nil && size.lengthBasis == IJSVGTextLengthBasisXHeight) {
        // Font size uses parent metrics, or the initial font at the root.
        id initialFont = [self.fontResolver fontForValues:@{}
                                                     size:parentSize];
        parentXHeight = IJSVGTextFontXHeight((__bridge CTFontRef)initialFont,
                                             parentSize,
                                             self.fontResolver.renderScale);
    }
    style.size = IJSVGTextFontSize(size, parentSize, parentXHeight);
    style.fontScale = self.fontResolver.renderScale;
    style.values = values;
    IJSVGTextKeyword bidi = values[IJSVGAttributeUnicodeBidi].keyword;
    if(bidi == IJSVGTextKeywordEmbed || bidi == IJSVGTextKeywordBidiOverride ||
       bidi == IJSVGTextKeywordIsolate || bidi == IJSVGTextKeywordIsolateOverride ||
       bidi == IJSVGTextKeywordPlaintext) {
        _hasBidiScopes = YES;
    }
    style.orientation = values[IJSVGAttributeTextOrientation].keyword;
    IJSVGTextAttributeValue* decoration = values[IJSVGAttributeTextDecorationLine]
        ?: values[IJSVGAttributeTextDecoration];
    style.decorations = decoration.decorations;
    if(IJSVGTextCanReuseFont(parent, values, style.size)) {
        style.font = parent.font;
        style.xHeight = parent.xHeight;
        style.nativeSpacing = parent.nativeSpacing;
    } else {
        style.font = [self.fontResolver fontForValues:values
                                                 size:style.size];
        style.nativeSpacing = [self.fontResolver usesNativeSpacingForFont:style.font];
        style.xHeight = IJSVGTextFontXHeight((__bridge CTFontRef)style.font,
                                             style.size, style.fontScale);
    }
    style.wordSpacing = IJSVGTextLength(values[IJSVGAttributeWordSpacing],
                                        style.size, style.xHeight, style.size);
    style.rtl = values[IJSVGAttributeDirection].keyword == IJSVGTextKeywordRTL;
    IJSVGTextKeyword writing = values[IJSVGAttributeWritingMode].keyword;
    style.vertical = writing == IJSVGTextKeywordVerticalRL || writing == IJSVGTextKeywordVerticalLR;
    style.baseline = parent.baseline;
    IJSVGTextAttributeValue* shift = values[IJSVGAttributeBaselineShift];
    switch(shift.keyword) {
        case IJSVGTextKeywordSuper:
            style.baseline -= .6 * style.size;
            break;
        case IJSVGTextKeywordSub:
            style.baseline += .3 * style.size;
            break;
        case IJSVGTextKeywordBaseline:
            break;
        default: {
            CGFloat referenceHeight = parent != nil ? parent.lineHeight : style.size;
            style.baseline -= IJSVGTextLength(shift, style.size, style.xHeight, referenceHeight);
            break;
        }
    }
    IJSVGTextAttributeValue* lineHeight = values[IJSVGAttributeLineHeight];
    style.lineHeight = style.size * 1.2;
    if(lineHeight != nil && lineHeight.keyword != IJSVGTextKeywordNormal) {
        style.lineHeight = lineHeight.unitless
            ? lineHeight.number * style.size
            : IJSVGTextLength(lineHeight, style.size, style.xHeight,
                              style.size);
        if(!lineHeight.unitless && lineHeight.lengthBasis != IJSVGTextLengthBasisAbsolute) {
            // Resolve relative line heights before passing the length to child nodes.
            IJSVGTextAttributeValue* computed = [[IJSVGTextAttributeValue alloc] init];
            computed.number = style.lineHeight;
            values[IJSVGAttributeLineHeight] = computed;
            style.values = values;
        }
    }
    [self.styles setObject:style
                    forKey:node];
    return style;
}

- (void)appendString:(NSString*)string
               owner:(IJSVGText*)owner
                path:(IJSVGText*)path
{
    IJSVGTextComputedStyle* style = [self styleForNode:owner];
    IJSVGTextKeyword whitespace = style.values[IJSVGAttributeWhiteSpace].keyword;
    BOOL preserve = (whitespace == IJSVGTextKeywordPre || whitespace == IJSVGTextKeywordPreWrap ||
                     whitespace == IJSVGTextKeywordBreakSpaces) ||
        (!whitespace && style.values[IJSVGAttributeXMLSpace].keyword == IJSVGTextKeywordPreserve);
    BOOL preserveLines = preserve || whitespace == IJSVGTextKeywordPreLine;
    IJSVGTextKeyword transform = style.values[IJSVGAttributeTextTransform].keyword;
    if(transform == IJSVGTextKeywordUppercase) {
        string = string.uppercaseString;
    } else if(transform == IJSVGTextKeywordLowercase) {
        string = string.lowercaseString;
    } else if(transform == IJSVGTextKeywordCapitalize) {
        _hasCapitalization = YES;
    }
    for(NSUInteger index = 0; index < string.length;) {
        unichar first = [string characterAtIndex:index];
        NSUInteger length = CFStringIsSurrogateHighCharacter(first) && index + 1 < string.length &&
                CFStringIsSurrogateLowCharacter([string characterAtIndex:index + 1]) ? 2 : 1;
        unichar second = length == 2 ? [string characterAtIndex:index + 1] : 0;
        index += length;
        BOOL line = first == '\n' || first == '\r';
        BOOL space = first == ' ' || first == '\t' || line;
        if(line && !whitespace && !preserve) {
            continue; // SVG 1.1 xml:space default.
        }
        BOOL collapse = space && !preserve && !(line && preserveLines);
        if(collapse && (_hasPendingSpace || _characterCount == 0 ||
                        _characters[_characterCount - 1].firstCodeUnit == '\n')) {
            continue;
        }
        if(space && (!preserveLines || (preserve && !whitespace))) {
            first = ' ';
        }
        IJSVGTextCharacter record = { 0 };
        IJSVGTextCharacter* character = &record;
        character->firstCodeUnit = first;
        character->secondCodeUnit = second;
        character->owner = owner;
        character->pathNode = path;
        character->style = style;
        character->x = character->y = NAN;
        character->scale = 1;
        // Wait for more text before keeping a space at the end.
        if(collapse) {
            _pendingSpace = record;
            _hasPendingSpace = YES;
            continue;
        }
        if(line && preserveLines) {
            _hasPendingSpace = NO;
        }
        if(_hasPendingSpace) {
            IJSVGTextAppendCharacter(&_characters, &_characterCount,
                                     &_characterCapacity, &_pendingSpace);
            _hasPendingSpace = NO;
        }
        IJSVGTextAppendCharacter(&_characters, &_characterCount,
                                 &_characterCapacity, character);
    }
}

- (void)capitalizeWords
{
    if(!_hasCapitalization || _characterCount == 0) {
        return;
    }
    NSMutableData* storage = [NSMutableData dataWithCapacity:_characterCount * sizeof(unichar)];
    for(NSUInteger index = 0; index < _characterCount; index++) {
        IJSVGTextCharacter* character = &_characters[index];
        [storage appendBytes:&character->firstCodeUnit
                       length:sizeof(unichar)];
        if(character->secondCodeUnit != 0) {
            [storage appendBytes:&character->secondCodeUnit
                           length:sizeof(unichar)];
        }
    }
    NSString* string = [[NSString alloc] initWithCharacters:storage.bytes
                                                    length:storage.length / sizeof(unichar)];
    NSMutableIndexSet* starts = [[NSMutableIndexSet alloc] init];
    [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
                               options:NSStringEnumerationByWords | NSStringEnumerationSubstringNotRequired
                            usingBlock:^(NSString* substring, NSRange range, NSRange enclosingRange, BOOL* stop) {
                                [starts addIndex:range.location];
                            }];
    IJSVGTextCharacter* characters = NULL;
    NSUInteger count = 0;
    NSUInteger capacity = 0;
    NSUInteger offset = 0;
    for(NSUInteger index = 0; index < _characterCount; index++) {
        IJSVGTextCharacter character = _characters[index];
        NSUInteger length = character.secondCodeUnit == 0 ? 1 : 2;
        BOOL capitalize = character.style.values[IJSVGAttributeTextTransform].keyword == IJSVGTextKeywordCapitalize;
        if(capitalize && [starts containsIndex:offset]) {
            // Only titlecase the initial scalar; preserve the rest of the word.
            NSString* initial = [string substringWithRange:NSMakeRange(offset, length)].capitalizedString;
            for(NSUInteger unit = 0; unit < initial.length; unit++) {
                character.firstCodeUnit = [initial characterAtIndex:unit];
                character.secondCodeUnit = 0;
                if(CFStringIsSurrogateHighCharacter(character.firstCodeUnit) && unit + 1 < initial.length &&
                   CFStringIsSurrogateLowCharacter([initial characterAtIndex:unit + 1])) {
                    character.secondCodeUnit = [initial characterAtIndex:++unit];
                }
                IJSVGTextAppendCharacter(&characters, &count, &capacity, &character);
            }
        } else {
            IJSVGTextAppendCharacter(&characters, &count, &capacity, &character);
        }
        offset += length;
    }
    free(_characters);
    _characters = characters;
    _characterCount = count;
    _characterCapacity = capacity;
}

- (void)collect:(IJSVGText*)node
           path:(IJSVGText*)path
{
    if(!node.shouldRender) {
        return;
    }
    if(node.isTextPath) {
        path = node;
    }
    for(id item in node.textContent) {
        if([item isKindOfClass:NSString.class]) {
            [self appendString:item
                         owner:node
                          path:path];
        } else if([item isKindOfClass:IJSVGText.class]) {
            [self collect:item
                     path:path];
        }
    }
}

- (NSRange)rangeForNode:(IJSVGText*)node
{
    uintptr_t entry = (uintptr_t)CFDictionaryGetValue(_rangeIndices,
                                                      (__bridge const void*)node);
    const NSRange* ranges = _rangeRecords.bytes;
    return entry != 0 ? ranges[entry - 1] : NSMakeRange(0, 0);
}

- (void)resolvePositions:(IJSVGText*)node
{
    NSRange range = [self rangeForNode:node];
    static NSArray<NSString*>* keys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[
            IJSVGAttributeX, IJSVGAttributeY, IJSVGAttributeDX,
            IJSVGAttributeDY, IJSVGAttributeRotate
        ];
    });
    static const IJSVGNodeAttribute attributes[] = { IJSVGNodeAttributeX, IJSVGNodeAttributeY,
                                                     IJSVGNodeAttributeDX, IJSVGNodeAttributeDY, IJSVGNodeAttributeRotate };
    for(NSUInteger index = 0; index < keys.count; index++) {
        IJSVGNodeAttribute attribute = attributes[index];
        BOOL isRotation = attribute == IJSVGNodeAttributeRotate;
        BOOL horizontal = attribute == IJSVGNodeAttributeX || attribute == IJSVGNodeAttributeDX;
        CGFloat referenceLength = horizontal ? self.viewport.width : self.viewport.height;
        NSArray<IJSVGTextAttributeValue*>* values = node.positioning[keys[index]].lengths;
        NSUInteger count = MIN(range.length, values.count);
        if(isRotation && values.count != 0) {
            count = range.length;
        }
        for(NSUInteger offset = 0; offset < count; offset++) {
            IJSVGTextCharacter* character = &_characters[range.location + offset];
            NSUInteger valueIndex = MIN(offset, values.count - 1);
            IJSVGTextAttributeValue* value = values[valueIndex];
            CGFloat amount = isRotation
                ? value.number
                : IJSVGTextLength(value, character->style.size,
                                  character->style.xHeight, referenceLength);
            switch(attribute) {
                case IJSVGNodeAttributeX:
                    character->x = amount;
                    break;
                case IJSVGNodeAttributeY:
                    character->y = amount;
                    break;
                case IJSVGNodeAttributeDX:
                    character->dx = amount;
                    break;
                case IJSVGNodeAttributeDY:
                    character->dy = amount;
                    break;
                case IJSVGNodeAttributeRotate:
                    character->rotation = amount;
                    break;
                default:
                    break;
            }
        }
    }
    for(IJSVGText* child in node.children) {
        [self resolvePositions:child];
    }
}

- (NSDictionary*)attributesForCharacter:(IJSVGTextCharacter*)character
{
    IJSVGTextComputedStyle* style = character->style;
    NSMutableDictionary* attributes = [NSMutableDictionary dictionaryWithDictionary:@{
        (__bridge NSString*)kCTFontAttributeName: style.font,
        IJSVGTextOwnerKey: character->owner
    }];
    IJSVGTextKeyword ligatures = style.values[IJSVGAttributeFontVariantLigatures].keyword;
    if(ligatures == IJSVGTextKeywordNone || ligatures == IJSVGTextKeywordNoCommonLigatures) {
        attributes[(__bridge NSString*)kCTLigatureAttributeName] = @0;
    }
    IJSVGTextAttributeValue* spacing = style.values[IJSVGAttributeLetterSpacing];
    if(spacing != nil && spacing.keyword != IJSVGTextKeywordNormal) {
        CGFloat letterSpacing = IJSVGTextLength(spacing, style.size,
                                                style.xHeight, style.size);
        CGFloat scaledSpacing = letterSpacing * style.fontScale;
        attributes[(__bridge NSString*)kCTKernAttributeName] = @(scaledSpacing);
        attributes[(__bridge NSString*)kCTLigatureAttributeName] = @0;
    } else if(style.values[IJSVGAttributeFontKerning].keyword == IJSVGTextKeywordNone ||
              (!style.nativeSpacing && style.values[IJSVGAttributeFontKerning].keyword != IJSVGTextKeywordNormal)) {
        // Preserve native system font spacing unless explicitly disabled.
        attributes[(__bridge NSString*)kCTKernAttributeName] = @0;
    }
    NSString* language = style.values[IJSVGAttributeLang].string ?: style.values[IJSVGAttributeXMLLang].string;
    if(language) {
        attributes[(__bridge NSString*)kCTLanguageAttributeName] = language;
    }
    if(style.vertical) {
        attributes[(__bridge NSString*)kCTVerticalFormsAttributeName] = @YES;
    }
    return attributes;
}

- (NSArray<IJSVGText*>*)bidiScopesForNode:(IJSVGText*)node
{
    NSMutableArray* scopes = [[NSMutableArray alloc] init];
    for(IJSVGNode* current = node; current != nil; current = current.parentNode) {
        IJSVGTextKeyword bidi = [self styleForNode:current].values[IJSVGAttributeUnicodeBidi].keyword;
        if(bidi == IJSVGTextKeywordEmbed || bidi == IJSVGTextKeywordBidiOverride ||
           bidi == IJSVGTextKeywordIsolate || bidi == IJSVGTextKeywordIsolateOverride ||
           bidi == IJSVGTextKeywordPlaintext) {
            [scopes insertObject:current atIndex:0];
        }
        if(current == self.root) {
            break;
        }
    }
    return scopes;
}

- (void)appendBidiScope:(IJSVGText*)node
                opening:(BOOL)opening
                   text:(NSMutableAttributedString*)text
                    map:(NSMutableData*)map
             attributes:(NSDictionary*)attributes
{
    IJSVGTextComputedStyle* style = [self styleForNode:node];
    IJSVGTextKeyword bidi = style.values[IJSVGAttributeUnicodeBidi].keyword;
    NSString* controls = nil;
    switch(bidi) {
        case IJSVGTextKeywordEmbed:
            controls = opening ? (style.rtl ? @"\u202B" : @"\u202A") : @"\u202C";
            break;
        case IJSVGTextKeywordBidiOverride:
            controls = opening ? (style.rtl ? @"\u202E" : @"\u202D") : @"\u202C";
            break;
        case IJSVGTextKeywordIsolate:
            controls = opening ? (style.rtl ? @"\u2067" : @"\u2066") : @"\u2069";
            break;
        case IJSVGTextKeywordIsolateOverride:
            controls = opening ? (style.rtl ? @"\u2068\u202E" : @"\u2068\u202D") : @"\u202C\u2069";
            break;
        case IJSVGTextKeywordPlaintext:
            controls = opening ? @"\u2068" : @"\u2069";
            break;
        default:
            return;
    }
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:controls
                                                                attributes:attributes]];
    // Added bidi controls affect shaping without taking an SVG character index.
    NSUInteger missing = NSNotFound;
    for(NSUInteger index = 0; index < controls.length; index++) {
        [map appendBytes:&missing
                  length:sizeof(missing)];
    }
}

- (NSMutableAttributedString*)bidiTextForRange:(NSRange)range
                                    attributed:(NSAttributedString*)attributed
                                           map:(NSMutableData*)map
                                       offsets:(NSMutableData*)offsets
{
    NSMutableAttributedString* result = [[NSMutableAttributedString alloc] init];
    [offsets setLength:range.length * sizeof(NSUInteger)];
    NSUInteger* positions = offsets.mutableBytes;
    NSArray<IJSVGText*>* active = @[];
    NSDictionary* attributes = nil;
    NSUInteger end = NSMaxRange(range);
    for(NSUInteger index = range.location; index < end;) {
        IJSVGTextCharacter* first = &_characters[index];
        attributes = [attributed attributesAtIndex:first->utf16
                                      effectiveRange:NULL];
        NSArray<IJSVGText*>* next = [self bidiScopesForNode:first->owner];
        NSUInteger common = 0;
        while(common < active.count && common < next.count && active[common] == next[common]) {
            common++;
        }
        for(NSUInteger scope = active.count; scope > common; scope--) {
            [self appendBidiScope:active[scope - 1]
                         opening:NO
                            text:result
                             map:map
                      attributes:attributes];
        }
        for(NSUInteger scope = common; scope < next.count; scope++) {
            [self appendBidiScope:next[scope]
                         opening:YES
                            text:result
                             map:map
                      attributes:attributes];
        }
        active = next;
        NSUInteger start = first->utf16;
        NSUInteger length = 0;
        while(index < end && _characters[index].owner == first->owner) {
            IJSVGTextCharacter* character = &_characters[index];
            positions[index - range.location] = result.length + length;
            NSUInteger units = character->secondCodeUnit == 0 ? 1 : 2;
            for(NSUInteger unit = 0; unit < units; unit++) {
                [map appendBytes:&index
                          length:sizeof(index)];
            }
            length += units;
            index++;
        }
        [result appendAttributedString:[attributed attributedSubstringFromRange:NSMakeRange(start, length)]];
    }
    for(IJSVGText* scope in active.reverseObjectEnumerator) {
        [self appendBidiScope:scope
                     opening:NO
                        text:result
                         map:map
                  attributes:attributes];
    }
    return result;
}

- (void)shapeRange:(NSRange)range
        attributed:(NSAttributedString*)attributed
          utf16Map:(NSData*)map
            origin:(CGPoint)origin
{
    if(!range.length) {
        return;
    }
    IJSVGTextCharacter* first = &_characters[range.location];
    NSUInteger end = NSMaxRange(range);
    NSMutableData* shapedMap = nil;
    NSMutableData* offsets = nil;
    NSMutableAttributedString* substring;
    NSUInteger mapStart = first->utf16;
    if(_hasBidiScopes) {
        shapedMap = [[NSMutableData alloc] init];
        offsets = [[NSMutableData alloc] init];
        substring = [self bidiTextForRange:range
                                 attributed:attributed
                                        map:shapedMap
                                    offsets:offsets];
        mapStart = 0;
    } else {
        // Reuse the original character mapping when no bidi controls are needed.
        NSUInteger utf16End = end == _characterCount ? attributed.length : _characters[end].utf16;
        NSRange stringRange = NSMakeRange(first->utf16, utf16End - first->utf16);
        substring = [[attributed attributedSubstringFromRange:stringRange] mutableCopy];
    }
    // Chunks with the same direction can share their paragraph settings.
    NSUInteger directionIndex = first->style.rtl ? 1 : 0;
    id paragraph = _paragraphStyles[directionIndex];
    if(paragraph == nil) {
        CTWritingDirection direction = first->style.rtl ? kCTWritingDirectionRightToLeft : kCTWritingDirectionLeftToRight;
        CTParagraphStyleSetting setting = {
          kCTParagraphStyleSpecifierBaseWritingDirection,
          sizeof(direction), &direction
        };
        paragraph = CFBridgingRelease(CTParagraphStyleCreate(&setting, 1));
        _paragraphStyles[directionIndex] = paragraph;
    }
    [substring addAttribute:(__bridge NSString*)kCTParagraphStyleAttributeName
                      value:paragraph
                      range:NSMakeRange(0, substring.length)];
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)substring);
    const NSUInteger* mapping = shapedMap != nil ? shapedMap.bytes : map.bytes;
    const NSUInteger* stringOffsets = offsets.bytes;
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    CFIndex runCount = CFArrayGetCount(runs);
    CGFloat lineAdvance = CTLineGetTypographicBounds(line, NULL, NULL, NULL) / first->style.fontScale;
    for(NSUInteger i = range.location; i < end; i++) {
        IJSVGTextCharacter* character = &_characters[i];
        character->middle = YES;
        character->position = origin;
    }
    for(CFIndex index = 0; index < runCount; index++) {
        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, index);
        IJSVGTextAppendGlyphRun(run, _characters, self.glyphs, self.glyphFonts,
                                mapStart, substring.length, mapping,
                                origin);
    }
    // Glyph positions cover normal characters directly. Only characters inside a
    // cluster need a caret lookup; querying every index repeatedly walks the line.
    for(NSUInteger index = range.location; index < end; index++) {
        IJSVGTextCharacter* character = &_characters[index];
        if(character->middle == NO) {
            continue;
        }
        NSUInteger stringIndex = stringOffsets != NULL ? stringOffsets[index - range.location] :
            character->utf16 - first->utf16;
        CGFloat offset = CTLineGetOffsetForStringIndex(line, stringIndex, NULL) / first->style.fontScale;
        CGPoint position = origin;
        if(first->style.vertical) {
            position.y += offset;
        } else {
            position.x += offset;
        }
        character->position = position;
    }
    first->chunk = YES;
    CGFloat lineOrigin = first->style.vertical ? origin.y : origin.x;
    CGFloat lineEnd = lineOrigin + lineAdvance;
    self.advance = MAX(self.advance, lineEnd);
    CFRelease(line);
}

- (void)adjustLength:(IJSVGText*)node
{
    for(IJSVGText* child in node.children) {
        [self adjustLength:child];
    }
    IJSVGTextAttributeValue* specified = node.positioning[IJSVGAttributeTextLength];
    NSRange range = [self rangeForNode:node];
    if(specified == nil || range.length == 0) {
        return;
    }
    IJSVGTextComputedStyle* style = [self styleForNode:node];
    CGFloat target = IJSVGTextLength(specified, style.size, style.xHeight,
                                     self.viewport.width);
    if(target < 0 || !isfinite(target)) {
        return;
    }
    BOOL vertical = style.vertical;
    CGFloat min = CGFLOAT_MAX;
    CGFloat max = -CGFLOAT_MAX;
    NSUInteger end = NSMaxRange(range);
    BOOL hasClusters = NO;
    for(NSUInteger index = range.location; index < end; index++) {
        IJSVGTextCharacter* character = &_characters[index];
        if(character->middle) {
            continue;
        }
        CGFloat position = vertical ? character->position.y : character->position.x;
        min = MIN(min, position);
        max = MAX(max, position + character->advance);
        hasClusters = YES;
    }
    CGFloat length = max - min;
    if(!hasClusters || length <= 0) {
        return;
    }
    BOOL scale = node.positioning[IJSVGAttributeLengthAdjust].keyword == IJSVGTextKeywordSpacingAndGlyphs;
    CGFloat factor = target / length;
    CGFloat delta = target - length;
    __attribute__((objc_precise_lifetime)) NSMutableData* storage = nil;
    NSUInteger* spacingUnits = NULL;
    NSUInteger unitCount = 0;
    if(!scale) {
        storage = [[NSMutableData alloc] initWithLength:range.length * sizeof(NSUInteger)];
        spacingUnits = storage.mutableBytes;
        unitCount = IJSVGTextBuildSpacingUnits(_characters, range, node,
                                               spacingUnits);
    }
    for(NSUInteger index = range.location; index < end; index++) {
        IJSVGTextCharacter* character = &_characters[index];
        if(character->middle) {
            continue;
        }
        CGFloat position = vertical ? character->position.y : character->position.x;
        CGFloat changed = position;
        if(scale) {
            changed = min + (position - min) * factor;
            character->scale *= factor;
            character->advance *= factor;
        } else if(unitCount > 1) {
            NSUInteger unit = spacingUnits[index - range.location];
            changed += delta * (CGFloat)unit / (unitCount - 1);
        }
        if(vertical) {
            character->position.y = changed;
        } else {
            character->position.x = changed;
        }
    }
    for(NSUInteger index = end; index < _characterCount; index++) {
        IJSVGTextCharacter* character = &_characters[index];
        if(vertical) {
            character->position.y += delta;
        } else {
            character->position.x += delta;
        }
    }
}

- (void)applyRelativePositions
{
    CGPoint relative = CGPointZero;
    for(NSUInteger characterIndex = 0; characterIndex < _characterCount; characterIndex++) {
        IJSVGTextCharacter* c = &_characters[characterIndex];
        relative.x += c->dx;
        relative.y += c->dy;
        c->position = CGPointMake(c->position.x + relative.x,
                                  c->position.y + relative.y);
    }
}

- (void)applyAbsolutePositions
{
    CGPoint shift = CGPointZero;
    IJSVGText* previousPath = nil;
    for(NSUInteger i = 0; i < _characterCount; i++) {
        IJSVGTextCharacter* c = &_characters[i];
        if(c->pathNode && c->pathNode != previousPath) {
            if(c->style.vertical) {
                shift.y = -c->position.y;
            } else {
                shift.x = -c->position.x;
            }
        }
        if(!isnan(c->x) && !(c->pathNode && c->style.vertical)) {
            shift.x = c->x - c->position.x + c->dx;
        }
        if(!isnan(c->y) && !(c->pathNode && !c->style.vertical)) {
            shift.y = c->y - c->position.y + c->dy;
        }
        c->position = CGPointMake(c->position.x + shift.x,
                                  c->position.y + shift.y);
        previousPath = c->pathNode;
    }
}

- (void)applyTextAnchors
{
    NSUInteger begin = 0;
    while(begin < _characterCount) {
        NSUInteger end = begin + 1;
        while(end < _characterCount && !_characters[end].chunk) {
            end++;
        }
        IJSVGTextCharacter* first = &_characters[begin];
        BOOL vertical = first->style.vertical;
        CGFloat min = CGFLOAT_MAX, max = -CGFLOAT_MAX;
        for(NSUInteger i = begin; i < end; i++) {
            IJSVGTextCharacter* c = &_characters[i];
            if(c->middle) {
                continue;
            }
            CGFloat p = vertical ? c->position.y : c->position.x;
            min = MIN(min, p);
            max = MAX(max, p + c->advance);
        }
        IJSVGTextKeyword anchor = first->style.values[IJSVGAttributeTextAnchor].keyword;
        if(anchor == IJSVGTextKeywordUnspecified) {
            anchor = IJSVGTextKeywordStart;
        }
        CGFloat amount = 0;
        if(min != CGFLOAT_MAX) {
            CGFloat origin = vertical ? first->position.y : first->position.x;
            if(anchor == IJSVGTextKeywordMiddle) {
                amount = origin - (min + max) * .5;
            } else if(((anchor == IJSVGTextKeywordEnd) && !first->style.rtl) ||
                      ((anchor == IJSVGTextKeywordStart) && first->style.rtl)) {
                amount = origin - max;
            } else {
                amount = origin - min;
            }
        }
        for(NSUInteger i = begin; i < end; i++) {
            IJSVGTextCharacter* c = &_characters[i];
            CGPoint position = c->position;
            CGFloat baseline = IJSVGTextBaselineOffset(c->style);
            if(vertical) {
                position.y += amount;
                position.x -= baseline;
            } else {
                position.x += amount;
                position.y += baseline;
            }
            c->position = position;
        }
        begin = end;
    }
}

- (void)positionCharacters
{
    [self applyRelativePositions];
    [self adjustLength:self.root];
    [self applyAbsolutePositions];
    [self applyTextAnchors];
}

- (void)positionOnPaths
{
    NSMapTable* metricsCache = nil;
    IJSVGText* metricsNode = nil;
    IJSVGTextComputedStyle* positioningStyle = nil;
    IJSVGTextPathPositioning positioning = { 0 };
    IJSVGTextPathMetrics* metrics = nil;
    IJSVGTextPathMetrics* previousMetrics = nil;
    id previousResolvedPath = nil;
    CGPoint endPoint = CGPointZero;
    CGPoint continuation = CGPointZero;
    IJSVGText* previous = nil;
    for(NSUInteger characterIndex = 0; characterIndex < _characterCount; characterIndex++) {
        IJSVGTextCharacter* c = &_characters[characterIndex];
        IJSVGText* node = c->pathNode;
        if(!node) {
            if(previous) {
                continuation = CGPointMake(continuation.x - c->position.x,
                                           continuation.y - c->position.y);
                previous = nil;
            }
            c->position = CGPointMake(c->position.x + continuation.x,
                                      c->position.y + continuation.y);
            continue;
        }
        if(metricsNode != node) {
            metricsNode = node;
            positioningStyle = nil;
            IJSVGNode* key = node.textPath ?: node;
            metrics = [metricsCache objectForKey:key];
            if(metrics == nil) {
                CGPathRef path = node.textPath && self.pathResolver ? self.pathResolver(node.textPath) : NULL;
                CGPathRef previousPath = (__bridge CGPathRef)previousResolvedPath;
                // Separate references can resolve to the same path geometry.
                if(path != NULL && previousPath != NULL && CGPathEqualToPath(path,
                                                                             previousPath)) {
                    metrics = previousMetrics;
                } else {
                    metrics = [[IJSVGTextPathMetrics alloc] initWithPath:path];
                    previousMetrics = metrics;
                    previousResolvedPath = path != NULL ? CFBridgingRelease(CGPathCreateCopy(path)) : nil;
                }
                if(path != NULL) {
                    CGPathRelease(path);
                }
                if(metricsCache == nil) {
                    metricsCache = [NSMapTable strongToStrongObjectsMapTable];
                }
                [metricsCache setObject:metrics
                                 forKey:key];
            }
            if(metrics.length > 0) {
                CGPoint endTangent;
                BOOL reverse = node.positioning[IJSVGAttributeSide].keyword == IJSVGTextKeywordRight;
                [metrics pointAt:reverse ? 0 : metrics.length
                           point:&endPoint
                         tangent:&endTangent];
            }
        }
        if(metrics.length <= 0) {
            c->hidden = YES;
            continue;
        }
      
        // Character anchoring can vary, but relative offsets belong to textPath.
        if(positioningStyle != c->style) {
            positioningStyle = c->style;
            positioning = IJSVGTextResolvePathPositioning(node, positioningStyle,
                                                          [self styleForNode:node],
                                                          metrics);
        }
        IJSVGTextPositionOnPath(c, &positioning, metrics);
        continuation = endPoint;
        previous = node;
    }
}

- (IJSVGGroup*)geometryGroupForNode:(IJSVGText*)node
{
    IJSVGGroup* group = [self.groups objectForKey:node];
    if(group) {
        return group;
    }
    group = [[IJSVGGroup alloc] init];
    [group applyPropertiesFromNode:node];
    group.x = group.y = nil;
    group.mask = node.mask;
    group.type = IJSVGNodeTypeGroup;
    group.parentNode = nil;
    // The renderer applies the root text elements effects exactly once.
    if(node == self.root) {
        group.transforms = @[];
        group.filters = @[];
        group.mask = nil;
        group.clipPath = nil;
        group.opacity = [IJSVGUnitLength unitWithFloat:1];
        group.parentNode = node.parentNode;
    } else {
        // Inline text content does not establish a transformed coordinate system.
        group.transforms = @[];
        IJSVGGroup* parent = [self geometryGroupForNode:(IJSVGText*)node.parentNode];
        [parent addChild:group];
    }
    [self.groups setObject:group
                    forKey:node];
    return group;
}

- (void)buildGeometry
{
    self.group = [self geometryGroupForNode:self.root];
    IJSVGText* previousOwner = nil;
    IJSVGPath* path = nil;
    CGMutablePathRef destination = NULL;
    CGMutablePathRef decorationDestination = NULL;
    NSMapTable* outlineFonts = [NSMapTable strongToStrongObjectsMapTable];
    id previousFont = nil;
    IJSVGTextDecorationMetrics decorationMetrics = { 0 };
    NSMutableIndexSet* decoratedCharacters = [[NSMutableIndexSet alloc] init];
    CFMutableDictionaryRef outlines = NULL;
    const IJSVGTextGlyph* glyphs = _glyphs.bytes;
    NSUInteger count = _glyphs.length / sizeof(IJSVGTextGlyph);
    for(NSUInteger index = 0; index < count; index++) {
        const IJSVGTextGlyph* glyph = &glyphs[index];
        IJSVGTextCharacter* c = &_characters[glyph->character];
        if(c->hidden || c->style.size == 0) {
            continue;
        }
        // Resume parent content after a span in document paint order.
        if(previousOwner != c->owner) {
            IJSVGGroup* group = [self geometryGroupForNode:c->owner];
            path = [[IJSVGPath alloc] init];
            path.type = IJSVGNodeTypePath;
            destination = path.path;
            [group addChild:path];
            decorationDestination = NULL;
            if(c->style.decorations != IJSVGTextDecorationNone) {
                IJSVGPath* decorationPath = [[IJSVGPath alloc] init];
                decorationPath.type = IJSVGNodeTypePath;
                decorationDestination = decorationPath.path;
                [group addChild:decorationPath];
            }
            previousOwner = c->owner;
        }
        if(previousFont != (__bridge id)glyph->font) {
            previousFont = (__bridge id)glyph->font;
            id cached = [outlineFonts objectForKey:previousFont];
            if(cached == nil) {
                CFMutableDictionaryRef cache = CFDictionaryCreateMutable(NULL,
                                                                         0,
                                                                         NULL,
                                                                         &kCFTypeDictionaryValueCallBacks);
                cached = CFBridgingRelease(cache);
                [outlineFonts setObject:cached
                                 forKey:previousFont];
            }
            outlines = (__bridge CFMutableDictionaryRef)cached;
        }
        // Add one so glyph zero still has a nonzero cache key.
        const void* key = (const void*)((uintptr_t)glyph->glyph + 1);
        id outline = (__bridge id)CFDictionaryGetValue(outlines, key);
        if(!outline) {
            CGPathRef cgPath = CTFontCreatePathForGlyph(glyph->font,
                                                        glyph->glyph, NULL);
            // Remember missing outlines too, such as spaces.
            outline = cgPath ? CFBridgingRelease(cgPath) : NSNull.null;
            CFDictionarySetValue(outlines, key, (__bridge const void*)outline);
        }
        CGAffineTransform transform = IJSVGTextGlyphTransform(c, glyph);
        if(outline != NSNull.null) {
            IJSVGTextAppendGlyphPath(destination, (__bridge CGPathRef)outline,
                                     transform);
        }
        // Separate decoration geometry prevents opposite winding from cutting
        // holes in glyphs. Spaces have decorations even without an outline.
        if(decorationDestination != NULL &&
           ![decoratedCharacters containsIndex:glyph->character]) {
            [decoratedCharacters addIndex:glyph->character];
            // Decorations span the cluster once, without combining glyph offsets.
            IJSVGTextGlyph decorationGlyph = *glyph;
            decorationGlyph.offset = CGPointZero;
            CGAffineTransform decorationTransform = IJSVGTextGlyphTransform(c, &decorationGlyph);
            IJSVGTextAppendDecorations(decorationDestination, c, glyph, decorationTransform,
                                       &decorationMetrics);
        }
    }
}

- (NSAttributedString*)attributedTextWithMap:(NSMutableData*)map
{
    // Computed styles include every rendered owner and its ancestors.
    _rangeRecords = [[NSMutableData alloc] initWithLength:_styles.count * sizeof(NSRange)];
    NSRange* ranges = _rangeRecords.mutableBytes;
    NSUInteger rangeCount = 0;
    NSMutableAttributedString* attributed = [[NSMutableAttributedString alloc] init];
    NSUInteger unitCount = 0;
    NSUInteger runLength = 0;
    NSUInteger maximumRunLength = 0;
    IJSVGText* previousOwner = nil;
    for(NSUInteger index = 0; index < _characterCount; index++) {
        IJSVGTextCharacter* character = &_characters[index];
        if(character->owner != previousOwner) {
            runLength = 0;
            previousOwner = character->owner;
        }
        NSUInteger length = character->secondCodeUnit == 0 ? 1 : 2;
        unitCount += length;
        runLength += length;
        maximumRunLength = MAX(maximumRunLength, runLength);
    }
    [map setLength:unitCount * sizeof(NSUInteger)];
    // Map Core Text string offsets back to our character records.
    NSUInteger* mapping = map.mutableBytes;
    __attribute__((objc_precise_lifetime)) NSMutableData* codeUnitStorage = [NSMutableData dataWithLength:maximumRunLength * sizeof(unichar)];
    unichar* codeUnits = codeUnitStorage.mutableBytes;
    NSUInteger characterIndex = 0;
    while(characterIndex < _characterCount) {
        NSUInteger runStart = characterIndex;
        IJSVGTextCharacter* first = &_characters[runStart];
        NSUInteger runLength = 0;
        NSUInteger runOffset = attributed.length;
        while(characterIndex < _characterCount &&
              _characters[characterIndex].owner == first->owner) {
            IJSVGTextCharacter* character = &_characters[characterIndex];
            character->utf16 = runOffset + runLength;
            mapping[character->utf16] = characterIndex;
            codeUnits[runLength++] = character->firstCodeUnit;
            if(character->secondCodeUnit != 0) {
                mapping[character->utf16 + 1] = characterIndex;
                codeUnits[runLength++] = character->secondCodeUnit;
            }
            characterIndex++;
        }
        NSString* runString = [[NSString alloc] initWithCharacters:codeUnits
                                                            length:runLength];
        NSAttributedString* run = [[NSAttributedString alloc] initWithString:runString
                                                                  attributes:[self attributesForCharacter:first]];
        [attributed appendAttributedString:run];
        if(first->style.wordSpacing != 0) {
            // Include word spacing in both typesetting and final glyph advances.
            NSString* kernKey = (__bridge NSString*)kCTKernAttributeName;
            CGFloat kern = [[run attribute:kernKey atIndex:0 effectiveRange:NULL] doubleValue];
            kern += first->style.wordSpacing * first->style.fontScale;
            for(NSUInteger index = runStart; index < characterIndex; index++) {
                IJSVGTextCharacter* character = &_characters[index];
                if(character->firstCodeUnit == ' ') {
                    [attributed addAttribute:kernKey
                                       value:@(kern)
                                       range:NSMakeRange(character->utf16, 1)];
                }
            }
        }

        const void* key = (__bridge const void*)first->owner;
        uintptr_t entry = (uintptr_t)CFDictionaryGetValue(_rangeIndices, key);
        if(entry == 0) {
            entry = ++rangeCount;
            ranges[entry - 1].location = runStart;
            CFDictionarySetValue(_rangeIndices, key, (const void*)entry);
        }
        NSRange* range = &ranges[entry - 1];
        range->length = characterIndex - range->location;
    }
    IJSVGTextAccumulateRanges(_root, _rangeIndices, ranges, &rangeCount);
    _string = attributed.string.copy;
    return attributed;
}

- (void)shapeAttributedText:(NSAttributedString*)attributed
                   utf16Map:(NSData*)map
{
    IJSVGTextComputedStyle* rootStyle = [self styleForNode:_root];
    IJSVGTextAttributeValue* inlineValue = rootStyle.values[IJSVGAttributeInlineSize];
    CGFloat referenceLength = rootStyle.vertical ? _viewport.height : _viewport.width;
    CGFloat inlineSize = IJSVGTextLength(inlineValue, rootStyle.size,
                                         rootStyle.xHeight, referenceLength);
    CTTypesetterRef typesetter = NULL;
    if(inlineSize > 0) {
        typesetter = CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
    }
    NSUInteger start = 0;
    CGPoint origin = CGPointZero;
    CGFloat lineHeight = rootStyle.lineHeight;
    while(start < _characterCount) {
        IJSVGTextCharacter* first = &_characters[start];
        if(first->firstCodeUnit == '\n' || first->firstCodeUnit == '\r') {
            first->middle = YES;
            if(rootStyle.vertical) {
                IJSVGTextKeyword writingMode = rootStyle.values[IJSVGAttributeWritingMode].keyword;
                CGFloat lineOffset = writingMode == IJSVGTextKeywordVerticalLR ? lineHeight : -lineHeight;
                origin = CGPointMake(origin.x + lineOffset, 0);
            } else {
                origin = CGPointMake(0, origin.y + lineHeight);
            }
            lineHeight = rootStyle.lineHeight;
            start++;
            continue;
        }
        NSUInteger chunkEnd = IJSVGTextChunkEnd(_characters, _characterCount,
                                                start, inlineSize);
        NSUInteger end = IJSVGTextWrappedEnd(typesetter, first, start, chunkEnd,
                                             inlineSize, attributed, map);
        BOOL wrapped = end < chunkEnd;
        [self shapeRange:NSMakeRange(start, end - start)
              attributed:attributed
                utf16Map:map
                  origin:origin];
        CGFloat last = 0;
        for(NSUInteger i = start; i < end; i++) {
            IJSVGTextCharacter* c = &_characters[i];
            CGFloat position = rootStyle.vertical ? c->position.y : c->position.x;
            CGFloat characterEnd = position + c->advance;
            last = MAX(last, characterEnd);
            lineHeight = MAX(lineHeight, c->style.lineHeight);
        }
        if(rootStyle.vertical) {
            origin.y = last;
        } else {
            origin.x = last;
        }
        start = end;
        if(wrapped) {
            if(rootStyle.vertical) {
                IJSVGTextKeyword writingMode = rootStyle.values[IJSVGAttributeWritingMode].keyword;
                CGFloat lineOffset = writingMode == IJSVGTextKeywordVerticalLR ? lineHeight : -lineHeight;
                CGFloat nextLineX = origin.x + lineOffset;
                origin = CGPointMake(nextLineX, 0);
            } else {
                origin = CGPointMake(0, origin.y + lineHeight);
            }
            lineHeight = rootStyle.lineHeight;
        }
    }
    if(typesetter != NULL) {
        CFRelease(typesetter);
    }
}

- (NSArray<NSValue*>*)characterPositions
{
    @synchronized(self) {
        // Rendering does not need boxed points, so create them only on request.
        if(_characterPositions == nil) {
            NSUInteger count = _positionData.length / sizeof(CGPoint);
            const CGPoint* points = _positionData.bytes;
            NSMutableArray<NSValue*>* positions = [NSMutableArray arrayWithCapacity:count];
            for(NSUInteger index = 0; index < count; index++) {
                [positions addObject:[NSValue valueWithPoint:points[index]]];
            }
            _characterPositions = [positions copy];
            _positionData = nil;
        }
        return _characterPositions;
    }
}

- (NSArray<NSNumber*>*)characterRotations
{
    @synchronized(self) {
        if(_characterRotations == nil) {
            NSUInteger count = _rotationData.length / sizeof(CGFloat);
            const CGFloat* values = _rotationData.bytes;
            NSMutableArray<NSNumber*>* rotations = [NSMutableArray arrayWithCapacity:count];
            for(NSUInteger index = 0; index < count; index++) {
                [rotations addObject:@(values[index])];
            }
            _characterRotations = [rotations copy];
            _rotationData = nil;
        }
        return _characterRotations;
    }
}

- (void)resolveClusters:(NSAttributedString*)attributed
               utf16Map:(NSData*)map
{
    for(NSUInteger index = 0; index < _characterCount; index++) {
        _characters[index].cluster = index;
    }
    const NSUInteger* mapping = map.bytes;
    NSStringEnumerationOptions options = NSStringEnumerationByComposedCharacterSequences |
        NSStringEnumerationSubstringNotRequired;
    [attributed.string enumerateSubstringsInRange:NSMakeRange(0, attributed.length)
                                          options:options
                                       usingBlock:^(NSString* substring, NSRange range, NSRange enclosingRange, BOOL* stop) {
        NSUInteger start = mapping[range.location];
        NSUInteger end = mapping[NSMaxRange(range) - 1] + 1;
        for(NSUInteger index = start + 1; index < end; index++) {
            IJSVGTextCharacter* character = &self->_characters[index];
            IJSVGTextCharacter* first = &self->_characters[start];
            if(character->owner != first->owner || !isnan(character->x) || !isnan(character->y)) {
                start = index;
            } else {
                character->cluster = start;
            }
        }
    }];
}

- (void)prepareText:(IJSVGText*)text
{
    @autoreleasepool {
        [self collect:text
                 path:nil];
        _hasPendingSpace = NO;
        [self capitalizeWords];
        NSMutableData* map = [[NSMutableData alloc] init];
        NSAttributedString* attributed = [self attributedTextWithMap:map];
        [self resolvePositions:text];
        [self resolveClusters:attributed
                      utf16Map:map];
        [self shapeAttributedText:attributed
                         utf16Map:map];
    }
}

- (void)finishLayout
{
    _glyphCount = _glyphs.length / sizeof(IJSVGTextGlyph);
    NSMutableData* positions = [NSMutableData dataWithLength:_characterCount * sizeof(CGPoint)];
    CGPoint* points = positions.mutableBytes;
    NSMutableData* rotations = [NSMutableData dataWithLength:_characterCount * sizeof(CGFloat)];
    CGFloat* angles = rotations.mutableBytes;
    NSUInteger index = 0;
    for(NSUInteger characterIndex = 0; characterIndex < _characterCount; characterIndex++) {
        IJSVGTextCharacter* c = &_characters[characterIndex];
        angles[index] = c->rotation * 180 / M_PI;
        points[index++] = c->position;
    }
    _positionData = positions;
    _rotationData = rotations;
    // Only immutable geometry and diagnostic metrics survive paint construction.
    _root = nil;
    free(_characters);
    _characters = NULL;
    _characterCount = 0;
    _characterCapacity = 0;
    _glyphs = nil;
    _glyphFonts = nil;
    _styles = nil;
    CFRelease(_rangeIndices);
    _rangeIndices = NULL;
    _rangeRecords = nil;
    _groups = nil;
    _fontResolver = nil;
    _pathResolver = nil;
    _paragraphStyles[0] = nil;
    _paragraphStyles[1] = nil;
}

- (instancetype)initWithText:(IJSVGText*)text
                    viewport:(CGSize)viewport
                pathResolver:(IJSVGTextPathResolver)pathResolver
{
    return [self initWithText:text
                     viewport:viewport
                  renderScale:1
                 pathResolver:pathResolver];
}

- (instancetype)initWithText:(IJSVGText*)text
                    viewport:(CGSize)viewport
                 renderScale:(CGFloat)renderScale
                pathResolver:(IJSVGTextPathResolver)pathResolver
{
    if((self = [super init])) {
        _root = text;
        _viewport = viewport;
        _pathResolver = [pathResolver copy];
        _glyphs = [NSMutableData data];
        _glyphFonts = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory |
                                                      NSPointerFunctionsObjectPointerPersonality];
        _styles = [NSMapTable strongToStrongObjectsMapTable];
        _rangeIndices = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
        _groups = [NSMapTable strongToStrongObjectsMapTable];
        _fontResolver = [[IJSVGTextFontResolver alloc] init];
        _fontResolver.renderScale = isfinite(renderScale) && renderScale > 0 ? renderScale : 1;
        if(IJSVGTextRenderingForNode(text) == IJSVGTextKeywordGeometricPrecision) {
            _fontResolver.renderScale = 1;
        }
        [self prepareText:text];
        [self positionCharacters];
        [self positionOnPaths];
        @autoreleasepool {
            [self buildGeometry];
        }
        [self finishLayout];
    }
    return self;
}

@end
