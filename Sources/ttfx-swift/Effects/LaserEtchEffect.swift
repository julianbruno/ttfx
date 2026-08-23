import TTFXCore

public struct LaserEtchEffect: Effect {
    public struct Configuration: Sendable {
        public enum EtchPattern: Sendable {
            case algorithm
            case rowTopToBottom
        }

        public var etchPattern: EtchPattern

        public init(etchPattern: EtchPattern = .algorithm) {
            self.etchPattern = etchPattern
        }
    }

    private let laserEtchConfiguration: Configuration
    private let canvas: Canvas
    private let input: InputText
    private var emittedGroupedDeadBranchFrame = false
    private var tickIndex = 0

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(
            configuration: configuration,
            canvas: canvas,
            input: input,
            seed: seed,
            laserEtchConfiguration: .init()
        )
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        laserEtchConfiguration: Configuration
    ) {
        self.laserEtchConfiguration = laserEtchConfiguration
        self.canvas = canvas
        self.input = input
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        switch laserEtchConfiguration.etchPattern {
        case .rowTopToBottom:
            guard !emittedGroupedDeadBranchFrame else { return .complete }
            emittedGroupedDeadBranchFrame = true
            return .complete
        case .algorithm:
            guard canvas.columns == 1, canvas.rows == 1, input.scalars.count == 1 else {
                return .complete
            }
            renderOneCellDefault(into: &frame)
            tickIndex += 1
            return .running
        }
    }

    private mutating func renderOneCellDefault(into frame: inout Frame) {
        let cell: Cell
        if tickIndex == 0 {
            cell = Cell(codepoint: UInt32(UnicodeScalar("*").value), foreground: 0xFFFFFF, background: 0)
        } else if tickIndex <= 2 {
            cell = Cell(codepoint: UInt32(UnicodeScalar("^").value), foreground: 0xFFE680, background: 0)
        } else {
            let colorIndex = min((tickIndex - 3) / 3, Self.oneCellCoolingColors.count - 1)
            cell = Cell(codepoint: input.scalars[0], foreground: Self.oneCellCoolingColors[colorIndex], background: 0)
        }
        frame[column: 1, row: 1] = cell
    }

    private static let oneCellCoolingColors: [UInt32] = [
        0xFFE680,
        0xFFD870,
        0xFFCA60,
        0xFFBC50,
        0xFFAE40,
        0xFFA030,
        0xFF9220,
        0xFF8410,
        0xFF7B00,
        0xFF8B1F,
        0xFF9B3E,
        0xFFAB5D,
        0xFFBB7C,
        0xFFCB9B,
        0xFFDBBA,
        0xFFEBD9,
        0xFFFFFF
    ]
}
