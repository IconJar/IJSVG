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
    CGPoint CP1 = CGPointMake(QP0.x + ((2.0 / 3.0) * (QP1.x - QP0.x)), QP0.y + ((2.0 / 3.0) * (QP1.y - QP0.y)));
    CGPoint CP2 = CGPointMake(QP2.x + (2.0 / 3.0) * (QP1.x - QP2.x), QP2.y + (2.0 / 3.0) * (QP1.y - QP2.y));

    [self curveToPoint:CP3
         controlPoint1:CP1
         controlPoint2:CP2];
}

- (CGPathRef)newCGPathRef:(BOOL)autoClose
{
    NSInteger i = 0;
    NSInteger numElements = self.elementCount;
    NSBezierPath* bezPath = self;

    // nothing to return
    if (numElements == 0) {
        return NULL;
    }

    CGMutablePathRef aPath = CGPathCreateMutable();

    NSPoint points[3];
    BOOL didClosePath = YES;

    for (i = 0; i < numElements; i++) {
        switch ([bezPath elementAtIndex:i associatedPoints:points]) {

        // move
        case NSMoveToBezierPathElement: {
            CGPathMoveToPoint(aPath, NULL, points[0].x, points[0].y);
            break;
        }

        // line
        case NSLineToBezierPathElement: {
            CGPathAddLineToPoint(aPath, NULL, points[0].x, points[0].y);
            didClosePath = NO;
            break;
        }

        // curve
        case NSCurveToBezierPathElement: {
            CGPathAddCurveToPoint(aPath, NULL, points[0].x, points[0].y,
                points[1].x, points[1].y,
                points[2].x, points[2].y);
            didClosePath = NO;
            break;
        }

        // close
        case NSClosePathBezierPathElement: {
            CGPathCloseSubpath(aPath);
            didClosePath = YES;
            break;
        }
        }
    }

    if (!didClosePath && autoClose) {
        CGPathCloseSubpath(aPath);
    }

    // create immutable and release
    CGPathRef pathToReturn = CGPathCreateCopy(aPath);
    CGPathRelease(aPath);

    return pathToReturn;
}

@end
