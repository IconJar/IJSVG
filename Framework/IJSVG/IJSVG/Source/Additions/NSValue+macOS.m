//
//  NSValue+macOS.m
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#import <TargetConditionals.h>
#if !TARGET_OS_OSX

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

@end

#endif
