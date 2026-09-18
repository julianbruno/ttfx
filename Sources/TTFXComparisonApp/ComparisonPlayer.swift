import Foundation
import Observation
import AVFoundation
import TTFXComparisonKit

@MainActor @Observable final class ComparisonPlayer {
    let rust = AVPlayer()
    let swiftCLI = AVPlayer()
    let swiftUI = AVPlayer()
    let metal = AVPlayer()
    var effect: ComparisonEffect?
    var fps = 25
    var position = 0.0
    var isPlaying = false
    var isLooping = false
    private(set) var playbackSpeed = 1.0
    private(set) var playbackProfile = PlaybackProfile.none
    private static let updateInterval = 1.0 / 30
    static let playbackSpeeds: [Double] = [0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3]
    var error: String?
    private var startedAt: TimeInterval = 0
    private var startPosition = 0.0
    private var timer: Timer?
    private let uptime: () -> TimeInterval
    init(uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.uptime = uptime
        // Scheduled host-clock playback requires disabling AVPlayer's automatic stall waits.
        // Otherwise setRate(time:atHostTime:) raises an Objective-C exception mid-action.
        rust.automaticallyWaitsToMinimizeStalling = false
        swiftCLI.automaticallyWaitsToMinimizeStalling = false
        swiftUI.automaticallyWaitsToMinimizeStalling = false
        metal.automaticallyWaitsToMinimizeStalling = false
    }
    var duration: Double {
        guard let effect else { return 0 }
        return Double(effect.maximumFrames) / Double(fps)
    }
    func load(_ effect: ComparisonEffect, directory: URL, fps: Int) throws {
        pause()
        let rustURL = try ComparisonManifest.videoURL(effect.rust, directory: directory)
        let cliURL = try effect.swiftCLI.map { try ComparisonManifest.videoURL($0, directory: directory) }
        let swiftUIURL = try effect.swiftUI.map { try ComparisonManifest.videoURL($0, directory: directory) }
        let metalURL = try ComparisonManifest.videoURL(effect.metal, directory: directory)
        self.effect = effect; self.fps = fps; self.position = 0; self.error = nil
        rust.replaceCurrentItem(with: AVPlayerItem(url: rustURL))
        swiftCLI.replaceCurrentItem(with: cliURL.map(AVPlayerItem.init(url:)))
        swiftUI.replaceCurrentItem(with: swiftUIURL.map(AVPlayerItem.init(url:)))
        metal.replaceCurrentItem(with: AVPlayerItem(url: metalURL))
        rust.actionAtItemEnd = .pause; swiftCLI.actionAtItemEnd = .pause; swiftUI.actionAtItemEnd = .pause; metal.actionAtItemEnd = .pause
        rust.isMuted = true; swiftCLI.isMuted = true; swiftUI.isMuted = true; metal.isMuted = true
        seek(0)
    }
    func pause() {
        if isPlaying { position = clockPosition() }
        rust.pause(); swiftCLI.pause(); swiftUI.pause(); metal.pause(); timer?.invalidate(); timer = nil; isPlaying = false
    }
    func clear() {
        pause(); effect = nil; position = 0; error = nil
        rust.replaceCurrentItem(with: nil); swiftCLI.replaceCurrentItem(with: nil); swiftUI.replaceCurrentItem(with: nil); metal.replaceCurrentItem(with: nil)
    }
    func play() {
        guard effect != nil, !isPlaying else { return }
        if position >= duration { position = 0 }
        guard loadedPlayers.allSatisfy({ $0.currentItem?.status == .readyToPlay }) else {
            error = "Videos are loading. Press Play when they are ready."; return
        }
        error = nil
        isPlaying = true
        schedulePlayback()
        timer = Timer.scheduledTimer(withTimeInterval: Self.updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }
    func setPlaybackSpeed(_ speed: Double) {
        guard speed.isFinite, (0.5...3).contains(speed), speed != playbackSpeed else { return }
        if isPlaying {
            position = clockPosition()
            // Stop at the old-rate endpoint before changing the clock scale.
            if position >= duration && !canLoop { pause() }
        }
        playbackSpeed = speed
        if isPlaying {
            if position >= duration { completeEndpoint() }
            else { schedulePlayback() }
        }
    }
    func setPlaybackProfile(_ profile: PlaybackProfile) {
        guard profile != playbackProfile else { return }
        if isPlaying {
            position = clockPosition()
            if position >= duration && !canLoop { pause() }
        }
        playbackProfile = profile
        if isPlaying {
            if position >= duration { completeEndpoint() }
            else { schedulePlayback() }
        }
    }
    nonisolated static func mediaPosition(start: Double, elapsed: Double, speed: Double, duration: Double) -> Double {
        min(duration, start + max(0, elapsed) * speed)
    }
    private func clockPosition() -> Double {
        playbackProfile.position(start: startPosition, elapsed: uptime() - startedAt, speed: playbackSpeed, duration: duration)
    }
    private func schedulePlayback() {
        startPosition = position
        // All present players use the same host-clock deadline.
        let hostTime = CMClockGetTime(CMClockGetHostTimeClock()) + CMTime(seconds: 0.1, preferredTimescale: 600)
        startedAt = uptime() + 0.1
        start(rust, video: effect!.rust, hostTime: hostTime)
        if let video = effect!.swiftCLI { start(swiftCLI, video: video, hostTime: hostTime) }
        if let video = effect!.swiftUI { start(swiftUI, video: video, hostTime: hostTime) }
        start(metal, video: effect!.metal, hostTime: hostTime)
    }
    private func start(_ player: AVPlayer, video: ComparisonVideo, hostTime: CMTime) {
        guard position < video.duration(fps: fps) else { player.pause(); return }
        player.setRate(Float(playbackProfile.rate(start: startPosition, elapsed: 0, speed: playbackSpeed, duration: duration, interval: Self.updateInterval)), time: CMTime(seconds: position, preferredTimescale: 600), atHostTime: hostTime)
    }
    private func update() {
        guard isPlaying else { return }
        position = clockPosition()
        if let item = loadedPlayers.compactMap({ $0.currentItem }).first(where: { $0.status == .failed }) {
            error = item.error?.localizedDescription ?? "Video playback failed."; pause(); return
        }
        if position >= duration { completeEndpoint() }
        else if !playbackProfile.isConstant && uptime() >= startedAt {
            let rate = Float(playbackProfile.rate(
                start: startPosition, elapsed: uptime() - startedAt,
                speed: playbackSpeed, duration: duration, interval: Self.updateInterval
            ))
            // Adjust rates together, without a seek on every frame.
            if let effect {
                updateRate(rust, video: effect.rust, rate: rate)
                updateRate(metal, video: effect.metal, rate: rate)
                if let video = effect.swiftCLI { updateRate(swiftCLI, video: video, rate: rate) }
                if let video = effect.swiftUI { updateRate(swiftUI, video: video, rate: rate) }
            }
        }
    }
    private func updateRate(_ player: AVPlayer, video: ComparisonVideo, rate: Float) {
        if position >= video.duration(fps: fps) { player.pause() }
        else { player.rate = rate }
    }
    private var canLoop: Bool {
        isLooping && error == nil && loadedPlayers.allSatisfy { $0.currentItem?.status == .readyToPlay }
    }
    private func completeEndpoint() {
        guard canLoop else { pause(); return }
        position = 0
        // setRate(time:atHostTime:) positions and starts each player on one deadline.
        // Do not launch asynchronous seeks here: their completions can race the scheduled start.
        schedulePlayback()
    }
    func seek(_ value: Double) {
        pause()
        position = min(max(0, value), duration)
        guard let effect else { return }
        rust.seek(to: CMTime(seconds: ComparisonTimeline.time(position, frames: effect.rust.frames, fps: fps), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        if let video = effect.swiftCLI {
            swiftCLI.seek(to: CMTime(seconds: ComparisonTimeline.time(position, frames: video.frames, fps: fps), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        if let video = effect.swiftUI {
            swiftUI.seek(to: CMTime(seconds: ComparisonTimeline.time(position, frames: video.frames, fps: fps), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        metal.seek(to: CMTime(seconds: ComparisonTimeline.time(position, frames: effect.metal.frames, fps: fps), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    private var loadedPlayers: [AVPlayer] {
        [rust, metal] + (effect?.swiftUI == nil ? [] : [swiftUI]) + (effect?.swiftCLI == nil ? [] : [swiftCLI])
    }
}
