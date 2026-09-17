import Foundation
import SwiftUI
import AppKit
import TTFXCore
import TTFXEffects
import TTFXSwiftUI
import TTFXComparisonKit

internal enum CaptureError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let message): message } }
}

@main struct TTFXVideoCapture {
    @MainActor static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        func option(_ name: String, _ fallback: String) -> String {
            guard let i = arguments.firstIndex(of: name), arguments.indices.contains(i + 1) else { return fallback }
            return arguments[i + 1]
        }
        if arguments.contains("--help") {
            print("TTFXVideoCapture [--output directory] [--rust binary] [--swift-cli binary] [--ffmpeg binary] [--effect name] [--max-frames 3000] [--fps 25] [--seed 42]")
            return
        }
        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let root = projectRoot(currentDirectory: currentDirectory)
        let output = URL(fileURLWithPath: option("--output", root.appendingPathComponent("artifacts/video-comparison").path))
        let rust = option("--rust", root.appendingPathComponent("target/release/ttfx").path)
        let swiftCLI = option("--swift-cli", URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("ttfx").path)
        let ffmpeg = option("--ffmpeg", "/opt/homebrew/bin/ffmpeg")
        guard let fps = Int(option("--fps", "25")), (1...120).contains(fps),
              let maxFrames = Int(option("--max-frames", "3000")), (1...100000).contains(maxFrames),
              let seed = UInt64(option("--seed", "42")) else { throw CaptureError.message("Invalid fps, max-frames or seed") }
        let text = "TTFX\nRust + Swift\nVisual comparison"
        let columns = 24, rows = 8
        let selected = option("--effect", "all")
        guard selected == "all" || EffectRegistry.contains(selected) else { throw CaptureError.message("Unknown effect: \(selected)") }
        let effects = selected == "all" ? EffectRegistry.names : [selected]
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let git = gitMetadata(repository: root)
        var manifest = ComparisonManifest(generatedAt: ISO8601DateFormatter().string(from: Date()), revision: git.revision, text: text, seed: seed, columns: columns, rows: rows, fps: fps, maxFrames: maxFrames, effects: [])
        // A single-effect rerun updates a compatible existing library without dropping other pairs.
        if selected != "all", let existing = try? ComparisonManifest.load(from: output) {
            guard existing.text == text, existing.seed == seed, existing.fps == fps, existing.columns == columns, existing.rows == rows else { throw CaptureError.message("Existing library settings differ; choose a new output folder") }
            manifest.effects = existing.effects.filter { $0.name != selected }
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let provenance: [String: String] = ["rustBinary": rust, "swiftCLIBinary": swiftCLI, "swiftCLICommand": dumpArguments(name: "EFFECT", fps: fps, seed: seed, cap: maxFrames + 1).joined(separator: " "), "ffmpegBinary": ffmpeg, "rustCommand": dumpArguments(name: "EFFECT", fps: fps, seed: seed, cap: maxFrames + 1).joined(separator: " "), "workingTreeStatus": git.workingTreeStatus, "captureMethod": "Rust and actual Swift CLI executable ANSI replay through CoreText; Swift native effect frames through production Metal shaders; one encoded frame per engine tick. No frame sampling or duration normalization."]
        try encoder.encode(provenance).write(to: output.appendingPathComponent("provenance.json"), options: .atomic)
        let renderer = TTFXMetalRenderer()
        guard renderer.canEncodeGPUCommands else { throw CaptureError.message("Metal GPU unavailable; no substitute renderer is used") }
        let rasterizer = ANSIRasterizer(columns: columns, rows: rows)
        for name in effects {
            print("Capturing \(name)…")
            let directory = output.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let dumpURL = directory.appendingPathComponent("rust.frames")
            try ansiDump(binary: rust, name: name, text: text, fps: fps, seed: seed, cap: maxFrames + 1, output: dumpURL, label: "Rust")
            let rawFrames = try parseFrames(Data(contentsOf: dumpURL))
            guard !rawFrames.isEmpty else { throw CaptureError.message("Rust emitted no frames for \(name)") }
            let rustCount = min(maxFrames, rawFrames.count)
            let rustWriter = try VideoWriter(output: directory.appendingPathComponent("rust.mp4"), width: columns * 16, height: rows * 24, fps: fps, ffmpeg: ffmpeg)
            for rawFrame in rawFrames.prefix(maxFrames) {
                try autoreleasepool { try rustWriter.append(rasterizer.pixels(rawFrame)) }
            }
            try rustWriter.finish()
            let cliDumpURL = directory.appendingPathComponent("swift-cli.frames")
            try ansiDump(binary: swiftCLI, name: name, text: text, fps: fps, seed: seed, cap: maxFrames + 1, output: cliDumpURL, label: "Swift CLI")
            let cliFrames = try parseFrames(Data(contentsOf: cliDumpURL))
            guard !cliFrames.isEmpty else { throw CaptureError.message("Swift CLI emitted no frames for \(name)") }
            let cliCount = min(maxFrames, cliFrames.count)
            let cliWriter = try VideoWriter(output: directory.appendingPathComponent("swift-cli.mp4"), width: columns * 16, height: rows * 24, fps: fps, ffmpeg: ffmpeg)
            for frame in cliFrames.prefix(maxFrames) {
                try autoreleasepool { try cliWriter.append(rasterizer.pixels(frame)) }
            }
            try cliWriter.finish()
            let canvas = try Canvas(columns: columns, rows: rows)
            let input = canvas.ingest(text)
            var effect = EffectRegistry.makeEffect(named: name, configuration: EffectConfiguration(text: text, seed: seed, frameRate: fps), canvas: canvas, input: input, seed: seed)!
            let swiftUIWriter = try VideoWriter(output: directory.appendingPathComponent("swiftui.mp4"), width: columns * 16, height: rows * 24, fps: fps, ffmpeg: ffmpeg)
            let metalWriter = try VideoWriter(output: directory.appendingPathComponent("metal.mp4"), width: columns * 16, height: rows * 24, fps: fps, ffmpeg: ffmpeg)
            var swiftCount = 0
            var status = TickStatus.running
            while status == .running, swiftCount < maxFrames {
                var frame = try Frame(columns: columns, rows: rows)
                status = effect.tick(into: &frame)
                let snapshot = TTFXFrameSnapshot(frame: frame)
                try autoreleasepool {
                    try swiftUIWriter.append(renderSwiftUIBGRA(snapshot: snapshot, width: columns * 16, height: rows * 24))
                    try metalWriter.append(renderer.exportBGRA(snapshot: snapshot, cellWidth: 16, cellHeight: 24))
                }
                swiftCount += 1
            }
            try swiftUIWriter.finish()
            try metalWriter.finish()
            manifest.effects.append(.init(name: name,
                rust: .init(path: "\(name)/rust.mp4", frames: rustCount, completed: rawFrames.count <= maxFrames, provenance: "Rust terminal ANSI output replayed with CoreText (Menlo). Deterministic export, not a screen recording."),
                swiftUI: .init(path: "\(name)/swiftui.mp4", frames: swiftCount, completed: status == .complete, provenance: "Swift effect engine rendered by the app's SwiftUI fallback frame view with a colored fixed-cell Menlo grid."),
                swiftCLI: .init(path: "\(name)/swift-cli.mp4", frames: cliCount, completed: cliFrames.count <= maxFrames, provenance: "Actual pure-Swift CLI executable ANSI output replayed with CoreText (Menlo). Not SwiftUI or Metal."),
                metal: .init(path: "\(name)/metal.mp4", frames: swiftCount, completed: status == .complete, provenance: "Swift effect engine rendered by the gallery’s production Metal atlas and shaders to GPU textures.")))
            manifest.effects.sort { $0.name < $1.name }
            try encoder.encode(manifest).write(to: output.appendingPathComponent("manifest.json"), options: .atomic)
            print("\(name): Rust \(rustCount) frames\(rawFrames.count > maxFrames ? " (limit reached)" : " complete"), SwiftUI/Metal \(swiftCount) frames\(status == .complete ? " complete" : " (limit reached)")")
        }
        print("Library ready: \(output.path) — \(manifest.effects.count) effect pairs")
    }
    @MainActor static func renderSwiftUIBGRA(snapshot: TTFXFrameSnapshot, width: Int, height: Int) throws -> Data {
        let content = TTFXFrameView(snapshot: snapshot, fontSize: 20, cellSize: CGSize(width: 16, height: 24))
            .frame(width: CGFloat(width), height: CGFloat(height), alignment: .topLeading)
            .background(Color.black)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: CGFloat(width), height: CGFloat(height))
        guard let image = renderer.cgImage else { throw CaptureError.message("SwiftUI rendering failed") }
        var pixels = Data(count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress,
                  let context = CGContext(data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
                throw CaptureError.message("Could not allocate SwiftUI bitmap context")
            }
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }

    static func projectRoot(currentDirectory: URL, sourceFile: String = #filePath, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = environment["TTFX_REPOSITORY_ROOT"], !override.isEmpty {
            return URL(fileURLWithPath: override).standardizedFileURL
        }
        if let root = firstAncestorContainingProjectFiles(from: currentDirectory) { return root }
        let sourceDirectory = URL(fileURLWithPath: sourceFile).deletingLastPathComponent()
        if let root = firstAncestorContainingProjectFiles(from: sourceDirectory) { return root }
        return currentDirectory.standardizedFileURL
    }

    static func firstAncestorContainingProjectFiles(from url: URL) -> URL? {
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

    static func gitMetadata(repository: URL) -> (revision: String, workingTreeStatus: String) {
        let revision = optionalCommand("/usr/bin/git", ["-C", repository.path, "rev-parse", "HEAD"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let dirty = optionalCommand("/usr/bin/git", ["-C", repository.path, "status", "--porcelain"])
        guard let revision else {
            return ("unknown (not a git repository)", "unavailable: not a git repository")
        }
        return (revision + ((dirty ?? "").isEmpty ? "" : " (working tree modified)"), dirty ?? "unavailable")
    }

    static func optionalCommand(_ executable: String, _ arguments: [String]) -> String? {
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments; process.standardOutput = pipe; process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
    static func ansiDump(binary: String, name: String, text: String, fps: Int, seed: UInt64, cap: Int, output: URL, label: String) throws {
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let file = try FileHandle(forWritingTo: output)
        defer { try? file.close() }
        let process = Process(), input = Pipe()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = dumpArguments(name: name, fps: fps, seed: seed, cap: cap)
        process.standardOutput = file; process.standardInput = input
        try process.run(); try input.fileHandleForWriting.write(contentsOf: Data(text.utf8)); try input.fileHandleForWriting.close()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CaptureError.message("\(label) capture failed: \(name) (exit \(process.terminationStatus))") }
    }
    static func dumpArguments(name: String, fps: Int, seed: UInt64, cap: Int) -> [String] {
        ["--parity-dump", "--virtual-clock", "--seed", "\(seed)", "--frame-rate", "\(fps)", "--max-frames", "\(cap)", "--ignore-terminal-dimensions", "--canvas-width", "24", "--canvas-height", "8", "--anchor-text", "sw", "--anchor-canvas", "sw", name]
    }

    static func parseFrames(_ data: Data) throws -> [String] {
        var offset = 0, frames: [String] = []
        while offset < data.count {
            guard let newline = data[offset...].firstIndex(of: 10),
                  let length = Int(String(decoding: data[offset..<newline], as: UTF8.self)), length >= 0 else { throw CaptureError.message("Invalid frame length") }
            let start = newline + 1, end = start + length
            guard end < data.count, data[end] == 10, let frame = String(data: data[start..<end], encoding: .utf8) else { throw CaptureError.message("Truncated or invalid ANSI frame") }
            frames.append(frame); offset = end + 1
        }
        return frames
    }
}
