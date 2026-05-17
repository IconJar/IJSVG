//
//  IJSVGFilterEffect.m
//  IJSVG
//
//  Created by Curtis Hard on 18/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterEffect.h>
#import <IJSVG/IJSVGFilterGraph.h>
#import <IJSVG/IJSVGFilterEffectGaussianBlur.h>
#import <IJSVG/IJSVGFilterEffectFlood.h>
#import <IJSVG/IJSVGFilterEffectOffset.h>
#import <IJSVG/IJSVGFilterEffectComposite.h>
#import <IJSVG/IJSVGFilterEffectMerge.h>
#import <IJSVG/IJSVGFilterEffectColorMatrix.h>
#import <IJSVG/IJSVGFilterEffectBlend.h>
#import <IJSVG/IJSVGFilterEffectTurbulence.h>
#import <IJSVG/IJSVGFilterEffectDisplacementMap.h>
#import <IJSVG/IJSVGFilterEffectLighting.h>
#import <IJSVG/IJSVGUtils.h>

@implementation IJSVGFilterEffect

static NSDictionary<NSString*, Class>* _elementClassMap = nil;

+ (void)load
{
    _elementClassMap = @{
        @"fegaussianblur": IJSVGFilterEffectGaussianBlur.class,
        @"feflood": IJSVGFilterEffectFlood.class,
        @"feoffset": IJSVGFilterEffectOffset.class,
        @"fecomposite": IJSVGFilterEffectComposite.class,
        @"femerge": IJSVGFilterEffectMerge.class,
        @"femergenode": IJSVGFilterEffectMerge.class,
        @"fecolormatrix": IJSVGFilterEffectColorMatrix.class,
        @"feblend": IJSVGFilterEffectBlend.class,
        @"feturbulence": IJSVGFilterEffectTurbulence.class,
        @"fedisplacementmap": IJSVGFilterEffectDisplacementMap.class,
        @"fespecularlighting": IJSVGFilterEffectSpecularLighting.class,
        @"fediffuselighting": IJSVGFilterEffectDiffuseLighting.class,
    };
}

+ (Class)effectClassForElementName:(NSString*)name
{
    NSString* key = name.lowercaseString;
    return _elementClassMap[key] ?: IJSVGFilterEffect.class;
}

+ (BOOL)isElementNameSupported:(NSString*)name
{
    NSString* key = name.lowercaseString;
    return _elementClassMap[key] != nil;
}

+ (IJSVGFilterEffectSource)sourceForString:(NSString*)string
{
    const char* name = string.UTF8String;
    if(name == NULL) return IJSVGFilterEffectSourceGraphic;
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "sourcegraphic") == YES) return IJSVGFilterEffectSourceGraphic;
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "sourcealpha") == YES) return IJSVGFilterEffectSourceAlpha;
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "backgroundimage") == YES) return IJSVGFilterEffectSourceBackgroundImage;
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "backgroundalpha") == YES) return IJSVGFilterEffectSourceBackgroundAlpha;
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "fillpaint") == YES) return IJSVGFilterEffectSourceFillPaint;
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "strokepaint") == YES) return IJSVGFilterEffectSourceStrokePaint;
    return IJSVGFilterEffectSourcePrimitiveReference;
}

+ (IJSVGFilterEffectEdgeMode)edgeModeForString:(NSString*)string
{
    const char* name = string.lowercaseString.UTF8String;
    if(name == NULL) return IJSVGFilterEffectEdgeModeNone;
    if(IJSVGCharBufferCompare(name, "none") == YES) return IJSVGFilterEffectEdgeModeNone;
    if(IJSVGCharBufferCompare(name, "wrap") == YES) return IJSVGFilterEffectEdgeModeWrap;
    if(IJSVGCharBufferCompare(name, "duplicate") == YES) return IJSVGFilterEffectEdgeModeDuplicate;
    return IJSVGFilterEffectEdgeModeNone;
}

- (void)parseEffectAttributes:(NSDictionary<NSString*, NSString*>*)attributes
{
    // Subclasses override
}

- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph
{
    CIImage* input = [graph imageForInput:self.inputName];
    CIImage* output = [self processImage:input];
    [graph setImage:output forResult:self.resultName];
    return output;
}

- (CIImage*)processImage:(CIImage*)image
{
    return image;
}

@end
