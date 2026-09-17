import SwiftUI

public struct TTFXFrameView: View {
    public let snapshot: TTFXFrameSnapshot
    public let fontSize: CGFloat
    public let cellSize: CGSize

    public init(snapshot: TTFXFrameSnapshot, fontSize: CGFloat = 20, cellSize: CGSize = CGSize(width: 16, height: 24)) {
        self.snapshot = snapshot
        self.fontSize = fontSize
        self.cellSize = cellSize
    }

    public var body: some View {
        Canvas { context, _ in
            for cell in snapshot.cells {
                let rect = CGRect(
                    x: CGFloat(cell.column - 1) * cellSize.width,
                    y: CGFloat(snapshot.rows - cell.row) * cellSize.height,
                    width: cellSize.width,
                    height: cellSize.height
                )
                context.fill(Path(rect), with: .color(Self.color(cell.background)))
                guard cell.codepoint != 32 else { continue }
                let text = context.resolve(
                    Text(cell.glyph)
                        .font(.custom("Menlo", fixedSize: fontSize))
                        .foregroundColor(Self.color(cell.foreground))
                )
                let size = text.measure(in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
                // Rust's terminal replay places Menlo at x + 1 and baseline y + 5
                // in bottom-origin coordinates. Scale the same inset for previews.
                let scale = fontSize / 20
                let origin = CGPoint(
                    x: rect.minX + scale,
                    y: rect.maxY - 5 * scale - text.firstBaseline(in: size)
                )
                var cellContext = context
                cellContext.clip(to: Path(rect))
                cellContext.draw(text, at: origin, anchor: .topLeading)
            }
        }
        .frame(width: CGFloat(snapshot.columns) * cellSize.width, height: CGFloat(snapshot.rows) * cellSize.height)
        .accessibilityLabel(snapshot.visibleTextLines.joined(separator: "\n"))
    }

    private static func color(_ rgb: UInt32) -> Color {
        Color(.sRGB, red: Double((rgb >> 16) & 255) / 255,
              green: Double((rgb >> 8) & 255) / 255,
              blue: Double(rgb & 255) / 255, opacity: 1)
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
    public let renderer: TTFXMetalRenderer?

    public init(snapshot: TTFXFrameSnapshot, cellSize: TTFXMetalCellSize = TTFXMetalCellSize(width: 10, height: 18), renderer: TTFXMetalRenderer? = nil) {
        self.snapshot = snapshot
        self.cellSize = cellSize
        self.renderer = renderer
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer ?? TTFXMetalRenderer(), cellSize: cellSize)
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
        let view = MTKView(frame: .zero, device: context.coordinator.renderer.device)
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.delegate = context.coordinator
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        return view
    }

    private func updateMetalView(_ view: MTKView, context: Context) {
        context.coordinator.snapshot = snapshot
        context.coordinator.cellSize = cellSize
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
        fileprivate let renderer: TTFXMetalRenderer
        fileprivate var cellSize: TTFXMetalCellSize

        init(renderer: TTFXMetalRenderer, cellSize: TTFXMetalCellSize) {
            self.renderer = renderer
            self.cellSize = cellSize
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            drawableSize = TTFXMetalDrawableSize(width: Float(size.width), height: Float(size.height))
        }

        public func draw(in view: MTKView) {
            guard let snapshot else { return }
            _ = renderer.draw(snapshot: snapshot, cellSize: cellSize, view: view)
        }
    }
}
#endif
