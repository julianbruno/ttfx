import Foundation
import TTFXCore

public struct ErrorCorrectEffect: Effect {
    public struct Configuration: Sendable {
        public var errorPairs: Double
        public var swapDelay: Int
        public var errorColor: Color
        public var correctColor: Color
        public var movementSpeed: Double
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            errorPairs: Double = 0.1,
            swapDelay: Int = 6,
            errorColor: Color = Color(hex: "e74c3c"),
            correctColor: Color = Color(hex: "45bf55"),
            movementSpeed: Double = 0.9,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(errorPairs > 0, "error pairs must be positive")
            precondition(swapDelay >= 1, "swap delay must be positive")
            precondition(movementSpeed > 0, "movement speed must be positive")
            self.errorPairs = errorPairs
            self.swapDelay = swapDelay
            self.errorColor = errorColor
            self.correctColor = correctColor
            self.movementSpeed = movementSpeed
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Stage { case idle, error, wipeStart, correcting, wipeEnd, final, done }
    private struct Visual { let symbol: UInt32; let color: UInt32 }
    private struct Glyph {
        let input: Coordinate
        let symbol: UInt32
        let finalColor: UInt32
        let correction: [UInt32]
        let final: [Visual]
        var coordinate: Coordinate
        var origin: Coordinate
        var visual: Visual
        var stage = Stage.idle
        var timeline: [Visual] = []
        var age = 0
        var motionStep = 0
        var motionSteps = 0
        var totalDistance = 0.0
        var layer = 0
        var active: Bool { stage != .idle && stage != .done }
    }
    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var pairs: [[Int]] = []
    private var delay = 0
    private var complete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, errorCorrectConfiguration: .init())
    }
    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64,
                errorCorrectConfiguration: Configuration) {
        self.canvas = canvas
        self.options = errorCorrectConfiguration
        guard !input.scalars.isEmpty else { complete = true; return }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: coordinates.map(\.row).min()!, maxRow: coordinates.map(\.row).max()!,
            minColumn: coordinates.map(\.column).min()!, maxColumn: coordinates.map(\.column).max()!,
            direction: options.finalGradientDirection)).entries.map { ($0.coordinate, $0.color) })
        let correction = (try! Gradient(stops: [options.errorColor, options.correctColor], steps: 10)).spectrum.map(Self.rgb)
        glyphs = coordinates.indices.map { index in
            let color = mapping[coordinates[index]]!
            let final = (try! Gradient(stops: [options.correctColor, color], steps: 10)).spectrum
                .flatMap { Array(repeating: Visual(symbol: input.scalars[index], color: Self.rgb($0)), count: 3) }
            return Glyph(input: coordinates[index], symbol: input.scalars[index], finalColor: Self.rgb(color),
                correction: correction, final: final, coordinate: coordinates[index], origin: coordinates[index],
                visual: .init(symbol: input.scalars[index], color: Self.rgb(color)))
        }
        var rng = configuration.makeRNG(seed: seed)
        var remaining = Array(glyphs.indices)
        for _ in 0..<min(Int(options.errorPairs * Double(remaining.count)), remaining.count / 2) {
            let first = remaining.remove(at: rng.integer(in: remaining.indices))
            let second = remaining.remove(at: rng.integer(in: remaining.indices))
            glyphs[first].coordinate = glyphs[second].input
            glyphs[second].coordinate = glyphs[first].input
            for index in [first, second] { glyphs[index].visual = .init(symbol: glyphs[index].symbol, color: Self.rgb(options.errorColor)) }
            pairs.append([first, second])
        }
    }

    private mutating func activate(_ index: Int, _ stage: Stage) {
        glyphs[index].stage = stage
        glyphs[index].age = 0
        let error = Self.rgb(options.errorColor)
        let correct = Self.rgb(options.correctColor)
        switch stage {
        case .error:
            let pair = Array(repeating: Visual(symbol: 0x2593, color: error), count: 3)
                + Array(repeating: Visual(symbol: glyphs[index].symbol, color: 0xffffff), count: 3)
            glyphs[index].timeline = Array(repeating: pair, count: 10).flatMap { $0 }
        case .wipeStart:
            glyphs[index].timeline = "▁▂▃▄▅▆▇█".unicodeScalars.flatMap { Array(repeating: Visual(symbol: $0.value, color: error), count: 3) }
        case .correcting:
            glyphs[index].origin = glyphs[index].coordinate
            glyphs[index].totalDistance = Geometry.lineLength(from: glyphs[index].origin, to: glyphs[index].input)
            glyphs[index].motionSteps = PyCompat.roundHalfEven(glyphs[index].totalDistance / options.movementSpeed)
            glyphs[index].motionStep = 0
            glyphs[index].layer = 1
            glyphs[index].timeline = [.init(symbol: 0x2588, color: error)]
        case .wipeEnd:
            glyphs[index].layer = 0
            glyphs[index].timeline = "▇▆▅▄▃▂▁".unicodeScalars.flatMap { Array(repeating: Visual(symbol: $0.value, color: correct), count: 3) }
        case .final: glyphs[index].timeline = glyphs[index].final
        case .idle, .done: return
        }
        glyphs[index].visual = glyphs[index].timeline[0]
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !complete else { return .complete }
        if !pairs.isEmpty && delay == 0 {
            for index in pairs.removeFirst() { activate(index, .error) }
            delay = options.swapDelay
        } else { delay -= 1 }
        for index in glyphs.indices where glyphs[index].active {
            if glyphs[index].stage == .correcting {
                glyphs[index].motionStep += 1
                let ratio = glyphs[index].motionSteps == 0 ? 1 : min(1, Double(glyphs[index].motionStep) / Double(glyphs[index].motionSteps))
                glyphs[index].coordinate = Geometry.coordinateOnLine(from: glyphs[index].origin, to: glyphs[index].input, t: ratio)
                if ratio == 1 { activate(index, .wipeEnd) }
                else {
                    let total = max(glyphs[index].totalDistance, 1)
                    let progress = max(total - max(glyphs[index].totalDistance * (1 - ratio), 1), 1) / total
                    let color = glyphs[index].correction[min(10, max(0, PyCompat.roundHalfEven(progress * 10)))]
                    glyphs[index].visual = .init(symbol: 0x2588, color: color)
                }
            }
            if glyphs[index].stage != .correcting {
                glyphs[index].visual = glyphs[index].timeline[glyphs[index].age]
                glyphs[index].age += 1
                if glyphs[index].age == glyphs[index].timeline.count {
                    switch glyphs[index].stage {
                    case .error: activate(index, .wipeStart)
                    case .wipeStart: activate(index, .correcting)
                    case .wipeEnd: activate(index, .final)
                    case .final: glyphs[index].stage = .done
                    default: break
                    }
                }
            }
        }
        for index in glyphs.indices.sorted(by: { (glyphs[$0].layer, $0) < (glyphs[$1].layer, $1) }) {
            let glyph = glyphs[index]
            frame[column: glyph.coordinate.column, row: glyph.coordinate.row] = .init(codepoint: glyph.visual.symbol,
                foreground: glyph.visual.color, background: glyph.visual.color == 0 ? 0xFFFF_FFFE : 0)
        }
        complete = pairs.isEmpty && !glyphs.contains(where: \.active)
        return complete ? .complete : .running
    }
    private static func rgb(_ color: Color) -> UInt32 { UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue) }
}
