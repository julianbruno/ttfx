import Foundation
import TTFXCore

public struct SpotlightsEffect: Effect {
    public struct Configuration: Sendable {
        public var beamWidthRatio: Double
        public var beamFalloff: Double
        public var searchDuration: Int
        public var searchSpeedRange: ClosedRange<Double>
        public var spotlightCount: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            beamWidthRatio: Double = 2.0,
            beamFalloff: Double = 0.3,
            searchDuration: Int = 550,
            searchSpeedRange: ClosedRange<Double> = 0.35...0.75,
            spotlightCount: Int = 3,
            finalGradientStops: [Color] = [Color(hex: "ab48ff"), Color(hex: "e7b2b2"), Color(hex: "fffebd")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(beamWidthRatio > 0, "beam width ratio must be positive")
            precondition(beamFalloff >= 0, "beam falloff must be non-negative")
            precondition(searchDuration > 0, "search duration must be positive")
            precondition(searchSpeedRange.lowerBound > 0 && searchSpeedRange.upperBound > 0, "search speed must be positive")
            precondition(spotlightCount > 0, "spotlight count must be positive")
            precondition(!finalGradientStops.isEmpty, "final gradient stops must not be empty")
            self.beamWidthRatio = beamWidthRatio
            self.beamFalloff = beamFalloff
            self.searchDuration = searchDuration
            self.searchSpeedRange = searchSpeedRange
            self.spotlightCount = spotlightCount
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph { let symbol: UInt32; let coordinate: Coordinate; let bright: Color; let dark: Color }
    private struct SearchPath { let target: Coordinate; let control: Coordinate; let speed: Double }
    private struct Spotlight {
        let paths: [SearchPath]
        var coordinate: Coordinate
        var origin: Coordinate
        var pathIndex = 0
        var step = 0
        var maxSteps = 0
        var returning = false
        var active = true
    }
    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var spotlights: [Spotlight] = []
    private var range = 1
    private var remaining = 0
    private var searching = true
    private var complete = false
    private var center: Coordinate {
        .init(column: max(1, (canvas.columns + 1) / 2), row: max(1, (canvas.rows + 1) / 2))
    }
    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, spotlightsConfiguration: .init())
    }
    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64,
                spotlightsConfiguration: Configuration) {
        self.canvas = canvas
        self.options = spotlightsConfiguration
        self.rng = configuration.makeRNG(seed: seed)
        self.remaining = spotlightsConfiguration.searchDuration
        guard !input.scalars.isEmpty else { complete = true; return }
        for _ in 0..<options.spotlightCount {
            let spawn = randomOutside()
            var targets = [randomInside()]
            for _ in 0..<10 {
                var target = randomInside()
                while Geometry.lineLength(from: targets.last!, to: target, doubleRowDifference: false) < Double(canvas.columns / 4) {
                    target = randomInside()
                }
                targets.append(target)
            }
            var paths: [SearchPath] = []
            for target in targets {
                let speed = rng.uniform(options.searchSpeedRange.lowerBound, options.searchSpeedRange.upperBound)
                paths.append(.init(target: target, control: randomOutside(), speed: speed))
            }
            let steps = PyCompat.roundHalfEven(Geometry.bezierLength(from: spawn, controls: [paths[0].control], to: paths[0].target) / paths[0].speed)
            spotlights.append(.init(paths: paths, coordinate: spawn, origin: spawn, maxSteps: steps))
        }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: coordinates.map(\.row).min()!, maxRow: coordinates.map(\.row).max()!,
            minColumn: coordinates.map(\.column).min()!, maxColumn: coordinates.map(\.column).max()!,
            direction: options.finalGradientDirection)).entries.map { ($0.coordinate, $0.color) })
        glyphs = coordinates.indices.map {
            let bright = mapping[coordinates[$0]]!
            return .init(symbol: input.scalars[$0], coordinate: coordinates[$0], bright: bright, dark: rustAdjustedBrightness(bright, factor: 0.2))
        }
        let smallest = min(canvas.columns, canvas.rows)
        range = max(1, min(Int(floor(Double(smallest) / options.beamWidthRatio)), smallest))
    }
    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !complete else { return .complete }
        var lit = Set<Coordinate>()
        for light in spotlights { lit.formUnion(Geometry.coordinatesInEllipse(center: light.coordinate, diameter: range)) }
        for glyph in glyphs {
            var color = glyph.dark
            if lit.contains(glyph.coordinate) {
                let distance = spotlights.map { Geometry.lineLength(from: $0.coordinate, to: glyph.coordinate) }.min() ?? .infinity
                let threshold = Double(range) * (1 - options.beamFalloff)
                color = distance > threshold
                    ? rustAdjustedBrightness(glyph.bright, factor: max(0.2, 1 - (distance - threshold) / (Double(range) * options.beamFalloff)))
                    : glyph.bright
            }
            let word = Self.rgb(color)
            frame[column: glyph.coordinate.column, row: glyph.coordinate.row] = .init(codepoint: glyph.symbol,
                foreground: word, background: word == 0 ? 0xFFFF_FFFE : 0)
        }
        if searching {
            remaining -= 1
            if remaining == 0 {
                searching = false
                for index in spotlights.indices {
                    spotlights[index].returning = true
                    spotlights[index].origin = spotlights[index].coordinate
                    spotlights[index].step = 0
                    spotlights[index].maxSteps = PyCompat.roundHalfEven(Geometry.lineLength(from: spotlights[index].coordinate, to: center) / 0.5)
                }
            }
        }
        if !spotlights.contains(where: \.active) {
            if spotlights.count > 1 { spotlights.removeLast(spotlights.count - 1) }
            range += 1
            if Double(range) > floor(Double(max(canvas.columns, canvas.rows)) / 1.5) { complete = true }
        }
        for index in spotlights.indices where spotlights[index].active {
            spotlights[index].step += 1
            let light = spotlights[index]
            let ratio = light.maxSteps == 0 ? 1 : min(1, Double(light.step) / Double(light.maxSteps))
            if light.returning {
                spotlights[index].coordinate = Geometry.coordinateOnLine(from: light.origin, to: center, t: Easing.inOutSine.value(at: ratio))
                if ratio == 1 { spotlights[index].active = false }
            } else {
                let path = light.paths[light.pathIndex]
                spotlights[index].coordinate = Geometry.coordinateOnBezier(from: light.origin, controls: [path.control], to: path.target,
                    t: Easing.inOutQuad.value(at: ratio))
                if ratio == 1 {
                    let next = (light.pathIndex + 1) % light.paths.count
                    let nextPath = light.paths[next]
                    spotlights[index].pathIndex = next
                    spotlights[index].origin = spotlights[index].coordinate
                    spotlights[index].step = 0
                    spotlights[index].maxSteps = PyCompat.roundHalfEven(Geometry.bezierLength(from: spotlights[index].coordinate,
                        controls: [nextPath.control], to: nextPath.target) / nextPath.speed)
                }
            }
        }
        return complete ? .complete : .running
    }
    private mutating func randomInside() -> Coordinate {
        .init(column: rng.integer(in: 1...canvas.columns), row: rng.integer(in: 1...canvas.rows))
    }
    private mutating func randomOutside() -> Coordinate {
        let candidates: [Coordinate] = [
            .init(column: rng.integer(in: 1...canvas.columns), row: canvas.rows + 1),
            .init(column: rng.integer(in: 1...canvas.columns), row: 0),
            .init(column: 0, row: rng.integer(in: 1...canvas.rows)),
            .init(column: canvas.columns + 1, row: rng.integer(in: 1...canvas.rows)),
        ]
        return candidates[rng.integer(in: candidates.indices)]
    }
    private static func rgb(_ color: Color) -> UInt32 { UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue) }
}
