//
//  IJSVGFilterEffectLighting.h
//  IJSVG
//
//  Shared base for feSpecularLighting and feDiffuseLighting.
//

#import <IJSVG/IJSVGFilterEffect.h>

typedef NS_ENUM(NSInteger, IJSVGLightType) {
    IJSVGLightTypeDistant,
    IJSVGLightTypePoint,
    IJSVGLightTypeSpot,
};

@interface IJSVGFilterEffectLighting : IJSVGFilterEffect

@property (nonatomic, assign) CGFloat surfaceScale;
@property (nonatomic, assign) CGFloat lightColorR;
@property (nonatomic, assign) CGFloat lightColorG;
@property (nonatomic, assign) CGFloat lightColorB;

// Light source
@property (nonatomic, assign) IJSVGLightType lightType;

// Point / spot light
@property (nonatomic, assign) CGFloat lightX;
@property (nonatomic, assign) CGFloat lightY;
@property (nonatomic, assign) CGFloat lightZ;

// Spot light target
@property (nonatomic, assign) CGFloat pointsAtX;
@property (nonatomic, assign) CGFloat pointsAtY;
@property (nonatomic, assign) CGFloat pointsAtZ;
@property (nonatomic, assign) CGFloat spotExponent;
@property (nonatomic, assign) CGFloat limitingConeAngle;

// Distant light
@property (nonatomic, assign) CGFloat azimuth;
@property (nonatomic, assign) CGFloat elevation;

// Helpers for subclasses
- (uint8_t*)renderInputToBitmapWithGraph:(id)graph
                                   width:(NSInteger*)outW
                                  height:(NSInteger*)outH;
- (void)computeNormalAtX:(NSInteger)x y:(NSInteger)y
                   pixels:(const uint8_t*)pixels
                    width:(NSInteger)w height:(NSInteger)h
                    scale:(CGFloat)scale
                       nx:(CGFloat*)nx ny:(CGFloat*)ny nz:(CGFloat*)nz;
- (void)lightDirectionAtSvgX:(CGFloat)sx svgY:(CGFloat)sy
                    surfaceZ:(CGFloat)sz
                          lx:(CGFloat*)lx ly:(CGFloat*)ly lz:(CGFloat*)lz;
- (void)parseLightSourceElement:(NSString*)elementName
                     attributes:(NSDictionary<NSString*, NSString*>*)attributes;

@end


@interface IJSVGFilterEffectSpecularLighting : IJSVGFilterEffectLighting

@property (nonatomic, assign) CGFloat specularConstant;
@property (nonatomic, assign) CGFloat specularExponent;

@end


@interface IJSVGFilterEffectDiffuseLighting : IJSVGFilterEffectLighting

@property (nonatomic, assign) CGFloat diffuseConstant;

@end
