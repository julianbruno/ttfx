import TTFXCore

public struct UnstableEffect: Effect {
    public struct Configuration: Sendable {
        public var unstableColor: Color
        public var explosionEasing: Easing
        public var explosionSpeed: Double
        public var reassemblyEasing: Easing
        public var reassemblySpeed: Double
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            unstableColor: Color = Color(hex: "ff9200"),
            explosionEasing: Easing = .outExpo,
            explosionSpeed: Double = 1.0,
            reassemblyEasing: Easing = .outExpo,
            reassemblySpeed: Double = 1.0,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(explosionSpeed > 0, "explosion speed must be positive")
            precondition(reassemblySpeed > 0, "reassembly speed must be positive")
            self.unstableColor = unstableColor
            self.explosionEasing = explosionEasing
            self.explosionSpeed = explosionSpeed
            self.reassemblyEasing = reassemblyEasing
            self.reassemblySpeed = reassemblySpeed
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Phase { case rumble, explosion, reassembly, complete }

    private struct Glyph {
        let characterID: Int
        let symbol: UInt32
        let inputCoordinate: Coordinate
        let jumbledCoordinate: Coordinate
        let explosionTarget: Coordinate
        let finalColor: UInt32
        let rumbleColors: [UInt32]
        let finalColors: [UInt32]
        var coordinate: Coordinate
        var sceneIndex = 0
        var sceneTicks = 0
        var path: PathState?
        var activePath = false
    }

    private struct PathState {
        let start: Coordinate
        let end: Coordinate
        let easing: Easing
        let steps: Int
        var step = 0
    }

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var phase: Phase = .rumble
    private var currentRumbleSteps = 0
    private var maxRumbleSteps = 150
    private var rumbleModDelay = 18
    private var explosionHoldTime = 30
    private var active: [Int] = []

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, unstableConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        unstableConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = unstableConfiguration
        self.rng = Xoshiro256PlusPlus(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard phase != .complete else { return .complete }
        guard !glyphs.isEmpty else {
            phase = .complete
            return .complete
        }

        var emitted = false
        if phase == .rumble {
            if currentRumbleSteps < maxRumbleSteps {
                if currentRumbleSteps > 30 && currentRumbleSteps % rumbleModDelay == 0 {
                    let rowOffset = [-1, 0, 1][rng.integer(in: 0..<3)]
                    let columnOffset = [-1, 0, 1][rng.integer(in: 0..<3)]
                    for index in glyphs.indices {
                        glyphs[index].coordinate = Coordinate(
                            column: glyphs[index].coordinate.column + columnOffset,
                            row: glyphs[index].coordinate.row + rowOffset
                        )
                    }
                    render(into: &frame)
                    for index in glyphs.indices {
                        glyphs[index].coordinate = glyphs[index].jumbledCoordinate
                        advanceRumbleScene(index)
                    }
                    rumbleModDelay = max(1, rumbleModDelay - 1)
                } else {
                    render(into: &frame)
                    for index in glyphs.indices { advanceRumbleScene(index) }
                }
                currentRumbleSteps += 1
                emitted = true
            } else {
                phase = .explosion
                active = glyphs.indices.map { $0 }
                for index in active { activateExplosion(index) }
            }
        }

        if !emitted && phase == .explosion {
            if !active.isEmpty {
                for index in active { updatePath(index) }
                active.removeAll { glyphs[$0].coordinate == glyphs[$0].explosionTarget }
                render(into: &frame)
                emitted = true
            } else if explosionHoldTime != 0 {
                explosionHoldTime -= 1
                render(into: &frame)
                emitted = true
            } else {
                phase = .reassembly
                active = glyphs.indices.map { $0 }
                for index in active { activateReassembly(index) }
            }
        }

        if !emitted && phase == .reassembly, !active.isEmpty {
            for index in active { updatePath(index) }
            render(into: &frame)
            for index in active { advanceFinalScene(index) }
            active = active.filter { !(glyphs[$0].coordinate == glyphs[$0].inputCoordinate && finalSceneComplete($0)) }
            if active.isEmpty { phase = .complete }
            emitted = true
        }

        if !emitted {
            phase = .complete
            return .complete
        }
        return phase == .complete ? .complete : .running
    }

    private mutating func build(input: InputText) {
        var created: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)] = []
        for (index, pair) in zip(input.scalars, input.positions).enumerated() where pair.0 != 32 {
            created.append((index, pair.0, Coordinate(column: pair.1.column, row: pair.1.row)))
        }
        guard !created.isEmpty else {
            phase = .complete
            return
        }

        let bottom = created.map(\.coordinate.row).min()!
        let top = created.map(\.coordinate.row).max()!
        let left = created.map(\.coordinate.column).min()!
        let right = created.map(\.coordinate.column).max()!
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )
        let finalColors = Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, $0.color) })
        var remainingCoordinates = created.map(\.coordinate)
        let ordered = created.sorted {
            if $0.coordinate.row != $1.coordinate.row { return $0.coordinate.row > $1.coordinate.row }
            if $0.coordinate.column != $1.coordinate.column { return $0.coordinate.column < $1.coordinate.column }
            return $0.characterID < $1.characterID
        }
        glyphs = []
        glyphs.reserveCapacity(created.count)
        for source in ordered {
            let edge = rng.integer(in: 0...3)
            let target: Coordinate
            switch edge {
            case 0:
                target = Coordinate(column: 1, row: randomRow())
            case 1:
                target = Coordinate(column: canvas.columns, row: randomRow())
            case 2:
                target = Coordinate(column: randomColumn(), row: 1)
            default:
                target = Coordinate(column: randomColumn(), row: canvas.rows)
            }
            let jumbledIndex = rng.integer(in: 0..<remainingCoordinates.count)
            let jumbled = remainingCoordinates.remove(at: jumbledIndex)
            let final = finalColors[source.coordinate] ?? finalGradient.spectrum.last!
            let mappedFinal = final
            let rumble = try! Gradient(stops: [mappedFinal, options.unstableColor], steps: 12).spectrum.map(Self.rgb)
            var finalScene = try! Gradient(stops: [options.unstableColor, mappedFinal], steps: 12).spectrum.map(Self.rgb)
            finalScene.append(finalScene[finalScene.count - 1])
            glyphs.append(Glyph(
                characterID: source.characterID,
                symbol: source.symbol,
                inputCoordinate: source.coordinate,
                jumbledCoordinate: jumbled,
                explosionTarget: target,
                finalColor: Self.rgb(mappedFinal),
                rumbleColors: rumble,
                finalColors: finalScene,
                coordinate: jumbled
            ))
        }
        glyphs.sort { $0.characterID < $1.characterID }
    }

    private mutating func activateExplosion(_ index: Int) {
        glyphs[index].path = makePath(
            start: glyphs[index].coordinate,
            end: glyphs[index].explosionTarget,
            easing: options.explosionEasing,
            speed: options.explosionSpeed
        )
        glyphs[index].activePath = true
    }

    private mutating func activateReassembly(_ index: Int) {
        glyphs[index].sceneIndex = 0
        glyphs[index].sceneTicks = 0
        glyphs[index].path = makePath(
            start: glyphs[index].coordinate,
            end: glyphs[index].inputCoordinate,
            easing: options.reassemblyEasing,
            speed: options.reassemblySpeed
        )
        glyphs[index].activePath = true
    }

    private func makePath(start: Coordinate, end: Coordinate, easing: Easing, speed: Double) -> PathState {
        let distance = Geometry.lineLength(from: start, to: end)
        return PathState(start: start, end: end, easing: easing, steps: PyCompat.roundHalfEven(distance / speed))
    }

    private mutating func updatePath(_ index: Int) {
        guard var path = glyphs[index].path else { return }
        if path.steps == 0 {
            glyphs[index].coordinate = path.end
            glyphs[index].path = nil
            glyphs[index].activePath = false
            return
        }
        path.step += 1
        let t = path.easing.value(at: Double(path.step) / Double(path.steps))
        glyphs[index].coordinate = Geometry.coordinateOnLine(from: path.start, to: path.end, t: t)
        if path.step >= path.steps {
            glyphs[index].path = nil
            glyphs[index].activePath = false
        } else {
            glyphs[index].path = path
        }
    }

    private mutating func advanceRumbleScene(_ index: Int) {
        advanceScene(index, frameDuration: 10, colorsCount: glyphs[index].rumbleColors.count)
    }

    private mutating func advanceFinalScene(_ index: Int) {
        advanceScene(index, frameDuration: 3, colorsCount: glyphs[index].finalColors.count)
    }

    private mutating func advanceScene(_ index: Int, frameDuration: Int, colorsCount: Int) {
        glyphs[index].sceneTicks += 1
        guard glyphs[index].sceneTicks >= frameDuration else { return }
        glyphs[index].sceneTicks = 0
        if glyphs[index].sceneIndex + 1 < colorsCount { glyphs[index].sceneIndex += 1 }
    }

    private func finalSceneComplete(_ index: Int) -> Bool {
        glyphs[index].sceneIndex + 1 == glyphs[index].finalColors.count && glyphs[index].sceneTicks == 0
    }

    private mutating func randomRow() -> Int { rng.integer(in: 1...canvas.rows) }
    private mutating func randomColumn() -> Int { rng.integer(in: 1...canvas.columns) }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: Glyph] = [:]
            for glyph in glyphs.sorted(by: { $0.characterID < $1.characterID }) {
                guard (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                winners[cellIndex] = glyph
            }
            for (cellIndex, glyph) in winners {
                let color: UInt32
                switch phase {
                case .rumble, .explosion:
                    color = glyph.rumbleColors[min(glyph.sceneIndex, glyph.rumbleColors.count - 1)]
                case .reassembly, .complete:
                    color = glyph.finalColors[min(glyph.sceneIndex, glyph.finalColors.count - 1)]
                }
                cells[cellIndex] = Cell(codepoint: glyph.symbol, foreground: color, background: 0)
            }
        }
    }

    private static func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
