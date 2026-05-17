//
//  IJSVGFilterEffectFlood.h
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffect.h>

@interface IJSVGFilterEffectFlood : IJSVGFilterEffect

@property (nonatomic, strong) NSColor* floodColor;
@property (nonatomic, assign) CGFloat floodOpacity;

@end
