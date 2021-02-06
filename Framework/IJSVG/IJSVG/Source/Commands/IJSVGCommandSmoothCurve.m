//
//  IJSVGCommandSmoothCurve.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandCurve.h"
#import "IJSVGCommandSmoothCurve.h"
#import "IJSVGUtils.h"

@implementation IJSVGCommandSmoothCurve

+ (NSInteger)requiredParameterCount
{
    return 4;
}

+ (void)runWithParams:(CGFloat*)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand*)currentCommand
      previousCommand:(IJSVGCommand*)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath*)path
{
    CGPoint currentPoint = path.currentPoint;
    CGPoint firstControl = CGPointMake(currentPoint.x, currentPoint.y);
    if (command != nil) {
        if (command.class == [IJSVGCommandCurve class] || command.class == self.class) {
            if (command.class == [IJSVGCommandCurve class]) {
                if (command.type == kIJSVGCommandTypeAbsolute) {
                    firstControl = CGPointMake(-1 * command.parameters[2] + 2 * currentPoint.x,
                        -1 * command.parameters[3] + 2 * currentPoint.y);
                } else {
                    NSPoint oldPoint = CGPointMake(currentPoint.x - command.parameters[4],
                        currentPoint.y - command.parameters[5]);
                    firstControl = CGPointMake(-1 * (command.parameters[2] + oldPoint.x) + 2 * currentPoint.x,
                        -1 * (command.parameters[3] + oldPoint.y) + 2 * currentPoint.y);
                }
            } else {
                if (command.type == kIJSVGCommandTypeAbsolute) {
                    firstControl = CGPointMake(-1 * command.parameters[0] + 2 * currentPoint.x,
                        -1 * command.parameters[1] + 2 * currentPoint.y);
                } else {
                    NSPoint oldPoint = CGPointMake(currentPoint.x - command.parameters[2],
                        currentPoint.y - command.parameters[3]);
                    firstControl = CGPointMake(-1 * (command.parameters[0] + oldPoint.x) + 2 * currentPoint.x,
                        -1 * (command.parameters[1] + oldPoint.y) + 2 * currentPoint.y);
                }
            }
        }
    }
    if (type == kIJSVGCommandTypeAbsolute) {
        CGPathAddCurveToPoint(path.path, NULL, firstControl.x, firstControl.y,
                              params[0], params[1], params[2], params[3]);
        return;
    }
    CGPathAddCurveToPoint(path.path, NULL, firstControl.x, firstControl.y,
                          currentPoint.x + params[0], currentPoint.y + params[1],
                          currentPoint.x + params[2], currentPoint.y + params[3]);
}

@end
