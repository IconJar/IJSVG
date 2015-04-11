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
//    NSPoint point = [path currentPoint];
//    
//    CGFloat x1 = point.x;
//    CGFloat y1 = point.y;
//    
//    NSPoint radii = [[self class] readCoordinatePair:params
//                                               index:0];
//    
//    CGFloat rX = fabs(radii.x);
//    CGFloat rY = fabs(radii.y);
//    
//    CGFloat phi = params[2];
//    phi *= M_PI/180;
//    
//    BOOL largeArcFlag = params[3] != 0.f;
//    BOOL sweepFlag = params[4] != 0.f;
//    
//    NSPoint endPoint = NSMakePoint( params[5], params[6]);
//    
//    CGFloat x2 = point.x + endPoint.x;
//    CGFloat y2 = point.y + endPoint.y;
}

@end
