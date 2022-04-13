//
//  IJSVGCommandMove.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandLineTo.h"
#import "IJSVGCommandMove.h"

@implementation IJSVGCommandMove

+ (NSInteger)requiredParameterCount
{
    return 2;
}

+ (void)runWithParams:(CGFloat*)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand*)currentCommand
      previousCommand:(IJSVGCommand*)command
                 type:(IJSVGCommandType)type
                 path:(CGMutablePathRef)path
{
    // move to's allow more then one move to, but if there are more then one,
    // we need to run the line to instead...who knew!
    if (command.class == self.class && currentCommand.isSubCommand == YES) {
        [IJSVGCommandLineTo runWithParams:params
                               paramCount:count
                                  command:currentCommand
                          previousCommand:command
                                     type:type
                                     path:path];
        return;
    }

    // actual move to command - do a moveToPoint only
    // if the type is absolute, or its possible the type is
    // relative but there is no previous command which means
    // there is no current point. Asking for current point on an empty
    // path will result in an exception being thrown
    if (type == kIJSVGCommandTypeAbsolute || command == nil) {
        CGPathMoveToPoint(path, NULL,
                          params[0], params[1]);
        return;
    }
    CGPoint currentPoint = CGPathGetCurrentPoint(path);
    CGPathMoveToPoint(path, NULL,
                      currentPoint.x + params[0],
                      currentPoint.y + params[1]);
}

@end
