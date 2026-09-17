import Foundation
import TTFXCore

public struct BurnEffect: Effect {
    public struct Configuration: Sendable {
        public var startingColor: Color
        public var burnColors: [Color]
        public var smokeChance: Double
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            startingColor: Color = Color(hex: "837373"),
            burnColors: [Color] = [Color(hex: "ffffff"), Color(hex: "fff75d"), Color(hex: "fe650d"), Color(hex: "8A003C"), Color(hex: "510100")],
            smokeChance: Double = 0.5,
            finalGradientStops: [Color] = [Color(hex: "00c3ff"), Color(hex: "ffff1c")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(smokeChance >= 0 && smokeChance <= 1, "smoke chance must be in 0...1")
            self.startingColor = startingColor
            self.burnColors = burnColors
            self.smokeChance = smokeChance
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Visual { let symbol: UInt32; let color: UInt32 }
    private struct Glyph {
        let coordinate: Coordinate
        let symbol: UInt32
        let final: [Visual]
        var visual: Visual
        var age: Int?
        var finishing = false
    }
    private struct Smoke {
        let symbol: UInt32
        var origin = Coordinate(column: 1, row: 1)
        var target = Coordinate(column: 1, row: 1)
        var coordinate = Coordinate(column: 1, row: 1)
        var maxSteps = 0
        var age: Int?
        var color: UInt32 = 0
    }
    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var sourceAt: [Coordinate: Int] = [:]
    private var pending: [Coordinate] = []
    private var burnFrames: [Visual] = []
    private var smokeFrames: [UInt32] = []
    private var smoke: [Smoke] = []
    private var available: [Int] = []
    private var complete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, burnConfiguration: .init())
    }
    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64, burnConfiguration: Configuration) {
        self.canvas = canvas
        self.options = burnConfiguration
        self.rng = .init(seed: seed)
        guard !input.scalars.isEmpty else { complete = true; return }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let left = coordinates.map(\.column).min()!, right = coordinates.map(\.column).max()!
        let bottom = coordinates.map(\.row).min()!, top = coordinates.map(\.row).max()!
        let start = Coordinate(column: rng.integer(in: left...right), row: rng.integer(in: bottom...top))
        let symbols = Array(".,'`#*".unicodeScalars).map(\.value)
        for _ in 0..<2000 { smoke.append(.init(symbol: symbols[rng.integer(in: symbols.indices)])) }
        available = Array(smoke.indices)
        smokeFrames = (try! Gradient(stops: [Color(hex: "504F4F"), Color(hex: "C7C7C7")], steps: 9)).spectrum
            .flatMap { Array(repeating: Self.rgb($0), count: 10) }
        let final = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! final.coordinateColorMapping(minRow: bottom, maxRow: top,
            minColumn: left, maxColumn: right, direction: options.finalGradientDirection)).entries.map { ($0.coordinate, $0.color) })
        let fire = (try! Gradient(stops: options.burnColors, steps: 10)).spectrum
        let fireSymbols = Array("'.▖▙█▜▀▝.".unicodeScalars).map(\.value)
        let count = max(fire.count, fireSymbols.count)
        func distribution(_ index: Int, _ smaller: Int) -> Int {
            let base = count / smaller, remainder = count % smaller
            var boundary = 0
            for candidate in 0..<smaller {
                boundary += base + (candidate < remainder ? 1 : 0)
                if index < boundary { return candidate }
            }
            return smaller - 1
        }
        burnFrames = (0..<count).flatMap { index in
            Array(repeating: Visual(symbol: fireSymbols[distribution(index, fireSymbols.count)],
                color: Self.rgb(fire[distribution(index, fire.count)])), count: 4)
        }
        // Prim's growing-tree order uses all text-rectangle cells, including
        // fill. Fill nodes consume release slots without starting animations.
        var linked = Set<Coordinate>()
        var edges = [start]
        pending = [start]
        func neighbors(_ coordinate: Coordinate) -> [Coordinate] {
            [(0, 1), (1, 0), (0, -1), (-1, 0)].compactMap { dx, dy in
                let next = Coordinate(column: coordinate.column + dx, row: coordinate.row + dy)
                return (left...right).contains(next.column) && (bottom...top).contains(next.row) && !linked.contains(next) ? next : nil
            }
        }
        while !edges.isEmpty {
            let current = edges.remove(at: rng.integer(in: edges.indices))
            var nextOptions = neighbors(current)
            if !nextOptions.isEmpty {
                let next = nextOptions.remove(at: rng.integer(in: nextOptions.indices))
                linked.insert(current); linked.insert(next)
                pending.append(next)
                if !nextOptions.isEmpty { edges.append(current) }
                if !neighbors(next).isEmpty { edges.append(next) }
            }
        }
        for index in input.scalars.indices {
            let coordinate = coordinates[index]
            let timeline = (try! Gradient(stops: [fire.last!, mapping[coordinate]!], steps: 8)).spectrum
                .flatMap { Array(repeating: Visual(symbol: input.scalars[index], color: Self.rgb($0)), count: 4) }
            sourceAt[coordinate] = glyphs.count
            glyphs.append(.init(coordinate: coordinate, symbol: input.scalars[index], final: timeline,
                visual: .init(symbol: input.scalars[index], color: Self.rgb(options.startingColor))))
        }
    }
    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !complete else { return .complete }
        for _ in 0..<rng.integer(in: 2...4) where !pending.isEmpty {
            let coordinate = pending.removeFirst()
            if let index = sourceAt[coordinate] { glyphs[index].age = 0 }
        }
        let activeSmoke = smoke.indices.filter { smoke[$0].age != nil }
        for index in glyphs.indices {
            guard let age = glyphs[index].age else { continue }
            let timeline = glyphs[index].finishing ? glyphs[index].final : burnFrames
            glyphs[index].visual = timeline[age]
            if age + 1 == timeline.count {
                if glyphs[index].finishing { glyphs[index].age = nil }
                else {
                    glyphs[index].finishing = true
                    glyphs[index].age = 0
                    glyphs[index].visual = glyphs[index].final[0]
                    if rng.random() <= options.smokeChance, let id = available.popLast() {
                        let origin = glyphs[index].coordinate
                        let target = Coordinate(column: rng.integer(in: (origin.column - 4)...(origin.column + 4)), row: canvas.rows + 1)
                        smoke[id].origin = origin
                        smoke[id].coordinate = origin
                        smoke[id].target = target
                        smoke[id].maxSteps = PyCompat.roundHalfEven(Geometry.lineLength(from: origin, to: target) / 0.5)
                        smoke[id].age = 0
                        smoke[id].color = smokeFrames[0]
                    }
                }
            } else { glyphs[index].age = age + 1 }
        }
        for id in activeSmoke {
            let age = smoke[id].age!
            let ratio = smoke[id].maxSteps == 0 ? 1 : min(1, Double(age + 1) / Double(smoke[id].maxSteps))
            let distance = Geometry.lineLength(from: smoke[id].origin, to: smoke[id].target)
            smoke[id].coordinate = Geometry.coordinateOnLine(from: smoke[id].origin, to: smoke[id].target,
                t: distance == 0 ? 1 : (ratio * distance) / distance)
            smoke[id].color = smokeFrames[age]
            if age + 1 == smokeFrames.count { smoke[id].age = nil; available.append(id) }
            else { smoke[id].age = age + 1 }
        }
        for glyph in glyphs {
            frame[column: glyph.coordinate.column, row: glyph.coordinate.row] = .init(codepoint: glyph.visual.symbol,
                foreground: glyph.visual.color, background: glyph.visual.color == 0 ? 0xFFFF_FFFE : 0)
        }
        for particle in smoke where particle.age != nil {
            let coordinate = particle.coordinate
            if (1...canvas.columns).contains(coordinate.column), (1...canvas.rows).contains(coordinate.row) {
                frame[column: coordinate.column, row: coordinate.row] = .init(codepoint: particle.symbol, foreground: particle.color, background: 0)
            }
        }
        complete = pending.isEmpty && !glyphs.contains { $0.age != nil } && !smoke.contains { $0.age != nil }
        return complete ? .complete : .running
    }
    private static func rgb(_ color: Color) -> UInt32 { UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue) }
}
