//
//  IJSVGCommandClose.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandClose.h"

@implementation IJSVGCommandClose

+ (void)load
{
    [IJSVGCommand registerClass:[self class]
                     forCommand:@"z"];
}

+ (NSInteger)requiredParameterCount
{
    return 0;
}

+ (void)runWithParams:(CGFloat *)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand *)currentCommand
      previousCommand:(IJSVGCommand *)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath *)path
{
    [path close];
}

@end
