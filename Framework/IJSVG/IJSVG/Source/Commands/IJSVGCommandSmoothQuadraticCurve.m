//
//  IJSVGCommandCommandQuadraticCurve.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandQuadraticCurve.h"
#import "IJSVGCommandSmoothQuadraticCurve.h"
#import "IJSVGUtils.h"

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
                 path:(IJSVGPath*)path
{
    NSPoint commandPoint = NSMakePoint(path.currentPoint.x, path.currentPoint.y);
    if (command != nil) {
        if (command.class == IJSVGCommandQuadraticCurve.class) {
            // quadratic curve
            if (command.type == kIJSVGCommandTypeAbsolute) {
                commandPoint = NSMakePoint(-1 * command.parameters[0] + 2 * path.currentPoint.x,
                    -1 * command.parameters[1] + 2 * path.currentPoint.y);
            } else {
                NSPoint oldPoint = CGPointMake(path.currentPoint.x - command.parameters[2],
                    path.currentPoint.y - command.parameters[3]);
                commandPoint = CGPointMake(-1 * (command.parameters[0] + oldPoint.x) + 2 * (path.currentPoint.x),
                    -1 * (command.parameters[1] + oldPoint.y) + 2 * path.currentPoint.y);
            }
        } else if (command.class == self.class) {
            // smooth quadratic curve
            commandPoint = CGPointMake(-1 * (path.lastControlPoint.x) + 2 * (path.currentPoint.x),
                -1 * (path.lastControlPoint.y) + 2 * path.currentPoint.y);
        }
    }
    path.lastControlPoint = commandPoint;
    if (type == kIJSVGCommandTypeAbsolute) {
        [path.path addQuadCurveToPoint:NSMakePoint(params[0], params[1])
                          controlPoint:commandPoint];
        return;
    }
    [path.path addQuadCurveToPoint:NSMakePoint(path.currentPoint.x + params[0], path.currentPoint.y + params[1])
                      controlPoint:commandPoint];
}

@end
