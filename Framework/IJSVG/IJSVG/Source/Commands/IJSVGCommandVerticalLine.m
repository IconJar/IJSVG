//
//  IJSVGCommandVerticalLine.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGCommandVerticalLine.h>

@implementation IJSVGCommandVerticalLine

+ (NSInteger)requiredParameterCount
{
    return 1;
}

+ (void)runWithParams:(CGFloat*)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand*)currentCommand
      previousCommand:(IJSVGCommand*)command
                 type:(IJSVGCommandType)type
                 path:(CGMutablePathRef)path
{
    if (type == kIJSVGCommandTypeAbsolute) {
        CGPathAddLineToPoint(path, NULL, CGPathGetCurrentPoint(path).x, params[0]);
        return;
    }
    CGPoint currentPoint = CGPathGetCurrentPoint(path);
    CGPathAddLineToPoint(path, NULL, currentPoint.x, currentPoint.y + params[0]);
}

@end
