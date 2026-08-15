public enum SceneSync: Equatable, Sendable {
    case none
    case step
    case distance
    case progress
}

public struct ComposedScene: Equatable, Sendable {
    public let id: String
    public let frames: [SceneFrame]
    public let sync: SceneSync
    public let loop: Bool

    public init(id: String, frames: [SceneFrame], sync: SceneSync = .none, loop: Bool = false) {
        precondition(!frames.isEmpty, "a scene requires a frame")
        self.id = id
        self.frames = frames
        self.sync = sync
        self.loop = loop
    }
}

public struct ScenePlayback: Sendable {
    public let scene: ComposedScene
    private var frameIndex = 0
    private var ticksRemaining: Int
    public private(set) var isComplete = false

    public init(scene: ComposedScene) {
        self.scene = scene
        ticksRemaining = scene.frames[0].duration
    }

    public mutating func reset() {
        frameIndex = 0
        ticksRemaining = scene.frames[0].duration
        isComplete = false
    }

    public mutating func step(progress: Double? = nil) -> SceneFrame? {
        guard !isComplete else { return nil }
        if let progress, scene.sync != .none {
            frameIndex = min(Int(progress * Double(scene.frames.count)), scene.frames.count - 1)
            return scene.frames[frameIndex]
        }
        let current = scene.frames[frameIndex]
        ticksRemaining -= 1
        if ticksRemaining == 0 {
            if frameIndex + 1 < scene.frames.count {
                frameIndex += 1
                ticksRemaining = scene.frames[frameIndex].duration
            } else if scene.loop {
                reset()
            } else {
                isComplete = true
            }
        }
        return current
    }

    public mutating func step(metrics: SceneMetrics) -> SceneFrame? {
        let index: Int
        switch scene.sync {
        case .none:
            return step()
        case .step:
            index = metrics.step
        case .progress:
            index = Int(metrics.progress * Double(scene.frames.count))
        case .distance:
            let ratio = metrics.totalDistance == 0 ? 0 : metrics.distance / metrics.totalDistance
            index = Int(ratio * Double(scene.frames.count))
        }
        frameIndex = min(max(index, 0), scene.frames.count - 1)
        return scene.frames[frameIndex]
    }
}

public struct SceneMetrics: Equatable, Sendable {
    public let step: Int
    public let progress: Double
    public let distance: Double
    public let totalDistance: Double

    public init(step: Int, progress: Double, distance: Double, totalDistance: Double) {
        self.step = step
        self.progress = progress
        self.distance = distance
        self.totalDistance = totalDistance
    }
}

public enum GradientColorBehavior: Equatable, Sendable {
    case `static`
    case dynamic(preexisting: Color?)
}

public enum SceneBuilder {
    public static func gradient(
        symbols: [Character],
        durations: [Int],
        foreground: Gradient?,
        background: Gradient?,
        foregroundBehavior: GradientColorBehavior = .static,
        backgroundBehavior: GradientColorBehavior = .static
    ) throws -> [SceneFrame] {
        precondition(!symbols.isEmpty, "gradient requires symbols")
        precondition(!durations.isEmpty, "gradient requires durations")
        let foregroundSpectrum = try colorSpectrum(for: foreground, behavior: foregroundBehavior)
        let backgroundSpectrum = try colorSpectrum(for: background, behavior: backgroundBehavior)
        let count = max(foregroundSpectrum.count, backgroundSpectrum.count, symbols.count)
        return (0..<count).map { index in
            let symbol = symbols[index % symbols.count]
            let duration = durations[index % durations.count]
            let foregroundWord = colorWord(color(at: index, in: foregroundSpectrum))
            let backgroundWord = colorWord(color(at: index, in: backgroundSpectrum))
            return SceneFrame(symbol: symbol, duration: duration, foreground: foregroundWord, background: backgroundWord)
        }
    }

    private static func colorSpectrum(for gradient: Gradient?, behavior: GradientColorBehavior) throws -> [Color] {
        guard let gradient else { return [] }
        switch behavior {
        case .static:
            return gradient.spectrum
        case let .dynamic(preexisting):
            guard let preexisting, let source = gradient.spectrum.last else { return [] }
            return try Gradient(
                stops: [source, preexisting],
                steps: max(gradient.spectrum.count - 1, 1)
            ).spectrum
        }
    }

    private static func colorWord(_ color: Color?) -> UInt32 {
        guard let color else { return 0 }
        return UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }

    private static func color(at index: Int, in spectrum: [Color]) -> Color? {
        guard !spectrum.isEmpty else { return nil }
        return spectrum[index % spectrum.count]
    }
}
