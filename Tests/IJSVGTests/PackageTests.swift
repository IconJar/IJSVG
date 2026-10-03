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
