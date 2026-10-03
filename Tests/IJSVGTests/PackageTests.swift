import AppKit
import IJSVG
import IJSVGTestSupport
import Metal
import Testing

@Test func rendersSVGFromSwift() throws {
    let svg = try #require(IJSVG(svgString: """
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
            <rect width="16" height="16" fill="red"/>
        </svg>
        """))
    #expect(svg.size == CGSize(width: 16, height: 16))
    let image = try #require(svg.image(with: CGSize(width: 32, height: 32)))
    #expect(image.size == CGSize(width: 32, height: 32))
    let cgImage = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    let color = try #require(bitmap.colorAt(x: 16, y: 16)?.usingColorSpace(.deviceRGB))
    #expect(color.redComponent > 0.95)
    #expect(color.greenComponent < 0.05)
    #expect(color.blueComponent < 0.05)
    #expect(color.alphaComponent > 0.95)
}

@Test(arguments: ["IJSVGBlur", "IJSVGInnerShadow", "IJSVGSubtract", "IJSVGSeparableBlur"])
func loadsPackagedShader(name: String) throws {
    let source = try #require(IJSVGPackageShaderSource(name))
    #expect(!source.isEmpty)
    // Resource checks also run on machines without a Metal device.
    if let device = MTLCreateSystemDefaultDevice() {
        let library = try device.makeLibrary(source: source, options: nil)
        #expect(!library.functionNames.isEmpty)
    }
}

@Test func importsThrowingInitializers() throws {
    let source = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"8\"/>"
    let parsed: IJSVG = try IJSVG(parsing: source)
    let data = Data(source.utf8)
    let fromData: IJSVG = try IJSVG(data: data)
    #expect(parsed.size == fromData.size)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".svg")
    try data.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let fromURL: IJSVG = try IJSVG(contentsOf: url)
    let fromPath: IJSVG = try IJSVG(filePath: url.path)
    #expect(fromURL.size == parsed.size)
    #expect(fromPath.size == parsed.size)
}

@Test func reportsParsingAndFileErrors() {
    #expect(throws: (any Error).self) { try IJSVG(parsing: "not SVG") }
    #expect(throws: (any Error).self) { try IJSVG(data: Data()) }
    let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".svg")
    #expect(throws: (any Error).self) { try IJSVG(contentsOf: missing) }
    #expect(IJSVG(svgString: "not SVG") == nil)
}

@Test func optionalMetadataCanBeCleared() throws {
    let svg = try IJSVG(parsing: "<svg xmlns=\"http://www.w3.org/2000/svg\"/>")
    #expect(svg.title == nil)
    #expect(svg.desc == nil)
    svg.title = "Example"
    svg.title = nil
    svg.desc = nil
    svg.renderingBackingScaleHelper = nil
    #expect(svg.title == nil)
    let exporter = svg.exporter(with: CGSize(width: 16, height: 16), options: [], floatingPointOptions: IJSVGFloatingPointOptionsDefault())
    exporter.delegate = nil
    #expect(exporter.delegate == nil)
}

@MainActor @Test func viewAcceptsAnEmptySVG() {
    let view = IJSVGView(svg: nil)
    view.svg = nil
    #expect(view.svg == nil)
}
