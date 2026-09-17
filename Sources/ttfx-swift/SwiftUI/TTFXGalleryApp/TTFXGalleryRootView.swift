import SwiftUI
import TTFXSwiftUI

public struct TTFXGalleryRootView: View {
    nonisolated public static let controlsMinimumWidth = 300.0
    nonisolated public static let previewMinimumWidth = 640.0
    nonisolated public static let previewMinimumHeight = 480.0

    nonisolated public static func visiblePreviewLines(snapshot: TTFXFrameSnapshot, sampleText: String) -> [String] {
        visiblePreviewLines(visibleTextLines: snapshot.visibleTextLines, sampleText: sampleText)
    }

    nonisolated public static func visiblePreviewLines(visibleTextLines: [String], sampleText: String) -> [String] {
        let renderedText = visibleTextLines.joined(separator: "\n")
        if renderedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lines = sampleText.split(whereSeparator: \.isNewline).map(String.init)
            return lines.isEmpty ? [""] : lines
        }
        return visibleTextLines
    }

    nonisolated public static func visiblePreviewMinimumSize(canvasWidth: Int, canvasHeight: Int, fontSize: Double) -> CGSize {
        let width = max(previewMinimumWidth, Double(canvasWidth) * fontSize * 0.68 + 32)
        let height = max(previewMinimumHeight, Double(canvasHeight) * fontSize * 1.2 + 32)
        return CGSize(width: width, height: height)
    }

    public static let accessibilityLabels = [
        "TTFX Gallery App",
        "Effect picker",
        "Sample text",
        "Seed",
        "Canvas width",
        "Canvas height",
        "Frames per second",
        "Preview font size",
        "Loop playback",
        "Use Metal",
        "Play or pause preview",
        "Reset preview",
        "TTFX preview",
        "Renderer status"
    ]

    @State private var viewModel: TTFXGalleryViewModel

    public init(viewModel: TTFXGalleryViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? (try! TTFXGalleryViewModel()))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TTFX Gallery App")
                .font(.largeTitle.bold())
                .accessibilityLabel("TTFX Gallery App")

            HStack(alignment: .top, spacing: 16) {
                GroupBox("Controls") {
                    controls
                        .frame(minWidth: Self.controlsMinimumWidth, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: 12) {
                    GroupBox("Preview") {
                        ScrollView([.horizontal, .vertical]) {
                            preview
                                .accessibilityLabel("TTFX preview")
                                .accessibilityValue("\(viewModel.previewSummary) rendering \(viewModel.sampleText)")
                                .frame(
                                    minWidth: visiblePreviewMinimumSize.width,
                                    minHeight: visiblePreviewMinimumSize.height,
                                    alignment: .topLeading
                                )
                                .padding(8)
                        }
                        .frame(minWidth: Self.previewMinimumWidth, maxWidth: .infinity, minHeight: Self.previewMinimumHeight, alignment: .topLeading)
                    }

                    Text(viewModel.rendererStatus)
                        .font(.caption)
                        .accessibilityLabel("Renderer status")
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding()
        .frame(minWidth: 1120, minHeight: 760)
        .onReceive(Timer.publish(every: Double(viewModel.frameIntervalMilliseconds) / 1000.0, on: .main, in: .common).autoconnect()) { _ in
            viewModel.advanceFrame()
        }
    }

    private var visiblePreviewMinimumSize: CGSize {
        Self.visiblePreviewMinimumSize(
            canvasWidth: viewModel.canvasWidth,
            canvasHeight: viewModel.canvasHeight,
            fontSize: viewModel.previewFontSize
        )
    }

    @ViewBuilder
    private var preview: some View {
        switch viewModel.previewRendererSelection {
        case .metalFrameView:
            #if canImport(MetalKit) && (os(macOS) || os(iOS) || os(tvOS))
            TTFXMetalFrameView(snapshot: viewModel.currentSnapshot, cellSize: .init(width: Float(viewModel.previewFontSize * 0.68), height: Float(viewModel.previewFontSize * 1.2)))
                .frame(width: visiblePreviewMinimumSize.width, height: visiblePreviewMinimumSize.height)
            #else
            TTFXFrameView(snapshot: viewModel.currentSnapshot)
            #endif
        case .swiftUIFrameView:
            TTFXGalleryVisiblePreview(snapshot: viewModel.currentSnapshot, sampleText: viewModel.sampleText, fontSize: viewModel.previewFontSize)
        }
    }

    private var controls: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            Toggle("Use Metal", isOn: $viewModel.useMetal)
                .accessibilityLabel("Use Metal")
            GridRow {
                Text("Effect")
                Picker("Effect picker", selection: Binding(get: {
                    viewModel.selectedEffectName
                }, set: { newValue in
                    viewModel.selectEffect(newValue)
                })) {
                    ForEach(viewModel.effectNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .accessibilityLabel("Effect picker")
            }

            GridRow {
                Text("Text")
                TextField("Sample text", text: Binding(get: {
                    viewModel.sampleText
                }, set: { newValue in
                    viewModel.sampleText = newValue
                }), axis: .vertical)
                .accessibilityLabel("Sample text")
            }

            GridRow {
                Text("Seed")
                TextField("Seed", value: Binding(get: {
                    viewModel.seed
                }, set: { newValue in
                    viewModel.seed = newValue
                }), format: .number)
                .accessibilityLabel("Seed")
            }

            GridRow {
                Text("Canvas")
                VStack(alignment: .leading, spacing: 8) {
                    Stepper("Width: \(viewModel.canvasWidth) columns", value: Binding(get: {
                        viewModel.canvasWidth
                    }, set: { newValue in
                        viewModel.setCanvasWidth(newValue)
                    }), in: TTFXGalleryViewModel.minimumCanvasColumns...TTFXGalleryViewModel.maximumCanvasColumns)
                    .accessibilityLabel("Canvas width")

                    Stepper("Height: \(viewModel.canvasHeight) rows", value: Binding(get: {
                        viewModel.canvasHeight
                    }, set: { newValue in
                        viewModel.setCanvasHeight(newValue)
                    }), in: TTFXGalleryViewModel.minimumCanvasRows...TTFXGalleryViewModel.maximumCanvasRows)
                    .accessibilityLabel("Canvas height")
                }
            }

            GridRow {
                Text("Frame rate")
                TextField("Frames per second", value: Binding(get: {
                    viewModel.framesPerSecond
                }, set: { newValue in
                    viewModel.setFramesPerSecond(newValue)
                }), format: .number)
                .accessibilityLabel("Frames per second")
            }

            GridRow {
                Text("Font size")
                Stepper("\(Int(viewModel.previewFontSize)) pt", value: Binding(get: {
                    Int(viewModel.previewFontSize)
                }, set: { newValue in
                    viewModel.setPreviewFontSize(Double(newValue))
                }), in: Int(TTFXGalleryViewModel.minimumPreviewFontSize)...Int(TTFXGalleryViewModel.maximumPreviewFontSize))
                .accessibilityLabel("Preview font size")
            }

            GridRow {
                Text("Playback")
                HStack {
                    Toggle("Loop", isOn: Binding(get: {
                        viewModel.isLooping
                    }, set: { newValue in
                        viewModel.setLooping(newValue)
                    }))
                    .accessibilityLabel("Loop playback")

                    Button(viewModel.isPlaying ? "Pause" : "Play") {
                        viewModel.togglePlayback()
                    }
                    .accessibilityLabel("Play or pause preview")

                    Button("Reset") {
                        viewModel.reset()
                    }
                    .accessibilityLabel("Reset preview")

                    Button("Advance frame") {
                        viewModel.advanceFrame()
                    }
                    .accessibilityLabel("Advance preview frame")
                }
            }
        }
    }
}


private struct TTFXGalleryVisiblePreview: View {
    let snapshot: TTFXFrameSnapshot
    let sampleText: String
    let fontSize: Double

    private var visibleLines: [String] {
        TTFXGalleryRootView.visiblePreviewLines(snapshot: snapshot, sampleText: sampleText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visibleLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: fontSize, weight: .regular, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .accessibilityLabel(visibleLines.joined(separator: "\n"))
    }
}

