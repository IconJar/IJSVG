//
//  UIColor+macOS.h
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#import <IJSVG/IJSVGXEntities.h>

#import <TargetConditionals.h>
#if !TARGET_OS_OSX

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include "CGColorSpaceWrapper.h"

@interface UIColor (macOS)

+ (UIColor *)colorWithDeviceRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (UIColor *)colorWithDeviceHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha;
- (CGFloat)redComponent;
- (CGFloat)greenComponent;
- (CGFloat)blueComponent;
- (CGFloat)alphaComponent;

- (CGColorSpaceWrapper *)colorSpace;
/* `colorUsingColorSpace:` is a private symbol, which takes precedence over the one we create.
 * So instead we create our own symbol, both in the iOS and macOS world, and use that symbol. */
- (UIColor *)colorUsingXColorSpace:(XColorSpace *)colorSpace;

@end

#else

@interface NSColor (iOSParity)

- (NSColor *)colorUsingXColorSpace:(XColorSpace *)colorSpace;

@end

#endif
