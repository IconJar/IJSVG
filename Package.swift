// swift-tools-version: 6.0
//
//  Package.swift
//  IJSVG
//
//  Created by Curtis Hard on 03/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "IJSVG",
    platforms: [
        .macOS("14.6"),
        .iOS(.v16),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "IJSVG", targets: ["IJSVG"])
    ],
    targets: [
        .target(
            name: "IJSVG",
            path: "Framework/IJSVG/IJSVG",
            exclude: ["Info.plist"],
            resources: [
                .copy("Source/Rendering/FilterShaders/IJSVGBlur.metal"),
                .copy("Source/Rendering/FilterShaders/IJSVGInnerShadow.metal"),
                .copy("Source/Rendering/FilterShaders/IJSVGSeparableBlur.cimetal"),
                .copy("Source/Rendering/FilterShaders/IJSVGSubtract.cimetal"),
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("PrivateHeaders/IJSVG"),
                .headerSearchPath("Source/Nodes"),
                .headerSearchPath("Source/Exporter"),
                .headerSearchPath("Source/Rendering"),
                .headerSearchPath("Source/Parsing"),
                .headerSearchPath("Source/Stylesheets")
            ],
            linkerSettings: [
                .linkedLibrary("xml2"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreText"),
                .linkedFramework("ImageIO"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreImage"),
                .linkedFramework("Metal"),
                .linkedFramework("Accelerate"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .target(
            name: "IJSVGTestSupport",
            dependencies: ["IJSVG"],
            path: "Tests/IJSVGTestSupport",
            publicHeadersPath: "include"
        ),
        .testTarget(name: "IJSVGPlatformTests", dependencies: ["IJSVG"]),
        .testTarget(
            name: "IJSVGTests",
            dependencies: ["IJSVG", "IJSVGTestSupport"]
        )
    ],
    cLanguageStandard: .gnu11
)
