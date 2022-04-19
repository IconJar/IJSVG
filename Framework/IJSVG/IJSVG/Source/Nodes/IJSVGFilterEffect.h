//
//  IJSVGFilterEffect.h
//  IJSVG
//
//  Created by Curtis Hard on 18/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>

typedef NS_ENUM(NSInteger, IJSVGFilterEffectSource) {
    IJSVGFilterEffectSourceGraphic,
    IJSVGFilterEffectSourceAlpha,
    IJSVGFilterEffectSourceBackgroundImage,
    IJSVGFilterEffectSourceBackgroundAlpha,
    IJSVGFilterEffectSourceFillPaint,
    IJSVGFilterEffectSourceStrokePaint,
    IJSVGFilterEffectSourcePrimitiveReference,
};

typedef NS_ENUM(NSInteger, IJSVGFilterEffectEdgeMode) {
    IJSVGFilterEffectEdgeModeNone,
    IJSVGFilterEffectEdgeModeWrap,
    IJSVGFilterEffectEdgeModeDuplicate,
};

@interface IJSVGFilterEffect : IJSVGGroup

@property (nonatomic, assign) IJSVGFilterEffectSource source;
@property (nonatomic, retain) IJSVGUnitLength* stdDeviation;
@property (nonatomic, assign) IJSVGFilterEffectEdgeMode edgeMode;
@property (nonatomic, copy) NSString* primitiveReference;

+ (Class)effectClassForElementName:(NSString*)name;
+ (IJSVGFilterEffectSource)sourceForString:(NSString*)string;
+ (IJSVGFilterEffectEdgeMode)edgeModeForString:(NSString*)string;

- (CIImage*)processImage:(CIImage*)image;

@end
