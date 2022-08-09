IJSVG 3.0
===

IJSVG is a Mac OSX 10.13+ COCOA library for rendering SVG's within your COCOA applications, its extremely fast and native.

It also supports the `NSPasteboards` writing protocol, an IJSVG object can be put onto the pasteboard and application like Sketch and Photoshop can paste them into the document as vector objects (generated PDF's on the fly).

### What is new in IJSVG 3.0?
— Its almost a complete full rewrite.
- Is now fully ARC 🎉.
- Parsing and rendering is much faster.
- Support for aspect ratios and nested SVG's.
- Fixes a lot of pattern and gradient rendering.
- Fixes various clipPath issues.
- Masking now correctly uses alpha masking instead of what `CALayer` uses.
- Various improvements with exporting such as modifying the viewBox instead of using a new group for scaling.
- Exporting now supports converting strokes to paths.
- Much simpler to use API's for creating SVG's from scratch.
- Much better threading support.
- Much improved color replacement support (can now specify only replacing a color that is a fill and not touch ths stroke).
- Improved API's for querying the node graph.
- Support for the wild card CSS selector.
- Removed most `NS` graphics API calls and uses `CG` where possible.
- Various memory and performance increases throughout.

Quick Start
====
Add all the IJSVG library files into your project, import the IJSVG.h into the files you wish to use the SVG's. The easiest way to

#### Step 1 - initialize the SVG object
    IJSVG* svg = [[IJSVG alloc] initWithFilePathURL:someURLHere];
    // or with and without extension to find it within the bundle
    IJSVG* svg = [IJSVG SVGNamed:@"my_svg"]; 

#### Step 2 - grab the NSImage from it
    NSImage* svgImage = [svg imageWithSize:CGSizeMake(100.f,100.f)];
  
#Other ways of drawing

IJSVG does allow you to directly draw the SVG into any focused drawing context for example within the drawRect of an NSView...

    - (void)drawRect
    {
      [svg drawInRect:self.bounds];
    }
    
#### Helpers

IJSVG provides a very simple way of helping out the backing scale factor of the drawing context when the SVG is drawn. Due to CALayers defaulting to 1.0 when custom drawing methods are implemented, they do not know about your backing scale factor. Luckily you can simply do this:

    __block IJSVG * svg ....
    svg.renderingBackingScaleHelper = ^{
        return NSScreen.mainScreen.backingScaleFactor; // can be changed to whatever
    };
    
# Exporting

IJSVG provides a way of exporting the rendered layer tree back to an SVG file. This should be a 1:1 representation of what is rendered in CoreGraphics.

Its a simple as doing this:

    IJSVG* svg ...
    IJSVGExporter * exporter = [[IJSVGExporter alloc] initWithSVG:svg options:IJSVGExporterOptionAll];
    NSString* svgString = exporter.SVGString;
    
Which will give you back the SVG code to put into a file, there are various options you can give it for more XML manipulation such as collpasing groups and converting transform's from matrix's back to their human readable counter parts.
    
# What it supports
* Elements: def, use, g, path, clipPath, circle, elipse, rect, polyline, polygon and line (supports groups heirachy and inheritance, clip-paths etc).
* Commands: A, M, L, H, V, C, S, T, Q and Z and full support for multiple parameters of each type.
* Transformations: matrix, rotate, translate, scale and skew transformations.
* Stroking: stroking, stroke color, stroke opacity, dashed, dashed offset and phase, stroke line cap style.
* Filling: fill color, fill mode (winding rules), fill opacity, linear gradients, radial gradients and patterns.
* Color: supports all predefined colors from the SVG spec, HEX values along with RGB(A) and HSL.
* CSS: Basic embedded style sheets are support with very basic selectors.

## Credit
IJSVG is loosely based on [UIBezierPath-SVG](https://github.com/ap4y/UIBezierPath-SVG) by [ap4y](https://github.com/ap4y)

SVG icons in example found around the net, some from [Sketch App Resources](http://www.sketchappsources.com/all-svg-resource.html) all open source and free to use.
