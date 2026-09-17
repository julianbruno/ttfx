import Foundation
import TTFXCore

public struct BinaryPathEffect: Effect {
    public struct Configuration: Sendable {
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection
        public var binaryColors: [Color]
        public var movementSpeed: Double
        public var activeBinaryGroups: Double

        public init(
            finalGradientStops: [Color] = [Color(hex: "00d500"), Color(hex: "007500")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .radial,
            binaryColors: [Color] = [Color(hex: "044E29"), Color(hex: "157e38"), Color(hex: "45bf55"), Color(hex: "95ed87")],
            movementSpeed: Double = 1.0,
            activeBinaryGroups: Double = 0.08
        ) {
            precondition(!finalGradientStops.isEmpty, "final gradient stops must not be empty")
            precondition(!binaryColors.isEmpty, "binary colors must not be empty")
            precondition(movementSpeed > 0, "movement speed must be positive")
            precondition(activeBinaryGroups >= 0, "active binary groups must be non-negative")
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
            self.binaryColors = binaryColors
            self.movementSpeed = movementSpeed
            self.activeBinaryGroups = activeBinaryGroups
        }
    }

    private struct Bit {
        let symbol: UInt32
        let color: UInt32
        let points: [Coordinate]
        let distances: [Double]
        let total: Double
        let maxSteps: Int
        var coordinate: Coordinate
        var step = 0
        var released = false
        var visible = false
        var moving = true

        mutating func tick() {
            guard released && moving else { return }
            if maxSteps == 0 || total == 0 {
                coordinate = points.last!
                moving = false
                return
            }
            step += 1
            var distance = Double(step) / Double(maxSteps) * total
            for index in distances.indices {
                if distance <= distances[index] {
                    coordinate = distances[index] == 0 ? points[index] : Geometry.coordinateOnLine(
                        from: points[index], to: points[index + 1], t: distance / distances[index])
                    break
                }
                distance -= distances[index]
                if index == distances.count - 1 { coordinate = points.last! }
            }
            if step >= maxSteps { moving = false }
        }
    }

    private struct Representation {
        let coordinate: Coordinate
        let symbol: UInt32
        let collapse: [UInt32]
        let brighten: [UInt32]
        var bits: [Bit]
        var released = 0
        var visible = false
        var scene: [UInt32] = []
        var sceneStep = 0
        var eased = false
        var foreground: UInt32 = 0
        var active: Bool { sceneStep < scene.count || bits.contains { $0.released && $0.moving } }

        mutating func activate(brightening: Bool) {
            visible = true
            scene = brightening ? brighten : collapse
            eased = !brightening
            sceneStep = 0
            foreground = scene[0]
        }

        mutating func tick() {
            for index in bits.indices { bits[index].tick() }
            if sceneStep < scene.count {
                let index = eased
                    ? PyCompat.roundHalfEven(pow(Double(sceneStep) / Double(scene.count), 2) * Double(scene.count - 1))
                    : sceneStep
                foreground = scene[index]
                sceneStep += 1
            }
        }
    }

    private let canvas: Canvas
    private var rng: Xoshiro256PlusPlus
    private var representations: [Representation] = []
    private var pending: [Int] = []
    private var active: [Int] = []
    private var wipeGroups: [[Int]] = []
    private var wiping = false
    private var wipeFinished = false
    private var complete = false
    private var maxActive = 1

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, binaryPathConfiguration: .init())
    }

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64,
                binaryPathConfiguration options: Configuration) {
        self.canvas = canvas
        self.rng = .init(seed: seed)
        guard !input.scalars.isEmpty else { complete = true; return }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: coordinates.map(\.row).min()!, maxRow: coordinates.map(\.row).max()!,
            minColumn: coordinates.map(\.column).min()!, maxColumn: coordinates.map(\.column).max()!,
            direction: options.finalGradientDirection)).entries.map { ($0.coordinate, $0.color) })
        for index in input.scalars.indices {
            let target = coordinates[index]
            let start = randomOutside()
            var points = [start]
            var columnOrientation = rng.integer(in: 0...1) == 0
            while points.last! != target {
                let last = points.last!
                let columnDistance = abs(last.column - target.column)
                let rowDistance = abs(last.row - target.row)
                let next: Coordinate
                if columnOrientation && rowDistance > 0 {
                    let step = rng.integer(in: 1...min(rowDistance, max(10, Int(Double(canvas.columns) * 0.2))))
                    next = .init(column: last.column, row: last.row + (last.row > target.row ? -step : step))
                    columnOrientation = false
                } else if !columnOrientation && columnDistance > 0 {
                    let step = rng.integer(in: 1...min(columnDistance, 4))
                    next = .init(column: last.column + (last.column > target.column ? -step : step), row: last.row)
                    columnOrientation = true
                } else { next = target }
                points.append(next)
            }
            points += [target, target]
            let distances = zip(points, points.dropFirst()).map { Geometry.lineLength(from: $0, to: $1) }
            let total = distances.reduce(0, +)
            let string = String(input.scalars[index], radix: 2)
            let binary = String(repeating: "0", count: max(0, 8 - string.count)) + string
            let bits = binary.unicodeScalars.map { symbol in
                Bit(symbol: symbol.value, color: Self.rgb(options.binaryColors[rng.integer(in: options.binaryColors.indices)]),
                    points: points, distances: distances, total: total,
                    maxSteps: PyCompat.roundHalfEven(total / options.movementSpeed), coordinate: start)
            }
            let final = mapping[target]!
            let dim = rustAdjustedBrightness(final, factor: 0.5)
            let collapse = (try! Gradient(stops: [Color(hex: "ffffff"), dim], steps: 7)).spectrum
                .flatMap { Array(repeating: Self.rgb($0), count: 3) }
            let brighten = (try! Gradient(stops: [dim, final], steps: 10)).spectrum
                .flatMap { Array(repeating: Self.rgb($0), count: 2) }
            representations.append(.init(coordinate: target, symbol: input.scalars[index],
                collapse: collapse, brighten: brighten, bits: bits))
        }
        pending = Array(representations.indices)
        maxActive = max(1, Int(Double(pending.count) * options.activeBinaryGroups))
        let grouped = Dictionary(grouping: representations.indices) {
            representations[$0].coordinate.column + representations[$0].coordinate.row
        }
        wipeGroups = grouped.keys.sorted(by: >).map { grouped[$0]! }
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !complete else { return .complete }
        // Rust emits a final held frame after its last active animation tick.
        if wipeFinished && !representations.contains(where: \.active) {
            render(into: &frame)
            complete = true
            return .complete
        }
        if !wiping {
            while active.count < maxActive && !pending.isEmpty {
                active.append(pending.remove(at: rng.integer(in: pending.indices)))
            }
            var finished: Set<Int> = []
            for index in active {
                if representations[index].released < representations[index].bits.count {
                    let bit = representations[index].released
                    representations[index].bits[bit].released = true
                    representations[index].bits[bit].visible = true
                    representations[index].released += 1
                } else if representations[index].bits.allSatisfy({ $0.coordinate == representations[index].coordinate }) {
                    for bit in representations[index].bits.indices { representations[index].bits[bit].visible = false }
                    representations[index].activate(brightening: false)
                    finished.insert(index)
                }
            }
            active.removeAll { finished.contains($0) }
            if !representations.contains(where: \.active) { wiping = true }
        }
        if wiping {
            for _ in 0..<2 {
                if wipeGroups.isEmpty { wipeFinished = true }
                else {
                    for index in wipeGroups.removeFirst() { representations[index].activate(brightening: true) }
                }
            }
        }
        for index in representations.indices { representations[index].tick() }
        render(into: &frame)
        return .running
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

    private func render(into frame: inout Frame) {
        func put(_ symbol: UInt32, _ color: UInt32, _ coordinate: Coordinate) {
            guard (1...canvas.columns).contains(coordinate.column), (1...canvas.rows).contains(coordinate.row) else { return }
            frame[column: coordinate.column, row: coordinate.row] = .init(codepoint: symbol,
                foreground: color, background: color == 0 ? 0xFFFF_FFFE : 0)
        }
        for source in representations where source.visible { put(source.symbol, source.foreground, source.coordinate) }
        for source in representations {
            for bit in source.bits where bit.visible { put(bit.symbol, bit.color, bit.coordinate) }
        }
    }

    private static func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
