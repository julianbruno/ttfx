import Testing
import Foundation
import AVFoundation
@testable import TTFXComparisonKit
@testable import TTFXComparisonApp

@Test @MainActor func pairedPlayersAdvanceAndPauseOnGeneratedVideos() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = root.appendingPathComponent("artifacts/video-comparison")
    guard FileManager.default.fileExists(atPath: directory.appendingPathComponent("manifest.json").path) else { return }
    let manifest = try ComparisonManifest.load(from: directory)
    let effect = try #require(manifest.effects.first(where: { $0.name == "print" }))
    let player = ComparisonPlayer()
    try player.load(effect, directory: directory, fps: manifest.fps)
    for _ in 0..<100 {
        if player.rust.currentItem?.status == .readyToPlay, player.metal.currentItem?.status == .readyToPlay { break }
        try await Task.sleep(for: .milliseconds(50))
    }
    player.play()
    #expect(player.isPlaying)
    try await Task.sleep(for: .milliseconds(800))
    #expect(player.position > 0.4)
    #expect(player.rust.currentTime().seconds > 0.4)
    #expect(player.metal.currentTime().seconds > 0.4)
    #expect(abs(player.rust.currentTime().seconds - player.metal.currentTime().seconds) < 0.12)
    player.pause()
    let position = player.position
    try await Task.sleep(for: .milliseconds(150))
    #expect(player.position == position)
    player.clear()
}
