//
//  IJSVGXColor.h
//  IJSVG
//
//  Created by François Lamboley on 2024/02/13.
//
//

#if __has_include(<AppKit/AppKit.h>)
#import <AppKit/AppKit.h>
#define XColor NSColor
#define XColorSpaceRef NSColorSpace*
#define XImage NSImage
#define XPoint NSPoint
#define XRect NSRect
#define XView NSView
#endif
#import <Foundation/Foundation.h>
#if __has_include(<UIKit/UIKit.h>)
@import UIKit;
@import CoreGraphics;
#define XColor UIColor
#define XColorSpace UIColorSpace
#define XColorSpaceRef CGColorSpaceRef
#define XImage UIImage
#define XPoint CGPoint
#define XRect CGRect
#define XView UIView
#endif
