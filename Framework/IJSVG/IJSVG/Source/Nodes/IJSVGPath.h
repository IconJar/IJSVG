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
@property (nonatomic, assign) IJSVGUnitType pathUnits;
@property (nonatomic, strong) IJSVGUnitLength* x1;
@property (nonatomic, strong) IJSVGUnitLength* y1;
@property (nonatomic, strong) IJSVGUnitLength* x2;
@property (nonatomic, strong) IJSVGUnitLength* y2;
@property (nonatomic, strong) IJSVGUnitLength* cx;
@property (nonatomic, strong) IJSVGUnitLength* cy;
@property (nonatomic, strong) IJSVGUnitLength* rx;
@property (nonatomic, strong) IJSVGUnitLength* ry;
@property (nonatomic, strong) IJSVGUnitLength* r;
@property (nonatomic, assign) CGPoint lastControlPoint;
@property (nonatomic, readonly) CGRect controlPointBoundingBox;
@property (nonatomic, readonly) CGRect pathBoundingBox;

+ (void)recursivelyAddPathedNodesPaths:(NSArray<IJSVGNode*>*)nodes
                             transform:(CGAffineTransform)transform
                                toPath:(CGMutablePathRef)mutPath;

- (void)close;
- (NSPoint)currentPoint;

@end
