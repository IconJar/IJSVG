//
//  IJSVGCommandLineTo.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandLineTo.h"

@implementation IJSVGCommandLineTo

+ (void)load
{
    [IJSVGCommand registerClass:[self class]
                     forCommand:@"l"];
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
    if( type == IJSVGCommandTypeAbsolute )
    {
        [[path currentSubpath] lineToPoint:NSMakePoint( params[0], params[1])];
        return;
    }
    NSPoint point = NSMakePoint( [path currentSubpath].currentPoint.x + params[0],
                                [path currentSubpath].currentPoint.y + params[1]);
    [[path currentSubpath] lineToPoint:point];
}

@end
