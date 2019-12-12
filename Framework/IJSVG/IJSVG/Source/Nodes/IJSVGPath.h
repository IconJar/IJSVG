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
    NSBezierPath* subpath;
    CGPoint lastControlPoint;
}

@property (nonatomic, assign) IJSVGPrimitivePathType primitiveType;
@property (nonatomic, readonly) NSBezierPath* path;
@property (nonatomic, readonly) NSBezierPath* subpath;
@property (nonatomic, assign) CGPoint lastControlPoint;
@property (nonatomic, readonly) CGPathRef CGPath;

- (NSBezierPath*)currentSubpath;
- (void)close;
- (NSPoint)currentPoint;
- (void)overwritePath:(NSBezierPath*)aPath;
- (CGPathRef)newPathRefByAutoClosingPath:(BOOL)autoClose;

@end
