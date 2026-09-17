import Foundation
import Testing
import TTFXEffects
@testable import TTFXGalleryApp

@Test func galleryViewModelUsesRegistryOrderAndDefaultSelection() throws {
    let model = try TTFXGalleryViewModel(metalAvailability: .init(isAvailable: false, message: "headless"))

    #expect(model.effectNames == EffectRegistry.names)
    #expect(model.effectNames.count == 37)
    #expect(model.selectedEffectName == "print")
    #expect(model.sampleText == "Hello")
    #expect(!model.sampleText.localizedCaseInsensitiveContains("Swift"))
    #expect(!model.sampleText.localizedCaseInsensitiveContains("TTFX"))
    #expect(!model.currentSnapshot.visibleTextLines.joined(separator: "\n").localizedCaseInsensitiveContains("TTFX"))
}

@MainActor
@Test func rootViewUsesLargePreviewArea() throws {
    #expect(TTFXGalleryRootView.previewMinimumWidth >= 640)
    #expect(TTFXGalleryRootView.previewMinimumHeight >= 480)
}

@MainActor
@Test func rootViewKeepsEffectSelectorInVisibleControlsSidebar() throws {
    #expect(TTFXGalleryRootView.controlsMinimumWidth >= 260)
    #expect(TTFXGalleryRootView.accessibilityLabels.contains("Effect picker"))
}

@Test func visiblePreviewPrefersRenderedEffectFramesWhenAvailable() throws {
    var model = try TTFXGalleryViewModel(metalAvailability: .init(isAvailable: false, message: "headless"))
    model.play()
    model.advanceFrame()

    let lines = TTFXGalleryRootView.visiblePreviewLines(snapshot: model.currentSnapshot, sampleText: model.sampleText)
    #expect(lines.joined(separator: "\n") != model.sampleText)
    #expect(lines.joined(separator: "\n").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty == false)
}

@Test func visiblePreviewFallsBackToTextFieldWhenRenderedFrameIsBlank() throws {
    let model = try TTFXGalleryViewModel(sampleText: "Hello", metalAvailability: .init(isAvailable: false, message: "headless"))
    let blankLines = Array(repeating: String(repeating: " ", count: model.canvasWidth), count: model.canvasHeight)

    let lines = TTFXGalleryRootView.visiblePreviewLines(visibleTextLines: blankLines, sampleText: model.sampleText)
    #expect(lines == ["Hello"])
}

@Test func previewFontSizeIsConfigurableAndClampedToSafeBounds() throws {
    var model = try TTFXGalleryViewModel(metalAvailability: .init(isAvailable: false, message: "headless"))

    #expect(model.previewFontSize == 48)
    #expect(TTFXGalleryViewModel.defaultPreviewFontSize == 48)

    model.setPreviewFontSize(4)
    #expect(model.previewFontSize == TTFXGalleryViewModel.minimumPreviewFontSize)

    model.setPreviewFontSize(10_000)
    #expect(model.previewFontSize == TTFXGalleryViewModel.maximumPreviewFontSize)

    model.setPreviewFontSize(28)
    #expect(model.previewFontSize == 28)

    model.incrementPreviewFontSize()
    #expect(model.previewFontSize == 29)

    model.decrementPreviewFontSize()
    #expect(model.previewFontSize == 28)
}

@Test func previewCanvasSizeScalesWithCanvasAndFontControls() throws {
    let small = TTFXGalleryRootView.visiblePreviewMinimumSize(canvasWidth: 24, canvasHeight: 8, fontSize: 48)
    let wide = TTFXGalleryRootView.visiblePreviewMinimumSize(canvasWidth: 48, canvasHeight: 8, fontSize: 48)
    let tall = TTFXGalleryRootView.visiblePreviewMinimumSize(canvasWidth: 24, canvasHeight: 16, fontSize: 48)

    #expect(small.width >= TTFXGalleryRootView.previewMinimumWidth)
    #expect(small.height >= TTFXGalleryRootView.previewMinimumHeight)
    #expect(wide.width > small.width)
    #expect(tall.height > small.height)
}

@Test func canvasControlStepsReinitializeRenderedPreview() throws {
    var model = try TTFXGalleryViewModel(metalAvailability: .init(isAvailable: false, message: "headless"))
    let initialSummary = model.previewSummary

    model.incrementCanvasWidth()
    model.incrementCanvasHeight()

    #expect(model.canvasWidth == 25)
    #expect(model.canvasHeight == 9)
    #expect(model.previewSummary != initialSummary)
    #expect(model.previewSummary == "print seed 42 canvas 25x9")
    #expect(model.currentSnapshot.visibleTextLines.count == 9)
}

@Test func loopPlaybackResetsAtDeterministicFrameBudgetAndContinuesOnlyWhenEnabled() throws {
    var model = try TTFXGalleryViewModel(metalAvailability: .init(isAvailable: false, message: "headless"), loopFrameBudget: 2)

    #expect(!model.isLooping)
    model.play()
    model.advanceFrame()
    model.advanceFrame()
    model.advanceFrame()
    #expect(model.frameIndex == 2)
    #expect(!model.isPlaying)

    model.setLooping(true)
    #expect(model.isLooping)
    model.play()
    model.advanceFrame()
    model.advanceFrame()
    #expect(model.frameIndex == 1)
    #expect(model.isPlaying)
}

@Test func galleryViewModelUpdatesControlsAndClampsCanvasBounds() throws {
    var model = try TTFXGalleryViewModel(metalAvailability: .init(isAvailable: false, message: "headless"))

    model.sampleText = "Edited text"
    model.seed = 99
    model.setCanvasWidth(-20)
    model.setCanvasHeight(10_000)
    model.selectEffect("wipe")

    #expect(model.sampleText == "Edited text")
    #expect(model.seed == 99)
    #expect(model.canvasWidth == TTFXGalleryViewModel.minimumCanvasColumns)
    #expect(model.canvasHeight == TTFXGalleryViewModel.maximumCanvasRows)
    #expect(model.selectedEffectName == "wipe")
    #expect(model.frameIndex == 0)
}

@Test func playbackAdvancesOnlyWhilePlayingAndResetIsDeterministic() throws {
    var model = try TTFXGalleryViewModel(metalAvailability: .init(isAvailable: false, message: "headless"))

    let initial = model.currentSnapshot
    model.advanceFrame()
    #expect(model.frameIndex == 0)
    #expect(model.currentSnapshot == initial)

    model.play()
    model.advanceFrame()
    let advanced = model.currentSnapshot
    #expect(model.frameIndex == 1)

    model.pause()
    model.advanceFrame()
    #expect(model.frameIndex == 1)
    #expect(model.currentSnapshot == advanced)

    model.reset()
    #expect(model.frameIndex == 0)
    #expect(model.currentSnapshot == initial)
}

@Test func rendererStateReinitializesWhenSeedOrEffectChanges() throws {
    var model = try TTFXGalleryViewModel(metalAvailability: .init(isAvailable: false, message: "headless"))
    model.play()
    model.advanceFrame()
    #expect(model.frameIndex == 1)

    model.seed = 123
    #expect(model.frameIndex == 0)
    #expect(model.previewSummary == "print seed 123 canvas 24x8")

    model.selectEffect("wipe")
    #expect(model.selectedEffectName == "wipe")
    #expect(model.frameIndex == 0)
    #expect(model.previewSummary == "wipe seed 123 canvas 24x8")
}

@MainActor
@Test func rendererStatusAndAccessibilityLabelsAreHeadlessInspectable() throws {
    let model = try TTFXGalleryViewModel(metalAvailability: .init(isAvailable: false, message: "headless disabled"))

    #expect(model.rendererStatus == "SwiftUI preview — headless disabled")
    #expect(TTFXGalleryRootView.accessibilityLabels == [
        "TTFX Gallery App",
        "Effect picker",
        "Sample text",
        "Seed",
        "Canvas width",
        "Canvas height",
        "Frames per second",
        "Preview font size",
        "Loop playback",
        "Play or pause preview",
        "Reset preview",
        "TTFX preview",
        "Renderer status"
    ])
}

@Test func frameRateStateControlsFrameTiming() throws {
    var model = try TTFXGalleryViewModel(metalAvailability: .init(isAvailable: false, message: "headless"))

    #expect(model.framesPerSecond == 60)
    #expect(model.frameIntervalMilliseconds == 16)

    model.setFramesPerSecond(24)
    #expect(model.framesPerSecond == 24)
    #expect(model.frameIntervalMilliseconds == 42)

    model.setFramesPerSecond(0)
    #expect(model.framesPerSecond == TTFXGalleryViewModel.minimumFramesPerSecond)

    model.setFramesPerSecond(10_000)
    #expect(model.framesPerSecond == TTFXGalleryViewModel.maximumFramesPerSecond)
}

@Test func previewRendererSelectionUsesVisibleSwiftUIFallbackUntilDrawableRenderingIsImplemented() throws {
    let fallback = TTFXGalleryPreviewRendererSelection.resolve(
        availability: .init(isAvailable: false, message: "headless"),
        platformSupportsMetalView: true
    )
    #expect(fallback == .swiftUIFrameView)
    #expect(TTFXGalleryPreviewRendererSelection.statusText(
        availability: .init(isAvailable: false, message: "headless"),
        platformSupportsMetalView: true
    ) == "SwiftUI preview — headless")

    let unsupported = TTFXGalleryPreviewRendererSelection.resolve(
        availability: .init(isAvailable: true, message: "Metal renderer available"),
        platformSupportsMetalView: false
    )
    #expect(unsupported == .swiftUIFrameView)
    #expect(TTFXGalleryPreviewRendererSelection.statusText(
        availability: .init(isAvailable: true, message: "Metal renderer available"),
        platformSupportsMetalView: false
    ) == "SwiftUI preview — Metal view not available on this platform")

    let visibleFallback = TTFXGalleryPreviewRendererSelection.resolve(
        availability: .init(isAvailable: true, message: "Metal renderer available"),
        platformSupportsMetalView: true
    )
    #expect(visibleFallback == .swiftUIFrameView)
    #expect(TTFXGalleryPreviewRendererSelection.statusText(
        availability: .init(isAvailable: true, message: "Metal renderer available"),
        platformSupportsMetalView: true
    ) == "SwiftUI preview — Metal GPU view not connected yet")
}

@Test func productionAppSourceDoesNotUseSubprocessesFixturesOrFrameDumpFallbacks() throws {
    let sourceRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/ttfx-swift/SwiftUI/TTFXGalleryApp")
    let forbidden = [
        "Process(", "Process.", "swift run ttfx", "cargo", "fixture", "fixtures",
        "parity-dump", "frame-dump", "frameDump", "subprocess", "shell"
    ]

    let files = try FileManager.default.contentsOfDirectory(at: sourceRoot, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "swift" }
    for file in files {
        let text = try String(contentsOf: file, encoding: .utf8)
        for token in forbidden {
            #expect(!text.localizedCaseInsensitiveContains(token), "Forbidden token '\(token)' found in \(file.lastPathComponent)")
        }
    }
}

@Test func galleryXcodeAppDeclaresBundleIdentifierAndIOSDestinations() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let pbx = try String(
        contentsOf: root.appendingPathComponent("TTFXGalleryApp.xcodeproj/project.pbxproj"),
        encoding: .utf8
    )
    let infoPlist = try String(
        contentsOf: root.appendingPathComponent("Sources/ttfx-swift/SwiftUI/TTFXGalleryApp/Info.plist"),
        encoding: .utf8
    )

    #expect(pbx.contains("PRODUCT_BUNDLE_IDENTIFIER = codes.suscodigos.ttfx.gallery"))
    #expect(pbx.contains("Sources/ttfx-swift/SwiftUI/TTFXGalleryApp/Info.plist"))
    #expect(pbx.contains("GENERATE_INFOPLIST_FILE = YES"))
    #expect(pbx.contains("SDKROOT = auto"))
    #expect(pbx.contains("iphoneos"))
    #expect(pbx.contains("iphonesimulator"))
    #expect(pbx.contains("SUPPORTED_PLATFORMS = \"iphoneos iphonesimulator macosx\""))
    #expect(pbx.contains("INFOPLIST_KEY_UILaunchScreen_Generation = YES"))
    #expect(infoPlist.contains("codes.suscodigos.ttfx.gallery"))
    #expect(infoPlist.contains("CFBundleIdentifier"))
}
