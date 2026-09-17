#if os(macOS)
import SwiftUI
import AVKit
import AppKit
import TTFXComparisonKit
import TTFXEffects

struct ComparisonRootView: View {
    @State private var manifest: ComparisonManifest?
    @State private var directory: URL?
    @State private var selection: String? = "print"
    @State private var search = ""
    @State private var error: String?
    @SceneStorage("comparison.showSwiftCLI") private var showSwiftCLI = true
    @SceneStorage("comparison.showSwiftUI") private var showSwiftUI = true
    @State private var player = ComparisonPlayer()
    private var names: [String] { EffectRegistry.names.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        GeometryReader { geometry in
            splitView.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(minWidth: 880, minHeight: 480)
    }
    private var splitView: some View {
        NavigationSplitView {
            List(names, id: \.self, selection: $selection) { name in
                HStack {
                    Text(name)
                    Spacer()
                    if manifest?.effects.contains(where: { $0.name == name }) == true {
                        Image(systemName: "film").foregroundStyle(.secondary)
                    }
                }.tag(name)
            }
            .navigationTitle("Effects")
            .searchable(text: $search)
            .safeAreaInset(edge: .bottom) {
                Text("\(manifest?.effects.count ?? 0) / \(EffectRegistry.names.count) video sets")
                    .font(.caption).foregroundStyle(.secondary).padding()
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 210)
        } detail: {
            ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let manifest, let effect = player.effect {
                    HStack(alignment: .firstTextBaseline) {
                        Text(effect.name).font(.largeTitle.bold())
                        Spacer()
                        Text("\(manifest.columns) × \(manifest.rows) · \(manifest.fps) fps · seed \(manifest.seed)")
                            .foregroundStyle(.secondary)
                    }
                    ComparisonTrackControls(showSwiftCLI: $showSwiftCLI, showSwiftUI: $showSwiftUI)
                    HStack(alignment: .top, spacing: 18) {
                        videoPane("Rust terminal", video: effect.rust, avPlayer: player.rust, manifest: manifest)
                        videoPane("Swift Metal", video: effect.metal, avPlayer: player.metal, manifest: manifest)
                        if showSwiftCLI {
                            if let cli = effect.swiftCLI {
                                videoPane("Swift CLI", video: cli, avPlayer: player.swiftCLI, manifest: manifest)
                            } else {
                                missingRecordingPane(title: "Swift CLI", filename: "swift-cli.mp4")
                            }
                        }
                        if showSwiftUI {
                            if let swiftUI = effect.swiftUI {
                                videoPane("SwiftUI", video: swiftUI, avPlayer: player.swiftUI, manifest: manifest)
                            } else {
                                missingRecordingPane(title: "SwiftUI", filename: "swiftui.mp4")
                            }
                        }
                    }
                    HStack {
                        Button { player.seek(0) } label: { Image(systemName: "backward.end.fill") }.help("Restart all videos")
                        Button { player.isPlaying ? player.pause() : player.play() } label: {
                            Label(player.isPlaying ? "Pause" : "Play", systemImage: player.isPlaying ? "pause.fill" : "play.fill")
                        }.keyboardShortcut(.space, modifiers: [])
                        Slider(value: Binding(get: { player.position }, set: { player.seek($0) }), in: 0...max(0.001, player.duration))
                        Text(String(format: "%.2f / %.2f s", player.position, player.duration))
                            .monospacedDigit().frame(width: 130, alignment: .trailing)
                    }
                    Text("All present videos use the same timeline. Shorter videos hold their final frame; durations are never stretched.")
                        .font(.caption).foregroundStyle(.secondary)
                    Divider()
                    HStack(alignment: .top) {
                        Text(manifest.text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("Captured \(manifest.generatedAt)")
                            Text("Source \(manifest.revision)").lineLimit(1)
                        }.font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Spacer(minLength: 0)
                } else {
                    ContentUnavailableView("Choose a video library", systemImage: "film.stack", description: Text("Open the generated video-comparison folder to compare Rust, Swift CLI, SwiftUI, and Swift Metal effect by effect."))
                }
                if let message = error ?? player.error {
                    Text(message).foregroundStyle(.red).textSelection(.enabled)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle("TTFX Video Comparison")
        }
        .toolbar {
            Button("Open Library…", systemImage: "folder") { chooseLibrary() }.keyboardShortcut("o")
            Button("Reload", systemImage: "arrow.clockwise") { if let directory { load(directory) } }
        }
        .onChange(of: selection) { _, _ in selectEffect() }
        .onAppear { loadDefault() }
        .onDisappear { player.pause() }
    }
    private func videoPane(_ title: String, video: ComparisonVideo, avPlayer: AVPlayer, manifest: ComparisonManifest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(video.completed ? "Complete" : "Capture limit reached")
                    .font(.caption).foregroundStyle(video.completed ? Color.secondary : .orange)
            }
            ComparisonVideoSurface(player: avPlayer)
                .aspectRatio(Double(manifest.columns * 16) / Double(manifest.rows * 24), contentMode: .fit)
                .background(.black)
            Text(String(format: "%d frames · %.2f s", video.frames, video.duration(fps: manifest.fps)))
                .font(.caption.monospacedDigit())
            Text(video.provenance).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func missingRecordingPane(title: String, filename: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text("Missing recording").font(.caption).foregroundStyle(.orange)
            }
            ZStack {
                Color.black
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                    Text("No \(title) video in this library")
                        .font(.headline)
                    Text("Regenerate with ./tools/video-comparison/capture.sh to add \(filename) entries.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .aspectRatio(2, contentMode: .fit)
            Text("Older libraries may not include this optional track.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .topLeading)
    }
    private func chooseLibrary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }
    private func loadDefault() {
        guard directory == nil else { return }
        load(Self.defaultLibraryURL(
            arguments: ProcessInfo.processInfo.arguments,
            storedLibraryPath: UserDefaults.standard.string(forKey: "comparisonLibrary"),
            currentDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        ))
    }

    nonisolated static func defaultLibraryURL(arguments: [String], storedLibraryPath: String?, currentDirectory: URL, sourceFile: String = #filePath, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let index = arguments.firstIndex(of: "--library"), arguments.indices.contains(index + 1) {
            return URL(fileURLWithPath: arguments[index + 1]).standardizedFileURL
        }
        if let storedLibraryPath, !storedLibraryPath.isEmpty {
            return URL(fileURLWithPath: storedLibraryPath).standardizedFileURL
        }
        return projectRoot(currentDirectory: currentDirectory, sourceFile: sourceFile, environment: environment)
            .appendingPathComponent("artifacts/video-comparison")
            .standardizedFileURL
    }

    nonisolated static func projectRoot(currentDirectory: URL, sourceFile: String = #filePath, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = environment["TTFX_REPOSITORY_ROOT"], !override.isEmpty {
            return URL(fileURLWithPath: override).standardizedFileURL
        }
        if let root = firstAncestorContainingProjectFiles(from: currentDirectory) { return root }
        let sourceDirectory = URL(fileURLWithPath: sourceFile).deletingLastPathComponent()
        if let root = firstAncestorContainingProjectFiles(from: sourceDirectory) { return root }
        return currentDirectory.standardizedFileURL
    }

    nonisolated static func firstAncestorContainingProjectFiles(from url: URL) -> URL? {
        var candidate = url.standardizedFileURL
        let fileManager = FileManager.default
        for _ in 0..<64 {
            let hasCargo = fileManager.fileExists(atPath: candidate.appendingPathComponent("Cargo.toml").path)
            let hasPackage = fileManager.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path)
            if hasCargo && hasPackage { return candidate }
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path { return nil }
            candidate = parent
        }
        return nil
    }
    private func load(_ url: URL) {
        do {
            manifest = try ComparisonManifest.load(from: url); directory = url; error = nil
            UserDefaults.standard.set(url.path, forKey: "comparisonLibrary")
            if !manifest!.effects.contains(where: { $0.name == selection }) { selection = manifest!.effects.first?.name }
            selectEffect()
        } catch { self.error = error.localizedDescription }
    }
    private func selectEffect() {
        guard let manifest, let directory, let effect = manifest.effects.first(where: { $0.name == selection }) else {
            player.clear(); return
        }
        do { try player.load(effect, directory: directory, fps: manifest.fps); error = nil }
        catch { self.error = error.localizedDescription }
    }
}

private struct ComparisonVideoSurface: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView(); view.controlsStyle = .none; view.videoGravity = .resizeAspect; view.player = player
        return view
    }
    func updateNSView(_ view: AVPlayerView, context: Context) { view.player = player }
}
#endif
