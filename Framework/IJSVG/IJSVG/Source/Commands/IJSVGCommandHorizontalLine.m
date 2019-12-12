//
//  IJSVGCommandHorizontalLine.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandHorizontalLine.h"

@implementation IJSVGCommandHorizontalLine

+ (NSInteger)requiredParameterCount
{
    return 1;
}

+ (void)runWithParams:(CGFloat*)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand*)currentCommand
      previousCommand:(IJSVGCommand*)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath*)path
{
    if (type == kIJSVGCommandTypeAbsolute) {
        [path.path lineToPoint:NSMakePoint(params[0], path.currentPoint.y)];
        return;
    }
    [path.path relativeLineToPoint:NSMakePoint(params[0], 0.f)];
}

@end
