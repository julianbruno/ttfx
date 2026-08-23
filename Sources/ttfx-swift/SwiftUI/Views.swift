import SwiftUI

public struct TTFXFrameView: View {
    public let snapshot: TTFXFrameSnapshot

    public init(snapshot: TTFXFrameSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(snapshot.visibleTextLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .accessibilityLabel(snapshot.visibleTextLines.joined(separator: "\n"))
    }
}

public struct TTFXGalleryView: View {
    public let demos: [TTFXGalleryDemo]
    @State private var selection: TTFXGalleryDemo.ID?

    public init(demos: [TTFXGalleryDemo] = TTFXGallery.demos) {
        self.demos = demos
        _selection = State(initialValue: demos.first?.id)
    }

    public var body: some View {
        List(demos, selection: $selection) { demo in
            VStack(alignment: .leading) {
                Text(demo.title)
                    .font(.headline)
                Text("seed \(demo.seed) • \(demo.canvas.columns)x\(demo.canvas.rows)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("TTFX Gallery")
    }
}

public struct TTFXRendererStatusView: View {
    public let availability: TTFXMetalRendererAvailability

    public init(availability: TTFXMetalRendererAvailability = .current) {
        self.availability = availability
    }

    public var body: some View {
        Label(availability.message, systemImage: availability.isAvailable ? "display" : "display.trianglebadge.exclamationmark")
            .foregroundStyle(availability.isAvailable ? .primary : .secondary)
    }
}

#if canImport(MetalKit) && (os(macOS) || os(iOS) || os(tvOS))
import MetalKit

#if os(macOS)
public typealias TTFXPlatformViewRepresentable = NSViewRepresentable
public typealias TTFXPlatformView = MTKView
#else
public typealias TTFXPlatformViewRepresentable = UIViewRepresentable
public typealias TTFXPlatformView = MTKView
#endif

public struct TTFXMetalFrameView: TTFXPlatformViewRepresentable {
    public let snapshot: TTFXFrameSnapshot
    public let cellSize: TTFXMetalCellSize
    public let renderer: TTFXMetalRenderer

    public init(snapshot: TTFXFrameSnapshot, cellSize: TTFXMetalCellSize = TTFXMetalCellSize(width: 10, height: 18), renderer: TTFXMetalRenderer = TTFXMetalRenderer()) {
        self.snapshot = snapshot
        self.cellSize = cellSize
        self.renderer = renderer
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer, cellSize: cellSize)
    }

    #if os(macOS)
    public func makeNSView(context: Context) -> MTKView {
        makeMetalView(context: context)
    }

    public func updateNSView(_ view: MTKView, context: Context) {
        updateMetalView(view, context: context)
    }
    #else
    public func makeUIView(context: Context) -> MTKView {
        makeMetalView(context: context)
    }

    public func updateUIView(_ view: MTKView, context: Context) {
        updateMetalView(view, context: context)
    }
    #endif

    private func makeMetalView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.delegate = context.coordinator
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        return view
    }

    private func updateMetalView(_ view: MTKView, context: Context) {
        context.coordinator.snapshot = snapshot
        context.coordinator.drawableSize = TTFXMetalDrawableSize(width: Float(view.drawableSize.width), height: Float(view.drawableSize.height))
        #if os(macOS)
        view.setNeedsDisplay(view.bounds)
        #else
        view.setNeedsDisplay()
        #endif
    }

    public final class Coordinator: NSObject, MTKViewDelegate {
        fileprivate var snapshot: TTFXFrameSnapshot?
        fileprivate var drawableSize = TTFXMetalDrawableSize(width: 0, height: 0)
        private let renderer: TTFXMetalRenderer
        private let cellSize: TTFXMetalCellSize

        init(renderer: TTFXMetalRenderer, cellSize: TTFXMetalCellSize) {
            self.renderer = renderer
            self.cellSize = cellSize
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            drawableSize = TTFXMetalDrawableSize(width: Float(size.width), height: Float(size.height))
        }

        public func draw(in view: MTKView) {
            guard let snapshot else { return }
            _ = renderer.prepare(snapshot: snapshot, cellSize: cellSize, drawableSize: drawableSize)
        }
    }
}
#endif
