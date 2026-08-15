import Foundation

public enum PathEasing: Equatable, Sendable {
    case linear
    case inOutQuad
    case outExpo
    case outCirc
    case inOutQuart
    case inOutExpo
    case outSine
    case inOutSine

    func apply(_ value: Double) -> Double {
        switch self {
        case .linear: return value
        case .inOutQuad:
            if value < 0.5 { return 2 * value * value }
            let inverse = -2 * value + 2
            return 1 - inverse * inverse / 2
        case .outExpo:
            return value == 1 ? 1 : 1 - pow(2, -10 * value)
        case .outCirc:
            return sqrt(1 - pow(value - 1, 2))
        case .inOutQuart:
            if value < 0.5 { return 8 * pow(value, 4) }
            return 1 - pow(-2 * value + 2, 4) / 2
        case .inOutExpo:
            if value == 0 || value == 1 { return value }
            if value < 0.5 { return pow(2, 20 * value - 10) / 2 }
            return (2 - pow(2, -20 * value + 10)) / 2
        case .outSine:
            return sin(value * .pi / 2)
        case .inOutSine:
            return -(cos(.pi * value) - 1) / 2
        }
    }
}

public struct PathSegment: Equatable, Sendable {
    public let start: Coordinate
    public let end: Coordinate
    public let controls: [Coordinate]

    public init(start: Coordinate, end: Coordinate, controls: [Coordinate] = []) {
        self.start = start
        self.end = end
        self.controls = controls
    }

    func coordinate(at progress: Double) -> Coordinate {
        controls.isEmpty
            ? Geometry.coordinateOnLine(from: start, to: end, t: progress)
            : Geometry.coordinateOnBezier(from: start, controls: controls, to: end, t: progress)
    }

    var distance: Double {
        controls.isEmpty
            ? Geometry.lineLength(from: start, to: end)
            : Geometry.bezierLength(from: start, controls: controls, to: end)
    }
}

public struct ComposedPath: Equatable, Sendable {
    public let id: String
    public let speed: Double
    public let easing: PathEasing
    public let holdTicks: Int
    public let loop: Bool
    public let segments: [PathSegment]

    public init(
        id: String,
        speed: Double,
        easing: PathEasing = .linear,
        holdTicks: Int = 0,
        loop: Bool = false,
        waypoints: [Coordinate],
        controls: [[Coordinate]] = []
    ) {
        precondition(speed > 0, "path speed must be positive")
        precondition(holdTicks >= 0, "hold ticks must not be negative")
        precondition(waypoints.count >= 2, "a path requires two waypoints")
        self.id = id
        self.speed = speed
        self.easing = easing
        self.holdTicks = holdTicks
        self.loop = loop
        self.segments = zip(waypoints, waypoints.dropFirst()).enumerated().map { index, pair in
            PathSegment(start: pair.0, end: pair.1, controls: index < controls.count ? controls[index] : [])
        }
    }
}

public enum PathStep: Equatable, Sendable {
    case moving(Coordinate)
    case holding(Coordinate)
    case complete(Coordinate)
}

public struct PathCursor: Sendable {
    public private(set) var path: ComposedPath
    private var segmentIndex = 0
    private var stepInSegment = 0
    private var holdRemaining: Int?

    public init(path: ComposedPath) {
        self.path = path
    }

    public mutating func reset() {
        segmentIndex = 0
        stepInSegment = 0
        holdRemaining = nil
    }

    public mutating func step() -> PathStep {
        if var holdRemaining {
            let end = path.segments[path.segments.count - 1].end
            if holdRemaining > 0 {
                holdRemaining -= 1
                self.holdRemaining = holdRemaining
                return .holding(end)
            }
            if path.loop {
                reset()
                return .moving(path.segments[0].start)
            }
            return .complete(end)
        }
        let segment = path.segments[segmentIndex]
        let steps = max(1, PyCompat.roundHalfEven(segment.distance / path.speed))
        stepInSegment += 1
        let fraction = min(Double(stepInSegment) / Double(steps), 1)
        let coordinate = segment.coordinate(at: path.easing.apply(fraction))
        if stepInSegment == steps {
            if segmentIndex < path.segments.count - 1 {
                segmentIndex += 1
                stepInSegment = 0
            } else {
                holdRemaining = path.holdTicks
            }
        }
        return .moving(coordinate)
    }
}

public struct PathChain: Equatable, Sendable {
    public let pathIDs: [String]
    public let loop: Bool

    public init(pathIDs: [String], loop: Bool = false) {
        precondition(!pathIDs.isEmpty, "path chain requires a path")
        self.pathIDs = pathIDs
        self.loop = loop
    }
}

public struct ChainedPathStep: Equatable, Sendable {
    public let pathID: String
    public let step: PathStep
}

public struct PathChainCursor: Sendable {
    private let chain: PathChain
    private let paths: [String: ComposedPath]
    private var pathIndex = 0
    private var cursor: PathCursor

    public init(chain: PathChain, paths: [ComposedPath]) {
        self.chain = chain
        self.paths = Dictionary(uniqueKeysWithValues: paths.map { ($0.id, $0) })
        guard let first = self.paths[chain.pathIDs[0]] else { preconditionFailure("chain path not found") }
        cursor = .init(path: first)
    }

    public mutating func reset() {
        pathIndex = 0
        cursor = .init(path: paths[chain.pathIDs[0]]!)
    }

    public mutating func step() -> ChainedPathStep {
        let pathID = chain.pathIDs[pathIndex]
        let result = cursor.step()
        guard case .complete = result else { return .init(pathID: pathID, step: result) }
        if pathIndex + 1 < chain.pathIDs.count {
            pathIndex += 1
            cursor = .init(path: paths[chain.pathIDs[pathIndex]]!)
            return step()
        }
        if chain.loop {
            reset()
            return step()
        }
        return .init(pathID: pathID, step: result)
    }
}
