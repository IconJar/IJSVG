//
//  IJSVGCommandMove.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandMove.h"


@implementation IJSVGCommandMove

+ (void)load
{
    [IJSVGCommand registerClass:[self class]
                     forCommand:@"m"];
}

+ (NSInteger)requiredParameterCount
{
    return 2;
}

+ (void)runWithParams:(CGFloat *)params
           paramCount:(NSInteger)count
      previousCommand:(IJSVGCommand *)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath *)path
{
    if( type == IJSVGCommandTypeAbsolute )
    {
        [[path currentSubpath] moveToPoint:NSMakePoint( params[0], params[1])];
        return;
    }
    @try {
        [[path currentSubpath] relativeMoveToPoint:NSMakePoint( params[0], params[1])];
    }
    @catch (NSException *exception) {
        [[path currentSubpath] moveToPoint:NSMakePoint( params[0], params[1])];
    }
}

@end
