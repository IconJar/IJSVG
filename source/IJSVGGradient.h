//
//  IJSVGGradient.h
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGDef.h"
#import "IJSVGTransform.h"

@interface IJSVGGradient : IJSVGNode

@property ( nonatomic, retain ) NSGradient * gradient;
@property ( nonatomic, assign ) CGFloat angle;
@property ( nonatomic, assign ) CGPoint startPoint;
@property ( nonatomic, assign ) CGPoint endPoint;
@property ( nonatomic, assign ) CGGradientRef CGGradient;
@property ( nonatomic, retain ) IJSVGUnitLength * x1;
@property ( nonatomic, retain ) IJSVGUnitLength * x2;
@property ( nonatomic, retain ) IJSVGUnitLength * y1;
@property ( nonatomic, retain ) IJSVGUnitLength * y2;

+ (CGFloat *)computeColorStopsFromString:(NSXMLElement *)element
                                  colors:(NSArray **)someColors;
- (CGGradientRef)CGGradient;
- (void)drawInContextRef:(CGContextRef)ctx
                    rect:(NSRect)rect;

@end
