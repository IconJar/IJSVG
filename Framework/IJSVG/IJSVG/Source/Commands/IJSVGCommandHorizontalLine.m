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
                 path:(CGMutablePathRef)path
{
    if (type == kIJSVGCommandTypeAbsolute) {
        CGPathAddLineToPoint(path, NULL, params[0], CGPathGetCurrentPoint(path).y);
        return;
    }
    CGPoint currentPoint = CGPathGetCurrentPoint(path);
    CGPathAddLineToPoint(path, NULL, currentPoint.x + params[0],
                         currentPoint.y);
}

@end
