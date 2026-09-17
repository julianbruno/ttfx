import Foundation

public struct ComparisonVideo: Codable, Equatable, Sendable {
    public var path: String
    public var frames: Int
    public var completed: Bool
    public var provenance: String
    public init(path: String, frames: Int, completed: Bool, provenance: String) {
        self.path = path; self.frames = frames; self.completed = completed; self.provenance = provenance
    }
    public func duration(fps: Int) -> Double { Double(frames) / Double(fps) }
}

public struct ComparisonEffect: Codable, Equatable, Identifiable, Sendable {
    public var name: String
    public var rust: ComparisonVideo
    public var swiftCLI: ComparisonVideo?
    public var swiftUI: ComparisonVideo?
    public var metal: ComparisonVideo
    public var id: String { name }
    public init(name: String, rust: ComparisonVideo, swiftUI: ComparisonVideo? = nil, swiftCLI: ComparisonVideo? = nil, metal: ComparisonVideo) {
        self.name = name; self.rust = rust; self.swiftUI = swiftUI; self.swiftCLI = swiftCLI; self.metal = metal
    }
}

public struct ComparisonManifest: Codable, Equatable, Sendable {
    public var version = 1
    public var generatedAt: String
    public var revision: String
    public var text: String
    public var seed: UInt64
    public var columns: Int
    public var rows: Int
    public var fps: Int
    public var maxFrames: Int
    public var effects: [ComparisonEffect]
    public init(generatedAt: String, revision: String, text: String, seed: UInt64, columns: Int, rows: Int, fps: Int, maxFrames: Int, effects: [ComparisonEffect]) {
        self.generatedAt = generatedAt; self.revision = revision; self.text = text; self.seed = seed
        self.columns = columns; self.rows = rows; self.fps = fps; self.maxFrames = maxFrames; self.effects = effects
    }
    public static func load(from directory: URL) throws -> Self {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw ComparisonError.missingManifest(manifestURL.path)
        }
        let manifest = try JSONDecoder().decode(Self.self, from: Data(contentsOf: manifestURL))
        guard manifest.version == 1, manifest.fps > 0, manifest.columns > 0, manifest.rows > 0,
              Set(manifest.effects.map(\.name)).count == manifest.effects.count else {
            throw ComparisonError.invalidManifest
        }
        for effect in manifest.effects {
            for video in effect.videos {
                guard video.frames > 0 else { throw ComparisonError.invalidManifest }
                _ = try videoURL(video, directory: directory)
            }
        }
        return manifest
    }
    public static func videoURL(_ video: ComparisonVideo, directory: URL) throws -> URL {
        let root = directory.standardizedFileURL.resolvingSymlinksInPath()
        let url = root.appendingPathComponent(video.path).standardizedFileURL.resolvingSymlinksInPath()
        guard !video.path.hasPrefix("/"), url.path.hasPrefix(root.path + "/"),
              FileManager.default.fileExists(atPath: url.path) else { throw ComparisonError.missingVideo(video.path) }
        return url
    }
}

public extension ComparisonEffect {
    var videos: [ComparisonVideo] {
        [rust] + (swiftCLI.map { [$0] } ?? []) + (swiftUI.map { [$0] } ?? []) + [metal]
    }

    var maximumFrames: Int {
        videos.map(\.frames).max() ?? 0
    }
}

public enum ComparisonError: LocalizedError {
    case invalidManifest
    case missingManifest(String)
    case missingVideo(String)
    public var errorDescription: String? {
        switch self {
        case .invalidManifest: "The video library manifest is invalid or uses an unsupported version."
        case .missingManifest(let path): "No video comparison manifest found at \(path). Generate one with ./tools/video-comparison/capture.sh, or open a folder that contains manifest.json."
        case .missingVideo(let path): "Video is missing or outside the library: \(path)"
        }
    }
}

public enum ComparisonTimeline {
    /// Hold the final encoded frame when one recording ends first.
    public static func time(_ time: Double, frames: Int, fps: Int) -> Double {
        min(max(0, time), Double(max(0, frames - 1)) / Double(max(1, fps)))
    }
}
