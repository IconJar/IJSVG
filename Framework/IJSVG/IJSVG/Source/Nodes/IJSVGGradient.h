//
//  IJSVGGradient.h
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColorList.h>
#import <IJSVG/IJSVGDef.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGGroup.h>
#import <Foundation/Foundation.h>

@interface IJSVGGradient : IJSVGGroup

@property (nonatomic, retain) NSGradient* gradient;
@property (nonatomic, assign) CGGradientRef CGGradient;
@property (nonatomic, retain) IJSVGUnitLength* x1;
@property (nonatomic, retain) IJSVGUnitLength* x2;
@property (nonatomic, retain) IJSVGUnitLength* y1;
@property (nonatomic, retain) IJSVGUnitLength* y2;
@property (nonatomic, retain) IJSVGColorList* colorList;

+ (CGFloat*)computeColorStops:(IJSVGGradient*)gradient
                       colors:(NSArray**)someColors;

- (CGGradientRef)CGGradient;
- (void)drawInContextRef:(CGContextRef)ctx
              objectRect:(NSRect)objectRect
       absoluteTransform:(CGAffineTransform)absoluteTransform
                viewPort:(CGRect)viewBox;

- (void)_debugStart:(CGPoint)startPoint
                end:(CGPoint)endPoint
            context:(CGContextRef)ctx;

- (IJSVGColorList*)colorList;
- (IJSVGColorList*)computedColorList;

@end
