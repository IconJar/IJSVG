//
//  IJSVGPath.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGGroup.h"
#import "IJSVGPath.h"

@implementation IJSVGPath

- (void)dealloc
{
    if(_path != NULL) {
        (void)CGPathRelease(_path), _path = NULL;
    }
    [super dealloc];
}

- (id)init
{
    if ((self = [super init]) != nil) {
        _primitiveType = kIJSVGPrimitivePathTypePath;
        _path = CGPathCreateMutable();
        self.renderable = YES;
    }
    return self;
}

- (CGRect)bounds
{
    return self.pathBoundingBox;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGPath* node = [super copyWithZone:zone];
    node.path = _path;
    return node;
}

- (void)setPath:(CGMutablePathRef)path
{
    // this will automatically copy any path into a mutable path
    // regardless of if it was a mutable path to begin with
    if(_path != NULL) {
        (void)CGPathRelease(_path), _path = NULL;
    }
    _path = CGPathCreateMutableCopy(path);
}

- (CGRect)pathBoundingBox
{
    return CGPathGetPathBoundingBox(_path);
}

- (CGRect)controlPointBoundingBox
{
    return CGPathGetBoundingBox(_path);
}

- (NSPoint)currentPoint
{
    return CGPathGetCurrentPoint(_path);
}

- (void)close
{
    CGPathCloseSubpath(_path);
}

- (BOOL)isStroked
{
    return (self.strokeColor != nil && self.strokeColor.alphaComponent != 0.f) ||
        self.strokePattern != nil ||
        self.strokeGradient != nil;
}

@end
