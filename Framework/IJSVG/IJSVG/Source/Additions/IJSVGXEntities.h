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
# define CXMLAttributeKind NSXMLAttributeKind
# define CXMLCommentKind NSXMLCommentKind
# define CXMLDocument NSXMLDocument
# define CXMLElement NSXMLElement
# define CXMLElementKind NSXMLElementKind
# define CXMLNode NSXMLNode
# define CXMLNodeCompactEmptyElement NSXMLNodeCompactEmptyElement
# define CXMLNodeKind NSXMLNodeKind
# define CXMLNodeOptions NSXMLNodeOptions
# define CXMLNodeOptionsNone NSXMLNodeOptionsNone
# define CXMLNodePrettyPrint NSXMLNodePrettyPrint
# define CXMLTextKind NSXMLTextKind

#endif


# if __has_include(<UIKit/UIKit.h>)

@import CoreGraphics;
@import UIKit;
@import TouchXML;

# define NSCompositingOperationCopy 1

# define XColor UIColor
# define XColorSpace CGColorSpaceWrapper
# define XCompositingOperation CGBlendMode
# define XCompositingOperationCopy kCGBlendModeCopy
# define XImage UIImage
# define XPoint CGPoint
# define XPointMake CGPointMake
# define XPointZero CGPointZero
# define XRect CGRect
# define XRectFromCGRect (CGRect)
# define XRectMake CGRectMake
# define XRectToCGRect (CGRect)
# define XScreen UIScreen
# define XView UIView

# import "CGColorSpaceWrapper.h"
# import "NSString+macOS.h"
# import "NSValue+macOS.h"
# import "UIColor+macOS.h"
# import "UIImage+macOS.h"
# import "UIScreen+macOS.h"

#endif
