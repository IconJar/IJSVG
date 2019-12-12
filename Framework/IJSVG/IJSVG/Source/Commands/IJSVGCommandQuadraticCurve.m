//
//  IJSVGCommandQuadraticCurve.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandQuadraticCurve.h"
#import "IJSVGUtils.h"

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
                 path:(IJSVGPath*)path
{
    if (type == kIJSVGCommandTypeAbsolute) {
        [path.path addQuadCurveToPoint:NSMakePoint(params[2], params[3])
                          controlPoint:NSMakePoint(params[0], params[1])];
        return;
    }
    [path.path addQuadCurveToPoint:NSMakePoint(path.currentPoint.x + params[2], path.currentPoint.y + params[3])
                      controlPoint:NSMakePoint(path.currentPoint.x + params[0], path.currentPoint.y + params[1])];
}

@end
