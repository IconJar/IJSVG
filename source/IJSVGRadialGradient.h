//
//  IJSVGRadialGradient.h
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGGradient.h"

@interface IJSVGRadialGradient : IJSVGGradient

@property ( nonatomic, retain ) IJSVGUnitLength * cx;
@property ( nonatomic, retain ) IJSVGUnitLength * cy;
@property ( nonatomic, retain ) IJSVGUnitLength * fx;
@property ( nonatomic, retain ) IJSVGUnitLength * fy;
@property ( nonatomic, retain ) IJSVGUnitLength * radius;

+ (NSGradient *)parseGradient:(NSXMLElement *)element
                     gradient:(IJSVGRadialGradient *)gradient;

@end
