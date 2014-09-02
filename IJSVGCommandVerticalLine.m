//
//  IJSVGCommandVerticalLine.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandVerticalLine.h"

@implementation IJSVGCommandVerticalLine

+ (void)load
{
    [IJSVGCommand registerClass:[self class]
                     forCommand:@"v"];
}

+ (NSInteger)requiredParameterCount
{
    return 1;
}

+ (void)runWithParams:(CGFloat *)params
           paramCount:(NSInteger)count
      previousCommand:(IJSVGCommand *)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath *)path
{
    if( type == IJSVGCommandTypeAbsolute )
    {
        [[path currentSubpath] lineToPoint:NSMakePoint( [path currentSubpath].currentPoint.x, params[0])];
        return;
    }
    NSPoint point = NSMakePoint( [path currentSubpath].currentPoint.x,
                                [path currentSubpath].currentPoint.y + params[0]);
    [[path currentSubpath] lineToPoint:point];
}

@end
