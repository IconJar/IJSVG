//
//  IJSVGRadialGradient.h
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradient.h>
#import <Foundation/Foundation.h>

@interface IJSVGRadialGradient : IJSVGGradient

@property (nonatomic, retain) IJSVGUnitLength* cx;
@property (nonatomic, retain) IJSVGUnitLength* cy;
@property (nonatomic, retain) IJSVGUnitLength* fx;
@property (nonatomic, retain) IJSVGUnitLength* fy;
@property (nonatomic, retain) IJSVGUnitLength* fr;
@property (nonatomic, retain) IJSVGUnitLength* r;

+ (NSGradient*)parseGradient:(NSXMLElement*)element
                    gradient:(IJSVGRadialGradient*)gradient;

@end
