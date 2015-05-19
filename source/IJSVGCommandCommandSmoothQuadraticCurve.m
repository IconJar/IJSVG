//
//  IJSVGCommandCommandQuadraticCurve.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandCommandSmoothQuadraticCurve.h"
#import "IJSVGUtils.h"
#import "IJSVGCommandQuadraticCurve.h"

@implementation IJSVGCommandCommandSmoothQuadraticCurve

+ (void)load
{
    [IJSVGCommand registerClass:[self class]
                     forCommand:@"t"];
}

+ (NSInteger)requiredParameterCount
{
    return 2;
}

+ (void)runWithParams:(CGFloat *)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand *)currentCommand
      previousCommand:(IJSVGCommand *)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath *)path
{
    NSPoint commandPoint = NSMakePoint( [path currentSubpath].currentPoint.x, [path currentSubpath].currentPoint.y );
    if( command != nil )
    {
        if( command.commandClass == [IJSVGCommandQuadraticCurve class] )
        {
            // quadratic curve
            if( command.type == IJSVGCommandTypeAbsolute )
            {
                commandPoint =  NSMakePoint(-1*command.parameters[0] + 2*[path currentSubpath].currentPoint.x,
                                            -1*command.parameters[1] + 2*[path currentSubpath].currentPoint.y);
            } else {
                NSPoint oldPoint = CGPointMake([path currentSubpath].currentPoint.x - command.parameters[2],
                                               [path currentSubpath].currentPoint.y - command.parameters[3]);
                commandPoint = CGPointMake(-1*(command.parameters[0] + oldPoint.x) + 2*([path currentSubpath].currentPoint.x),
                                           -1*(command.parameters[1] + oldPoint.y) + 2*[path currentSubpath].currentPoint.y);
            }
        } else if( command.commandClass == [self class] ) {
            // smooth quadratic curve
            commandPoint = CGPointMake(-1*(path.lastControlPoint.x) + 2*([path currentSubpath].currentPoint.x),
                                       -1*(path.lastControlPoint.y) + 2*[path currentSubpath].currentPoint.y);
        }
    }
    path.lastControlPoint = commandPoint;
    if( type == IJSVGCommandTypeAbsolute )
    {
        [[path currentSubpath] addQuadCurveToPoint:NSMakePoint(params[0], params[1])
                                      controlPoint:commandPoint];
        return;
    }
    [[path currentSubpath] addQuadCurveToPoint:NSMakePoint([path currentSubpath].currentPoint.x + params[0], [path currentSubpath].currentPoint.y + params[1])
                                  controlPoint:commandPoint];
}

@end
