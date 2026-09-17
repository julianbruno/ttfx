import Foundation
import TTFXCore

public struct RingsEffect: Effect {
    public struct Configuration: Sendable {
        public var ringColors: [Color]
        public var ringGap: Double
        public var spinDuration: Int
        public var spinSpeed: ClosedRange<Double>
        public var disperseDuration: Int
        public var spinDisperseCycles: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            ringColors: [Color] = [Color(hex: "ab48ff"), Color(hex: "e7b2b2"), Color(hex: "fffebd")],
            ringGap: Double = 0.1,
            spinDuration: Int = 200,
            spinSpeed: ClosedRange<Double> = 0.25...1.0,
            disperseDuration: Int = 200,
            spinDisperseCycles: Int = 3,
            finalGradientStops: [Color] = [Color(hex: "ab48ff"), Color(hex: "e7b2b2"), Color(hex: "fffebd")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(ringGap > 0, "ring gap must be positive")
            precondition(spinDuration > 0, "spin duration must be positive")
            precondition(spinSpeed.lowerBound > 0, "spin speed range must be positive")
            precondition(disperseDuration > 0, "disperse duration must be positive")
            precondition(spinDisperseCycles > 0, "spin disperse cycles must be positive")
            self.ringColors = ringColors
            self.ringGap = ringGap
            self.spinDuration = spinDuration
            self.spinSpeed = spinSpeed
            self.disperseDuration = disperseDuration
            self.spinDisperseCycles = spinDisperseCycles
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Phase { case start, disperse, spin, final, complete }
    private enum MotionKind { case ring(Int), initialDisperse, disperse, condense, home, external }
    private struct Motion {
        let kind: MotionKind
        let points: [Coordinate]
        let distances: [Double]
        let total: Double
        let steps: Int
        let easing: Easing
        var step = 0
        init(kind: MotionKind, origin: Coordinate, targets: [Coordinate], speed: Double, easing: Easing = .linear) {
            self.kind = kind
            self.points = [origin] + targets
            self.distances = zip(points, points.dropFirst()).map { Geometry.lineLength(from: $0, to: $1) }
            self.total = distances.reduce(0, +)
            self.steps = PyCompat.roundHalfEven(total / speed)
            self.easing = easing
        }
        mutating func advance() -> Coordinate {
            guard steps > 0, total > 0 else { return points.last! }
            step += 1
            var distance = easing.value(at: Double(step) / Double(steps)) * total
            for index in distances.indices {
                if distance <= distances[index] {
                    let fraction = distances[index] == 0 ? 0 : distance / distances[index]
                    return Geometry.coordinateOnLine(from: points[index], to: points[index + 1], t: fraction)
                }
                distance -= distances[index]
            }
            return points.last!
        }
        var complete: Bool { step >= steps || total == 0 }
    }
    private struct Glyph {
        let symbol: UInt32
        let input: Coordinate
        let final: Color
        var coordinate: Coordinate
        var foreground: UInt32
        var visible = true
        var rotation: [Coordinate] = []
        var speed = 0.0
        var lastRingPath = 0
        var disperseTargets: [Coordinate] = []
        var spinScene: [UInt32] = []
        var disperseScene: [UInt32] = []
        var scene: [UInt32] = []
        var age = 0
        var spinAge = 0
        var disperseAge = 0
        var sceneIsSpin: Bool?
        var motion: Motion?
        var external: Coordinate?
        var active: Bool { motion != nil || age < scene.count }
    }
    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var rings: [[Int]] = []
    private var phase = Phase.start
    private var initialRemaining = 100
    private var firstDisperse = true
    private var spinRemaining: Int
    private var disperseRemaining: Int
    private var cyclesRemaining: Int
    private var gap = 1

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, ringsConfiguration: .init())
    }
    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64, ringsConfiguration: Configuration) {
        self.canvas = canvas
        self.options = ringsConfiguration
        self.rng = .init(seed: seed)
        self.spinRemaining = ringsConfiguration.spinDuration
        self.disperseRemaining = ringsConfiguration.disperseDuration
        self.cyclesRemaining = ringsConfiguration.spinDisperseCycles
        guard !input.scalars.isEmpty else { phase = .complete; return }
        gap = max(1, PyCompat.roundHalfEven(Double(min(canvas.columns, canvas.rows)) * options.ringGap))
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: coordinates.map(\.row).min()!, maxRow: coordinates.map(\.row).max()!,
            minColumn: coordinates.map(\.column).min()!, maxColumn: coordinates.map(\.column).max()!,
            direction: options.finalGradientDirection)).entries.map { ($0.coordinate, $0.color) })
        glyphs = coordinates.indices.map { .init(symbol: input.scalars[$0], input: coordinates[$0], final: mapping[coordinates[$0]]!,
            coordinate: coordinates[$0], foreground: Self.rgb(mapping[coordinates[$0]]!)) }
        var pending = Array(glyphs.indices)
        rng.shuffle(&pending)
        let center = Coordinate(column: max(1, (canvas.columns + 1) / 2), row: max(1, (canvas.rows + 1) / 2))
        var geometry: [([Coordinate], Double, Color)] = []
        for radius in stride(from: 1, to: max(canvas.columns, canvas.rows), by: gap) {
            let points = Geometry.coordinatesOnCircle(origin: center, radius: radius, limit: 7 * radius)
            let inside = points.filter { (1...canvas.columns).contains($0.column) && (1...canvas.rows).contains($0.row) }.count
            if Double(inside) / Double(points.count) < 0.25 { break }
            let speed = rng.uniform(options.spinSpeed.lowerBound, options.spinSpeed.upperBound)
            geometry.append((points, speed, options.ringColors[geometry.count % options.ringColors.count]))
        }
        for (ringIndex, value) in geometry.enumerated() {
            let (points, speed, color) = value
            let direction = ringIndex.isMultiple(of: 2) ? points : Array(points.reversed())
            var assigned: [Int] = []
            for offset in direction.indices where !pending.isEmpty {
                let id = pending.removeFirst()
                glyphs[id].rotation = Array(direction[offset...]) + Array(direction[..<offset])
                glyphs[id].speed = speed
                glyphs[id].spinScene = (try! Gradient(stops: [glyphs[id].final, color], steps: 8)).spectrum.flatMap { Array(repeating: Self.rgb($0), count: 3) }
                glyphs[id].disperseScene = (try! Gradient(stops: [color, glyphs[id].final], steps: 8)).spectrum.flatMap { Array(repeating: Self.rgb($0), count: 10) }
                assigned.append(id)
            }
            rings.append(assigned)
        }
        for id in glyphs.indices where glyphs[id].rotation.isEmpty { glyphs[id].external = randomOutside() }
    }
    private mutating func move(_ id: Int, kind: MotionKind, targets: [Coordinate], speed: Double, easing: Easing = .linear) {
        glyphs[id].motion = .init(kind: kind, origin: glyphs[id].coordinate, targets: targets, speed: speed, easing: easing)
    }
    private mutating func scene(_ id: Int, spin: Bool) {
        // Rust resumes interrupted scenes and resets only completed playback.
        if let previous = glyphs[id].sceneIsSpin {
            let cursor = glyphs[id].age < glyphs[id].scene.count ? glyphs[id].age : 0
            if previous { glyphs[id].spinAge = cursor } else { glyphs[id].disperseAge = cursor }
        }
        glyphs[id].scene = spin ? glyphs[id].spinScene : glyphs[id].disperseScene
        glyphs[id].age = spin ? glyphs[id].spinAge : glyphs[id].disperseAge
        glyphs[id].sceneIsSpin = spin
        if !glyphs[id].scene.isEmpty { glyphs[id].foreground = glyphs[id].scene[glyphs[id].age] }
    }
    private mutating func disperse(_ id: Int, initial: Bool) {
        let origin = initial ? glyphs[id].rotation[0] : glyphs[id].coordinate
        let choices = Geometry.coordinatesInRectangle(center: origin, distance: gap)
        glyphs[id].disperseTargets = (0..<5).map { _ in choices[rng.integer(in: choices.indices)] }
        if initial {
            move(id, kind: .initialDisperse, targets: [glyphs[id].disperseTargets[0]], speed: 0.3, easing: .outCubic)
        } else {
            if case .ring(let index) = glyphs[id].motion?.kind { glyphs[id].lastRingPath = index }
            else { glyphs[id].lastRingPath = 0 }
            move(id, kind: .disperse, targets: glyphs[id].disperseTargets, speed: 0.14)
        }
        scene(id, spin: false)
    }
    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard phase != .complete else { return .complete }
        switch phase {
        case .start:
            if initialRemaining == 0 { phase = .disperse } else { initialRemaining -= 1 }
        case .disperse:
            if firstDisperse {
                firstDisperse = false
                for group in rings { for id in group { disperse(id, initial: true) } }
                for id in glyphs.indices {
                    if let external = glyphs[id].external { move(id, kind: .external, targets: [external], speed: 0.8, easing: .outSine) }
                }
            } else if disperseRemaining == 0 {
                phase = .spin
                cyclesRemaining -= 1
                spinRemaining = options.spinDuration
                for group in rings {
                    for id in group {
                        move(id, kind: .condense, targets: [glyphs[id].rotation[glyphs[id].lastRingPath]], speed: 0.1)
                        scene(id, spin: true)
                    }
                }
            } else { disperseRemaining -= 1 }
        case .spin:
            if spinRemaining == 0 {
                if cyclesRemaining == 0 {
                    phase = .final
                    for id in glyphs.indices {
                        glyphs[id].visible = true
                        move(id, kind: .home, targets: [glyphs[id].input], speed: 0.8, easing: .outQuad)
                        if glyphs[id].external == nil { scene(id, spin: false) }
                    }
                } else {
                    disperseRemaining = options.disperseDuration
                    for group in rings { for id in group { disperse(id, initial: false) } }
                    phase = .disperse
                }
            } else { spinRemaining -= 1 }
        case .final:
            if !glyphs.contains(where: \.active) { phase = .complete }
        case .complete: break
        }
        for id in glyphs.indices {
            if var motion = glyphs[id].motion {
                glyphs[id].coordinate = motion.advance()
                glyphs[id].motion = motion.complete ? nil : motion
                if motion.complete {
                    switch motion.kind {
                    case .external: glyphs[id].visible = false
                    case .home: break
                    case .initialDisperse, .disperse:
                        move(id, kind: .disperse, targets: glyphs[id].disperseTargets, speed: 0.14)
                    case .condense:
                        let index = glyphs[id].lastRingPath
                        move(id, kind: .ring(index), targets: [glyphs[id].rotation[index]], speed: glyphs[id].speed)
                    case .ring(let index):
                        let next = (index + 1) % glyphs[id].rotation.count
                        move(id, kind: .ring(next), targets: [glyphs[id].rotation[next]], speed: glyphs[id].speed)
                    }
                }
            }
            if glyphs[id].age < glyphs[id].scene.count {
                glyphs[id].foreground = glyphs[id].scene[glyphs[id].age]
                glyphs[id].age += 1
            }
        }
        for glyph in glyphs where glyph.visible {
            if (1...canvas.columns).contains(glyph.coordinate.column), (1...canvas.rows).contains(glyph.coordinate.row) {
                frame[column: glyph.coordinate.column, row: glyph.coordinate.row] = .init(codepoint: glyph.symbol,
                    foreground: glyph.foreground, background: glyph.foreground == 0 ? 0xFFFF_FFFE : 0)
            }
        }
        return phase == .complete ? .complete : .running
    }
    private mutating func randomOutside() -> Coordinate {
        let candidates: [Coordinate] = [
            .init(column: rng.integer(in: 1...canvas.columns), row: canvas.rows + 1),
            .init(column: rng.integer(in: 1...canvas.columns), row: 0),
            .init(column: 0, row: rng.integer(in: 1...canvas.rows)),
            .init(column: canvas.columns + 1, row: rng.integer(in: 1...canvas.rows))]
        return candidates[rng.integer(in: candidates.indices)]
    }
    private static func rgb(_ color: Color) -> UInt32 { UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue) }
}
