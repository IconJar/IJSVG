import AppKit
import IJSVG
import IJSVGTestSupport
import Testing

private let annotationTestSVG = """
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="8">
    <rect width="16" height="8" fill="red"/>
</svg>
"""

@Test func renderingNamesImportWithoutAmbiguousOverloads() throws {
    let svg = try IJSVG(parsing: annotationTestSVG)
    svg.renderingBackingScaleHelper = { 1 }
    let size = CGSize(width: 32, height: 16)
    let image: NSImage = try svg.renderImage(size: size)
    let flipped: NSImage = try svg.renderImage(size: size, flipped: true)
    let fitted: NSImage = try svg.renderImage(fitting: size, flipped: false)
    #expect(image.size == size)
    #expect(flipped.size == size)
    #expect(fitted.size == size)
    let cgImage: CGImage = try svg.renderCGImage(size: size, flipped: false)
    #expect(cgImage.width == 32)
    #expect(cgImage.height == 16)
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    let color = try #require(bitmap.colorAt(x: 8, y: 8)?.usingColorSpace(.deviceRGB))
    #expect(color.redComponent > 0.95)
    #expect(color.alphaComponent > 0.95)
    let rect = CGRect(origin: .zero, size: size)
    let documents: [Data] = [svg.pdfData(), svg.pdfData(in: rect), try svg.renderPDF(), try svg.renderPDF(in: rect)]
    for data in documents {
        let provider = try #require(CGDataProvider(data: data as CFData))
        let document = try #require(CGPDFDocument(provider))
        #expect(document.numberOfPages == 1)
    }
}

@Test func coreGraphicsObjectsHaveManagedSwiftTypes() throws {
    let source = CGPath(rect: CGRect(x: 0, y: 0, width: 8, height: 4), transform: nil)
    let flipped: CGPath = IJSVGUtils.flippedPath(source)
    #expect(flipped.boundingBoxOfPath.size == source.boundingBoxOfPath.size)
    let commands = IJSVGCommand.commands(forDataCharacters: "M0 0 L8 4")
    let path: CGMutablePath = try #require(IJSVGCommand.makePath(commands: commands))
    #expect(path.currentPoint == CGPoint(x: 8, y: 4))
    let rgb: CGColorSpace = IJSVGDeviceRGBColorSpace()
    let gray: CGColorSpace = IJSVGDeviceGrayColorSpace()
    #expect(rgb.numberOfComponents == 3)
    #expect(gray.numberOfComponents == 1)

    // Borrowed getters must remain valid after the owning nodes are released.
    let borrowedPath: CGMutablePath = try autoreleasepool {
        let node = IJSVGPath()
        node.path = path
        return try #require(node.path)
    }
    #expect(borrowedPath.currentPoint == CGPoint(x: 8, y: 4))
    let borrowedImage: CGImage = try autoreleasepool {
        let svg = try IJSVG(parsing: annotationTestSVG)
        let node = IJSVGImage()
        node.image = try svg.renderImage(size: CGSize(width: 16, height: 8))
        return try #require(node.cgImage())
    }
    #expect(borrowedImage.width > 0)
    let borrowedGradient: CGGradient = try autoreleasepool {
        let gradient = IJSVGGradient()
        gradient.colors = [.red, .blue]
        gradient.numberOfStops = 2
        return try #require(gradient.cgGradient)
    }
    #expect(CFGetTypeID(borrowedGradient) == CGGradient.typeID)
}

@Test func parserNullabilitySupportsOptionalBaseURL() throws {
    let parser = try IJSVGParser(svgString: annotationTestSVG, fileURL: nil)
    let root: IJSVGRootNode = parser.rootNode(with: CGSize(width: 16, height: 8))
    let children: [IJSVGNode] = root.children
    #expect(children.count == 1)
    #expect(throws: (any Error).self) {
        try IJSVGParser(svgData: Data(), fileURL: nil)
    }
}

@Test func nodeAndStyleNullabilityMatchesEmptyState() {
    let node = IJSVGNode()
    #expect(node.parent == nil)
    #expect(node.rootNode == nil)
    #expect(node.fill == nil)
    #expect(node.stroke == nil)
    #expect(node.identifier == nil)
    node.fill = nil
    node.stroke = nil
    node.mask = nil
    node.filter = nil
    let image = IJSVGImage()
    #expect(image.image == nil)
    #expect(image.sourceData == nil)
    let style = IJSVGStyle()
    #expect(style.fillColor == nil)
    #expect(style.strokeColor == nil)
    style.fillColor = .red
    style.fillColor = nil
    let colors: IJSVGTraitedColorStorage = style.colors
    #expect(colors.count == 0)
    let primitives: [IJSVGFilterPrimitive] = IJSVGFilter().primitives
    #expect(primitives.isEmpty)
    #expect(IJSVGFilterPrimitive().parameters == nil)
}

@Test func colorLookupsReturnOptionals() {
    let missing: NSColor? = IJSVGColor.color(from: "not-a-color")
    let none: NSColor? = IJSVGColor.color(from: "none")
    #expect(missing == nil)
    #expect(none == nil)
    let storage = IJSVGTraitedColorStorage()
    let replacement: NSColor? = storage.color(for: .red, matching: .fill)
    #expect(replacement == nil)
    let colors: Set<IJSVGTraitedColor> = storage.colors
    #expect(colors.isEmpty)
}

@Test func pdfErrorAnnotationChecksTheErrorAlongsideData() {
    let svg = IJSVGWithPDFError()
    #expect(throws: (any Error).self) { try svg.renderPDF() }
    #expect(throws: (any Error).self) { try svg.renderPDF(in: .zero) }
    #expect(svg.pdfData().isEmpty)
}
