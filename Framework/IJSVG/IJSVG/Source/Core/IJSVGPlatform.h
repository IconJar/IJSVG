//
//  IJSVGPlatform.h
//  IJSVG
//
//  Platform abstraction for shared macOS / iOS code.
//

#import <TargetConditionals.h>
#import <Foundation/Foundation.h>

#if TARGET_OS_OSX

#import <AppKit/AppKit.h>

static inline CGContextRef NSGraphicsGetCurrentContext(void) {
    return NSGraphicsContext.currentContext.CGContext;
}

#elif TARGET_OS_IOS

#import <UIKit/UIKit.h>
#import <IJSVG/IJSVGiOSXML.h>

#define NSColor UIColor
#define NSImage UIImage
#define NSBezierPath UIBezierPath
#define NSEdgeInsets UIEdgeInsets
#define NSEdgeInsetsZero UIEdgeInsetsZero
#define NSFont UIFont
#define NSView UIView
#define NSGraphicsGetCurrentContext() UIGraphicsGetCurrentContext()

typedef CGPoint NSPoint;
typedef CGSize NSSize;
typedef CGRect NSRect;

#define NSZeroPoint CGPointZero
#define NSZeroSize CGSizeZero
#define NSZeroRect CGRectZero
#define NSMakePoint(x, y) CGPointMake((x), (y))
#define NSMakeSize(w, h) CGSizeMake((w), (h))
#define NSMakeRect(x, y, w, h) CGRectMake((x), (y), (w), (h))

// On macOS NSRect is typedef'd to CGRect, so the conversion functions are
// identity. On iOS NSRect doesn't exist natively — we typedef it to CGRect
// above, so the same identity rule applies. Same for Point/Size.
#define NSRectFromCGRect(r) (r)
#define NSRectToCGRect(r) (r)
#define NSPointFromCGPoint(p) (p)
#define NSPointToCGPoint(p) (p)
#define NSSizeFromCGSize(s) (s)
#define NSSizeToCGSize(s) (s)

// AppKit's -[NSView setNeedsDisplay:] takes a BOOL; UIKit's takes none.
// Provide a BOOL-taking variant so shared call sites compile unchanged.
@interface UIView (IJSVGNeedsDisplay)
- (void)setNeedsDisplay:(BOOL)flag;
@end

// Foundation on iOS only ships the CG-named NSValue geometry methods; AppKit
// uses the NS-named ones. Bridge them so cross-platform call sites work.
@interface NSValue (IJSVGGeometry)
+ (NSValue*)valueWithPoint:(CGPoint)point;
+ (NSValue*)valueWithSize:(CGSize)size;
+ (NSValue*)valueWithRect:(CGRect)rect;
@property (readonly) CGPoint pointValue;
@property (readonly) CGSize sizeValue;
@property (readonly) CGRect rectValue;
@end

#endif
