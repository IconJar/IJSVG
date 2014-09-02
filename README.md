IJSVG
=====
IJSVG is a Mac OSX 10.7+ COCOA library for rendering SVG's within your COCOA applications, its extremely fast and native.

Quick Start
====
Add all the IJSVG library files into your project, import the IJSVG.h into the files you wish to use the SVG's. The easiest way to

#### Step 1 - initialize the SVG object
    IJSVG * svg = [[IJSVG alloc] initWithFilePathURL:someURLHere];

#### Step 2 - grab the NSImage from it
    NSImage * svgImage = [svg imageWithSize:NSMakeSize(100.f,100.f)];
  
#Other ways of drawing

IJSVG does allow you to directly draw the SVG into any focused drawing context for example within the drawRect of an NSView...

    - (void)drawRect
    {
      [svg drawInRect:self.bounds] 
    }
    
# What it supports
* Elements: g, path, circle, elipse, rect, polyline, polygon and line (supports groups heirachy and inheritance)
* Commands: M, L, H, V, C, S, T, Q and Z (have yet to look at A) and full support for multiple parameters of each type
* Transformations: matrix, rotate (not around a point - currently), translate, scale transformations
* Stroking: stroking (not dashed - currently), stroke color, stroke opacity
* Filling: fill color, fill mode ( winding rules ), fill opacity
* Color: supports all predefined colors from the SVG spec and hex values
* Caching: has basic caching implemenation


# What doesnt work
* Animation
* The A command
* Transform for skewX and skewY
* Transform for rotate around a point
* Dashed strokes
* If the SVG has a switch in it from other application (Adobe products) it will fail to find a valid SVG (this is being worked on)

## Credit
IJSVG is loosely based on [UIBezierPath-SVG](https://github.com/ap4y/UIBezierPath-SVG) by [ap4y](https://github.com/ap4y)
