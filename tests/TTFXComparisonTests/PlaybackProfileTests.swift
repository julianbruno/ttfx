import Foundation
import AVFoundation
import TTFXComparisonKit
import Testing
import SwiftUI
@testable import TTFXComparisonApp

@Test func playbackProfilesMapMonotonicallyAndResumeContinuously() {
    for profile in PlaybackProfile.allCases {
        #expect(profile.position(start: 0, elapsed: 0, speed: 1, duration: 10) == 0)
        #expect(profile.position(start: 0, elapsed: 10, speed: 1, duration: 10) == 10)
        var previous = 0.0
        for index in 0...100 {
            let time = Double(index) / 10
            let position = profile.position(start: 0, elapsed: time, speed: 1, duration: 10)
            #expect(position >= previous)
            #expect(abs(profile.position(start: position, elapsed: 0, speed: 3, duration: 10) - position) < 0.0001)
            previous = position
        }
        #expect(profile.position(start: 4, elapsed: -1, speed: 1, duration: 10) == 4)
        #expect(profile.position(start: 0, elapsed: 5, speed: 2, duration: 10) == 10)
    }
    #expect(PlaybackProfile.easeIn.position(start: 0, elapsed: 2, speed: 1, duration: 10) < 2)
    #expect(PlaybackProfile.easeOut.position(start: 0, elapsed: 2, speed: 1, duration: 10) > 2)
}

@Test @MainActor func playbackProfileDefaultsNoneAndDoesNotStartPausedPlayer() {
    let player = ComparisonPlayer()
    #expect(player.playbackProfile == .none)
    player.position = 2
    player.setPlaybackProfile(.easeOut)
    #expect(player.position == 2)
    #expect(player.playbackProfile == .easeOut)
    #expect(!player.isPlaying)
    player.setPlaybackSpeed(2)
    #expect(player.playbackProfile == .easeOut)
}

@Test(.enabled(if: profileVideoLibraryExists, "Generated video library unavailable."))
@MainActor func playbackProfilesKeepGeneratedTracksTogetherAcrossChanges() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = root.appendingPathComponent("artifacts/video-comparison")
    let manifest = try ComparisonManifest.load(from: directory)
    let effect = try #require(manifest.effects.first(where: { $0.maximumFrames >= manifest.fps * 2 && $0.swiftCLI != nil && $0.swiftUI != nil }))
    let player = ComparisonPlayer()
    try player.load(effect, directory: directory, fps: manifest.fps)
    let tracks = [player.rust, player.swiftCLI, player.swiftUI, player.metal]
    for _ in 0..<100 {
        if tracks.allSatisfy({ $0.currentItem?.status == .readyToPlay }) { break }
        try await Task.sleep(for: .milliseconds(50))
    }
    player.setPlaybackProfile(.easeIn)
    player.play()
    try await Task.sleep(for: .milliseconds(800))
    #expect(player.position > 0)
    for track in tracks {
        #expect(abs(track.currentTime().seconds - player.position) < 0.15)
    }
    let before = player.position
    player.setPlaybackProfile(.easeOut)
    #expect(player.position >= before && player.position - before < 0.1)
    try await Task.sleep(for: .milliseconds(350))
    for track in tracks {
        #expect(abs(track.currentTime().seconds - player.position) < 0.15)
    }
    player.pause()
    let paused = player.position
    player.setPlaybackProfile(.easeInOut)
    #expect(player.position == paused)
    player.seek(player.duration - 0.1)
    try await Task.sleep(for: .milliseconds(200))
    player.setPlaybackSpeed(3)
    player.play()
    try await Task.sleep(for: .milliseconds(600))
    #expect(player.position == player.duration)
    #expect(!player.isPlaying)
    player.isLooping = true
    player.play()
    try await Task.sleep(for: .seconds(player.duration / 3 + 0.5))
    #expect(player.isPlaying)
    #expect(player.position < player.duration)
    for track in tracks {
        #expect(abs(track.currentTime().seconds - player.position) < 0.15)
    }
    player.clear()
}

private var profileVideoLibraryExists: Bool {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return FileManager.default.fileExists(atPath: root.appendingPathComponent("artifacts/video-comparison/manifest.json").path)
}
