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
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sequence = (IJSVGPathDataSequence*)malloc(sizeof(IJSVGPathDataSequence) * 7);
        _sequence[0] = kIJSVGPathDataSequenceTypeFloat;
        _sequence[1] = kIJSVGPathDataSequenceTypeFloat;
        _sequence[2] = kIJSVGPathDataSequenceTypeFloat;
        _sequence[3] = kIJSVGPathDataSequenceTypeFlag;
        _sequence[4] = kIJSVGPathDataSequenceTypeFlag;
        _sequence[5] = kIJSVGPathDataSequenceTypeFloat;
        _sequence[6] = kIJSVGPathDataSequenceTypeFloat;
    });
    return _sequence;
}

// modified from https://github.com/SVGKit/SVGKit/blob/880c94a5b77b6f22beb491a7a7e02ace220c32af/Source/Parsers/SVGKPointsAndPathsParser.m
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
    CGFloat xAxisRotation = 0.f;
    BOOL largeArcFlag = NO;
    BOOL sweepFlag = NO;
    
    radii = [currentCommand readPoint];
    xAxisRotation = [currentCommand readFloat];
    largeArcFlag = [currentCommand readBOOL];
    sweepFlag = [currentCommand readBOOL];
    arcEndPoint = [currentCommand readPoint];
    
    CGFloat rx = fabs(radii.x);
    CGFloat ry = fabs(radii.y);
    
    xAxisRotation *= M_PI / 180.f;
    xAxisRotation = fmod(xAxisRotation, 2.f * M_PI);

    if (type == kIJSVGCommandTypeRelative) {
        arcEndPoint.x += pathCurrentPoint.x;
        arcEndPoint.y += pathCurrentPoint.y;
    }
    
    CGFloat x1 = pathCurrentPoint.x;
    CGFloat y1 = pathCurrentPoint.y;
    
    CGFloat x2 = arcEndPoint.x;
    CGFloat y2 = arcEndPoint.y;
    
    if (rx == 0.f || ry == 0.f) {
        CGPathAddLineToPoint(path.path, NULL, x2, y2);
        return;
    }
    
    CGFloat cosPhi = cos(xAxisRotation);
    CGFloat sinPhi = sin(xAxisRotation);
    
    CGFloat x1p = cosPhi * (x1 - x2) / 2.f + sinPhi * (y1 - y2) / 2.f;
    CGFloat y1p = -sinPhi * (x1 - x2) / 2.f + cosPhi * (y1 - y2) / 2.f;
    
    CGFloat rx_2 = rx * rx;
    CGFloat ry_2 = ry * ry;
    CGFloat xp_2 = x1p * x1p;
    CGFloat yp_2 = y1p * y1p;

    CGFloat delta = xp_2 / rx_2 + yp_2 / ry_2;
    
    if (delta > 1.f) {
        rx *= sqrt(delta);
        ry *= sqrt(delta);
        rx_2 = rx * rx;
        ry_2 = ry * ry;
    }
    
    CGFloat sign = (largeArcFlag == sweepFlag) ? -1.f : 1.f;
    CGFloat numerator = MAX(0.f, rx_2 * ry_2 - rx_2 * yp_2 - ry_2 * xp_2);
    CGFloat denom = rx_2 * yp_2 + ry_2 * xp_2;
    CGFloat lhs = denom == 0.f ? 0.f : sign * sqrt(numerator / denom);
    
    CGFloat cxp = lhs * (rx * y1p) / ry;
    CGFloat cyp = lhs * -((ry * x1p) / rx);
    
    CGFloat cx = cosPhi * cxp + -sinPhi * cyp + (x1 + x2) / 2.f;
    CGFloat cy = cxp * sinPhi + cyp * cosPhi + (y1 + y2) / 2.f;

    CGAffineTransform transform = CGAffineTransformMakeScale(1.f / rx, 1.f / ry);
    transform = CGAffineTransformRotate(transform, -xAxisRotation);
    transform = CGAffineTransformTranslate(transform, -cx, -cy);
    
    CGPoint arcPt1 = CGPointApplyAffineTransform(CGPointMake(x1, y1), transform);
    CGPoint arcPt2 = CGPointApplyAffineTransform(CGPointMake(x2, y2), transform);
        
    CGFloat startAngle = atan2(arcPt1.y, arcPt1.x);
    CGFloat endAngle = atan2(arcPt2.y, arcPt2.x);
    
    CGFloat angleDelta = endAngle - startAngle;;
    
    if (sweepFlag == YES) {
        if (angleDelta < 0.f) {
            angleDelta += 2.f * M_PI;
        }
    } else if (angleDelta > 0.f) {
        angleDelta = angleDelta - 2.f * M_PI;
    }
    
    transform = CGAffineTransformMakeTranslation(cx, cy);
    transform = CGAffineTransformRotate(transform, xAxisRotation);
    transform = CGAffineTransformScale(transform, rx, ry);

    CGPathAddRelativeArc(path.path, &transform, 0.f, 0.f, 1.f,
                         startAngle, angleDelta);
}

@end
