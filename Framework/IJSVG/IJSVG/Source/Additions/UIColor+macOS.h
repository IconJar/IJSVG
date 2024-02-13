//
//  UIColor+macOS.swift
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
- (CGFloat)alphaComponent;

@end

#endif
