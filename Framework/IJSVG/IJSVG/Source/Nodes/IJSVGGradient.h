//
//  IJSVGGradient.h
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGTraitedColorStorage.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGGroup.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGGradient : IJSVGGroup

@property (nonatomic, strong, nullable) NSArray<NSColor*>* colors;
@property (nonatomic, assign, nullable) CGFloat* locations;
@property (nonatomic, assign) NSUInteger numberOfStops;
@property (nonatomic, assign, nullable) CGGradientRef CGGradient;
@property (nonatomic, strong, nullable) IJSVGUnitLength* x1;
@property (nonatomic, strong, nullable) IJSVGUnitLength* x2;
@property (nonatomic, strong, nullable) IJSVGUnitLength* y1;
@property (nonatomic, strong, nullable) IJSVGUnitLength* y2;

@property (nonatomic, readonly) NSArray<IJSVGNode*>* stops;

+ (CGFloat* _Nullable)computeColorStops:(IJSVGGradient*)gradient
                       colors:(NSArray* _Nonnull * _Nonnull)someColors;

- (CGGradientRef _Nullable)CGGradient CF_RETURNS_NOT_RETAINED;
- (void)drawInContextRef:(CGContextRef)ctx
                  bounds:(NSRect)objectRect
               transform:(CGAffineTransform)absoluteTransform;

@end

NS_ASSUME_NONNULL_END
