//
//  IJSVGXColor.h
//  IJSVG
//
//  Created by François Lamboley on 2024/02/13.
//
//

#if __has_include(<AppKit/AppKit.h>)

@import AppKit;

# define XColor NSColor
# define XColorSpace NSColorSpace
# define XCompositingOperation NSCompositingOperation
# define XCompositingOperationCopy NSCompositingOperationCopy
# define XImage NSImage
# define XPoint NSPoint
# define XPointMake NSMakePoint
# define XPointZero NSZeroPoint
# define XRect NSRect
# define XRectFromCGRect NSRectFromCGRect
# define XRectMake NSMakeRect
# define XRectToCGRect NSRectToCGRect
# define XScreen NSScreen
# define XView NSView
# define CXMLDocument NSXMLDocument
# define CXMLElement NSXMLElement
# define CXMLNode NSXMLNode
# define CXMLNodeCompactEmptyElement NSXMLNodeCompactEmptyElement
# define CXMLNodeKind NSXMLNodeKind
# define CXMLNodeOptions NSXMLNodeOptions
# define CXMLNodeOptionsNone NSXMLNodeOptionsNone
# define CXMLNodePrettyPrint NSXMLNodePrettyPrint
# define CXMLElementKind NSXMLElementKind
# define CXMLNodePreserveWhitespace NSXMLNodePreserveWhitespace

#endif


# if __has_include(<UIKit/UIKit.h>)

@import CoreGraphics;
@import UIKit;
@import TouchXML;

# define XColor UIColor
# define XColorSpace IJSVGColorSpace
# define XCompositingOperation CGBlendMode
# define XCompositingOperationCopy kCGBlendModeCopy
# define XImage UIImage
# define XPoint CGPoint
# define XPointMake CGPointMake
# define XPointZero CGPointZero
# define XRect CGRect
# define XRectMake CGRectMake
# define XScreen UIScreen
# define XView UIView

#endif
