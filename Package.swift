// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ttfx-swift",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ttfx-swift",
            targets: ["TTFXCore"]
        ),
        .library(
            name: "TTFXSwiftUI",
            targets: ["TTFXSwiftUI"]
        ),
        .executable(
            name: "ttfx",
            targets: ["TTFXCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "TTFXCore",
            path: "Sources/ttfx-swift/Core"
        ),
        .target(
            name: "TTFXEffects",
            dependencies: ["TTFXCore"],
            path: "Sources/ttfx-swift/Effects"
        ),
        .target(
            name: "TTFXSwiftUI",
            dependencies: [
                "TTFXCore",
                "TTFXEffects"
            ],
            path: "Sources/ttfx-swift/SwiftUI"
        ),
        .executableTarget(
            name: "TTFXCLI",
            dependencies: [
                "TTFXCore",
                "TTFXEffects",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/ttfx-swift/CLI"
        ),
        .testTarget(
            name: "TTFXCoreTests",
            dependencies: ["TTFXCore"],
            path: "tests/ttfx-swiftTests"
        ),
        .testTarget(
            name: "TTFXEffectsTests",
            dependencies: ["TTFXEffects"],
            path: "tests/ttfx-effectsTests"
        ),
        .testTarget(
            name: "TTFXCLITests",
            dependencies: ["TTFXCLI"],
            path: "tests/ttfx-cliTests"
        ),
        .testTarget(
            name: "TTFXSwiftUITests",
            dependencies: ["TTFXSwiftUI"],
            path: "tests/ttfx-swiftUITests"
        )
    ]
)
