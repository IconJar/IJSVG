//
//  IJSVGPath.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGBezierPathAdditions.h"
#import "IJSVGNode.h"
#import <Foundation/Foundation.h>

@class IJSVGGroup;

typedef NS_ENUM(NSInteger, IJSVGPrimitivePathType) {
    IJSVGPrimitivePathTypePath,
    IJSVGPrimitivePathTypeRect,
    IJSVGPrimitivePathTypePolygon,
    IJSVGPrimitivePathTypePolyLine,
    IJSVGPrimitivePathTypeCircle,
    IJSVGPrimitivePathTypeEllipse,
    IJSVGPrimitivePathTypeLine
};

@interface IJSVGPath : IJSVGNode {

    NSBezierPath* path;
    CGPoint lastControlPoint;
}

@property (nonatomic, assign) IJSVGPrimitivePathType primitiveType;
@property (nonatomic, retain) NSBezierPath* path;
@property (nonatomic, assign) CGPoint lastControlPoint;
@property (nonatomic, readonly) CGPathRef CGPath;

- (void)close;
- (NSPoint)currentPoint;

@end
