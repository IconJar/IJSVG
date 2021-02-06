//
//  IJSVGCommandArc.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandEllipticalArc.h"
#import "IJSVGUtils.h"

@implementation IJSVGCommandEllipticalArc

static IJSVGPathDataSequence* _sequence;

+ (NSInteger)requiredParameterCount
{
    return 7;
}

+ (IJSVGPathDataSequence*)pathDataSequence
{
    if(_sequence == NULL) {
        _sequence = (IJSVGPathDataSequence*)malloc(sizeof(IJSVGPathDataSequence) * 7);
        _sequence[0] = kIJSVGPathDataSequenceTypeFloat;
        _sequence[1] = kIJSVGPathDataSequenceTypeFloat;
        _sequence[2] = kIJSVGPathDataSequenceTypeFloat;
        _sequence[3] = kIJSVGPathDataSequenceTypeFlag;
        _sequence[4] = kIJSVGPathDataSequenceTypeFlag;
        _sequence[5] = kIJSVGPathDataSequenceTypeFloat;
        _sequence[6] = kIJSVGPathDataSequenceTypeFloat;
    }
    return _sequence;
}

+ (void)runWithParams:(CGFloat*)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand*)currentCommand
      previousCommand:(IJSVGCommand*)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath*)path
{
    CGPoint radii = CGPointZero;
    CGPoint arcEndPoint = CGPointZero;
    CGPoint pathCurrentPoint = path.currentPoint;
    CGPoint arcStartPoint = pathCurrentPoint;
    CGFloat xAxisRotation = 0;
    BOOL largeArcFlag = 0;
    BOOL sweepFlag = 0;

    radii = [currentCommand readPoint];
    xAxisRotation = [currentCommand readFloat];
    largeArcFlag = [currentCommand readBOOL];
    sweepFlag = [currentCommand readBOOL];
    arcEndPoint = [currentCommand readPoint];

    if (type == kIJSVGCommandTypeRelative) {
        arcEndPoint.x += pathCurrentPoint.x;
        arcEndPoint.y += pathCurrentPoint.y;
    }

    xAxisRotation *= M_PI / 180.f;
    CGPoint currentPoint = CGPointMake(cos(xAxisRotation) * (arcStartPoint.x - arcEndPoint.x) / 2.0 + sin(xAxisRotation) * (arcStartPoint.y - arcEndPoint.y) / 2.0, -sin(xAxisRotation) * (arcStartPoint.x - arcEndPoint.x) / 2.0 + cos(xAxisRotation) * (arcStartPoint.y - arcEndPoint.y) / 2.0);

    CGFloat radiiAdjustment = pow(currentPoint.x, 2) / pow(radii.x, 2) + pow(currentPoint.y, 2) / pow(radii.y, 2);
    radii.x *= (radiiAdjustment > 1) ? sqrt(radiiAdjustment) : 1;
    radii.y *= (radiiAdjustment > 1) ? sqrt(radiiAdjustment) : 1;

    CGFloat sweep = (largeArcFlag == sweepFlag ? -1 : 1) * sqrt(((pow(radii.x, 2) * pow(radii.y, 2)) - (pow(radii.x, 2) * pow(currentPoint.y, 2)) - (pow(radii.y, 2) * pow(currentPoint.x, 2))) / (pow(radii.x, 2) * pow(currentPoint.y, 2) + pow(radii.y, 2) * pow(currentPoint.x, 2)));
    sweep = (sweep != sweep) ? 0 : sweep;
    CGPoint preCenterPoint = CGPointMake(sweep * radii.x * currentPoint.y / radii.y, sweep * -radii.y * currentPoint.x / radii.x);

    CGPoint centerPoint = CGPointMake((arcStartPoint.x + arcEndPoint.x) / 2.0 + cos(xAxisRotation) * preCenterPoint.x - sin(xAxisRotation) * preCenterPoint.y, (arcStartPoint.y + arcEndPoint.y) / 2.0 + sin(xAxisRotation) * preCenterPoint.x + cos(xAxisRotation) * preCenterPoint.y);

    CGFloat startAngle = angle(CGPointMake(1, 0), CGPointMake((currentPoint.x - preCenterPoint.x) / radii.x, (currentPoint.y - preCenterPoint.y) / radii.y));

    CGPoint deltaU = CGPointMake((currentPoint.x - preCenterPoint.x) / radii.x,
        (currentPoint.y - preCenterPoint.y) / radii.y);
    CGPoint deltaV = CGPointMake((-currentPoint.x - preCenterPoint.x) / radii.x,
        (-currentPoint.y - preCenterPoint.y) / radii.y);
    CGFloat angleDelta = (deltaU.x * deltaV.y < deltaU.y * deltaV.x ? -1 : 1) * acos(ratio(deltaU, deltaV));

    angleDelta = (ratio(deltaU, deltaV) <= -1) ? M_PI : (ratio(deltaU, deltaV) >= 1) ? 0 : angleDelta;

    // check for actually numbers, if this is not valid
    // kill it, blame WWDC 2017 SVG background for this...
    if (isnan(startAngle) || isnan(angleDelta)) {
        return;
    }

    CGFloat radius = MAX(radii.x, radii.y);
    CGPoint scale = (radii.x > radii.y)
        ? CGPointMake(1.f, radii.y / radii.x)
        : CGPointMake(radii.x / radii.y, 1.f);
    
    // translate it
    CGAffineTransform transform = CGAffineTransformMakeTranslation(-centerPoint.x, -centerPoint.y);
    CGPathRef transformPath = CGPathCreateCopyByTransformingPath(path.path, &transform);
    
    // rotate it
    transform = CGAffineTransformMakeRotation(-xAxisRotation);
    CGPathRef rotatedPath = CGPathCreateCopyByTransformingPath(transformPath, &transform);
    
    // scale it
    transform = CGAffineTransformMakeScale((1.f/scale.x), (1.f/scale.y));
    CGMutablePathRef scaledPath = CGPathCreateMutableCopyByTransformingPath(rotatedPath, &transform);
    
    // add the arc
    CGPathAddArc(scaledPath, NULL, 0.f, 0.f, radius, startAngle,
                 startAngle + angleDelta, !sweepFlag);
    
    // scale
    transform = CGAffineTransformMakeScale(scale.x, scale.y);
    CGPathRef rescaledPath = CGPathCreateCopyByTransformingPath(scaledPath, &transform);
    
    // rotate
    transform = CGAffineTransformMakeRotation(xAxisRotation);
    CGPathRef rerotatePath = CGPathCreateCopyByTransformingPath(rescaledPath, &transform);
    
    // translate
    transform = CGAffineTransformMakeTranslation(centerPoint.x, centerPoint.y);
    CGPathRef finalPath = CGPathCreateCopyByTransformingPath(rerotatePath, &transform);
    
    // set the path back onto the path
    path.path = (CGMutablePathRef)finalPath;
    
    // memory clean
    (void)CGPathRelease(transformPath), transformPath = NULL;
    (void)CGPathRelease(rotatedPath), rotatedPath = NULL;
    (void)CGPathRelease(scaledPath), scaledPath = NULL;
    (void)CGPathRelease(rescaledPath), rescaledPath = NULL;
    (void)CGPathRelease(rerotatePath), rerotatePath = NULL;
    (void)CGPathRelease(finalPath), finalPath = NULL;
    
}

@end
