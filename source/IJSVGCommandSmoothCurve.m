//
//  IJSVGCommandSmoothCurve.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandSmoothCurve.h"
#import "IJSVGCommandCurve.h"
#import "IJSVGUtils.h"

@implementation IJSVGCommandSmoothCurve

+ (void)load
{
    [IJSVGCommand registerClass:[self class]
                     forCommand:@"s"];
}

+ (NSInteger)requiredParameterCount
{
    return 4;
}

+ (void)runWithParams:(CGFloat *)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand *)currentCommand
      previousCommand:(IJSVGCommand *)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath *)path
{
    NSPoint firstControl = NSMakePoint( [path currentSubpath].currentPoint.x, [path currentSubpath].currentPoint.y );
    if( command != nil )
    {
        if( command.commandClass == [IJSVGCommandCurve class] || command.commandClass == [self class] )
        {
            if( command.commandClass == [IJSVGCommandCurve class] )
            {
                if( command.type == IJSVGCommandTypeAbsolute )
                {
                    firstControl = NSMakePoint(-1*command.parameters[2] + 2*[path currentSubpath].currentPoint.x,
                                               -1*command.parameters[3] + 2*[path currentSubpath].currentPoint.y);
                } else {
                    NSPoint oldPoint = NSMakePoint([path currentSubpath].currentPoint.x - command.parameters[4],
                                                   [path currentSubpath].currentPoint.y - command.parameters[5]);
                    firstControl = NSMakePoint(-1*(command.parameters[2] + oldPoint.x) + 2*[path currentSubpath].currentPoint.x,
                                               -1*(command.parameters[3] + oldPoint.y) + 2*[path currentSubpath].currentPoint.y);
                }
            } else {
                if( command.type == IJSVGCommandTypeAbsolute ) {
                    firstControl = NSMakePoint(-1*command.parameters[0] + 2*[path currentSubpath].currentPoint.x,
                                               -1*command.parameters[1] + 2*[path currentSubpath].currentPoint.y);
                } else {
                    NSPoint oldPoint = NSMakePoint([path currentSubpath].currentPoint.x - command.parameters[2],
                                                   [path currentSubpath].currentPoint.y - command.parameters[3]);
                    firstControl = NSMakePoint(-1*(command.parameters[0] + oldPoint.x) + 2*[path currentSubpath].currentPoint.x,
                                               -1*(command.parameters[1] + oldPoint.y) + 2*[path currentSubpath].currentPoint.y);
                }
            }
        }
    }
    if( type == IJSVGCommandTypeAbsolute )
    {
        [[path currentSubpath] curveToPoint:NSMakePoint( params[2], params[3])
                  controlPoint1:NSMakePoint( firstControl.x, firstControl.y )
                  controlPoint2:NSMakePoint(params[0], params[1])];
        return;
    }
    [[path currentSubpath] curveToPoint:NSMakePoint( [path currentSubpath].currentPoint.x + params[2], [path currentSubpath].currentPoint.y + params[3])
              controlPoint1:NSMakePoint( firstControl.x, firstControl.y )
              controlPoint2:NSMakePoint( [path currentSubpath].currentPoint.x + params[0], [path currentSubpath].currentPoint.y + params[1])];
}

@end
