import Foundation
import TTFXCore

public struct BlackholeEffect: Effect {
    public struct Configuration: Sendable {
        public var blackholeColor: Color
        public var starColors: [Color]
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            blackholeColor: Color = Color(hex: "ffffff"),
            starColors: [Color] = [
                Color(hex: "ffcc0d"), Color(hex: "ff7326"), Color(hex: "ff194d"),
                Color(hex: "bf2669"), Color(hex: "702a8c"), Color(hex: "049dbf")
            ],
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "ffffff")],
            finalGradientSteps: [Int] = [9],
            finalGradientDirection: GradientDirection = .diagonal
        ) {
            precondition(!starColors.isEmpty, "star colors must not be empty")
            self.blackholeColor = blackholeColor
            self.starColors = starColors
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Phase { case forming, consuming, collapsing, exploding, complete }
    private enum Kind { case formation, rotation, consume, expand, collapse, nearby, home }
    private struct Motion {
        let kind: Kind
        let points: [Coordinate]
        let distances: [Double]
        let total: Double
        let steps: Int
        let easing: Easing
        var step = 0
        var reached = 0.0
        init(kind: Kind, origin: Coordinate, targets: [Coordinate], speed: Double, easing: Easing = .linear) {
            self.kind = kind; self.points = [origin] + targets
            self.distances = zip(points, points.dropFirst()).map { Geometry.lineLength(from: $0, to: $1) }
            self.total = distances.reduce(0, +); self.steps = PyCompat.roundHalfEven(total / speed); self.easing = easing
        }
        mutating func advance() -> Coordinate {
            guard steps > 0, total > 0 else { return points.last! }
            step += 1
            reached = easing.value(at: Double(step) / Double(steps)) * total
            var remaining = reached
            for index in distances.indices {
                if remaining <= distances[index] {
                    return Geometry.coordinateOnLine(from: points[index], to: points[index + 1],
                        t: distances[index] == 0 ? 0 : remaining / distances[index])
                }
                remaining -= distances[index]
            }
            return points.last!
        }
        var complete: Bool { step >= steps || total == 0 }
    }
    private struct Glyph {
        let source: Coordinate
        let symbol: UInt32
        let final: Color
        var coordinate: Coordinate
        var visual: Cell
        var layer = 0
        var motion: Motion?
        var scene: [Cell] = []
        var age = 0
        var consumed: [Cell] = []
        var cooling: [Cell] = []
        var speed = 0.0
        var homeSpeed = 0.0
        var rotation: [Coordinate] = []
        var active: Bool { motion != nil || age < scene.count }
    }
    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var ring: [Int] = []
    private var pendingRing: [Int] = []
    private var pendingConsume: [Int] = []
    private var phase = Phase.forming
    private var radius = 3
    private var formationDelay = 0
    private var delay = 0
    private var pointScene: [Cell] = []
    private var center: Coordinate { .init(column: max(1, (canvas.columns + 1) / 2), row: max(1, (canvas.rows + 1) / 2)) }

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, blackholeConfiguration: .init())
    }
    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64, blackholeConfiguration: Configuration) {
        self.canvas = canvas; self.options = blackholeConfiguration; self.rng = configuration.makeRNG(seed: seed)
        guard !input.scalars.isEmpty else { phase = .complete; return }
        radius = max(min(PyCompat.roundHalfEven(Double(canvas.columns) * 0.3), PyCompat.roundHalfEven(Double(canvas.rows) * 0.2)), 3)
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: coordinates.map(\.row).min()!, maxRow: coordinates.map(\.row).max()!,
            minColumn: coordinates.map(\.column).min()!, maxColumn: coordinates.map(\.column).max()!,
            direction: options.finalGradientDirection)).entries.map { ($0.coordinate, $0.color) })
        glyphs = coordinates.indices.map { .init(source: coordinates[$0], symbol: input.scalars[$0], final: mapping[coordinates[$0]]!,
            coordinate: coordinates[$0], visual: .blank) }
        var available = Array(glyphs.indices)
        while ring.count < radius * 3 && !available.isEmpty { ring.append(available.remove(at: rng.integer(in: available.indices))) }
        let positions = Geometry.coordinatesOnCircle(origin: center, radius: radius, limit: ring.count)
        for (index, id) in ring.enumerated() { glyphs[id].rotation = Array(positions[index...]) + Array(positions[..<index]) }
        let symbols = "*'`¤•°·".unicodeScalars.map(\.value)
        let colors = (try! Gradient(stops: [Color(hex: "4a4a4d"), Color(hex: "ffffff")], steps: 6)).spectrum
        for id in glyphs.indices {
            let symbol = symbols[rng.integer(in: symbols.indices)]
            let color = colors[rng.integer(in: colors.indices)]
            glyphs[id].visual = Self.cell(symbol, color)
            if !ring.contains(id) {
                glyphs[id].coordinate = .init(column: rng.integer(in: 1...canvas.columns), row: rng.integer(in: 1...canvas.rows))
                glyphs[id].speed = rng.uniform(0.17, 0.30)
                glyphs[id].consumed = (try! Gradient(stops: [color, Color(hex: "000000")], steps: 10)).spectrum.map { Self.cell(symbol, $0) } + [.blank]
                pendingConsume.append(id)
            }
        }
        rng.shuffle(&pendingConsume)
        pendingRing = ring
        formationDelay = max(100 / ring.count, 6); delay = formationDelay
    }
    private mutating func move(_ id: Int, _ kind: Kind, _ targets: [Coordinate], _ speed: Double, _ easing: Easing = .linear) {
        glyphs[id].motion = .init(kind: kind, origin: glyphs[id].coordinate, targets: targets, speed: speed, easing: easing)
    }
    private mutating func scene(_ id: Int, _ frames: [Cell]) {
        glyphs[id].scene = frames; glyphs[id].age = 0
        if let first = frames.first { glyphs[id].visual = first }
    }
    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard phase != .complete || glyphs.contains(where: \.active) else { return .complete }
        switch phase {
        case .forming:
            if !pendingRing.isEmpty {
                if delay == 0 {
                    let id = pendingRing.removeFirst()
                    move(id, .formation, [glyphs[id].rotation[0]], 0.7, .inOutSine)
                    glyphs[id].layer = 1
                    scene(id, [Self.cell(42, options.blackholeColor)])
                    delay = formationDelay
                } else { delay -= 1 }
            } else if !glyphs.contains(where: \.active) {
                for id in ring { move(id, .rotation, glyphs[id].rotation, 0.45) }
                phase = .consuming
            }
        case .consuming:
            if !pendingConsume.isEmpty {
                for id in pendingConsume {
                    move(id, .consume, [center], glyphs[id].speed, .inExpo)
                    glyphs[id].layer = 2
                }
                pendingConsume.removeAll()
            } else if glyphs.indices.allSatisfy({ !glyphs[$0].active || ring.contains($0) }) { phase = .collapsing }
        case .collapsing:
            let positions = Geometry.coordinatesOnCircle(origin: center, radius: radius + 3, limit: ring.count)
            for (index, id) in ring.enumerated() {
                if index == 0 {
                    for _ in 0..<3 { for symbol in "◦◎◉●◉◎◦".unicodeScalars {
                        let color = options.starColors[rng.integer(in: options.starColors.indices)]
                        pointScene += Array(repeating: Self.cell(symbol.value, color), count: 3)
                    } }
                }
                move(id, .expand, [positions[index]], 0.2, .inExpo)
            }
            phase = .exploding
        case .exploding:
            if ring.allSatisfy({ !glyphs[$0].active }) {
                let colors = ["ffcc0d", "ff7326", "ff194d", "bf2669", "702a8c", "049dbf"].map { Color(hex: $0) }
                for id in glyphs.indices {
                    let nearby = Geometry.coordinatesOnCircle(origin: glyphs[id].source, radius: 3, limit: 5)[rng.integer(in: 0...4)]
                    let speed = Double(rng.integer(in: 3...4)) / 10
                    glyphs[id].homeSpeed = Double(rng.integer(in: 4...6)) / 100
                    let color = colors[rng.integer(in: colors.indices)]
                    glyphs[id].cooling = (try! Gradient(stops: [color, glyphs[id].final], steps: 10)).spectrum.flatMap {
                        Array(repeating: Self.cell(glyphs[id].symbol, $0), count: 20)
                    }
                    scene(id, [Self.cell(glyphs[id].symbol, color)])
                    move(id, .nearby, [nearby], speed, .outExpo)
                }
                phase = .complete
            }
        case .complete: break
        }
        for id in glyphs.indices {
            if var motion = glyphs[id].motion {
                glyphs[id].coordinate = motion.advance()
                glyphs[id].motion = motion.complete ? nil : motion
                if motion.kind == .consume {
                    if motion.complete { glyphs[id].visual = .blank }
                    else {
                        let progress = max(max(motion.total, 1) - max(motion.total - motion.reached, 1), 1) / max(motion.total, 1)
                        let index = min(glyphs[id].consumed.count - 1, max(0, PyCompat.roundHalfEven(Double(glyphs[id].consumed.count - 1) * progress)))
                        glyphs[id].visual = glyphs[id].consumed[index]
                    }
                }
                if motion.complete {
                    switch motion.kind {
                    case .rotation: move(id, .rotation, glyphs[id].rotation, 0.45)
                    case .expand: move(id, .collapse, [center], 0.3, .inExpo)
                    case .collapse:
                        if id == ring.first { scene(id, pointScene); glyphs[id].layer = 3 }
                    case .nearby:
                        move(id, .home, [glyphs[id].source], glyphs[id].homeSpeed, .inCubic)
                        scene(id, glyphs[id].cooling)
                    default: break
                    }
                }
            }
            if glyphs[id].age < glyphs[id].scene.count {
                glyphs[id].visual = glyphs[id].scene[glyphs[id].age]; glyphs[id].age += 1
            }
        }
        let ordered = glyphs.indices.sorted { glyphs[$0].layer == glyphs[$1].layer ? $0 < $1 : glyphs[$0].layer < glyphs[$1].layer }
        for id in ordered {
            let glyph = glyphs[id]
            if (1...canvas.columns).contains(glyph.coordinate.column), (1...canvas.rows).contains(glyph.coordinate.row) {
                frame[column: glyph.coordinate.column, row: glyph.coordinate.row] = glyph.visual
            }
        }
        return phase == .complete && !glyphs.contains(where: \.active) ? .complete : .running
    }
    private static func cell(_ symbol: UInt32, _ color: Color) -> Cell {
        let rgb = UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
        return .init(codepoint: symbol, foreground: rgb, background: rgb == 0 ? 0xFFFF_FFFE : 0)
    }
}
