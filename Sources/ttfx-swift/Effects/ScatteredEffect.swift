import TTFXCore

public struct ScatteredEffect: Effect {
    public struct Configuration: Sendable {
        public var movementSpeed: Double
        public var movementEasing: Easing
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientFrames: Int
        public var finalGradientDirection: GradientDirection

        public init(
            movementSpeed: Double = 0.5,
            movementEasing: Easing = .inOutBack,
            finalGradientStops: [Color] = [Color(hex: "ff9048"), Color(hex: "ab9dff"), Color(hex: "bdffea")],
            finalGradientSteps: [Int] = [12],
            finalGradientFrames: Int = 9,
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(movementSpeed > 0, "movement speed must be positive")
            precondition(finalGradientFrames > 0, "final gradient frames must be positive")
            self.movementSpeed = movementSpeed
            self.movementEasing = movementEasing
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientFrames = finalGradientFrames
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph {
        let characterID: Int
        let target: Coordinate
        let symbol: UInt32
        let colors: [UInt32]
        let start: Coordinate
        let totalDistance: Double
        let maxSteps: Int
        var coordinate: Coordinate
        var currentStep = 0
        var lastDistance = 0.0
        var pathActive = true

        var layer: Int { pathActive ? 1 : 0 }
    }

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var initialHoldFrames = 25
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, scatteredConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        scatteredConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = scatteredConfiguration
        self.rng = Xoshiro256PlusPlus(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard !glyphs.isEmpty else {
            isComplete = true
            return .complete
        }

        if initialHoldFrames != 0 {
            initialHoldFrames -= 1
            render(into: &frame)
            return .running
        }

        advancePaths()
        render(into: &frame)
        if !glyphs.contains(where: \.pathActive) {
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
        let finalColorByCoordinate = Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, $0.color) })
        let startColor = finalGradient.spectrum[0]

        glyphs = created.sorted { lhs, rhs in
            if lhs.coordinate.row != rhs.coordinate.row { return lhs.coordinate.row > rhs.coordinate.row }
            if lhs.coordinate.column != rhs.coordinate.column { return lhs.coordinate.column < rhs.coordinate.column }
            return lhs.characterID < rhs.characterID
        }.map { source in
            let targetColor = finalColorByCoordinate[source.coordinate]!
            let colors = (try! Gradient(stops: [startColor, targetColor], steps: 10)).spectrum.map(Self.rgb)
            let start = startCoordinate()
            let distance = Geometry.lineLength(from: start, to: source.coordinate)
            return Glyph(
                characterID: source.characterID,
                target: source.coordinate,
                symbol: source.symbol,
                colors: colors,
                start: start,
                totalDistance: distance,
                maxSteps: PyCompat.roundHalfEven(distance / options.movementSpeed),
                coordinate: start
            )
        }
    }

    private mutating func advancePaths() {
        for index in glyphs.indices where glyphs[index].pathActive {
            let start = glyphs[index].start
            guard glyphs[index].maxSteps > 0, glyphs[index].totalDistance != 0 else {
                glyphs[index].coordinate = glyphs[index].target
                glyphs[index].lastDistance = glyphs[index].totalDistance
                glyphs[index].pathActive = false
                continue
            }

            glyphs[index].currentStep += 1
            let ratio = Double(glyphs[index].currentStep) / Double(glyphs[index].maxSteps)
            let distance = options.movementEasing.value(at: ratio) * glyphs[index].totalDistance
            glyphs[index].lastDistance = distance
            glyphs[index].coordinate = Geometry.coordinateOnLine(
                from: start,
                to: glyphs[index].target,
                t: distance / glyphs[index].totalDistance
            )
            if glyphs[index].currentStep == glyphs[index].maxSteps {
                glyphs[index].pathActive = false
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: (layer: Int, order: Int, glyph: Glyph)] = [:]
            for glyph in glyphs.sorted(by: { $0.characterID < $1.characterID }) {
                guard (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                if let existing = winners[cellIndex], existing.layer > glyph.layer { continue }
                winners[cellIndex] = (glyph.layer, glyph.characterID, glyph)
            }
            for (index, winner) in winners {
                cells[index] = Cell(codepoint: winner.glyph.symbol, foreground: foreground(for: winner.glyph), background: 0)
            }
        }
    }

    private func foreground(for glyph: Glyph) -> UInt32 {
        guard glyph.pathActive else { return glyph.colors[glyph.colors.count - 1] }
        if glyph.currentStep == 0 { return glyph.colors[0] }
        let total = max(glyph.totalDistance, 1)
        let remaining = max(glyph.totalDistance - glyph.lastDistance, 1)
        let reached = max(total - remaining, 1)
        let progress = reached / total
        let index = min(max(PyCompat.roundHalfEven(Double(glyph.colors.count - 1) * progress), 0), glyph.colors.count - 1)
        return glyph.colors[index]
    }

    private mutating func startCoordinate() -> Coordinate {
        guard canvas.columns >= 2, canvas.rows >= 2 else { return Coordinate(column: 1, row: 1) }
        return Coordinate(column: rng.integer(in: 1...canvas.columns), row: rng.integer(in: 1...canvas.rows))
    }

    private static func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
