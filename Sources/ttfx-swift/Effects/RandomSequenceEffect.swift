import TTFXCore

private let randomSequenceExplicitBlackForegroundSentinel: UInt32 = 0xFFFF_FFFE

public struct RandomSequenceEffect: Effect {
    public struct Configuration: Sendable {
        public var speed: Double
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientFrames: Int
        public var finalGradientDirection: GradientDirection

        public init(
            speed: Double = 0.007,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientFrames: Int = 8,
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(speed > 0, "speed must be positive")
            precondition(finalGradientFrames > 0, "final gradient frames must be positive")
            self.speed = speed
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientFrames = finalGradientFrames
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph {
        let characterID: Int
        let coordinate: Coordinate
        let symbol: UInt32
        let frames: [UInt32]
        var visible = false
        var active = false
        var frameIndex = 0
    }

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var pending: [Int] = []
    private var charactersPerTick = 1
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, randomSequenceConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        randomSequenceConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = randomSequenceConfiguration
        self.rng = Xoshiro256PlusPlus(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard !glyphs.isEmpty else {
            isComplete = true
            return .complete
        }

        for _ in 0..<charactersPerTick {
            guard let next = pending.popLast() else { break }
            glyphs[next].visible = true
            glyphs[next].active = true
        }

        render(into: &frame)
        advanceScenes()

        if pending.isEmpty && !glyphs.contains(where: \.active) {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        let created = zip(input.scalars, input.positions).enumerated().map { index, pair in
            (
                characterID: index,
                symbol: pair.0,
                coordinate: Coordinate(column: pair.1.column, row: pair.1.row)
            )
        }.sorted { lhs, rhs in
            if lhs.coordinate.row != rhs.coordinate.row { return lhs.coordinate.row > rhs.coordinate.row }
            if lhs.coordinate.column != rhs.coordinate.column { return lhs.coordinate.column < rhs.coordinate.column }
            return lhs.characterID < rhs.characterID
        }
        guard !created.isEmpty else {
            isComplete = true
            return
        }

        charactersPerTick = max(Int(options.speed * Double(input.scalars.count)), 1)
        let bottom = created.map(\.coordinate.row).min()!
        let top = created.map(\.coordinate.row).max()!
        let left = created.map(\.coordinate.column).min()!
        let right = created.map(\.coordinate.column).max()!
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let finalMapping = try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )
        let finalColorByCoordinate = Dictionary(uniqueKeysWithValues: finalMapping.entries.map { ($0.coordinate, $0.color) })
        let terminalBackground = Color(hex: "000000")

        glyphs = created.map { source in
            let finalColor = finalColorByCoordinate[source.coordinate]!
            let spectrum = (try! Gradient(stops: [terminalBackground, finalColor], steps: 7)).spectrum
            let frames = spectrum.flatMap { color in
                Array(repeating: Self.rgb(color), count: options.finalGradientFrames)
            }
            return Glyph(
                characterID: source.characterID,
                coordinate: source.coordinate,
                symbol: source.symbol,
                frames: frames
            )
        }
        pending = Array(glyphs.indices)
        rng.shuffle(&pending)
    }

    private mutating func advanceScenes() {
        for index in glyphs.indices where glyphs[index].active {
            if glyphs[index].frameIndex + 1 < glyphs[index].frames.count {
                glyphs[index].frameIndex += 1
            } else {
                glyphs[index].active = false
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            for glyph in glyphs.sorted(by: { $0.characterID < $1.characterID }) where glyph.visible {
                guard (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                let foreground = glyph.frames[min(glyph.frameIndex, glyph.frames.count - 1)]
                cells[cellIndex] = Cell(
                    codepoint: glyph.symbol,
                    foreground: foreground,
                    background: foreground == 0 ? randomSequenceExplicitBlackForegroundSentinel : 0
                )
            }
        }
    }

    private static func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
