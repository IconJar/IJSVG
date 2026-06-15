//
//  IJSVGFilterEffectComposite.h
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffect.h>

typedef NS_ENUM(NSInteger, IJSVGFilterCompositeOperator) {
    IJSVGFilterCompositeOperatorOver,
    IJSVGFilterCompositeOperatorIn,
    IJSVGFilterCompositeOperatorOut,
    IJSVGFilterCompositeOperatorAtop,
    IJSVGFilterCompositeOperatorXor,
    IJSVGFilterCompositeOperatorLighter,
    IJSVGFilterCompositeOperatorArithmetic,
};

@interface IJSVGFilterEffectComposite : IJSVGFilterEffect

@property (nonatomic, assign) IJSVGFilterCompositeOperator compositeOperator;
@property (nonatomic, assign) CGFloat k1;
@property (nonatomic, assign) CGFloat k2;
@property (nonatomic, assign) CGFloat k3;
@property (nonatomic, assign) CGFloat k4;

@end
