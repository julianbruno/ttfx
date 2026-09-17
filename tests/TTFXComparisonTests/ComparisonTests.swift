import Testing
import Foundation
@testable import TTFXComparisonKit

@Test func shorterVideoHoldsFinalFrameWithoutStretching() {
    #expect(ComparisonTimeline.time(5, frames: 50, fps: 25) == 1.96)
    #expect(ComparisonTimeline.time(1, frames: 50, fps: 25) == 1)
    #expect(ComparisonTimeline.time(-1, frames: 50, fps: 25) == 0)
}

@Test func manifestLoadsLegacyTwoTrackAndSwiftUIThreeTrackLibraries() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root.appendingPathComponent("print"), withIntermediateDirectories: true)
    for name in ["rust.mp4", "swiftui.mp4", "metal.mp4"] {
        try Data([0]).write(to: root.appendingPathComponent("print/\(name)"))
    }

    let legacy = """
    {"version":1,"generatedAt":"now","revision":"rev","text":"TTFX","seed":42,"columns":24,"rows":8,"fps":25,"maxFrames":10,"effects":[{"name":"print","rust":{"path":"print/rust.mp4","frames":2,"completed":true,"provenance":"rust"},"metal":{"path":"print/metal.mp4","frames":3,"completed":true,"provenance":"metal"}}]}
    """
    try Data(legacy.utf8).write(to: root.appendingPathComponent("manifest.json"))
    let legacyManifest = try ComparisonManifest.load(from: root)
    #expect(legacyManifest.effects[0].swiftUI == nil)
    #expect(legacyManifest.effects[0].swiftCLI == nil)
    #expect(legacyManifest.effects[0].maximumFrames == 3)

    let threeTrack = """
    {"version":1,"generatedAt":"now","revision":"rev","text":"TTFX","seed":42,"columns":24,"rows":8,"fps":25,"maxFrames":10,"effects":[{"name":"print","rust":{"path":"print/rust.mp4","frames":2,"completed":true,"provenance":"rust"},"swiftUI":{"path":"print/swiftui.mp4","frames":4,"completed":true,"provenance":"swiftui"},"metal":{"path":"print/metal.mp4","frames":3,"completed":true,"provenance":"metal"}}]}
    """
    try Data(threeTrack.utf8).write(to: root.appendingPathComponent("manifest.json"))
    let threeTrackManifest = try ComparisonManifest.load(from: root)
    #expect(threeTrackManifest.effects[0].swiftUI?.path == "print/swiftui.mp4")
    #expect(threeTrackManifest.effects[0].maximumFrames == 4)
}

@Test func libraryRejectsMissingManifestVideoAndPathEscape() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    #expect(throws: ComparisonError.self) { try ComparisonManifest.load(from: root) }
    let video = ComparisonVideo(path: "missing.mp4", frames: 10, completed: true, provenance: "test")
    #expect(throws: (any Error).self) { try ComparisonManifest.videoURL(video, directory: root) }
    var escaping = video; escaping.path = "../outside.mp4"
    #expect(throws: (any Error).self) { try ComparisonManifest.videoURL(escaping, directory: root) }
}

@testable import TTFXComparisonApp

@Test func comparisonAppDefaultLibraryFallsBackFromBuildDirectoryToSourceCheckout() throws {
    let fakeRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let fakeSource = fakeRoot.appendingPathComponent("Sources/TTFXComparisonApp/ComparisonRootView.swift")
    let buildDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Build/Products/Debug")
    try FileManager.default.createDirectory(at: fakeSource.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: buildDirectory, withIntermediateDirectories: true)
    try Data().write(to: fakeRoot.appendingPathComponent("Cargo.toml"))
    try Data().write(to: fakeRoot.appendingPathComponent("Package.swift"))
    defer { try? FileManager.default.removeItem(at: fakeRoot); try? FileManager.default.removeItem(at: buildDirectory.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()) }

    let library = ComparisonRootView.defaultLibraryURL(arguments: ["TTFXComparisonApp"], storedLibraryPath: nil, currentDirectory: buildDirectory, sourceFile: fakeSource.path, environment: [:])
    #expect(library.path == fakeRoot.appendingPathComponent("artifacts/video-comparison").path)
}

@Test func comparisonAppDefaultLibraryHonorsExplicitLibraryAndStoredSelection() {
    let explicit = "/tmp/explicit-comparison"
    let stored = "/tmp/stored-comparison"
    let current = URL(fileURLWithPath: "/tmp")
    #expect(ComparisonRootView.defaultLibraryURL(arguments: ["TTFXComparisonApp", "--library", explicit], storedLibraryPath: stored, currentDirectory: current, environment: [:]).path == explicit)
    #expect(ComparisonRootView.defaultLibraryURL(arguments: ["TTFXComparisonApp"], storedLibraryPath: stored, currentDirectory: current, environment: [:]).path == stored)
}

@testable import TTFXVideoCapture

@Test func videoCaptureProjectRootFallsBackFromDerivedDataToSourceCheckout() throws {
    let fakeRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let fakeSource = fakeRoot.appendingPathComponent("Sources/TTFXVideoCapture/TTFXVideoCapture.swift")
    let derivedData = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Build/Products/Debug")
    try FileManager.default.createDirectory(at: fakeSource.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: derivedData, withIntermediateDirectories: true)
    try Data().write(to: fakeRoot.appendingPathComponent("Cargo.toml"))
    try Data().write(to: fakeRoot.appendingPathComponent("Package.swift"))
    defer { try? FileManager.default.removeItem(at: fakeRoot); try? FileManager.default.removeItem(at: derivedData.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()) }

    #expect(TTFXVideoCapture.projectRoot(currentDirectory: derivedData, sourceFile: fakeSource.path, environment: [:]).path == fakeRoot.path)
}

@Test func videoCaptureProjectRootHonorsEnvironmentOverride() throws {
    let override = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    #expect(TTFXVideoCapture.projectRoot(currentDirectory: FileManager.default.temporaryDirectory, environment: ["TTFX_REPOSITORY_ROOT": override.path]).path == override.path)
}

@Test func videoCaptureGitMetadataSurvivesNonRepositoryDirectory() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let metadata = TTFXVideoCapture.gitMetadata(repository: root)
    #expect(metadata.revision == "unknown (not a git repository)")
    #expect(metadata.workingTreeStatus == "unavailable: not a git repository")
}

@Test func rustFrameDecoderPreservesUnicodeAndDetectsTruncation() throws {
    let frame = "\u{1b}[38;2;255;0;0mΩ\u{1b}[0m\n"
    var data = Data("\(frame.utf8.count)\n".utf8)
    data.append(Data(frame.utf8)); data.append(10)
    #expect(try TTFXVideoCapture.parseFrames(data) == [frame])
    #expect(throws: (any Error).self) { try TTFXVideoCapture.parseFrames(data.dropLast()) }
}

@Test func ansiReplayPreservesRGBBackgroundsAndTopToBottomRows() throws {
    let renderer = ANSIRasterizer(columns: 1, rows: 2)
    let pixels = try renderer.pixels("\u{1b}[48;2;255;0;0m \u{1b}[0m\n\u{1b}[48;2;0;0;255m \u{1b}[0m")
    #expect(Array(pixels[0..<4]) == [0, 0, 255, 255])
    let bottom = 30 * 16 * 4
    #expect(Array(pixels[bottom..<(bottom + 4)]) == [255, 0, 0, 255])
}

@Test func swiftCLITrackParticipatesInManifestValidationAndDuration() throws {
    let video = ComparisonVideo(path: "print/swift-cli.mp4", frames: 12, completed: false, provenance: "Swift CLI ANSI replay")
    let effect = ComparisonEffect(name: "print", rust: video, swiftCLI: video, metal: video)
    #expect(effect.videos.count == 3)
    #expect(effect.maximumFrames == 12)
    let roundTrip = try JSONDecoder().decode(ComparisonEffect.self, from: JSONEncoder().encode(effect))
    #expect(roundTrip.swiftCLI == video)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("print"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let manifest = ComparisonManifest(generatedAt: "now", revision: "test", text: "input", seed: 42, columns: 24, rows: 8, fps: 25, maxFrames: 12, effects: [effect])
    try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("manifest.json"))
    #expect(throws: ComparisonError.self) { try ComparisonManifest.load(from: root) }
    try Data([0]).write(to: root.appendingPathComponent(video.path))
    #expect(try ComparisonManifest.load(from: root).effects[0].swiftCLI == video)
    var invalid = manifest
    invalid.effects[0].swiftCLI?.frames = 0
    try JSONEncoder().encode(invalid).write(to: root.appendingPathComponent("manifest.json"))
    #expect(throws: ComparisonError.self) { try ComparisonManifest.load(from: root) }
}

@Test func ansiSubprocessUsesIdenticalArgumentsAndExactUnicodeInput() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let binary = root.appendingPathComponent("fake-cli")
    let script = "#!/bin/sh\nprintf '%s\\n' \"$@\" > '\(root.path)/args'\ncat > '\(root.path)/input'\nprintf '2\\nΩ\\n'\n"
    try Data(script.utf8).write(to: binary)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
    #expect(TTFXVideoCapture.dumpArguments(name: "print", fps: 30, seed: 123, cap: 8) == ["--parity-dump", "--virtual-clock", "--seed", "123", "--frame-rate", "30", "--max-frames", "8", "--ignore-terminal-dimensions", "--canvas-width", "24", "--canvas-height", "8", "--anchor-text", "sw", "--anchor-canvas", "sw", "print"])
    let output = root.appendingPathComponent("frames")
    let text = "Ω\ninput without final newline"
    try TTFXVideoCapture.ansiDump(binary: binary.path, name: "print", text: text, fps: 30, seed: 123, cap: 8, output: output, label: "Swift CLI")
    #expect(try Data(contentsOf: root.appendingPathComponent("input")) == Data(text.utf8))
    #expect(try String(contentsOf: root.appendingPathComponent("args"), encoding: .utf8).split(separator: "\n").map(String.init) == TTFXVideoCapture.dumpArguments(name: "print", fps: 30, seed: 123, cap: 8))
    #expect(try TTFXVideoCapture.parseFrames(Data(contentsOf: output)) == ["Ω"])
    try Data("#!/bin/sh\nexit 7\n".utf8).write(to: binary)
    #expect(throws: CaptureError.self) {
        try TTFXVideoCapture.ansiDump(binary: binary.path, name: "print", text: "", fps: 25, seed: 42, cap: 2, output: output, label: "Swift CLI")
    }
}

@Test func optionalTrackControlsExplainIndependentVisibility() {
    let cli = OptionalComparisonTrack.swiftCLI
    let ui = OptionalComparisonTrack.swiftUI
    #expect(cli.title == "Swift CLI")
    #expect(ui.title == "SwiftUI")
    #expect(cli.symbol == "terminal")
    #expect(ui.symbol == "macwindow")
    #expect(cli.shortcut == "1")
    #expect(ui.shortcut == "2")
    #expect(cli.visibilityLabel(isVisible: true) == "Visible")
    #expect(cli.visibilityLabel(isVisible: false) == "Hidden")
    #expect(cli.accessibilityLabel == "Swift CLI comparison pane")
    #expect(ui.accessibilityLabel == "SwiftUI comparison pane")
    #expect(cli.help(isVisible: true).contains("Hide"))
    #expect(ui.help(isVisible: false).contains("Show"))
    #expect(cli.detail.contains("ANSI"))
    #expect(ui.detail.contains("fallback"))
}
