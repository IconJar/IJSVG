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

@property (nonatomic, strong) IJSVGUnitLength* cx;
@property (nonatomic, strong) IJSVGUnitLength* cy;
@property (nonatomic, strong) IJSVGUnitLength* fx;
@property (nonatomic, strong) IJSVGUnitLength* fy;
@property (nonatomic, strong) IJSVGUnitLength* fr;
@property (nonatomic, strong) IJSVGUnitLength* r;

+ (void)parseGradient:(NSXMLElement*)element
             gradient:(IJSVGRadialGradient*)gradient;

@end
