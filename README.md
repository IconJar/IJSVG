IJSVG
=====
IJSVG is a Mac OSX 10.7+ COCOA library for rendering SVG's within your COCOA applications, its extremely fast and native.

Orignaly written for IconJar (in development)

It takes SVG's files and makes pretty pictures like this:

![SVG Example](http://cl.ly/image/0G3S3Q1s271Z/Screen%20Shot%202014-09-02%20at%2018.17.52.png)

It also supports the NSPasteboards writing protocol, an IJSVG object can be put onto the pasteboard and application like Sketch and Photoshop can paste them into the document as vector objects (generated PDF's on the fly).

Example app
====
There is an example application provided, it will generate this test bed for SVG's

![SVG Example App](http://cl.ly/image/2j1T2c351Z22/Screen%20Shot%202014-09-05%20at%2017.50.50.png)

The example screen contains six SVG's rendered in individual views, from left to right.
* First example shows transforms and colours
* Second example shows linear gradients
* Third example shows defined paths being reused
* Forth example shows transforms such as translate being used and stroke colours
* Fith example shows clip paths being used
* Sixth example shows dashed stroke array's being used

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
    
# What it supports
* Elements: def, use, g, path, clipPath, circle, elipse, rect, polyline, polygon and line (supports groups heirachy and inheritance, clip-paths etc)
* Commands: A, M, L, H, V, C, S, T, Q and Z and full support for multiple parameters of each type
* Transformations: matrix, rotate (not around a point - currently), translate, scale transformations
* Stroking: stroking, stroke color, stroke opacity, dashed, dashed offset and phase, stroke line cap style
* Filling: fill color, fill mode (winding rules), fill opacity, linear gradients (rudimentary radial gradients)
* Color: supports all predefined colors from the SVG spec and hex values
* Caching: has basic caching implemenation
* Switches and foreign objects, there is a delegate you can implement to handle foreign objects, once you say you can handle it, its up to you to handle the SVG as IJSVG will stop parsing the document once you have told it you will handle it

## Credit
IJSVG is loosely based on [UIBezierPath-SVG](https://github.com/ap4y/UIBezierPath-SVG) by [ap4y](https://github.com/ap4y)

SVG icons in example found around the net, some from [Sketch App Resources](http://www.sketchappsources.com/all-svg-resource.html) all open source and free to use
