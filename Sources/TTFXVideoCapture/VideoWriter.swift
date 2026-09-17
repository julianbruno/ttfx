import Foundation

final class VideoWriter {
    private let process = Process()
    private let pipe = Pipe()
    private let output: URL
    init(output: URL, width: Int, height: Int, fps: Int, ffmpeg: String) throws {
        self.output = output
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = ["-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pixel_format", "bgra", "-video_size", "\(width)x\(height)", "-framerate", "\(fps)", "-i", "pipe:0", "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "16", "-pix_fmt", "yuv420p", "-movflags", "+faststart", output.path]
        process.standardInput = pipe
        try process.run()
    }
    func append(_ pixels: Data) throws { try pipe.fileHandleForWriting.write(contentsOf: pixels) }
    func finish() throws {
        try pipe.fileHandleForWriting.close()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CaptureError.message("ffmpeg failed for \(output.lastPathComponent)") }
    }
    deinit {
        try? pipe.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
    }
}
