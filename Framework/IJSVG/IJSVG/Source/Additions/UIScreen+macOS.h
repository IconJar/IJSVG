//
//  UIScreen+macOS.swift
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#if __has_include(<UIKit/UIKit.h>)
@import UIKit;

@interface UIScreen (macOS)

- (CGFloat)backingScaleFactor;

@end

#endif
