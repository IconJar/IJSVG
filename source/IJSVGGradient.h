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

@interface IJSVGGradient : IJSVGDef {
    
    NSGradient * gradient;
    CGGradientRef CGGradient;
    CGFloat angle;
    CGPoint startPoint;
    CGPoint endPoint;
    
    IJSVGUnit x1;
    IJSVGUnit x2;
    IJSVGUnit y1;
    IJSVGUnit y2;
    
}

@property ( nonatomic, retain ) NSGradient * gradient;
@property ( nonatomic, assign ) CGFloat angle;
@property ( nonatomic, assign ) CGPoint startPoint;
@property ( nonatomic, assign ) CGPoint endPoint;
@property ( nonatomic, assign ) CGGradientRef CGGradient;
@property ( nonatomic, assign ) IJSVGUnit x1;
@property ( nonatomic, assign ) IJSVGUnit x2;
@property ( nonatomic, assign ) IJSVGUnit y1;
@property ( nonatomic, assign ) IJSVGUnit y2;

+ (CGFloat *)computeColorStopsFromString:(NSXMLElement *)element
                                  colors:(NSArray **)someColors;
- (CGGradientRef)CGGradient;
- (void)drawInContextRef:(CGContextRef)ctx
                    path:(IJSVGPath *)path;

@end
