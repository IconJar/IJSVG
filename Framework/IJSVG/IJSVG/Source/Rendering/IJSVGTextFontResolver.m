//
//  IJSVGTextFontResolver.m
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTextFontResolver.h>
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


static CTFontRef IJSVGTextCreateFontVariant(CTFontRef font, CGFloat size,
                                            CTFontSymbolicTraits traits)
{
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

- (instancetype)init
{
    if((self = [super init])) {
        _renderScale = 1;
        _fonts = [[NSMutableDictionary alloc] init];
        _descriptors = [[NSMutableDictionary alloc] init];
    }
    return self;
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
    dispatch_once(&onceToken,
                  ^{
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
        match = CTFontDescriptorCreateMatchingFontDescriptor(descriptor,
                                                             (__bridge CFSetRef)mandatory);
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
{
    if(descriptors.count < 2) {
        return nil;
    }
    NSArray* defaults = CFBridgingRelease(CTFontCopyDefaultCascadeListForLanguages(font,
                                                                                   NULL));
    NSUInteger count = descriptors.count - 1 + defaults.count;
    NSMutableArray* cascade = [[NSMutableArray alloc] initWithCapacity:count];
    for(NSUInteger index = 1; index < descriptors.count; index++) {
        CTFontDescriptorRef descriptor = (__bridge CTFontDescriptorRef)descriptors[index];
        CTFontRef fallback = CTFontCreateWithFontDescriptor(descriptor, size,
                                                            NULL);
        CTFontRef variant = IJSVGTextCreateFontVariant(fallback, size, traits);
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
    IJSVGTextKeyword rendering = values[IJSVGAttributeTextRendering].keyword;
    CGFloat scale = rendering == IJSVGTextKeywordGeometricPrecision ? 1 : self.renderScale;
    CGFloat opticalSize = MAX(.001, size * scale);
    NSArray* key = @[families, @(size), @(traits), @(opticalSize),
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
    CTFontRef font = IJSVGTextCreateFontVariant(base, resolvedSize, traits);
    CFRelease(base);
    NSArray* features = IJSVGTextFontFeatures(values);
    NSArray* cascade = [self cascadeForDescriptors:descriptors
                                              font:font
                                              size:resolvedSize
                                            traits:traits];
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
