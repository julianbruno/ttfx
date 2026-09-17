import Testing
import Foundation
import AVFoundation
@testable import TTFXComparisonKit
@testable import TTFXComparisonApp

@Test(.enabled(if: generatedComparisonLibraryExists, "Generated video library is unavailable; run capture.sh first."))
@MainActor func pairedPlayersAdvanceAndPauseOnGeneratedVideos() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = root.appendingPathComponent("artifacts/video-comparison")
    let exists = FileManager.default.fileExists(atPath: directory.appendingPathComponent("manifest.json").path)
    try #require(exists, "Generated library missing; runtime integration unavailable.")
    let manifest = try ComparisonManifest.load(from: directory)
    let effect = try #require(manifest.effects.first(where: { $0.name == "print" }))
    let cli = try #require(effect.swiftCLI, "Regenerate library with Swift CLI track before integration check.")
    let player = ComparisonPlayer()
    try player.load(effect, directory: directory, fps: manifest.fps)
    for _ in 0..<100 {
        if [player.rust, player.swiftUI, player.swiftCLI, player.metal].allSatisfy({ $0.currentItem?.status == .readyToPlay }) { break }
        try await Task.sleep(for: .milliseconds(50))
    }
    player.play()
    #expect(player.isPlaying)
    try await Task.sleep(for: .milliseconds(800))
    #expect(player.position > 0.4)
    #expect(player.rust.currentTime().seconds > 0.4)
    #expect(player.metal.currentTime().seconds > 0.4)
    #expect(player.swiftCLI.currentTime().seconds > 0.4)
    #expect(abs(player.rust.currentTime().seconds - player.swiftCLI.currentTime().seconds) < 0.12)
    #expect(abs(player.rust.currentTime().seconds - player.metal.currentTime().seconds) < 0.12)
    player.pause()
    let position = player.position
    try await Task.sleep(for: .milliseconds(150))
    #expect(player.position == position)
    let cliTime = player.swiftCLI.currentTime().seconds
    try await Task.sleep(for: .milliseconds(150))
    #expect(abs(player.swiftCLI.currentTime().seconds - cliTime) < 0.04)
    player.seek(1)
    try await Task.sleep(for: .milliseconds(250))
    #expect(abs(player.swiftCLI.currentTime().seconds - ComparisonTimeline.time(1, frames: cli.frames, fps: manifest.fps)) < 0.04)
    player.seek(player.duration)
    try await Task.sleep(for: .milliseconds(250))
    #expect(abs(player.swiftCLI.currentTime().seconds - ComparisonTimeline.time(player.duration, frames: cli.frames, fps: manifest.fps)) < 0.04)
    player.clear()
    #expect(player.swiftCLI.currentItem == nil)
}

@Test @MainActor func swiftCLIPlayerLoadsPausesAndClearsLegacyTrack() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data([0]).write(to: root.appendingPathComponent("test.mp4"))
    let video = ComparisonVideo(path: "test.mp4", frames: 100, completed: true, provenance: "test")
    let player = ComparisonPlayer()
    try player.load(.init(name: "print", rust: video, swiftCLI: video, metal: video), directory: root, fps: 25)
    #expect(player.swiftCLI.currentItem != nil)
    #expect(!player.swiftCLI.automaticallyWaitsToMinimizeStalling)
    #expect(player.swiftCLI.isMuted)
    #expect(player.swiftCLI.actionAtItemEnd == .pause)
    player.play()
    #expect(!player.isPlaying)
    #expect(player.error != nil)
    player.seek(2)
    #expect(player.position == 2)
    #expect(player.swiftCLI.rate == 0)
    player.pause()
    #expect(player.swiftCLI.rate == 0)
    try player.load(.init(name: "legacy", rust: video, metal: video), directory: root, fps: 25)
    #expect(player.swiftCLI.currentItem == nil)
    player.clear()
    #expect(player.rust.currentItem == nil)
    #expect(player.swiftUI.currentItem == nil)
    #expect(player.swiftCLI.currentItem == nil)
    #expect(player.metal.currentItem == nil)
}

private var generatedComparisonLibraryExists: Bool {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/video-comparison/manifest.json").path)
}
