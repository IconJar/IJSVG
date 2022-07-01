//
//  IJSVGCommandCommandQuadraticCurve.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGCommandQuadraticCurve.h>
#import <IJSVG/IJSVGCommandSmoothQuadraticCurve.h>
#import <IJSVG/IJSVGUtils.h>

@implementation IJSVGCommandSmoothQuadraticCurve

+ (NSInteger)requiredParameterCount
{
    return 2;
}

+ (void)runWithParams:(CGFloat*)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand*)currentCommand
      previousCommand:(IJSVGCommand*)command
                 type:(IJSVGCommandType)type
                 path:(CGMutablePathRef)path
{
    CGPoint lastControlPoint = IJSVGPathGetLastQuadraticCommandPoint(path);
    CGPoint currentPoint = CGPathGetCurrentPoint(path);
    CGPoint commandPoint = CGPointMake(currentPoint.x, currentPoint.y);
    if(command != nil) {
        if(command.class == IJSVGCommandQuadraticCurve.class) {
            // quadratic curve
            if(command.type == kIJSVGCommandTypeAbsolute) {
                commandPoint = NSMakePoint(-1 * command.parameters[0] + 2 * currentPoint.x,
                    -1 * command.parameters[1] + 2 * currentPoint.y);
            } else {
                CGPoint oldPoint = CGPointMake(currentPoint.x - command.parameters[2],
                    currentPoint.y - command.parameters[3]);
                commandPoint = CGPointMake(-1 * (command.parameters[0] + oldPoint.x) + 2 * (currentPoint.x),
                    -1 * (command.parameters[1] + oldPoint.y) + 2 * currentPoint.y);
            }
        } else if(command.class == self.class) {
            // smooth quadratic curve
            commandPoint = CGPointMake(-1 * (lastControlPoint.x) + 2 * (currentPoint.x),
                -1 * (lastControlPoint.y) + 2 * currentPoint.y);
        }
    }
//    path.lastControlPoint = commandPoint;
    if(type == kIJSVGCommandTypeAbsolute) {
        CGPathAddQuadCurveToPoint(path, NULL, commandPoint.x, commandPoint.y,
                                  params[0], params[1]);
        return;
    }
    CGPathAddQuadCurveToPoint(path, NULL, commandPoint.x, commandPoint.y,
                              currentPoint.x + params[0], currentPoint.y + params[1]);
}

@end
