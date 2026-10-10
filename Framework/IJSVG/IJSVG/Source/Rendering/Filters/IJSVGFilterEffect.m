//
//  IJSVGFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterEffect.h>
#import <IJSVGBlendFilterEffect.h>
#import <IJSVGColorMatrixFilterEffect.h>
#import <IJSVGComponentTransferFilterEffect.h>
#import <IJSVGCompositeFilterEffect.h>
#import <IJSVGConvolveMatrixFilterEffect.h>
#import <IJSVGDisplacementMapFilterEffect.h>
#import <IJSVGMorphologyFilterEffect.h>
#import <IJSVGTileFilterEffect.h>
#import <IJSVGFloodFilterEffect.h>
#import <IJSVGOffsetFilterEffect.h>
#import <IJSVGImageFilterEffect.h>
#import <IJSVGMergeFilterEffect.h>
#import <IJSVGGaussianBlurFilterEffect.h>
#import <IJSVGDropShadowFilterEffect.h>
#import <IJSVGTurbulenceFilterEffect.h>
#import <IJSVGDiffuseLightingFilterEffect.h>
#import <IJSVGSpecularLightingFilterEffect.h>

@implementation IJSVGFilterEffect

+ (NSDictionary<NSNumber*, IJSVGFilterEffect*>*)registeredEffects
{
    return @{
        @(IJSVGNodeTypeFilterBlend): [[IJSVGBlendFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterColorMatrix): [[IJSVGColorMatrixFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterComponentTransfer): [[IJSVGComponentTransferFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterComposite): [[IJSVGCompositeFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterConvolveMatrix): [[IJSVGConvolveMatrixFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterDisplacementMap): [[IJSVGDisplacementMapFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterMorphology): [[IJSVGMorphologyFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterTile): [[IJSVGTileFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterFlood): [[IJSVGFloodFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterOffset): [[IJSVGOffsetFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterImage): [[IJSVGImageFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterMerge): [[IJSVGMergeFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterGaussianBlur): [[IJSVGGaussianBlurFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterDropShadow): [[IJSVGDropShadowFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterTurbulence): [[IJSVGTurbulenceFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterDiffuseLighting): [[IJSVGDiffuseLightingFilterEffect alloc] init],
        @(IJSVGNodeTypeFilterSpecularLighting): [[IJSVGSpecularLightingFilterEffect alloc] init]
    };
}

+ (instancetype)effectForType:(IJSVGNodeType)type
{
    // Create one shared instance of each effect. Render data stays in the context.
    static NSDictionary<NSNumber*, IJSVGFilterEffect*>* effects;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        effects = [self registeredEffects];
    });
    return (id)effects[@(type)];
}

- (BOOL)requiresSupersamplingForPrimitive:(IJSVGFilterPrimitive*)primitive
{
    return NO;
}

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    return CIImage.emptyImage;
}

@end
