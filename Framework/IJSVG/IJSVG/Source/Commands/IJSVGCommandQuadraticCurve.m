//
//  IJSVGCommandQuadraticCurve.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGCommandQuadraticCurve.h>
#import <IJSVG/IJSVGUtils.h>

@implementation IJSVGCommandQuadraticCurve

+ (NSInteger)requiredParameterCount
{
    return 4;
}

+ (void)runWithParams:(CGFloat*)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand*)currentCommand
      previousCommand:(IJSVGCommand*)command
                 type:(IJSVGCommandType)type
                 path:(CGMutablePathRef)path
{
    if(type == kIJSVGCommandTypeAbsolute) {
        CGPathAddQuadCurveToPoint(path, NULL, params[0], params[1],
                                  params[2], params[3]);
        return;
    }
    CGPoint currentPoint = CGPathGetCurrentPoint(path);
    CGPathAddQuadCurveToPoint(path, NULL,
                              currentPoint.x + params[0], currentPoint.y + params[1],
                              currentPoint.x + params[2], currentPoint.y + params[3]);
}

@end
