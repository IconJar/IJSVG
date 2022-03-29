//
//  IJSVGPath.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGColorNode.h>
#import <Foundation/Foundation.h>

@class IJSVGGroup;

typedef NS_ENUM(NSInteger, IJSVGPrimitivePathType) {
    kIJSVGPrimitivePathTypePath,
    kIJSVGPrimitivePathTypeRect,
    kIJSVGPrimitivePathTypePolygon,
    kIJSVGPrimitivePathTypePolyLine,
    kIJSVGPrimitivePathTypeCircle,
    kIJSVGPrimitivePathTypeEllipse,
    kIJSVGPrimitivePathTypeLine
};

@interface IJSVGPath : IJSVGNode {
}

@property (nonatomic, assign) IJSVGPrimitivePathType primitiveType;
@property (nonatomic, assign) CGMutablePathRef path;
@property (nonatomic, assign) CGPoint lastControlPoint;
@property (nonatomic, readonly) CGRect controlPointBoundingBox;
@property (nonatomic, readonly) CGRect pathBoundingBox;

- (void)close;
- (NSPoint)currentPoint;

@end
