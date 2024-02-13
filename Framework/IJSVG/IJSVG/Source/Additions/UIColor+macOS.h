//
//  UIColor+macOS.h
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#if __has_include(<UIKit/UIKit.h>)
@import UIKit;
@import CoreGraphics;

@interface UIColor (macOS)

+ (UIColor *)colorWithCGColor:(CGColorRef)color;
+ (UIColor *)colorWithDeviceRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (UIColor *)colorWithDeviceHue:(CGFloat)red saturation:(CGFloat)green brightness:(CGFloat)blue alpha:(CGFloat)alpha;
- (CGFloat)redComponent;
- (CGFloat)greenComponent;
- (CGFloat)blueComponent;
- (CGFloat)alphaComponent;

- (CGColorSpaceWrapper *)colorSpace;
- (instancetype)colorUsingColorSpace:(CGColorSpaceWrapper *)colorSpace;

@end

#endif
