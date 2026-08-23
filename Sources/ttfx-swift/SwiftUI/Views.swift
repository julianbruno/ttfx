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
