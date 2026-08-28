import Foundation
import TTFXCore
import TTFXEffects
import TTFXSwiftUI

public enum TTFXGalleryPreviewRendererSelection: Equatable, Sendable {
    case metalFrameView
    case swiftUIFrameView

    public static func resolve(
        availability: TTFXMetalRendererAvailability,
        platformSupportsMetalView: Bool
    ) -> TTFXGalleryPreviewRendererSelection {
        .swiftUIFrameView
    }

    public static func statusText(
        availability: TTFXMetalRendererAvailability,
        platformSupportsMetalView: Bool
    ) -> String {
        switch resolve(availability: availability, platformSupportsMetalView: platformSupportsMetalView) {
        case .metalFrameView:
            return availability.message
        case .swiftUIFrameView where availability.isAvailable && platformSupportsMetalView:
            return "Fallback renderer: drawable-backed Metal preview deferred"
        case .swiftUIFrameView where availability.isAvailable:
            return "Fallback renderer: platform Metal view unavailable"
        case .swiftUIFrameView:
            return "Fallback renderer: \(availability.message)"
        }
    }

    public var statusText: String {
        switch self {
        case .metalFrameView:
            return "Metal renderer available"
        case .swiftUIFrameView:
            return "Fallback renderer"
        }
    }
}

public struct TTFXGalleryViewModel {
    public static let minimumCanvasColumns = 4
    public static let maximumCanvasColumns = 120
    public static let minimumCanvasRows = 2
    public static let maximumCanvasRows = 40
    public static let minimumFramesPerSecond = 1
    public static let maximumFramesPerSecond = 120
    public static let minimumPreviewFontSize = 12.0
    public static let maximumPreviewFontSize = 144.0
    public static let defaultPreviewFontSize = 48.0
    public static let minimumLoopFrameBudget = 1

    public let effectNames: [String]
    public private(set) var selectedEffectName: String
    public var isPlaying = false
    public private(set) var isLooping = false
    public private(set) var frameIndex = 0
    public private(set) var currentSnapshot: TTFXFrameSnapshot
    public private(set) var rendererStatus: String
    public private(set) var framesPerSecond: Int
    public private(set) var previewFontSize: Double
    public private(set) var loopFrameBudget: Int
    public var previewRendererSelection: TTFXGalleryPreviewRendererSelection {
        TTFXGalleryPreviewRendererSelection.resolve(
            availability: metalAvailability,
            platformSupportsMetalView: Self.platformSupportsMetalFrameView
        )
    }
    public var frameIntervalMilliseconds: Int {
        Self.frameIntervalMilliseconds(for: framesPerSecond)
    }

    public var previewSummary: String {
        "\(selectedEffectName) seed \(seed) canvas \(canvasWidth)x\(canvasHeight)"
    }

    public var sampleText: String {
        didSet { reinitializeRenderer() }
    }

    public var seed: UInt64 {
        didSet { reinitializeRenderer() }
    }

    public private(set) var canvasWidth: Int
    public private(set) var canvasHeight: Int

    private var renderer: TTFXDeterministicRenderer
    private let metalAvailability: TTFXMetalRendererAvailability

    public init(
        sampleText: String = "Hello",
        seed: UInt64 = 42,
        canvasWidth: Int = 24,
        canvasHeight: Int = 8,
        metalAvailability: TTFXMetalRendererAvailability = .current,
        framesPerSecond: Int = 60,
        previewFontSize: Double = Self.defaultPreviewFontSize,
        loopFrameBudget: Int = 120
    ) throws {
        self.effectNames = EffectRegistry.names
        self.selectedEffectName = EffectRegistry.names.contains("print") ? "print" : EffectRegistry.names[0]
        self.sampleText = sampleText
        self.seed = seed
        self.canvasWidth = Self.clamp(canvasWidth, lower: Self.minimumCanvasColumns, upper: Self.maximumCanvasColumns)
        self.canvasHeight = Self.clamp(canvasHeight, lower: Self.minimumCanvasRows, upper: Self.maximumCanvasRows)
        self.metalAvailability = metalAvailability
        self.framesPerSecond = Self.clamp(framesPerSecond, lower: Self.minimumFramesPerSecond, upper: Self.maximumFramesPerSecond)
        self.previewFontSize = Self.clamp(previewFontSize, lower: Self.minimumPreviewFontSize, upper: Self.maximumPreviewFontSize)
        self.loopFrameBudget = max(loopFrameBudget, Self.minimumLoopFrameBudget)
        self.rendererStatus = Self.statusText(for: metalAvailability)
        self.renderer = Self.makeRenderer(effectName: selectedEffectName, sampleText: sampleText, seed: seed, canvasWidth: self.canvasWidth, canvasHeight: self.canvasHeight, frameIntervalMilliseconds: Self.frameIntervalMilliseconds(for: self.framesPerSecond))
        self.currentSnapshot = try renderer.tick(at: .milliseconds(0))
    }

    public mutating func selectEffect(_ name: String) {
        guard effectNames.contains(name), selectedEffectName != name else { return }
        selectedEffectName = name
        reinitializeRenderer()
    }

    public mutating func setCanvasWidth(_ width: Int) {
        canvasWidth = Self.clamp(width, lower: Self.minimumCanvasColumns, upper: Self.maximumCanvasColumns)
        reinitializeRenderer()
    }

    public mutating func setCanvasHeight(_ height: Int) {
        canvasHeight = Self.clamp(height, lower: Self.minimumCanvasRows, upper: Self.maximumCanvasRows)
        reinitializeRenderer()
    }

    public mutating func incrementCanvasWidth() {
        setCanvasWidth(canvasWidth + 1)
    }

    public mutating func decrementCanvasWidth() {
        setCanvasWidth(canvasWidth - 1)
    }

    public mutating func incrementCanvasHeight() {
        setCanvasHeight(canvasHeight + 1)
    }

    public mutating func decrementCanvasHeight() {
        setCanvasHeight(canvasHeight - 1)
    }

    public mutating func setFramesPerSecond(_ framesPerSecond: Int) {
        self.framesPerSecond = Self.clamp(framesPerSecond, lower: Self.minimumFramesPerSecond, upper: Self.maximumFramesPerSecond)
        reinitializeRenderer()
    }

    public mutating func setPreviewFontSize(_ previewFontSize: Double) {
        self.previewFontSize = Self.clamp(previewFontSize, lower: Self.minimumPreviewFontSize, upper: Self.maximumPreviewFontSize)
    }

    public mutating func incrementPreviewFontSize() {
        setPreviewFontSize(previewFontSize + 1)
    }

    public mutating func decrementPreviewFontSize() {
        setPreviewFontSize(previewFontSize - 1)
    }

    public mutating func setLooping(_ isLooping: Bool) {
        self.isLooping = isLooping
    }

    public mutating func play() { isPlaying = true }
    public mutating func pause() { isPlaying = false }

    public mutating func togglePlayback() {
        isPlaying.toggle()
    }

    public mutating func advanceFrame() {
        guard isPlaying else { return }
        let nextFrameIndex = frameIndex + 1
        if nextFrameIndex > loopFrameBudget {
            if isLooping {
                reinitializeRenderer()
            } else {
                isPlaying = false
            }
            return
        }
        frameIndex = nextFrameIndex
        currentSnapshot = (try? renderer.tick(at: .milliseconds(frameIndex * frameIntervalMilliseconds))) ?? currentSnapshot
    }

    public mutating func reset() {
        reinitializeRenderer()
    }

    private mutating func reinitializeRenderer() {
        frameIndex = 0
        rendererStatus = Self.statusText(for: metalAvailability)
        renderer = Self.makeRenderer(effectName: selectedEffectName, sampleText: sampleText, seed: seed, canvasWidth: canvasWidth, canvasHeight: canvasHeight, frameIntervalMilliseconds: frameIntervalMilliseconds)
        currentSnapshot = (try? renderer.tick(at: .milliseconds(0))) ?? currentSnapshot
    }

    private static func makeRenderer(effectName: String, sampleText: String, seed: UInt64, canvasWidth: Int, canvasHeight: Int, frameIntervalMilliseconds: Int) -> TTFXDeterministicRenderer {
        let box = EffectFrameBox(effectName: effectName, sampleText: sampleText, seed: seed, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        return TTFXDeterministicRenderer(frameInterval: .milliseconds(frameIntervalMilliseconds)) {
            try box.nextFrame()
        }
    }

    private static func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
        min(max(value, lower), upper)
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private static func frameIntervalMilliseconds(for framesPerSecond: Int) -> Int {
        framesPerSecond == 60 ? 16 : Int((1000.0 / Double(framesPerSecond)).rounded(.up))
    }

    private static var platformSupportsMetalFrameView: Bool {
        #if canImport(MetalKit) && (os(macOS) || os(iOS) || os(tvOS))
        true
        #else
        false
        #endif
    }

    private static func statusText(for availability: TTFXMetalRendererAvailability) -> String {
        TTFXGalleryPreviewRendererSelection.statusText(
            availability: availability,
            platformSupportsMetalView: platformSupportsMetalFrameView
        )
    }
}

private final class EffectFrameBox {
    private var effect: any Effect
    private var frame: Frame

    init(effectName: String, sampleText: String, seed: UInt64, canvasWidth: Int, canvasHeight: Int) {
        let canvas = (try? Canvas(columns: canvasWidth, rows: canvasHeight)) ?? (try! Canvas(columns: 24, rows: 8))
        let input = canvas.ingest(sampleText)
        let configuration = EffectConfiguration(text: sampleText, seed: seed)
        self.effect = EffectRegistry.makeEffect(named: effectName, configuration: configuration, canvas: canvas, input: input, seed: seed)
            ?? EffectRegistry.makeEffect(named: EffectRegistry.names[0], configuration: configuration, canvas: canvas, input: input, seed: seed)!
        self.frame = (try? Frame(columns: canvas.columns, rows: canvas.rows)) ?? (try! Frame(columns: 24, rows: 8))
    }

    func nextFrame() throws -> Frame {
        _ = effect.tick(into: &frame)
        return frame
    }
}
