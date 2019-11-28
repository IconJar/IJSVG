//
//  IJSVGBezierPathAdditions.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface NSBezierPath (IJSVGAdditions)

- (void)addQuadCurveToPoint:(NSPoint)aPoint
               controlPoint:(NSPoint)cp;

@end
