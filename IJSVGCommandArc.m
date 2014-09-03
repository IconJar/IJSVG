//
//  IJSVGCommandArc.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandArc.h"

@implementation IJSVGCommandArc

+ (void)load
{
    [IJSVGCommand registerClass:[self class]
                     forCommand:@"a"];
}

+ (NSInteger)requiredParameterCount
{
    return 7;
}

+ (void)runWithParams:(CGFloat *)params
           paramCount:(NSInteger)count
      previousCommand:(IJSVGCommand *)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath *)path
{
    
}

@end
