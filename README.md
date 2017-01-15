IJSVG
=====
IJSVG is a Mac OSX 10.7+ COCOA library for rendering SVG's within your COCOA applications, its extremely fast and native.

Orignaly written for IconJar (in development)

It also supports the NSPasteboards writing protocol, an IJSVG object can be put onto the pasteboard and application like Sketch and Photoshop can paste them into the document as vector objects (generated PDF's on the fly).

Quick Start
====
Add all the IJSVG library files into your project, import the IJSVG.h into the files you wish to use the SVG's. The easiest way to

#### Step 1 - initialize the SVG object
    IJSVG * svg = [[IJSVG alloc] initWithFilePathURL:someURLHere];
    // or with and without extension to find it within the bundle
    IJSVG * svg = [IJSVG svgNamed:@"my_svg"]; 

#### Step 2 - grab the NSImage from it
    NSImage * svgImage = [svg imageWithSize:NSMakeSize(100.f,100.f)];
  
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
        return [svg computeBackingScale:someView.window.backingScaleFactor];
    };
    
# What it supports
* Elements: def, use, g, path, clipPath, circle, elipse, rect, polyline, polygon and line (supports groups heirachy and inheritance, clip-paths etc)
* Commands: A, M, L, H, V, C, S, T, Q and Z and full support for multiple parameters of each type
* Transformations: matrix, rotate, translate, scale and skew transformations
* Stroking: stroking, stroke color, stroke opacity, dashed, dashed offset and phase, stroke line cap style
* Filling: fill color, fill mode (winding rules), fill opacity, linear gradients, radial gradients and patterns
* Color: supports all predefined colors from the SVG spec and hex values
* Caching: has basic caching implemenation
* CSS: Basic embedded style sheets are support with very basic selectors
* Switches and foreign objects, there is a delegate you can implement to handle foreign objects, once you say you can handle it, its up to you to handle the SVG as IJSVG will stop parsing the document once you have told it you will handle it

## Credit
IJSVG is loosely based on [UIBezierPath-SVG](https://github.com/ap4y/UIBezierPath-SVG) by [ap4y](https://github.com/ap4y)

SVG icons in example found around the net, some from [Sketch App Resources](http://www.sketchappsources.com/all-svg-resource.html) all open source and free to use
