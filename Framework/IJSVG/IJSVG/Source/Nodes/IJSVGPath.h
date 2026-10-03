//
//  IJSVGPath.h
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGColorNode.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

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
@property (nonatomic, assign, nullable) CGMutablePathRef path;
@property (nonatomic, assign) IJSVGUnitType pathUnits;
@property (nonatomic, strong, nullable) IJSVGUnitLength* x1;
@property (nonatomic, strong, nullable) IJSVGUnitLength* y1;
@property (nonatomic, strong, nullable) IJSVGUnitLength* x2;
@property (nonatomic, strong, nullable) IJSVGUnitLength* y2;
@property (nonatomic, strong, nullable) IJSVGUnitLength* cx;
@property (nonatomic, strong, nullable) IJSVGUnitLength* cy;
@property (nonatomic, strong, nullable) IJSVGUnitLength* rx;
@property (nonatomic, strong, nullable) IJSVGUnitLength* ry;
@property (nonatomic, strong, nullable) IJSVGUnitLength* r;
@property (nonatomic, assign) CGPoint lastControlPoint;
@property (nonatomic, readonly) CGRect controlPointBoundingBox;
@property (nonatomic, readonly) CGRect pathBoundingBox;

+ (void)recursivelyAddPathedNodesPaths:(NSArray<IJSVGNode*>*)nodes
                             transform:(CGAffineTransform)transform
                                toPath:(CGMutablePathRef)mutPath;

// The node owns the path; the getter does not transfer ownership.
- (CGMutablePathRef _Nullable)path CF_RETURNS_NOT_RETAINED;

- (void)close;
- (NSPoint)currentPoint;

@end

NS_ASSUME_NONNULL_END
