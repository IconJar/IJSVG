//
//  IJSVGFilterEffect.m
//  IJSVG
//
//  Created by Curtis Hard on 18/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGFilterEffect.h"
#import "IJSVGFilterEffectGaussianBlur.h"

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
    const char* name = string.lowercaseString.UTF8String;
    if(name == NULL) {
        return IJSVGFilterEffectSourceGraphic;
    }
    if(strcmp(name, "sourcegraphic") == 0) {
        return IJSVGFilterEffectSourceGraphic;
    }
    if(strcmp(name, "sourcealpha") == 0) {
        return IJSVGFilterEffectSourceAlpha;
    }
    if(strcmp(name, "backgroundimage") == 0) {
        return IJSVGFilterEffectSourceBackgroundImage;
    }
    if(strcmp(name, "backgroundalpha") == 0) {
        return IJSVGFilterEffectSourceBackgroundAlpha;
    }
    if(strcmp(name, "fillpaint") == 0) {
        return IJSVGFilterEffectSourceFillPaint;
    }
    if(strcmp(name, "strokepain") == 0) {
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
    if(strcmp(name, "none") == 0) {
        return IJSVGFilterEffectEdgeModeNone;
    }
    if(strcmp(name, "wrap") == 0) {
        return IJSVGFilterEffectEdgeModeWrap;
    }
    if(strcmp(name, "duplicate") == 0) {
        return IJSVGFilterEffectEdgeModeDuplicate;
    }
    return IJSVGFilterEffectEdgeModeNone;
}

- (CIImage*)processImage:(CIImage*)image
{
    return image;
}

@end
