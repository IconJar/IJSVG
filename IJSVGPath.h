//
//  IJSVGPath.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGBezierPathAdditions.h"
#import "IJSVGNode.h"

@class IJSVGGroup;

@interface IJSVGPath : IJSVGNode {
    
    NSBezierPath * path;
    NSBezierPath * subpath;
    
}

@property ( nonatomic, readonly ) NSBezierPath * path;
@property ( nonatomic, readonly ) NSBezierPath * subpath;

- (NSBezierPath *)currentSubpath;
- (void)close;
- (NSPoint)currentPoint;
- (void)overwritePath:(NSBezierPath *)aPath;

@end
