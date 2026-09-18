// swift-tools-version: 6.2

import Foundation
import PackageDescription

let package = Package(
    name: "ttfx-swift",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "TTFXVideoCapture", targets: ["TTFXVideoCapture"]),
        .executable(name: "TTFXComparisonApp", targets: ["TTFXComparisonApp"]),
        .library(
            name: "ttfx-swift",
            targets: ["TTFXCore", "TTFXEffects"]
        ),
        .library(
            name: "TTFXSwiftUI",
            targets: ["TTFXSwiftUI"]
        ),
        .executable(
            name: "ttfx",
            targets: ["TTFXCLI"]
        ),
        .executable(
            name: "TTFXGalleryApp",
            targets: ["TTFXGalleryApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(name: "TTFXVideoCapture", dependencies: ["TTFXCore", "TTFXEffects", "TTFXSwiftUI", "TTFXComparisonKit"], path: "Sources/TTFXVideoCapture"),
        .target(name: "TTFXComparisonKit", path: "Sources/TTFXComparisonKit"),
        .executableTarget(name: "TTFXComparisonApp", dependencies: ["TTFXComparisonKit", "TTFXEffects"], path: "Sources/TTFXComparisonApp"),
        .testTarget(name: "TTFXComparisonTests", dependencies: ["TTFXComparisonKit", "TTFXVideoCapture", "TTFXComparisonApp"], path: "tests/TTFXComparisonTests"),
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
            path: "Sources/ttfx-swift/SwiftUI",
            exclude: ["TTFXGalleryApp"],
            resources: [.copy("Shaders")]
        ),
        .executableTarget(
            name: "TTFXGalleryApp",
            dependencies: [
                "TTFXCore",
                "TTFXEffects",
                "TTFXSwiftUI"
            ],
            path: "Sources/ttfx-swift/SwiftUI/TTFXGalleryApp",
            exclude: ["Info.plist"]
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
            dependencies: ["TTFXCLI", "TTFXCore", "TTFXEffects"],
            path: "tests/ttfx-cliTests"
        ),
        .testTarget(
            name: "TTFXSwiftUITests",
            dependencies: ["TTFXSwiftUI"],
            path: "tests/ttfx-swiftUITests"
        ),
        .testTarget(
            name: "TTFXGalleryAppTests",
            dependencies: ["TTFXGalleryApp"],
            path: "tests/TTFXGalleryAppTests"
        )
    ]
)

// The CLI reuses the same engine sources without evaluating any graphical targets.
// GUI products remain the default graph for existing macOS/Xcode workflows.
if ProcessInfo.processInfo.environment["TTFX_CLI_ONLY"] == "1" {
    let portableTargets: Set<String> = [
        "TTFXCore", "TTFXEffects", "TTFXCLI",
        "TTFXCoreTests", "TTFXEffectsTests", "TTFXCLITests"
    ]
    package.targets.removeAll { !portableTargets.contains($0.name) }
    package.products.removeAll { !["ttfx", "ttfx-swift"].contains($0.name) }
}
