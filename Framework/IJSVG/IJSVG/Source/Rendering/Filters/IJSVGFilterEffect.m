//
//  IJSVGFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterEffect.h>
#import <IJSVG/IJSVGBlendFilterEffect.h>
#import <IJSVG/IJSVGColorMatrixFilterEffect.h>
#import <IJSVG/IJSVGComponentTransferFilterEffect.h>
#import <IJSVG/IJSVGCompositeFilterEffect.h>
#import <IJSVG/IJSVGConvolveMatrixFilterEffect.h>
#import <IJSVG/IJSVGDisplacementMapFilterEffect.h>
#import <IJSVG/IJSVGMorphologyFilterEffect.h>
#import <IJSVG/IJSVGTileFilterEffect.h>
#import <IJSVG/IJSVGFloodFilterEffect.h>
#import <IJSVG/IJSVGOffsetFilterEffect.h>
#import <IJSVG/IJSVGImageFilterEffect.h>
#import <IJSVG/IJSVGMergeFilterEffect.h>
#import <IJSVG/IJSVGGaussianBlurFilterEffect.h>
#import <IJSVG/IJSVGDropShadowFilterEffect.h>
#import <IJSVG/IJSVGTurbulenceFilterEffect.h>
#import <IJSVG/IJSVGDiffuseLightingFilterEffect.h>
#import <IJSVG/IJSVGSpecularLightingFilterEffect.h>

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
