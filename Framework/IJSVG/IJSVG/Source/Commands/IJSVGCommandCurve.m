//
//  IJSVGCommandCurve.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandCurve.h"

@implementation IJSVGCommandCurve

+ (NSInteger)requiredParameterCount
{
    return 6;
}

+ (void)runWithParams:(CGFloat*)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand*)currentCommand
      previousCommand:(IJSVGCommand*)command
                 type:(IJSVGCommandType)type
                 path:(CGMutablePathRef)path
{
    if (type == kIJSVGCommandTypeAbsolute) {
        CGPathAddCurveToPoint(path, NULL, params[0], params[1],
                              params[2], params[3],
                              params[4], params[5]);
        return;
    }
    CGPoint currentPoint = CGPathGetCurrentPoint(path);
    CGPathAddCurveToPoint(path, NULL,
                          currentPoint.x + params[0], currentPoint.y + params[1],
                          currentPoint.x + params[2], currentPoint.y + params[3],
                          currentPoint.x + params[4], currentPoint.y + params[5]);
}

@end
