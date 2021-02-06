//
//  IJSVGCommandLineTo.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandLineTo.h"

@implementation IJSVGCommandLineTo

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
    if (type == kIJSVGCommandTypeAbsolute) {
        CGPathAddLineToPoint(path.path, NULL, params[0], params[1]);
        return;
    }
    CGPoint currentPoint = path.currentPoint;
    CGPathAddLineToPoint(path.path, NULL, currentPoint.x + params[0],
                         currentPoint.y + params[1]);
}

@end
