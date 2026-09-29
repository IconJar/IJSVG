//
//  IJSVGFilterTests.swift
//  IJSVGExampleTests
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

import AppKit
import IJSVG
import Testing

struct IJSVGFilterTests {
    private func parse(_ body: String) throws -> IJSVGRootNode {
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"30\" height=\"10\">\(body)</svg>"
        let parser = try IJSVGParser(svgString: svg, fileURL: nil)
        return try #require(parser.rootNode(with: CGSize(width: 30, height: 10)))
    }

    private func shadows(_ attributes: String) throws -> [IJSVGFilterPrimitive] {
        let root = try parse("""
            <defs><filter id="shadow"><feDropShadow \(attributes)/></filter></defs>
            <circle cx="5" cy="5" r="4" filter="url(#shadow)"/>
            """)
        let filter = try #require(root.children.first?.filter)
        return filter.primitives
    }

    private func document(_ body: String) -> String {
        "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"30\" height=\"10\" viewBox=\"0 0 30 10\">\(body)</svg>"
    }

    private func render(_ string: String, scale: Int = 10) throws -> [UInt8] {
        try render(string, width: 30 * scale, height: 10 * scale)
    }

    private func render(_ string: String, width: Int, height: Int) throws -> [UInt8] {
        let svg = try #require(IJSVG(svgString: string))
        svg.renderingBackingScaleHelper = { 1 }
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        svg.draw(in: CGRect(x: 0, y: 0, width: width, height: height), context: context)
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: bytes, count: width * height * 4))
    }

    private func pixel(_ bytes: [UInt8], x: Int, y: Int, scale: Int = 10) -> [UInt8] {
        let index = ((10 * scale - 1 - y) * 30 * scale + x) * 4
        return Array(bytes[index..<(index + 4)])
    }

    @Test(arguments: [16, 17, 32, 63, 64, 127, 129])
    func wideComponentTransferCoversEveryRow(height: Int) throws {
        let width = 4096
        func image(filtered: Bool) -> String {
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)">
                <defs><filter id="f" x="0" y="0" width="100%" height="100%"
                              color-interpolation-filters="sRGB">
                    <feComponentTransfer>
                        <feFuncR type="gamma" amplitude=".4" exponent="2"/>
                        <feFuncG type="gamma" amplitude=".2" exponent="3"/>
                        <feFuncB type="gamma" amplitude=".6" exponent=".5"/>
                    </feComponentTransfer>
                </filter></defs>
                <rect width="100%" height="100%" fill="\(filtered ? "white" : "#663399")"
                      \(filtered ? "filter=\"url(#f)\"" : "")/>
            </svg>
            """
        }
        let actual = try render(image(filtered: true), width: width, height: height)
        let expected = try render(image(filtered: false), width: width, height: height)
        #expect(zip(actual, expected).allSatisfy { abs(Int($0) - Int($1)) <= 1 })
    }

    @Test func innerShadowPreviewPreservesSmoothLetterEdges() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
        let string = try String(contentsOf: directory.appendingPathComponent("ab-button-blood-type-color.svg"),
                                encoding: .utf8)
        let svg = try #require(IJSVG(svgString: string))
        svg.renderingBackingScaleHelper = { 1 }
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 128, height: 128,
            bitsPerComponent: 8, bytesPerRow: 512, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: 0, y: 128)
        context.scaleBy(x: 1, y: -1)
        svg.draw(in: CGRect(x: 0, y: 0, width: 128, height: 128), context: context)
        let preview = NSBitmapImageRep(cgImage: try #require(context.makeImage()))
        // Reference: original renderer at 512 pixels, reduced once to 128 with
        // high quality interpolation. Compare the lettering, excluding the border.
        let reference = try #require(NSBitmapImageRep(data: Data(contentsOf:
            directory.appendingPathComponent("ab-button-blood-type-color-reference.png"))))
        var error = 0.0
        for y in 32..<96 {
            for x in 16..<114 {
                let actual = try #require(preview.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                let expected = try #require(reference.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                error += abs(actual.redComponent - expected.redComponent)
                    + abs(actual.greenComponent - expected.greenComponent)
                    + abs(actual.blueComponent - expected.blueComponent)
            }
        }
        // Native resolution filtering produces ~3.1 levels of mean RGB error;
        // 2x supersampling reduces it to ~1.4 (on a 0...255 scale).
        #expect(error * 255 / (64 * 98 * 3) < 2.4)
    }

    @Test func hardShadowOffsetColourAndOpacity() throws {
        let bytes = try render(document("""
            <defs><filter id="f" x="-100%" y="-100%" width="300%" height="300%">
                <feDropShadow dx="3" dy="2" stdDeviation="0" flood-color="cyan" flood-opacity=".5"/>
            </filter></defs>
            <rect x="2" y="2" width="3" height="3" fill="red" filter="url(#f)"/>
            """))
        #expect(pixel(bytes, x: 30, y: 30) == [255, 0, 0, 255])
        let shadow = pixel(bytes, x: 65, y: 55)
        #expect(shadow[0] == 0 && abs(Int(shadow[1]) - 128) <= 1)
        #expect(abs(Int(shadow[2]) - 128) <= 1 && abs(Int(shadow[3]) - 128) <= 1)
        #expect(pixel(bytes, x: 65, y: 15)[3] == 0)
    }

    @Test func anisotropicBlurAndRegionClipping() throws {
        let bytes = try render(document("""
            <defs><filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="8" height="10">
                <feDropShadow dx="0" dy="0" stdDeviation="1 0" flood-color="cyan"/>
            </filter></defs>
            <rect x="3" y="3" width="4" height="4" fill="red" filter="url(#f)"/>
            """))
        let blurred = pixel(bytes, x: 22, y: 50)
        #expect(blurred[3] > 0 && blurred[3] < 128)
        #expect(blurred[1] == blurred[3] && blurred[2] == blurred[3])
        #expect(pixel(bytes, x: 50, y: 22)[3] == 0)
        #expect(pixel(bytes, x: 85, y: 50)[3] == 0)
    }

    @Test func groupOpacityAppliesAfterShadowAndNamedInputsWork() throws {
        let bytes = try render(document("""
            <defs><filter id="f" x="-100%" y="-100%" width="400%" height="300%">
                <feDropShadow dx="3" dy="0" stdDeviation="0" flood-color="cyan" result="first"/>
                <feDropShadow in="first" dx="3" dy="0" stdDeviation="0" flood-color="blue"/>
            </filter></defs>
            <g filter="url(#f)" opacity=".5">
                <rect x="2" y="2" width="3" height="3" fill="red"/>
                <rect x="3" y="2" width="1" height="3" fill="red"/>
            </g>
            """))
        #expect(abs(Int(pixel(bytes, x: 35, y: 30)[3]) - 128) <= 1)
        #expect(abs(Int(pixel(bytes, x: 65, y: 30)[1]) - 128) <= 1)
        #expect(abs(Int(pixel(bytes, x: 95, y: 30)[2]) - 128) <= 1)
    }

    @Test func objectBoundingBoxUnitsAndPrimitiveRegion() throws {
        let bytes = try render(document("""
            <defs><filter id="f" x="-100%" y="-100%" width="400%" height="400%" primitiveUnits="objectBoundingBox">
                <feDropShadow dx="1" dy="1" stdDeviation="0" flood-color="cyan"
                    x="0" y="0" width="1.5" height="2"/>
            </filter></defs>
            <rect x="2" y="2" width="3" height="2" fill="red" filter="url(#f)"/>
            """))
        #expect(pixel(bytes, x: 30, y: 30) == [255, 0, 0, 255])
        #expect(pixel(bytes, x: 55, y: 50) == [0, 255, 255, 255])
        #expect(pixel(bytes, x: 70, y: 50)[3] == 0)
    }

    @Test func clipAndMaskApplyToFilteredOutput() throws {
        for attribute in ["clip-path=\"url(#c)\"", "mask=\"url(#m)\""] {
            let bytes = try render(document("""
                <defs>
                    <filter id="f" x="-100%" y="-100%" width="400%" height="300%">
                        <feDropShadow dx="3" dy="0" stdDeviation="0" flood-color="cyan"/>
                    </filter>
                    <clipPath id="c"><rect x="0" y="0" width="6" height="10"/></clipPath>
                    <mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="30" height="10">
                        <rect x="0" y="0" width="6" height="10" fill="white"/>
                    </mask>
                </defs>
                <rect x="2" y="2" width="3" height="3" fill="red" filter="url(#f)" \(attribute)/>
                """))
            #expect(pixel(bytes, x: 30, y: 30) == [255, 0, 0, 255])
            #expect(pixel(bytes, x: 55, y: 30)[3] > 240)
            #expect(pixel(bytes, x: 70, y: 30)[3] == 0)
        }
    }

    @Test func transformedStrokeShadowSurvivesExport() throws {
        let original = document("""
            <defs><filter id="f" x="-100%" y="-100%" width="300%" height="300%" primitiveUnits="objectBoundingBox">
                <feDropShadow dx=".5" dy="0" stdDeviation="0" flood-color="cyan"/>
            </filter></defs>
            <g transform="translate(2 1) scale(1.5 .8)">
                <rect x="2" y="2" width="3" height="3" fill="red" stroke="blue" stroke-width="1" filter="url(#f)"/>
            </g>
            """)
        let svg = try #require(IJSVG(svgString: original))
        let exporter = try #require(IJSVGExporter(svg: svg, size: CGSize(width: 300, height: 100), options: .all))
        let exported = try #require(exporter.svgString())
        let before = try render(original)
        let after = try render(exported)
        let difference = zip(before, after).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        #expect(Double(difference) / Double(before.count) < 1)
    }

    @Test func exportRetainsFilterDefinitionsAndVectorContent() throws {
        let original = document("""
            <defs><filter id="f" x="-30%" y="-40%" width="160%" height="180%">
                <feDropShadow in="SourceGraphic" result="shadow" dx=".2" dy=".4"
                    stdDeviation=".2 .3" flood-color="cyan" flood-opacity=".5"/>
            </filter></defs>
            <circle cx="5" cy="5" r="3" fill="pink" filter="url(#f)"/>
            """)
        let svg = try #require(IJSVG(svgString: original))
        let exporter = try #require(IJSVGExporter(svg: svg, size: CGSize(width: 300, height: 100), options: .all))
        let exported = try #require(exporter.svgString())
        let xml = try XMLDocument(xmlString: exported)
        #expect(try xml.nodes(forXPath: "//filter/feDropShadow").count == 1)
        #expect(try xml.nodes(forXPath: "//*[@filter]").count == 1)
        #expect(try xml.nodes(forXPath: "//image").isEmpty)
        let before = try render(original)
        let after = try render(exported)
        let difference = zip(before, after).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        #expect(Double(difference) / Double(before.count) < 1)
    }

    @Test(arguments: [
        "dropshadow-nested-transforms",
        "dropshadow-chains-units",
        "dropshadow-clipping-masks",
        "dropshadow-deep-nesting"
    ])
    func complexFixturesRenderAndSurviveExport(name: String) throws {
        // Read the same editable SVGs used by the example app.
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("IJSVGExample/\(name).svg")
        let original = try String(contentsOf: fixtureURL, encoding: .utf8)
        let withoutFilters = try XMLDocument(xmlString: original)
        for node in try withoutFilters.nodes(forXPath: "//*[@filter]") {
            (node as? XMLElement)?.removeAttribute(forName: "filter")
        }
        for scale in [10, 20] {
            let size = CGSize(width: 30 * scale, height: 10 * scale)
            let svg = try #require(IJSVG(svgString: original))
            let exporter = try #require(IJSVGExporter(svg: svg, size: size, options: .all))
            let exported = try #require(exporter.svgString())
            let xml = try XMLDocument(xmlString: exported)
            let definitions = try xml.nodes(forXPath: "//filter/feDropShadow")
            #expect(definitions.isEmpty == false)
            #expect(try xml.nodes(forXPath: "//image").isEmpty)
            for node in try xml.nodes(forXPath: "//*[@filter]") {
                let element = try #require(node as? XMLElement)
                let reference = try #require(element.attribute(forName: "filter")?.stringValue)
                let identifier = reference.replacingOccurrences(of: "url(#", with: "")
                    .replacingOccurrences(of: ")", with: "")
                #expect(try xml.nodes(forXPath: "//filter[@id='\(identifier)']").count == 1)
            }
            let before = try render(original, scale: scale)
            let after = try render(exported, scale: scale)
            let plain = try render(withoutFilters.xmlString, scale: scale)
            let occupied = stride(from: 3, to: before.count, by: 4).filter { before[$0] > 0 }.count
            #expect(occupied > 1000)
            let effectDifference = zip(before, plain).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
            #expect(Double(effectDifference) / Double(before.count) > 1)
            let roundTripDifference = zip(before, after).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
            #expect(Double(roundTripDifference) / Double(before.count) < 1)
        }
    }

    @Test func dropShadowDefaults() throws {
        let shadow = try #require(shadows("").first)
        #expect(shadow.type == .filterDropShadow)
        #expect(shadow.shouldRender == false)
        let implicit = try render(filtered("<feDropShadow/>"))
        let explicit = try render(filtered("""
            <feDropShadow dx="2" dy="2" stdDeviation="2" flood-color="black" flood-opacity="1"/>
            """))
        #expect(implicit == explicit)
    }

    @Test func exampleShadowValues() throws {
        let first = try #require(shadows("dx=\"0.2\" dy=\"0.4\" stdDeviation=\"0.2\"").first)
        #expect(first.parameters[IJSVGAttributeDX] == "0.2")
        #expect(first.parameters[IJSVGAttributeDY] == "0.4")
        #expect(first.parameters[IJSVGAttributeStdDeviation] == "0.2")

        let second = try #require(shadows("dx=\"0\" dy=\"0\" stdDeviation=\"0.5\" flood-color=\"cyan\"").first)
        #expect(second.parameters[IJSVGAttributeDX] == "0" && second.parameters[IJSVGAttributeDY] == "0")
        #expect(second.parameters[IJSVGAttributeStdDeviation] == "0.5")
        #expect(second.parameters[IJSVGAttributeFloodColor] == "cyan")

        let third = try #require(shadows("dx=\"-0.8\" dy=\"-0.8\" stdDeviation=\"0\" flood-color=\"pink\" flood-opacity=\"0.5\"").first)
        #expect(third.parameters[IJSVGAttributeDX] == "-0.8" && third.parameters[IJSVGAttributeDY] == "-0.8")
        #expect(third.parameters[IJSVGAttributeStdDeviation] == "0")
        #expect(third.parameters[IJSVGAttributeFloodOpacity] == "0.5")
        #expect(third.parameters[IJSVGAttributeFloodColor] == "pink")
    }

    @Test func primitiveOrderStylesAndCopying() throws {
        let root = try parse("""
            <style>filter > feDropShadow { flood-color: cyan; flood-opacity: .25; }</style>
            <defs><filter id="shadow">
                <feDropShadow in="SourceAlpha" result="first" stdDeviation="1, 2" flood-color="pink"/>
                <feDropShadow in="first" result="second" style="flood-color: pink; flood-opacity: 50%"/>
            </filter></defs>
            <circle cx="5" cy="5" r="4" filter="url(#shadow)"/>
            """)
        let filter = try #require(root.children.first?.filter)
        #expect(filter.primitives.count == 2)
        let first = try #require(filter.primitives.first)
        let second = try #require(filter.primitives.last)
        #expect(first.input == "SourceAlpha" && first.result == "first")
        #expect(second.input == "first" && second.result == "second")
        #expect(first.parameters[IJSVGAttributeStdDeviation] == "1, 2")
        #expect(first.parameters[IJSVGAttributeFloodOpacity] == ".25")
        #expect(second.parameters[IJSVGAttributeFloodOpacity] == "50%")
        #expect(first.parent === filter)
        let copied = try #require(filter.copy() as? IJSVGFilter)
        let copiedFirst = try #require(copied.primitives.first)
        #expect(copiedFirst !== first && copiedFirst.parent === copied)
        #expect(copiedFirst.input == first.input && copiedFirst.result == first.result)
        #expect(copiedFirst.parameters == first.parameters)
    }

    @Test func invalidNumbersKeepDefaultsAndOpacityIsClamped() throws {
        let invalid = try render(filtered("""
            <feDropShadow dx="NaN" dy="1px" stdDeviation="-1" flood-opacity="2"/>
            """))
        #expect(try render(filtered("<feDropShadow/>")) == invalid)
        let clear = try render(filtered("""
            <feDropShadow stdDeviation="1 2 3" flood-opacity="-1"/>
            """))
        #expect(try render(filtered("<feOffset/>")) == clear)
    }

    @Test func flagsBeyond64AndMixedStorage() throws {
        let flags = try #require(IJSVGBitFlags(length: 96))
        flags.setBit(0)
        flags.setBit(64)
        flags.setBit(95)
        let copied = try #require(IJSVGBitFlags(length: 96))
        copied.addBits(flags)
        #expect(copied.bitIsSet(0) && copied.bitIsSet(64) && copied.bitIsSet(95))
        #expect(copied.bitIsSet(1) == false)
        let compact = IJSVGBitFlags64()
        compact.setBit(63)
        copied.addBits(compact)
        #expect(copied.bitIsSet(63))
        copied.setAllBits()
        #expect((0..<96).allSatisfy { copied.bitIsSet(Int32($0)) })
    }
}


extension IJSVGFilterTests {
    private func filtered(_ primitives: String, attributes: String = "color-interpolation-filters=\"sRGB\"",
                          content: String = "<rect x=\"2\" y=\"2\" width=\"4\" height=\"4\" fill=\"red\"/>") -> String {
        document("""
            <defs><filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="30" height="10" \(attributes)>
            \(primitives)
            </filter></defs>
            <g filter="url(#f)">\(content)</g>
            """)
    }

    @Test func branchesMergeInOrderAndUseSecondInput() throws {
        let bytes = try render(filtered("""
            <feFlood flood-color="cyan" result="paint"/>
            <feComposite in="paint" in2="SourceAlpha" operator="in" result="colored"/>
            <feOffset in="colored" dx="5" result="moved"/>
            <feMerge><feMergeNode in="moved"/><feMergeNode in="SourceGraphic"/></feMerge>
            """))
        #expect(pixel(bytes, x: 35, y: 35) == [255, 0, 0, 255])
        #expect(pixel(bytes, x: 85, y: 35) == [0, 255, 255, 255])
        #expect(pixel(bytes, x: 150, y: 35)[3] == 0)
    }

    @Test func mergeOrderAndDuplicateNames() throws {
        let bytes = try render(filtered("""
            <feFlood flood-color="blue" result="a"/>
            <feFlood flood-color="red" flood-opacity=".5" result="b"/>
            <feMerge result="a"><feMergeNode in="a"/><feMergeNode in="b"/></feMerge>
            <feOffset in="a"/>
            """))
        let value = pixel(bytes, x: 35, y: 35)
        #expect(abs(Int(value[0])-128) <= 1 && abs(Int(value[2])-128) <= 1 && value[3] == 255)
    }

    @Test func invalidInputNamesUsePreviousResult() throws {
        let bytes = try render(filtered("""
            <feFlood flood-color="cyan"/>
            <feOffset in="not-yet-defined"/>
            """))
        #expect(pixel(bytes, x: 35, y: 35) == [0, 255, 255, 255])
    }

    @Test func filterReferenceArrayPreservesOrder() throws {
        let body = """
            <defs>
                <filter id="a" x="-100%" width="400%"><feOffset dx="4"/></filter>
                <filter id="b" x="-100%" width="400%"><feColorMatrix type="matrix"
                    values="0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 1 0"/></filter>
            </defs>
            <rect x="2" y="2" width="3" height="3" fill="red" filter="url('#a') url(#b)"/>
            """
        let root = try parse(body)
        #expect(root.children.first?.filters.count == 2)
        let bytes = try render(document(body))
        #expect(pixel(bytes, x: 75, y: 35) == [0, 255, 0, 255])
        #expect(pixel(bytes, x: 35, y: 35)[3] == 0)
    }

    @Test func colorMatrixAndTransferOperateOnStraightChannels() throws {
        let bytes = try render(filtered("""
            <feColorMatrix type="matrix" values="0 0 0 0 0 1 0 0 0 0 0 0 1 0 0 0 0 0 1 0"/>
            <feComponentTransfer>
                <feFuncG type="linear" slope=".5"/>
                <feFuncA type="linear" slope=".5"/>
            </feComponentTransfer>
            """))
        let value = pixel(bytes, x: 35, y: 35)
        #expect(value[0] == 0 && abs(Int(value[1])-64) <= 1 && value[2] == 0)
        #expect(abs(Int(value[3])-128) <= 1)
    }

    @Test func filterColorSpaceChangesArithmetic() throws {
        let primitive = "<feComponentTransfer><feFuncR type=\"linear\" slope=\".5\"/></feComponentTransfer>"
        let srgb = try render(filtered(primitive))
        let linear = try render(filtered(primitive, attributes: ""))
        #expect(abs(Int(pixel(srgb, x: 35, y: 35)[0])-128) <= 1)
        #expect(abs(Int(pixel(linear, x: 35, y: 35)[0])-188) <= 1)
    }

    @Test func primitiveRegionRestrictsLaterBlurAndTileRepeatsIt() throws {
        let bytes = try render(filtered("""
            <feFlood flood-color="cyan" x="2" y="2" width="2" height="2" result="tile"/>
            <feTile in="tile"/>
            """))
        #expect(pixel(bytes, x: 15, y: 15) == [0, 255, 255, 255])
        #expect(pixel(bytes, x: 155, y: 75) == [0, 255, 255, 255])
        let clipped = try render(filtered("""
            <feFlood flood-color="cyan" x="2" y="2" width="2" height="2"/>
            <feGaussianBlur stdDeviation="1"/>
            """))
        #expect(pixel(clipped, x: 15, y: 30)[3] == 0)
        #expect(pixel(clipped, x: 30, y: 30)[3] > 0)
    }

    @Test func gaussianBlurPreservesColorAndZeroAxis() throws {
        let bytes = try render(filtered("<feGaussianBlur stdDeviation=\"1 0\"/>"))
        let fringe = pixel(bytes, x: 15, y: 35)
        #expect(fringe[0] == fringe[3] && fringe[3] > 0 && fringe[3] < 128)
        #expect(pixel(bytes, x: 35, y: 15)[3] == 0)
    }

    @Test func morphologyErodesAndDilates() throws {
        let dilated = try render(filtered("<feMorphology operator=\"dilate\" radius=\"1\"/>"))
        let eroded = try render(filtered("<feMorphology operator=\"erode\" radius=\"1\"/>"))
        #expect(pixel(dilated, x: 15, y: 35) == [255, 0, 0, 255])
        #expect(pixel(eroded, x: 25, y: 35)[3] == 0)
        #expect(pixel(eroded, x: 35, y: 35) == [255, 0, 0, 255])
    }

    @Test func convolutionIdentityAndBias() throws {
        let identity = try render(filtered("<feConvolveMatrix order=\"1\" kernelMatrix=\"2\" divisor=\"2\"/>"))
        #expect(pixel(identity, x: 35, y: 35) == [255, 0, 0, 255])
        let biased = try render(filtered("<feConvolveMatrix order=\"1\" kernelMatrix=\"0\" bias=\".5\" preserveAlpha=\"true\"/>"))
        let value = pixel(biased, x: 35, y: 35)
        #expect(value[0...2].allSatisfy { abs(Int($0)-128) <= 1 })
        #expect(value[3] == 255)
        #expect(pixel(biased, x: 15, y: 35)[3] == 0)
    }

    @Test func displacementUsesUnpremultipliedMapChannels() throws {
        let bytes = try render(filtered("""
            <feFlood flood-color="red" flood-opacity=".5" result="map"/>
            <feDisplacementMap in="SourceGraphic" in2="map" scale="4" xChannelSelector="R" yChannelSelector="A"/>
            """))
        #expect(pixel(bytes, x: 15, y: 35) == [255, 0, 0, 255])
        #expect(pixel(bytes, x: 55, y: 35)[3] == 0)
    }

    @Test func blendMultiplyAndArithmeticComposite() throws {
        let multiplied = try render(filtered("""
            <feFlood flood-color="cyan" result="paint"/>
            <feBlend in="SourceGraphic" in2="paint" mode="multiply"/>
            """))
        #expect(pixel(multiplied, x: 35, y: 35) == [0, 0, 0, 255])
        let arithmetic = try render(filtered("""
            <feFlood flood-color="blue" result="paint"/>
            <feComposite in="SourceGraphic" in2="paint" operator="arithmetic" k2=".5" k3=".5"/>
            """))
        let value = pixel(arithmetic, x: 35, y: 35)
        #expect(abs(Int(value[0])-128) <= 1 && abs(Int(value[2])-128) <= 1 && value[3] == 255)
    }

    @Test(arguments: [false, true], [false, true])
    func turbulenceMatchesOriginalSamples(fractal: Bool, stitch: Bool) throws {
        // Samples from the original scalar evaluator, before sharing the RGBA lattice.
        let references = [
            [[3, 13, 11, 57], [20, 13, 30, 72], [41, 26, 36, 115], [5, 4, 4, 35]],
            [[82, 60, 88, 156], [84, 74, 49, 158], [80, 87, 94, 144], [58, 63, 62, 128]],
            [[3, 13, 11, 56], [16, 10, 31, 65], [33, 41, 50, 125], [8, 13, 12, 59]],
            [[82, 60, 87, 156], [86, 78, 45, 159], [74, 98, 107, 153], [73, 79, 52, 130]]
        ]
        let reference = references[(fractal ? 1 : 0) + (stitch ? 2 : 0)]
        let bytes = try render(filtered("""
            <feTurbulence baseFrequency=".17 .31" seed="7" numOctaves="4"
                type="\(fractal ? "fractalNoise" : "turbulence")"
                stitchTiles="\(stitch ? "stitch" : "noStitch")"/>
            """), scale: 1)
        for (index, position) in [(0, 0), (3, 3), (14, 5), (29, 9)].enumerated() {
            let actual = pixel(bytes, x: position.0, y: position.1, scale: 1)
            for channel in 0..<4 {
                #expect(abs(Int(actual[channel]) - reference[index][channel]) <= 2)
            }
        }
    }

    @Test(arguments: ["", "scale=\"0\""])
    func zeroDisplacementPreservesSource(scale: String) throws {
        let content = """
            <rect x="2" y="2" width="4" height="4" fill="#804020" opacity=".6"/>
            <circle cx="8" cy="5" r="3" fill="blue" opacity=".4"/>
            """
        let actual = try render(filtered("""
            <feFlood flood-color="red" result="map"/>
            <feDisplacementMap in="SourceGraphic" in2="map" \(scale)
                xChannelSelector="R" yChannelSelector="B"/>
            """, content: content))
        let expected = try render(filtered("<feOffset/>", content: content))
        #expect(actual == expected)
    }

    @Test func turbulenceIsSeededAndVaries() throws {
        let a = try render(filtered("<feTurbulence baseFrequency=\".3 .2\" seed=\"7\" numOctaves=\"3\" type=\"fractalNoise\"/>"))
        let b = try render(filtered("<feTurbulence baseFrequency=\".3 .2\" seed=\"7\" numOctaves=\"3\" type=\"fractalNoise\"/>"))
        let c = try render(filtered("<feTurbulence baseFrequency=\".3 .2\" seed=\"8\" numOctaves=\"3\" type=\"fractalNoise\"/>"))
        #expect(a == b)
        #expect(a != c)
        #expect(pixel(a, x: 35, y: 35) != pixel(a, x: 155, y: 75))
    }

    @Test func diffuseAndSpecularDistantLighting() throws {
        for type in ["feDiffuseLighting", "feSpecularLighting"] {
            let bytes = try render(filtered("""
                <\(type) lighting-color="cyan"><feDistantLight elevation="90"/></\(type)>
                """))
            #expect(pixel(bytes, x: 40, y: 40) == [0, 255, 255, 255])
        }
    }

    @Test func nestedFilterNodesCopyAndRoundTrip() throws {
        let original = filtered("""
            <feFlood flood-color="cyan" result="paint"/>
            <feComposite in="paint" in2="SourceAlpha" operator="in" result="colored"/>
            <feComponentTransfer in="colored"><feFuncA type="linear" slope=".5"/></feComponentTransfer>
            <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
            """)
        let svg = try #require(IJSVG(svgString: original))
        let exporter = try #require(IJSVGExporter(svg: svg, size: CGSize(width: 300, height: 100), options: .all))
        let exported = try #require(exporter.svgString())
        let xml = try XMLDocument(xmlString: exported)
        #expect(try xml.nodes(forXPath: "//filter/feMerge/feMergeNode").count == 2)
        #expect(try xml.nodes(forXPath: "//filter/feComponentTransfer/feFuncA").count == 1)
        let before = try render(original)
        let after = try render(exported)
        #expect(before == after)
    }
}

extension IJSVGFilterTests {
    @Test func referencedImageRendersAndSurvivesExport() throws {
        let original = document("""
            <defs>
                <rect id="image" x="8" y="2" width="3" height="4" fill="cyan"/>
                <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="30" height="10">
                    <feImage href="#image"/>
                </filter>
            </defs>
            <rect x="2" y="2" width="3" height="3" fill="red" filter="url(#f)"/>
            """)
        let before = try render(original)
        #expect(pixel(before, x: 95, y: 35) == [0, 255, 255, 255])
        #expect(pixel(before, x: 35, y: 35)[3] == 0)
        let svg = try #require(IJSVG(svgString: original))
        let exporter = try #require(IJSVGExporter(svg: svg, size: CGSize(width: 300, height: 100), options: .all))
        let exported = try #require(exporter.svgString())
        #expect(try render(exported) == before)
    }

    @Test func embeddedRasterImagePreservesAspectRatio() throws {
        let image = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 1,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 8, bitsPerPixel: 32))
        let pixels = try #require(image.bitmapData)
        for x in 0..<2 {
            pixels[x * 4] = 255
            pixels[x * 4 + 1] = 0
            pixels[x * 4 + 2] = 0
            pixels[x * 4 + 3] = 255
        }
        let png = try #require(image.representation(using: .png, properties: [:])).base64EncodedString()
        let bytes = try render(filtered("""
            <feImage href="data:image/png;base64,\(png)" x="8" y="2" width="4" height="4"/>
            """))
        #expect(pixel(bytes, x: 95, y: 35) == [255, 0, 0, 255])
        #expect(pixel(bytes, x: 95, y: 25)[3] == 0)
        #expect(pixel(bytes, x: 35, y: 35)[3] == 0)
        for (aspect, topIsFilled, bottomIsFilled) in [
            ("xMinYMin meet", true, false),
            ("xMaxYMax meet", false, true),
            ("xMidYMid slice", true, true),
            ("none", true, true)
        ] {
            let original = filtered("""
                <feImage href="data:image/png;base64,\(png)" x="8" y="2" width="4" height="4"
                    preserveAspectRatio="\(aspect)"/>
                """)
            let rendered = try render(original)
            #expect((pixel(rendered, x: 95, y: 25)[3] == 255) == topIsFilled)
            #expect((pixel(rendered, x: 95, y: 55)[3] == 255) == bottomIsFilled)
            let svg = try #require(IJSVG(svgString: original))
            let exporter = try #require(IJSVGExporter(svg: svg, size: CGSize(width: 300, height: 100), options: .all))
            #expect(try render(#require(exporter.svgString())) == rendered)
        }
    }

    @Test func filterTemplatesAndPrimitiveCopiesAreIndependent() throws {
        let root = try parse("""
            <defs>
                <filter id="base" x="-50%" width="200%">
                    <feMerge><feMergeNode in="SourceGraphic"/></feMerge>
                </filter>
                <filter id="derived" href="#base" y="-25%"/>
            </defs>
            <rect x="2" y="2" width="4" height="4" filter="url(#derived)"/>
            """)
        let filter = try #require(root.children.first?.filter)
        #expect(filter.x.stringValue() == "-50%")
        #expect(filter.y.stringValue() == "-25%")
        let copy = try #require(filter.copy() as? IJSVGFilter)
        let originalMerge = try #require(filter.primitives.first)
        let copiedMerge = try #require(copy.primitives.first)
        #expect(originalMerge !== copiedMerge)
        #expect(originalMerge.children.first !== copiedMerge.children.first)
        #expect(copiedMerge.children.first?.parent === copiedMerge)
    }

    @Test func convolutionAndDisplacementRespectVerticalCoordinates() throws {
        let shifted = try render(filtered("""
            <feConvolveMatrix order="1 3" kernelMatrix="1 0 0" targetY="1" kernelUnitLength="1"
                edgeMode="none"/>
            """))
        #expect(pixel(shifted, x: 35, y: 15) == [255, 0, 0, 255])
        #expect(pixel(shifted, x: 35, y: 55)[3] == 0)
        let displaced = try render(filtered("""
            <feFlood flood-color="lime" result="map"/>
            <feDisplacementMap in="SourceGraphic" in2="map" scale="4"
                xChannelSelector="A" yChannelSelector="G"/>
            """))
        #expect(pixel(displaced, x: 15, y: 15) == [255, 0, 0, 255])
        #expect(pixel(displaced, x: 35, y: 55)[3] == 0)
    }

    @Test func pointAndSpotLightingUseTheirChildParameters() throws {
        for light in [
            "<fePointLight x=\"4\" y=\"4\" z=\"100\"/>",
            "<feSpotLight x=\"4\" y=\"4\" z=\"100\" pointsAtX=\"4\" pointsAtY=\"4\" pointsAtZ=\"0\" limitingConeAngle=\"30\"/>"
        ] {
            let bytes = try render(filtered("<feDiffuseLighting lighting-color=\"cyan\">\(light)</feDiffuseLighting>"))
            let value = pixel(bytes, x: 40, y: 40)
            #expect(value[0] == 0 && value[1] > 250 && value[2] > 250 && value[3] == 255)
        }
    }

    @Test func fillAndStrokePaintAreIndependentInputs() throws {
        let original = document("""
            <defs><filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="30" height="10">
                <feOffset in="StrokePaint"/>
            </filter></defs>
            <rect x="2" y="2" width="4" height="4" fill="red" stroke="blue" filter="url(#f)"/>
            """)
        #expect(pixel(try render(original), x: 150, y: 50) == [0, 0, 255, 255])
    }
}

extension IJSVGFilterTests {
    @Test func filterReferenceCyclesTerminate() throws {
        let original = document("""
            <defs>
                <filter id="a" href="#b"/>
                <filter id="b" href="#a"/>
                <g id="self"><rect width="4" height="4" filter="url(#c)"/></g>
                <filter id="c"><feImage href="#self"/></filter>
            </defs>
            <rect x="2" y="2" width="4" height="4" filter="url(#a)"/>
            <rect x="8" y="2" width="4" height="4" filter="url(#c)"/>
            """)
        let bytes = try render(original)
        #expect(bytes.count == 300 * 100 * 4)
    }

    @Test func gradientAndPatternPaintInputs() throws {
        for definition in [
            "<linearGradient id=\"p\"><stop stop-color=\"red\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient>",
            "<pattern id=\"p\" patternUnits=\"userSpaceOnUse\" width=\"2\" height=\"2\"><rect width=\"2\" height=\"2\" fill=\"cyan\"/></pattern>"
        ] {
            let original = document("""
                <defs>\(definition)
                    <filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="30" height="10"><feOffset in="FillPaint"/></filter>
                </defs>
                <rect x="2" y="2" width="4" height="4" fill="url(#p)" filter="url(#f)"/>
                """)
            let before = try render(original)
            let outside = pixel(before, x: 155, y: 55)
            #expect(outside[3] == 255)
            if definition.hasPrefix("<linearGradient") {
                #expect(outside[2] > 250)
                #expect(pixel(before, x: 25, y: 35)[0] > pixel(before, x: 55, y: 35)[0])
            } else {
                #expect(outside == [0, 255, 255, 255])
            }
            let svg = try #require(IJSVG(svgString: original))
            let exporter = try #require(IJSVGExporter(svg: svg, size: CGSize(width: 300, height: 100), options: .all))
            let exported = try #require(exporter.svgString())
            let after = try render(exported)
            let difference = zip(before, after).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
            #expect(Double(difference) / Double(before.count) < 1)
        }
    }

    @Test func bitmapBackgroundInputUsesPreviouslyPaintedContent() throws {
        let original = document("""
            <defs><filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" width="30" height="10">
                <feColorMatrix in="BackgroundImage" type="matrix"
                    values="0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 1 0"/>
            </filter></defs>
            <rect x="2" y="2" width="4" height="4" fill="blue"/>
            <rect x="12" y="2" width="4" height="4" fill="red" filter="url(#f)"/>
            """)
        let bytes = try render(original)
        #expect(pixel(bytes, x: 35, y: 35) == [0, 255, 0, 255])
        #expect(pixel(bytes, x: 135, y: 35)[3] == 0)
    }

    @Test func componentTransferTableDiscreteAndGamma() throws {
        let bytes = try render(filtered("""
            <feComponentTransfer>
                <feFuncR type="table" tableValues=".25 .75"/>
                <feFuncG type="discrete" tableValues=".5 1"/>
                <feFuncB type="gamma" amplitude="0" offset=".25"/>
                <feFuncA type="identity"/>
            </feComponentTransfer>
            """))
        let value = pixel(bytes, x: 35, y: 35)
        #expect(abs(Int(value[0])-191) <= 1)
        #expect(abs(Int(value[1])-128) <= 1)
        #expect(abs(Int(value[2])-64) <= 1)
        #expect(value[3] == 255)
    }
}

extension IJSVGFilterTests {
    @Test func filterReferencesUseNamespaceAliasesAndHrefPrecedence() throws {
        for reference in ["x:href=\"#cyan\"", "x:href=\"#red\" href=\"#cyan\""] {
            let original = document("""
                <defs xmlns:x="http://www.w3.org/1999/xlink">
                    <rect id="cyan" x="8" y="2" width="3" height="4" fill="cyan"/>
                    <rect id="red" x="8" y="2" width="3" height="4" fill="red"/>
                    <filter id="base" filterUnits="userSpaceOnUse" x="0" y="0" width="30" height="10">
                        <feImage \(reference)/>
                    </filter>
                    <filter id="derived" x:href="#base"/>
                </defs>
                <rect x="2" y="2" width="3" height="3" filter="url('#derived')"/>
                """)
            let parser = try IJSVGParser(svgString: original, fileURL: nil)
            let root = try #require(parser.rootNode(with: CGSize(width: 30, height: 10)))
            let filter = try #require(root.children.first?.filter)
            #expect(filter.primitives.count == 1)
            let primitive = try #require(filter.primitives.first)
            let imageNode = try #require(primitive.imageNode)
            #expect(imageNode.x.value == 8)
            #expect(imageNode.width.value == 3)
            #expect(imageNode.shouldRender)
            #expect(filter.units == .userSpaceOnUse)
            #expect(filter.width.value == 30)
            let rendered = try render(original)
            #expect(pixel(rendered, x: 95, y: 35) == [0, 255, 255, 255])
            let svg = try #require(IJSVG(svgString: original))
            let exporter = try #require(IJSVGExporter(svg: svg, size: CGSize(width: 300, height: 100), options: .all))
            #expect(try render(#require(exporter.svgString())) == rendered)
        }
    }

    @Test func filterURLByteParserPreservesIdentifiersAndOrder() {
        let cases: [(String, [String])] = [
            ("", []),
            (" \t\r\n", []),
            ("url(#first)", ["first"]),
            (" URL( '#first' )\turl(\"#second\")\nurl(#first) ", ["first", "second", "first"]),
            ("url(#first)url(#second)", ["first", "second"]),
            ("url(#éclair) url('#影')", ["éclair", "影"]),
            ("url('#shape(1)')", ["shape(1)"])
        ]
        for (input, expected) in cases {
            #expect(IJSVGUtils.defURLs(input) == expected, "Input: \(input)")
        }
    }

    @Test func filterURLByteParserRejectsIncompleteOrInvalidLists() {
        for input in [
            "u", "ur", "url", "url(", "url(#", "url(#first", "url('#first)",
            "url(\"#first')", "url()", "url(#)", "url('')", "url('#')",
            "url(file.svg#first)", "url(#first) trailing", "url(#first) url(#",
            "url(#first))", "url(#first),url(#second)", "url(#first second)",
            "url(#first(nested))", "url(#first) blur(2)", "url(#first\\second)",
            "url(#first)\0url(#second)", "url('#first\nsecond')",
            "url('#first'junk'#second')", "url('#first' trailing)",
            "url(#first) ) url(#second)", "url(#first) url(#second) unfinished("
        ] {
            #expect(IJSVGUtils.defURLs(input).isEmpty, "Input: \(input)")
        }
    }

    @Test func filterURLListRejectsMalformedReferences() throws {
        for reference in ["url('#f')", "url(&quot;#f&quot;)", "URL(#f) url(#f)"] {
            let root = try parse("""
                <defs><filter id="f"><feOffset/></filter></defs>
                <rect width="4" height="4" filter="\(reference)"/>
                """)
            #expect(root.children.first?.filters.isEmpty == false)
        }
        for reference in ["url(')", "url(#f", "url(#f) trailing", "url(#missing)", "url(file.svg#f)"] {
            let root = try parse("""
                <defs><filter id="f"><feOffset/></filter></defs>
                <rect width="4" height="4" filter="\(reference)"/>
                """)
            #expect(root.children.first?.filters.isEmpty == true)
        }
    }
}

extension IJSVGFilterTests {
    @Test func coreImageCompositeOperatorsPreservePremultipliedAlpha() throws {
        let cases: [(String, [Int])] = [
            ("over", [128, 0, 64, 191]), ("in", [64, 0, 0, 64]),
            ("out", [64, 0, 0, 64]), ("atop", [64, 0, 64, 128]),
            ("xor", [64, 0, 64, 128]), ("lighter", [128, 0, 128, 255])
        ]
        for (operation, expected) in cases {
            let bytes = try render(filtered("""
                <feFlood flood-color="red" flood-opacity=".5" result="a"/>
                <feFlood flood-color="blue" flood-opacity=".5" result="b"/>
                <feComposite in="a" in2="b" operator="\(operation)" color-interpolation-filters="sRGB"/>
                """))
            let actual = pixel(bytes, x: 35, y: 35)
            for channel in 0..<4 {
                #expect(abs(Int(actual[channel]) - expected[channel]) <= 2, "\(operation), channel \(channel)")
            }
        }
    }
}

extension IJSVGFilterTests {
    @Test(arguments: ["0", ".3", "1.7", ".3 .1", "1.7 0", "0 1.7", "1.7 .8"], ["sRGB", "linearRGB"])
    func acceleratedShadowMatchesExplicitBlur(deviation: String, colorSpace: String) throws {
        let content = """
            <rect x="4" y="2" width="5" height="5" fill="#804020" opacity=".6"/>
            <circle cx="13" cy="5" r="3" fill="blue" opacity=".4"/>
            """
        func renderEffects(_ primitives: String) throws -> [UInt8] {
            // Keep blur tails inside the filter region before the explicit offset.
            try render(document("""
                <defs><filter id="f" filterUnits="userSpaceOnUse"
                    x="-10" y="-10" width="50" height="30" color-interpolation-filters="\(colorSpace)">
                    \(primitives)
                </filter></defs>
                <g filter="url(#f)">\(content)</g>
                """), scale: 2)
        }
        let shadow = try renderEffects("""
            <feDropShadow dx="2" dy="-1" stdDeviation="\(deviation)"
                flood-color="#4080c0" flood-opacity=".7"/>
            """)
        let explicit = try renderEffects("""
            <feGaussianBlur in="SourceAlpha" stdDeviation="\(deviation)"/>
            <feOffset dx="2" dy="-1" result="blur"/>
            <feFlood flood-color="#4080c0" flood-opacity=".7"/>
            <feComposite in2="blur" operator="in" result="shadow"/>
            <feMerge><feMergeNode in="shadow"/><feMergeNode in="SourceGraphic"/></feMerge>
            """)
        let maximumError = zip(shadow, explicit).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(maximumError <= 1)
    }

    @Test(arguments: ["sRGB", "linearRGB"], [10, 20])
    func lightingColorReadbackPreservesInterpolation(colorSpace: String, scale: Int) throws {
        let bytes = try render(filtered("""
            <feDiffuseLighting surfaceScale="0" diffuseConstant=".5" lighting-color="#804020">
                <feDistantLight elevation="90"/>
            </feDiffuseLighting>
            """, attributes: "color-interpolation-filters=\"\(colorSpace)\""), scale: scale)
        let actual = pixel(bytes, x: 35, y: 35, scale: scale)
        for (channel, value) in [128.0, 64.0, 32.0].enumerated() {
            let encoded = value / 255
            let linear = encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055, 2.4)
            let shaded = linear * 0.5
            let expected = colorSpace == "sRGB" ? encoded * 0.5
                : (shaded <= 0.0031308 ? shaded * 12.92 : 1.055 * pow(shaded, 1 / 2.4) - 0.055)
            #expect(stride(from: channel, to: bytes.count, by: 4).allSatisfy {
                abs(Double(bytes[$0]) - expected * 255) <= 2
            })
        }
        #expect(actual[3] == 255)
    }

    @Test(arguments: [false, true])
    func acceleratedArithmeticMatchesPremultipliedEquation(sameInput: Bool) throws {
        let bytes = try render(filtered("""
            <feFlood flood-color="#804020" flood-opacity=".5" result="a"/>
            <feFlood flood-color="#2080c0" flood-opacity=".75" result="b"/>
            <feComposite in="a" in2="\(sameInput ? "a" : "b")" operator="arithmetic" k1=".4" k2="-.3" k3=".8" k4=".07"/>
            """))
        let a = [128.0 / 255 * 0.5, 64.0 / 255 * 0.5, 32.0 / 255 * 0.5, 0.5]
        let b = sameInput ? a : [32.0 / 255 * 0.75, 128.0 / 255 * 0.75, 192.0 / 255 * 0.75, 0.75]
        let expected = zip(a, b).map { min(1, max(0, 0.4 * $0 * $1 - 0.3 * $0 + 0.8 * $1 + 0.07)) }
        let actual = pixel(bytes, x: 35, y: 35)
        for c in 0..<4 {
            #expect(abs(Double(actual[c]) - min(expected[c], expected[3]) * 255) <= 2)
        }
    }

    @Test func acceleratedIndependentGammaMatchesScalarEquation() throws {
        let bytes = try render(filtered("""
            <feFlood flood-color="#4080c0" flood-opacity=".5"/>
            <feComponentTransfer>
                <feFuncR type="gamma" exponent="1.3" amplitude=".8" offset=".1"/>
                <feFuncG type="gamma" exponent=".7"/>
                <feFuncB type="gamma" exponent="-.5" amplitude=".4"/>
                <feFuncA type="gamma" exponent="1.7"/>
            </feComponentTransfer>
            """))
        let alpha = pow(0.5, 1.7)
        let expected = [0.8 * pow(64.0 / 255, 1.3) + 0.1,
                        pow(128.0 / 255, 0.7), 0.4 * pow(192.0 / 255, -0.5), 1]
        let actual = pixel(bytes, x: 35, y: 35)
        for c in 0..<4 {
            #expect(abs(Double(actual[c]) - min(1, expected[c]) * alpha * 255) <= 2)
        }
        let zero = try render(filtered("""
            <feFlood flood-color="black" flood-opacity="0"/>
            <feComponentTransfer><feFuncA type="gamma" exponent="-1"/></feComponentTransfer>
            """))
        #expect(zero.allSatisfy { $0 == 0 })
    }

    @Test func acceleratedConvolutionMatchesScalarReference() throws {
        let content = """
            <rect x="0" y="0" width="8" height="8" fill="red" opacity=".5"/>
            <rect x="3" y="2" width="8" height="5" fill="blue" opacity=".75"/>
            """
        for (width, height) in [(8, 4), (11, 11)] {
            var weights = Array(repeating: 0.0, count: width * height)
            weights[0] = -0.25
            weights[width + 2] = 0.5
            weights[weights.count - 1] = 0.75
            let kernel = weights.map { String($0) }.joined(separator: " ")
            for edge in ["none", "duplicate", "wrap"] {
                for preserve in ["true", "false"] {
                    func primitive(step: String) -> String {
                        """
                        <feConvolveMatrix order="\(width) \(height)" kernelMatrix="\(kernel)"
                            targetX="1" targetY="2" divisor="1.25" bias=".1"
                            edgeMode="\(edge)" preserveAlpha="\(preserve)" kernelUnitLength="\(step)"/>
                        """
                    }
                    let fast = try render(filtered(primitive(step: "1"), content: content), scale: 1)
                    let source = try render(document(content), scale: 1)
                    func sample(_ x: Int, _ y: Int) -> [Double] {
                        var sx = x, sy = y
                        if edge == "duplicate" {
                            sx = min(29, max(0, sx))
                            sy = min(9, max(0, sy))
                        } else if edge == "wrap" {
                            sx = (sx % 30 + 30) % 30
                            sy = (sy % 10 + 10) % 10
                        }
                        if sx < 0 || sx >= 30 || sy < 0 || sy >= 10 {
                            return [0, 0, 0, 0]
                        }
                        return pixel(source, x: sx, y: sy, scale: 1).map { Double($0) / 255 }
                    }
                    var maximumError = 0.0
                    for y in 0..<10 {
                        for x in 0..<30 {
                            var sums = [Double](repeating: 0, count: 4)
                            for j in 0..<height {
                                for i in 0..<width {
                                    let value = sample(x + i - 1, y + j - 2)
                                    let weight = weights[(height - j - 1) * width + width - i - 1]
                                    for c in 0..<4 {
                                        let channel = preserve == "true" && c < 3
                                            ? (value[3] > 0 ? value[c] / value[3] : 0) : value[c]
                                        sums[c] += channel * weight
                                    }
                                }
                            }
                            let alpha = preserve == "true" ? sample(x, y)[3] : min(1, max(0, sums[3] / 1.25 + 0.1))
                            let actual = pixel(fast, x: x, y: y, scale: 1)
                            for c in 0..<4 {
                                let expected: Double
                                if c == 3 {
                                    expected = alpha
                                } else if preserve == "true" {
                                    expected = min(1, max(0, sums[c] / 1.25 + 0.1)) * alpha
                                } else {
                                    expected = min(alpha, max(0, sums[c] / 1.25 + 0.1 * alpha))
                                }
                                maximumError = max(maximumError, abs(Double(actual[c]) - expected * 255))
                            }
                        }
                    }
                    #expect(maximumError <= 3,
                            "Kernel \(width)x\(height), \(edge), preserveAlpha=\(preserve)")
                }
            }
        }
    }

    @Test func coreImageConvolutionMatchesGeneralKernels() throws {
        let content = """
            <rect x="0" y="0" width="8" height="8" fill="red" opacity=".5"/>
            <rect x="3" y="2" width="8" height="5" fill="blue" opacity=".75"/>
            """
        for (width, height) in [(3, 3), (5, 5), (7, 7), (9, 1), (1, 9), (2, 3)] {
            var small = Array(repeating: 0.0, count: width * height)
            small[0] = -0.25
            small[small.count / 2] = 0.75
            small[small.count - 1] = 0.5
            var large = Array(repeating: 0.0, count: 121)
            for y in 0..<height {
                for x in 0..<width {
                    large[(y + 11 - height) * 11 + x + 11 - width] = small[y * width + x]
                }
            }
            for edge in ["none", "duplicate", "wrap"] {
                func primitive(_ weights: [Double], width: Int, height: Int) -> String {
                    """
                    <feConvolveMatrix order="\(width) \(height)" kernelMatrix="\(weights.map { String($0) }.joined(separator: " "))"
                        targetX="0" targetY="0" divisor="1" edgeMode="\(edge)"/>
                    """
                }
                let fast = try render(filtered(primitive(small, width: width, height: height), content: content), scale: 1)
                let general = try render(filtered(primitive(large, width: 11, height: 11), content: content), scale: 1)
                #expect(zip(fast, general).allSatisfy { abs(Int($0) - Int($1)) <= 2 },
                    "Kernel \(width)x\(height), \(edge)")
            }
        }
    }

    @Test func coreImageGammaAndPolynomialRespectAlpha() throws {
        let bytes = try render(filtered("""
            <feFlood flood-color="#808080" flood-opacity=".5"/>
            <feComponentTransfer>
                <feFuncR type="gamma" exponent="1.5"/>
                <feFuncG type="gamma" exponent="1.5" amplitude=".5"/>
                <feFuncB type="gamma" exponent="1.5" offset=".1"/>
                <feFuncA type="linear" slope=".5"/>
            </feComponentTransfer>
            """))
        let value = pixel(bytes, x: 35, y: 35)
        let gamma = pow(128.0 / 255.0, 1.5)
        let expected = [gamma, gamma * 0.5, gamma + 0.1, 1].map { Int(($0 * 0.25 * 255).rounded()) }
        #expect(zip(value, expected).allSatisfy { abs(Int($0) - $1) <= 2 })
    }

    @Test func numericFilterAttributesUseSVGNumberSyntax() throws {
        let expected = try render(filtered("""
            <feDropShadow dx="2" dy="-1" stdDeviation=".5, 1" flood-opacity=".5"/>
            """))
        let scientific = try render(filtered("""
            <feDropShadow dx="+2e0" dy="-1E+0" stdDeviation="5e-1, 1e0" flood-opacity="5e1%"/>
            """))
        #expect(scientific == expected)
        let defaults = try render(filtered("<feDropShadow/>"))
        for invalid in ["1e", "1,,2", "1,", "1px", "1e999"] {
            let actual = try render(filtered("<feDropShadow dx=\"\(invalid)\" stdDeviation=\"\(invalid)\"/>"))
            #expect(actual.elementsEqual(defaults), "Invalid numeric attribute: \(invalid)")
        }
    }

    @Test func filterPresentationAttributesUseSharedStyleCascade() throws {
        let root = try parse("""
            <style>
                feDiffuseLighting { lighting-color: red; color-interpolation-filters: sRGB; }
            </style>
            <defs><filter id="f">
                <feDiffuseLighting lighting-color="blue" surfaceScale="2"
                    style="lighting-color: lime; color-interpolation-filters: linearRGB">
                    <fePointLight x="1" y="2" z="3"/>
                </feDiffuseLighting>
            </filter></defs>
            <rect width="10" height="10" filter="url(#f)"/>
            """)
        let primitive = try #require(root.children.first?.filter?.primitives.first)
        #expect(primitive.parameters[IJSVGAttributeLightingColor] == "lime")
        #expect(primitive.parameters[IJSVGAttributeSurfaceScale] == "2")
        #expect(primitive.filterColorInterpolation == "linearRGB")
        let light = try #require(primitive.children.first as? IJSVGFilterPrimitive)
        #expect(light.parameters[IJSVGAttributeZ] == "3")
    }

}

extension IJSVGFilterTests {
    private func transformTestElement(_ element: String, color: String, attributes: String = "") -> String {
        switch element {
        case "rect":
            return "<rect x=\"-1\" y=\"-1\" width=\"2\" height=\"2\" fill=\"\(color)\" \(attributes)/>"
        case "circle":
            return "<circle r=\"1\" fill=\"\(color)\" \(attributes)/>"
        case "ellipse":
            return "<ellipse rx=\"1\" ry=\".7\" fill=\"\(color)\" \(attributes)/>"
        case "polygon":
            return "<polygon points=\"-1,-1 1,-1 0,1\" fill=\"\(color)\" \(attributes)/>"
        case "line":
            return "<line x1=\"-1\" y1=\"0\" x2=\"1\" y2=\"0\" stroke=\"\(color)\" stroke-width=\"1\" \(attributes)/>"
        case "polyline":
            return "<polyline points=\"-1,-1 0,1 1,-1\" fill=\"none\" stroke=\"\(color)\" stroke-width=\".5\" \(attributes)/>"
        case "use":
            return "<use href=\"#shape\" fill=\"\(color)\" \(attributes)/>"
        default:
            return "<path d=\"M-1-1 H1 V1 H-1 Z\" fill=\"\(color)\" \(attributes)/>"
        }
    }

    private func expectTransformPixels(_ actual: [UInt8], match expected: [UInt8], scale: Int = 10) {
        #expect(actual.count == expected.count)
        // Measure only occupied pixels so a mostly empty canvas cannot hide a misplaced shape.
        let occupied = stride(from: 3, to: expected.count, by: 4).filter {
            actual[$0] != 0 || expected[$0] != 0
        }
        #expect(occupied.count > 50)
        let difference = occupied.reduce(0) { total, alpha in
            total + (0..<4).reduce(0) {
                $0 + abs(Int(actual[alpha - $1]) - Int(expected[alpha - $1]))
            }
        }
        // Filtering rasterizes before the final transform; direct vector drawing does not.
        // Allow up to 3% mean channel error at edges, but separately constrain geometry.
        #expect(Double(difference) / Double(max(1, occupied.count * 4)) < 255 * 0.03)
        let width = 30 * scale
        let actualAlpha = occupied.reduce(0.0) { $0 + Double(actual[$1]) }
        let expectedAlpha = occupied.reduce(0.0) { $0 + Double(expected[$1]) }
        #expect(expectedAlpha > 0)
        #expect(abs(actualAlpha - expectedAlpha) / max(1, expectedAlpha) < 0.03)
        for axis in [0, 1] {
            let actualCenter = occupied.reduce(0.0) {
                let coordinate = axis == 0 ? ($1 / 4) % width : ($1 / 4) / width
                return $0 + Double(coordinate) * Double(actual[$1])
            } / max(1, actualAlpha)
            let expectedCenter = occupied.reduce(0.0) {
                let coordinate = axis == 0 ? ($1 / 4) % width : ($1 / 4) / width
                return $0 + Double(coordinate) * Double(expected[$1])
            } / max(1, expectedAlpha)
            #expect(abs(actualCenter - expectedCenter) < 0.5)
        }
        // Pixels surrounded by a solid 5x5 reference neighborhood must retain their color.
        for alpha in occupied where expected[alpha] == 255 {
            let x = (alpha / 4) % width
            let y = (alpha / 4) / width
            guard x >= 2, x < width - 2, y >= 2, y < 10 * scale - 2 else { continue }
            let solid = (-2...2).allSatisfy { dy in
                (-2...2).allSatisfy { dx in
                    let neighbor = alpha + (dy * width + dx) * 4
                    return (0..<4).allSatisfy { expected[neighbor - $0] == expected[alpha - $0] }
                }
            }
            if solid {
                #expect((0..<4).allSatisfy { abs(Int(actual[alpha - $0]) - Int(expected[alpha - $0])) <= 2 })
            }
        }
    }

    private func expectTransformExport(_ original: String, pixels: [UInt8], scale: Int) throws {
        let svg = try #require(IJSVG(svgString: original))
        let size = CGSize(width: 30 * scale, height: 10 * scale)
        let exporter = try #require(IJSVGExporter(svg: svg, size: size, options: .all))
        let exported = try #require(exporter.svgString())
        let xml = try XMLDocument(xmlString: exported)
        #expect(try xml.nodes(forXPath: "//filter").isEmpty == false)
        #expect(try xml.nodes(forXPath: "//image").isEmpty)
        expectTransformPixels(try render(exported, scale: scale), match: pixels, scale: scale)
    }

    @Test(arguments: ["rect", "circle", "ellipse", "path", "polygon", "line", "polyline", "use"], [
        "translate(8 3) scale(1.5 .75)",
        "translate(12 3) rotate(90) scale(1.5 .75)",
        "matrix(1 .2 .3 1 8 3) skewX(15) scale(1.2 .8)"
    ])
    func multipleTransformsAndFilterLists(element: String, transform: String) throws {
        let definitions = """
            <defs>
                <path id="shape" d="M-1-1 H1 V1 H-1 Z"/>
                <filter id="offset" filterUnits="userSpaceOnUse" x="-10" y="-10" width="40" height="30">
                    <feOffset dx="2" dy="0"/>
                </filter>
                <filter id="color" filterUnits="userSpaceOnUse" x="-10" y="-10" width="40" height="30">
                    <feColorMatrix type="matrix" values="0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 1 0"/>
                </filter>
            </defs>
            """
        let original = document("""
            \(definitions)
            \(transformTestElement(element, color: "red",
                attributes: "transform=\"\(transform)\" filter=\"url(#offset) url(#color)\""))
            """)
        // Offset uses local element coordinates before the transform list.
        let expected = document("""
            \(definitions)
            <g transform="\(transform)"><g transform="translate(2 0)">
                \(transformTestElement(element, color: "lime"))
            </g></g>
            """)
        for scale in [10, 20] {
            let pixels = try render(original, scale: scale)
            expectTransformPixels(pixels, match: try render(expected, scale: scale), scale: scale)
            try expectTransformExport(original, pixels: pixels, scale: scale)
        }
    }

    @Test(arguments: ["rect", "circle", "ellipse", "path", "polygon", "line", "polyline", "use"])
    func transformedElementsInsideFilteredGroups(element: String) throws {
        let definitions = """
            <defs>
                <path id="shape" d="M-1-1 H1 V1 H-1 Z"/>
                <filter id="shadow" filterUnits="userSpaceOnUse" x="-10" y="-10" width="40" height="30">
                    <feDropShadow dx="3" dy="0" stdDeviation="0" flood-color="cyan"/>
                </filter>
                <filter id="parent" filterUnits="userSpaceOnUse" x="-10" y="-10" width="40" height="30">
                    <feOffset dx="2" dy="1"/>
                </filter>
            </defs>
            """
        let original = document("""
            \(definitions)
            <g transform="translate(5 1) scale(1.2 .8)" filter="url(#parent)">
                <g transform="translate(2 2) rotate(15)">
                    \(transformTestElement(element, color: "red",
                        attributes: "transform=\"scale(1.5 .8)\" filter=\"url(#shadow)\""))
                </g>
            </g>
            """)
        // The parent offset moves both the source and the shadow of its child together.
        let expected = document("""
            \(definitions)
            <g transform="translate(5 1) scale(1.2 .8)">
                <g transform="translate(2 1)">
                    <g transform="translate(2 2) rotate(15)"><g transform="scale(1.5 .8)">
                        <g transform="translate(3 0)">\(transformTestElement(element, color: "cyan"))</g>
                        \(transformTestElement(element, color: "red"))
                    </g></g>
                </g>
            </g>
            """)
        let pixels = try render(original)
        expectTransformPixels(pixels, match: try render(expected))
        try expectTransformExport(original, pixels: pixels, scale: 10)
    }

    @Test(arguments: [false, true])
    func transformedFilterOrderChangesShadowColor(reverse: Bool) throws {
        let filters = reverse ? "url(#color) url(#shadow)" : "url(#shadow) url(#color)"
        let original = document("""
            <defs>
                <filter id="shadow" filterUnits="userSpaceOnUse" x="-10" y="-10" width="40" height="30">
                    <feDropShadow dx="3" dy="0" stdDeviation="0" flood-color="red"/>
                </filter>
                <filter id="color" filterUnits="userSpaceOnUse" x="-10" y="-10" width="40" height="30">
                    <feColorMatrix type="matrix" values="0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 1 0"/>
                </filter>
            </defs>
            <g transform="translate(6 1)">
                <rect x="0" y="0" width="2" height="2" fill="red"
                    transform="translate(2 1) scale(2 1)" filter="\(filters)"/>
            </g>
            """)
        let pixels = try render(original)
        #expect(pixel(pixels, x: 100, y: 30) == [0, 255, 0, 255])
        #expect(pixel(pixels, x: 160, y: 30) == (reverse ? [255, 0, 0, 255] : [0, 255, 0, 255]))
        #expect(pixel(pixels, x: 130, y: 30)[3] == 0)
        try expectTransformExport(original, pixels: pixels, scale: 10)
    }
}

extension IJSVGFilterTests {
    @Test(arguments: ["displacement", "convolution"])
    func largeSamplingFiltersPreserveImageAndRowBoundaries(effect: String) throws {
        let content = """
            <rect x="1" y="1" width="9" height="3" fill="#804020" opacity=".6"/>
            <circle cx="17" cy="6" r="3" fill="#2080c0" opacity=".8"/>
            """
        let primitive = effect == "displacement" ? """
            <feFlood flood-color="white" result="map"/>
            <feDisplacementMap in="SourceGraphic" in2="map" scale="2"/>
            """ : """
            <feConvolveMatrix order="1" kernelMatrix="1" kernelUnitLength=".075 .125" preserveAlpha="true"/>
            """
        let reference = effect == "displacement" ? "<feOffset dx=\"-1\" dy=\"-1\"/>" : "<feOffset/>"
        let actual = try render(filtered(primitive, content: content), scale: 20)
        let expected = try render(filtered(reference, content: content), scale: 20)
        let maximumError = zip(actual, expected).reduce(0) { max($0, abs(Int($1.0) - Int($1.1))) }
        #expect(maximumError <= 2)
    }

    @Test(arguments: [false, true])
    func largeArithmeticAndTransferMatchEquations(transfer: Bool) throws {
        let primitive = transfer ? """
            <feFlood flood-color="#4080c0" flood-opacity=".5"/>
            <feComponentTransfer>
                <feFuncR type="gamma" exponent="1.3" amplitude=".8" offset=".1"/>
                <feFuncG type="gamma" exponent=".7"/>
                <feFuncB type="gamma" exponent="-.5" amplitude=".4"/>
                <feFuncA type="gamma" exponent="1.7"/>
            </feComponentTransfer>
            """ : """
            <feFlood flood-color="#804020" flood-opacity=".5" result="a"/>
            <feFlood flood-color="#2080c0" flood-opacity=".75" result="b"/>
            <feComposite in="a" in2="b" operator="arithmetic" k1=".4" k2="-.3" k3=".8" k4=".07"/>
            """
        let expected: [Double]
        if transfer {
            let alpha = pow(0.5, 1.7)
            expected = [0.8 * pow(64.0 / 255, 1.3) + 0.1, pow(128.0 / 255, 0.7),
                        0.4 * pow(192.0 / 255, -0.5), 1].map { min(1, $0) * alpha * 255 }
        } else {
            let a = [128.0 / 255 * 0.5, 64.0 / 255 * 0.5, 32.0 / 255 * 0.5, 0.5]
            let b = [32.0 / 255 * 0.75, 128.0 / 255 * 0.75, 192.0 / 255 * 0.75, 0.75]
            let values = zip(a, b).map { min(1, max(0, 0.4 * $0 * $1 - 0.3 * $0 + 0.8 * $1 + 0.07)) }
            expected = values.map { min($0, values[3]) * 255 }
        }
        let bytes = try render(filtered(primitive), scale: 20)
        for channel in 0..<4 {
            #expect(stride(from: channel, to: bytes.count, by: 4).allSatisfy {
                abs(Double(bytes[$0]) - expected[channel]) <= 2
            })
        }
    }

    @Test func chainedCPUFiltersPreserveVerticalOrientationAndColorSpace() throws {
        let content = """
            <rect x="2" y="1" width="6" height="3" fill="#804020" opacity=".5"/>
            <rect x="10" y="6" width="7" height="3" fill="#2080c0" opacity=".75"/>
            """
        let identity = """
            <feConvolveMatrix order="1" kernelMatrix="1" kernelUnitLength=".075 .125" preserveAlpha="true"/>
            """
        let actual = try render(filtered("""
            <feConvolveMatrix order="1" kernelMatrix="1" kernelUnitLength=".075 .125"
                preserveAlpha="true" color-interpolation-filters="linearRGB"/>
            \(identity)
            <feConvolveMatrix order="1" kernelMatrix="1" kernelUnitLength=".075 .125"
                preserveAlpha="true" color-interpolation-filters="linearRGB"/>
            """, content: content), scale: 20)
        let expected = try render(filtered("<feOffset/>", content: content), scale: 20)
        #expect(zip(actual, expected).allSatisfy { abs(Int($0) - Int($1)) <= 2 })
    }
}

extension IJSVGFilterTests {
    @Test(arguments: ["displacement", "none", "duplicate", "wrap"])
    func fractionalSamplingMatchesBilinearReference(mode: String) throws {
        let content = """
            <rect x="1" y="0" width="9" height="5" fill="#804020" opacity=".6"/>
            <rect x="16" y="6" width="8" height="4" fill="#2080c0" opacity=".8"/>
            """
        let source = try render(document(content), scale: 1)
        let primitive = mode == "displacement" ? """
            <feFlood flood-color="white" flood-opacity=".25" result="map"/>
            <feDisplacementMap in="clipped" in2="map" scale="3"/>
            """ : """
            <feConvolveMatrix in="clipped" order="1 3" kernelMatrix="1 0 0"
                targetY="1" kernelUnitLength=".75 1.25" edgeMode="\(mode)"/>
            """
        let actual = try render(filtered("""
            <feOffset in="SourceGraphic" x="2" y="1" width="20" height="8" result="clipped"/>
            \(primitive)
            """, content: content), scale: 1)
        func sample(_ x: Int, _ y: Int, _ channel: Int) -> Double {
            var sx = x, sy = y
            if mode == "duplicate" {
                sx = min(21, max(2, sx))
                sy = min(8, max(1, sy))
            } else if mode == "wrap" {
                sx = 2 + ((sx - 2) % 20 + 20) % 20
                sy = 1 + ((sy - 1) % 8 + 8) % 8
            }
            guard (2..<22).contains(sx), (1..<9).contains(sy) else { return 0 }
            return Double(pixel(source, x: sx, y: sy, scale: 1)[channel])
        }
        var maximumError = 0.0
        for y in 0..<10 {
            for x in 0..<30 {
                let px = Double(x) + (mode == "displacement" ? -0.75 : 0)
                let py = Double(y) + (mode == "displacement" ? -0.75 : 1.25)
                let ix = Int(floor(px)), iy = Int(floor(py))
                let fx = px - Double(ix), fy = py - Double(iy)
                let value = pixel(actual, x: x, y: y, scale: 1)
                for channel in 0..<4 {
                    var expected = 0.0
                    if mode == "displacement" || ((2..<22).contains(x) && (1..<9).contains(y)) {
                        expected = sample(ix, iy, channel) * (1 - fx) * (1 - fy)
                            + sample(ix + 1, iy, channel) * fx * (1 - fy)
                            + sample(ix, iy + 1, channel) * (1 - fx) * fy
                            + sample(ix + 1, iy + 1, channel) * fx * fy
                    }
                    maximumError = max(maximumError, abs(Double(value[channel]) - expected))
                }
            }
        }
        #expect(maximumError <= 2)
    }

    @Test func clippedTurbulenceMatchesFullRegionNoise() throws {
        let full = try render(filtered("""
            <feTurbulence baseFrequency=".17 .31" seed="7" numOctaves="4" type="fractalNoise"/>
            <feOffset x="3.25" y="1.5" width="20.5" height="7"/>
            """), scale: 20)
        let clipped = try render(filtered("""
            <feTurbulence baseFrequency=".17 .31" seed="7" numOctaves="4" type="fractalNoise"
                x="3.25" y="1.5" width="20.5" height="7"/>
            """), scale: 20)
        #expect(zip(full, clipped).allSatisfy { abs(Int($0) - Int($1)) <= 1 })
    }
}

extension IJSVGFilterTests {
    @Test(arguments: ["lighting", "displacement"])
    func clippedCPUFilterMatchesClippedFullOutput(effect: String) throws {
        let content = """
            <rect x="1" y="1" width="12" height="5" fill="#804020" opacity=".6"/>
            <circle cx="17" cy="6" r="3" fill="#2080c0" opacity=".8"/>
            """
        let bounds = "x=\"3.25\" y=\"1.5\" width=\"20.5\" height=\"7\""
        func primitive(_ attributes: String) -> String {
            if effect == "lighting" {
                return """
                    <feDiffuseLighting surfaceScale="2" lighting-color="#804020" \(attributes)>
                        <fePointLight x="10" y="5" z="20"/>
                    </feDiffuseLighting>
                    """
            }
            return """
                <feFlood flood-color="white" flood-opacity=".25" result="map"/>
                <feDisplacementMap in="SourceGraphic" in2="map" scale="3" \(attributes)/>
                """
        }
        let full = try render(filtered(primitive("") + "<feOffset \(bounds)/>", content: content), scale: 20)
        let clipped = try render(filtered(primitive(bounds), content: content), scale: 20)
        #expect(zip(full, clipped).allSatisfy { abs(Int($0) - Int($1)) <= 1 })
    }

    @Test(arguments: ["sRGB", "linearRGB"])
    func longMergeKeepsPrimitiveColorSpace(colorSpace: String) throws {
        let colors = ["#804020", "#2080c0", "#40c080"]
        let floods = colors.enumerated().map {
            "<feFlood flood-color=\"\($0.element)\" flood-opacity=\".25\" result=\"paint\($0.offset)\"/>"
        }.joined()
        let nodes = (0..<12).map { "<feMergeNode in=\"paint\($0 % 3)\"/>" }.joined()
        let bytes = try render(filtered(floods + "<feMerge>\(nodes)</feMerge>",
                                       attributes: "color-interpolation-filters=\"\(colorSpace)\""))
        let values = [[128.0, 64.0, 32.0], [32.0, 128.0, 192.0], [64.0, 192.0, 128.0]]
        var result = [0.0, 0.0, 0.0]
        var alpha = 0.0
        for index in 0..<12 {
            alpha = 0.25 + alpha * 0.75
            for channel in 0..<3 {
                let encoded = values[index % 3][channel] / 255
                let value = colorSpace == "sRGB" ? encoded
                    : (encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055, 2.4))
                result[channel] = value * 0.25 + result[channel] * 0.75
            }
        }
        let actual = pixel(bytes, x: 35, y: 35)
        for channel in 0..<3 {
            let straight = result[channel] / alpha
            let encoded = colorSpace == "sRGB" ? straight
                : (straight <= 0.0031308 ? straight * 12.92 : 1.055 * pow(straight, 1 / 2.4) - 0.055)
            #expect(abs(Double(actual[channel]) - encoded * alpha * 255) <= 2)
        }
        #expect(abs(Double(actual[3]) - alpha * 255) <= 1)
    }
}
