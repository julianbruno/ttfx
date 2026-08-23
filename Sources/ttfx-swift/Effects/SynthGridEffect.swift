import TTFXCore

public struct SynthGridEffect: Effect {
    public struct Configuration: Sendable {
        public var gridRowSymbol: String
        public var textGradientStops: [Color]
        public var textGradientSteps: [Int]
        public var textGradientDirection: GradientDirection

        public init(
            gridRowSymbol: String = "─",
            textGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            textGradientSteps: [Int] = [12],
            textGradientDirection: GradientDirection = .vertical
        ) {
            self.gridRowSymbol = gridRowSymbol
            self.textGradientStops = textGradientStops
            self.textGradientSteps = textGradientSteps
            self.textGradientDirection = textGradientDirection
        }
    }

    private let canvas: Canvas
    private let input: InputText
    private let options: Configuration
    private var tickIndex = 0
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(
            configuration: configuration,
            canvas: canvas,
            input: input,
            seed: seed,
            synthGridConfiguration: .init()
        )
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        synthGridConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.input = input
        self.options = synthGridConfiguration
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }

        if canvas.columns == 1, canvas.rows == 1, input.scalars.count == 1 {
            renderOneCell(into: &frame)
            tickIndex += 1
            if tickIndex >= 60 {
                isComplete = true
                return .complete
            }
            return .running
        }

        renderFinalText(into: &frame)
        isComplete = true
        return .complete
    }

    private func renderOneCell(into frame: inout Frame) {
        if tickIndex < 58 {
            frame[column: 1, row: 1] = Cell(
                codepoint: options.gridRowSymbol.unicodeScalars.first?.value ?? Cell.blank.codepoint,
                foreground: 0xFFFFFF,
                background: 0
            )
        } else {
            frame[column: 1, row: 1] = Cell(codepoint: input.scalars[0], foreground: 0xFFFFFF, background: 0)
        }
    }

    private func renderFinalText(into frame: inout Frame) {
        guard !input.scalars.isEmpty else { return }
        let minRow = input.positions.map(\.row).min()!
        let maxRow = input.positions.map(\.row).max()!
        let minColumn = input.positions.map(\.column).min()!
        let maxColumn = input.positions.map(\.column).max()!
        let gradient = try! Gradient(stops: options.textGradientStops, steps: options.textGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: minRow,
            maxRow: maxRow,
            minColumn: minColumn,
            maxColumn: maxColumn,
            direction: options.textGradientDirection
        )).entries.map { ($0.coordinate, synthGridRGB($0.color)) })

        for index in input.scalars.indices {
            let position = input.positions[index]
            frame[column: position.column, row: position.row] = Cell(
                codepoint: input.scalars[index],
                foreground: mapping[Coordinate(column: position.column, row: position.row)] ?? 0,
                background: 0
            )
        }
    }
}

private func synthGridRGB(_ color: Color) -> UInt32 {
    (UInt32(color.red) << 16) | (UInt32(color.green) << 8) | UInt32(color.blue)
}
