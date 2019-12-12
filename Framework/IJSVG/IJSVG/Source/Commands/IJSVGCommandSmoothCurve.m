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
    NSPoint firstControl = NSMakePoint(path.currentPoint.x, path.currentPoint.y);
    if (command != nil) {
        if (command.class == [IJSVGCommandCurve class] || command.class == self.class) {
            if (command.class == [IJSVGCommandCurve class]) {
                if (command.type == kIJSVGCommandTypeAbsolute) {
                    firstControl = NSMakePoint(-1 * command.parameters[2] + 2 * path.currentPoint.x,
                        -1 * command.parameters[3] + 2 * path.currentPoint.y);
                } else {
                    NSPoint oldPoint = NSMakePoint(path.currentPoint.x - command.parameters[4],
                        path.currentPoint.y - command.parameters[5]);
                    firstControl = NSMakePoint(-1 * (command.parameters[2] + oldPoint.x) + 2 * path.currentPoint.x,
                        -1 * (command.parameters[3] + oldPoint.y) + 2 * path.currentPoint.y);
                }
            } else {
                if (command.type == kIJSVGCommandTypeAbsolute) {
                    firstControl = NSMakePoint(-1 * command.parameters[0] + 2 * path.currentPoint.x,
                        -1 * command.parameters[1] + 2 * path.currentPoint.y);
                } else {
                    NSPoint oldPoint = NSMakePoint(path.currentPoint.x - command.parameters[2],
                        path.currentPoint.y - command.parameters[3]);
                    firstControl = NSMakePoint(-1 * (command.parameters[0] + oldPoint.x) + 2 * path.currentPoint.x,
                        -1 * (command.parameters[1] + oldPoint.y) + 2 * path.currentPoint.y);
                }
            }
        }
    }
    if (type == kIJSVGCommandTypeAbsolute) {
        [path.path curveToPoint:NSMakePoint(params[2], params[3])
                  controlPoint1:NSMakePoint(firstControl.x, firstControl.y)
                  controlPoint2:NSMakePoint(params[0], params[1])];
        return;
    }
    [path.path curveToPoint:NSMakePoint(path.currentPoint.x + params[2], path.currentPoint.y + params[3])
              controlPoint1:NSMakePoint(firstControl.x, firstControl.y)
              controlPoint2:NSMakePoint(path.currentPoint.x + params[0], path.currentPoint.y + params[1])];
}

@end
