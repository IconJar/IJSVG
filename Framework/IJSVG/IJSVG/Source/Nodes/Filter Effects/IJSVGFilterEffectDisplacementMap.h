//
//  IJSVGFilterEffectDisplacementMap.h
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffect.h>

typedef NS_ENUM(NSInteger, IJSVGChannelSelector) {
    IJSVGChannelSelectorR = 0,
    IJSVGChannelSelectorG = 1,
    IJSVGChannelSelectorB = 2,
    IJSVGChannelSelectorA = 3,
};

@interface IJSVGFilterEffectDisplacementMap : IJSVGFilterEffect

@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign) IJSVGChannelSelector xChannelSelector;
@property (nonatomic, assign) IJSVGChannelSelector yChannelSelector;

@end
