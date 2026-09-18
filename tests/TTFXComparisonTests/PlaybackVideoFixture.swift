import Foundation
import AVFoundation
import CoreVideo
import Testing
import TTFXComparisonKit

/// Playback tests own their media; optional user capture output is not a test fixture.
@MainActor final class PlaybackVideoFixture {
    let directory: URL
    let fps = 25
    let shortVideo = ComparisonVideo(path: "short.mp4", frames: 60, completed: true, provenance: "Synthetic test fixture")
    let longVideo = ComparisonVideo(path: "long.mp4", frames: 100, completed: true, provenance: "Synthetic test fixture")

    var shortEffect: ComparisonEffect { effect(shortVideo) }
    var longEffect: ComparisonEffect { effect(longVideo) }

    private init(directory: URL) { self.directory = directory }

    static func make() async throws -> PlaybackVideoFixture {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ttfx-playback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fixture = PlaybackVideoFixture(directory: directory)
        do {
            for video in [fixture.shortVideo, fixture.longVideo] {
                try await fixture.write(video)
            }
            return fixture
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    func remove() throws { try FileManager.default.removeItem(at: directory) }

    private func effect(_ video: ComparisonVideo) -> ComparisonEffect {
        .init(name: "fixture", rust: video, swiftUI: video, swiftCLI: video, metal: video)
    }

    private func write(_ video: ComparisonVideo) async throws {
        let writer = try AVAssetWriter(outputURL: directory.appendingPathComponent(video.path), fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64
        ])
        try #require(writer.canAdd(input))
        writer.add(input)
        try #require(writer.startWriting(), "\(String(describing: writer.error))")
        writer.startSession(atSourceTime: .zero)
        do {
            let pool = try #require(adaptor.pixelBufferPool)
            for frame in 0..<video.frames {
                let deadline = ContinuousClock.now + .seconds(5)
                while !input.isReadyForMoreMediaData {
                    try #require(writer.status == .writing, "\(String(describing: writer.error))")
                    try #require(ContinuousClock.now < deadline, "Video encoder timed out.")
                    try await Task.sleep(for: .milliseconds(5))
                }
                var buffer: CVPixelBuffer?
                try #require(CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess)
                let pixels = try #require(buffer)
                CVPixelBufferLockBaseAddress(pixels, [])
                if let base = CVPixelBufferGetBaseAddress(pixels) {
                    memset(base, Int32(frame % 255), CVPixelBufferGetBytesPerRow(pixels) * 64)
                }
                CVPixelBufferUnlockBaseAddress(pixels, [])
                try #require(adaptor.append(pixels, withPresentationTime: CMTime(value: Int64(frame), timescale: Int32(fps))))
            }
            writer.endSession(atSourceTime: CMTime(value: Int64(video.frames), timescale: Int32(fps)))
            input.markAsFinished()
            await writer.finishWriting()
            try #require(writer.status == .completed, "\(String(describing: writer.error))")
        } catch {
            writer.cancelWriting()
            throw error
        }
    }
}

@Test @MainActor func playbackFixturesHaveEncodedDurationsAndCleanUp() async throws {
    let fixture = try await PlaybackVideoFixture.make()
    defer { try? fixture.remove() }
    for video in [fixture.shortVideo, fixture.longVideo] {
        let asset = AVURLAsset(url: fixture.directory.appendingPathComponent(video.path))
        let duration = try await asset.load(.duration)
        #expect(abs(duration.seconds - video.duration(fps: fixture.fps)) < 0.001)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        #expect(tracks.count == 1)
    }
    try fixture.remove()
    #expect(!FileManager.default.fileExists(atPath: fixture.directory.path))
}
