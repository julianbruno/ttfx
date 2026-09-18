import TTFXCore

public struct SprayEffect: Effect {
    public enum Position: Sendable {
        case n, ne, e, se, s, sw, w, nw, center
    }

    public struct Configuration: Sendable {
        public var position: Position
        public var volume: Double
        public var movementSpeedRange: ClosedRange<Double>
        public var movementEasing: Easing
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            position: Position = .e,
            volume: Double = 0.005,
            movementSpeedRange: ClosedRange<Double> = 0.6...1.4,
            movementEasing: Easing = .outExpo,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(volume > 0, "spray volume must be positive")
            precondition(movementSpeedRange.lowerBound > 0 && movementSpeedRange.upperBound > 0, "movement speed range must be positive")
            precondition(movementSpeedRange.lowerBound <= movementSpeedRange.upperBound, "movement speed range must not be empty")
            self.position = position
            self.volume = volume
            self.movementSpeedRange = movementSpeedRange
            self.movementEasing = movementEasing
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum SceneState {
        case frame(index: Int, ticksElapsed: Int)
        case done
    }

    private struct Glyph {
        let characterID: Int
        let target: Coordinate
        let symbol: UInt32
        let colors: [UInt32]
        let origin: Coordinate
        let totalDistance: Double
        let maxSteps: Int
        var coordinate: Coordinate
        var currentStep = 0
        var pathActive = true
        var visible = false
        var scene: SceneState = .frame(index: 0, ticksElapsed: 0)

        var active: Bool {
            if pathActive { return true }
            if case .frame = scene { return true }
            return false
        }

        var layer: Int { pathActive ? 1 : 0 }
    }

    private static let sceneFrameDuration = 20
    private static let sprayGradientSteps = 7

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var pending: [Int] = []
    private var active: [Int] = []
    private var releaseVolume = 1
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, sprayConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        sprayConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = sprayConfiguration
        self.rng = configuration.makeRNG(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard hasPendingWork else {
            isComplete = true
            return .complete
        }

        if !pending.isEmpty {
            for _ in 0..<rng.integer(in: 1...releaseVolume) {
                guard let glyphIndex = pending.popLast() else { break }
                glyphs[glyphIndex].visible = true
                active.append(glyphIndex)
            }
        }

        active.sort { glyphs[$0].characterID < glyphs[$1].characterID }
        for glyphIndex in active {
            updatePath(for: glyphIndex)
        }
        render(into: &frame)
        for glyphIndex in active {
            updateScene(for: glyphIndex)
        }
        active.removeAll { !glyphs[$0].active }

        if !hasPendingWork {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        var created: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)] = []
        created.reserveCapacity(input.scalars.count)
        for (index, pair) in zip(input.scalars, input.positions).enumerated() where pair.0 != 32 {
            created.append((index, pair.0, Coordinate(column: pair.1.column, row: pair.1.row)))
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
        let finalMapping = try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )
        let finalColorByCoordinate = Dictionary(uniqueKeysWithValues: finalMapping.entries.map { ($0.coordinate, $0.color) })
        let origin = sprayOrigin()

        let buildOrder = created.indices.sorted {
            let lhs = created[$0].coordinate
            let rhs = created[$1].coordinate
            if lhs.row != rhs.row { return lhs.row > rhs.row }
            if lhs.column != rhs.column { return lhs.column < rhs.column }
            return created[$0].characterID < created[$1].characterID
        }

        glyphs = Array(repeating: placeholderGlyph(), count: created.count)
        pending.reserveCapacity(created.count)
        for sourceIndex in buildOrder {
            let source = created[sourceIndex]
            let speed = rng.uniform(options.movementSpeedRange.lowerBound, options.movementSpeedRange.upperBound)
            let startColor = finalGradient.spectrum[rng.integer(in: 0..<finalGradient.spectrum.count)]
            let finalColor = finalColorByCoordinate[source.coordinate]!
            let colors = try! Gradient(stops: [startColor, finalColor], steps: Self.sprayGradientSteps).spectrum.map(rgb)
            let distance = Geometry.lineLength(from: origin, to: source.coordinate)
            glyphs[sourceIndex] = Glyph(
                characterID: source.characterID,
                target: source.coordinate,
                symbol: source.symbol,
                colors: colors,
                origin: origin,
                totalDistance: distance,
                maxSteps: PyCompat.roundHalfEven(distance / speed),
                coordinate: origin
            )
            pending.append(sourceIndex)
        }
        rng.shuffle(&pending)
        releaseVolume = max(Int(Double(pending.count) * options.volume), 1)
    }

    private mutating func updatePath(for index: Int) {
        guard glyphs[index].pathActive else { return }
        let glyph = glyphs[index]
        if glyph.maxSteps <= 0 || glyph.totalDistance == 0 {
            glyphs[index].coordinate = glyph.target
            glyphs[index].pathActive = false
            return
        }

        glyphs[index].currentStep += 1
        let ratio = Double(glyphs[index].currentStep) / Double(glyph.maxSteps)
        let distance = options.movementEasing.value(at: ratio) * glyph.totalDistance
        glyphs[index].coordinate = Geometry.coordinateOnLine(
            from: glyph.origin,
            to: glyph.target,
            t: distance / glyph.totalDistance
        )
        if glyphs[index].currentStep == glyph.maxSteps {
            glyphs[index].pathActive = false
        }
    }

    private mutating func updateScene(for index: Int) {
        switch glyphs[index].scene {
        case .done:
            break
        case .frame(let colorIndex, let ticksElapsed):
            let elapsed = ticksElapsed + 1
            if elapsed == Self.sceneFrameDuration {
                if colorIndex + 1 < glyphs[index].colors.count {
                    glyphs[index].scene = .frame(index: colorIndex + 1, ticksElapsed: 0)
                } else {
                    glyphs[index].scene = .done
                }
            } else {
                glyphs[index].scene = .frame(index: colorIndex, ticksElapsed: elapsed)
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: (layer: Int, characterID: Int, glyphIndex: Int)] = [:]
            for index in glyphs.indices where glyphs[index].visible {
                let coordinate = glyphs[index].coordinate
                guard (1...canvas.columns).contains(coordinate.column),
                      (1...canvas.rows).contains(coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - coordinate.row) * canvas.columns + coordinate.column - 1
                let candidate = (glyphs[index].layer, glyphs[index].characterID)
                if let winner = winners[cellIndex], (winner.layer, winner.characterID) > candidate {
                    continue
                }
                winners[cellIndex] = (glyphs[index].layer, glyphs[index].characterID, index)
            }
            for (cellIndex, winner) in winners {
                let glyph = glyphs[winner.glyphIndex]
                cells[cellIndex] = Cell(codepoint: glyph.symbol, foreground: foreground(for: glyph), background: 0)
            }
        }
    }

    private func foreground(for glyph: Glyph) -> UInt32 {
        switch glyph.scene {
        case .done:
            return glyph.colors[glyph.colors.count - 1]
        case .frame(let index, _):
            return glyph.colors[index]
        }
    }

    private var hasPendingWork: Bool {
        !pending.isEmpty || !active.isEmpty
    }

    private func sprayOrigin() -> Coordinate {
        switch options.position {
        case .center:
            return Coordinate(column: centered(canvas.columns), row: centered(canvas.rows))
        case .n:
            return Coordinate(column: PyCompat.floorDivide(canvas.columns, 2), row: canvas.rows)
        case .ne:
            return Coordinate(column: canvas.columns - 1, row: canvas.rows)
        case .e:
            return Coordinate(column: canvas.columns - 1, row: PyCompat.floorDivide(canvas.rows, 2))
        case .se:
            return Coordinate(column: canvas.columns - 1, row: 1)
        case .s:
            return Coordinate(column: PyCompat.floorDivide(canvas.columns, 2), row: 1)
        case .sw:
            return Coordinate(column: 1, row: 1)
        case .w:
            return Coordinate(column: 1, row: PyCompat.floorDivide(canvas.rows, 2))
        case .nw:
            return Coordinate(column: 1, row: canvas.rows)
        }
    }

    private func centered(_ size: Int) -> Int {
        var center = max(PyCompat.floorDivide(size, 2), 1)
        if !size.isMultiple(of: 2), size > 1 { center += 1 }
        return center
    }

    private func placeholderGlyph() -> Glyph {
        Glyph(
            characterID: 0,
            target: Coordinate(column: 1, row: 1),
            symbol: 32,
            colors: [0],
            origin: Coordinate(column: 1, row: 1),
            totalDistance: 0,
            maxSteps: 0,
            coordinate: Coordinate(column: 1, row: 1),
            pathActive: false,
            visible: false,
            scene: .done
        )
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
