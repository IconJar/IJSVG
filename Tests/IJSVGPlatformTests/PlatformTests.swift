import CoreGraphics
import Foundation
import IJSVG
import Testing

private let redSVG = "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><rect width='16' height='16' fill='red'/></svg>"

@Test func cgImageRespectsExplicitScale() throws {
    let svg = try IJSVG(parsing: redSVG)
    svg.renderingBackingScaleHelper = { 2 }
    let pixels = try svg.renderCGImage(size: CGSize(width: 16, height: 16), flipped: false)
    #expect(pixels.width == 32)
    #expect(pixels.height == 32)
}

@Test func embeddedSVGSurvivesRendering() throws {
    let encoded = Data(redSVG.utf8).base64EncodedString()
    let source = "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><image width='16' height='16' href='data:image/svg+xml;base64,\(encoded)'/></svg>"
    let svg = try IJSVG(parsing: source)
    svg.renderingBackingScaleHelper = { 1 }
    let image = try svg.renderCGImage(size: CGSize(width: 16, height: 16), flipped: false)
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(image, in: CGRect(x: 0, y: 0, width: 16, height: 16))
    let pixel = try #require(context.data).assumingMemoryBound(to: UInt8.self).advanced(by: 8 * 64 + 8 * 4)
    #expect(pixel[0] > 240)
    #expect(pixel[1] < 15)
    #expect(pixel[2] < 15)
    #expect(pixel[3] > 240)
}

@Test func cgImageInputIsRetainedAndUsesPixelDimensions() throws {
    let source = try IJSVG(parsing: redSVG)
    source.renderingBackingScaleHelper = { 2 }
    let image = try source.renderCGImage(size: CGSize(width: 16, height: 16), flipped: false)
    let svg = IJSVG(cgImage: image)
    #expect(svg.size == CGSize(width: 32, height: 32))
    let rendered = try svg.renderCGImage(size: CGSize(width: 16, height: 16), flipped: false)
    #expect(rendered.width == 16)
}
