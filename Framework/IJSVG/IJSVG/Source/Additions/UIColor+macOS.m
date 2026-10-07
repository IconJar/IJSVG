//
//  UIColor+macOS.m
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#import <TargetConditionals.h>
#if !TARGET_OS_OSX

#import <UIKit/UIKit.h>
#import "UIColor+macOS.h"

@implementation UIColor (macOS)

+ (UIColor *)colorWithDeviceRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
    return [self colorWithRed:red green:green blue:blue alpha:alpha];
}

+ (UIColor *)colorWithDeviceHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha
{
    return [self colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

- (CGFloat)redComponent
{
    CGFloat red, green, blue, alpha;
    [self getRed:&red green:&green blue:&blue alpha:&alpha];
    return red;
}

- (CGFloat)greenComponent
{
    CGFloat red, green, blue, alpha;
    [self getRed:&red green:&green blue:&blue alpha:&alpha];
    return green;
}

- (CGFloat)blueComponent
{
    CGFloat red, green, blue, alpha;
    [self getRed:&red green:&green blue:&blue alpha:&alpha];
    return blue;
}

- (CGFloat)alphaComponent
{
    CGFloat red, green, blue, alpha;
    [self getRed:&red green:&green blue:&blue alpha:&alpha];
    return alpha;
}

- (CGColorSpaceWrapper *)colorSpace
{
    CGColorSpaceWrapper *ret = [CGColorSpaceWrapper new];
    ret.colorSpace = CGColorGetColorSpace(self.CGColor);
    return ret;
}

- (UIColor *)colorUsingXColorSpace:(XColorSpace *)colorSpace
{
    CGColorRef cgColor = CGColorCreateCopyByMatchingToColorSpace(colorSpace.colorSpace, kCGRenderingIntentDefault, self.CGColor, NULL);
    return [[UIColor alloc] initWithCGColor:cgColor];
}

@end

#else

#import <AppKit/AppKit.h>
#import "UIColor+macOS.h"

@implementation NSColor (iOSParity)

- (NSColor *)colorUsingXColorSpace:(XColorSpace *)colorSpace
{
	return [self colorUsingColorSpace:colorSpace];
}

@end

#endif
