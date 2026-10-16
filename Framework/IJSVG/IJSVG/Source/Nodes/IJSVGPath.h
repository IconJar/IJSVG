//
//  IJSVGPath.h
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGColorNode.h>
#import <IJSVG/IJSVGGraphicsNode.h>

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

@interface IJSVGPath : IJSVGGraphicsNode {
}

@property (nonatomic, assign) IJSVGPrimitivePathType primitiveType;

// Nil uses the measured length. Zero is a valid authored length.
@property (nonatomic, copy, nullable) NSNumber* pathLength;
@property (nonatomic, assign, nullable) CGMutablePathRef path;
@property (nonatomic, assign) IJSVGUnitType pathUnits;

// Retained only to distinguish authored arc vertices from their cubic
// approximation.
@property (nonatomic, copy, nullable) NSString* markerPathData;
@property (nonatomic, assign) CGPoint lastControlPoint;
@property (nonatomic, readonly) CGRect controlPointBoundingBox;
@property (nonatomic, readonly) CGRect pathBoundingBox;
@property (nonatomic, readonly) BOOL hasPointSubpaths;

+ (void)recursivelyAddPathedNodesPaths:(NSArray<IJSVGNode*>*)nodes transform:(CGAffineTransform)transform toPath:(CGMutablePathRef)mutPath;

// The node owns the path, the getter does not transfer ownership.
- (CGMutablePathRef _Nullable)path CF_RETURNS_NOT_RETAINED;

- (void)cachePointSubpaths:(BOOL)hasPointSubpaths forPath:(CGPathRef)path;

- (void)close;
- (CGPoint)currentPoint;

@end

NS_ASSUME_NONNULL_END
