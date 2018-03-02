//
//  IJSVGCommandArc.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandArc.h"
#import "IJSVGUtils.h"

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
              command:(IJSVGCommand *)currentCommand
      previousCommand:(IJSVGCommand *)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath *)path
{
    CGPoint radii = CGPointZero;
    CGPoint arcEndPoint = CGPointZero;
    CGPoint arcStartPoint = path.currentPoint;
    CGFloat xAxisRotation = 0;
    BOOL largeArcFlag = 0;
    BOOL sweepFlag = 0;
    
    radii = [currentCommand readPoint];
    xAxisRotation = [currentCommand readFloat];
    largeArcFlag = [currentCommand readBOOL];
    sweepFlag = [currentCommand readBOOL];
    arcEndPoint = [currentCommand readPoint];
    
    if (type == IJSVGCommandTypeRelative) {
        arcEndPoint.x += path.currentPoint.x;
        arcEndPoint.y += path.currentPoint.y;
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
    
    CGFloat startAngle = angle(CGPointMake(1, 0), CGPointMake((currentPoint.x-preCenterPoint.x)/radii.x,
                                                              (currentPoint.y-preCenterPoint.y)/radii.y));
    
    CGPoint deltaU = CGPointMake((currentPoint.x - preCenterPoint.x) / radii.x,
                                 (currentPoint.y - preCenterPoint.y) / radii.y);
    CGPoint deltaV = CGPointMake((-currentPoint.x - preCenterPoint.x) / radii.x,
                                 (-currentPoint.y - preCenterPoint.y) / radii.y);
    CGFloat angleDelta = (deltaU.x * deltaV.y < deltaU.y * deltaV.x ? -1 : 1) * acos(ratio(deltaU, deltaV));
    
    angleDelta = (ratio(deltaU, deltaV) <= -1) ? M_PI : (ratio(deltaU, deltaV) >= 1) ? 0 : angleDelta;
    
    // check for actually numbers, if this is not valid
    // kill it, blame WWDC 2017 SVG background for this...
    if(isnan(startAngle) || isnan(angleDelta)) {
        return;
    }
    
    CGFloat radius = MAX(radii.x, radii.y);
    CGPoint scale = (radii.x > radii.y) ? CGPointMake(1, radii.y / radii.x) :
        CGPointMake(radii.x / radii.y, 1);
    
    NSAffineTransform * trans = [NSAffineTransform transform];
    [trans translateXBy:-centerPoint.x yBy:-centerPoint.y];
    [path.currentSubpath transformUsingAffineTransform:trans];
    
    trans = [NSAffineTransform transform];
    [trans rotateByRadians:-xAxisRotation];
    [path.currentSubpath transformUsingAffineTransform:trans];
    
    trans = [NSAffineTransform transform];
    [trans scaleXBy:(1/scale.x) yBy:(1/scale.y)];
    [path.currentSubpath transformUsingAffineTransform:trans];
    
    [path.currentSubpath appendBezierPathWithArcWithCenter:NSZeroPoint
                                                    radius:radius
                                                startAngle:radians_to_degrees(startAngle)
                                                  endAngle:radians_to_degrees(startAngle + angleDelta)
                                                 clockwise:!sweepFlag];
    
    trans = [NSAffineTransform transform];
    [trans scaleXBy:scale.x yBy:scale.y];
    [path.currentSubpath transformUsingAffineTransform:trans];
    
    trans = [NSAffineTransform transform];
    [trans rotateByRadians:xAxisRotation];
    [path.currentSubpath transformUsingAffineTransform:trans];
    
    trans = [NSAffineTransform transform];
    [trans translateXBy:centerPoint.x yBy:centerPoint.y];
    [path.currentSubpath transformUsingAffineTransform:trans];
}

@end
