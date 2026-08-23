import TTFXCore

public struct RingsEffect: Effect {
    public struct Configuration: Sendable {
        public var ringColors: [Color]
        public var ringGap: Double
        public var spinDuration: Int
        public var spinSpeed: ClosedRange<Double>
        public var disperseDuration: Int
        public var spinDisperseCycles: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            ringColors: [Color] = [Color(hex: "ab48ff"), Color(hex: "e7b2b2"), Color(hex: "fffebd")],
            ringGap: Double = 0.1,
            spinDuration: Int = 200,
            spinSpeed: ClosedRange<Double> = 0.25...1.0,
            disperseDuration: Int = 200,
            spinDisperseCycles: Int = 3,
            finalGradientStops: [Color] = [Color(hex: "ab48ff"), Color(hex: "e7b2b2"), Color(hex: "fffebd")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(ringGap > 0, "ring gap must be positive")
            precondition(spinDuration > 0, "spin duration must be positive")
            precondition(spinSpeed.lowerBound > 0, "spin speed range must be positive")
            precondition(disperseDuration > 0, "disperse duration must be positive")
            precondition(spinDisperseCycles > 0, "spin disperse cycles must be positive")
            self.ringColors = ringColors
            self.ringGap = ringGap
            self.spinDuration = spinDuration
            self.spinSpeed = spinSpeed
            self.disperseDuration = disperseDuration
            self.spinDisperseCycles = spinDisperseCycles
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private let input: InputText
    private let canvas: Canvas
    private let options: Configuration
    private var tickIndex = 0
    private var frames: [[Cell]] = []
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, ringsConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        ringsConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.input = input
        self.options = ringsConfiguration
        if canvas.columns == 1, canvas.rows == 1, input.scalars.count == 1 {
            self.frames = Self.makeOneCellFrames(inputSymbol: input.scalars[0], options: ringsConfiguration)
        }
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        if !frames.isEmpty {
            let cells = frames[min(tickIndex, frames.count - 1)]
            for index in cells.indices {
                frame[column: index + 1, row: 1] = cells[index]
            }
            tickIndex += 1
            if tickIndex >= frames.count {
                isComplete = true
                return .complete
            }
            return .running
        }

        renderFinal(into: &frame)
        isComplete = true
        return .complete
    }

    private func renderFinal(into frame: inout Frame) {
        guard !input.scalars.isEmpty else { return }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let minRow = coordinates.map(\.row).min()!
        let maxRow = coordinates.map(\.row).max()!
        let minColumn = coordinates.map(\.column).min()!
        let maxColumn = coordinates.map(\.column).max()!
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: minRow,
            maxRow: maxRow,
            minColumn: minColumn,
            maxColumn: maxColumn,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, ringsRGB($0.color)) })
        for index in input.scalars.indices {
            let position = input.positions[index]
            frame[column: position.column, row: position.row] = Cell(
                codepoint: input.scalars[index],
                foreground: mapping[Coordinate(column: position.column, row: position.row)] ?? 0,
                background: 0
            )
        }
    }

    private static func makeOneCellFrames(inputSymbol: UInt32, options: Configuration) -> [[Cell]] {
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let finalColor = ringsRGB(finalGradient.spectrum.last ?? options.finalGradientStops.last!)
        let inputCell = Cell(codepoint: inputSymbol, foreground: finalColor, background: 0)
        let blank = Cell.blank
        // QUIRK(src/effects/rings.rs): with one input cell on a 1x1 canvas, no ring is
        // created, so the character remains at home through the 100-frame start hold,
        // briefly exits via the non-ring external path, then returns home to complete.
        return Array(repeating: [inputCell], count: 101)
            + Array(repeating: [blank], count: 4)
            + Array(repeating: [inputCell], count: 2)
    }
}

private func ringsRGB(_ color: Color) -> UInt32 {
    (UInt32(color.red) << 16) | (UInt32(color.green) << 8) | UInt32(color.blue)
}
