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

- (CGPathRef)CGPath
{
    int i, numElements;
    
    // Need to begin a path here.
    CGPathRef           immutablePath = NULL;
    
    // Then draw the path elements.
    numElements = (int)[self elementCount];
    if (numElements > 0)
    {
        CGMutablePathRef    path = CGPathCreateMutable();
        NSPoint             points[3];
        BOOL                didClosePath = YES;
        
        for (i = 0; i < numElements; i++)
        {
            switch ([self elementAtIndex:i associatedPoints:points])
            {
                case NSMoveToBezierPathElement:
                    CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
                    break;
                    
                case NSLineToBezierPathElement:
                    CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
                    didClosePath = NO;
                    break;
                    
                case NSCurveToBezierPathElement:
                    CGPathAddCurveToPoint(path, NULL, points[0].x, points[0].y,
                                          points[1].x, points[1].y,
                                          points[2].x, points[2].y);
                    didClosePath = NO;
                    break;
                    
                case NSClosePathBezierPathElement:
                    CGPathCloseSubpath(path);
                    didClosePath = YES;
                    break;
            }
        }
        
        // Be sure the path is closed or Quartz may not do valid hit detection.
        if (!didClosePath)
            CGPathCloseSubpath(path);
        
        immutablePath = CGPathCreateCopy(path);
        CGPathRelease(path);
    }
    return immutablePath;
}

@end
