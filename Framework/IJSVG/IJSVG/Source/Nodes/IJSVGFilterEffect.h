//
//  IJSVGFilterEffect.h
//  IJSVG
//
//  Created by Curtis Hard on 18/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>

@class IJSVGFilterGraph;

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
@property (nonatomic, strong) IJSVGUnitLength* stdDeviation;
@property (nonatomic, assign) IJSVGFilterEffectEdgeMode edgeMode;
@property (nonatomic, copy) NSString* primitiveReference;

// Graph-based input/output routing
@property (nonatomic, copy) NSString* inputName;   // "in" attribute
@property (nonatomic, copy) NSString* inputName2;  // "in2" attribute
@property (nonatomic, copy) NSString* resultName;  // "result" attribute

+ (Class)effectClassForElementName:(NSString*)name;
+ (BOOL)isElementNameSupported:(NSString*)name;
+ (IJSVGFilterEffectSource)sourceForString:(NSString*)string;
+ (IJSVGFilterEffectEdgeMode)edgeModeForString:(NSString*)string;

- (void)parseEffectAttributes:(NSDictionary<NSString*, NSString*>*)attributes;
- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph;
- (CIImage*)processImage:(CIImage*)image;

@end
