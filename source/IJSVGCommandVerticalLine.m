//
//  IJSVGCommandVerticalLine.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandVerticalLine.h"

@implementation IJSVGCommandVerticalLine

+ (NSInteger)requiredParameterCount
{
    return 1;
}

+ (void)runWithParams:(CGFloat *)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand *)currentCommand
      previousCommand:(IJSVGCommand *)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath *)path
{
    if( type == IJSVGCommandTypeAbsolute )
    {
        [[path currentSubpath] lineToPoint:NSMakePoint( [path currentSubpath].currentPoint.x, params[0])];
        return;
    }
    [[path currentSubpath] relativeLineToPoint:NSMakePoint( 0.f, params[0])];
}

@end
