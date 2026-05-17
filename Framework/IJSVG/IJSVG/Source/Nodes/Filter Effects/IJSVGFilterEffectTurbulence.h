//
//  IJSVGFilterEffectTurbulence.h
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffect.h>

typedef NS_ENUM(NSInteger, IJSVGTurbulenceType) {
    IJSVGTurbulenceTypeTurbulence,
    IJSVGTurbulenceTypeFractalNoise,
};

@interface IJSVGFilterEffectTurbulence : IJSVGFilterEffect

@property (nonatomic, assign) CGFloat baseFrequencyX;
@property (nonatomic, assign) CGFloat baseFrequencyY;
@property (nonatomic, assign) NSInteger numOctaves;
@property (nonatomic, assign) CGFloat seed;
@property (nonatomic, assign) IJSVGTurbulenceType turbulenceType;

@end
