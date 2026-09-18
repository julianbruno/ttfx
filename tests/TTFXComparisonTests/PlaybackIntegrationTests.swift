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
    player.isLooping = true
    for _ in 0..<100 {
        if player.swiftCLI.currentItem?.status == .failed { break }
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(player.swiftCLI.currentItem?.status == .failed)
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

@Test @MainActor func playbackSpeedRejectsInvalidRatesAndScalesMediaClock() {
    let player = ComparisonPlayer()
    #expect(player.playbackSpeed == 1)
    for speed in [0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3] {
        player.setPlaybackSpeed(speed)
        #expect(player.playbackSpeed == speed)
        #expect(!player.isPlaying)
    }
    for speed in [0, 0.49, 3.01, Double.nan, Double.infinity] {
        player.setPlaybackSpeed(speed)
        #expect(player.playbackSpeed == 3)
    }
    #expect(ComparisonPlayer.mediaPosition(start: 2, elapsed: 4, speed: 0.5, duration: 20) == 4)
    #expect(ComparisonPlayer.mediaPosition(start: 2, elapsed: 4, speed: 3, duration: 20) == 14)
    #expect(ComparisonPlayer.mediaPosition(start: 2, elapsed: -1, speed: 3, duration: 20) == 2)
    #expect(ComparisonPlayer.mediaPosition(start: 2, elapsed: 10, speed: 3, duration: 20) == 20)
}

@Test(.enabled(if: generatedComparisonLibraryExists, "Generated video library is unavailable."))
@MainActor func playbackSpeedKeepsFourTracksSynchronizedAcrossLiveChange() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = root.appendingPathComponent("artifacts/video-comparison")
    let manifest = try ComparisonManifest.load(from: directory)
    let effect = try #require(manifest.effects.first(where: { $0.name == "rings" }))
    let player = ComparisonPlayer()
    try player.load(effect, directory: directory, fps: manifest.fps)
    let tracks = [player.rust, player.swiftCLI, player.swiftUI, player.metal]
    for _ in 0..<100 {
        if tracks.allSatisfy({ $0.currentItem?.status == .readyToPlay }) { break }
        try await Task.sleep(for: .milliseconds(50))
    }
    player.setPlaybackSpeed(0.5)
    #expect(tracks.allSatisfy { $0.rate == 0 })
    player.play()
    try await Task.sleep(for: .milliseconds(700))
    #expect(player.position > 0.2 && player.position < 0.5)
    #expect(tracks.allSatisfy { $0.rate == 0.5 })
    let before = player.position
    player.setPlaybackSpeed(3)
    #expect(player.position >= before && player.position - before < 0.1)
    let rebased = player.position
    player.setPlaybackSpeed(3)
    #expect(player.position == rebased)
    try await Task.sleep(for: .milliseconds(600))
    #expect(player.position - rebased > 1.2 && player.position - rebased < 1.9)
    #expect(tracks.allSatisfy { $0.rate == 3 })
    for track in tracks {
        #expect(abs(track.currentTime().seconds - player.position) < 0.15)
    }
    player.pause()
    let paused = player.position
    player.setPlaybackSpeed(0.5)
    try await Task.sleep(for: .milliseconds(150))
    #expect(player.position == paused)
    #expect(!player.isPlaying)
    #expect(tracks.allSatisfy { $0.rate == 0 })
    player.seek(player.duration - 0.4)
    try await Task.sleep(for: .milliseconds(250))
    player.setPlaybackSpeed(3)
    player.play()
    try await Task.sleep(for: .milliseconds(400))
    #expect(player.position == player.duration)
    #expect(!player.isPlaying)
    player.clear()
}

@Test @MainActor func slowingAtEndpointKeepsFinalPositionBeforeTimerUpdate() {
    // Simulate the clock reaching the endpoint before the next timer tick.
    let player = ComparisonPlayer(uptime: { 1 })
    let video = ComparisonVideo(path: "unused.mp4", frames: 75, completed: true, provenance: "test")
    player.effect = .init(name: "endpoint", rust: video, swiftUI: video, swiftCLI: video, metal: video)
    player.setPlaybackSpeed(3)
    player.isPlaying = true
    player.setPlaybackSpeed(0.5)
    #expect(player.position == 3)
    #expect(player.playbackSpeed == 0.5)
    #expect(!player.isPlaying)
    #expect([player.rust, player.swiftCLI, player.swiftUI, player.metal].allSatisfy { $0.rate == 0 })
}

@Test @MainActor func loopDefaultsOffAndNeverStartsPausedPlayback() {
    let player = ComparisonPlayer()
    #expect(!player.isLooping)
    player.isLooping = true
    player.setPlaybackSpeed(3)
    player.seek(0)
    #expect(player.isLooping)
    #expect(!player.isPlaying)
    #expect(player.playbackSpeed == 3)
}

@Test(.enabled(if: generatedComparisonLibraryExists, "Generated video library is unavailable."))
@MainActor func loopRepeatsFourTracksTogetherAndDisablesAtNextEndpoint() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = root.appendingPathComponent("artifacts/video-comparison")
    let manifest = try ComparisonManifest.load(from: directory)
    let effect = try #require(manifest.effects.first(where: { $0.name == "print" }))
    let player = ComparisonPlayer()
    try player.load(effect, directory: directory, fps: manifest.fps)
    let tracks = [player.rust, player.swiftCLI, player.swiftUI, player.metal]
    for _ in 0..<100 {
        if tracks.allSatisfy({ $0.currentItem?.status == .readyToPlay }) { break }
        try await Task.sleep(for: .milliseconds(50))
    }
    player.isLooping = true
    player.setPlaybackSpeed(3)
    player.play()
    var boundaries = 0
    var previous = player.position
    for _ in 0..<400 {
        try await Task.sleep(for: .milliseconds(25))
        if player.position < previous { boundaries += 1 }
        previous = player.position
        if boundaries >= 2 && player.position > 0.4 { break }
    }
    #expect(boundaries >= 2)
    #expect(player.isPlaying)
    #expect(player.playbackSpeed == 3)
    #expect(tracks.allSatisfy { $0.rate == 3 })
    for track in tracks { #expect(abs(track.currentTime().seconds - player.position) < 0.15) }
    player.isLooping = false
    #expect(player.isPlaying)
    try await Task.sleep(for: .seconds(player.duration / 3 + 0.3))
    #expect(!player.isPlaying)
    #expect(player.position == player.duration)
    #expect(tracks.allSatisfy { $0.rate == 0 })
    player.isLooping = true
    player.play()
    try await Task.sleep(for: .milliseconds(300))
    player.pause()
    let paused = player.position
    try await Task.sleep(for: .milliseconds(200))
    #expect(player.position == paused)
    player.seek(player.duration)
    try await Task.sleep(for: .milliseconds(200))
    #expect(!player.isPlaying)
    #expect(player.position == player.duration)
    player.clear()
}

@Test(.enabled(if: generatedComparisonLibraryExists, "Generated video library is unavailable."))
@MainActor func loopHoldsShorterLegacyTrackAndHandlesEndpointSpeedChange() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = root.appendingPathComponent("artifacts/video-comparison")
    let manifest = try ComparisonManifest.load(from: directory)
    let printEffect = try #require(manifest.effects.first(where: { $0.name == "print" }))
    // Reuse actual media with a longer shared timeline: the Rust track must hold, not loop independently.
    let longer = ComparisonVideo(path: printEffect.metal.path, frames: 100, completed: true, provenance: "test")
    let player = ComparisonPlayer()
    try player.load(.init(name: "legacy", rust: printEffect.rust, metal: longer), directory: directory, fps: manifest.fps)
    for _ in 0..<100 {
        if [player.rust, player.metal].allSatisfy({ $0.currentItem?.status == .readyToPlay }) { break }
        try await Task.sleep(for: .milliseconds(50))
    }
    player.isLooping = true
    player.setPlaybackSpeed(3)
    player.play()
    try await Task.sleep(for: .milliseconds(950))
    #expect(player.position > printEffect.rust.duration(fps: manifest.fps))
    #expect(player.rust.currentTime().seconds > 2)
    #expect(player.rust.rate == 0)
    #expect(player.isPlaying)
    try await Task.sleep(for: .milliseconds(600))
    #expect(player.position < 1)
    #expect(player.rust.currentTime().seconds < 1)
    #expect(player.swiftCLI.currentItem == nil)
    #expect(player.swiftUI.currentItem == nil)
    player.clear()

    var now = 0.0
    let endpoint = ComparisonPlayer(uptime: { now })
    try endpoint.load(printEffect, directory: directory, fps: manifest.fps)
    for _ in 0..<100 {
        if [endpoint.rust, endpoint.swiftCLI, endpoint.swiftUI, endpoint.metal].allSatisfy({ $0.currentItem?.status == .readyToPlay }) { break }
        try await Task.sleep(for: .milliseconds(50))
    }
    endpoint.isLooping = true
    endpoint.setPlaybackSpeed(3)
    endpoint.play()
    now = 10
    endpoint.setPlaybackSpeed(0.5)
    #expect(endpoint.isPlaying)
    #expect(endpoint.position == 0)
    #expect(endpoint.playbackSpeed == 0.5)
    endpoint.pause()
    #expect(!endpoint.isPlaying)
    endpoint.clear()
}

@Test @MainActor func loopCannotRestartLoadingOrFailedPlayersAtEndpoint() {
    let player = ComparisonPlayer(uptime: { 1 })
    let video = ComparisonVideo(path: "unused.mp4", frames: 75, completed: true, provenance: "test")
    player.effect = .init(name: "unready", rust: video, metal: video)
    player.setPlaybackSpeed(3)
    player.isLooping = true
    player.isPlaying = true
    player.setPlaybackSpeed(0.5)
    #expect(!player.isPlaying)
    #expect(player.position == player.duration)
    #expect(player.rust.rate == 0 && player.metal.rate == 0)
    player.play()
    #expect(!player.isPlaying)
    #expect(player.error != nil)
}
