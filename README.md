IJSVG 4.1
===

IJSVG is a Cocoa library for drawing SVGs in macOS 14.6 and later. It uses Core Graphics for drawing and Core Image for SVG filters, with Metal and SIMD used to speed up supported effects.

You can also copy an IJSVG object to the pasteboard. It provides PDF data so apps such as Sketch and Photoshop can paste the artwork as vectors.

### What is new in IJSVG 4.1.9?

- SVG markers with custom artwork at the start, middle and end of paths.
- Automatic marker orientation, including `auto-start-reverse`, and `context-fill` / `context-stroke` colours.
- Faster rendering and export for SVGs with repeated markers.

### What is new in IJSVG 4.1.0?

- Text support, including `text`, `tspan` and `textPath`.
- Font selection and fallback, text spacing, alignment, rotation and decorations.
- Text wrapping, vertical text and text that follows a path.
- Support for CSS font shorthand, `textLength` and `lengthAdjust`.
- Faster parsing of paths, CSS rules and repeated elements, with less memory used for CSS matching.
- More Objective C tests for text, parsing and drawing.

In our Release benchmarks, the latest parser changes cut parsing time by about
98% for complex CSS selectors, 38% for overlapping CSS rules and 13% for repeated
attributes. The data used for CSS matching took about 81% less memory.
Results depend on the SVG. These tests compare with commit `0afcd11`, not 4.0.2,
and cover CPU parsing with shader compilation excluded from both builds.

### Introduced in IJSVG 4.0

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
Select version **4.1.9** or later to include SVG text, marker support and the latest rendering improvements.

Import the library with `import IJSVG` in Swift or `@import IJSVG;` in Objective-C.
The package uses the existing Objective-C implementation and bundles its Metal
shader sources automatically. Package builds compile shaders on first use;
the existing Xcode framework continues to use its precompiled blur library.

Run `swift build` and `swift test` from the repository root to build and check
the Objective-C XCTest coverage for API behavior, rendering, and shader resource loading. Shader compilation
checks run when a Metal device is available.

The existing framework project and example application remain available.
For manual integration, include the library sources and Metal shader resources,
and import IJSVG.h into the files where you use SVGs.

### Swift loading and optional values

Use the throwing initializers to receive parsing and file errors:

```swift
let svg = try IJSVG(contentsOf: fileURL)
let parsed = try IJSVG(parsing: svgText)
let decoded = try IJSVG(data: svgData)
let fromPath = try IJSVG(filePath: filePath)
```

The convenience initializer `IJSVG(svgString:)` returns an optional when error
information is not needed. Metadata such as `title` and `desc`, view SVG content,
and exporter delegates are optional and can be cleared with `nil`.

These annotations keep Objective C selectors unchanged. Swift callers of the
previous error accepting initializers should use the names above. Optional
properties now require normal optional handling instead of implicit unwrapping.

### Swift rendering and Core Graphics ownership

```swift
let image = try svg.renderImage(size: CGSize(width: 64, height: 64))
let flipped = try svg.renderImage(size: CGSize(width: 64, height: 64), flipped: true)
let fitted = try svg.renderImage(fitting: CGSize(width: 64, height: 64), flipped: false)
let cgImage = try svg.renderCGImage(size: CGSize(width: 64, height: 64), flipped: false)
let pdf = svg.pdfData()
let checkedPDF = try svg.renderPDF()
```

Use `pdfData(in:)` or `renderPDF(in:)` to specify the PDF drawing rectangle.
The `renderPDF` methods throw when the underlying method reports an error,
even if it also returns data. These annotations do not add rendering validation
or change when the Objective C implementation reports errors.

The Objective C selectors are unchanged. Swift calls to the image methods with
an error parameter now use `renderImage`, and `newCGImageRef` uses `renderCGImage`.
The existing `image(with:)` convenience methods remain available.

Core Graphics results use Swift memory management, including rendered images,
`IJSVGUtils.flippedPath(_:)`, `IJSVGCommand.makePath(commands:)`, and shared color
spaces. Do not call `takeRetainedValue()` or `takeUnretainedValue()` on these results.
Objective C callers still release newly created objects and do not release borrowed
node image, path, gradient, or shared color space references.

Parser base URLs can be `nil`. Missing node relationships, paint overrides, image
source data, filter inputs, and unsuccessful color lookups are optional in Swift.
Collections that are always initialized remain nonoptional.

### Artwork bounds and fitting (4.0.2)

After changing stroke styles or path geometry, fit overflowing artwork into the
original viewBox without changing the output dimensions or aspect ratio:

```objc
CGRect bounds = [svg artworkBounds];
[svg fitArtworkToViewBox:YES];
// Remove the fitting scale when restoring the original artwork.
[svg fitArtworkToViewBox:NO];
```

Swift callers use `svg.artworkBounds()` and
`svg.fitArtworkToViewBox(enabled: true)`. Call fitting again after subsequent
style or geometry changes. Repeated calls replace the fitting transform rather
than accumulating scale. Fitting preserves the original canvas center.

Bounds include resolved fills, strokes, caps, joins, dashes, and transforms.
They are conservative geometry bounds, not a pixel tight measurement of masks or
clipping. Filter effects are excluded.

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

Marker instances are exported as positioned vector artwork, preserving their appearance.

To export an SVG:

    IJSVG* svg ...
    IJSVGExporter * exporter = [[IJSVGExporter alloc] initWithSVG:svg options:IJSVGExporterOptionAll];
    NSString* svgString = exporter.SVGString;
    
This gives you an SVG string to save to a file. Export options include collapsing groups and converting transform matrices into individual transforms.
    
### SVG text

Text uses the same loading and drawing APIs as other SVG content:

```objc
NSString* source = @"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 240 80'>"
    "<text x='20' y='50' font-family='Helvetica' font-size='32' fill='#333'>"
    "Hello <tspan fill='#087ea4'>SVG</tspan></text></svg>";
IJSVG* svg = [[IJSVG alloc] initWithSVGString:source];
NSImage* image = [svg imageWithSize:CGSizeMake(240, 80)];
```

IJSVG uses fonts installed on the system and falls back to another font if one
is missing, so text can look different on another Mac. Use `textPath` with an
`href` pointing to a path ID to place text along a curve. Use `tspan` to change
the style or position of part of the text.

# What it supports

* Elements: svg, defs, use, g, path, clipPath, mask, image, circle, ellipse, rect, polyline, polygon, line, marker, text, tspan and textPath (including group hierarchy, inheritance and nested SVGs).
* Commands: A, M, L, H, V, C, S, T, Q and Z and full support for multiple parameters of each type.
* Transformations: matrix, rotate, translate, scale and skew transformations.
* Stroking: stroking, stroke color, stroke opacity, dashed, dashed offset and phase, stroke line cap style.
* Filling: fill color, fill mode (winding rules), fill opacity, linear gradients, radial gradients and patterns.
* Markers: `marker`, `marker-start`, `marker-mid` and `marker-end` on paths, lines, polylines and polygons. Supports custom child artwork, `markerUnits`, reference points, marker dimensions, `viewBox`, clipping, fixed angles, `auto` and `auto-start-reverse` orientation, and `context-fill` / `context-stroke` paints.
* Color: supports all predefined colors from the SVG spec, HEX values along with RGB(A) and HSL.
* CSS: Embedded style sheets and inline styles, with type, class, ID and universal selectors, descendant and child combinators, and adjacent and general sibling combinators. Declaration resolution accounts for specificity, source order and `!important`.
* Filters: `feBlend`, `feColorMatrix`, `feComponentTransfer`, `feComposite`, `feConvolveMatrix`, `feDisplacementMap`, `feMorphology`, `feTile`, `feFlood`, `feOffset`, `feImage`, `feMerge`, `feGaussianBlur`, `feDropShadow`, `feTurbulence`, `feDiffuseLighting` and `feSpecularLighting`.
* Filter inputs: `SourceGraphic`, `SourceAlpha`, `BackgroundImage`, `BackgroundAlpha`, `FillPaint`, `StrokePaint` and named intermediate results.

## Filter rendering and acceleration

Filters are evaluated as a graph, with support for `filterUnits`, `primitiveUnits`, filter and primitive regions, and sRGB or linear RGB color interpolation. Core Image provides the general evaluation path. Eligible operations use dedicated Metal kernels or SIMD CPU routines. The renderer selects the path automatically according to the filter graph, image size and available capabilities, and falls back when an accelerated path is unavailable or unsuitable.

Metal paths accelerate supported Gaussian blur and shadow configurations, as well as selected arithmetic composites. SIMD routines accelerate CPU blur, selected color matrices and local or backdrop compositing. Compatible blur and shadow jobs can be batched, and reusable buffers and cached blur weights reduce repeated work.

Shapes and paths continue to draw through Core Graphics. Filtered content is rasterized at the rendering scale and composited back into the drawing context.

## Credit
IJSVG is loosely based on [UIBezierPath-SVG](https://github.com/ap4y/UIBezierPath-SVG) by [ap4y](https://github.com/ap4y)

SVG icons in example found around the net, some from [Sketch App Resources](http://www.sketchappsources.com/all-svg-resource.html) all open source and free to use.
