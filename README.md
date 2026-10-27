IJSVG 7.0
===

IJSVG is an Objective C library for drawing SVGs on macOS 14.6, iOS 16, tvOS 16, and visionOS 1 or later, without AppKit or UIKit dependencies. It uses Core Graphics for drawing and Core Image for SVG filters, with Metal and SIMD used to speed up supported effects.

### What is new in IJSVG 7.0?

- Region queries expose link targets and node bounds before drawing, with local,
  SVG user and destination coordinate spaces for measurements and overlays.
- CSS filters support color adjustments, blur and drop shadows, including ordered
  chains mixed with local SVG filter references and export as SVG primitives.
- Rendering quality modes now control image interpolation, filter coverage
  sampling and filter output interpolation, with faster options for thumbnails.
- Parsing, initial drawing and repeated filter rendering use fewer allocations
  and more cached work. Fixes cover nested pattern filter scaling, filter extents,
  SVG loading and a memory leak.

See the region and rendering quality examples below, and the supported CSS
features and limitations under **What it supports**.

### Migration from IJSVG 6

This release changes the node model for apps that inspect or construct SVG text:

- `IJSVGText.textContent` now contains `IJSVGTextContent` entries instead of mixed
  strings and text nodes. Inspect each entry's `kind`, then read `string` or `span`.
  Construct entries with `initWithString:` or `initWithSpan:`; do not insert raw
  strings or nodes into the array.
- `IJSVGAnchor` now inherits from `IJSVGGroup`. Anchors within text use
  `IJSVGTextAnchor`, which inherits from `IJSVGText`. Both expose a `reference`;
  code inspecting anchors must account for both classes.
- `IJSVGNode.nodeTraits` exposes structural type flags inherited by subclasses.
  These are separate from the existing mutable `traits` flags for style behavior.

For example, replace a raw string in `textContent` with a typed entry:

```objc
textNode.textContent = @[
    [[IJSVGTextContent alloc] initWithString:@"Hello"]
];
```

The Core Graphics loading and drawing APIs and platform minimums remain the same
as IJSVG 6. Apps using only those APIs do not need the text-node migration above.

### What changed in IJSVG 6.0?

IJSVG 6 adds iOS, iPadOS, tvOS, and visionOS support using a shared Core Graphics
API. Native UI wrappers have been removed so the framework has no AppKit or
UIKit dependency. This release includes breaking API changes.

### Breaking changes in IJSVG 6.0

Native UI integration has been removed: `IJSVGView`, `IJSVGImageRep`, the
`NSImage` category, `NSPasteboardWriting`, and loading from asset catalogs. Load
asset data in your app and pass it to `init(data:)` instead.

Raster APIs use `CGImage` throughout. Use `init(cgImage:)` and
`renderCGImage(size:flipped:)` instead of the convenience APIs for native images.
`IJSVGImage.CGImage` and filter primitive `image` retain their assigned pixels;
Objective C callers still release their own Create/Copy references.

Drawing requires an explicit `CGContext`. Offscreen scale defaults to 1 on
every platform; use `renderingBackingScaleHelper` to request a different scale.

### Migration from versions before IJSVG 5

The following changes were introduced in IJSVG 5 and still apply.

- Supported SVG element types have dedicated node classes, such as `IJSVGRect`,
  `IJSVGCircle`, `IJSVGPath` and `IJSVGGroup`. Shared behavior lives in their base
  classes, and properties live on the classes that use them. Code that inspects,
  constructs or subclasses nodes should use the appropriate node class rather
  than assuming every property is available on `IJSVGNode`.
- Colors are exposed as `CGColorRef` in Objective C and `CGColor` in Swift,
  replacing `NSColor` in color properties, helpers and callbacks. This includes
  fills, strokes, current color, backgrounds, gradient stops and color replacement.
  Convert an AppKit color with `.CGColor` in Objective C or `.cgColor` in Swift.
- XML parsing no longer loads DTDs or expands custom entities. Standard XML
  escapes and numeric character references remain supported.
- The default color space is now sRGB instead of device RGB. This applies to
  colors, gradients and raster output.
  Exported pixels can differ from earlier releases because the destination now
  has a defined color profile. `IJSVGColor.defaultColorSpace` returns shared sRGB.

Color setters retain the supplied color. Gradient color arrays contain bridged
`CGColor` objects instead of `NSColor` objects. Code using Core Graphics creation
functions in Objective C must still release its own references after assigning
them. UI tint inputs and image wrappers belong in the consuming app.

### Rendering and export

Rendering and SVG export have received fixes across gradients, patterns, masks,
clipping, text, markers and filters. The node tree remains editable and can still
be exported to SVG.

Raster rendering also accepts an explicit RGB destination color space through
`renderCGImage(size:flipped:colorSpace:)` in Swift or
`newCGImageRefWithSize:flipped:colorSpace:error:` in Objective C. Pass sRGB for
bitmap exports or Display P3 when that destination is needed. The overload
preserves backing scale and flipping and reports unsupported color spaces or
bitmap creation failures through the existing error API.

SVG and CSS support is still incomplete, and some artwork may render differently
from a browser. Please report rendering or export issues with a small example SVG.
Performance improvements depend on the document and the effects it uses.

Quick Start
====

### Supported platforms

| Platform | Framework and Swift package | Example minimum | Example scheme |
| --- | --- | --- | --- |
| macOS | 14.6 | 14.6 | `IJSVGExample` |
| iOS and iPadOS | 16.0 | 17.0 | `IJSVGiOSExample` |
| tvOS | 16.0 | 17.0 | `IJSVGtvOSExample` |
| visionOS | 1.0 | 1.0 | `IJSVGvisionOSExample` |

The framework uses the same graphics APIs on every supported platform.
Filter rendering requires a device that supports Metal. Individual accelerated
paths also check the capabilities they need. watchOS is not supported.

### Swift Package Manager

Requires Xcode 16 / Swift 6 or later. The deployment minimums above apply to
both the Swift package and the Xcode framework.

In Xcode, choose **File > Add Package Dependencies**, enter this repository's URL,
and add the **IJSVG** library product to your app target. For local development,
choose **Add Local** and select the repository root containing `Package.swift`.
Select version **7.0.0** or later for the features documented here. Review the breaking changes
above when upgrading from an earlier major version.

Import the library with `import IJSVG` in Swift or `@import IJSVG;` in Objective-C.
The package uses the existing Objective-C implementation and bundles its Metal
shader sources automatically. Package builds compile shaders on first use;
the existing Xcode framework continues to use its precompiled blur library.

Run `swift build` and `swift test` from the repository root to build and check
the XCTest and Swift Testing coverage for API behavior, rendering, and shader
resource loading. Shader compilation checks run when a Metal device is available.

The existing framework project and example applications remain available.
Select the `IJSVGiOSExample` scheme for iPhone or iPad, or `IJSVGtvOSExample`
with an Apple TV destination. Use `IJSVGvisionOSExample` with an Apple Vision Pro
destination. These schemes share one app target and display the bundled
`car.svg`. Select the matching simulator or device and run the scheme.

For manual integration, include the library sources and Metal shader resources,
and import IJSVG.h into the files where you use SVGs.

### Shared graphics API

The framework uses Foundation, Core Graphics, Core Text, ImageIO, Core Image,
Metal, and Accelerate. It does not depend on AppKit or UIKit. The framework
project supports macOS, iOS, tvOS, and visionOS, including device and Simulator
destinations.

```swift
let svg = try IJSVG(parsing: svgText)
svg.renderingBackingScaleHelper = { 2 }
let pixels = try svg.renderCGImage(size: CGSize(width: 32, height: 32), flipped: true)
// pixels is a 64 × 64 CGImage. Wrap it for display in your app if needed.
let fromPixels = IJSVG(cgImage: pixels)
```

Use `flipped: true` when displaying the resulting `CGImage` in SwiftUI, as the
examples do. When drawing into your own context, choose the orientation that
matches its coordinate system.

Use `drawInRect:context:` to draw into a supplied Core Graphics context. Your app
owns that context's coordinate system and display scale. ImageIO decodes raster
inputs and applies EXIF orientation. Embedded SVGs retain their vector document
and are rendered at the destination resolution. `IJSVGImage.intrinsicSize` is
measured in pixels for raster inputs; it no longer depends on the DPI of native images.

Support for iOS, tvOS, and visionOS requires IJSVG 6.0.0 or later.

### Swift loading and optional values

Use the throwing initializers to receive parsing and file errors:

```swift
let svg = try IJSVG(contentsOf: fileURL)
let parsed = try IJSVG(parsing: svgText)
let decoded = try IJSVG(data: svgData)
let fromPath = try IJSVG(filePath: filePath)
```

The convenience initializer `IJSVG(svgString:)` returns an optional when error
information is not needed. Metadata such as `title` and `desc`
and exporter delegates are optional and can be cleared with `nil`.

These annotations keep Objective C selectors unchanged. Swift callers of the
previous error accepting initializers should use the names above. Optional
properties now require normal optional handling instead of implicit unwrapping.

### Swift rendering and Core Graphics ownership

```swift
let cgImage = try svg.renderCGImage(size: CGSize(width: 64, height: 64), flipped: true)
let pdf = svg.pdfData()
let checkedPDF = try svg.renderPDF()
```

Use `pdfData(in:)` or `renderPDF(in:)` to specify the PDF drawing rectangle.
The `renderPDF` methods throw when the underlying method reports an error,
even if it also returns data. These annotations do not add rendering validation
or change when the Objective C implementation reports errors.

The Objective C `newCGImageRefWithSize:flipped:error:` method imports as
`renderCGImage(size:flipped:)` in Swift. Convenience methods for native images are no
longer provided.

Core Graphics results use Swift memory management, including rendered images,
`IJSVGUtils.flippedPath(_:)`, `IJSVGCommand.makePath(commands:)`, and shared color
spaces. Do not call `takeRetainedValue()` or `takeUnretainedValue()` on these results.
Objective C callers still release newly created objects and do not release borrowed
node image, path, gradient, or shared color space references.

Parser base URLs can be `nil`. Missing node relationships, paint overrides, image
source data, filter inputs, and unsuccessful color lookups are optional in Swift.
Collections that are always initialized remain nonoptional.

### Artwork bounds and fitting

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

### Link regions and node bounds

Query anchor regions before drawing to place link overlays in the same rectangle:

```swift
let drawingRect = CGRect(x: 0, y: 0, width: 240, height: 160)
let links = svg.regions(in: drawingRect)
for region in links {
    // Place an overlay at region.rect; resolve region.value in your app.
    print(region.rect, region.value ?? "")
}
```

Each rendered anchor instance returns an `IJSVGRegion` in painting order. Its
`value` preserves the original `href`, including relative URLs and fragments.
Rectangles use SVG coordinates with Y increasing downward. Bounds include
transforms and viewport clipping, but are conservative for curved clips and
masks and exclude filters and occlusion by other artwork. The app owns hit
testing, URL resolution and navigation.

For general node measurements, use
`regions(in:coordinateSpace:nodeTypes:)`,
`regions(for:in:coordinateSpace:)` or
`regions(forIdentifier:in:coordinateSpace:)` in Swift. For example, in Objective C:

```objc
NSArray<IJSVGRegion*>* regions = [svg regionsForIdentifier:@"badge"
                                                 inRect:drawingRect
                                        coordinateSpace:IJSVGRegionCoordinateSpaceDestination];
```

Choose local coordinates for geometry before the node transform (including child
transforms), user coordinates for geometry in the outer SVG, or destination
coordinates for geometry mapped into the drawing rectangle. Only destination
bounds are clipped to that rectangle. The drawing size resolves relative units
in every coordinate space. General node bounds include strokes and exclude
filters and masks; local bounds ignore ancestor clipping. A `nil` node type list
includes all rendered nodes, while an empty list includes none.

Regions expose the node type, source node, identifier, coordinate space and
`instanceIndex`, which distinguishes rendered instances sharing a node or ID.

### Rendering quality

Full resolution is the default. Set rendering options before drawing or exporting
a raster image to choose a faster mode:

```objc
IJSVGRenderingOptions* options = [[IJSVGRenderingOptions alloc] init];
options.renderQuality = kIJSVGRenderQualityOptimized;
svg.renderingOptions = options;
```

| Quality | Image interpolation | Filter coverage |
| --- | --- | --- |
| `kIJSVGRenderQualityFullResolution` | High | Full sampling for nested filters |
| `kIJSVGRenderQualityOptimized` | Medium | Local sampling for thumbnails |
| `kIJSVGRenderQualityLow` | Low | No additional coverage samples |

The setting also controls filter output interpolation. Faster modes can change
edge pixels, so use full resolution where fidelity is more important than speed.
Document `image-rendering` hints can also affect image sampling.

#### Step 1 - initialize the SVG object
    IJSVG* svg = [[IJSVG alloc] initWithFilePathURL:someURLHere];
    // or with and without extension to find it within the bundle
    IJSVG* svg = [IJSVG SVGNamed:@"my_svg"]; 

#### Step 2: render a CGImage
    CGImageRef svgImage = [svg newCGImageRefWithSize:CGSizeMake(100.f, 100.f) flipped:NO error:nil];
    // Use or wrap the image, then release your reference.
    CGImageRelease(svgImage);
  
# Other ways of drawing

Draw directly into a Core Graphics context supplied by your app:

    [svg drawInRect:bounds context:context];

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
CGImageRef image = [svg newCGImageRefWithSize:CGSizeMake(240, 80) flipped:NO error:nil];
// Use the rendered image.
CGImageRelease(image);
```

IJSVG uses fonts installed on the system and falls back to another font if one
is missing, so text can look different on another device. Use `textPath` with an
`href` pointing to a path ID to place text along a curve. Use `tspan` to change
the style or position of part of the text.

# What it supports

* Elements: svg, defs, a, use, symbol, g, switch, path, clipPath, mask, image, circle, ellipse, rect, polyline, polygon, line, marker, text, tspan and textPath (including group hierarchy, inheritance and nested SVGs). Conditional processing includes `systemLanguage` and `requiredExtensions`.
* Commands: A, M, L, H, V, C, S, T, Q and Z and full support for multiple parameters of each type.
* Transformations: matrix, rotate, translate, scale and skew transformations, plus CSS `transform-origin` and `transform-box`.
* Stroking: stroke color and opacity, dash arrays and offsets, line caps, miter/round/bevel joins, miter limits, `pathLength` calibration and `vector-effect="non-scaling-stroke"`.
* Filling: fill color, fill mode (winding rules), fill opacity, linear gradients, radial gradients and patterns. Gradients support `color-interpolation="sRGB"` and `"linearRGB"`, including repeat/reflect spread modes; `auto` uses sRGB.
* Markers: `marker`, `marker-start`, `marker-mid` and `marker-end` on paths, lines, polylines and polygons. Supports custom child artwork, `markerUnits`, reference points, marker dimensions, `viewBox`, clipping, fixed angles, `auto` and `auto-start-reverse` orientation, and `context-fill` / `context-stroke` paints.
* Color: named SVG colors, HEX, RGB(A), HSL(A), OKLCH and `currentColor`.
* CSS cascade: embedded style sheets and inline styles, with specificity, source order and `!important`.
* CSS selectors: type, class, ID and universal selectors, descendant and child combinators, and adjacent and general sibling combinators. Attribute selectors support presence, equality, word, language prefix, prefix, suffix and substring matching, with `i` and `s` case flags. Namespace selectors and top level `@namespace` declarations are supported.
* CSS pseudo-classes: `:root`, `:scope`, `:empty`, `:lang()`, `:first-child`, `:last-child`, `:only-child`, their `of-type` variants, and `:nth-child()`, `:nth-last-child()`, `:nth-of-type()` and `:nth-last-of-type()`. Child index selectors support `of <selector-list>`. Logical selectors include `:is()`, `:where()`, `:not()` and `:has()` with relative selectors.
* CSS values and geometry: custom properties with `var()`, `calc()`, `min()`, `max()` and `clamp()` in supported length values, CSS geometry properties, and path data through `d: path("...")` or `d: none`.
* CSS media queries: `<style media="...">` and `@media` blocks, including nested blocks. Queries support `all`, `screen` and `print` types, comma separated alternatives, `and`, leading `not` and `only`, viewport width and height, and portrait or landscape orientation. Width and height accept exact values, `min-` and `max-` prefixes, and feature first comparisons such as `(width >= 600px)`.
* Context paints: `context-fill` and `context-stroke` in markers and `<use>` instances, including solid colors, gradients, patterns and nested uses. Context paint servers retain the referencing element's coordinate space.
* Rendering hints: `shape-rendering` (`auto`, `optimizeSpeed`, `crispEdges`, `geometricPrecision`) and `image-rendering` (`auto`, `optimizeSpeed`, `optimizeQuality`), including inherited and CSS values. Shape speed/crispness hints disable antialiasing; image speed uses nearest-neighbor sampling and quality uses high-quality interpolation.
* Painting and compositing: `paint-order`, group opacity, `mix-blend-mode`, `isolation`, clipping, alpha/luminance masks, `display` and `visibility`.
* Text: system font selection and fallback, font shorthand and OpenType settings, character positioning and rotation, `textLength` / `lengthAdjust`, text on paths, baseline alignment, spacing, bidirectional and vertical text, decorations, whitespace handling and wrapping with `inline-size`.
* Filters: `feBlend`, `feColorMatrix`, `feComponentTransfer`, `feComposite`, `feConvolveMatrix`, `feDisplacementMap`, `feMorphology`, `feTile`, `feFlood`, `feOffset`, `feImage`, `feMerge`, `feGaussianBlur`, `feDropShadow`, `feTurbulence`, `feDiffuseLighting` and `feSpecularLighting`.
* CSS filter functions: `blur()`, `brightness()`, `contrast()`, `drop-shadow()`, `grayscale()`, `hue-rotate()`, `invert()`, `opacity()`, `saturate()` and `sepia()`, including ordered chains mixed with local `url(...)` filters. CSS functions use sRGB and export as SVG primitives. Numeric amounts support percentages and CSS math expressions. Blur and shadow lengths support absolute units, `em`, `ex` and CSS math. Shadows default to the element color. Hue rotation supports `deg`, `rad`, `grad`, `turn` and calculated angles.
* Filter inputs: `SourceGraphic`, `SourceAlpha`, `BackgroundImage`, `BackgroundAlpha`, `FillPaint`, `StrokePaint` and named intermediate results.

### Known limitations

The list above describes implemented features, not complete SVG or CSS conformance.
IJSVG is a static artwork renderer; it does not provide a browser DOM, scripting,
interactive document behavior or SVG/CSS animation playback.

* CSS support is limited to the selectors and at-rules listed above. Interactive pseudo-classes such as `:hover` and `:focus`, pseudo-elements, nested `:has()`, and the column combinator are not supported. `@supports`, `@import`, `@font-face`, `@layer` and CSS nesting are not implemented.
* Media queries are evaluated during parsing against the document viewport using the `screen` media type, including when the artwork is later exported to PDF. Drawing at a different size does not reevaluate the stylesheet. Supported media lengths include `px`, `in`, `pt`, `pc`, `cm`, `mm`, `em` and `rem`, with a fixed 16px basis for `em` and `rem`. Other media features such as resolution, aspect ratio and user preferences, general `or` expressions, and reversed or chained range comparisons are not implemented.
* Fragment references such as `href="#symbol"` are supported, but external SVG document references such as `href="icons.svg#symbol"` are not resolved. Ordinary `<image>` loading does not currently resolve relative paths against the source document URL.
* `color-interpolation` controls gradient stop interpolation. Per-element linear RGB compositing/blending is not implemented; general compositing still uses the drawing context's color space. Filter interpolation remains controlled separately by `color-interpolation-filters`.
* `<foreignObject>` content is skipped. HTML layout and embedded web fonts are not supported; text uses locally available fonts.

Useful areas for further compatibility work include the remaining CSS selectors and at-rules,
resource URL resolution, and per-element compositing color spaces. Rendering
and export edge cases still need testing even for
features listed as supported.

## Filter rendering and acceleration

Filters are evaluated as a graph, with support for `filterUnits`, `primitiveUnits`, filter and primitive regions, and sRGB or linear RGB color interpolation. Core Image provides the general evaluation path. Eligible operations use dedicated Metal kernels or SIMD CPU routines. The renderer selects the path automatically according to the filter graph, image size and available capabilities, and falls back when an accelerated path is unavailable or unsuitable.

Metal paths accelerate supported Gaussian blur and shadow configurations, as well as selected arithmetic composites. SIMD routines accelerate CPU blur, selected color matrices and local or backdrop compositing. Compatible blur and shadow jobs can be batched, and reusable buffers and cached blur weights reduce repeated work.

Shapes and paths continue to draw through Core Graphics. Filtered content is rasterized at the rendering scale and composited back into the drawing context.

## Credit
IJSVG is loosely based on [UIBezierPath-SVG](https://github.com/ap4y/UIBezierPath-SVG) by [ap4y](https://github.com/ap4y)

SVG icons in example found around the net, some from [Sketch App Resources](http://www.sketchappsources.com/all-svg-resource.html) all open source and free to use.
