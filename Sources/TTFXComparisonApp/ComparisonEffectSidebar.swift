#if os(macOS)
import Foundation
import SwiftUI
import TTFXComparisonKit

struct ComparisonEffectSelector {
    struct Row: Identifiable {
        let id: String
        let trackCount: Int
        let limited: Bool
        var title: String { id.replacingOccurrences(of: "_", with: " ").capitalized }
        var status: String {
            guard trackCount > 0 else { return "Not recorded" }
            return "\(limited ? "Capture limited" : "Recorded") · \(trackCount) tracks"
        }
        var symbol: String { trackCount == 0 ? "film" : limited ? "exclamationmark.circle" : "film.stack" }
    }
    let names: [String]
    let effects: [ComparisonEffect]

    func filtered(_ query: String) -> [Row] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return names.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }.map { name in
            let videos = effects.first { $0.name == name }?.videos ?? []
            return Row(id: name, trackCount: videos.count, limited: videos.contains { !$0.completed })
        }
    }

    func summary(query: String) -> String {
        let rows = filtered(query)
        return "\(rows.count) of \(names.count) effects · \(rows.filter { $0.trackCount > 0 }.count) recorded"
    }

    // A filtered-out selection remains the current playback, not a deselection.
    func acceptsSelection(_ selection: String?, query: String) -> Bool {
        filtered(query).contains { $0.id == selection }
    }
}

struct ComparisonEffectSidebar: View {
    let selector: ComparisonEffectSelector
    @Binding var selection: String?
    @State private var search = ""

    private var visibleSelection: Binding<String?> {
        Binding(get: { selection }, set: { candidate in
            if selector.acceptsSelection(candidate, query: search) { selection = candidate }
        })
    }

    var body: some View {
        List(selection: visibleSelection) {
            ForEach(selector.filtered(search)) { row in
                HStack(spacing: 10) {
                    Image(systemName: row.symbol)
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title).fontWeight(.medium).lineLimit(1)
                        Text(row.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .padding(.vertical, 3)
                .tag(row.id)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(row.title), \(row.status)")
                .accessibilityHint("Select to compare this effect's recordings")
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if selector.filtered(search).isEmpty {
                ContentUnavailableView {
                    Label("No matching effects", systemImage: "magnifyingglass")
                } description: {
                    Text("Try another effect name.")
                } actions: {
                    Button("Clear search") { search = "" }
                }
            }
        }
        .navigationTitle("Effects")
        .searchable(text: $search, prompt: "Search effects")
        .safeAreaInset(edge: .bottom) {
            Text(selector.summary(query: search))
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        }
        .navigationSplitViewColumnWidth(min: 210, ideal: 240)
    }
}
#endif
