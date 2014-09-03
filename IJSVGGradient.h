//
//  IJSVGGradient.h
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGDef.h"

@interface IJSVGGradient : IJSVGDef {
    
    NSGradient * gradient;
    CGFloat angle;
    
}

@property ( nonatomic, retain ) NSGradient * gradient;
@property ( nonatomic, assign ) CGFloat angle;

+ (CGFloat *)computeColorStopsFromString:(NSXMLElement *)element
                                  colors:(NSArray **)someColors;

@end
