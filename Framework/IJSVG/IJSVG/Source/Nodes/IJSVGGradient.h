//
//  IJSVGGradient.h
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGColorList.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGGroup.h>

@interface IJSVGGradient : IJSVGGroup

@property (nonatomic, strong) NSArray<NSColor*>* colors;
@property (nonatomic, assign) CGFloat* locations;
@property (nonatomic, assign) NSUInteger numberOfStops;
@property (nonatomic, assign) CGGradientRef CGGradient;
@property (nonatomic, strong) IJSVGUnitLength* x1;
@property (nonatomic, strong) IJSVGUnitLength* x2;
@property (nonatomic, strong) IJSVGUnitLength* y1;
@property (nonatomic, strong) IJSVGUnitLength* y2;
@property (nonatomic, strong) IJSVGColorList* colorList;

+ (CGFloat*)computeColorStops:(IJSVGGradient*)gradient
                       colors:(NSArray**)someColors;

- (CGGradientRef)CGGradient;
- (void)drawInContextRef:(CGContextRef)ctx
              objectRect:(NSRect)objectRect
       absoluteTransform:(CGAffineTransform)absoluteTransform
                viewPort:(CGRect)viewBox;

- (IJSVGColorList*)colorList;
- (IJSVGColorList*)computedColorList;

@end
