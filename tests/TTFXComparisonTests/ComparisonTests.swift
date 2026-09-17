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
    #expect(legacyManifest.effects[0].maximumFrames == 3)

    let threeTrack = """
    {"version":1,"generatedAt":"now","revision":"rev","text":"TTFX","seed":42,"columns":24,"rows":8,"fps":25,"maxFrames":10,"effects":[{"name":"print","rust":{"path":"print/rust.mp4","frames":2,"completed":true,"provenance":"rust"},"swiftUI":{"path":"print/swiftui.mp4","frames":4,"completed":true,"provenance":"swiftui"},"metal":{"path":"print/metal.mp4","frames":3,"completed":true,"provenance":"metal"}}]}
    """
    try Data(threeTrack.utf8).write(to: root.appendingPathComponent("manifest.json"))
    let threeTrackManifest = try ComparisonManifest.load(from: root)
    #expect(threeTrackManifest.effects[0].swiftUI?.path == "print/swiftui.mp4")
    #expect(threeTrackManifest.effects[0].maximumFrames == 4)
}

@Test func libraryRejectsMissingVideoAndPathEscape() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let video = ComparisonVideo(path: "missing.mp4", frames: 10, completed: true, provenance: "test")
    #expect(throws: (any Error).self) { try ComparisonManifest.videoURL(video, directory: root) }
    var escaping = video; escaping.path = "../outside.mp4"
    #expect(throws: (any Error).self) { try ComparisonManifest.videoURL(escaping, directory: root) }
}

@testable import TTFXVideoCapture

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
