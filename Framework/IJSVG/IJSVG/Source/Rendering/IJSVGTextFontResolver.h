//
//  IJSVGTextFontResolver.h
//  IJSVG
//
//  Created by Curtis Hard on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRendering.h>
#import <IJSVG/IJSVGText.h>
#import <IJSVG/IJSVGUnitSize.h>
#import <IJSVGTextLayoutUtils.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGTextFontResolver : NSObject

@property (nonatomic, assign) CGFloat renderScale;
@property (nonatomic, assign) CGFloat defaultFontSize;

- (instancetype)initWithRenderingOptions:(nullable IJSVGRenderingOptions*)options;
- (CGFloat)resolveLength:(nullable IJSVGUnitLength*)length percentage:(CGFloat)percentage node:(IJSVGGraphicsNode*)node;
- (CGFloat)resolveCSSLength:(nullable IJSVGUnitLength*)length percentage:(CGFloat)percentage node:(IJSVGGraphicsNode*)node;
- (CGSize)resolveSize:(IJSVGUnitSize*)size percentage:(CGSize)percentage node:(IJSVGGraphicsNode*)node;
- (nullable IJSVGUnitRect*)rectByResolvingFontLengths:(nullable IJSVGUnitRect*)rect node:(IJSVGGraphicsNode*)node;
- (nullable IJSVGUnitLength*)unitByResolvingFontLength:(nullable IJSVGUnitLength*)length node:(IJSVGGraphicsNode*)node;

- (nullable IJSVGUnitLength*)unitByResolvingFontLength:(nullable IJSVGUnitLength*)length node:(IJSVGGraphicsNode*)node css:(BOOL)css;

- (nullable IJSVGTextComputedStyle*)fontStyleForNode:(nullable IJSVGNode*)node;
- (IJSVGTextComputedStyle*)fontStyleForNode:(IJSVGNode*)node parentStyle:(nullable IJSVGTextComputedStyle*)parent;

- (BOOL)usesNativeSpacingForFont:(id)font;

- (id)fontForValues:(NSDictionary<NSString*, IJSVGTextAttributeValue*>*)values size:(CGFloat)size;

@end

NS_ASSUME_NONNULL_END
