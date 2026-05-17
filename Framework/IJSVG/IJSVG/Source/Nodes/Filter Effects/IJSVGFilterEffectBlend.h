//
//  IJSVGFilterEffectBlend.h
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffect.h>

typedef NS_ENUM(NSInteger, IJSVGFilterBlendMode) {
    IJSVGFilterBlendModeNormal,
    IJSVGFilterBlendModeMultiply,
    IJSVGFilterBlendModeScreen,
    IJSVGFilterBlendModeDarken,
    IJSVGFilterBlendModeLighten,
    IJSVGFilterBlendModeOverlay,
};

@interface IJSVGFilterEffectBlend : IJSVGFilterEffect

@property (nonatomic, assign) IJSVGFilterBlendMode filterBlendMode;

@end
