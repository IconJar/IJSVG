//
//  IJSVGFilterEffectColorMatrix.h
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffect.h>

typedef NS_ENUM(NSInteger, IJSVGColorMatrixType) {
    IJSVGColorMatrixTypeMatrix,
    IJSVGColorMatrixTypeSaturate,
    IJSVGColorMatrixTypeHueRotate,
    IJSVGColorMatrixTypeLuminanceToAlpha,
};

@interface IJSVGFilterEffectColorMatrix : IJSVGFilterEffect

@property (nonatomic, assign) IJSVGColorMatrixType matrixType;
@property (nonatomic, strong) NSArray<NSNumber*>* matrixValues;

@end
