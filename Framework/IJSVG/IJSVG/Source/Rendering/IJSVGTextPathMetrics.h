//
//  IJSVGTextPathMetrics.h
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface IJSVGTextPathMetrics: NSObject

@property (nonatomic, assign) CGFloat length;
@property (nonatomic, assign) BOOL closed;

- (instancetype)initWithPath:(CGPathRef)path;

- (BOOL)pointAt:(CGFloat)distance
          point:(CGPoint*)point
        tangent:(CGPoint*)tangent;

@end
