import CoreGraphics
import Foundation
import IJSVG
import Testing

private func coverageBitmap() throws -> CGContext {
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    return try #require(CGContext(data: nil, width: 256, height: 256, bitsPerComponent: 8,
                                 bytesPerRow: 1024, space: space,
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
}

private func coveragePixels(_ context: CGContext) throws -> [UInt8] {
    let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
    return Array(UnsafeBufferPointer(start: bytes, count: 256 * 1024))
}

@Test(arguments: ["", "rotate(17 128 128)", "matrix(1 .15 .1 1 -10 -15)"], [false, true])
func filteredCoverageSurvivesChangingClips(transform: String, nested: Bool) throws {
    // Named branches require both the shifted blur and the unshifted source.
    // Three independent children exercise collection as well as cache replay.
    let source = """
    <svg xmlns="http://www.w3.org/2000/svg" width="256" height="256">
      <defs>
        <filter id="f" filterUnits="userSpaceOnUse" x="-32" y="-32" width="320" height="320">
          <feGaussianBlur in="SourceAlpha" stdDeviation="1.5 2" result="blur"/>
          <feOffset in="blur" dx="7.25" dy="-4.5" result="shifted"/>
          <feFlood flood-color="blue" result="color"/>
          <feComposite in="color" in2="shifted" operator="in" result="shadow"/>
          <feBlend in="SourceGraphic" in2="shadow"/>
        </filter>
        <mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="256" height="256">
          <rect x="9.25" y="11.5" width="230" height="225" fill="white"/>
        </mask>
      </defs>
      <g transform="\(transform)" mask="url(#m)" filter="\(nested ? "url(#f)" : "none")">
        <rect x="20" y="20" width="210" height="55" fill="red" filter="url(#f)"/>
        <rect x="20" y="95" width="210" height="55" fill="green" filter="url(#f)"/>
        <rect x="20" y="170" width="210" height="55" fill="orange" filter="url(#f)"/>
      </g>
    </svg>
    """
    try checkFilteredCoverage(source, label: "transform=\(transform), nested=\(nested)")
}

private func checkFilteredCoverage(_ source: String, label: String) throws {
    let rect = CGRect(x: 0, y: 0, width: 256, height: 256)
    let reference = try IJSVG(parsing: source)
    let full = try coverageBitmap()
    reference.draw(in: rect, context: full)
    let image = try #require(full.makeImage())
    let svg = try IJSVG(parsing: source)
    let clips = [CGRect(x: 90, y: 100, width: 30, height: 32),
                 CGRect(x: 93.25, y: 101.5, width: 37.5, height: 35.25),
                 CGRect(x: 145, y: 30, width: 50, height: 180), rect]
    for clip in clips {
        let actual = try coverageBitmap()
        actual.clip(to: clip)
        svg.draw(in: rect, context: actual)
        let expected = try coverageBitmap()
        expected.clip(to: clip)
        expected.draw(image, in: rect)
        let a = try coveragePixels(actual)
        let b = try coveragePixels(expected)
        // Ignore only the fractional destination clip edge: clipping an already
        // composited image can round differently from clipping each child.
        var maximumDifference = 0
        for y in 0..<256 {
            for x in 0..<256 where clip.insetBy(dx: 2, dy: 2).contains(CGPoint(x: x, y: y)) {
                for channel in 0..<4 {
                    let index = ((255 - y) * 256 + x) * 4 + channel
                    maximumDifference = max(maximumDifference, abs(Int(a[index]) - Int(b[index])))
                }
            }
        }
        #expect(maximumDifference <= 2, "\(label), clip=\(clip), delta=\(maximumDifference)")
    }
}

@Test(arguments: ["in", "atop", "arithmetic"], [false, true])
func branchedFilterCoverage(operation: String, reuseName: Bool) throws {
    // Resolve each input before publishing the primitive result. The second
    // blur may replace a name already consumed by the first offset.
    let source = """
    <svg xmlns="http://www.w3.org/2000/svg" width="256" height="256">
      <defs>
        <filter id="f" filterUnits="userSpaceOnUse" x="-32" y="-32" width="320" height="320">
          <feGaussianBlur in="SourceAlpha" stdDeviation="3 5" result="blur"/>
          <feOffset in="blur" dx="20" dy="-12" result="left"/>
          <feGaussianBlur in="SourceGraphic" stdDeviation="7 2" result="\(reuseName ? "blur" : "second")"/>
          <feOffset in="\(reuseName ? "blur" : "second")" dx="-18" dy="15" result="right"/>
          <feComposite in="left" in2="right" operator="\(operation)" k1="0.5" k2="0.3" k3="0.2" k4="0.1" result="combined"/>
          <feMerge><feMergeNode in="combined"/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
      </defs>
      <g filter="url(#f)">
        <rect x="30" y="25" width="160" height="185" fill="red"/>
        <circle cx="160" cy="120" r="50" fill="blue"/>
      </g>
    </svg>
    """
    try checkFilteredCoverage(source, label: "operator=\(operation), reuseName=\(reuseName)")
}
