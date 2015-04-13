//
//  IJSVGCommandHorizontalLine.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandHorizontalLine.h"

@implementation IJSVGCommandHorizontalLine

+ (void)load
{
    [IJSVGCommand registerClass:[self class]
                     forCommand:@"h"];
}

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
        [[path currentSubpath] lineToPoint:NSMakePoint( params[0], [path currentSubpath].currentPoint.y)];
        return;
    }
    [[path currentSubpath] relativeLineToPoint:NSMakePoint( params[0], 0.f)];
    
//    NSPoint point = NSMakePoint( [path currentSubpath].currentPoint.x + params[0],
//                                [path currentSubpath].currentPoint.y);
//    [[path currentSubpath] lineToPoint:point];
}

@end
