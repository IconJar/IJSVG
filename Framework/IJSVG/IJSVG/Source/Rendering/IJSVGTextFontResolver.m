//
//  IJSVGTextFontResolver.m
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTextFontResolver.h>
#import <IJSVG/IJSVGRendering.h>
#import <IJSVG/IJSVGParser.h>
#import <CoreText/CoreText.h>

static NSString* const IJSVGTextDefaultFontFamily = @"Times";
static NSString* const IJSVGTextDefaultFontName = @"Times-Roman";
static NSString* const IJSVGTextSystemFontFamily = @".AppleSystemUIFont";
static const uint32_t IJSVGTextOpticalSizeAxis = ('o' << 24) | ('p' << 16) | ('s' << 8) | 'z';

static CTFontSymbolicTraits IJSVGTextFontTraits(NSDictionary<NSString*, IJSVGTextAttributeValue*>* values)
{
    IJSVGTextKeyword weight = values[IJSVGAttributeFontWeight].keyword;
    IJSVGTextKeyword style = values[IJSVGAttributeFontStyle].keyword;
    CTFontSymbolicTraits traits = 0;
    if(weight == IJSVGTextKeywordBold || weight == IJSVGTextKeywordBolder) {
        traits |= kCTFontBoldTrait;
    }
    if(style == IJSVGTextKeywordItalic || style == IJSVGTextKeywordOblique) {
        traits |= kCTFontItalicTrait;
    }
    IJSVGTextKeyword stretch = values[IJSVGAttributeFontStretch].keyword;
    switch(stretch) {
        case IJSVGTextKeywordUltraCondensed:
        case IJSVGTextKeywordExtraCondensed:
        case IJSVGTextKeywordCondensed:
        case IJSVGTextKeywordSemiCondensed:
            traits |= kCTFontCondensedTrait;
            break;
        case IJSVGTextKeywordSemiExpanded:
        case IJSVGTextKeywordExpanded:
        case IJSVGTextKeywordExtraExpanded:
        case IJSVGTextKeywordUltraExpanded:
            traits |= kCTFontExpandedTrait;
            break;
        default:
            break;
    }
    return traits;
}

static NSArray* IJSVGTextFontFeatures(NSDictionary<NSString*, IJSVGTextAttributeValue*>* values)
{
    NSDictionary<NSString*, NSNumber*>* settings = values[IJSVGAttributeFontFeatureSettings].features;
    if(settings.count == 0 && values[IJSVGAttributeFontVariant].keyword != IJSVGTextKeywordSmallCaps) {
        return nil;
    }
    NSMutableArray* features = [NSMutableArray arrayWithCapacity:settings.count + 1];
    for(NSString* tag in settings) {
        [features addObject:@{
            (__bridge NSString*)kCTFontOpenTypeFeatureTag: tag,
            (__bridge NSString*)kCTFontOpenTypeFeatureValue: settings[tag]
        }];
    }

    if(values[IJSVGAttributeFontVariant].keyword == IJSVGTextKeywordSmallCaps) {
        [features addObject:@{
            (__bridge NSString*)kCTFontOpenTypeFeatureTag: @"smcp",
            (__bridge NSString*)kCTFontOpenTypeFeatureValue: @1
        }];
    }
    return features;
}


static BOOL IJSVGTextFontHasSmallCaps(CTFontRef font)
{
    NSArray* features = CFBridgingRelease(CTFontCopyFeatures(font));
    for(NSDictionary* feature in features) {
        NSInteger type = [feature[(__bridge NSString*)kCTFontFeatureTypeIdentifierKey] integerValue];
        if(type != kLowerCaseType && type != kLetterCaseType) {
            continue;
        }
        for(NSDictionary* selector in feature[(__bridge NSString*)kCTFontFeatureTypeSelectorsKey]) {
            NSInteger value = [selector[(__bridge NSString*)kCTFontFeatureSelectorIdentifierKey] integerValue];
            if((type == kLowerCaseType && value == kLowerCaseSmallCapsSelector) ||
                (type == kLetterCaseType && value == kSmallCapsSelector)) {
                return YES;
            }
        }
    }
    return NO;
}

static CGFloat IJSVGTextFontWeight(NSDictionary<NSString*, IJSVGTextAttributeValue*>* values)
{
    IJSVGTextAttributeValue* value = values[IJSVGAttributeFontWeight];
    return value.keyword == IJSVGTextKeywordBold ? 700 : (value.number > 0 ? value.number : 400);
}

static CGFloat IJSVGTextNormalizedWeight(CGFloat weight)
{
    // Core Text uses a normalized scale, with regular at zero.
    static const CGFloat weights[] = { -0.8, -0.6, -0.4, 0, 0.23, 0.3, 0.4, 0.56, 0.62, 1 };
    CGFloat index = MAX(0, MIN(9, weight / 100 - 1));
    NSUInteger lower = (NSUInteger)index;
    return lower == 9
        ? weights[lower]
        : weights[lower] + (weights[lower + 1] - weights[lower]) * (index - lower);
}

static CTFontRef IJSVGTextCreateFontVariant(CTFontRef font, CGFloat size,
                                            CTFontSymbolicTraits traits,
                                            CGFloat weight)
{
    if(weight >= 600) {
        traits |= kCTFontBoldTrait;
    }
    if(weight != 400 && weight != 700) {
        NSDictionary* attributes = @{
            (__bridge NSString*)kCTFontFamilyNameAttribute: CFBridgingRelease(CTFontCopyFamilyName(font)),
            (__bridge NSString*)kCTFontTraitsAttribute: @{
                (__bridge NSString*)kCTFontSymbolicTrait: @(traits),
                (__bridge NSString*)kCTFontWeightTrait: @(IJSVGTextNormalizedWeight(weight))
            }
        };
        CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)attributes);
        NSSet* mandatory = [NSSet setWithObject:(__bridge NSString*)kCTFontFamilyNameAttribute];
        NSArray* matches = CFBridgingRelease(CTFontDescriptorCreateMatchingFontDescriptors(descriptor,
                                                                                         (__bridge CFSetRef)mandatory));
        CFRelease(descriptor);
        CTFontSymbolicTraits styleMask = kCTFontItalicTrait | kCTFontCondensedTrait |
            kCTFontExpandedTrait;
        CTFontDescriptorRef best = NULL;
        CGFloat bestDistance = CGFLOAT_MAX;
        CGFloat requested = IJSVGTextNormalizedWeight(weight);
        for(id match in matches) {
            NSDictionary* candidateTraits = CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)match,
                                                                                           kCTFontTraitsAttribute));
            CTFontSymbolicTraits symbols = [candidateTraits[(__bridge NSString*)kCTFontSymbolicTrait] unsignedIntValue];
            if((symbols & styleMask) != (traits & styleMask)) {
                continue;
            }
            CGFloat candidate = [candidateTraits[(__bridge NSString*)kCTFontWeightTrait] doubleValue];
            CGFloat distance = fabs(candidate - requested);
            // CSS searches towards lighter faces below 400, towards heavier faces
            // above 500, and towards 500 before lighter faces between 400 and 500.
            if(weight < 400) {
                distance += candidate > requested ? 4 : 0;
            } else if(weight > 500) {
                distance += candidate < requested ? 4 : 0;
            } else {
                distance += candidate > IJSVGTextNormalizedWeight(500) ? 8 : (candidate < requested ? 4 : 0);
            }
            if(distance < bestDistance) {
                best = (__bridge CTFontDescriptorRef)match;
                bestDistance = distance;
            }
        }
        if(best != NULL) {
            return CTFontCreateWithFontDescriptor(best, size, NULL);
        }
    }
    CTFontSymbolicTraits mask = kCTFontBoldTrait | kCTFontItalicTrait |
        kCTFontCondensedTrait | kCTFontExpandedTrait;
    if((CTFontGetSymbolicTraits(font) & mask) == traits) {
        return (CTFontRef)CFRetain(font);
    }
    CTFontRef variant = CTFontCreateCopyWithSymbolicTraits(font, size, NULL,
                                                           traits, mask);
    // Keep the base font when the requested variant is unavailable.
    return variant ?: (CTFontRef)CFRetain(font);
}

@interface IJSVGTextFontResolver ()

@property (nonatomic, strong) NSMutableDictionary<NSArray*, id>* fonts;
@property (nonatomic, strong) NSMutableDictionary<NSString*, id>* descriptors;
@property (nonatomic, strong) NSHashTable* nativeSpacingFonts;

@end

@implementation IJSVGTextFontResolver

- (IJSVGTextComputedStyle*)fontStyleForNode:(IJSVGNode*)node
                              parentStyle:(IJSVGTextComputedStyle*)parent
{
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
        // Parsed values may be shared by other nodes. Never mutate them.
        IJSVGTextAttributeValue* computed = [[IJSVGTextAttributeValue alloc] init];
        computed.number = resolved;
        values[IJSVGAttributeFontWeight] = computed;
    }
    IJSVGTextComputedStyle* style = [[IJSVGTextComputedStyle alloc] init];
    CGFloat parentSize = parent != nil ? parent.size : self.defaultFontSize;
    IJSVGTextAttributeValue* size = specified[IJSVGAttributeFontSize];
    CGFloat parentXHeight = parent.xHeight;
    if(parent == nil && size.lengthBasis == IJSVGTextLengthBasisXHeight) {
        // Font size uses parent metrics, or the initial font at the root.
        id initialFont = [self fontForValues:@{}
                                       size:parentSize];
        parentXHeight = IJSVGTextFontXHeight((__bridge CTFontRef)initialFont,
                                             parentSize, self.renderScale);
    }
    style.size = IJSVGTextFontSize(size, parentSize, parentXHeight,
                                   self.defaultFontSize);
    style.fontScale = self.renderScale;
    style.values = values;
    if(IJSVGTextCanReuseFont(parent, values, style.size)) {
        style.font = parent.font;
        style.smallCapsFont = parent.smallCapsFont;
        style.xHeight = parent.xHeight;
        style.nativeSpacing = parent.nativeSpacing;
    } else {
        style.font = [self fontForValues:values
                                   size:style.size];
        CTFontRef font = (__bridge CTFontRef)style.font;
        if(values[IJSVGAttributeFontVariant].keyword == IJSVGTextKeywordSmallCaps &&
            !IJSVGTextFontHasSmallCaps(font)) {
            style.smallCapsFont = CFBridgingRelease(CTFontCreateCopyWithAttributes(font,
                CTFontGetSize(font) * .7, NULL, NULL));
        }
        style.nativeSpacing = [self usesNativeSpacingForFont:style.font];
        style.xHeight = IJSVGTextFontXHeight((__bridge CTFontRef)style.font,
                                             style.size, style.fontScale);
    }
    return style;
}

- (IJSVGTextComputedStyle*)fontStyleForNode:(IJSVGNode*)node
{
    if(node == nil) {
        return nil;
    }
    return [self fontStyleForNode:node parentStyle:[self fontStyleForNode:node.styleParent]];
}


- (instancetype)init
{
    if((self = [super init])) {
        _renderScale = 1;
        _defaultFontSize = IJSVGDefaultFontSize;
        _fonts = [[NSMutableDictionary alloc] init];
        _descriptors = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithRenderingOptions:(IJSVGRenderingOptions*)options
{
    if((self = [self init])) {
        if(options != nil) {
            _defaultFontSize = options.defaultFontSize;
        }
    }
    return self;
}

- (IJSVGNode*)geometryFontOwnerForLength:(IJSVGUnitLength*)length
                                    node:(IJSVGNode*)node
{
    NSDictionary<NSNumber*, IJSVGUnitLength*>* lengths = node.geometryLengths;
    for(NSNumber* attribute in lengths) {
        if(lengths[attribute] != length) {
            continue;
        }
        while(node.styleParent != nil &&
              node.styleParent.geometryLengths[attribute] == length) {
            node = node.styleParent;
        }
        break;
    }
    return node;
}

- (CGFloat)resolveLength:(IJSVGUnitLength*)length
              percentage:(CGFloat)percentage
                    node:(IJSVGNode*)node
{
    if(length.type != IJSVGUnitLengthTypeEM && length.type != IJSVGUnitLengthTypeEX) {
        return [length computeValue:percentage];
    }
    node = [self geometryFontOwnerForLength:length
                                       node:node];
    IJSVGTextComputedStyle* style = [self fontStyleForNode:node];
    // SVG geometry rounds x height to a user unit, matching WebKit.
    return [length computeValue:percentage
                       fontSize:style.size
                        xHeight:ceil(style.xHeight)];
}

- (CGFloat)resolveCSSLength:(IJSVGUnitLength*)length
                 percentage:(CGFloat)percentage
                       node:(IJSVGNode*)node
{
    if(length.type != IJSVGUnitLengthTypeEM && length.type != IJSVGUnitLengthTypeEX) {
        return [length computeValue:percentage];
    }
    node = [self geometryFontOwnerForLength:length
                                       node:node];
    IJSVGTextComputedStyle* style = [self fontStyleForNode:node];
    return [length computeValue:percentage
                       fontSize:style.size
                        xHeight:style.xHeight];
}

- (CGSize)resolveSize:(IJSVGUnitSize*)size
           percentage:(CGSize)percentage
                 node:(IJSVGNode*)node
{
    return CGSizeMake([self resolveLength:size.width percentage:percentage.width node:node],
                       [self resolveLength:size.height percentage:percentage.height node:node]);
}

- (IJSVGUnitRect*)rectByResolvingFontLengths:(IJSVGUnitRect*)rect
                                      node:(IJSVGNode*)node
{
    IJSVGUnitLength* lengths[] = {
      rect.origin.x, rect.origin.y,
      rect.size.width, rect.size.height
    };
    BOOL relative = NO;
    for(NSUInteger index = 0; index < 4; index++) {
        relative |= lengths[index].type == IJSVGUnitLengthTypeEM ||
            lengths[index].type == IJSVGUnitLengthTypeEX;
    }
    if(!relative) {
        return rect;
    }
    IJSVGUnitRect* result = rect.copy;
    result.origin.x = [self unitByResolvingFontLength:rect.origin.x node:node];
    result.origin.y = [self unitByResolvingFontLength:rect.origin.y node:node];
    result.size.width = [self unitByResolvingFontLength:rect.size.width node:node];
    result.size.height = [self unitByResolvingFontLength:rect.size.height node:node];
    return result;
}

- (IJSVGUnitLength*)unitByResolvingFontLength:(IJSVGUnitLength*)length
                                         node:(IJSVGNode*)node
{
    return [self unitByResolvingFontLength:length node:node css:NO];
}

- (IJSVGUnitLength*)unitByResolvingFontLength:(IJSVGUnitLength*)length
                                         node:(IJSVGNode*)node
                                          css:(BOOL)css
{
    if(length.type != IJSVGUnitLengthTypeEM && length.type != IJSVGUnitLengthTypeEX) {
        return length;
    }
    CGFloat value = css ? [self resolveCSSLength:length percentage:0 node:node]
        : [self resolveLength:length percentage:0 node:node];
    return [IJSVGUnitLength unitWithFloat:value];
}

- (BOOL)usesNativeSpacingForFont:(id)font
{
    return [self.nativeSpacingFonts containsObject:font];
}

- (id)descriptorForFamily:(NSString*)family
                     size:(CGFloat)size
{
    BOOL systemFont = [family isEqualToString:IJSVGTextSystemFontFamily];
    // The system font descriptor can change with the requested size.
    id cached = systemFont ? nil : self.descriptors[family];
    if(cached != nil) {
        return cached == NSNull.null ? nil : cached;
    }
    static NSSet* mandatory;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mandatory = [NSSet setWithObject:(__bridge NSString*)kCTFontFamilyNameAttribute];
    });
    CTFontDescriptorRef match = NULL;
    if(systemFont) {
        CTFontRef font = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem,
                                                       size, NULL);
        if(font != NULL) {
            NSDictionary* traits = @{
                (__bridge NSString*)kCTFontWeightTrait: @0,
                (__bridge NSString*)kCTFontWidthTrait: @0,
                (__bridge NSString*)kCTFontSlantTrait: @0
            };
            NSDictionary* attributes = @{(__bridge NSString*)kCTFontTraitsAttribute: traits};
            CFDictionaryRef fontAttributes = (__bridge CFDictionaryRef)attributes;
            CTFontDescriptorRef modifications = CTFontDescriptorCreateWithAttributes(fontAttributes);
            CTFontRef normalized = CTFontCreateCopyWithAttributes(font, size,
                                                                  NULL,
                                                                  modifications);
            match = CTFontCopyFontDescriptor(normalized);
            CFRelease(normalized);
            CFRelease(modifications);
            CFRelease(font);
        }
    } else {
        NSDictionary* attributes = @{(__bridge NSString*)kCTFontFamilyNameAttribute: family};
        CFDictionaryRef fontAttributes = (__bridge CFDictionaryRef)attributes;
        CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes(fontAttributes);
        match = CTFontDescriptorCreateMatchingFontDescriptor(descriptor, (__bridge CFSetRef)mandatory);
        CFRelease(descriptor);
    }
    id result = CFBridgingRelease(match);
    if(systemFont == NO) {
        // Remember missing families so repeated spans do not search again.
        self.descriptors[family] = result ?: NSNull.null;
    }
    return result;
}

- (NSArray*)descriptorsForFamilies:(NSArray<NSString*>*)families
                              size:(CGFloat)size
                        systemFont:(BOOL*)systemFont
{
    NSMutableArray* descriptors = [[NSMutableArray alloc] initWithCapacity:families.count];
    for(NSString* family in families) {
        id descriptor = [self descriptorForFamily:family
                                             size:size];
        if(descriptor != nil && [descriptors containsObject:descriptor] == NO) {
            if(descriptors.count == 0) {
                *systemFont = [family isEqualToString:IJSVGTextSystemFontFamily];
            }
            [descriptors addObject:descriptor];
        }
    }
    return descriptors;
}

- (NSArray*)cascadeForDescriptors:(NSArray*)descriptors
                             font:(CTFontRef)font
                             size:(CGFloat)size
                           traits:(CTFontSymbolicTraits)traits
                           weight:(CGFloat)weight
{
    if(descriptors.count < 2) {
        return nil;
    }
    NSArray* defaults = CFBridgingRelease(CTFontCopyDefaultCascadeListForLanguages(font, NULL));
    NSUInteger count = descriptors.count - 1 + defaults.count;
    NSMutableArray* cascade = [[NSMutableArray alloc] initWithCapacity:count];
    for(NSUInteger index = 1; index < descriptors.count; index++) {
        CTFontDescriptorRef descriptor = (__bridge CTFontDescriptorRef)descriptors[index];
        CTFontRef fallback = CTFontCreateWithFontDescriptor(descriptor, size, NULL);
        CTFontRef variant = IJSVGTextCreateFontVariant(fallback, size, traits, weight);
        [cascade addObject:CFBridgingRelease(CTFontCopyFontDescriptor(variant))];
        CFRelease(variant);
        CFRelease(fallback);
    }
    // Try the requested families before the system fallbacks.
    if(defaults != nil) {
        [cascade addObjectsFromArray:defaults];
    }
    return cascade;
}

- (id)fontForValues:(NSDictionary<NSString*, IJSVGTextAttributeValue*>*)values
               size:(CGFloat)size
{
    NSArray* families = values[IJSVGAttributeFontFamily].families ?: @[IJSVGTextDefaultFontFamily];
    CTFontSymbolicTraits traits = IJSVGTextFontTraits(values);
    CGFloat weight = IJSVGTextFontWeight(values);
    IJSVGTextKeyword rendering = values[IJSVGAttributeTextRendering].keyword;
    CGFloat scale = rendering == IJSVGTextKeywordGeometricPrecision ? 1 : self.renderScale;
    CGFloat opticalSize = MAX(.001, size * scale);
    IJSVGTextAttributeValue* adjustment = values[IJSVGAttributeFontSizeAdjust];
    BOOL adjustsSize = adjustment != nil && adjustment.keyword == IJSVGTextKeywordUnspecified;
    NSArray* key = @[families, @(size), @(traits), @(weight), @(opticalSize),
                     adjustsSize ? @(adjustment.number) : NSNull.null,
                     values[IJSVGAttributeFontFeatureSettings].features ?: @{},
                     @(values[IJSVGAttributeFontVariant].keyword)];
    id cached = self.fonts[key];
    if(cached != nil) {
        return cached;
    }
    CGFloat resolvedSize = MAX(size * self.renderScale, .001);
    BOOL systemFont = NO;
    NSArray* descriptors = [self descriptorsForFamilies:families
                                                   size:resolvedSize
                                             systemFont:&systemFont];
    CTFontRef base = NULL;
    if(descriptors.count != 0) {
        CTFontDescriptorRef descriptor = (__bridge CTFontDescriptorRef)descriptors.firstObject;
        base = CTFontCreateWithFontDescriptor(descriptor, resolvedSize, NULL);
    } else {
        CFStringRef fontName = (__bridge CFStringRef)IJSVGTextDefaultFontName;
        base = CTFontCreateWithName(fontName, resolvedSize, NULL);
    }
    CTFontRef font = IJSVGTextCreateFontVariant(base, resolvedSize, traits, weight);
    CFRelease(base);
    if(adjustsSize) {
        UniChar character = 'x';
        CGGlyph glyph = 0;
        CGFloat xHeight = CTFontGetXHeight(font);
        if(CTFontGetGlyphsForCharacters(font, &character, &glyph, 1)) {
            CGRect bounds = CTFontGetBoundingRectsForGlyphs(font, kCTFontOrientationHorizontal,
                                                            &glyph, NULL, 1);
            if(CGRectGetMaxY(bounds) > 0.f) {
                xHeight = CGRectGetMaxY(bounds);
            }
        }
        if(xHeight > 0.f) {
            CGFloat adjustedSize = resolvedSize * (resolvedSize / xHeight) * adjustment.number;
            if(isfinite(adjustedSize)) {
                resolvedSize = MAX(.001f, adjustedSize);
                CTFontRef adjusted = CTFontCreateCopyWithAttributes(font, resolvedSize, NULL, NULL);
                CFRelease(font);
                font = adjusted;
            }
        }
    }
    NSArray* features = IJSVGTextFontFeatures(values);
    NSArray* cascade = [self cascadeForDescriptors:descriptors
                                              font:font
                                              size:resolvedSize
                                            traits:traits
                                            weight:weight];
    if(features.count != 0 || cascade.count != 0 || systemFont) {
        NSUInteger count = (systemFont ? 1 : 0) + (features.count != 0 ? 1 : 0) + (cascade.count != 0 ? 1 : 0);
        NSMutableDictionary* attributes = [[NSMutableDictionary alloc] initWithCapacity:count];
        if(systemFont) {
            attributes[(__bridge NSString*)kCTFontVariationAttribute] = @{
                @(IJSVGTextOpticalSizeAxis): @(opticalSize)
            };
        }
        if(features.count != 0) {
            attributes[(__bridge NSString*)kCTFontFeatureSettingsAttribute] = features;
        }
        if(cascade.count != 0) {
            attributes[(__bridge NSString*)kCTFontCascadeListAttribute] = cascade;
        }
        CFDictionaryRef fontAttributes = (__bridge CFDictionaryRef)attributes;
        CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes(fontAttributes);
        CTFontRef configured = CTFontCreateCopyWithAttributes(font,
                                                              resolvedSize,
                                                              NULL, descriptor);
        CFRelease(descriptor);
        if(configured != NULL) {
            CFRelease(font);
            font = configured;
        }
    }
    id result = CFBridgingRelease(font);
    if(systemFont) {
        if(self.nativeSpacingFonts == nil) {
            NSPointerFunctionsOptions options = NSPointerFunctionsStrongMemory |
                NSPointerFunctionsObjectPointerPersonality;
            self.nativeSpacingFonts = [NSHashTable hashTableWithOptions:options];
        }
        [self.nativeSpacingFonts addObject:result];
    }
    self.fonts[key] = result;
    return result;
}

@end
