//
//  IJSVGRadialGradient.h
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGGradient.h"

@interface IJSVGRadialGradient : IJSVGGradient {
 
    CGFloat cx;
    CGFloat cy;
    CGFloat fx;
    CGFloat fy;
    CGFloat radius;
    
}

@property ( nonatomic, assign ) CGFloat cx;
@property ( nonatomic, assign ) CGFloat cy;
@property ( nonatomic, assign ) CGFloat fx;
@property ( nonatomic, assign ) CGFloat fy;
@property ( nonatomic, assign ) CGFloat radius;

+ (NSGradient *)parseGradient:(NSXMLElement *)element
                     gradient:(IJSVGRadialGradient *)gradient
                   startPoint:(CGPoint *)startPoint
                     endPoint:(CGPoint *)endPoint;

@end
