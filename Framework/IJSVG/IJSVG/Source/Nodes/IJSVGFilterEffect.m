//
//  IJSVGFilterEffect.m
//  IJSVG
//
//  Created by Curtis Hard on 18/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterEffect.h>
#import <IJSVG/IJSVGFilterEffectGaussianBlur.h>
#import <IJSVG/IJSVGUtils.h>

@implementation IJSVGFilterEffect

static NSDictionary<NSString*, Class>* _elementClassMap = nil;

+ (void)load
{
    _elementClassMap = @{
        @"fegaussianblur": IJSVGFilterEffectGaussianBlur.class
    };
}

+ (Class)effectClassForElementName:(NSString*)name
{
    NSString* key = name.lowercaseString;
    return _elementClassMap[key] ?: IJSVGFilterEffect.class;
}

+ (IJSVGFilterEffectSource)sourceForString:(NSString*)string
{
    const char* name = string.UTF8String;
    if(name == NULL) {
        return IJSVGFilterEffectSourceGraphic;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "sourcegraphic") == YES) {
        return IJSVGFilterEffectSourceGraphic;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "sourcealpha") == YES) {
        return IJSVGFilterEffectSourceAlpha;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "backgroundimage") == YES) {
        return IJSVGFilterEffectSourceBackgroundImage;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "backgroundalpha") == YES) {
        return IJSVGFilterEffectSourceBackgroundAlpha;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "fillpaint") == YES) {
        return IJSVGFilterEffectSourceFillPaint;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "strokepain") == YES) {
        return IJSVGFilterEffectSourceStrokePaint;
    }
    return IJSVGFilterEffectSourcePrimitiveReference;
}

+ (IJSVGFilterEffectEdgeMode)edgeModeForString:(NSString*)string
{
    const char* name = string.lowercaseString.UTF8String;
    if(name == NULL) {
        return IJSVGFilterEffectEdgeModeNone;
    }
    if(IJSVGCharBufferCompare(name, "none") == YES) {
        return IJSVGFilterEffectEdgeModeNone;
    }
    if(IJSVGCharBufferCompare(name, "wrap") == YES) {
        return IJSVGFilterEffectEdgeModeWrap;
    }
    if(IJSVGCharBufferCompare(name, "duplicate") == YES) {
        return IJSVGFilterEffectEdgeModeDuplicate;
    }
    return IJSVGFilterEffectEdgeModeNone;
}

- (CIImage*)processImage:(CIImage*)image
{
    return image;
}

@end
