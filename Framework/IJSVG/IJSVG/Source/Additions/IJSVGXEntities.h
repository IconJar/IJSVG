//
//  IJSVGXColor.h
//  IJSVG
//
//  Created by François Lamboley on 2024/02/13.
//
//

#import <TargetConditionals.h>
#if TARGET_OS_OSX

# import <AppKit/AppKit.h>

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


#else


# import <CoreGraphics/CoreGraphics.h>
# import <UIKit/UIKit.h>
# import <TouchXML/TouchXML.h>

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

/* TODO: These should probably be private (at least some of these). */
# import <IJSVG/CGColorSpaceWrapper.h>
# import <IJSVG/NSString+macOS.h>
# import <IJSVG/NSValue+macOS.h>
# import <IJSVG/UIColor+macOS.h>
# import <IJSVG/UIImage+macOS.h>
# import <IJSVG/UIScreen+macOS.h>

#endif
