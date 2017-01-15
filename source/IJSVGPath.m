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
    if(subpath!=nil) {
        [subpath release], subpath = nil;
    }
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

- (CGPathRef)newPathRefByAutoClosingPath:(BOOL)autoClose
{
    NSInteger i = 0;
    NSInteger numElements = [self.path elementCount];
    NSBezierPath * bezPath = self.path;
    
    // nothing to return
    if(numElements == 0) {
        return NULL;
    }
    
    CGMutablePathRef aPath = CGPathCreateMutable();
    
    NSPoint points[3];
    BOOL didClosePath = YES;
    
    for (i = 0; i < numElements; i++) {
        switch ([bezPath elementAtIndex:i associatedPoints:points])
        {
                
            // move
            case NSMoveToBezierPathElement: {
                CGPathMoveToPoint(aPath, NULL, points[0].x, points[0].y);
                break;
            }
                
            // line
            case NSLineToBezierPathElement: {
                CGPathAddLineToPoint(aPath, NULL, points[0].x, points[0].y);
                didClosePath = NO;
                break;
            }
                
            // curve
            case NSCurveToBezierPathElement: {
                CGPathAddCurveToPoint(aPath, NULL, points[0].x, points[0].y,
                                      points[1].x, points[1].y,
                                      points[2].x, points[2].y);
                didClosePath = NO;
                break;
            }
                
            // close
            case NSClosePathBezierPathElement: {
                CGPathCloseSubpath(aPath);
                didClosePath = YES;
                break;
            }
        }
    }
    
    if (!didClosePath && autoClose) {
        CGPathCloseSubpath(aPath);
    }
    
    // create immutable and release
    CGPathRef pathToReturn = CGPathCreateCopy(aPath);
    CGPathRelease(aPath);
    
    return pathToReturn;
}

@end
