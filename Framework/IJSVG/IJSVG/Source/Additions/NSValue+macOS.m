//
//  NSValue+macOS.m
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#if __has_include(<UIKit/UIKit.h>)
#import "NSValue+macOS.h"

@implementation NSValue (macOS)

+ (instancetype)valueWithRect:(CGRect)rect
{
    return [self valueWithCGRect:rect];
}

- (CGRect)rectValue
{
    return self.CGRectValue;
}

+ (instancetype)valueWithSize:(CGSize)size
{
    return [self valueWithCGSize:size];
}

- (CGSize)sizeValue
{
    return self.CGSizeValue;
}

+ (instancetype)valueWithPoint:(CGPoint)point
{
    return [self valueWithCGPoint:point];
}

- (CGPoint)pointValue
{
    return self.CGPointValue;
}

@end

#endif
