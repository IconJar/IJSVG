IJSVG 4.0
===

IJSVG is a native Cocoa library for rendering SVGs in macOS 14.6+ applications. It uses a Core Graphics (Quartz) paint graph, with SVG filter effects powered by Core Image, Metal acceleration and SIMD CPU processing.

It also supports the `NSPasteboards` writing protocol, an IJSVG object can be put onto the pasteboard and application like Sketch and Photoshop can paste them into the document as vector objects (generated PDF's on the fly).

### What is new in IJSVG 4.0?

- A Core Graphics paint graph for drawing shapes, groups, gradients, patterns, images, clipping and masks.
- SVG filter graphs, including blur, drop shadows, blending, compositing, color adjustments, displacement, turbulence and lighting effects.
- Metal acceleration for eligible blur, shadow and arithmetic compositing operations, including batching compatible blur and shadow jobs.
- SIMD CPU paths for blur, selected color matrices and compositing, with automatic fallback to the general filter evaluator when a fast path cannot be used.
- Filter regions, named inputs and results, and `color-interpolation-filters` support for sRGB and linear RGB processing.
- SVG export preserves filter definitions and their primitive chains.
- Its almost a complete full rewrite.
- Is now fully ARC 🎉.
- Parsing and rendering is much faster.
- Support for aspect ratios and nested SVG's.
- Fixes a lot of pattern and gradient rendering.
- Fixes various clipPath issues.
- Improved masking and clipping in the Quartz renderer.
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

The framework and example application target macOS 14.6 or later. Filter rendering requires a Metal-capable device. Individual accelerated paths also check the device capabilities they need.

### Swift Package Manager

Requires Xcode 16 / Swift 6 or later and macOS 14.6 or later.

In Xcode, choose **File > Add Package Dependencies**, enter this repository's URL,
and add the **IJSVG** library product to your app target. For local development,
choose **Add Local** and select the repository root containing `Package.swift`.
Use a branch or revision until a release tag containing the manifest is available.

Import the library with `import IJSVG` in Swift or `@import IJSVG;` in Objective-C.
The package uses the existing Objective-C implementation and bundles its Metal
shader sources automatically. Package builds compile shaders on first use;
the existing Xcode framework continues to use its precompiled blur library.

Run `swift build` and `swift test` from the repository root to build and check
Swift interoperability, rendering, and shader resource loading. Shader compilation
checks run when a Metal device is available.

The existing framework project and example application remain available.
For manual integration, include the library sources and Metal shader resources,
and import IJSVG.h into the files where you use SVGs.

#### Step 1 - initialize the SVG object
    IJSVG* svg = [[IJSVG alloc] initWithFilePathURL:someURLHere];
    // or with and without extension to find it within the bundle
    IJSVG* svg = [IJSVG SVGNamed:@"my_svg"]; 

#### Step 2 - grab the NSImage from it
    NSImage* svgImage = [svg imageWithSize:CGSizeMake(100.f,100.f)];
  
# Other ways of drawing

IJSVG does allow you to directly draw the SVG into any focused drawing context for example within the drawRect of an NSView...

    - (void)drawRect
    {
      [svg drawInRect:self.bounds];
    }
    
#### Helpers

Use `renderingBackingScaleHelper` to supply the backing scale factor for custom drawing. Return the scale of the destination window or bitmap so rasterized effects, such as filters, use the intended resolution:

    IJSVG * svg = ...;
    svg.renderingBackingScaleHelper = ^{
        return 2.0; // Example: a bitmap with two pixels per point
    };
    
# Exporting

IJSVG exports its node and paint graphs back to SVG, including gradients, patterns, clipping, masks and filter definitions. Filters are serialized as SVG primitives so their effects remain editable in the exported document.

Its a simple as doing this:

    IJSVG* svg ...
    IJSVGExporter * exporter = [[IJSVGExporter alloc] initWithSVG:svg options:IJSVGExporterOptionAll];
    NSString* svgString = exporter.SVGString;
    
Which will give you back the SVG code to put into a file, there are various options you can give it for more XML manipulation such as collpasing groups and converting transform's from matrix's back to their human readable counter parts.
    
# What it supports

* Elements: svg, defs, use, g, path, clipPath, mask, image, circle, ellipse, rect, polyline, polygon and line (including group hierarchy, inheritance and nested SVGs).
* Commands: A, M, L, H, V, C, S, T, Q and Z and full support for multiple parameters of each type.
* Transformations: matrix, rotate, translate, scale and skew transformations.
* Stroking: stroking, stroke color, stroke opacity, dashed, dashed offset and phase, stroke line cap style.
* Filling: fill color, fill mode (winding rules), fill opacity, linear gradients, radial gradients and patterns.
* Color: supports all predefined colors from the SVG spec, HEX values along with RGB(A) and HSL.
* CSS: Basic embedded style sheets are support with very basic selectors.
* Filters: `feBlend`, `feColorMatrix`, `feComponentTransfer`, `feComposite`, `feConvolveMatrix`, `feDisplacementMap`, `feMorphology`, `feTile`, `feFlood`, `feOffset`, `feImage`, `feMerge`, `feGaussianBlur`, `feDropShadow`, `feTurbulence`, `feDiffuseLighting` and `feSpecularLighting`.
* Filter inputs: `SourceGraphic`, `SourceAlpha`, `BackgroundImage`, `BackgroundAlpha`, `FillPaint`, `StrokePaint` and named intermediate results.

## Filter rendering and acceleration

Filters are evaluated as a graph, with support for `filterUnits`, `primitiveUnits`, filter and primitive regions, and sRGB or linear RGB color interpolation. Core Image provides the general evaluation path. Eligible operations use dedicated Metal kernels or SIMD CPU routines. The renderer selects the path automatically according to the filter graph, image size and available capabilities, and falls back when an accelerated path is unavailable or unsuitable.

Metal paths accelerate supported Gaussian blur and shadow configurations, as well as selected arithmetic composites. SIMD routines accelerate CPU blur, selected color matrices and local or backdrop compositing. Compatible blur and shadow jobs can be batched, and reusable buffers and cached blur weights reduce repeated work.

Shapes and paths continue to draw through Core Graphics. Filtered content is rasterized at the rendering scale and composited back into the drawing context.

## Credit
IJSVG is loosely based on [UIBezierPath-SVG](https://github.com/ap4y/UIBezierPath-SVG) by [ap4y](https://github.com/ap4y)

SVG icons in example found around the net, some from [Sketch App Resources](http://www.sketchappsources.com/all-svg-resource.html) all open source and free to use.
