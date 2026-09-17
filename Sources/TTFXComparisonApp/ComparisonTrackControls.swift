#if os(macOS)
import SwiftUI

/// Presentation metadata shared by the native controls and accessibility output.
enum OptionalComparisonTrack {
    case swiftCLI
    case swiftUI

    var title: String { self == .swiftCLI ? "Swift CLI" : "SwiftUI" }
    var symbol: String { self == .swiftCLI ? "terminal" : "macwindow" }
    var shortcut: String { self == .swiftCLI ? "1" : "2" }
    var detail: String {
        self == .swiftCLI ? "Pure-Swift terminal ANSI replay" : "Native SwiftUI fallback renderer"
    }
    var accessibilityLabel: String { "\(title) comparison pane" }
    func visibilityLabel(isVisible: Bool) -> String { isVisible ? "Visible" : "Hidden" }
    func help(isVisible: Bool) -> String {
        "\(isVisible ? "Hide" : "Show") \(title). \(detail). Shortcut: ⌘\(shortcut)."
    }
}

struct ComparisonTrackControls: View {
    @Binding var showSwiftCLI: Bool
    @Binding var showSwiftUI: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    heading
                    Spacer(minLength: 8)
                    controls
                }
                VStack(alignment: .leading, spacing: 10) {
                    heading
                    controls
                }
            }
            Text("Rust terminal and Swift Metal stay visible. Add either or both optional panes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Optional comparison panes")
    }

    private var heading: some View {
        Label("Optional panes", systemImage: "rectangle.split.3x1")
            .font(.subheadline.weight(.semibold))
            .fixedSize()
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                trackToggle(.swiftCLI, isOn: $showSwiftCLI)
                trackToggle(.swiftUI, isOn: $showSwiftUI)
            }
            VStack(alignment: .leading, spacing: 8) {
                trackToggle(.swiftCLI, isOn: $showSwiftCLI)
                trackToggle(.swiftUI, isOn: $showSwiftUI)
            }
        }
    }

    private func trackToggle(_ track: OptionalComparisonTrack, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 8) {
                Label(track.title, systemImage: track.symbol)
                    .fontWeight(.medium)
                Label(track.visibilityLabel(isVisible: isOn.wrappedValue),
                      systemImage: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
            }
            .padding(.vertical, 3)
        }
        .toggleStyle(.button)
        .controlSize(.regular)
        .fixedSize()
        .keyboardShortcut(KeyEquivalent(Character(track.shortcut)), modifiers: .command)
        .help(track.help(isVisible: isOn.wrappedValue))
        .accessibilityLabel(track.accessibilityLabel)
        .accessibilityValue(track.visibilityLabel(isVisible: isOn.wrappedValue))
        .accessibilityHint(track.detail)
    }
}
#endif
