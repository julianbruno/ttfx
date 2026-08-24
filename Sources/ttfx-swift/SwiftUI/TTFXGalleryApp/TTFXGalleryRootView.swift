import SwiftUI
import TTFXSwiftUI

public struct TTFXGalleryRootView: View {
    public static let controlsMinimumWidth = 280.0
    public static let previewMinimumWidth = 200.0
    public static let previewMinimumHeight = 340.0

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
                        preview
                            .accessibilityLabel("TTFX preview")
                            .accessibilityValue("\(viewModel.previewSummary) rendering \(viewModel.sampleText)")
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
        .frame(minWidth: 860, minHeight: 560)
        .onReceive(Timer.publish(every: Double(viewModel.frameIntervalMilliseconds) / 1000.0, on: .main, in: .common).autoconnect()) { _ in
            viewModel.advanceFrame()
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch viewModel.previewRendererSelection {
        case .metalFrameView:
            #if canImport(MetalKit) && (os(macOS) || os(iOS) || os(tvOS))
            TTFXMetalFrameView(snapshot: viewModel.currentSnapshot)
            #else
            TTFXFrameView(snapshot: viewModel.currentSnapshot)
            #endif
        case .swiftUIFrameView:
            TTFXGalleryVisiblePreview(snapshot: viewModel.currentSnapshot, sampleText: viewModel.sampleText, fontSize: viewModel.previewFontSize)
        }
    }

    private var controls: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
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
                HStack {
                    TextField("Canvas width", value: Binding(get: {
                        viewModel.canvasWidth
                    }, set: { newValue in
                        viewModel.setCanvasWidth(newValue)
                    }), format: .number)
                    .accessibilityLabel("Canvas width")

                    Text("×")

                    TextField("Canvas height", value: Binding(get: {
                        viewModel.canvasHeight
                    }, set: { newValue in
                        viewModel.setCanvasHeight(newValue)
                    }), format: .number)
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
                TextField("Preview font size", value: Binding(get: {
                    viewModel.previewFontSize
                }, set: { newValue in
                    viewModel.setPreviewFontSize(newValue)
                }), format: .number)
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

