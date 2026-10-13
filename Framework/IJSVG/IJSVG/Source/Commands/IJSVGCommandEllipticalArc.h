//
//  IJSVGCommandEllipticalArc.h
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGCommand.h>

void IJSVGPathAddEllipticalArc(CGMutablePathRef path, const CGFloat* params, BOOL relative);

@interface IJSVGCommandEllipticalArc : IJSVGCommand

@end
