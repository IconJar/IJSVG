//
//  IJSVGBezierPathAdditions.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGBezierPathAdditions.h"

@implementation NSBezierPath (IJSVGAdditions)

- (void)addQuadCurveToPoint:(CGPoint)QP2
               controlPoint:(CGPoint)QP1
{
    CGPoint QP0 = [self currentPoint];
    CGPoint CP3 = QP2;
    CGPoint CP1 = CGPointMake( QP0.x + ((2.0 / 3.0) * (QP1.x - QP0.x)), QP0.y + ((2.0 / 3.0) * (QP1.y - QP0.y)));
    CGPoint CP2 = CGPointMake( QP2.x + (2.0 / 3.0) * (QP1.x - QP2.x), QP2.y + (2.0 / 3.0) * (QP1.y - QP2.y) );
    
    [self curveToPoint:CP3
         controlPoint1:CP1
         controlPoint2:CP2];
}

@end
