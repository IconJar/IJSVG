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

@synthesize CGPath = _CGPath;

- (void)dealloc
{
    if (_CGPath != nil) {
        CGPathRelease(_CGPath);
        _CGPath = nil;
    }
    ((void)[_path release]), _path = nil;
    [super dealloc];
}

- (id)init
{
    if ((self = [super init]) != nil) {
        _primitiveType = kIJSVGPrimitivePathTypePath;
        _path = NSBezierPath.bezierPath.retain;
    }
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGPath* node = [super copyWithZone:zone];
    node.path = [self.path.copy autorelease];
    return node;
}

- (NSPoint)currentPoint
{
    return _path.currentPoint;
}

- (void)close
{
    [_path closePath];
}

- (void)invlidateCGPath
{
    if (_CGPath != nil) {
        CGPathRelease(_CGPath);
    }
    _CGPath = nil;
}

- (CGPathRef)CGPath
{
    if (_CGPath == nil) {
        _CGPath = [_path newCGPathRef:NO];
    }
    return _CGPath;
}

@end
