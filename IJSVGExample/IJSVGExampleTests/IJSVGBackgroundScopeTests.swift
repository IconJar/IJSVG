import AppKit
import IJSVG
import Testing

@Suite @MainActor
struct IJSVGBackgroundScopeTests {
    private func pixels(_ contents: String, size: Int) throws -> [UInt8] {
        let svg = try IJSVG(parsing: """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
            \(contents)
            </svg>
            """)
        svg.renderingBackingScaleHelper = { 1 }
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: size * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.translateBy(x: 0, y: CGFloat(size))
        context.scaleBy(x: 1, y: -1)
        svg.draw(in: CGRect(x: 0, y: 0, width: size, height: size), context: context)
        let data = try #require(context.data)
        return Array(UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: UInt8.self), count: size * size * 4
        ))
    }

    @Test(arguments: [16, 64, 128])
    func unusedBackgroundPreservesIsolationAndGroupOpacity(size: Int) throws {
        func document(_ scope: String) -> String {
            """
            <rect width="16" height="16" fill="red"/>
            <g \(scope) opacity=".5" transform="translate(1 1) rotate(7 7 7)">
                <rect x="2" y="2" width="9" height="9" fill="lime"/>
                <rect x="6" y="4" width="7" height="7" fill="blue"
                      style="mix-blend-mode:screen"/>
            </g>
            """
        }
        let actual = try pixels(document("enable-background='new'"), size: size)
        let expected = try pixels(document("style='isolation:isolate'"), size: size)
        #expect(actual == expected)
    }

    @Test(arguments: [16, 64, 128])
    func boundedLayersPreservePaintedCoverage(size: Int) throws {
        let fixtures = [
            """
            <g transform="translate(1.3 2.1) rotate(23 4 4)">
                <path d="M1 1 L5 1 L5 5" fill="none" stroke="blue"
                      stroke-width="1.7" stroke-linecap="round" stroke-linejoin="miter"/>
                <circle cx="10" cy="9" r="1.2" fill="lime"/>
            </g>
            """,
            """
            <defs><clipPath id="clip"><circle cx="8" cy="8" r="5"/></clipPath></defs>
            <g clip-path="url(#clip)" transform="translate(.3 .7) skewX(20)">
                <rect x="2" y="2" width="8" height="8" fill="blue"/>
                <circle cx="11" cy="11" r="3" fill="lime"/>
            </g>
            """,
            """
            <defs><filter id="blur" x="-100%" y="-100%" width="300%" height="300%">
                <feGaussianBlur stdDeviation="1"/>
            </filter></defs>
            <rect x="5" y="5" width="4" height="4" fill="blue" filter="url(#blur)"/>
            """
        ]
        for contents in fixtures {
            func document(fullCanvas: Bool) -> String {
                // The invisible rectangle broadens the reference layer without
                // painting anything, giving an independent uncropped reference.
                let spacer = fullCanvas
                    ? "<rect x='-100' y='-100' width='216' height='216' opacity='0'/>"
                    : ""
                return """
                    <g enable-background="new" opacity=".6">
                        \(spacer)
                        \(contents)
                    </g>
                    """
            }
            let actual = try pixels(document(fullCanvas: false), size: size)
            let expected = try pixels(document(fullCanvas: true), size: size)
            #expect(actual == expected)
            #expect(actual.contains { $0 != 0 })
        }
    }

    @Test
    func backgroundReaderRetainsItsOwnScope() throws {
        let document = """
            <defs><filter id="f" filterUnits="userSpaceOnUse" x="0" y="0"
                width="16" height="16" color-interpolation-filters="sRGB">
                <feColorMatrix in="BackgroundImage"
                    values="0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 1 0"/>
            </filter></defs>
            <rect width="16" height="16" fill="red"/>
            <g enable-background="new">
                <rect x="2" y="2" width="4" height="4" fill="blue"/>
                <g><rect width="16" height="16" filter="url(#f)"/></g>
            </g>
            """
        let actual = try pixels(document, size: 16)
        let inside = (4 * 16 + 4) * 4
        let outside = (10 * 16 + 10) * 4
        #expect(Array(actual[inside..<(inside + 4)]) == [0, 255, 0, 255])
        #expect(Array(actual[outside..<(outside + 4)]) == [255, 0, 0, 255])
    }
}
