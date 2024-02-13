// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IJSVG",
    platforms: [.macOS("14.6")],
    products: [
        .library(name: "IJSVG", targets: ["IJSVG"])
    ],
    dependencies: [
        .package(url: "https://github.com/Archery-Inc/TouchXML.git", branch: "mutability")
    ],
    targets: [
        .target(
            name: "IJSVG",
            dependencies: [.product(name: "TouchXML", package: "TouchXML")],
            path: "Framework/IJSVG/IJSVG",
            exclude: ["Info.plist"],
            resources: [
                .copy("Source/Rendering/FilterShaders/IJSVGBlur.metal"),
                .copy("Source/Rendering/FilterShaders/IJSVGInnerShadow.metal"),
                .copy("Source/Rendering/FilterShaders/IJSVGSeparableBlur.metal"),
                .copy("Source/Rendering/FilterShaders/IJSVGSubtract.metal"),
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("PrivateHeaders"),
                .headerSearchPath("Source/Rendering")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Quartz"),
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
        .testTarget(
            name: "IJSVGTests",
            dependencies: ["IJSVG", "IJSVGTestSupport"]
        )
    ],
    cLanguageStandard: .gnu11
)
