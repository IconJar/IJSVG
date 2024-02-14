//
//  CGColorSpaceWrapper.m
//  IJSVG
//
//  Created by François Lamboley on 2024/02/13.
//
//

#import "CGColorSpaceWrapper.h"

@implementation CGColorSpaceWrapper

+ (instancetype)deviceRGBColorSpace
{
    CGColorSpaceWrapper *ret = [self new];
    ret->colorSpace = CGColorSpaceCreateDeviceRGB();
    return ret;
}

- (CGColorSpaceRef)CGColorSpace
{
    return colorSpace;
}

@end
