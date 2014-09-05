//
//  IJSVGBezierPathAdditions.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGBezierPathAdditions.h"

@implementation NSBezierPath (IJSVGAdditions)

- (void)addQuadCurveToPoint:(NSPoint)aPoint
               controlPoint:(NSPoint)cp
{
    NSPoint QP0 = self.currentPoint;
    NSPoint CP3 = aPoint;
    NSPoint CP1 = NSMakePoint(QP0.x + ((2.f/3.f) * (cp.x - QP0.x)),
                              QP0.y + ((2.0 / 3.0) * (cp.y - QP0.y)));
    
    NSPoint CP2 = CGPointMake(aPoint.x + (2.0 / 3.0) * (cp.x - aPoint.x),
                              aPoint.y + (2.0 / 3.0) * (cp.y - aPoint.y));
    [self curveToPoint:CP3
         controlPoint1:CP1
         controlPoint2:CP2];
}

@end
