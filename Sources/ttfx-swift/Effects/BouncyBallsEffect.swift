import TTFXCore

public struct BouncyBallsEffect: Effect {
    public struct Configuration: Sendable {
        public var ballColors: [Color]
        public var ballSymbols: [String]
        public var ballDelay: Int
        public var movementSpeed: Double
        public var movementEasing: Easing
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            ballColors: [Color] = [Color(hex: "d1f4a5"), Color(hex: "96e2a4"), Color(hex: "5acda9")],
            ballSymbols: [String] = ["*", "o", "O", "0", "."],
            ballDelay: Int = 4,
            movementSpeed: Double = 0.45,
            movementEasing: Easing = .outBounce,
            finalGradientStops: [Color] = [Color(hex: "f8ffae"), Color(hex: "43c6ac")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .diagonal
        ) {
            precondition(!ballColors.isEmpty, "ball colors must not be empty")
            precondition(!ballSymbols.isEmpty, "ball symbols must not be empty")
            precondition(ballDelay >= 0, "ball delay must not be negative")
            precondition(movementSpeed > 0, "movement speed must be positive")
            self.ballColors = ballColors
            self.ballSymbols = ballSymbols
            self.ballDelay = ballDelay
            self.movementSpeed = movementSpeed
            self.movementEasing = movementEasing
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum ScenePhase {
        case ball
        case final(index: Int, ticksElapsed: Int)
        case done
    }

    private struct Glyph {
        let characterID: Int
        let inputCoordinate: Coordinate
        let inputSymbol: UInt32
        let ballSymbol: UInt32
        let ballColor: UInt32
        let finalColors: [UInt32]
        let origin: Coordinate
        let totalDistance: Double
        let pathSteps: Int
        var coordinate: Coordinate
        var pathStep = 0
        var pathActive = true
        var visible = false
        var scene: ScenePhase = .ball

        var isActive: Bool {
            pathActive || {
                switch scene {
                case .ball, .final: return true
                case .done: return false
                }
            }()
        }

        var visual: (symbol: UInt32, foreground: UInt32) {
            switch scene {
            case .ball:
                return (ballSymbol, ballColor)
            case .final(let index, _):
                return (inputSymbol, finalColors[index])
            case .done:
                return (inputSymbol, finalColors[finalColors.count - 1])
            }
        }
    }

    private static let finalGradientSteps = 10
    private static let finalFrameDuration = 6

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var groups: [[Int]] = []
    private var pending: [Int] = []
    private var active: [Int] = []
    private var ballDelay = 0
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, bouncyBallsConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        bouncyBallsConfiguration: Configuration
    ) {
        self.canvas = canvas
        options = bouncyBallsConfiguration
        rng = Xoshiro256PlusPlus(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        if !hasPendingWork {
            isComplete = true
            return .complete
        }

        if pending.isEmpty, !groups.isEmpty {
            pending = groups.removeFirst()
        }
        if !pending.isEmpty {
            if ballDelay == 0 {
                for _ in 0..<rng.integer(in: 2...6) {
                    guard !pending.isEmpty else { break }
                    let index = rng.integer(in: 0...pending.count - 1)
                    let glyphIndex = pending.remove(at: index)
                    glyphs[glyphIndex].visible = true
                    active.append(glyphIndex)
                }
                ballDelay = options.ballDelay
            } else {
                ballDelay -= 1
            }
        }

        active.sort { glyphs[$0].characterID < glyphs[$1].characterID }
        for index in active { updatePath(for: index) }
        render(into: &frame)
        for index in active { updateScene(for: index) }
        active.removeAll { !glyphs[$0].isActive }

        if !hasPendingWork {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        var created: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)] = []
        created.reserveCapacity(input.scalars.count)
        for (index, pair) in zip(input.scalars, input.positions).enumerated() {
            if pair.0 != 32 {
                created.append((index, pair.0, Coordinate(column: pair.1.column, row: pair.1.row)))
            }
        }
        guard !created.isEmpty else {
            isComplete = true
            return
        }

        let coordinates = created.map(\.coordinate)
        let bottom = coordinates.map(\.row).min()!
        let top = coordinates.map(\.row).max()!
        let left = coordinates.map(\.column).min()!
        let right = coordinates.map(\.column).max()!
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )
        let finalColors = Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, Self.rgb($0.color)) })

        let buildOrder = created.indices.sorted {
            let lhs = created[$0].coordinate
            let rhs = created[$1].coordinate
            if lhs.row != rhs.row { return lhs.row > rhs.row }
            return lhs.column < rhs.column
        }

        glyphs = Array(repeating: placeholderGlyph(), count: created.count)
        var pendingOrder: [Int] = []
        pendingOrder.reserveCapacity(created.count)
        for sourceIndex in buildOrder {
            let source = created[sourceIndex]
            let ballColor = options.ballColors[rng.integer(in: 0..<options.ballColors.count)]
            let ballSymbol = options.ballSymbols[rng.integer(in: 0..<options.ballSymbols.count)]
            let mappedFinal = color(finalColors[source.coordinate]!)
            let fade = try! Gradient(stops: [ballColor, mappedFinal], steps: Self.finalGradientSteps).spectrum.map(Self.rgb)
            let dropRow = Int(Double(canvas.rows) * rng.uniform(1.0, 1.5))
            let origin = Coordinate(column: source.coordinate.column, row: dropRow)
            let distance = Geometry.lineLength(from: origin, to: source.coordinate)
            glyphs[sourceIndex] = Glyph(
                characterID: source.characterID,
                inputCoordinate: source.coordinate,
                inputSymbol: source.symbol,
                ballSymbol: ballSymbol.unicodeScalars.first!.value,
                ballColor: Self.rgb(ballColor),
                finalColors: fade,
                origin: origin,
                totalDistance: distance,
                pathSteps: PyCompat.roundHalfEven(distance / options.movementSpeed),
                coordinate: origin
            )
            pendingOrder.append(sourceIndex)
        }

        let sortedByRow = pendingOrder.sorted { glyphs[$0].inputCoordinate.row < glyphs[$1].inputCoordinate.row }
        var grouped: [Int: [Int]] = [:]
        var rows: [Int] = []
        for index in sortedByRow {
            let row = glyphs[index].inputCoordinate.row
            if grouped[row] == nil { rows.append(row) }
            grouped[row, default: []].append(index)
        }
        groups = rows.sorted().compactMap { grouped[$0] }
        ballDelay = 0
    }

    private mutating func updatePath(for index: Int) {
        guard glyphs[index].pathActive else { return }
        let glyph = glyphs[index]
        if glyph.pathSteps == 0 || glyph.totalDistance == 0 {
            glyphs[index].coordinate = glyph.inputCoordinate
            glyphs[index].pathActive = false
            activateFinal(for: index)
            return
        }
        glyphs[index].pathStep += 1
        let ratio = Double(glyphs[index].pathStep) / Double(glyph.pathSteps)
        let distance = options.movementEasing.value(at: ratio) * glyph.totalDistance
        glyphs[index].coordinate = Geometry.coordinateOnLine(
            from: glyph.origin,
            to: glyph.inputCoordinate,
            t: distance / glyph.totalDistance
        )
        if glyphs[index].pathStep == glyph.pathSteps {
            glyphs[index].pathActive = false
            activateFinal(for: index)
        }
    }

    private mutating func activateFinal(for index: Int) {
        glyphs[index].scene = .final(index: 0, ticksElapsed: 0)
    }

    private mutating func updateScene(for index: Int) {
        switch glyphs[index].scene {
        case .ball, .done:
            break
        case .final(let colorIndex, let ticksElapsed):
            let elapsed = ticksElapsed + 1
            if elapsed == Self.finalFrameDuration {
                if colorIndex + 1 < glyphs[index].finalColors.count {
                    glyphs[index].scene = .final(index: colorIndex + 1, ticksElapsed: 0)
                } else {
                    glyphs[index].scene = .done
                }
            } else {
                glyphs[index].scene = .final(index: colorIndex, ticksElapsed: elapsed)
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: (layer: Int, characterID: Int, visual: (symbol: UInt32, foreground: UInt32))] = [:]
            for glyph in glyphs where glyph.visible {
                let coordinate = glyph.coordinate
                guard (1...canvas.columns).contains(coordinate.column),
                      (1...canvas.rows).contains(coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - coordinate.row) * canvas.columns + coordinate.column - 1
                if let winner = winners[cellIndex], (winner.layer, winner.characterID) > (0, glyph.characterID) {
                    continue
                }
                winners[cellIndex] = (0, glyph.characterID, glyph.visual)
            }
            for (index, winner) in winners {
                cells[index] = .init(codepoint: winner.visual.symbol, foreground: winner.visual.foreground, background: 0)
            }
        }
    }

    private var hasPendingWork: Bool {
        !groups.isEmpty || !pending.isEmpty || !active.isEmpty
    }

    private func placeholderGlyph() -> Glyph {
        Glyph(
            characterID: 0,
            inputCoordinate: Coordinate(column: 1, row: 1),
            inputSymbol: 32,
            ballSymbol: 32,
            ballColor: 0,
            finalColors: [0],
            origin: Coordinate(column: 1, row: 1),
            totalDistance: 0,
            pathSteps: 0,
            coordinate: Coordinate(column: 1, row: 1),
            pathActive: false,
            scene: .done
        )
    }

    private func color(_ word: UInt32) -> Color {
        Color(hex: String(format: "%06x", word))
    }

    private static func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
