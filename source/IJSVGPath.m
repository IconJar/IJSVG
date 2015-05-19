//
//  IJSVGPath.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGPath.h"
#import "IJSVGGroup.h"

@implementation IJSVGPath

@synthesize path;
@synthesize subpath;
@synthesize lastControlPoint;

- (void)dealloc
{
    [subpath release], subpath = nil;
    [super dealloc];
}

- (id)init
{
    if( ( self = [super init] ) != nil )
    {
        subpath = [[NSBezierPath bezierPath] retain];
        path = subpath; // for legacy use
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGPath * node = [super copyWithZone:zone];
    [node overwritePath:self.path];
    return node;
}

- (NSPoint)currentPoint
{
    return [subpath currentPoint];
}

- (NSBezierPath *)currentSubpath
{
    return subpath;
}

- (void)close
{
    [subpath closePath];
}

- (void)overwritePath:(NSBezierPath *)aPath
{
    [subpath release], subpath = nil;
    subpath = [aPath retain];
    path = subpath;
}

@end
