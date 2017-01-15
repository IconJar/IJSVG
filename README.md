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
    
# Exporting
#### Yes, thats right... CALayers -> SVG (whos idea was this?!)

IJSVG provides a way of exporting the rendered layer tree back to an SVG file. This isnt 100% perfect but it does a good job of generating what IJSVG renders (have yet to find an issue).

Its a simple as doing this:

    IJSVG * svg ...
    IJSVGExporter * exporter = [[IJSVGExporter alloc] initWithSVG:svg options:IJSVGExporterOptionAll];
    NSString * svgString = [exporter SVGString];
    
Which will give you back the SVG code to put into a file, there are various options you can give it for more XML manipulation such s collpasing groups and converting transform's from matrix's back to their human readable counter parts.

The fun part is you can actually create an SVG object from a IJSVGLayer and work with them without needing to load a file, for example:

    // create group layer and a shape layer (subclass of CAShapeLayer)
    IJSVGGroupLayer * baseSVGGroup = ....
    IJSVGShapeLayer * shapeLayer = ....
    [baseSVGGroup addSublayer:shapeLayer];
    
    // create the SVG - note the viewbox!
    IJSVG * svg = [[IJSVG alloc] initWithSVGLayer:baseSVGGroup viewBox:NSMakeRect(0.f, 0.f, 50.f, 50.f)];
    .... do what you want
    
and now you would have a usuable SVG to render where ever you would like and more importantly you can now export that back to an SVG file.

All layers must be of generic type IJSVGLayer or IJSVGShapeLayer, it will throw an exception if you do not use these. Also if you go out the scope of what those layers can do, it wont render nor will it export (get malformed results).
    
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
